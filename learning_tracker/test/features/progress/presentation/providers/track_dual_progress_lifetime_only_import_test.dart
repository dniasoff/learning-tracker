/// Regression test for the P1 found in run-10's device audit (emulator-5562):
/// `trackDualProgressMetricsProvider`'s `lifetimePercentage` read "0%" on the
/// Progress tab's per-track row for a curriculum that three OTHER screens
/// (Dashboard, Lifetime Knowledge, Add Lifetime Learning) correctly read as
/// 100% — reproducible even after a full app restart, ruling out a staleness/
/// cache-invalidation explanation.
///
/// Root cause: Settings → "Add Lifetime Learning" (`CompletionSource
/// .lifetimeOnly`) deliberately writes ledger rows with `trackId: null` (see
/// `lifetime_marking_screen.dart`'s `LedgerManualBatchItem(trackId: null,
/// ...)`) — it supports marking a curriculum the profile has no active track
/// for at all. `_computeTrackDualProgressMetric` (lifetime_knowledge_providers
/// .dart) computed `lifetimePercentage` from ONLY the trackId-keyed ledger/
/// completions maps, which structurally can never contain a `trackId: null`
/// row — silently excluding lifetime-only imports from a track's own
/// curriculum, contradicting `trackDualProgressMetricsProvider`'s own doc
/// comment ("all completion sources: live + bulk-prior + lifetime imports")
/// and the B1 three-tier policy table (`bulk_mark_completion_use_case.dart`),
/// which explicitly credits lifetimeOnly rows toward "Lifetime data".
///
/// `currentCyclePercentage` is untouched by the fix and is not exercised here
/// — it is a distinct, deliberately time-gated metric (`since:
/// track.activatedAt`) documented as correctly excluding lifetimeOnly rows.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart'
    show syncWriteFacadeProvider;

import '../../../../helpers/drift_memory.dart';

const _profileId = 1;
const _leafCount = 5;
const _curriculumId = 'chumash';

// Fixed instants — TQ-6 requires a hermetic clock under test/, never a
// live wall-clock read.
final _trackActivatedAt = DateTime.utc(2026, 1, 1);
final _lifetimeMarkCompletedAt = DateTime.utc(2000, 1, 1);

/// Fake content repo returning a fixed 5-leaf tree, all sharing the same
/// (level1, level2) pair — mirrors `track_dual_progress_metrics_batch_test`'s
/// `_FakeContentRepo`. A single `level2` ledger mark on that pair therefore
/// expands to ALL 5 leaves via `LifetimeTreeBuilder.computeLearnedLeafRefs`'s
/// scope-mark tier, giving a clean 5/5 = 100% when the fix works.
class _FakeContentRepo implements ContentRepository {
  const _FakeContentRepo();

  List<ContentItem> _itemsFor(CurriculumId curriculumId) => List.generate(
    _leafCount,
    (i) => ContentItem(
      curriculumId: curriculumId.storageKey,
      sefariaRef: '${curriculumId.storageKey}_ref_$i',
      displayNameEn: 'Item $i',
      displayNameHe: 'פריט $i',
      level1: 'Seder',
      level2: 'Masechta',
      level3: null,
      level4: null,
      isLeaf: true,
      sortOrder: i,
    ),
  );

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async => _itemsFor(curriculumId);

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(
    CurriculumId curriculumId,
  ) async => CurriculumHierarchyConfig(
    curriculumId: curriculumId.storageKey,
    levelLabels: const ['Seder', 'Masechta'],
    totalItems: _leafCount,
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
  }) async => _itemsFor(curriculumId);

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

/// Avoids the SharedPreferences plugin dependency of the real
/// hebrewTermsPreferenceProvider (mirrors the sibling batch test).
class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

ProviderContainer _makeContainer(UserDatabase db) => ProviderContainer(
  overrides: [
    userDatabaseProvider.overrideWith((ref) => db),
    contentRepositoryProvider.overrideWithValue(const _FakeContentRepo()),
    activeProfileIdProvider.overrideWith(() => _ProfileIdOverride()),
    useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
    // Hermetic: no Firestore/Firebase Auth in tests.
    syncWriteFacadeProvider.overrideWithValue(null),
  ],
);

/// Inserts a ledger row exactly as `lifetime_marking_screen.dart`'s
/// `_markSelections` does for a Settings → "Add Lifetime Learning" save:
/// `trackId: null`, a scope-level mark (not a single leaf), the bulk-prior
/// sentinel `completedAt`. See `LedgerManualBatchItem` /
/// `LearningLedgerRepositoryImpl.recordCompletionsBatch`.
Future<void> _seedLifetimeOnlyScopeMark(
  UserDatabase db, {
  required String curriculumId,
  required String entryScope,
  required String unitIdentifier,
}) async {
  await db.learningLedgerDao.insertEntry(
    LearningLedgerCompanion.insert(
      profileId: _profileId,
      curriculumId: curriculumId,
      entryScope: entryScope,
      unitIdentifier: unitIdentifier,
      unitDisplayNameHe: 'מסכת בדיקה',
      unitDisplayNameEn: 'Test Masechta',
      trackType: 'personal',
      trackId: const Value(null),
      completedAt: _lifetimeMarkCompletedAt,
      completionNumber: 1,
      markedBy: _profileId,
      isManual: const Value(true),
    ),
  );
}

