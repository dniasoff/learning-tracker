/// F4 regression tests for [curriculumPaceStatusProvider].
///
/// Verifies that bulk-marked completions (sentinel date 2000-01-01) are
/// excluded from live velocity so that a fully-bulk-marked track does not
/// produce a phantom "ahead by N days" result on day 1.
///
/// Scenarios tested:
/// 1. Mishnayos regression: track started today, 1336 bulk-baseline, 0 live →
///    graceWindow (no phantom ahead/behind).
/// 2. Track started 30 days ago, target 100 days from start, 1000 baseline +
///    100 live → correct status computed (ahead in this fixture).
/// 3. Same setup but only 10 live completions → behind.
/// 4. No goal → provider returns null.
@Tags(['progress', 'pace', 'f4_regression'])
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
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/services/pace_calculator.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';

import '../../../../helpers/drift_memory.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _profileId = 1;
const _curriculumKey = 'mishnayos';

// Reference local-day midnight used as "today" in all fixtures.
final _today = DateTime(2026, 5, 20);

// Sentinel date used by BulkMarkCompletionUseCase.
final _sentinelDate = DateTime.utc(2000, 1, 1);

// ---------------------------------------------------------------------------
// Fake content repository — returns a fixed count of leaf items.
// ---------------------------------------------------------------------------

class _FakeContentRepo implements ContentRepository {
  const _FakeContentRepo(this._leafCount);
  final int _leafCount;

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

// ---------------------------------------------------------------------------
// ActiveProfileId override
// ---------------------------------------------------------------------------

class _ProfileIdOverride extends ActiveProfileId {
  _ProfileIdOverride(this._id);
  final int _id;
  @override
  int build() => _id;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a ProviderContainer wired to an in-memory DB, a fixed content tree,
/// and a pinned clock.
ProviderContainer _container({
  required UserDatabase db,
  required int leafCount,
  required DateTime today,
}) {
  return ProviderContainer(
    overrides: [
      userDatabaseProvider.overrideWithValue(db),
      contentRepositoryProvider.overrideWithValue(_FakeContentRepo(leafCount)),
      activeProfileIdProvider.overrideWith(
        () => _ProfileIdOverride(_profileId),
      ),
      clockProvider.overrideWith((ref) => today),
    ],
  );
}

/// Seeds a bulk-baseline completion with the sentinel date (2000-01-01).
Future<void> _seedBulk(
  UserDatabase db, {
  required int trackId,
  required String ref,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumKey,
      sefariaRef: ref,
      stageId: 1,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: _sentinelDate,
    ),
  );
}

/// Seeds a live completion at the given timestamp for a specific stage.
Future<void> _seedLive(
  UserDatabase db, {
  required int trackId,
  required String ref,
  required DateTime at,
  int stageId = 1,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumKey,
      sefariaRef: ref,
      stageId: stageId,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: at,
    ),
  );
}

