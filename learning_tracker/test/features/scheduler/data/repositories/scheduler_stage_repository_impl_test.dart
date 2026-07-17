/// AUD-scheduler-11 (EH-3) regression test.
///
/// [SchedulerStageRepositoryImpl._rowToSchedulerStage] decodes the JSON
/// `schedule` column written by [StageDao]. Before this fix, a malformed
/// `schedule` value (migration bug, manual DB edit, a bad sync-merge write)
/// was silently swallowed by a log-less `catch (_)` and replaced with a
/// hardcoded `{'type': 'delay', 'delay_days': 0}` default — changing that
/// stage's chazara/review timing with zero diagnostic trail to explain a
/// future "my review schedule looks wrong" report.
///
/// Red -> Green:
///   BEFORE the fix: the catch block had no `AppLogger` call, so this test's
///   Talker-history assertion failed (RED) even though the fallback
///   `SchedulerStage` values were already correct.
///   AFTER the fix: the catch logs via
///   `AppLogger.instance.warning(event: 'scheduler_stage_malformed_schedule')`
///   with the stage row id and raw schedule string before falling back.
@Tags(['epic_6'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_stage_repository_impl.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';

import '../../../../helpers/test_database.dart';

const _malformedSchedule = '{{not valid json';

void main() {
  late UserDatabase db;
  late SchedulerStageRepositoryImpl repo;
  late int stageId;

  setUp(() async {
    // Fresh Talker per test so log history assertions never see a prior
    // test's entries (mirrors completion_repository_siyum_detection_failure_test.dart).
    AppLogger.init();

    db = createTestDatabase();
    await seedProfile(db);

    final trackRow = await db
        .into(db.curriculumTracks)
        .insertReturning(
          CurriculumTracksCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            stateChangedAt: DateTime.utc(2026, 1, 1),
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );

    stageId = await db.stageDao.insertStageDefinition(
      StageDefinitionsCompanion.insert(
        profileId: 1,
        curriculumId: 'mishnayos',
        trackId: trackRow.id,
        stageOrder: 0,
        stageName: 'Stage 1',
        // Directly insert malformed JSON into the schedule column,
        // bypassing the normal encode path -- simulates a migration bug,
        // manual DB edit, or bad sync-merge write.
        schedule: const Value(_malformedSchedule),
      ),
    );

    repo = SchedulerStageRepositoryImpl(stageDao: db.stageDao);
  });

  tearDown(() async => db.close());

  group('AUD-scheduler-11 — malformed schedule JSON is not silently lost', () {
    test(
      'getStages falls back to a delay(0) schedule when schedule JSON is malformed',
      () async {
        final stages = await repo.getStages(CurriculumId.mishnayos);

        expect(stages, hasLength(1));
        final stage = stages.single;
        expect(stage.id, stageId);
        expect(stage.delayDays, 0);
        expect(stage.scheduleType, ScheduleType.delay);
        expect(stage.daysOfWeek, isNull);
        expect(stage.rollingWindowSize, isNull);
      },
    );

    test('the malformed schedule fallback is logged via AppLogger with the row '
        'id and raw schedule string, not left silent', () async {
      await repo.getStages(CurriculumId.mishnayos);

      final history = AppLogger.instance.talker.history
          .map((e) => e.generateTextMessage())
          .toList();
      expect(
        history.any(
          (m) =>
              m.contains('scheduler_stage_malformed_schedule') &&
              m.contains(stageId.toString()) &&
              m.contains(_malformedSchedule),
        ),
        isTrue,
        reason:
            'Expected the malformed-schedule fallback to be logged via '
            'AppLogger (including the stage row id and raw schedule '
            'string) instead of silently defaulting to delay(0). Talker '
            'history: $history',
      );
    });
  });
}