void main() {
  group(
    'P1 (run-10/5562) — trackDualProgressMetricsProvider.lifetimePercentage '
    'must count trackId-less lifetime-only imports for the track\'s own '
    'curriculum',
    () {
      test('a lifetime-only scope mark covering the whole track content '
          'raises lifetimePercentage to 100% — the app\'s red demo before '
          'the fix landed', () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);
        await seedTrack(
          db,
          profileId: _profileId,
          curriculumId: _curriculumId,
          activatedAt: _trackActivatedAt,
        );

        final container = _makeContainer(db);
        addTearDown(container.dispose);

        // Keep the autoDispose family (and its batched-provider children)
        // alive across both reads — mirrors track_dual_progress_metrics_
        // batch_test.dart's staleness-regression case. Without this, the
        // provider tree can dispose and rebuild fresh on the second read
        // regardless of the fix, which would test nothing.
        final sub = container.listen(
          trackDualProgressMetricsProvider(_profileId),
          (_, __) {},
        );
        addTearDown(sub.close);

        final before = await container.read(
          trackDualProgressMetricsProvider(_profileId).future,
        );
        final beforeMetric = before.single;
        expect(
          beforeMetric.lifetimePercentage,
          0.0,
          reason: 'no completions or ledger rows seeded yet',
        );
        expect(
          beforeMetric.currentCyclePercentage,
          0.0,
          reason: 'currentCyclePercentage is out of scope for this fix',
        );

        // Settings → "Add Lifetime Learning" writing a level2 (masechta)
        // scope mark with trackId: null — covers all 5 fake leaves via
        // LifetimeTreeBuilder's scope-mark tier.
        await _seedLifetimeOnlyScopeMark(
          db,
          curriculumId: _curriculumId,
          entryScope: 'level2',
          unitIdentifier: 'Seder|Masechta',
        );

        // Signal reactive update exactly as the real write path does after
        // a ledger insert — the batched curriculum-keyed providers each
        // watch completionCommittedProvider (see lifetime_knowledge_
        // providers.dart) specifically so this tick forces a re-fetch
        // instead of serving their first build's cached .future forever.
        container.read(completionCommittedProvider.notifier).increment();
        await Future<void>.microtask(() {});

        final after = await container.read(
          trackDualProgressMetricsProvider(_profileId).future,
        );
        final afterMetric = after.single;

        expect(
          afterMetric.lifetimePercentage,
          1.0,
          reason:
              'a lifetime-only import (trackId: null) covering this '
              "track's own curriculum scope must be counted toward "
              'lifetimePercentage — its own doc comment promises "all '
              'completion sources (live + bulk-prior + lifetime '
              'imports)", and the B1 policy table credits lifetimeOnly '
              'toward "Lifetime data". Before the fix this read 0.0 — '
              'exactly the run-10/5562 finding.',
        );
        expect(
          afterMetric.currentCyclePercentage,
          0.0,
          reason:
              'currentCyclePercentage must stay untouched by this fix — '
              'its trackAchievement tier deliberately excludes '
              'lifetimeOnly rows, and that is a separate, documented '
              'design decision this fix must not disturb',
        );
      });

      test('a lifetime-only import for a DIFFERENT curriculum does not leak '
          'into this track\'s lifetimePercentage', () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);
        await seedTrack(
          db,
          profileId: _profileId,
          curriculumId: _curriculumId,
          activatedAt: _trackActivatedAt,
        );

        await _seedLifetimeOnlyScopeMark(
          db,
          curriculumId: 'bavli',
          entryScope: 'level2',
          unitIdentifier: 'Seder|Masechta',
        );

        final container = _makeContainer(db);
        addTearDown(container.dispose);

        final metrics = await container.read(
          trackDualProgressMetricsProvider(_profileId).future,
        );

        expect(
          metrics.single.lifetimePercentage,
          0.0,
          reason:
              'the curriculum-keyed union must be scoped to THIS track\'s '
              'curriculumId — a lifetime-only import for an unrelated '
              'curriculum must not inflate this track\'s percentage',
        );
      });
    },
  );

  group('run-10 acceptance sweep (5562) — the Progress-tab metrics list is '
      'ACTIVE-only (a deleted track must not appear)', () {
    test('a track the user deleted is excluded from '
        'trackDualProgressMetricsProvider', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);

      // One ACTIVE track (chumash) …
      await seedTrack(
        db,
        profileId: _profileId,
        curriculumId: _curriculumId,
        activatedAt: _trackActivatedAt,
      );
      // … and one DELETED track (mishnayos) for the same profile. The user
      // removed this via Manage Tracks; it stays in the table (state='deleted')
      // for the sync engine, but it must never surface in the UI's ACTIVE list.
      await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: _profileId,
              curriculumId: 'mishnayos',
              stateChangedAt: _trackActivatedAt,
              activatedAt: _trackActivatedAt,
              state: const Value('deleted'),
            ),
          );

      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final metrics = await container.read(
        trackDualProgressMetricsProvider(_profileId).future,
      );

      // Only the active chumash track — pre-fix this used getAllForProfile()
      // and returned BOTH, so the deleted mishnayos track showed under the
      // Progress tab's "ACTIVE TRACKS" header at 0%/0%.
      expect(
        metrics.map((m) => m.curriculumId).toList(),
        [CurriculumId.chumash],
        reason:
            'trackDualProgressMetricsProvider must use the active-only query '
            '(getActiveTracksForProfile), matching Manage Tracks and its own '
            '"one per active track" doc comment — a deleted track must not '
            'appear in the Progress-tab list',
      );
    });
  });
}
