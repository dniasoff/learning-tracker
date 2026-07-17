/// Regression test for AUD-progress-03 — trackDualProgressMetricsProvider's
/// per-track DAO reads (completions, ledger entries, program enrollment)
/// were previously issued ONCE PER TRACK inside a sequential loop (Fowler
/// N+1). This test asserts they now come from profile-wide batched
/// providers that build EXACTLY ONCE regardless of how many active tracks
/// the profile has.
///
/// Mirrors the `ProviderObserver` pattern used by
/// `lifetime_knowledge_screen_test.dart`'s F13 assertion for the sibling
/// `lifetimeDataProvider` fix — same technique, extended to the per-track
/// dual-progress loop that F13 left un-batched.
///
/// AUD-progress-03 bounce (w4r1c20): the original version of this file
/// asserted only build COUNTS (exactly once, not once-per-track), never
/// post-commit FRESHNESS — so it stayed green even while the batched
/// providers cached a stale `.future` forever after their first build (see
/// `track_dual_progress_reactivity_test.dart`'s new `lifetimePercentage`
/// case for the direct staleness regression test). The second test below
/// closes that gap: it asserts the batched providers rebuild exactly once
/// MORE (still shared across tracks, not once-per-track) after a
/// `completionCommittedProvider` tick, and that the resulting
/// `lifetimePercentage` actually advances.
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
const _trackCurricula = ['mishnayos', 'chumash', 'bavli'];

/// Fake content repo returning a fixed leaf-item tree for whichever
/// curriculum is requested — the assertions here depend only on
/// provider-build call counts, not on per-curriculum content. No scope rows
/// are seeded for any track, so `_safeLoadLeavesForTrack` falls through to
/// `getContentForCurriculum` (mirrors `track_dual_progress_reactivity_test`'s
/// `_FakeContentRepo`).
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
/// hebrewTermsPreferenceProvider — domainTermLabelsFromRef only reads the
/// boolean value, which this override supplies directly (mirrors
/// `track_dual_progress_reactivity_test.dart`).
class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

/// Counts `didAddProvider` events for the three profile-wide batched
/// providers introduced by the AUD-progress-03 fix. Matches by the family's
/// debug `name` — same technique as the F13 `_CountingObserver` in
/// `lifetime_knowledge_screen_test.dart`.
final class _CountingObserver extends ProviderObserver {
  int completionsBuilds = 0;
  int ledgerBuilds = 0;
  int programsBuilds = 0;

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    final familyName = context.provider.from?.name;
    final providerName = context.provider.name;
    final id = familyName ?? providerName ?? context.provider.toString();
    if (id.contains('trackCompletionsByProfileProvider')) {
      completionsBuilds++;
    } else if (id.contains('trackLedgerEntriesByProfileProvider')) {
      ledgerBuilds++;
    } else if (id.contains('profileProgramsByProfileProvider')) {
      programsBuilds++;
    }
  }
}

Future<int> _seedTrackWithStage(
  UserDatabase db, {
  required String curriculumId,
}) async {
  final trackId = await seedTrack(
    db,
    profileId: _profileId,
    curriculumId: curriculumId,
  );
  await db
      .into(db.stageDefinitions)
      .insert(
        StageDefinitionsCompanion.insert(
          curriculumId: curriculumId,
          trackId: trackId,
          profileId: _profileId,
          stageOrder: 1,
          stageName: 'Learn',
          isDefault: const Value(true),
          schedule: const Value('{"type":"delay","delay_days":0}'),
        ),
      );
  return trackId;
}

Future<void> _seedLiveCompletion(
  UserDatabase db, {
  required String curriculumId,
  required int trackId,
  required String ref,
  required DateTime at,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: curriculumId,
      sefariaRef: ref,
      stageId: 1,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: at,
    ),
  );
}

ProviderContainer _makeContainer(UserDatabase db, ProviderObserver observer) =>
    ProviderContainer(
      observers: [observer],
      overrides: [
        userDatabaseProvider.overrideWith((ref) => db),
        contentRepositoryProvider.overrideWithValue(const _FakeContentRepo()),
        activeProfileIdProvider.overrideWith(() => _ProfileIdOverride()),
        useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
        // Hermetic: no Firestore/Firebase Auth in tests (matches the pattern
        // in track_dual_progress_reactivity_test.dart).
        syncWriteFacadeProvider.overrideWithValue(null),
      ],
    );

