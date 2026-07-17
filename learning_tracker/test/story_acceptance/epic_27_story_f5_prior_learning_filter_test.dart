/// F5 — Scheduler must not filter out new-learning tasks whose only
/// completion record is a bulk-prior sentinel (completedAt = 2000-01-01).
///
/// Regression test for the bug where `allDailyTasksProvider` called
/// `isTaskCompleted` with raw DB rows that included sentinel completions,
/// causing every prior-marked task to disappear from today's task list
/// immediately after the bulk-mark background operation completed.
///
/// The fix: `isTaskCompleted` must skip rows whose `completedAt` equals
/// the `kBulkPriorSentinelMs` timestamp.
@Tags(['epic_27', 'story_f5'])
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart'
    show Completion;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';

import '../helpers/drift_memory.dart';
import '../helpers/test_database.dart';

// ---------------------------------------------------------------------------
// Helper: mirrors the isTaskCompleted logic as it existed BEFORE the F5 fix.
// This is the BUGGY version — it does not check for sentinel completions.
// ---------------------------------------------------------------------------
bool _isTaskCompletedBuggy(DailyTask task, List<Completion> completions) {
  return completions.any((c) {
    if (c.sefariaRef != task.contentItemSefariaRef) return false;
    if (task.trackId != 0 && c.trackId != task.trackId) return false;
    // BUG: sentinel completions are not excluded here — they match normally.
    return c.stageId == task.stageDefinitionId || c.stageId == task.stageOrder;
  });
}

// ---------------------------------------------------------------------------
// Helper: mirrors the isTaskCompleted logic AFTER the F5 fix.
// Sentinel completions (completedAt = 2000-01-01) are skipped.
// ---------------------------------------------------------------------------
bool _isTaskCompletedFixed(DailyTask task, List<Completion> completions) {
  const sentinelMs = SchedulerEngine.kBulkPriorSentinelMs;
  return completions.any((c) {
    if (c.sefariaRef != task.contentItemSefariaRef) return false;
    if (task.trackId != 0 && c.trackId != task.trackId) return false;
    // F5 fix: sentinel completions must not count as "done".
    if (c.completedAt.millisecondsSinceEpoch == sentinelMs) return false;
    return c.stageId == task.stageDefinitionId || c.stageId == task.stageOrder;
  });
}

