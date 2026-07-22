/// R8 (OOM) red-demo — device-free proof that the items-learned / lifetime-view
/// aggregates no longer force-materialize every curriculum.
///
/// R8 was a CONFIRMED P0: opening the Learn / Lifetime-Knowledge progress
/// aggregate loaded ALL 9 curricula's full content (~70k ContentItems) into
/// ContentRepository's permanent in-memory cache, OOM-killing the process on a
/// 512 MB heap. The fix (Part A) reorders the two service functions so a
/// curriculum with nothing learned returns null BEFORE `getContentForCurriculum`
/// is ever called — so only the ACTIVE curricula materialize.
///
/// This test wraps a real (disk-backed) [ContentRepositoryImpl] in a counting
/// proxy that records how many DISTINCT curricula are force-materialized during
/// ONE aggregate computation, for a profile with track completions in EXACTLY
/// ONE curriculum (Mussar). It mirrors what
/// `itemsLearnedSummariesProvider` / `lifetimeViewSummariesProvider` do —
/// `CurriculumId.values.map(compute…)` then drop nulls.
///
/// WITH the fix: materialized == {mussar} (1).
/// WITHOUT the fix (revert the two reorders in items_learned_providers.dart):
/// each of the 9 curricula is loaded before its empty-completions check, so
/// materialized.length == 9 — the OOM path.
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/content_repository_impl.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart';

import '../../../../helpers/drift_memory.dart';

/// Real repository backed by the on-disk bundled assets (rootBundle is empty in
/// the test environment).
class _DiskContentRepository extends ContentRepositoryImpl {
  @override
  Future<String> loadRawContentJson(String key) =>
      File('assets/content/hierarchy/$key.json').readAsString();
}

/// Delegating proxy that records the DISTINCT curricula for which the full
/// content list is force-materialized via [getContentForCurriculum].
class _CountingContentRepository implements ContentRepository {
  _CountingContentRepository(this._inner);

  final ContentRepository _inner;

  /// storageKeys of every curriculum that had getContentForCurriculum called.
  final Set<String> materialized = <String>{};

  @override
  Future<List<ContentItem>> getContentForCurriculum(CurriculumId curriculumId) {
    materialized.add(curriculumId.storageKey);
    return _inner.getContentForCurriculum(curriculumId);
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
  late _CountingContentRepository repo;
  const profileId = 1;
  // A genuine Mussar leaf ref so the active curriculum yields a real learned
  // count (not just a materialization).
  const mussarLeafRef = 'Mesillat Yesharim 1:1';

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db); // profile id 1
    final trackId = await seedTrack(
      db,
      profileId: profileId,
      curriculumId: CurriculumId.mussar.storageKey,
      activatedAt: DateTime.utc(2026, 1, 1),
    );
    final stageId = await db.stageDao.insertStageDefinition(
      StageDefinitionsCompanion.insert(
        profileId: profileId,
        curriculumId: CurriculumId.mussar.storageKey,
        trackId: trackId,
        stageOrder: 1,
        stageName: 'Learn',
        schedule: const Value('{"type":"delay","delay_days":0}'),
      ),
    );
    await seedCompletion(
      db,
      CompletionEventsCompanion.insert(
        profileId: profileId,
        curriculumId: CurriculumId.mussar.storageKey,
        sefariaRef: mussarLeafRef,
        stageId: stageId,
        trackType: 'personal',
        trackId: Value(trackId),
        eventTimestamp: DateTime.utc(2026, 3, 15),
      ),
    );
    repo = _CountingContentRepository(_DiskContentRepository());
  });

  tearDown(() async => db.close());

  test('precondition: exactly Mussar has track completions', () async {
    final mussar = await db.completionDao.getCompletionsByTier(
      profileId: profileId,
      tier: CompletionTierFilter.trackAchievement,
      curriculumId: CurriculumId.mussar,
    );
    expect(mussar, isNotEmpty);
    for (final c in CurriculumId.values.where(
      (c) => c != CurriculumId.mussar,
    )) {
      final other = await db.completionDao.getCompletionsByTier(
        profileId: profileId,
        tier: CompletionTierFilter.trackAchievement,
        curriculumId: c,
      );
      expect(other, isEmpty, reason: '${c.storageKey} should have none');
    }
  });

  test('itemsLearned aggregate force-materializes ONLY the 1 active curriculum '
      '(pre-fix this was all 9 — the R8 OOM path)', () async {
    final summaries = <CurriculumCompletionSummary>[];
    for (final c in CurriculumId.values) {
      final s = await computeItemsLearnedSummary(
        db: db,
        repo: repo,
        curriculum: c,
        profileId: profileId,
      );
      if (s != null) summaries.add(s);
    }

    expect(
      repo.materialized,
      {CurriculumId.mussar.storageKey},
      reason:
          'only the active curriculum may be force-loaded; reverting the '
          'Part A reorder makes this all 9 CurriculumId.values',
    );
    expect(repo.materialized.length, 1);
    expect(summaries.map((s) => s.curriculumId).toList(), [
      CurriculumId.mussar,
    ]);
    expect(summaries.single.learnedLeafCount, 1);
  });

  test(
    'lifetimeView aggregate force-materializes ONLY the 1 active curriculum',
    () async {
      final summaries = <CurriculumCompletionSummary>[];
      for (final c in CurriculumId.values) {
        final s = await computeLifetimeViewSummary(
          db: db,
          repo: repo,
          curriculum: c,
          profileId: profileId,
        );
        if (s != null) summaries.add(s);
      }

      expect(repo.materialized, {CurriculumId.mussar.storageKey});
      expect(repo.materialized.length, 1);
      expect(summaries.map((s) => s.curriculumId).toList(), [
        CurriculumId.mussar,
      ]);
      expect(summaries.single.learnedLeafCount, 1);
    },
  );
}
