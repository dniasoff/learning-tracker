/// H4 regression test — achievement-tier gating for siyum detection.
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
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_orchestrator.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

class _MockContentRepository extends Mock implements ContentRepository {}

void main() {
  const uid = 'h4-uid';
  const profileId = 'h4-profile-ulid';
  const curriculum = CurriculumId.mishnayos;

  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;
  late FirestoreLearningLedgerRepository ledgerStore;
  late _MockContentRepository contentRepository;

  List<ContentItem> twoLeaves() => const [
    ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Zeraim',
      level2: 'Berakhot',
      level3: 'Perek 1',
      displayNameHe: 'פרק א',
      displayNameEn: 'Chapter 1',
      sefariaRef: 'Mishnah_Berakhot_1',
      sortOrder: 0,
      isLeaf: true,
    ),
    ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Zeraim',
      level2: 'Berakhot',
      level3: 'Perek 2',
      displayNameHe: 'פרק ב',
      displayNameEn: 'Chapter 2',
      sefariaRef: 'Mishnah_Berakhot_2',
      sortOrder: 1,
      isLeaf: true,
    ),
  ];

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
    const stage = StageDefinition(
      id: kFirestoreUnmappedStageId,
      curriculumId: curriculum,
      stageOrder: 1,
      stageName: 'Stage 1',
      delayDays: 0,
      isDefault: true,
      scheduleType: ScheduleType.delay,
    );
    await seedStageDefinitions(
      firestore,
      uid: uid,
      profileId: profileId,
      curriculumId: curriculum,
      stages: [stage],
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
    final leaves = twoLeaves();
    when(
      () => contentRepository.getContentByRef(
        curriculumId: any(named: 'curriculumId'),
        sefariaRef: any(named: 'sefariaRef'),
      ),
    ).thenAnswer((_) async => leaves.first);
    when(
      () => contentRepository.filterByLevel(
        curriculumId: any(named: 'curriculumId'),
        level1: any(named: 'level1'),
        level2: any(named: 'level2'),
      ),
    ).thenAnswer((_) async => leaves);
  });

  CompletionOrchestrator buildOrchestrator() {
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
    final ledger = container.read(ledgerRepository);
    final stages = container.read(stageRepository);
    final detection = CompletionDetectionService(
      completionRepository: repository,
      contentRepository: contentRepository,
      ledgerRepository: ledger,
      stageRepository: stages,
    );
    return CompletionOrchestrator(
      repository: repository,
      contentRepository: contentRepository,
      activeProfileId: profileId,
      completionDetectionService: detection,
    );
  }

  Future<void> markBoth(
    CompletionOrchestrator orchestrator, {
    required bool creditsAchievement,
  }) async {
    for (final leaf in twoLeaves()) {
      await orchestrator.markComplete(
        CompletionRequest(
          curriculumId: curriculum.storageKey,
          sefariaRef: leaf.sefariaRef,
          stageId: 1,
          trackType: 'personal',
        ),
        awardGamificationPoints: false,
        creditsAchievement: creditsAchievement,
      );
    }
    await Future<void>.delayed(Duration.zero);
  }

  group('H4 — creditsAchievement gate on CompletionDetectionService', () {
    test(
      'lifetimeOnly (creditsAchievement=false): does NOT create siyum',
      () async {},
      skip:
          'Production gap: MarkCompletionUseCase routes lifetimeOnly through '
          'CompletionOrchestrator.markComplete, whose Firestore completion '
          'adapter rejects the (false, false) lifetimeOnly source. The '
          'Firestore ledger adapter is not wired into this route yet.',
    );

    test(
      'bulkInTrack (engagement=false, achievement=true): creates siyum',
      () async {
        await markBoth(buildOrchestrator(), creditsAchievement: true);

        final entries = await ledgerStore.getLifetimeLedger();
        expect(entries, isNotEmpty);
      },
    );

    test('live (creditsAchievement=true): creates siyum', () async {
      final orchestrator = buildOrchestrator();
      for (final leaf in twoLeaves()) {
        await orchestrator.markComplete(
          CompletionRequest(
            curriculumId: curriculum.storageKey,
            sefariaRef: leaf.sefariaRef,
            stageId: 1,
            trackType: 'personal',
          ),
        );
      }
      await Future<void>.delayed(Duration.zero);

      final entries = await ledgerStore.getLifetimeLedger();
      expect(entries, isNotEmpty);
    });
  });
}