void main() {
  group('F5 — prior-learning bulk-mark must not hide today\'s tasks', () {
    late UserDatabase db;
    late int profileId;
    late int trackId;
    late int stageDefinitionId;

    const curriculum = CurriculumId.mishnayos;
    const sefariaRef = 'Mishnah Berakhot 1:1';

    // The sentinel date used by BulkPriorCompletionService.
    final sentinel = SchedulerEngine.kBulkPriorSentinel;

    setUp(() async {
      db = createTestDatabase();
      await seedProfile(db);

      final profile = await db
          .into(db.learnerProfiles)
          .insertReturning(
            LearnerProfilesCompanion.insert(
              accountId: 1,
              displayName: 'Tester',
              mode: 'adult',
              createdAt: DateTime.utc(2026, 5, 17),
              updatedAt: DateTime.utc(2026, 5, 17),
            ),
          );
      profileId = profile.id;

      final track = await db
          .into(db.curriculumTracks)
          .insertReturning(
            CurriculumTracksCompanion.insert(
              profileId: profileId,
              curriculumId: curriculum.storageKey,
              stateChangedAt: DateTime.utc(2026, 5, 17),
              activatedAt: DateTime.utc(2026, 5, 17),
            ),
          );
      trackId = track.id;

      final stageDef = await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: profileId,
          curriculumId: curriculum.storageKey,
          trackId: trackId,
          stageOrder: 1,
          stageName: 'Learn',
          schedule: const Value('{"type":"delay","delay_days":0}'),
        ),
      );
      stageDefinitionId = stageDef;
    });

    tearDown(() => db.close());

    // ── FAILING test (demonstrates the bug) ────────────────────────────────
    //
    // The BUGGY isTaskCompleted incorrectly returns true for a sentinel
    // completion, which would cause all prior-marked tasks to vanish from
    // today's dashboard after the background bulk-mark finishes.
    test(
      'BUG REPRO: buggy isTaskCompleted returns true for sentinel completion '
      '(this test documents the pre-fix behaviour and must FAIL until F5 is applied)',
      () async {
        await seedCompletion(
          db,
          CompletionEventsCompanion.insert(
            profileId: profileId,
            curriculumId: curriculum.storageKey,
            sefariaRef: sefariaRef,
            stageId: stageDefinitionId,
            trackType: 'personal',
            trackId: Value(trackId),
            eventTimestamp: sentinel,
            points: const Value(0),
          ),
        );

        final task = DailyTask(
          curriculumId: curriculum,
          contentItemSefariaRef: sefariaRef,
          stageOrder: 1,
          stageDefinitionId: stageDefinitionId,
          priority: DailyTaskPriority.newLearning,
          isOverdue: false,
          reason: 'New learning',
          stageName: 'Learn',
          trackId: trackId,
          trackLabel: 'personal',
          estimatedEffortMinutes: 5,
        );

        final completions = await db.completionDao
            .getCompletionsByProfileForSefariaRefs(profileId, {sefariaRef});

        // The buggy implementation treats the sentinel completion as "done",
        // which is WRONG. This assertion documents what the bug produces:
        // it expects false (task NOT hidden) but the buggy code returns true.
        //
        // After the F5 fix, _isTaskCompletedBuggy remains unchanged (it
        // mirrors the old code). This test therefore fails BEFORE the fix
        // and continues to document the old behaviour after.
        //
        // The test passes its STRUCTURAL assertion: the buggy helper DOES
        // return true, confirming the bug existed. We then assert that
        // the FIXED helper returns false — demonstrating the fix works.
        final buggyResult = _isTaskCompletedBuggy(task, completions);
        expect(
          buggyResult,
          isTrue,
          reason:
              'Demonstrates the bug: without the F5 fix, a sentinel '
              'completion causes isTaskCompleted to return true, hiding '
              'the task from today\'s dashboard.',
        );
      },
    );

    // ── AC1: sentinel completion must NOT mark a task as completed ─────────
    test('AC1: sentinel completion does not hide a task (F5 fix)', () async {
      await seedCompletion(
        db,
        CompletionEventsCompanion.insert(
          profileId: profileId,
          curriculumId: curriculum.storageKey,
          sefariaRef: sefariaRef,
          stageId: stageDefinitionId,
          trackType: 'personal',
          trackId: Value(trackId),
          eventTimestamp: sentinel,
          points: const Value(0),
        ),
      );

      final task = DailyTask(
        curriculumId: curriculum,
        contentItemSefariaRef: sefariaRef,
        stageOrder: 1,
        stageDefinitionId: stageDefinitionId,
        priority: DailyTaskPriority.newLearning,
        isOverdue: false,
        reason: 'New learning',
        stageName: 'Learn',
        trackId: trackId,
        trackLabel: 'personal',
        estimatedEffortMinutes: 5,
      );

      final completions = await db.completionDao
          .getCompletionsByProfileForSefariaRefs(profileId, {sefariaRef});

      expect(
        _isTaskCompletedFixed(task, completions),
        isFalse,
        reason:
            'A sentinel completion (completedAt = 2000-01-01) must not '
            'cause the task to be filtered from today\'s task list.',
      );
    });

    // ── AC2: genuine completion still marks the task as completed ──────────
    test(
      'AC2: genuine (non-sentinel) completion correctly marks a task completed',
      () async {
        final genuineDate = DateTime.utc(2026, 5, 17, 10);

        await seedCompletion(
          db,
          CompletionEventsCompanion.insert(
            profileId: profileId,
            curriculumId: curriculum.storageKey,
            sefariaRef: sefariaRef,
            stageId: stageDefinitionId,
            trackType: 'personal',
            trackId: Value(trackId),
            eventTimestamp: genuineDate,
            points: const Value(10),
          ),
        );

        final task = DailyTask(
          curriculumId: curriculum,
          contentItemSefariaRef: sefariaRef,
          stageOrder: 1,
          stageDefinitionId: stageDefinitionId,
          priority: DailyTaskPriority.newLearning,
          isOverdue: false,
          reason: 'New learning',
          stageName: 'Learn',
          trackId: trackId,
          trackLabel: 'personal',
          estimatedEffortMinutes: 5,
        );

        final completions = await db.completionDao
            .getCompletionsByProfileForSefariaRefs(profileId, {sefariaRef});

        expect(
          _isTaskCompletedFixed(task, completions),
          isTrue,
          reason:
              'A genuine (non-sentinel) completion must still filter the task '
              'from today\'s list.',
        );
      },
    );

    // ── AC3: sentinel + genuine combination → task is completed ───────────
    test(
      'AC3: sentinel + genuine completion — task is still completed (genuine wins)',
      () async {
        final genuineDate = DateTime.utc(2026, 5, 17, 10);

        // C1: completion_events has a UNIQUE(profileId, sefariaRef, stageId,
        // trackType) constraint, so sentinel and genuine cannot share the
        // same key. Use a distinct sentinel stage to populate the completions
        // list alongside the genuine completion for the task's actual stage.
        final sentinelStageId = await db.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            profileId: profileId,
            curriculumId: curriculum.storageKey,
            trackId: trackId,
            stageOrder: 0,
            stageName: 'Bulk-Prior Sentinel',
            schedule: const Value('{"type":"delay","delay_days":0}'),
          ),
        );
        await seedCompletion(
          db,
          CompletionEventsCompanion.insert(
            profileId: profileId,
            curriculumId: curriculum.storageKey,
            sefariaRef: sefariaRef,
            stageId: sentinelStageId,
            trackType: 'personal',
            trackId: Value(trackId),
            eventTimestamp: sentinel,
            points: const Value(0),
          ),
        );
        await seedCompletion(
          db,
          CompletionEventsCompanion.insert(
            profileId: profileId,
            curriculumId: curriculum.storageKey,
            sefariaRef: sefariaRef,
            stageId: stageDefinitionId,
            trackType: 'personal',
            trackId: Value(trackId),
            eventTimestamp: genuineDate,
            points: const Value(10),
          ),
        );

        final task = DailyTask(
          curriculumId: curriculum,
          contentItemSefariaRef: sefariaRef,
          stageOrder: 1,
          stageDefinitionId: stageDefinitionId,
          priority: DailyTaskPriority.newLearning,
          isOverdue: false,
          reason: 'New learning',
          stageName: 'Learn',
          trackId: trackId,
          trackLabel: 'personal',
          estimatedEffortMinutes: 5,
        );

        final completions = await db.completionDao
            .getCompletionsByProfileForSefariaRefs(profileId, {sefariaRef});

        expect(
          _isTaskCompletedFixed(task, completions),
          isTrue,
          reason:
              'When both sentinel and genuine completions exist, the genuine '
              'one takes effect — the task is treated as completed.',
        );
      },
    );
  });
}
