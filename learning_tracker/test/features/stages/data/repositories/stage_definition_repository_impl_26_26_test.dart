// Tests for story 26.26 (DNI-369) — updated for W4.10 ScheduleSpec API.
//
// AUD-tracks-12: the addStage/reorderStages/deleteStage/updateStage groups
// that used to live here were removed along with the (dead, zero-UI-caller)
// StageDefinitionRepository mutation methods they exercised — see the
// removal note on StageDefinitionRepositoryImpl. What remains is:
// - ScheduleSpec.fromParts reconstruction from raw DB columns
// - resetToDefaults cross-profile / cross-track isolation (R6-12 regression)
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/schedule_spec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

void main() {
  group('ScheduleSpec.fromParts — reconstruction', () {
    test('fromParts with delay key returns DelaySchedule', () {
      final spec = ScheduleSpec.fromParts(
        scheduleTypeKey: 'delay',
        delayDays: 7,
        daysOfWeek: null,
        rollingWindowSize: null,
      );
      expect(spec, const DelaySchedule(7));
    });

    test('fromParts with weekly key returns WeeklySchedule', () {
      final spec = ScheduleSpec.fromParts(
        scheduleTypeKey: 'weekly',
        delayDays: 0,
        daysOfWeek: [1, 5],
        rollingWindowSize: null,
      );
      expect(spec, WeeklySchedule([1, 5]));
    });

    test('fromParts with rolling key returns RollingSchedule', () {
      final spec = ScheduleSpec.fromParts(
        scheduleTypeKey: 'rolling',
        delayDays: 0,
        daysOfWeek: null,
        rollingWindowSize: 14,
      );
      expect(spec, RollingSchedule(14));
    });

    test('fromParts with unknown key falls back to DelaySchedule', () {
      final spec = ScheduleSpec.fromParts(
        scheduleTypeKey: 'unknown_legacy',
        delayDays: 3,
        daysOfWeek: null,
        rollingWindowSize: null,
      );
      expect(spec, const DelaySchedule(3));
    });
  });

  group('Firestore stage reset — profile isolation (R6-12)', () {
    const uid = 'stage-reset-uid';
    const profile1 = '01J6Q2H4A8M7K3P9R5T6V8WXYZ';
    const profile2 = '01J6Q2H4A8M7K3P9R5T6V8WXY0';
    const curriculum = CurriculumId.mishnayos;
    final firestore = createFakeFirestore(authenticatedUid: uid);

    test('resetting profile 1 curriculum does not affect profile 2', () async {
      final repo1 = FirestoreStageDefinitionRepository(
        firestore: firestore,
        uid: uid,
        profileId: profile1,
      );
      final repo2 = FirestoreStageDefinitionRepository(
        firestore: firestore,
        uid: uid,
        profileId: profile2,
      );

      await seedStageDefinitions(
        firestore,
        uid: uid,
        profileId: profile1,
        curriculumId: curriculum,
      );
      await seedStageDefinitions(
        firestore,
        uid: uid,
        profileId: profile2,
        curriculumId: curriculum,
      );

      await repo1.resetToDefaults(curriculum);

      expect(await repo1.getStagesForCurriculum(curriculum), hasLength(3));
      final profile2Stages = await repo2.getStagesForCurriculum(curriculum);
      expect(profile2Stages, hasLength(3));
      expect(profile2Stages.map((stage) => stage.stageOrder).toList(), [
        1,
        2,
        3,
      ]);
    });

    test(
      'different Drift track ids cannot be represented after AD-25',
      () async {},
      skip:
          'AD-25 makes curriculumId the sole Firestore track identity; '
          'there is no portable trackId-scoped stage collection to exercise.',
    );
  });
}