/// Seeds a deadline goal for [trackId].
Future<void> _seedGoal(
  UserDatabase db, {
  required int trackId,
  required DateTime targetDate,
  required DateTime createdAt,
}) async {
  await db
      .into(db.goals)
      .insert(
        GoalsCompanion.insert(
          profileId: _profileId,
          curriculumId: _curriculumKey,
          trackId: trackId,
          targetDate: Value(targetDate),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late UserDatabase db;
  late ProviderContainer container;

  tearDown(() {
    container.dispose();
    db.close();
  });

  // -------------------------------------------------------------------------
  // 1 — Mishnayos regression: full bulk baseline, 0 live → graceWindow
  // -------------------------------------------------------------------------
  test(
    'Mishnayos regression: 1336 bulk + 0 live on day 1 → graceWindow, no phantom ahead',
    () async {
      db = inMemoryDb();
      await seedProfile(db);

      // Track activated today.
      final trackId = await seedTrack(
        db,
        profileId: _profileId,
        curriculumId: _curriculumKey,
        activatedAt: _today,
      );

      // Seed 1336 bulk completions with sentinel date 2000-01-01.
      for (var i = 0; i < 1336; i++) {
        await _seedBulk(db, trackId: trackId, ref: 'ref_$i');
      }

      // Goal: 365 days from trackStart.
      await _seedGoal(
        db,
        trackId: trackId,
        targetDate: _today.add(const Duration(days: 365)),
        createdAt: _today,
      );

      container = _container(db: db, leafCount: 1336, today: _today);

      final result = await container.read(
        curriculumPaceStatusProvider(_curriculumKey).future,
      );

      expect(result, isNotNull);
      expect(
        result!.paceStatus,
        ProgressPaceStatus.graceWindow,
        reason:
            'Day 0 is always graceWindow — bulk entries must not leak into '
            'live velocity and inflate paceVariance',
      );
      expect(result.bulkBaseline, 1336);
      expect(result.liveProgress, 0);
      expect(result.paceVariance, 0.0);
      // Critically: must NOT be ProgressPaceStatus.ahead
      expect(result.paceStatus, isNot(ProgressPaceStatus.ahead));
    },
  );

  // -------------------------------------------------------------------------
  // 2 — 30 days elapsed, 1000 baseline + 100 live → ahead
  //     totalItems=1336, baseline=1336 (all bulk), target=100 days from start,
  //     BUT in this scenario totalItems=200 so remaining=200-1000 would be
  //     negative… let's use a more realistic fixture:
  //     totalItems=1336, bulkBaseline=1000, remaining=336, track=100 days
  //     required=336/100=3.36/day, elapsed=30, expected=3.36*30=100.8
  //     live=100 → paceVariance = 100-100.8 = -0.8 → onTrack (within 1-day margin of 3.36)
  //     To get "ahead", bump live=150 → paceVariance=49.2 > requiredVelocity(3.36)→ahead
  // -------------------------------------------------------------------------
  test(
    '30 days elapsed, 1000 bulk baseline, 150 live out of 1336 → ahead',
    () async {
      db = inMemoryDb();
      await seedProfile(db);

      final trackStart = _today.subtract(const Duration(days: 30));
      final trackId = await seedTrack(
        db,
        profileId: _profileId,
        curriculumId: _curriculumKey,
        activatedAt: trackStart,
      );

      // 1000 bulk completions (sentinel date).
      for (var i = 0; i < 1000; i++) {
        await _seedBulk(db, trackId: trackId, ref: 'ref_$i');
      }

      // 150 live completions dated after trackStart.
      for (var i = 0; i < 150; i++) {
        await _seedLive(
          db,
          trackId: trackId,
          ref: 'live_$i',
          at: trackStart.add(Duration(days: i % 30 + 1)),
        );
      }

      // Goal: 100 days from trackStart (i.e. 70 days from today).
      await _seedGoal(
        db,
        trackId: trackId,
        targetDate: trackStart.add(const Duration(days: 100)),
        createdAt: trackStart,
      );

      container = _container(db: db, leafCount: 1336, today: _today);

      final result = await container.read(
        curriculumPaceStatusProvider(_curriculumKey).future,
      );

      expect(result, isNotNull);
      expect(result!.liveProgress, 150);
      expect(result.bulkBaseline, 1000);
      // required = (1336-1000)/100 = 3.36/day
      // expected = 3.36 * 30 = 100.8
      // paceVariance = 150 - 100.8 = 49.2  → > requiredVelocity(3.36) → ahead
      expect(
        result.paceStatus,
        ProgressPaceStatus.ahead,
        reason: '150 live items vs 100.8 expected (3.36/day * 30 days) → ahead',
      );
    },
  );

  // -------------------------------------------------------------------------
  // 3 — Same setup but only 10 live → behind
  // -------------------------------------------------------------------------
  test(
    '30 days elapsed, 1000 bulk baseline, 10 live out of 1336 → behind',
    () async {
      db = inMemoryDb();
      await seedProfile(db);

      final trackStart = _today.subtract(const Duration(days: 30));
      final trackId = await seedTrack(
        db,
        profileId: _profileId,
        curriculumId: _curriculumKey,
        activatedAt: trackStart,
      );

      // 1000 bulk completions.
      for (var i = 0; i < 1000; i++) {
        await _seedBulk(db, trackId: trackId, ref: 'ref_$i');
      }

      // Only 10 live completions.
      for (var i = 0; i < 10; i++) {
        await _seedLive(
          db,
          trackId: trackId,
          ref: 'live_$i',
          at: trackStart.add(Duration(days: i + 1)),
        );
      }

      await _seedGoal(
        db,
        trackId: trackId,
        targetDate: trackStart.add(const Duration(days: 100)),
        createdAt: trackStart,
      );

      container = _container(db: db, leafCount: 1336, today: _today);

      final result = await container.read(
        curriculumPaceStatusProvider(_curriculumKey).future,
      );

      expect(result, isNotNull);
      expect(result!.liveProgress, 10);
      expect(result.bulkBaseline, 1000);
      // required = 3.36/day, expected = 100.8
      // paceVariance = 10 - 100.8 = -90.8 → < -3.36 → behind
      expect(
        result.paceStatus,
        ProgressPaceStatus.behind,
        reason: '10 live items vs 100.8 expected (3.36/day * 30 days) → behind',
      );
    },
  );

  // -------------------------------------------------------------------------
  // 4 — No goal → returns null
  // -------------------------------------------------------------------------
  test('no goal → provider returns null', () async {
    db = inMemoryDb();
    await seedProfile(db);

    await seedTrack(db, profileId: _profileId, curriculumId: _curriculumKey);

    container = _container(db: db, leafCount: 100, today: _today);

    final result = await container.read(
      curriculumPaceStatusProvider(_curriculumKey).future,
    );

    expect(result, isNull);
  });

  // -------------------------------------------------------------------------
  // 5 — Chazara regression: distinct refs, NOT raw stage rows.
  //
  // 100-item / 100-day chazara track (stages learn + chazara1 + chazara2), at
  // day 50 with the first 50 items fully completed (each ref produces 3
  // completion_events rows = 150 rows total). On a row-counting numerator this
  // reported liveProgress=150 vs expected=50 → phantom "Ahead by ~100 days".
  // With distinct-ref counting, liveProgress=50 == expected=50 → onTrack.
  // -------------------------------------------------------------------------
  test(
    'chazara: 50 items fully done (150 stage rows) on day 50 of 100 → onTrack '
    '(distinct refs, not raw rows)',
    () async {
      db = inMemoryDb();
      await seedProfile(db);

      final trackStart = _today.subtract(const Duration(days: 50));
      final trackId = await seedTrack(
        db,
        profileId: _profileId,
        curriculumId: _curriculumKey,
        activatedAt: trackStart,
      );

      // 50 fully-completed items, each at 3 stages (learn + 2 chazaras),
      // spread across the elapsed window → 150 completion_events rows.
      for (var i = 0; i < 50; i++) {
        final at = trackStart.add(Duration(days: i + 1));
        for (final stageId in const [1, 2, 3]) {
          await _seedLive(
            db,
            trackId: trackId,
            ref: 'live_$i',
            at: at,
            stageId: stageId,
          );
        }
      }

      // Goal: 100 days from trackStart (50 days from today).
      await _seedGoal(
        db,
        trackId: trackId,
        targetDate: trackStart.add(const Duration(days: 100)),
        createdAt: trackStart,
      );

      container = _container(db: db, leafCount: 100, today: _today);

      final result = await container.read(
        curriculumPaceStatusProvider(_curriculumKey).future,
      );

      expect(result, isNotNull);
      // 150 stage rows must collapse to 50 distinct refs.
      expect(
        result!.liveProgress,
        50,
        reason:
            'liveProgress must count distinct sefariaRefs (50), not raw '
            'completion_events rows (150) — chazara stages multiply rows',
      );
      // required = 100/100 = 1/day, expected = 1 * 50 = 50, paceVariance = 0.
      expect(result.paceVariance, 0.0);
      expect(
        result.paceStatus,
        ProgressPaceStatus.onTrack,
        reason:
            '50 distinct items done vs 50 expected → onTrack; a row-based '
            'numerator would yield 150 vs 50 → phantom ahead',
      );
      expect(result.paceStatus, isNot(ProgressPaceStatus.ahead));
    },
  );

  // -------------------------------------------------------------------------
  // 6 — Chazara bulk baseline: distinct refs, not raw stage rows.
  //
  // Bulk-marking 40 items on a 3-stage track produced 120 rows → bulkBaseline
  // over-counted to 120 > totalItems(100), clamping requiredVelocity to a
  // degenerate 0. With distinct-ref counting, bulkBaseline = 40.
  // -------------------------------------------------------------------------
  test(
    'chazara: 40 items bulk-marked (120 stage rows) → bulkBaseline = 40, not 120',
    () async {
      db = inMemoryDb();
      await seedProfile(db);

      final trackId = await seedTrack(
        db,
        profileId: _profileId,
        curriculumId: _curriculumKey,
        activatedAt: _today,
      );

      // 40 bulk-marked items, each at 3 stages → 120 sentinel-dated rows.
      for (var i = 0; i < 40; i++) {
        for (final stageId in const [1, 2, 3]) {
          await db.completionEventDao.appendEvent(
            CompletionEventsCompanion.insert(
              profileId: _profileId,
              curriculumId: _curriculumKey,
              sefariaRef: 'ref_$i',
              stageId: stageId,
              trackType: 'personal',
              trackId: Value(trackId),
              eventTimestamp: _sentinelDate,
            ),
          );
        }
      }

      await _seedGoal(
        db,
        trackId: trackId,
        targetDate: _today.add(const Duration(days: 100)),
        createdAt: _today,
      );

      container = _container(db: db, leafCount: 100, today: _today);

      final result = await container.read(
        curriculumPaceStatusProvider(_curriculumKey).future,
      );

      expect(result, isNotNull);
      expect(
        result!.bulkBaseline,
        40,
        reason:
            'bulkBaseline must count distinct sefariaRefs (40), not raw rows '
            '(120) — 120 > totalItems(100) clamps requiredVelocity to 0',
      );
      // remaining = 100 - 40 = 60 over 100 days → requiredVelocity > 0 (non-degenerate).
      expect(result.requiredVelocity, greaterThan(0.0));
    },
  );
}
