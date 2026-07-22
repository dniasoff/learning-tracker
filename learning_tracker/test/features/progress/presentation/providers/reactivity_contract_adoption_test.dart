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

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

import '../../../../helpers/drift_memory.dart';
import '../../../../helpers/reactivity_contract.dart';

const _profileId = 1;
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
  int build() => _profileId;
}

/// Records the one completion each test mutates with, and ticks the
/// `completionCommittedProvider` signal these providers are expected to
/// watch — mirrors the write path used elsewhere in the app (a raw DB
/// insert + tick, not the full `CompletionWriter` use case, matching every
/// other reactivity guard in this suite).
Future<void> _recordCompletionAndTick(
  ProviderContainer container,
  UserDatabase db,
  int trackId,
) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumKey,
      sefariaRef: _sefariaRef,
      stageId: 1,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: DateTime.utc(2026, 6, 1, 10),
    ),
  );
  container.read(completionCommittedProvider.notifier).increment();
}

void main() {
  group('progress providers rebuild on completionCommittedProvider', () {
    test('curriculumProgressProvider', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);
      final trackId = await seedTrack(
        db,
        profileId: _profileId,
        curriculumId: _curriculumKey,
      );
      await db
          .into(db.stageDefinitions)
          .insert(
            StageDefinitionsCompanion.insert(
              profileId: _profileId,
              trackId: trackId,
              curriculumId: _curriculumKey,
              stageOrder: 1,
              stageName: 'Learned',
              schedule: const Value('{"type":"delay","delay_days":0}'),
            ),
          );

      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWith((ref) => db),
          contentRepositoryProvider.overrideWithValue(_FakeContentRepository()),
          activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
          syncWriteFacadeProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      await expectRebuildsOn(
        container,
        curriculumProgressProvider(_curriculumKey),
        () => _recordCompletionAndTick(container, db, trackId),
        reason:
            'CP-02: curriculumProgressProvider must watch '
            'completionCommittedProvider so Breakdown by Level updates live',
      );
    });

    test('itemsLearnedDataProvider', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);
      final trackId = await seedTrack(
        db,
        profileId: _profileId,
        curriculumId: _curriculumKey,
      );

      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWith((ref) => db),
          contentRepositoryProvider.overrideWithValue(_FakeContentRepository()),
          activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
          syncWriteFacadeProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      await expectRebuildsOn(
        container,
        itemsLearnedDataProvider((
          profileId: _profileId,
          curriculumId: _curriculum,
        )),
        () => _recordCompletionAndTick(container, db, trackId),
        reason:
            'ILP-01: itemsLearnedDataProvider must watch '
            'completionCommittedProvider so Items Learned updates live',
      );
    });

    test('lifetimeViewDataProvider', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);
      final trackId = await seedTrack(
        db,
        profileId: _profileId,
        curriculumId: _curriculumKey,
      );

      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWith((ref) => db),
          contentRepositoryProvider.overrideWithValue(_FakeContentRepository()),
          activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
          syncWriteFacadeProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      await expectRebuildsOn(
        container,
        lifetimeViewDataProvider((
          profileId: _profileId,
          curriculumId: _curriculum,
        )),
        () => _recordCompletionAndTick(container, db, trackId),
        reason:
            'ILP-01: lifetimeViewDataProvider must watch '
            'completionCommittedProvider so Lifetime View updates live',
      );
    });
  });
}
