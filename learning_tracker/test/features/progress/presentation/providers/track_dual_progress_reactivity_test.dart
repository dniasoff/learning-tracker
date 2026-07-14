/// Regression test for Fix 3 — trackDualProgressMetricsProvider must rebuild
/// when completionCommittedProvider increments.
///
/// Before the fix, the provider did not watch completionCommittedProvider, so
/// the dashboard card would not refresh after a live completion.
///
/// Fix 3 — Progress Aggregator L1+L2 remediation (2026-05-20).
///
/// AUD-t-progress-06: the previous version of this file overrode
/// trackDualProgressMetricsProvider's own body with a stub that
/// independently re-implemented the `ref.watch<int>(completionCommittedProvider)`
/// dependency — so the real body in lifetime_knowledge_providers.dart was
/// never exercised and deleting the real watch would not have failed this
/// file. This version drives the REAL, unmodified provider over a real
/// in-memory DB (mirrors recent_activity_reactivity_test.dart's pattern):
/// only `userDatabaseProvider`, `activeProfileIdProvider`, and
/// `contentRepositoryProvider` (the leaf-content source) are overridden.
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
const _curriculumKey = 'mishnayos';
const _leafCount = 10;
final _activatedAt = DateTime.utc(2026, 1, 1);

/// Fake content repository returning a fixed leaf-item tree for
/// [_curriculumKey] — mirrors the pattern used by
/// curriculum_pace_status_provider_test.dart. No scope rows are seeded for
/// the track, so trackDualProgressMetricsProvider's `_safeLoadLeavesForTrack`
/// helper falls through to `getContentForCurriculum`.
class _FakeContentRepo implements ContentRepository {
  const _FakeContentRepo();

  List<ContentItem> get _items => List.generate(
    _leafCount,
    (i) => ContentItem(
      curriculumId: _curriculumKey,
      sefariaRef: 'ref_$i',
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
  ) async => _items;

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

/// Avoids the SharedPreferences plugin dependency of the real
/// hebrewTermsPreferenceProvider — domainTermLabelsFromRef only reads the
/// boolean value, which this override supplies directly.
class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

Future<void> _seedStage(UserDatabase db, {required int trackId}) async {
  await db
      .into(db.stageDefinitions)
      .insert(
        StageDefinitionsCompanion.insert(
          curriculumId: _curriculumKey,
          trackId: trackId,
          profileId: _profileId,
          stageOrder: 1,
          stageName: 'Learn',
          isDefault: const Value(true),
          schedule: const Value('{"type":"delay","delay_days":0}'),
        ),
      );
}

Future<void> _seedLiveCompletion(
  UserDatabase db,
  int trackId,
  DateTime at, {
  String ref = 'ref_0',
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumKey,
      sefariaRef: ref,
      stageId: 1,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: at,
    ),
  );
}

ProviderContainer _makeContainer(UserDatabase db) => ProviderContainer(
  overrides: [
    userDatabaseProvider.overrideWith((ref) => db),
    activeProfileIdProvider.overrideWith(() => _ProfileIdOverride()),
    contentRepositoryProvider.overrideWithValue(const _FakeContentRepo()),
    useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
    // Hermetic: no Firestore/Firebase Auth in tests (matches the pattern in
    // dashboard_completion_percentage_test.dart, which also drives
    // TrackProgressService's real provider tree over an in-memory DB).
    syncWriteFacadeProvider.overrideWithValue(null),
  ],
);

void main() {
  group('trackDualProgressMetricsProvider — reactivity (Fix 3)', () {
    late UserDatabase db;
    late int trackId;

    setUp(() async {
      db = inMemoryDb();
      await seedProfile(db);
      trackId = await seedTrack(
        db,
        profileId: _profileId,
        curriculumId: _curriculumKey,
        activatedAt: _activatedAt,
      );
      await _seedStage(db, trackId: trackId);
    });

    tearDown(() => db.close());

    test(
      'reflects a new completion after completionCommittedProvider tick '
      '(real provider body, no override of the provider under test)',
      () async {
        final container = _makeContainer(db);
        addTearDown(container.dispose);

        // Keep the autoDispose family alive across both reads.
        final sub = container.listen(
          trackDualProgressMetricsProvider(_profileId),
          (_, __) {},
        );
        addTearDown(sub.close);

        // Initial read: no completions yet → 0% current-cycle progress.
        final first = await container.read(
          trackDualProgressMetricsProvider(_profileId).future,
        );
        expect(first, hasLength(1));
        expect(
          first.single.currentCyclePercentage,
          0.0,
          reason: 'no completions seeded yet',
        );

        // Seed a live completion directly in the DB — mirrors what the real
        // write path persists before it also ticks completionCommittedProvider.
        await _seedLiveCompletion(db, trackId, DateTime.utc(2026, 6, 1));

        // Signal reactive update — the provider must rebuild automatically.
        container.read(completionCommittedProvider.notifier).increment();
        await Future<void>.microtask(() {});

        final second = await container.read(
          trackDualProgressMetricsProvider(_profileId).future,
        );

        expect(
          second.single.currentCyclePercentage,
          greaterThan(first.single.currentCyclePercentage),
          reason:
              'trackDualProgressMetricsProvider must reflect the new '
              'completion written between reads without requiring a manual '
              'refresh; only completionCommittedProvider.notifier.increment() '
              'was called',
        );
        expect(second.single.currentCyclePercentage, closeTo(0.1, 1e-9));
      },
    );
  });
}
