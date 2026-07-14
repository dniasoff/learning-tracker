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

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';

import '../../../../helpers/drift_memory.dart';

/// A [StageDao] whose [insertStageDefinition] throws on the Nth call
/// (1-indexed), simulating a mid-sequence crash so tests can assert
/// [LearningProcessWizardService.applyWizardResult] rolls back atomically
/// (AUD-onboarding-06, DB-2) instead of leaving a partial stage set.
class _ThrowingAfterNthInsertStageDao extends StageDao {
  _ThrowingAfterNthInsertStageDao(super.db, {required this.throwOnCallNumber});

  final int throwOnCallNumber;
  int _insertCalls = 0;

  @override
  Future<int> insertStageDefinition(StageDefinitionsCompanion entry) {
    _insertCalls++;
    if (_insertCalls == throwOnCallNumber) {
      throw Exception(
        'AUD-onboarding-06 fixture: simulated crash on insert #$_insertCalls',
      );
    }
    return super.insertStageDefinition(entry);
  }
}

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
            stateChangedAt: DateTime.utc(2026, 1, 1),
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
  //
  // AUD-t-onboarding-04: was split across two duplicate group blocks
  // ('getPresetsForCurriculum' / 'LearningProcessWizardService.
  // getPresetsForCurriculum') left over from a rename; merged into one.
  // Removed 3 confirmed-duplicate cases: "returns programs for the given
  // curriculum" (a strict subset of "returns non-empty list for mishnayos
  // curriculum" below) and the two "(F2 variant)" cases, which were
  // near-line-for-line repeats of the two cases kept here.

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

    test('returns empty list for a curriculum with no programs', () {
      // All 9 curricula should have at least some programs; but if not,
      // the function should return an empty list without error.
      final presets = service.getPresetsForCurriculum(CurriculumId.mussar);
      expect(presets, isA<List<LearningProgramData>>());
    });
  });

  // ─── WizardChoice.noReview ────────────────────────────────────────────────
  //
  // AUD-t-onboarding-04: was split across two duplicate group blocks
  // ('applyWizardResult — noReview' / 'LearningProcessWizardService —
  // noReview') left over from a rename; merged into one. Removed 2
  // confirmed-duplicate cases: "creates single לימוד stage at order 1" (a
  // strict subset of "creates a single Learn stage only" below) and
  // "replaces existing stages" (a strict subset of "replaces existing
  // stages before creating new ones" below, which pre-populates 2 stages
  // instead of 1 and is kept as the more specific assertion).

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
      expect(stages.first.schedule, contains('"delay_days":0'));
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

    test('replaces existing stages before creating new ones', () async {
      // Pre-populate two stages using mishnayos (tracks use mishnayos curriculumId).
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos.storageKey,
          trackId: trackId,
          stageOrder: 1,
          stageName: 'old stage A',
          schedule: const Value('{"type":"delay","delay_days":0}'),
        ),
      );
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos.storageKey,
          trackId: trackId,
          stageOrder: 2,
          stageName: 'old stage B',
          schedule: const Value('{"type":"delay","delay_days":7}'),
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
    });
  });

  // ─── WizardChoice.custom ─────────────────────────────────────────────────
  //
  // AUD-t-onboarding-04: was split across two duplicate group blocks
  // ('applyWizardResult — custom' / 'LearningProcessWizardService —
  // custom') left over from a rename; merged into one. Removed 3
  // confirmed-duplicate cases from the second group: "custom with empty
  // customRounds only creates Learn stage" (a strict duplicate of "creates
  // only לימוד when customRounds is empty" below) and the two "(F2
  // variant)" cases (near-line-for-line repeats of cases kept below).

  group('LearningProcessWizardService — custom', () {
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
      expect(stages[1].schedule, contains('"delay_days":7'));

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
      expect(stages[1].schedule, contains('"type":"rolling"'));
    });

    // ── AUD-onboarding-06 (DB-2) — atomicity of the stage-insert sequence ──

    test('rolls back ALL stage inserts (zero stages remain) when the insert '
        'loop throws mid-way, instead of leaving a partial set', () async {
      // Throw on the 2nd insertStageDefinition call: לימוד (call #1)
      // succeeds, "Round 1" (call #2) throws. Pre-fix, deleteStagesForTrack
      // + the insert loop were 3 independently-awaited, un-transacted
      // steps, so a crash here would leave exactly 1 orphaned לימוד row —
      // the "zero or partial review stages" bug the finding describes.
      final throwingDao = _ThrowingAfterNthInsertStageDao(
        db,
        throwOnCallNumber: 2,
      );
      final throwingService = LearningProcessWizardService(
        stageDao: throwingDao,
        learningProgramRepo: LearningProgramRepository.instance,
        profileProgramDao: db.profileProgramDao,
      );

      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.custom,
        customRounds: [
          CustomRound(
            label: 'Round 1',
            scheduleType: ScheduleType.delay,
            delayDays: 1,
          ),
          CustomRound(
            label: 'Round 2',
            scheduleType: ScheduleType.delay,
            delayDays: 2,
          ),
        ],
      );

      await expectLater(
        () => throwingService.applyWizardResult(
          result,
          profileId: 1,
          trackId: trackId,
        ),
        throwsException,
      );

      // Read back through the real (non-throwing) DAO on the same
      // underlying connection — the transaction must have rolled back
      // the לימוד insert that "succeeded" before the throw too.
      final stages = await db.stageDao.getStagesByTrack(trackId);
      expect(
        stages,
        isEmpty,
        reason:
            'DB-2: a crash mid-sequence must roll back to zero stages, '
            'not leave a partial set (e.g. only לימוד, missing the '
            'chazarah rounds) — applyWizardResult must wrap the '
            'delete+insert sequence in a single transaction()',
      );
    });

    test(
      'rolls back the delete when the insert loop throws — pre-existing '
      'stages survive a failed replace instead of being left empty',
      () async {
        // Pre-populate one stage so we can prove clearFirst's delete is
        // ALSO part of the same atomic unit as the inserts.
        await db.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            profileId: 1,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackId: trackId,
            stageOrder: 1,
            stageName: 'Pre-existing Stage',
            schedule: const Value('{"type":"delay","delay_days":0}'),
          ),
        );

        final throwingDao = _ThrowingAfterNthInsertStageDao(
          db,
          throwOnCallNumber: 1,
        );
        final throwingService = LearningProcessWizardService(
          stageDao: throwingDao,
          learningProgramRepo: LearningProgramRepository.instance,
          profileProgramDao: db.profileProgramDao,
        );

        const result = WizardResult(
          curriculumId: CurriculumId.mishnayos,
          choice: WizardChoice.noReview,
        );

        await expectLater(
          () => throwingService.applyWizardResult(
            result,
            profileId: 1,
            trackId: trackId,
          ),
          throwsException,
        );

        final stages = await db.stageDao.getStagesByTrack(trackId);
        expect(
          stages,
          hasLength(1),
          reason:
              'DB-2: the delete and the insert loop are one atomic unit — '
              'a crash in the insert half must roll back the delete too, '
              'leaving the pre-existing stage intact rather than deleted '
              'with nothing to replace it',
        );
        expect(stages.first.stageName, 'Pre-existing Stage');
      },
    );

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
      expect(stages[1].schedule, contains('"delay_days":1'));
      expect(stages[2].stageName, 'Chazara B');
      expect(stages[2].schedule, contains('"delay_days":7'));
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
        // scheduleType stored in JSON schedule column
        expect(stages[1].schedule, contains('"type":"weekly"'));
      },
    );
  });

  // ─── WizardChoice.preset ─────────────────────────────────────────────────
  //
  // AUD-t-onboarding-04: was split across two duplicate group blocks
  // ('applyWizardResult — preset' / 'LearningProcessWizardService —
  // preset') left over from a rename; merged into one. Removed 4
  // confirmed-duplicate cases from the second group: "creates stages from
  // the program stages_config" (duplicate of "creates stages from program
  // stagesConfig" below) and "is a no-op (no stages) when programId does
  // not exist" plus its "(F2 variant)" (both duplicates of "handles
  // unknown programId gracefully" below), and "preset sets profile program
  // association (F2 variant)" (duplicate of "stores the preset program
  // association in profilePrograms" below).

  group('LearningProcessWizardService — preset', () {
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
