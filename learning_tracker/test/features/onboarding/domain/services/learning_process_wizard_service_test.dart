/// Tests for [LearningProcessWizardService].
///
/// Covers applyWizardResult with all three WizardChoice paths:
///   - noReview: single לימוד stage
///   - custom: לימוד + N custom chazarah rounds
///   - preset: stages from a program's stagesConfig
///
/// Also exercises:
///   - getPresetsForCurriculum
///   - _parseScheduleType / _parseDaysOfWeek (exercised via custom rounds)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/services/learning_program_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/stages/domain/models/schedule_type.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late UserDatabase db;
  late LearningProcessWizardService service;
  late int trackId;

  setUp(() async {
    db = createTestDatabase();
    service = LearningProcessWizardService(
      stageDao: db.stageDao,
      learningProgramRepo: LearningProgramRepository.instance,
      profileProgramDao: db.profileProgramDao,
    );

    // Create a minimal track to use as FK.
    final track = await db
        .into(db.curriculumTracks)
        .insertReturning(
          CurriculumTracksCompanion.insert(
            profileId: 0,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackType: 'personal',
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    trackId = track.id;
  });

  tearDown(() async {
    await db.close();
  });

  // ─── getPresetsForCurriculum ──────────────────────────────────────────────

  group('getPresetsForCurriculum', () {
    test('returns non-empty list for mishnayos curriculum', () {
      final presets = service.getPresetsForCurriculum(CurriculumId.mishnayos);
      expect(presets, isNotEmpty);
      for (final p in presets) {
        expect(p.curriculumType, CurriculumId.mishnayos.storageKey);
      }
    });

    test('all returned programs match the requested curriculum type', () {
      for (final curriculum in CurriculumId.values) {
        final presets = service.getPresetsForCurriculum(curriculum);
        for (final p in presets) {
          expect(p.curriculumType, curriculum.storageKey);
        }
      }
    });
  });

  // ─── WizardChoice.noReview ────────────────────────────────────────────────

  group('applyWizardResult — noReview', () {
    test('creates single לימוד stage at order 1', () async {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.noReview,
      );
      await service.applyWizardResult(
        result,
        profileId: 0,
        trackId: trackId,
      );

      final stages = await db.stageDao.getStagesByTrack(trackId);
      expect(stages.length, 1);
      expect(stages.first.stageName, 'לימוד');
      expect(stages.first.stageOrder, 1);
    });

    test('replaces existing stages when called twice', () async {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.noReview,
      );
      await service.applyWizardResult(result, profileId: 0, trackId: trackId);
      await service.applyWizardResult(result, profileId: 0, trackId: trackId);

      // Should still be exactly 1 stage (not doubled).
      final stages = await db.stageDao.getStagesByTrack(trackId);
      expect(stages.length, 1);
    });
  });

  // ─── WizardChoice.custom ─────────────────────────────────────────────────

  group('applyWizardResult — custom', () {
    test('creates לימוד + custom chazarah rounds', () async {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.custom,
        customRounds: [
          CustomRound(
            label: 'Chazarah 1',
            scheduleType: ScheduleType.delay,
            delayDays: 7,
          ),
          CustomRound(
            label: 'Chazarah 2',
            scheduleType: ScheduleType.weekly,
            daysOfWeek: [1, 3, 5],
          ),
        ],
      );

      await service.applyWizardResult(result, profileId: 0, trackId: trackId);

      final stages = await db.stageDao.getStagesByTrack(trackId);
      expect(stages.length, 3);

      // Sort by stageOrder for deterministic checks.
      stages.sort((a, b) => a.stageOrder.compareTo(b.stageOrder));

      expect(stages[0].stageName, 'לימוד');
      expect(stages[0].stageOrder, 1);

      expect(stages[1].stageName, 'Chazarah 1');
      expect(stages[1].stageOrder, 2);
      expect(stages[1].delayDays, 7);

      expect(stages[2].stageName, 'Chazarah 2');
      expect(stages[2].stageOrder, 3);
    });

    test('creates only לימוד when customRounds is empty', () async {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.custom,
        customRounds: [],
      );

      await service.applyWizardResult(result, profileId: 0, trackId: trackId);

      final stages = await db.stageDao.getStagesByTrack(trackId);
      expect(stages.length, 1);
      expect(stages.first.stageName, 'לימוד');
    });

    test('creates only לימוד when customRounds is null', () async {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.custom,
        customRounds: null,
      );

      await service.applyWizardResult(result, profileId: 0, trackId: trackId);

      final stages = await db.stageDao.getStagesByTrack(trackId);
      expect(stages.length, 1);
      expect(stages.first.stageName, 'לימוד');
    });

    test('rolling schedule type is stored correctly', () async {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.custom,
        customRounds: [
          CustomRound(
            label: 'Rolling',
            scheduleType: ScheduleType.rolling,
          ),
        ],
      );

      await service.applyWizardResult(result, profileId: 0, trackId: trackId);

      final stages = await db.stageDao.getStagesByTrack(trackId);
      stages.sort((a, b) => a.stageOrder.compareTo(b.stageOrder));
      expect(stages[1].scheduleType, ScheduleType.rolling.storageKey);
    });
  });

  // ─── WizardChoice.preset ─────────────────────────────────────────────────

  group('applyWizardResult — preset', () {
    test('creates stages from program stagesConfig', () async {
      final presets = service.getPresetsForCurriculum(CurriculumId.mishnayos);
      // Skip if no presets available for this curriculum.
      if (presets.isEmpty) return;

      final program = presets.first;
      final result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.preset,
        programId: program.id,
      );

      await service.applyWizardResult(result, profileId: 0, trackId: trackId);

      final stages = await db.stageDao.getStagesByTrack(trackId);
      // At minimum we expect a לימוד stage (order 1).
      expect(stages, isNotEmpty);
      stages.sort((a, b) => a.stageOrder.compareTo(b.stageOrder));
      expect(stages.first.stageOrder, 1);
    });

    test('handles unknown programId gracefully (creates no stages)', () async {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.preset,
        programId: 99999, // Non-existent
      );

      await service.applyWizardResult(result, profileId: 0, trackId: trackId);

      // With an unknown programId getProgramById returns null, so no stages.
      final stages = await db.stageDao.getStagesByTrack(trackId);
      expect(stages, isEmpty);
    });
  });

  // ─── WizardResult model ──────────────────────────────────────────────────

  group('WizardResult', () {
    test('preset result stores programId', () {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.preset,
        programId: 3,
      );
      expect(result.programId, 3);
      expect(result.choice, WizardChoice.preset);
    });

    test('custom result stores customRounds', () {
      const rounds = [
        CustomRound(label: 'R1', scheduleType: ScheduleType.delay, delayDays: 3),
      ];
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.custom,
        customRounds: rounds,
      );
      expect(result.customRounds!.length, 1);
      expect(result.customRounds!.first.label, 'R1');
    });
  });
}
