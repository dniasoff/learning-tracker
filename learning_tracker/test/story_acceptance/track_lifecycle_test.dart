/// Comprehensive track lifecycle tests.
///
/// Covers the full track lifecycle — creation, backfill, overdue detection,
/// progress metrics, delete, restore — and the interactions between them.
/// Each group tests one invariant cluster; together they form the regression
/// net for track-lifecycle correctness.
///
/// Test groups:
///   A — Backfill: elapsed days produce the right snapshot rows
///   B — Track delete + restore
///   C — Overdue detection via prior-day snapshot refs
///   D — Progress metrics: completion count and distinct-ref agreement
///   E — Multi-track and multi-profile isolation
@Tags(['track_lifecycle'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/daily_plan_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart';

// ── Shared helpers ────────────────────────────────────────────────────────────

/// Insert a completion row via the event log (C1 canonical write path).
Future<void> _addCompletion(
  UserDatabase db, {
  required int profileId,
  required int trackId,
  required String sefariaRef,
  CurriculumId curriculum = CurriculumId.mishnayos,
  int stageId = 1,
  DateTime? completedAt,
}) => seedCompletion(
  db,
  CompletionsCompanion.insert(
    profileId: profileId,
    curriculumId: curriculum.storageKey,
    sefariaRef: sefariaRef,
    stageId: stageId,
    trackType: TrackType.personal.storageKey,
    trackId: trackId,
    completedAt: completedAt ?? DateTimeFactory.nowUtc(),
  ),
);

/// Build a one-item [DailyTask] for the given [sefariaRef] and [trackId].
DailyTask _makeTask(String sefariaRef, int trackId) => DailyTask(
  curriculumId: CurriculumId.mishnayos,
  contentItemSefariaRef: sefariaRef,
  stageOrder: 1,
  stageDefinitionId: 1,
  priority: DailyTaskPriority.overdueNewLearning,
  isOverdue: false,
  reason: 'test',
  stageName: 'Learn',
  trackId: trackId,
  trackLabel: 'Test',
);

/// Run [DailyPlanRepository.backfillMissingSnapshots] with one task per day.
///
/// Each day's task has sefariaRef = 'Ref {dayIndex}' so refs are distinct
/// per day and counts are predictable.
Future<int> _backfill(
  UserDatabase db, {
  required int profileId,
  required int trackId,
  required DateTime activatedAt,
  required DateTime currentDate,
}) async {
  final repo = DailyPlanRepository(db);
  var callCount = 0;
  await repo.backfillMissingSnapshots(
    profileId: profileId,
    trackId: trackId,
    activatedAt: activatedAt,
    currentDate: currentDate,
    buildSnapshotForDay: ({required dayIndex, required planDate}) async {
      callCount++;
      return [_makeTask('Ref $dayIndex', trackId)];
    },
  );
  return callCount;
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── A — Backfill: elapsed days produce the right snapshot rows ─────────────

  group(
    'A: Backfill — elapsed days produce correct snapshot rows',
    tags: ['track_lifecycle'],
    () {
      late UserDatabase db;
      const profileId = 1;

      setUp(() async {
        db = inMemoryDb();
        await seedProfile(db);
      });
      tearDown(() => db.close());

      test('0 elapsed days (activatedAt = today) → 0 backfill calls', () async {
        final today = DateTime.utc(2026, 5, 17);
        final trackId = await db.into(db.curriculumTracks).insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackType: TrackType.personal.storageKey,
            isActive: const Value(true),
            activatedAt: today,
          ),
        );

        final calls = await _backfill(
          db,
          profileId: profileId,
          trackId: trackId,
          activatedAt: today,
          currentDate: today,
        );

        expect(calls, 0, reason: 'no prior days to fill when track is brand new today');
        final rows = await db.dailyPlanDao.getPlanForDay(
          profileId: profileId,
          planDate: today,
        );
        expect(rows, isEmpty, reason: 'backfill does not write today\'s row');
      });

      test('3 elapsed days → 3 backfill calls, 3 distinct plan rows', () async {
        final today = DateTime.utc(2026, 5, 17);
        final threeDaysAgo = today.subtract(const Duration(days: 3));
        final trackId = await db.into(db.curriculumTracks).insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackType: TrackType.personal.storageKey,
            isActive: const Value(true),
            activatedAt: threeDaysAgo,
          ),
        );

        final calls = await _backfill(
          db,
          profileId: profileId,
          trackId: trackId,
          activatedAt: threeDaysAgo,
          currentDate: today,
        );

        expect(calls, 3, reason: '3 days elapsed → 3 snapshot calls');

        // Each prior day has exactly one plan row.
        // backfillMissingSnapshots stores rows keyed by LOCAL-date midnight
        // (DateUtils.extractLocalDate), so queries must use the same basis.
        final startDay = DateUtils.extractLocalDate(threeDaysAgo);
        for (var d = 0; d < 3; d++) {
          final planDate = startDay.add(Duration(days: d));
          final rows = await db.dailyPlanDao.getPlanForDay(
            profileId: profileId,
            planDate: planDate,
          );
          expect(
            rows,
            hasLength(1),
            reason: 'day $d (${planDate.toIso8601String()}) must have 1 plan row',
          );
        }
      });

      test('7 elapsed days → 7 backfill calls', () async {
        final today = DateTime.utc(2026, 5, 17);
        final sevenAgo = today.subtract(const Duration(days: 7));
        final trackId = await db.into(db.curriculumTracks).insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackType: TrackType.personal.storageKey,
            isActive: const Value(true),
            activatedAt: sevenAgo,
          ),
        );

        final calls = await _backfill(
          db,
          profileId: profileId,
          trackId: trackId,
          activatedAt: sevenAgo,
          currentDate: today,
        );

        expect(calls, 7);
      });

      test('backfill is idempotent — re-running does not duplicate rows', () async {
        final today = DateTime.utc(2026, 5, 17);
        final twoDaysAgo = today.subtract(const Duration(days: 2));
        final trackId = await db.into(db.curriculumTracks).insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackType: TrackType.personal.storageKey,
            isActive: const Value(true),
            activatedAt: twoDaysAgo,
          ),
        );

        // First backfill: 2 calls.
        final first = await _backfill(
          db,
          profileId: profileId,
          trackId: trackId,
          activatedAt: twoDaysAgo,
          currentDate: today,
        );
        expect(first, 2);

        // Second backfill: 0 calls (all days already have rows).
        final second = await _backfill(
          db,
          profileId: profileId,
          trackId: trackId,
          activatedAt: twoDaysAgo,
          currentDate: today,
        );
        expect(
          second,
          0,
          reason: 'idempotent: existing rows block the builder from being called again',
        );
      });

      test('backfill advances day-by-day — count grows with current date', () async {
        final base = DateTime.utc(2026, 5, 10); // day 0
        final trackId = await db.into(db.curriculumTracks).insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackType: TrackType.personal.storageKey,
            isActive: const Value(true),
            activatedAt: base,
          ),
        );

        // Simulate the app being opened on 3 successive days.
        for (var day = 1; day <= 3; day++) {
          final today = base.add(Duration(days: day));
          final calls = await _backfill(
            db,
            profileId: profileId,
            trackId: trackId,
            activatedAt: base,
            currentDate: today,
          );
          // Each successive day adds exactly 1 new snapshot (prior days already exist).
          expect(
            calls,
            1,
            reason: 'day $day: only the new prior day is backfilled; '
                'previous days are already snapshotted',
          );
        }
      });
    },
  );

  // ── B — Track delete + restore ─────────────────────────────────────────────

  group(
    'B: Track delete + restore',
    tags: ['track_lifecycle'],
    () {
      late UserDatabase db;
      const profileId = 1;

      setUp(() async {
        db = inMemoryDb();
        await seedProfile(db);
      });
      tearDown(() => db.close());

      test('soft-deleted track is absent from active-tracks query', () async {
        final trackId = await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );

        await db.trackDao.deleteTrackAndData(trackId);

        final active = await db.trackDao.getActiveTracksForProfile(profileId);
        expect(
          active.any((t) => t.id == trackId),
          isFalse,
          reason: 'soft-deleted track must not appear in active-tracks query',
        );
      });

      test('restore makes track active again with deletedAt = null', () async {
        final trackId = await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );
        await db.trackDao.deleteTrackAndData(trackId);

        await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );

        final track = await db.trackDao.getTrackById(trackId);
        expect(track!.isActive, isTrue);
        expect(track.deletedAt, isNull);
      });

      test('restore resets activatedAt to now (new learning session) (N5)', () async {
        final originalActivatedAt = DateTime.utc(2026, 5, 10);
        final trackId = await db.into(db.curriculumTracks).insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackType: TrackType.personal.storageKey,
            isActive: const Value(true),
            activatedAt: originalActivatedAt,
          ),
        );

        await db.trackDao.deleteTrackAndData(trackId);
        await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );

        final restored = await db.trackDao.getTrackById(trackId);
        // activatedAt must be reset to now — the new session boundary.
        // Pre-restore completions (completedAt = 2026-05-10) will predate it.
        expect(
          restored!.activatedAt.isAfter(originalActivatedAt),
          isTrue,
          reason: 'N5: restore must reset activatedAt to now so the current '
              'learning cycle starts fresh and pre-restore completions are '
              'excluded from current-session progress',
        );
      });

      test('restore preserves pre-delete completions for lifetime; '
          'current session starts at 0 (N4)', () async {
        final trackId = await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );
        await _addCompletion(
          db,
          profileId: profileId,
          trackId: trackId,
          sefariaRef: 'Berakhot 1:1',
          completedAt: DateTime.utc(2026, 5, 1), // clearly in the past
        );
        expect(
          await db.completionDao.getAggregateCountByProfile(
            CurriculumId.mishnayos.storageKey,
            profileId,
          ),
          1,
        );

        await db.trackDao.deleteTrackAndData(trackId);
        await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );

        final restored = await db.trackDao.getTrackById(trackId);

        // Lifetime count preserved.
        expect(
          await db.completionDao.getAggregateCountByProfile(
            CurriculumId.mishnayos.storageKey,
            profileId,
          ),
          1,
          reason: 'pre-restore completions survive for lifetime stats',
        );

        // Current-session count = 0 (pre-restore completedAt < new activatedAt).
        final session = await db.completionDao.getCompletionsByTrackAndProfileSince(
          trackId,
          profileId,
          restored!.activatedAt,
        );
        expect(
          session,
          isEmpty,
          reason: 'current session starts at 0 — pre-restore completions '
              'predate the new activatedAt',
        );
      });

      test('deleteTrackAndData removes daily-plan rows; restore allows re-backfill', () async {
        final today = DateTime.utc(2026, 5, 17);
        final threeDaysAgo = today.subtract(const Duration(days: 3));

        final trackId = await db.into(db.curriculumTracks).insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackType: TrackType.personal.storageKey,
            isActive: const Value(true),
            activatedAt: threeDaysAgo,
          ),
        );

        // Initial backfill: 3 rows written.
        await _backfill(
          db,
          profileId: profileId,
          trackId: trackId,
          activatedAt: threeDaysAgo,
          currentDate: today,
        );

        // Soft-delete removes the daily-plan rows.
        await db.trackDao.deleteTrackAndData(trackId);
        final plansAfterDelete = await (db.select(db.dailyPlans)
              ..where((t) => t.trackId.equals(trackId)))
            .get();
        expect(
          plansAfterDelete,
          isEmpty,
          reason: 'deleteTrackAndData must wipe daily-plan snapshot rows',
        );

        // Restore — activatedAt resets to now (new session), but the backfill
        // helper is called with the original threeDaysAgo explicitly, simulating
        // a caller that knows the prior content scope. 3 fresh rows expected.
        await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );
        final calls = await _backfill(
          db,
          profileId: profileId,
          trackId: trackId,
          activatedAt: threeDaysAgo,
          currentDate: today,
        );

        expect(
          calls,
          3,
          reason: 'after restore, daily-plan rows were wiped so backfill '
              'regenerates the 3 prior-day snapshots',
        );
      });

      test('completions on an unrelated track are unaffected by delete+restore '
          'of a different track', () async {
        final trackA = await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );
        final trackB = await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnaBerurah,
          trackType: TrackType.personal,
        );

        // Use a past timestamp so it clearly predates any restore activatedAt.
        await _addCompletion(
          db,
          profileId: profileId,
          trackId: trackA,
          sefariaRef: 'Berakhot 1:1',
          curriculum: CurriculumId.mishnayos,
          completedAt: DateTime.utc(2026, 5, 1),
        );
        await _addCompletion(
          db,
          profileId: profileId,
          trackId: trackB,
          sefariaRef: 'OC 1:1',
          curriculum: CurriculumId.mishnaBerurah,
        );

        // Delete and restore track A.
        await db.trackDao.deleteTrackAndData(trackA);
        await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );

        final restoredA = await db.trackDao.getTrackById(trackA);

        // Track B's completion must be untouched.
        expect(
          await db.completionDao.getAggregateCountByProfile(
            CurriculumId.mishnaBerurah.storageKey,
            profileId,
          ),
          1,
          reason: 'track B completions must survive track A delete+restore',
        );
        // Track A: lifetime count preserved (completion survives restore).
        expect(
          await db.completionDao.getAggregateCountByProfile(
            CurriculumId.mishnayos.storageKey,
            profileId,
          ),
          1,
          reason: 'track A lifetime completion is preserved after restore',
        );
        // Track A: current session = 0 (pre-restore completion predates activatedAt).
        final sessionA = await db.completionDao.getCompletionsByTrackAndProfileSince(
          trackA,
          profileId,
          restoredA!.activatedAt,
        );
        expect(
          sessionA,
          isEmpty,
          reason: 'track A current session starts fresh after restore',
        );
      });
    },
  );

  // ── C — Overdue detection via prior-day snapshot refs ─────────────────────

  group(
    'C: Overdue detection — prior-day snapshot refs',
    tags: ['track_lifecycle'],
    () {
      late UserDatabase db;
      const profileId = 1;

      setUp(() async {
        db = inMemoryDb();
        await seedProfile(db);
      });
      tearDown(() => db.close());

      test('no backfill → getPriorlyShownRefsForTrack returns empty set', () async {
        final today = DateTime.utc(2026, 5, 17);
        final trackId = await db.into(db.curriculumTracks).insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackType: TrackType.personal.storageKey,
            isActive: const Value(true),
            activatedAt: today,
          ),
        );

        final overdue = await db.dailyPlanDao.getPriorlyShownRefsForTrack(
          trackId: trackId,
          excludeDate: today,
        );
        expect(overdue, isEmpty);
      });

      test('3-day backfill → 3 distinct refs in priorlyShownRefs', () async {
        final today = DateTime.utc(2026, 5, 17);
        final threeDaysAgo = today.subtract(const Duration(days: 3));
        final trackId = await db.into(db.curriculumTracks).insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackType: TrackType.personal.storageKey,
            isActive: const Value(true),
            activatedAt: threeDaysAgo,
          ),
        );

        await _backfill(
          db,
          profileId: profileId,
          trackId: trackId,
          activatedAt: threeDaysAgo,
          currentDate: today,
        );

        final priorRefs = await db.dailyPlanDao.getPriorlyShownRefsForTrack(
          trackId: trackId,
          excludeDate: today,
        );

        expect(
          priorRefs,
          hasLength(3),
          reason: 'each of the 3 prior days contributed one unique ref; '
              'all 3 are candidates for overdue-new-learning detection',
        );
        expect(priorRefs, containsAll(['Ref 0', 'Ref 1', 'Ref 2']));
      });

      test('overdue refs grow day-by-day as track ages', () async {
        final base = DateTime.utc(2026, 5, 10);
        final trackId = await db.into(db.curriculumTracks).insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackType: TrackType.personal.storageKey,
            isActive: const Value(true),
            activatedAt: base,
          ),
        );

        for (var day = 1; day <= 5; day++) {
          final today = base.add(Duration(days: day));
          await _backfill(
            db,
            profileId: profileId,
            trackId: trackId,
            activatedAt: base,
            currentDate: today,
          );

          final priorRefs = await db.dailyPlanDao.getPriorlyShownRefsForTrack(
            trackId: trackId,
            excludeDate: today,
          );

          expect(
            priorRefs.length,
            day,
            reason: 'after $day elapsed days there should be $day prior refs',
          );
        }
      });

      test('completing a ref removes it from uncompleted overdue (scheduler logic)', () async {
        final today = DateTime.utc(2026, 5, 17);
        final twoDaysAgo = today.subtract(const Duration(days: 2));
        final trackId = await db.into(db.curriculumTracks).insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackType: TrackType.personal.storageKey,
            isActive: const Value(true),
            activatedAt: twoDaysAgo,
          ),
        );

        await _backfill(
          db,
          profileId: profileId,
          trackId: trackId,
          activatedAt: twoDaysAgo,
          currentDate: today,
        );

        // Prior refs before any completions: {Ref 0, Ref 1}.
        final priorRefs = await db.dailyPlanDao.getPriorlyShownRefsForTrack(
          trackId: trackId,
          excludeDate: today,
        );
        expect(priorRefs, hasLength(2));

        // Mark 'Ref 0' as completed.
        await _addCompletion(
          db,
          profileId: profileId,
          trackId: trackId,
          sefariaRef: 'Ref 0',
        );

        // The scheduler determines overdue as: priorRefs - completedRefs.
        final completions = await db.completionDao.getCompletionsByTrackAndProfile(
          trackId,
          profileId,
        );
        final completedRefs = completions.map((c) => c.sefariaRef).toSet();
        final stillOverdue = priorRefs.difference(completedRefs);

        expect(
          stillOverdue,
          {'Ref 1'},
          reason: 'Ref 0 was completed so only Ref 1 remains overdue',
        );
      });

      test('delete+restore re-runs backfill and restores overdue set', () async {
        final today = DateTime.utc(2026, 5, 17);
        final threeDaysAgo = today.subtract(const Duration(days: 3));

        final trackId = await db.into(db.curriculumTracks).insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackType: TrackType.personal.storageKey,
            isActive: const Value(true),
            activatedAt: threeDaysAgo,
          ),
        );

        // Initial backfill → 3 prior refs.
        await _backfill(
          db,
          profileId: profileId,
          trackId: trackId,
          activatedAt: threeDaysAgo,
          currentDate: today,
        );

        // Delete + restore.
        await db.trackDao.deleteTrackAndData(trackId);
        await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );

        // Re-backfill after restore (daily_plans were wiped by deleteTrackAndData).
        await _backfill(
          db,
          profileId: profileId,
          trackId: trackId,
          activatedAt: threeDaysAgo,
          currentDate: today,
        );

        final priorRefs = await db.dailyPlanDao.getPriorlyShownRefsForTrack(
          trackId: trackId,
          excludeDate: today,
        );

        expect(
          priorRefs,
          hasLength(3),
          reason: 'after delete+restore+backfill, all 3 prior overdue refs '
              'are present again because activatedAt was preserved',
        );
      });
    },
  );

  // ── D — Progress metrics ───────────────────────────────────────────────────

  group(
    'D: Progress metrics — completion count and distinct-ref agreement',
    tags: ['track_lifecycle'],
    () {
      late UserDatabase db;
      const profileId = 1;

      setUp(() async {
        db = inMemoryDb();
        await seedProfile(db);
      });
      tearDown(() => db.close());

      test('0 completions → count = 0', () async {
        await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );
        expect(
          await db.completionDao.getAggregateCountByProfile(
            CurriculumId.mishnayos.storageKey,
            profileId,
          ),
          0,
        );
      });

      test('same ref at 2 stages → count = 1 (distinct)', () async {
        final trackId = await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );
        await _addCompletion(
          db,
          profileId: profileId,
          trackId: trackId,
          sefariaRef: 'Berakhot 1:1',
          stageId: 1,
        );
        await _addCompletion(
          db,
          profileId: profileId,
          trackId: trackId,
          sefariaRef: 'Berakhot 1:1',
          stageId: 2,
        );

        final count = await db.completionDao.getAggregateCountByProfile(
          CurriculumId.mishnayos.storageKey,
          profileId,
        );
        expect(
          count,
          1,
          reason: 'completing the same ref twice (different stages) counts '
              'as 1 distinct item — not 2 raw rows (R5 / N6)',
        );
      });

      test('3 distinct refs → count = 3', () async {
        final trackId = await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );
        for (final ref in ['Berakhot 1:1', 'Berakhot 1:2', 'Berakhot 1:3']) {
          await _addCompletion(
            db,
            profileId: profileId,
            trackId: trackId,
            sefariaRef: ref,
          );
        }

        expect(
          await db.completionDao.getAggregateCountByProfile(
            CurriculumId.mishnayos.storageKey,
            profileId,
          ),
          3,
        );
      });

      test('delete + restore: lifetime count preserved; session count = 0 (N4)', () async {
        final trackId = await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );
        for (final ref in ['Berakhot 1:1', 'Berakhot 1:2']) {
          await _addCompletion(
            db,
            profileId: profileId,
            trackId: trackId,
            sefariaRef: ref,
            completedAt: DateTime.utc(2026, 5, 1), // clearly in the past
          );
        }
        expect(
          await db.completionDao.getAggregateCountByProfile(
            CurriculumId.mishnayos.storageKey,
            profileId,
          ),
          2,
        );

        await db.trackDao.deleteTrackAndData(trackId);
        await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );

        final restored = await db.trackDao.getTrackById(trackId);

        // Lifetime: pre-restore completions still count.
        expect(
          await db.completionDao.getAggregateCountByProfile(
            CurriculumId.mishnayos.storageKey,
            profileId,
          ),
          2,
          reason: 'lifetime count must be preserved after restore',
        );

        // Current session: 0 — all pre-restore completions predate activatedAt.
        final session = await db.completionDao.getCompletionsByTrackAndProfileSince(
          trackId,
          profileId,
          restored!.activatedAt,
        );
        expect(
          session,
          isEmpty,
          reason: 'current session starts at 0 after restore',
        );
      });

      test('getAggregateCountByProfile is scoped to one curriculum', () async {
        final trackMishna = await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );
        final trackMB = await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnaBerurah,
          trackType: TrackType.personal,
        );

        await _addCompletion(
          db,
          profileId: profileId,
          trackId: trackMishna,
          sefariaRef: 'Berakhot 1:1',
          curriculum: CurriculumId.mishnayos,
        );
        await _addCompletion(
          db,
          profileId: profileId,
          trackId: trackMB,
          sefariaRef: 'OC 1:1',
          curriculum: CurriculumId.mishnaBerurah,
        );
        await _addCompletion(
          db,
          profileId: profileId,
          trackId: trackMB,
          sefariaRef: 'OC 1:2',
          curriculum: CurriculumId.mishnaBerurah,
        );

        expect(
          await db.completionDao.getAggregateCountByProfile(
            CurriculumId.mishnayos.storageKey,
            profileId,
          ),
          1,
          reason: 'mishnayos count must not include mishnaBerurah completions',
        );
        expect(
          await db.completionDao.getAggregateCountByProfile(
            CurriculumId.mishnaBerurah.storageKey,
            profileId,
          ),
          2,
        );
      });

      test('track-level completion query matches curriculum-level for single-track curriculum', () async {
        final trackId = await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );
        for (final ref in ['Berakhot 1:1', 'Berakhot 1:2', 'Berakhot 1:3']) {
          await _addCompletion(
            db,
            profileId: profileId,
            trackId: trackId,
            sefariaRef: ref,
          );
        }

        final byTrack = await db.completionDao.getCompletionsByTrackAndProfile(
          trackId,
          profileId,
        );
        final byCurriculum = await db.completionDao.getAggregateCountByProfile(
          CurriculumId.mishnayos.storageKey,
          profileId,
        );

        expect(byTrack.map((c) => c.sefariaRef).toSet().length, byCurriculum);
      });
    },
  );

  // ── E — Multi-track and multi-profile isolation ────────────────────────────

  group(
    'E: Multi-track and multi-profile isolation',
    tags: ['track_lifecycle'],
    () {
      late UserDatabase db;

      setUp(() async {
        db = inMemoryDb();
        await seedProfile(db);
        // Seed a second profile so profileId=2 completions satisfy FK.
        await db.into(db.learnerProfiles).insert(
          LearnerProfilesCompanion.insert(
            accountId: 1,
            displayName: 'Test User 2',
            mode: 'adult',
            createdAt: DateTimeFactory.nowUtc(),
            updatedAt: DateTimeFactory.nowUtc(),
          ),
        );
      });
      tearDown(() => db.close());

      test('two profiles have independent completion counts', () async {
        const profile1 = 1;
        const profile2 = 2;

        final track1 = await db.trackDao.restoreOrCreate(
          profileId: profile1,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );
        final track2 = await db.trackDao.restoreOrCreate(
          profileId: profile2,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );

        // Profile 1: 3 completions.
        for (var i = 1; i <= 3; i++) {
          await _addCompletion(
            db,
            profileId: profile1,
            trackId: track1,
            sefariaRef: 'Berakhot 1:$i',
          );
        }
        // Profile 2: 1 completion.
        await _addCompletion(
          db,
          profileId: profile2,
          trackId: track2,
          sefariaRef: 'Berakhot 1:1',
        );

        expect(
          await db.completionDao.getAggregateCountByProfile(
            CurriculumId.mishnayos.storageKey,
            profile1,
          ),
          3,
        );
        expect(
          await db.completionDao.getAggregateCountByProfile(
            CurriculumId.mishnayos.storageKey,
            profile2,
          ),
          1,
          reason: 'profile 2 must not see profile 1\'s completions',
        );
      });

      test('backfill rows are isolated per track — different tracks same day', () async {
        final today = DateTime.utc(2026, 5, 17);
        final yesterday = today.subtract(const Duration(days: 1));
        const profileId = 1;

        final trackA = await db.into(db.curriculumTracks).insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackType: TrackType.personal.storageKey,
            isActive: const Value(true),
            activatedAt: yesterday,
          ),
        );
        final trackB = await db.into(db.curriculumTracks).insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: CurriculumId.mishnaBerurah.storageKey,
            trackType: TrackType.personal.storageKey,
            isActive: const Value(true),
            activatedAt: yesterday,
          ),
        );

        // Use track-specific ref prefixes so the ref strings are distinguishable
        // and the intersection is only non-empty if there is actual data leakage.
        final repo = DailyPlanRepository(db);
        await repo.backfillMissingSnapshots(
          profileId: profileId,
          trackId: trackA,
          activatedAt: yesterday,
          currentDate: today,
          buildSnapshotForDay: ({required dayIndex, required planDate}) async =>
              [_makeTask('A:Ref $dayIndex', trackA)],
        );
        await repo.backfillMissingSnapshots(
          profileId: profileId,
          trackId: trackB,
          activatedAt: yesterday,
          currentDate: today,
          buildSnapshotForDay: ({required dayIndex, required planDate}) async =>
              [_makeTask('B:Ref $dayIndex', trackB)],
        );

        final refsA = await db.dailyPlanDao.getPriorlyShownRefsForTrack(
          trackId: trackA,
          excludeDate: today,
        );
        final refsB = await db.dailyPlanDao.getPriorlyShownRefsForTrack(
          trackId: trackB,
          excludeDate: today,
        );

        expect(refsA, hasLength(1));
        expect(refsB, hasLength(1));
        expect(
          refsA.intersection(refsB),
          isEmpty,
          reason: 'each track\'s prior-ref set must be isolated — track A '
              'and track B are not cross-contaminated',
        );
      });

      test('restoreOrCreate creates separate rows per profile', () async {
        const profile1 = 1;
        const profile2 = 2;

        final id1 = await db.trackDao.restoreOrCreate(
          profileId: profile1,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );
        final id2 = await db.trackDao.restoreOrCreate(
          profileId: profile2,
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );

        expect(
          id1,
          isNot(equals(id2)),
          reason: 'different profiles must get separate track rows — the UNIQUE '
              'constraint is on (profileId, curriculumId, trackType)',
        );
      });
    },
  );
}
