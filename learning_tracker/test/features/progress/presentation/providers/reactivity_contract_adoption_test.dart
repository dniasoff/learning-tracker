/// R5 reactivity-contract adoption — progress aggregates.
///
/// Drives THREE of the app's highest-risk derived providers (all previously
/// the subject of one-off staleness escapes — CP-02, ILP-01 — fixed by
/// adding a `ref.watch(completionCommittedProvider)` line) through the
/// shared `expectRebuildsOn` helper (`test/helpers/reactivity_contract.dart`)
/// instead of each growing its own hand-rolled "read before / mutate / read
/// after" assertion:
///   - [curriculumProgressProvider] — Breakdown-by-Level cards.
///   - [itemsLearnedDataProvider] — Items Learned screen.
///   - [lifetimeViewDataProvider] — Lifetime View screen.
///
/// This is a NEW, additional guard — it does not replace or modify the
/// existing bespoke regression tests (`curriculum_progress_reactivity_test
/// .dart`, `items_learned_reactivity_test.dart`), which stay in place with
/// their own detailed fixtures.
@Tags(['progress', 'riverpod', 'contract'])
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show
        ActiveProfileDocId,
        activeProfileDocIdProvider,
        firestoreCompletionRepositoryProvider,
        firestoreLearnerProfileRepositoryProvider,
        firestoreLearningLedgerRepositoryProvider,
        firestoreStageDefinitionRepositoryProvider;
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_learner_profile_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_ledger_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';
import '../../../../helpers/reactivity_contract.dart';

const _uid = 'progress-reactivity-uid';
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
const _curriculumKey = 'mishnayos';
const _curriculum = CurriculumId.mishnayos;
const _sefariaRef = 'Mishnah Berakhot 1:1';

/// Single-leaf content fixture shared by all three providers under test —
/// each only needs SOME leaf to exist under [_curriculum] so a completion
/// against it is countable.
class _FakeContentRepository implements ContentRepository {
  final _items = const [
    ContentItem(
      curriculumId: _curriculumKey,
      sefariaRef: _sefariaRef,
      displayNameEn: _sefariaRef,
      displayNameHe: _sefariaRef,
      level1: 'Zeraim',
      level2: 'Berakhot',
      isLeaf: true,
      sortOrder: 0,
    ),
  ];

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async => curriculumId == _curriculum ? _items : const [];

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(
    CurriculumId curriculumId,
  ) async => CurriculumHierarchyConfig(
    curriculumId: curriculumId.storageKey,
    levelLabels: const ['Seder', 'Masechta', 'Perek', 'Mishna'],
    totalItems: _items.length,
  );

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async => const [];

  @override
  Future<List<ContentItem>> getScopedContent({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) async => _items;

  @override
  Future<List<ContentItem>> search({
    required CurriculumId curriculumId,
    required String query,
  }) async => const [];

  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async => null;
}

class _ProfileIdOverride extends ActiveProfileId {
  @override
  String? build() => _profileId;
}

class _ProfileDocIdOverride extends ActiveProfileDocId {
  @override
  String? build() => _profileId;
}

/// Records the one completion each test mutates with, and ticks the
/// `completionCommittedProvider` signal these providers are expected to
/// watch — mirrors the write path used elsewhere in the app (a raw DB
/// insert + tick, not the full `CompletionWriter` use case, matching every
/// other reactivity guard in this suite).
Future<void> _recordCompletionAndTick(
  ProviderContainer container,
  FakeFirebaseFirestore firestore,
) async {
  await seedCompletion(
    firestore,
    uid: _uid,
    profileId: _profileId,
    curriculumId: _curriculum,
    sefariaRef: _sefariaRef,
    stageId: 1,
    completedAt: DateTime.utc(2026, 6, 1, 10),
  );
  container.read(completionCommittedProvider.notifier).increment();
}

void main() {
  group('progress providers rebuild on completionCommittedProvider', () {
    test('curriculumProgressProvider', () async {
      final firestore = createFakeFirestore(authenticatedUid: _uid);
      await seedProfile(firestore, uid: _uid, profileId: _profileId);
      await seedStageDefinitions(
        firestore,
        uid: _uid,
        profileId: _profileId,
        curriculumId: _curriculum,
        stages: [
          const StageDefinition(
            curriculumId: _curriculum,
            stageOrder: 1,
            stageName: 'Learned',
            delayDays: 0,
            isDefault: true,
            scheduleType: ScheduleType.delay,
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          contentRepositoryProvider.overrideWithValue(_FakeContentRepository()),
          activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
          activeProfileDocIdProvider.overrideWith(_ProfileDocIdOverride.new),
          firestoreCompletionRepositoryProvider.overrideWith(
            (ref) async => FirestoreCompletionRepository(
              firestore: firestore,
              uid: _uid,
              profileId: _profileId,
            ),
          ),
          firestoreStageDefinitionRepositoryProvider.overrideWith(
            (ref) async => FirestoreStageDefinitionRepository(
              firestore: firestore,
              uid: _uid,
              profileId: _profileId,
            ),
          ),
          firestoreLearnerProfileRepositoryProvider.overrideWith(
            (ref) async => FirestoreLearnerProfileRepository(
              firestore: firestore,
              uid: _uid,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectRebuildsOn(
        container,
        curriculumProgressProvider(_curriculumKey),
        () => _recordCompletionAndTick(container, firestore),
        reason:
            'CP-02: curriculumProgressProvider must watch '
            'completionCommittedProvider so Breakdown by Level updates live',
      );
    });

    test('itemsLearnedDataProvider', () async {
      final firestore = createFakeFirestore(authenticatedUid: _uid);

      final container = ProviderContainer(
        overrides: [
          contentRepositoryProvider.overrideWithValue(_FakeContentRepository()),
          activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
          firestoreCompletionRepositoryProvider.overrideWith(
            (ref) async => FirestoreCompletionRepository(
              firestore: firestore,
              uid: _uid,
              profileId: _profileId,
            ),
          ),
          firestoreLearningLedgerRepositoryProvider.overrideWith(
            (ref) async => FirestoreLearningLedgerRepository(
              firestore: firestore,
              uid: _uid,
              profileId: _profileId,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectRebuildsOn(
        container,
        itemsLearnedDataProvider(_curriculum),
        () => _recordCompletionAndTick(container, firestore),
        reason:
            'ILP-01: itemsLearnedDataProvider must watch '
            'completionCommittedProvider so Items Learned updates live',
      );
    });

    test('lifetimeViewDataProvider', () async {
      final firestore = createFakeFirestore(authenticatedUid: _uid);

      final container = ProviderContainer(
        overrides: [
          contentRepositoryProvider.overrideWithValue(_FakeContentRepository()),
          activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
          firestoreCompletionRepositoryProvider.overrideWith(
            (ref) async => FirestoreCompletionRepository(
              firestore: firestore,
              uid: _uid,
              profileId: _profileId,
            ),
          ),
          firestoreLearningLedgerRepositoryProvider.overrideWith(
            (ref) async => FirestoreLearningLedgerRepository(
              firestore: firestore,
              uid: _uid,
              profileId: _profileId,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectRebuildsOn(
        container,
        lifetimeViewDataProvider(_curriculum),
        () => _recordCompletionAndTick(container, firestore),
        reason:
            'ILP-01: lifetimeViewDataProvider must watch '
            'completionCommittedProvider so Lifetime View updates live',
      );
    });
  });
}
