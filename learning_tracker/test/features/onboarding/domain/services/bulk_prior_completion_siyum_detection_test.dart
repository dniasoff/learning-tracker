/// End-to-end Firestore coverage for bulk-prior siyum detection.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_ledger_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_ledger_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_orchestrator.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_ledger_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

const _uid = 'bulk-siyum-detection-uid';
const _adultProfileId = '01J6Q2H4A8M7K3P9R5T6V8WXYA';

class _ActiveProfileOverride extends ActiveProfileId {
  @override
  String? build() => _adultProfileId;
}

class _FixtureContentRepository extends Fake implements ContentRepository {
  _FixtureContentRepository(this.items);

  final List<ContentItem> items;

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async => items;

  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async {
    for (final item in items) {
      if (item.curriculumId == curriculumId.storageKey &&
          item.sefariaRef == sefariaRef) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async => items.where((item) {
    if (item.curriculumId != curriculumId.storageKey) return false;
    if (level1 != null && item.level1 != level1) return false;
    if (level2 != null && item.level2 != level2) return false;
    if (level3 != null && item.level3 != level3) return false;
    if (level4 != null && item.level4 != level4) return false;
    return true;
  }).toList();
}

class _NoopBookmarkRepository implements BookmarkRepository {
  @override
  Future<void> advanceBookmark({
    required CurriculumId curriculumId,
    required String completedSefariaRef,
  }) async {}

  @override
  Future<BookmarkEntity?> getBookmark({
    required CurriculumId curriculumId,
  }) async => null;

  @override
  Future<BookmarkEntity> initializeBookmark({
    required CurriculumId curriculumId,
  }) async => BookmarkEntity(
    curriculumId: curriculumId,
    sefariaRef: '',
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  @override
  Future<BookmarkEntity> setBookmark({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async => BookmarkEntity(
    curriculumId: curriculumId,
    sefariaRef: sefariaRef,
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

List<ContentItem> _masechtaLeaves() => const [
  ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Zeraim',
    level2: 'Berakhot',
    level3: 'Perek 1',
    displayNameHe: 'משנה א',
    displayNameEn: 'Mishna 1',
    sefariaRef: 'Mishnah_Berakhot_1',
    sortOrder: 0,
    isLeaf: true,
  ),
  ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Zeraim',
    level2: 'Berakhot',
    level3: 'Perek 2',
    displayNameHe: 'משנה ב',
    displayNameEn: 'Mishna 2',
    sefariaRef: 'Mishnah_Berakhot_2',
    sortOrder: 1,
    isLeaf: true,
  ),
  ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Zeraim',
    level2: 'Berakhot',
    level3: 'Perek 3',
    displayNameHe: 'משנה ג',
    displayNameEn: 'Mishna 3',
    sefariaRef: 'Mishnah_Berakhot_3',
    sortOrder: 2,
    isLeaf: true,
  ),
];

List<ContentItem> _chumashSefarim() {
  const sefarim = ['Bereshit', 'Shemot', 'Vayikra', 'Bamidbar', 'Devarim'];
  return [
    for (var i = 0; i < sefarim.length; i++)
      ContentItem(
        curriculumId: 'chumash',
        level1: sefarim[i],
        level2: '1',
        displayNameHe: sefarim[i],
        displayNameEn: sefarim[i],
        sefariaRef: '${sefarim[i]}_1_1',
        sortOrder: i,
        isLeaf: true,
      ),
  ];
}

void main() {
  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;
  late FirestoreCompletionRepository completionStore;
  late FirestoreLearningLedgerRepository ledgerStore;
  late FirestoreStageDefinitionRepository stageStore;
  late ContentRepository contentRepository;
  late CompletionRepository completionRepository;
  late LearningLedgerRepository ledgerRepository;
  late StageDefinitionRepository stageRepository;

  setUp(() async {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    await seedAccount(firestore, uid: _uid);
    await seedProfile(
      firestore,
      uid: _uid,
      profileId: _adultProfileId,
      mode: ProfileMode.adult,
    );

    completionStore = FirestoreCompletionRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _adultProfileId,
    );
    ledgerStore = FirestoreLearningLedgerRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _adultProfileId,
    );
    stageStore = FirestoreStageDefinitionRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _adultProfileId,
    );
  });

  Future<void> configure(
    CurriculumId curriculum,
    List<ContentItem> items,
  ) async {
    await seedStageDefinitions(
      firestore,
      uid: _uid,
      profileId: _adultProfileId,
      curriculumId: curriculum,
      stages: [
        StageDefinition(
          curriculumId: curriculum,
          stageOrder: 1,
          stageName: 'Learn',
          delayDays: 0,
          isDefault: true,
          scheduleType: ScheduleType.delay,
        ),
      ],
    );
    contentRepository = _FixtureContentRepository(items);

    container = ProviderContainer(
      overrides: [
        activeProfileIdProvider.overrideWith(() => _ActiveProfileOverride()),
        firestoreCompletionRepositoryProvider.overrideWith(
          (ref) async => completionStore,
        ),
        firestoreLearningLedgerRepositoryProvider.overrideWith(
          (ref) async => ledgerStore,
        ),
        firestoreStageDefinitionRepositoryProvider.overrideWith(
          (ref) async => stageStore,
        ),
        learningLedgerRepositoryProvider.overrideWith(
          (ref) => FirestoreLearningLedgerRepositoryAdapter(
            ref: ref,
            activeProfileMode: ProfileMode.adult,
          ),
        ),
        activeCurriculaProvider.overrideWith(
          (ref) => Future.value([curriculum]),
        ),
        curriculumContentProvider(curriculum).overrideWith(
          (ref) => Future.value(items),
        ),
        siyumGranularityProvider(curriculum).overrideWithValue(
          MilestoneLevel.unit,
        ),
      ],
    );
    container.read(activeProfileDocIdProvider.notifier).set(_adultProfileId);
    addTearDown(container.dispose);

    completionRepository = container.read(completionRepositoryProvider);
    ledgerRepository = container.read(learningLedgerRepositoryProvider);
    final stageProvider = Provider<StageDefinitionRepository>(
      (ref) => FirestoreStageDefinitionRepositoryAdapter(ref: ref),
    );
    stageRepository = container.read(stageProvider);
  }

  BulkPriorCompletionService buildService() {
    final detection = CompletionDetectionService(
      completionRepository: completionRepository,
      contentRepository: contentRepository,
      ledgerRepository: ledgerRepository,
      stageRepository: stageRepository,
    );
    final orchestrator = CompletionOrchestrator(
      repository: completionRepository,
      contentRepository: contentRepository,
      activeProfileId: _adultProfileId,
      learningLedgerRepository: ledgerRepository,
      completionDetectionService: detection,
    );
    return BulkPriorCompletionService(
      contentRepository: contentRepository,
      completionRepository: completionRepository,
      bookmarkRepository: _NoopBookmarkRepository(),
      stageRepository: stageRepository,
      orchestrator: orchestrator,
    );
  }

  Future<void> bulkMark(
    CurriculumId curriculum,
    List<ContentItem> items,
  ) async {
    await buildService().execute(
      curriculumId: curriculum,
      resolvedItems: items,
      stageIds: const [1],
    );
  }

  group('F1 (W7-A) — Bulk-mark wizard triggers siyum detection', () {
    test(
      'bulk-marking every leaf of a masechta via BulkPriorCompletionService creates the masechta siyum ledger entry',
      () async {
        final leaves = _masechtaLeaves();
        await configure(CurriculumId.mishnayos, leaves);
        await bulkMark(CurriculumId.mishnayos, leaves);

        final entries = await ledgerStore.getLifetimeLedger();
        expect(
          entries.where(
            (entry) =>
                entry.curriculumId == CurriculumId.mishnayos &&
                entry.entryScope == 'masechta' &&
                entry.unitIdentifier == 'Berakhot',
          ),
          hasLength(1),
        );
      },
    );

    test(
      'partial bulk-mark (missing one leaf) does NOT create the masechta siyum',
      () async {
        final leaves = _masechtaLeaves();
        await configure(CurriculumId.mishnayos, leaves);
        await bulkMark(CurriculumId.mishnayos, leaves.take(2).toList());

        final entries = await ledgerStore.getLifetimeLedger();
        expect(
          entries.where((entry) => entry.entryScope == 'masechta'),
          isEmpty,
        );
      },
    );
  });

  group(
    'P0 — Chumash-shaped bulk-mark must not fire a false curriculum-complete siyum',
    () {
      test(
        '3 of 5 sefarim: no false curriculum-complete milestone, correct 5-sefer denominator, no masechta-mislabeled or duplicate entries',
        () async {
          final sefarim = _chumashSefarim();
          await configure(CurriculumId.chumash, sefarim);
          await bulkMark(CurriculumId.chumash, sefarim.take(3).toList());

          final entries = await ledgerStore.getLifetimeLedger();
          expect(entries, hasLength(3));
          expect(entries.map((entry) => entry.unitIdentifier).toSet(),
              hasLength(3));
          expect(entries.every((entry) => entry.entryScope == 'sefer'), isTrue);
          expect(
            entries.any((entry) => entry.entryScope == 'masechta'),
            isFalse,
          );

          final journey = await container.read(journeyViewModelProvider.future);
          final chumash = journey.curricula.single;
          expect(chumash.totalUnitsAvailable, 5);
          expect(chumash.uniqueUnitsCompleted, 3);
          expect(journey.curriculumLevelSiyumimCount, 0);
        },
      );

      test(
        '5 of 5 sefarim: DOES fire the real curriculum-complete milestone (positive control — the negative control above must remain valid)',
        () async {
          final sefarim = _chumashSefarim();
          await configure(CurriculumId.chumash, sefarim);
          await bulkMark(CurriculumId.chumash, sefarim);

          final entries = await ledgerStore.getLifetimeLedger();
          expect(entries, hasLength(5));
          expect(entries.map((entry) => entry.unitIdentifier).toSet(),
              hasLength(5));
          expect(entries.every((entry) => entry.entryScope == 'sefer'), isTrue);
          expect(
            entries.any((entry) => entry.entryScope == 'masechta'),
            isFalse,
          );

          final journey = await container.read(journeyViewModelProvider.future);
          final chumash = journey.curricula.single;
          expect(chumash.totalUnitsAvailable, 5);
          expect(chumash.uniqueUnitsCompleted, 5);
          expect(journey.curriculumLevelSiyumimCount, 1);
          expect(
            chumash.milestones.where(
              (milestone) => milestone.level == MilestoneLevel.curriculum,
            ),
            hasLength(1),
          );
        },
      );
    },
  );
}
