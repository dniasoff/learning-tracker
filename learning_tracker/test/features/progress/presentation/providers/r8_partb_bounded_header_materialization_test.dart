/// R8 Part B red-demo — proves the Lifetime-Knowledge/Dashboard HEADER total
/// (`lifetimeTotalsAcrossAllCurriculaProvider`, the "X / 70,033 sections"
/// denominator) no longer force-materializes (permanently caches) any
/// curriculum's full content to compute the total.
///
/// Part A stopped the items-learned aggregates from materializing all 9
/// curricula. This is the header/denominator follow-up (Part B): the header
/// used to read `lifetimeSummariesProvider`, which builds a full
/// [LifetimeTreeNode] tree per curriculum via
/// `ContentRepository.getContentForCurriculum` — PERMANENTLY caching every
/// curriculum's full leaf+container hierarchy in `ContentRepositoryImpl`'s
/// `_contentCache` (nothing ever evicts it). On a 512 MB heap (API 29,
/// on-device run-8) that OOM-killed the process.
///
/// This test wraps a real (disk-backed) [ContentRepositoryImpl] in a counting
/// proxy that records which curricula go through `getContentForCurriculum`
/// (the PERMANENT-CACHING path) versus `loadLeavesTransient` (the bounded,
/// non-retaining path).
///
/// WITH the fix: `getContentForCurriculum` is called ZERO times computing the
/// header total — every curriculum is still VISITED (via
/// `loadLeavesTransient`, since every curriculum contributes to the "X / N"
/// denominator regardless of whether the profile has touched it), but none is
/// permanently cached.
///
/// WITHOUT the fix (revert `lifetimeTotalsAcrossAllCurriculaProvider` in
/// `lifetime_knowledge_providers.dart` to read `lifetimeSummariesProvider`,
/// as it did before this change): `getContentForCurriculum` is called for
/// all 9 curricula — the OOM path. Verified manually (see delivery notes);
/// not committed as a live toggle to avoid shipping a deliberately-broken
/// path in `lib/`.
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/content_repository_impl.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';

import '../../../../helpers/drift_memory.dart';

/// Real repository backed by the on-disk bundled assets (rootBundle is empty
/// in the test environment).
class _DiskContentRepository extends ContentRepositoryImpl {
  @override
  Future<String> loadRawContentJson(String key) =>
      File('assets/content/hierarchy/$key.json').readAsString();
}

/// Delegating proxy that records, per curriculum, which loading path was
/// used: the PERMANENT-CACHING [getContentForCurriculum] versus the bounded,
/// non-retaining [loadLeavesTransient].
class _CountingUnionRepository
    implements ContentRepository, LifetimeUnionLeafSource {
  _CountingUnionRepository(this._inner);

  final ContentRepositoryImpl _inner;

  /// storageKeys for which the PERMANENT-CACHING path was invoked.
  final Set<String> fullyMaterialized = <String>{};

  /// storageKeys for which the bounded, non-retaining path was invoked.
  final Set<String> transientlyLoaded = <String>{};

  @override
  Future<List<ContentItem>> getContentForCurriculum(CurriculumId curriculumId) {
    fullyMaterialized.add(curriculumId.storageKey);
    return _inner.getContentForCurriculum(curriculumId);
  }

  @override
  Future<List<ContentItem>> loadLeavesTransient(CurriculumId curriculumId) {
    transientlyLoaded.add(curriculumId.storageKey);
    return _inner.loadLeavesTransient(curriculumId);
  }

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(
    CurriculumId curriculumId,
  ) => _inner.getHierarchyConfig(curriculumId);

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) => _inner.filterByLevel(
    curriculumId: curriculumId,
    level1: level1,
    level2: level2,
    level3: level3,
    level4: level4,
  );

  @override
  Future<List<ContentItem>> getScopedContent({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) => _inner.getScopedContent(
    curriculumId: curriculumId,
    scopeLevel: scopeLevel,
    scopeValues: scopeValues,
  );

  @override
  Future<List<ContentItem>> search({
    required CurriculumId curriculumId,
    required String query,
  }) => _inner.search(curriculumId: curriculumId, query: query);

  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) => _inner.getContentByRef(
    curriculumId: curriculumId,
    sefariaRef: sefariaRef,
  );
}

void main() {
  late UserDatabase db;
  late _CountingUnionRepository repo;
  const profileId = 1;
  // A genuine Mussar leaf ref so the total reflects a real learned count (not
  // just a materialization count) — mirrors the Part A red-demo fixture.
  const mussarLeafRef = 'Mesillat Yesharim 1:1';

  setUp(() async {
    final database = inMemoryDb();
    // TQ-6: close in the same scope as the factory call.
    addTearDown(database.close);
    db = database;
    await seedProfile(db); // profile id 1
    final trackId = await seedTrack(
      db,
      profileId: profileId,
      curriculumId: CurriculumId.mussar.storageKey,
      activatedAt: DateTime.utc(2026, 1, 1),
    );
    await seedCompletion(
      db,
      CompletionEventsCompanion.insert(
        profileId: profileId,
        curriculumId: CurriculumId.mussar.storageKey,
        sefariaRef: mussarLeafRef,
        stageId: 1,
        trackType: 'personal',
        trackId: Value(trackId),
        eventTimestamp: DateTime.utc(2026, 3, 15),
      ),
    );
    repo = _CountingUnionRepository(_DiskContentRepository());
  });

  test('lifetimeTotalsAcrossAllCurriculaProvider computes the header total '
      'WITHOUT permanently caching any curriculum (getContentForCurriculum is '
      'called ZERO times) — reverting to the lifetimeSummariesProvider-based '
      'implementation makes every one of the 9 curricula go through it instead '
      '(the R8 OOM path)', () async {
    final container = ProviderContainer(
      overrides: [
        userDatabaseProvider.overrideWithValue(db),
        contentRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    final totals = await container.read(
      lifetimeTotalsAcrossAllCurriculaProvider(profileId).future,
    );

    expect(
      repo.fullyMaterialized,
      isEmpty,
      reason:
          'the header total must never permanently cache a curriculum\'s '
          'full content just to compute "X / N sections"',
    );
    expect(
      repo.transientlyLoaded,
      CurriculumId.values.map((c) => c.storageKey).toSet(),
      reason:
          'every curriculum still contributes to the union total (a '
          'curriculum the profile never touched still counts toward the '
          'denominator) — it is just never permanently retained',
    );

    // Invariant: the displayed numbers are unchanged by this rewiring.
    expect(
      totals.totalSections,
      70033,
      reason: 'the displayed denominator must stay exactly what it was',
    );
    expect(
      totals.learnedSections,
      1,
      reason: 'the single real completed Mussar leaf must still be counted',
    );
  });
}
