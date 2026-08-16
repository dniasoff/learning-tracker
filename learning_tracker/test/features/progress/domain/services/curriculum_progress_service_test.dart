import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/progress/data/repositories/firestore_progress_repository_adapter.dart';
import 'package:learning_tracker/features/progress/domain/services/curriculum_progress_service.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart'
    as domain_stage;
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

const _uid = 'curriculum-progress-service-user';
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
const _curriculum = CurriculumId.mishnayos;

void main() {
  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;
  late FirestoreProgressRepositoryAdapter repository;

  setUp(() async {
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
      ],
    );
    container.read(activeProfileDocIdProvider.notifier).set(_profileId);
    final adapterProvider = Provider<FirestoreProgressRepositoryAdapter>(
      (ref) => FirestoreProgressRepositoryAdapter(ref: ref),
    );
    repository = container.read(adapterProvider);
  });

  tearDown(() => container.dispose());

  ContentItem leaf({
    required String level1,
    String? level2,
    required String sefariaRef,
  }) => ContentItem(
    curriculumId: _curriculum.storageKey,
    level1: level1,
    level2: level2,
    displayNameHe: sefariaRef,
    displayNameEn: sefariaRef,
    sefariaRef: sefariaRef,
    sortOrder: 0,
    isLeaf: true,
  );

  domain_stage.StageDefinition stage(int order, String name) =>
      domain_stage.StageDefinition(
        curriculumId: _curriculum,
        stageOrder: order,
        stageName: name,
        delayDays: 0,
        isDefault: true,
        scheduleType: ScheduleType.delay,
      );

  Future<void> seedMark(
    String ref,
    int stageId, {
    String trackType = 'personal',
  }) {
    return seedCompletion(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: _curriculum,
      sefariaRef: ref,
      stageId: stageId,
      trackType: trackType,
      completedAt: DateTime.utc(2026, 3, 15),
    );
  }

  Future<List<CompletionEntity>> completions() =>
      repository.getCompletionsByCurriculum(_curriculum.storageKey);

  group('CurriculumProgressService', () {
    test(
      'computes completion percentage for a seder with 50% completed',
      () async {
        final items = [
          leaf(level1: 'Seder Zeraim', level2: 'Berachos', sefariaRef: 'ref1'),
          leaf(level1: 'Seder Zeraim', level2: 'Peah', sefariaRef: 'ref2'),
          leaf(level1: 'Seder Zeraim', level2: 'Demai', sefariaRef: 'ref3'),
          leaf(level1: 'Seder Zeraim', level2: 'Kilayim', sefariaRef: 'ref4'),
        ];
        await seedMark('ref1', 1);
        await seedMark('ref2', 1);
        final result = CurriculumProgressService.compute(
          curriculumId: _curriculum.storageKey,
          contentItems: items,
          completions: await completions(),
          stageDefinitions: [stage(1, 'Learned')],
          levelLabels: ['Seder', 'Masechta'],
        );
        final seder = result.hierarchyLevels.single;
        expect(seder.levelName, 'Seder Zeraim');
        expect(seder.totalItems, 4);
        expect(seder.completedItems, 2);
        expect(seder.completionPercentage, 0.5);
      },
    );

    test('stage breakdown counts are accurate per hierarchy level', () async {
      final items = [
        leaf(level1: 'Seder Zeraim', sefariaRef: 'ref1'),
        leaf(level1: 'Seder Zeraim', sefariaRef: 'ref2'),
        leaf(level1: 'Seder Zeraim', sefariaRef: 'ref3'),
      ];
      await seedMark('ref1', 1);
      await seedMark('ref1', 2);
      await seedMark('ref2', 1);
      await seedMark('ref3', 1);
      await seedMark('ref3', 2);
      await seedMark('ref3', 3);
      final result = CurriculumProgressService.compute(
        curriculumId: _curriculum.storageKey,
        contentItems: items,
        completions: await completions(),
        stageDefinitions: [
          stage(1, 'Learned'),
          stage(2, 'Chazara 1'),
          stage(3, 'Chazara 2'),
        ],
        levelLabels: ['Seder'],
      );
      final breakdown = result.hierarchyLevels.single.stageBreakdown;
      expect(breakdown[0].stageName, 'Learned');
      expect(breakdown[0].count, 3);
      expect(breakdown[1].stageName, 'Chazara 1');
      expect(breakdown[1].count, 2);
      expect(breakdown[2].stageName, 'Chazara 2');
      expect(breakdown[2].count, 1);
    });

    test('track breakdown counts personal completions', () async {
      final items = [leaf(level1: 'Seder Zeraim', sefariaRef: 'ref1')];
      await seedMark('ref1', 1);
      await seedMark('ref1', 2);
      await seedMark('ref1', 3);
      final result = CurriculumProgressService.compute(
        curriculumId: _curriculum.storageKey,
        contentItems: items,
        completions: await completions(),
        stageDefinitions: [
          stage(1, 'Learned'),
          stage(2, 'Chazara 1'),
          stage(3, 'Chazara 2'),
        ],
        levelLabels: ['Seder', 'Masechta'],
      );
      expect(result.hierarchyLevels.single.trackBreakdown['personal'], 3);
    });

    test('overall stats categorize items correctly', () async {
      final items = [
        leaf(level1: 'S1', sefariaRef: 'ref1'),
        leaf(level1: 'S1', sefariaRef: 'ref2'),
        leaf(level1: 'S1', sefariaRef: 'ref3'),
        leaf(level1: 'S1', sefariaRef: 'ref4'),
      ];
      await seedMark('ref1', 1);
      await seedMark('ref1', 2);
      await seedMark('ref2', 1);
      final result = CurriculumProgressService.compute(
        curriculumId: _curriculum.storageKey,
        contentItems: items,
        completions: await completions(),
        stageDefinitions: [stage(1, 'Learned'), stage(2, 'Chazara 1')],
        levelLabels: ['Seder'],
      );
      expect(result.overallStats.totalItems, 4);
      expect(result.overallStats.completedAllStages, 1);
      expect(result.overallStats.inProgress, 1);
      expect(result.overallStats.notStarted, 2);
    });

    test('hierarchy has correct sub-levels', () async {
      final items = [
        leaf(level1: 'Seder Zeraim', level2: 'Berachos', sefariaRef: 'ref1'),
        leaf(level1: 'Seder Zeraim', level2: 'Berachos', sefariaRef: 'ref2'),
        leaf(level1: 'Seder Zeraim', level2: 'Peah', sefariaRef: 'ref3'),
        leaf(level1: 'Seder Moed', level2: 'Shabbos', sefariaRef: 'ref4'),
      ];
      await seedMark('ref1', 1);
      await seedMark('ref4', 1);
      final result = CurriculumProgressService.compute(
        curriculumId: _curriculum.storageKey,
        contentItems: items,
        completions: await completions(),
        stageDefinitions: [stage(1, 'Learned')],
        levelLabels: ['Seder', 'Masechta'],
      );
      expect(result.hierarchyLevels, hasLength(2));
      final zeraim = result.hierarchyLevels[0];
      expect(zeraim.levelName, 'Seder Zeraim');
      expect(zeraim.totalItems, 3);
      expect(zeraim.completedItems, 1);
      expect(zeraim.subLevels, hasLength(2));
      expect(zeraim.subLevels![0].levelName, 'Berachos');
      expect(zeraim.subLevels![0].totalItems, 2);
      expect(zeraim.subLevels![0].completedItems, 1);
      expect(zeraim.subLevels![1].levelName, 'Peah');
      expect(zeraim.subLevels![1].totalItems, 1);
      expect(zeraim.subLevels![1].completedItems, 0);
      final moed = result.hierarchyLevels[1];
      expect(moed.levelName, 'Seder Moed');
      expect(moed.totalItems, 1);
      expect(moed.completedItems, 1);
    });

    test('empty curriculum returns zero stats', () {
      final result = CurriculumProgressService.compute(
        curriculumId: _curriculum.storageKey,
        contentItems: [],
        completions: const [],
        stageDefinitions: const [],
        levelLabels: ['Seder', 'Masechta'],
      );
      expect(result.hierarchyLevels, isEmpty);
      expect(result.overallStats.totalItems, 0);
      expect(result.overallStats.completedAllStages, 0);
      expect(result.overallStats.inProgress, 0);
      expect(result.overallStats.notStarted, 0);
    });
  });
}
