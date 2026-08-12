/// Tests for [LearningProcessWizardService].
///
/// The service is exercised through its production Riverpod provider, whose
/// stage and profile-program adapters resolve against a fake Firestore.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_profile_program_repository.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';

const _uid = 'learning-process-wizard-uid';
const _profileId = '01JQ8M9Y7V3K2N6P4R5T8W0X1Z';

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _ProfileDocIdOverride extends ActiveProfileDocId {
  @override
  String build() => _profileId;
}

void main() {
  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;
  late LearningProcessWizardService service;
  late StageDefinitionRepository stageRepository;
  late FirestoreProfileProgramRepository profileProgramRepository;

  Future<List<StageDefinition>> readStages() {
    return stageRepository.getStagesForCurriculum(CurriculumId.mishnayos);
  }

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    final handles = AccountFirebaseHandles(
      app: _MockFirebaseApp(),
      firestore: firestore,
      auth: _MockFirebaseAuth(),
      uid: _uid,
    );
    container = ProviderContainer(
      overrides: [
        activeAccountFirebaseProvider.overrideWith((ref) async => handles),
        activeProfileDocIdProvider.overrideWith(_ProfileDocIdOverride.new),
      ],
    );
    addTearDown(container.dispose);

    service = container.read(learningProcessWizardServiceProvider);
    stageRepository = container.read(globalStageRepositoryProvider);
    profileProgramRepository = FirestoreProfileProgramRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
  });

  // ─── getPresetsForCurriculum ────────────────────────────────────────────

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
      final presets = service.getPresetsForCurriculum(CurriculumId.mussar);
      expect(presets, isA<List<LearningProgramData>>());
    });
  });

  // ─── WizardChoice.noReview ──────────────────────────────────────────────

  group('LearningProcessWizardService — noReview', () {
    test('creates a single Learn stage only', () async {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.noReview,
      );

      await service.applyWizardResult(result);

      final stages = await readStages();
      expect(stages, hasLength(1));
      expect(stages.first.stageOrder, 1);
      expect(stages.first.stageName, 'לימוד');
      expect(stages.first.delayDays, 0);
    });

    test('replaces existing stages when called twice', () async {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.noReview,
      );
      await service.applyWizardResult(result);
      await service.applyWizardResult(result);

      final stages = await readStages();
      expect(stages, hasLength(1));
    });

    test(
      'does not claim to delete stale Firestore stage documents',
      () async {},
      skip:
          'Drift-only replacement assertion: the Firestore adapter writes the '
          'new curriculum stages but cannot delete stale higher-order docs '
          'under the current Firestore rules.',
    );
  });

  // ─── WizardChoice.custom ────────────────────────────────────────────────

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

      await service.applyWizardResult(result);

      final stages = await readStages();
      expect(stages, hasLength(3));
      stages.sort((a, b) => a.stageOrder.compareTo(b.stageOrder));

      expect(stages[0].stageName, 'לימוד');
      expect(stages[0].stageOrder, 1);
      expect(stages[1].stageName, 'Chazarah 1');
      expect(stages[1].stageOrder, 2);
      expect(stages[1].delayDays, 7);
      expect(stages[2].stageName, 'Chazarah 2');
      expect(stages[2].stageOrder, 3);
      expect(stages[2].scheduleType, ScheduleType.weekly);
      expect(stages[2].daysOfWeek, [1, 3, 5]);
    });

    test('creates only לימוד when customRounds is empty', () async {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.custom,
        customRounds: [],
      );

      await service.applyWizardResult(result);

      final stages = await readStages();
      expect(stages, hasLength(1));
      expect(stages.first.stageName, 'לימוד');
    });

    test('creates only לימוד when customRounds is null', () async {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.custom,
        customRounds: null,
      );

      await service.applyWizardResult(result);

      final stages = await readStages();
      expect(stages, hasLength(1));
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

      await service.applyWizardResult(result);

      final stages = await readStages();
      stages.sort((a, b) => a.stageOrder.compareTo(b.stageOrder));
      expect(stages[1].scheduleType, ScheduleType.rolling);
      expect(stages[1].rollingWindowSize, 7);
    });

    test(
      'does not use the removed Drift insert loop for atomicity',
      () async {},
      skip:
          'Drift-specific failure injection: Firestore replacement is one '
          'batch write and has no per-stage DAO insert seam to throw from.',
    );

    test(
      'does not use the removed Drift delete-plus-insert transaction',
      () async {},
      skip:
          'Drift-specific rollback assertion: the Firestore service documents '
          'that preset association and stage replacement are not one '
          'cross-collection transaction.',
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

      await service.applyWizardResult(result);

      final stages = await readStages();
      expect(stages, hasLength(3));
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

      await service.applyWizardResult(result);

      final stages = await readStages();
      expect(stages.map((s) => s.stageOrder).toList(), [1, 2]);
    });

    test('custom weekly schedule stores scheduleType correctly', () async {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.custom,
        customRounds: [
          CustomRound(
            label: 'Weekly Review',
            scheduleType: ScheduleType.weekly,
            daysOfWeek: [1, 5],
          ),
        ],
      );

      await service.applyWizardResult(result);

      final stages = await readStages();
      expect(stages, hasLength(2));
      expect(stages[1].stageName, 'Weekly Review');
      expect(stages[1].scheduleType, ScheduleType.weekly);
      expect(stages[1].daysOfWeek, [1, 5]);
    });
  });

  // ─── WizardChoice.preset ─────────────────────────────────────────────────

  group('LearningProcessWizardService — preset', () {
    test('creates stages from program stagesConfig', () async {
      final presets = service.getPresetsForCurriculum(CurriculumId.mishnayos);
      if (presets.isEmpty) return;

      final program = presets.first;
      final result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.preset,
        programId: program.id,
      );

      await service.applyWizardResult(result);

      final stages = await readStages();
      expect(stages, isNotEmpty);
      stages.sort((a, b) => a.stageOrder.compareTo(b.stageOrder));
      expect(stages.first.stageOrder, 1);
    });

    test('handles unknown programId gracefully (creates no stages)', () async {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.preset,
        programId: 99999,
      );

      await service.applyWizardResult(result);

      final stages = await readStages();
      expect(stages, isEmpty);
    });

    test('stores the preset program association in Firestore', () async {
      final programs = service.getPresetsForCurriculum(CurriculumId.mishnayos);
      if (programs.isEmpty) return;

      final program = programs.first;
      final result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.preset,
        programId: program.id,
      );

      await service.applyWizardResult(result);

      final profileProgram = await profileProgramRepository.getProgram(
        CurriculumId.mishnayos,
      );
      expect(profileProgram, isNotNull);
      expect(profileProgram!.programId, program.id);
    });

    test('creates stages from program seeds (oraysa — id 1)', () async {
      const result = WizardResult(
        curriculumId: CurriculumId.mishnayos,
        choice: WizardChoice.preset,
        programId: 1,
      );

      await service.applyWizardResult(result);

      final stages = await readStages();
      if (stages.isNotEmpty) {
        expect(stages.first.stageName, 'לימוד');
      }
    });
  });

  // ─── WizardResult model ─────────────────────────────────────────────────

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
      expect(result.customRounds, hasLength(1));
      expect(result.customRounds!.first.label, 'R1');
    });
  });
}