void main() {
  group('AUD-progress-03 — trackDualProgressMetricsProvider N+1 batching', () {
    test('resolving 3 active tracks issues each batched provider exactly once '
        '(not once per track)', () async {
      // Single-test file: the db is created and closed within this test's
      // own scope rather than via setUp/tearDown (see
      // tool/check_inmemory_db_close.dart — TQ-6/AUD-t-gamification-04 wants
      // `<var>.close()`/`addTearDown(<var>.close)` reachable from the same
      // function-like scope as the `inMemoryDb()` call site).
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);

      for (final curriculumId in _trackCurricula) {
        await _seedTrackWithStage(db, curriculumId: curriculumId);
      }

      final observer = _CountingObserver();
      final container = _makeContainer(db, observer);
      addTearDown(container.dispose);

      final metrics = await container.read(
        trackDualProgressMetricsProvider(_profileId).future,
      );

      expect(metrics, hasLength(_trackCurricula.length));
      expect(
        observer.completionsBuilds,
        1,
        reason:
            'trackCompletionsByProfileProvider must be shared across all '
            '${_trackCurricula.length} per-track computations — '
            'AUD-progress-03 N+1 fix',
      );
      expect(
        observer.ledgerBuilds,
        1,
        reason:
            'trackLedgerEntriesByProfileProvider must be shared across '
            'all ${_trackCurricula.length} per-track computations — '
            'AUD-progress-03 N+1 fix',
      );
      expect(
        observer.programsBuilds,
        1,
        reason:
            'profileProgramsByProfileProvider must be shared across all '
            '${_trackCurricula.length} per-track computations — '
            'AUD-progress-03 N+1 fix',
      );
    });

    test('after a completionCommittedProvider tick, the 3 batched providers '
        'rebuild EXACTLY ONCE MORE (still shared, not once per track) and '
        'lifetimePercentage reflects the new completion — AUD-progress-03 '
        'bounce regression (w4r1c20)', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);

      final trackIds = <String, int>{};
      for (final curriculumId in _trackCurricula) {
        trackIds[curriculumId] = await _seedTrackWithStage(
          db,
          curriculumId: curriculumId,
        );
      }

      final observer = _CountingObserver();
      final container = _makeContainer(db, observer);
      addTearDown(container.dispose);

      // Keep the autoDispose family alive across both reads.
      final sub = container.listen(
        trackDualProgressMetricsProvider(_profileId),
        (_, __) {},
      );
      addTearDown(sub.close);

      final first = await container.read(
        trackDualProgressMetricsProvider(_profileId).future,
      );
      expect(first, hasLength(_trackCurricula.length));
      final firstMishnayos = first.firstWhere(
        (m) => m.curriculumId.storageKey == 'mishnayos',
      );
      expect(
        firstMishnayos.lifetimePercentage,
        0.0,
        reason: 'no completions seeded yet',
      );
      expect(observer.completionsBuilds, 1);
      expect(observer.ledgerBuilds, 1);
      expect(observer.programsBuilds, 1);

      // Seed a live completion directly in the DB — mirrors what the real
      // write path persists before it also ticks completionCommittedProvider.
      await _seedLiveCompletion(
        db,
        curriculumId: 'mishnayos',
        trackId: trackIds['mishnayos']!,
        ref: 'mishnayos_ref_0',
        at: DateTime.utc(2026, 6, 1),
      );

      // Signal reactive update — the provider must rebuild automatically.
      container.read(completionCommittedProvider.notifier).increment();
      await Future<void>.microtask(() {});

      final second = await container.read(
        trackDualProgressMetricsProvider(_profileId).future,
      );
      final secondMishnayos = second.firstWhere(
        (m) => m.curriculumId.storageKey == 'mishnayos',
      );

      expect(
        secondMishnayos.lifetimePercentage,
        greaterThan(firstMishnayos.lifetimePercentage),
        reason:
            'trackCompletionsByProfileProvider / '
            'trackLedgerEntriesByProfileProvider must re-fetch when '
            'completionCommittedProvider ticks — otherwise the parent '
            'rebuilds (per its own completionCommittedProvider watch) but '
            'reads stale cached children and lifetimePercentage never '
            'advances (AUD-progress-03 bounce)',
      );
      expect(secondMishnayos.lifetimePercentage, closeTo(1 / 5, 1e-9));

      // The other 2 tracks are untouched — sharing the batched providers
      // must not cross-contaminate one track's fresh data into another's.
      final secondChumash = second.firstWhere(
        (m) => m.curriculumId.storageKey == 'chumash',
      );
      expect(secondChumash.lifetimePercentage, 0.0);
    });
  });
}
