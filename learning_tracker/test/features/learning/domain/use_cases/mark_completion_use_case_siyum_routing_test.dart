/// W1-A regression test — siyumim use the independent achievement gate.
@Tags(['epic_3', 'b1_credit_policy'])
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_ledger_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_ledger_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_orchestrator.dart';
import 'package:learning_tracker/features/learning/domain/use_cases/mark_completion_use_case.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

class _MockContentRepository extends Mock implements ContentRepository {}

class _RecordingStreakPort implements CompletionStreakPort {
  int calls = 0;

  @override
  Future<void> recordStudyDay({
    required String? profileId,
    required DateTime at,
  }) async {
    calls++;
  }
}

void main() {
  const uid = 'routing-uid';
  const profileId = '01J6Q2H4A8M7K3P9R5T6V8WXY4';
  const curriculum = CurriculumId.mishnayos;
  const leafRef = 'Mishnah_Berakhot_1';

  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;
  late FirestoreLearningLedgerRepository ledgerStore;
  late _MockContentRepository contentRepository;
  late _RecordingStreakPort streakPort;
  late MarkCompletionUseCase useCase;

  setUp(() async {
    firestore = createFakeFirestore(authenticatedUid: uid);
    final completionStore = FirestoreCompletionRepository(
      firestore: firestore,
      uid: uid,
      profileId: profileId,
    );
    ledgerStore = FirestoreLearningLedgerRepository(
      firestore: firestore,
      uid: uid,
      profileId: profileId,
    );
    final stageStore = FirestoreStageDefinitionRepository(
      firestore: firestore,
      uid: uid,
      profileId: profileId,
    );
    await seedStageDefinitions(
      firestore,
      uid: uid,
      profileId: profileId,
      curriculumId: curriculum,
      stages: [
        const StageDefinition(
          curriculumId: curriculum,
          stageOrder: 1,
          stageName: 'Stage 1',
          delayDays: 0,
          isDefault: true,
          scheduleType: ScheduleType.delay,
        ),
      ],
    );
    container = ProviderContainer(
      overrides: [
        firestoreCompletionRepositoryProvider.overrideWith(
          (ref) async => completionStore,
        ),
        firestoreLearningLedgerRepositoryProvider.overrideWith(
          (ref) async => ledgerStore,
        ),
        firestoreStageDefinitionRepositoryProvider.overrideWith(
          (ref) async => stageStore,
        ),
      ],
    );
    container.read(activeProfileDocIdProvider.notifier).set(profileId);
    addTearDown(container.dispose);

    contentRepository = _MockContentRepository();
    const leaf = ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Zeraim',
      level2: 'Berakhot',
      level3: 'Perek 1',
      displayNameHe: 'פרק א',
      displayNameEn: 'Chapter 1',
      sefariaRef: leafRef,
      sortOrder: 0,
      isLeaf: true,
    );
    when(
      () => contentRepository.getContentByRef(
        curriculumId: any(named: 'curriculumId'),
        sefariaRef: any(named: 'sefariaRef'),
      ),
    ).thenAnswer((_) async => leaf);
    when(
      () => contentRepository.filterByLevel(
        curriculumId: any(named: 'curriculumId'),
        level1: any(named: 'level1'),
        level2: any(named: 'level2'),
      ),
    ).thenAnswer((_) async => [leaf]);
    when(
      () => contentRepository.getContentForCurriculum(any()),
    ).thenAnswer((_) async => []);

    final completionRepository = Provider<CompletionRepository>(
      (ref) => FirestoreCompletionRepositoryAdapter(ref: ref),
    );
    final ledgerRepository = Provider<LearningLedgerRepository>(
      (ref) => FirestoreLearningLedgerRepositoryAdapter(
        ref: ref,
        activeProfileMode: ProfileMode.adult,
      ),
    );
    final stageRepository = Provider<StageDefinitionRepository>(
      (ref) => FirestoreStageDefinitionRepositoryAdapter(ref: ref),
    );
    final repository = container.read(completionRepository);
    final detection = CompletionDetectionService(
      completionRepository: repository,
      contentRepository: contentRepository,
      ledgerRepository: container.read(ledgerRepository),
      stageRepository: container.read(stageRepository),
    );
    streakPort = _RecordingStreakPort();
    useCase = MarkCompletionUseCase(
      CompletionOrchestrator(
        repository: repository,
        contentRepository: contentRepository,
        activeProfileId: profileId,
        learningLedgerRepository: container.read(ledgerRepository),
        completionDetectionService: detection,
        streakPort: streakPort,
      ),
    );
  });

  group(
    'MarkCompletionUseCase routing — siyum gate uses creditsAchievement',
    () {
      test(
        'bulkInTrack completes a one-leaf masechta and writes a siyum',
        () async {
          await useCase.call(
            const CompletionRequest(
              curriculumId: 'mishnayos',
              sefariaRef: leafRef,
              stageId: 1,
              trackType: 'personal',
            ),
            source: CompletionSource.bulkInTrack,
          );
          await Future<void>.delayed(Duration.zero);

          expect(await ledgerStore.getLifetimeLedger(), isNotEmpty);
          expect(streakPort.calls, 0);
        },
      );

      test('lifetimeOnly does not write a siyum or streak', () async {
        await useCase.call(
          const CompletionRequest(
            curriculumId: 'mishnayos',
            sefariaRef: leafRef,
            stageId: 1,
            trackType: 'personal',
          ),
          source: CompletionSource.lifetimeOnly,
        );
        await Future<void>.delayed(Duration.zero);

        final entries = await ledgerStore.getLifetimeLedger();
        expect(entries, hasLength(1));
        expect(entries.single.source, CompletionSource.lifetimeOnly);
        expect(entries.single.isManual, isTrue);
        expect(streakPort.calls, 0);
      });

      test(
        'live completion writes a siyum and records one study day',
        () async {
          await useCase.call(
            const CompletionRequest(
              curriculumId: 'mishnayos',
              sefariaRef: leafRef,
              stageId: 1,
              trackType: 'personal',
            ),
          );
          await Future<void>.delayed(Duration.zero);

          expect(await ledgerStore.getLifetimeLedger(), isNotEmpty);
          expect(streakPort.calls, 1);
        },
      );
    },
  );
}
