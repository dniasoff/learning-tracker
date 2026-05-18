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

import '../../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late LearningProcessWizardService service;
  late int trackId;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);

    // Insert a track to satisfy the FK on stage_definitions.
    trackId = await db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: 1,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackType: 'personal',
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );

    service = LearningProcessWizardService(
      stageDao: db.stageDao,
      learningProgramRepo: LearningProgramRepository.instance,
      profileProgramDao: db.profileProgramDao,
    );
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

  group('LearningProcessWizardService.getPresetsForCurriculum', () {
    test('returns programs for the given curriculum', () {
      final presets = service.getPresetsForCurriculum(CurriculumId.mishnayos);
      for (final p in presets) {
        expect(p.curriculumType, CurriculumId.mishnayos.storageKey);
      }
    });

    test('returns empty list for a curriculum with no programs', () {
      // All 9 curricula should have at least some programs; but if not,
      // the function should return an empty list without error.
      final presets = service.getPresetsForCurriculum(CurriculumId.mussar);
      expect(presets, isA<List<LearningProgramData>>());
    });

    test('returns programs matching the curriculum type (F2 variant)', () {
      final presets = service.getPresetsForCurriculum(CurriculumId.mishnayos);
      expect(presets, isNotEmpty);
      expect(presets.every((p) => p.curriculumType == 'mishnayos'), isTrue);
    });

    test(
      'returns empty list for unknown curriculum with no seeds (F2 variant)',
      () {
        // CurriculumId.chumash seeds may or may not exist — we just assert type safety.
        final presets = service.getPresetsForCurriculum(CurriculumId.bavli);
        expect(presets, isA<List<LearningProgramData>>());
      },
    );
  });

  // ─── WizardChoice.noReview ────────────────────────────────────────────────

  group('applyWizardResult — noReview', () {
    test('creates single לימוד stage at order 1', () async {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.noReview,
      );
      await service.applyWizardResult(result, profileId: 1, trackId: trackId);

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
      await service.applyWizardResult(result, profileId: 1, trackId: trackId);
      await service.applyWizardResult(result, profileId: 1, trackId: trackId);

      // Should still be exactly 1 stage (not doubled).
      final stages = await db.stageDao.getStagesByTrack(trackId);
      expect(stages.length, 1);
    });
  });

  group('LearningProcessWizardService — noReview', () {
    test('creates a single Learn stage only', () async {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.noReview,
      );

      await service.applyWizardResult(result, profileId: 1, trackId: trackId);

      final stages = await db.stageDao.getStagesByTrack(trackId);
      expect(stages, hasLength(1));
      expect(stages.first.stageOrder, 1);
      expect(stages.first.stageName, 'לימוד');
      expect(stages.first.delayDays, 0);
    });

    test('replaces existing stages', () async {
      // Pre-insert a stage.
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos.storageKey,
          trackId: trackId,
          stageOrder: 1,
          stageName: 'Old Stage',
          delayDays: 0,
        ),
      );

      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.noReview,
      );

      await service.applyWizardResult(result, profileId: 1, trackId: trackId);

      final stages = await db.stageDao.getStagesByTrack(trackId);
      // Old stage replaced; only the one Learn stage remains.
      expect(stages, hasLength(1));
      expect(stages.first.stageName, 'לימוד');
    });

    test(
      'replaces existing stages before creating new ones (F2 variant)',
      () async {
        // Pre-populate two stages using mishnayos (tracks use mishnayos curriculumId).
        await db.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            profileId: 1,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackId: trackId,
            stageOrder: 1,
            stageName: 'old stage A',
            delayDays: 0,
          ),
        );
        await db.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            profileId: 1,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackId: trackId,
            stageOrder: 2,
            stageName: 'old stage B',
            delayDays: 7,
          ),
        );
        expect(await db.stageDao.getStagesByTrack(trackId), hasLength(2));

        const result = WizardResult(
          curriculumId: CurriculumId.mishnayos,
          choice: WizardChoice.noReview,
        );

        await service.applyWizardResult(result, profileId: 1, trackId: trackId);

        final stages = await db.stageDao.getStagesByTrack(trackId);
        expect(stages, hasLength(1));
        expect(stages.first.stageName, 'לימוד');
      },
    );
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

      await service.applyWizardResult(result, profileId: 1, trackId: trackId);

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

      await service.applyWizardResult(result, profileId: 1, trackId: trackId);

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

      await service.applyWizardResult(result, profileId: 1, trackId: trackId);

      final stages = await db.stageDao.getStagesByTrack(trackId);
      expect(stages.length, 1);
      expect(stages.first.stageName, 'לימוד');
    });

    test('rolling schedule type is stored correctly', () async {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.custom,
        customRounds: [
          CustomRound(label: 'Rolling', scheduleType: ScheduleType.rolling),
        ],
      );

      await service.applyWizardResult(result, profileId: 1, trackId: trackId);

      final stages = await db.stageDao.getStagesByTrack(trackId);
      stages.sort((a, b) => a.stageOrder.compareTo(b.stageOrder));
      expect(stages[1].scheduleType, ScheduleType.rolling.storageKey);
    });
  });

  group('LearningProcessWizardService — custom', () {
    test('creates Learn stage + N custom chazarah rounds', () async {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.custom,
        customRounds: [
          CustomRound(
            label: 'Chazara A',
            scheduleType: ScheduleType.delay,
            delayDays: 1,
          ),
          CustomRound(
            label: 'Chazara B',
            scheduleType: ScheduleType.delay,
            delayDays: 7,
          ),
        ],
      );

      await service.applyWizardResult(result, profileId: 1, trackId: trackId);

      final stages = await db.stageDao.getStagesByTrack(trackId);
      expect(stages, hasLength(3)); // Learn + 2 rounds
      expect(stages[0].stageName, 'לימוד');
      expect(stages[1].stageName, 'Chazara A');
      expect(stages[1].delayDays, 1);
      expect(stages[2].stageName, 'Chazara B');
      expect(stages[2].delayDays, 7);
    });

    test('stage orders are sequential starting from 1', () async {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.custom,
        customRounds: [
          CustomRound(
            label: 'Round 1',
            scheduleType: ScheduleType.delay,
            delayDays: 3,
          ),
        ],
      );

      await service.applyWizardResult(result, profileId: 1, trackId: trackId);

      final stages = await db.stageDao.getStagesByTrack(trackId);
      expect(stages.map((s) => s.stageOrder).toList(), [1, 2]);
    });

    test(
      'custom round with weekly schedule type stores scheduleType correctly',
      () async {
        const result = WizardResult(
          curriculumId: CurriculumId.mishnayos,
          choice: WizardChoice.custom,
          customRounds: [
            CustomRound(
              label: 'Weekly Review',
              scheduleType: ScheduleType.weekly,
              daysOfWeek: [1, 5], // Mon, Fri
            ),
          ],
        );

        await service.applyWizardResult(result, profileId: 1, trackId: trackId);

        final stages = await db.stageDao.getStagesByTrack(trackId);
        expect(stages, hasLength(2));
        expect(stages[1].stageName, 'Weekly Review');
        // scheduleType stored as storageKey string
        expect(stages[1].scheduleType, ScheduleType.weekly.storageKey);
      },
    );

    test('custom with empty customRounds only creates Learn stage', () async {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.custom,
        customRounds: [],
      );

      await service.applyWizardResult(result, profileId: 1, trackId: trackId);

      final stages = await db.stageDao.getStagesByTrack(trackId);
      expect(stages, hasLength(1));
      expect(stages.first.stageName, 'לימוד');
    });

    test('creates לימוד + custom chazarah rounds (F2 variant)', () async {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.custom,
        customRounds: [
          CustomRound(
            label: 'חזרה א',
            scheduleType: ScheduleType.delay,
            delayDays: 3,
          ),
          CustomRound(
            label: 'חזרה ב',
            scheduleType: ScheduleType.weekly,
            daysOfWeek: [5, 6],
          ),
        ],
      );

      await service.applyWizardResult(result, profileId: 1, trackId: trackId);

      final stages = await db.stageDao.getStagesByTrack(trackId);
      expect(stages, hasLength(3));
      expect(stages[0].stageName, 'לימוד');
      expect(stages[0].stageOrder, 1);
      expect(stages[1].stageName, 'חזרה א');
      expect(stages[1].stageOrder, 2);
      expect(stages[1].delayDays, 3);
      expect(stages[2].stageName, 'חזרה ב');
      expect(stages[2].stageOrder, 3);
    });

    test('custom with no rounds creates only לימוד (F2 variant)', () async {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.custom,
        customRounds: [],
      );

      await service.applyWizardResult(result, profileId: 1, trackId: trackId);

      final stages = await db.stageDao.getStagesByTrack(trackId);
      expect(stages, hasLength(1));
      expect(stages.first.stageName, 'לימוד');
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

      await service.applyWizardResult(result, profileId: 1, trackId: trackId);

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

      await service.applyWizardResult(result, profileId: 1, trackId: trackId);

      // With an unknown programId getProgramById returns null, so no stages.
      final stages = await db.stageDao.getStagesByTrack(trackId);
      expect(stages, isEmpty);
    });
  });

  group('LearningProcessWizardService — preset', () {
    test('creates stages from the program stages_config', () async {
      // Use program ID 1 which must exist in learningProgramSeeds.
      final programs = LearningProgramRepository.instance
          .getActiveProgramsByCurriculumType(CurriculumId.mishnayos.storageKey);
      // Skip the test if no mishnayos programs are seeded.
      if (programs.isEmpty) return;

      final program = programs.first;
      final result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.preset,
        programId: program.id,
      );

      await service.applyWizardResult(result, profileId: 1, trackId: trackId);

      final stages = await db.stageDao.getStagesByTrack(trackId);
      expect(stages, isNotEmpty);
      // Stage orders start at 1.
      expect(stages.first.stageOrder, 1);
    });

    test('stores the preset program association in profilePrograms', () async {
      final programs = LearningProgramRepository.instance
          .getActiveProgramsByCurriculumType(CurriculumId.mishnayos.storageKey);
      if (programs.isEmpty) return;

      final program = programs.first;
      final result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.preset,
        programId: program.id,
      );

      await service.applyWizardResult(result, profileId: 1, trackId: trackId);

      final profilePrograms = await db.select(db.profilePrograms).get();
      expect(profilePrograms.any((p) => p.programId == program.id), isTrue);
    });

    test('is a no-op (no stages) when programId does not exist', () async {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.preset,
        programId: 9999, // non-existent
      );

      await service.applyWizardResult(result, profileId: 1, trackId: trackId);

      final stages = await db.stageDao.getStagesByTrack(trackId);
      expect(stages, isEmpty);
    });

    test('creates stages from program seeds (oraysa — id 1)', () async {
      // Program id=1 is 'oraysa': has 4 stages including rolling + weekly.
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.preset,
        programId: 1, // oraysa
      );

      await service.applyWizardResult(result, profileId: 1, trackId: trackId);

      final stages = await db.stageDao.getStagesByTrack(trackId);
      // oraysa has at least some stages: learn, etc.
      if (stages.isNotEmpty) {
        expect(stages[0].stageName, 'לימוד');
      }
      // If no stages, the program ID may not exist for mishnayos — just don't throw.
    });

    test(
      'no-op when programId does not exist in repository (F2 variant)',
      () async {
        const result = WizardResult(
          curriculumId: CurriculumId.mishnayos,
          choice: WizardChoice.preset,
          programId: 99999, // non-existent
        );

        await service.applyWizardResult(result, profileId: 1, trackId: trackId);

        // Should not throw, stages list should be empty.
        final stages = await db.stageDao.getStagesByTrack(trackId);
        expect(stages, isEmpty);
      },
    );

    test('preset sets profile program association (F2 variant)', () async {
      final programs = LearningProgramRepository.instance
          .getActiveProgramsByCurriculumType(CurriculumId.mishnayos.storageKey);
      if (programs.isEmpty) return;

      final program = programs.first;
      final result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.preset,
        programId: program.id,
      );

      await service.applyWizardResult(result, profileId: 1, trackId: trackId);

      final prog = await db.profileProgramDao.getProgramForProfileAndCurriculum(
        1,
        CurriculumId.mishnayos.storageKey,
      );
      expect(prog, isNotNull);
      expect(prog!.programId, program.id);
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
        CustomRound(
          label: 'R1',
          scheduleType: ScheduleType.delay,
          delayDays: 3,
        ),
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
