/// Integration tests for [dashboardTrackCompletionPercentageProvider] and
/// [dashboardCompletionPercentageProvider].
///
/// Every test drives the REAL providers through a [ProviderContainer] over an
/// in-memory Drift database.  There are NO mirror/helper functions that
/// re-implement the logic under test (Finding 3).
///
/// Finding 1 guard: the production code already scopes completions to the
/// track's curriculum via the DAO layer.  Tests below verify this invariant
/// so a future regression would fail the suite.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/stages/presentation/providers/stage_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

/// The profile ID seeded into every test database via [_seedProfile].
const _profileId = 1;

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Seeds a minimal account + learner profile (id = 1) into [db].
///
/// Required before any FK-constrained insert into completion_events or
/// curriculum_tracks.
Future<void> _seedProfile(UserDatabase db) async {
  final now = DateTime.utc(2026, 1, 1);
  final accountId = await db.into(db.accounts).insert(
    AccountsCompanion.insert(
      email: 'test@example.com',
      tier: 'localBorn',
      displayName: 'Test User',
      userMode: 'adult',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await db.into(db.learnerProfiles).insert(
    LearnerProfilesCompanion.insert(
      accountId: accountId,
      displayName: 'Test User',
      mode: 'adult',
      createdAt: now,
      updatedAt: now,
    ),
  );
}

/// Creates a track row and returns its auto-generated id.
Future<int> _insertTrack(
  UserDatabase db, {
  required String curriculumId,
  int profileId = _profileId,
}) async {
  return db.into(db.curriculumTracks).insert(
    CurriculumTracksCompanion.insert(
      profileId: profileId,
      curriculumId: curriculumId,
      trackType: 'personal',
      activatedAt: DateTime.utc(2026, 1, 1),
      isActive: const Value(true),
    ),
  );
}

/// Inserts a stage definition row with an explicit [stageOrder].
///
/// [autoIncrementOffset] is NOT used — the auto-increment id will differ from
/// [stageOrder] whenever more than one row has been inserted, which is the
/// deliberate id≠stageOrder discipline required by the task brief.
Future<void> _insertStage(
  UserDatabase db, {
  required int trackId,
  required int stageOrder,
  required String stageName,
  required String curriculumId,
  int profileId = _profileId,
}) async {
  await db.into(db.stageDefinitions).insert(
    StageDefinitionsCompanion.insert(
      profileId: profileId,
      trackId: trackId,
      curriculumId: curriculumId,
      stageOrder: stageOrder,
      stageName: stageName,
      delayDays: 0,
    ),
  );
}

/// Records a completion event for the given [sefariaRef] + [stageOrder] pair.
///
/// [stageOrder] is what gets stored in [CompletionEvents.stageId] — the value
/// the dashboard providers look up against [StageDefinition.stageOrder].
Future<void> _insertCompletion(
  UserDatabase db, {
  required int trackId,
  required String curriculumId,
  required String sefariaRef,
  required int stageOrder,
  int profileId = _profileId,
  DateTime? completedAt,
}) async {
  final ts = completedAt ?? DateTime.utc(2026, 1, 1);
  await db.into(db.completionEvents).insert(
    CompletionEventsCompanion.insert(
      profileId: profileId,
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      stageId: stageOrder, // stored as the stageOrder value, NOT the row id
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: ts,
    ),
    mode: InsertMode.insertOrIgnore,
  );
}

/// Builds a [ProviderContainer] that:
/// - wires [userDatabaseProvider] → in-memory [db]
/// - fixes [activeProfileIdProvider] → [_profileId]
/// - fixes [completionCommittedProvider] → 0 (no rebuild needed in tests)
/// - stubs [syncEngineProvider] → null (no Firestore in tests)
/// - fixes [scopedItemCountProvider] for every [CurriculumId] to [totalItems]
///
/// The [globalStageRepositoryProvider] is NOT overridden; it resolves through
/// the real [StageDefinitionRepositoryImpl] backed by the in-memory DB.
ProviderContainer _makeContainer(
  UserDatabase db, {
  Map<CurriculumId, int> totalItemsBycurriculum = const {},
}) {
  return ProviderContainer(
    overrides: [
      userDatabaseProvider.overrideWithValue(db),
      activeProfileIdProvider.overrideWithValue(_profileId),
      syncEngineProvider.overrideWithValue(null),
      // Override scopedItemCountProvider for every CurriculumId so tests do
      // not touch the content database.
      for (final curriculum in CurriculumId.values)
        scopedItemCountProvider(curriculum).overrideWith(
          (ref) => Future.value(totalItemsBycurriculum[curriculum] ?? 0),
        ),
    ],
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late UserDatabase db;

  setUp(() async {
    db = UserDatabase(NativeDatabase.memory());
    await _seedProfile(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── dashboardTrackCompletionPercentage ────────────────────────────────────

  group('dashboardTrackCompletionPercentageProvider', () {
    test('returns 0.0 when no completions exist', () async {
      final trackId = await _insertTrack(db, curriculumId: 'mishnayos');
      // Insert two stages; stageOrders 10 and 20 so id ≠ stageOrder.
      await _insertStage(
        db,
        trackId: trackId,
        stageOrder: 10,
        stageName: 'Learn',
        curriculumId: 'mishnayos',
      );
      await _insertStage(
        db,
        trackId: trackId,
        stageOrder: 20,
        stageName: 'Chazara',
        curriculumId: 'mishnayos',
      );

      final container = _makeContainer(
        db,
        totalItemsBycurriculum: {CurriculumId.mishnayos: 5},
      );
      addTearDown(container.dispose);

      final pct = await container.read(
        dashboardTrackCompletionPercentageProvider(trackId).future,
      );
      expect(pct, 0.0, reason: 'no completions → 0.0');
    });

    test('returns 0.0 when scopedItemCount is 0', () async {
      // Finding 1 edge case: zero-item track → 0.0.
      final trackId = await _insertTrack(db, curriculumId: 'mishnayos');
      await _insertStage(
        db,
        trackId: trackId,
        stageOrder: 1,
        stageName: 'Learn',
        curriculumId: 'mishnayos',
      );
      await _insertCompletion(
        db,
        trackId: trackId,
        curriculumId: 'mishnayos',
        sefariaRef: 'Mishnah Berakhot 1:1',
        stageOrder: 1,
      );

      // totalItems = 0 → provider must return 0.0 regardless of completions.
      final container = _makeContainer(
        db,
        totalItemsBycurriculum: {CurriculumId.mishnayos: 0},
      );
      addTearDown(container.dispose);

      final pct = await container.read(
        dashboardTrackCompletionPercentageProvider(trackId).future,
      );
      expect(pct, 0.0, reason: 'zero-item track must return 0.0');
    });

    test('item is NOT done when only learn stage is completed (partial)', () async {
      // Two required stages; only learn completed.
      final trackId = await _insertTrack(db, curriculumId: 'mishnayos');
      // Use high stageOrders so auto-increment id ≠ stageOrder.
      await _insertStage(
        db,
        trackId: trackId,
        stageOrder: 5,
        stageName: 'Learn',
        curriculumId: 'mishnayos',
      );
      await _insertStage(
        db,
        trackId: trackId,
        stageOrder: 7,
        stageName: 'Chazara',
        curriculumId: 'mishnayos',
      );
      await _insertCompletion(
        db,
        trackId: trackId,
        curriculumId: 'mishnayos',
        sefariaRef: 'Mishnah Berakhot 1:1',
        stageOrder: 5, // only learn
      );

      final container = _makeContainer(
        db,
        totalItemsBycurriculum: {CurriculumId.mishnayos: 3},
      );
      addTearDown(container.dispose);

      final pct = await container.read(
        dashboardTrackCompletionPercentageProvider(trackId).future,
      );
      expect(pct, 0.0, reason: 'item missing chazara stage must not be counted');
    });

    test('item IS done only when ALL required stages have completions', () async {
      // Three stages with stageOrders 2, 4, 6 so auto-increment ids differ.
      final trackId = await _insertTrack(db, curriculumId: 'mishnayos');
      await _insertStage(
        db,
        trackId: trackId,
        stageOrder: 2,
        stageName: 'Learn',
        curriculumId: 'mishnayos',
      );
      await _insertStage(
        db,
        trackId: trackId,
        stageOrder: 4,
        stageName: 'Chazara 1',
        curriculumId: 'mishnayos',
      );
      await _insertStage(
        db,
        trackId: trackId,
        stageOrder: 6,
        stageName: 'Chazara 2',
        curriculumId: 'mishnayos',
      );

      const ref1 = 'Mishnah Berakhot 1:1';
      // ref1: all three stages done.
      await _insertCompletion(
        db,
        trackId: trackId,
        curriculumId: 'mishnayos',
        sefariaRef: ref1,
        stageOrder: 2,
        completedAt: DateTime.utc(2026, 1, 1),
      );
      await _insertCompletion(
        db,
        trackId: trackId,
        curriculumId: 'mishnayos',
        sefariaRef: ref1,
        stageOrder: 4,
        completedAt: DateTime.utc(2026, 1, 2),
      );
      await _insertCompletion(
        db,
        trackId: trackId,
        curriculumId: 'mishnayos',
        sefariaRef: ref1,
        stageOrder: 6,
        completedAt: DateTime.utc(2026, 1, 3),
      );

      const ref2 = 'Mishnah Berakhot 1:2';
      // ref2: only learn done (partial).
      await _insertCompletion(
        db,
        trackId: trackId,
        curriculumId: 'mishnayos',
        sefariaRef: ref2,
        stageOrder: 2,
        completedAt: DateTime.utc(2026, 1, 4),
      );

      final container = _makeContainer(
        db,
        totalItemsBycurriculum: {CurriculumId.mishnayos: 4},
      );
      addTearDown(container.dispose);

      final pct = await container.read(
        dashboardTrackCompletionPercentageProvider(trackId).future,
      );
      // 1 done / 4 total = 0.25
      expect(pct, closeTo(1 / 4, 0.0001),
          reason: 'only ref1 fully done; ref2 partial');
    });

    /// CRITICAL — Finding 1 guard (Option B, per-curriculum scoping).
    ///
    /// A completion event with curriculumId='mishnayos' must NOT be counted
    /// by a track whose curriculumId='bavli'.
    test(
        'completion under curriculum A is NOT counted by a track over curriculum B '
        '(Option-B regression guard — Finding 1)',
        () async {
      // Insert a mishnayos track + stage.
      final mishTrackId = await _insertTrack(db, curriculumId: 'mishnayos');
      await _insertStage(
        db,
        trackId: mishTrackId,
        stageOrder: 1,
        stageName: 'Learn',
        curriculumId: 'mishnayos',
      );
      // Insert a bavli track + stage.
      final bavliTrackId = await _insertTrack(db, curriculumId: 'bavli');
      await _insertStage(
        db,
        trackId: bavliTrackId,
        stageOrder: 1,
        stageName: 'Learn',
        curriculumId: 'bavli',
      );

      // Record a completion ONLY for the mishnayos track.
      await _insertCompletion(
        db,
        trackId: mishTrackId,
        curriculumId: 'mishnayos',
        sefariaRef: 'Mishnah Berakhot 1:1',
        stageOrder: 1,
      );

      final container = _makeContainer(
        db,
        totalItemsBycurriculum: {
          CurriculumId.mishnayos: 3,
          CurriculumId.bavli: 3,
        },
      );
      addTearDown(container.dispose);

      // Mishnayos track should see the completion (1/3).
      final mishPct = await container.read(
        dashboardTrackCompletionPercentageProvider(mishTrackId).future,
      );
      expect(mishPct, closeTo(1 / 3, 0.0001),
          reason: 'mishnayos track must count its own completion');

      // Bavli track must return 0.0 — the mishnayos completion must NOT bleed over.
      final bavliPct = await container.read(
        dashboardTrackCompletionPercentageProvider(bavliTrackId).future,
      );
      expect(bavliPct, 0.0,
          reason: 'bavli track must not count a mishnayos completion');
    });

    /// id ≠ stageOrder regression guard.
    ///
    /// If the provider accidentally uses the stage row's database id instead
    /// of stageOrder, this test will catch it because id ≥ 10 but the
    /// completions store stageOrder = 1.
    test('uses stageOrder (not stage row id) to match completions', () async {
      // Insert two unrelated stages first so the id auto-increments past 1.
      final dummyTrackId = await _insertTrack(db, curriculumId: 'bavli');
      await _insertStage(
        db,
        trackId: dummyTrackId,
        stageOrder: 1,
        stageName: 'Dummy A',
        curriculumId: 'bavli',
      );
      await _insertStage(
        db,
        trackId: dummyTrackId,
        stageOrder: 2,
        stageName: 'Dummy B',
        curriculumId: 'bavli',
      );

      // Now the real track: stageOrder = 1 but the auto-increment id ≥ 3.
      final trackId = await _insertTrack(db, curriculumId: 'mishnayos');
      await _insertStage(
        db,
        trackId: trackId,
        stageOrder: 1,
        stageName: 'Learn',
        curriculumId: 'mishnayos',
      );

      // Record completion using stageOrder=1.
      await _insertCompletion(
        db,
        trackId: trackId,
        curriculumId: 'mishnayos',
        sefariaRef: 'Mishnah Berakhot 1:1',
        stageOrder: 1, // matches stageOrder, NOT the db row id (≥3)
      );

      final container = _makeContainer(
        db,
        totalItemsBycurriculum: {CurriculumId.mishnayos: 1},
      );
      addTearDown(container.dispose);

      final pct = await container.read(
        dashboardTrackCompletionPercentageProvider(trackId).future,
      );
      // If provider used stage id (≥3) instead of stageOrder (1), pct = 0.0.
      expect(pct, closeTo(1.0, 0.0001),
          reason: 'provider must use stageOrder, not the stage DB row id');
    });
  });

  // ── dashboardCompletionPercentage ─────────────────────────────────────────

  group('dashboardCompletionPercentageProvider', () {
    test('returns 0.0 when no completions exist', () async {
      final container = _makeContainer(
        db,
        totalItemsBycurriculum: {CurriculumId.mishnayos: 10},
      );
      addTearDown(container.dispose);

      final pct = await container.read(
        dashboardCompletionPercentageProvider(CurriculumId.mishnayos).future,
      );
      expect(pct, 0.0, reason: 'no completions → 0.0');
    });

    test('returns 0.0 when scopedItemCount is 0', () async {
      // Even with a completion, zero totalItems → 0.0.
      final trackId = await _insertTrack(db, curriculumId: 'mishnayos');
      await _insertStage(
        db,
        trackId: trackId,
        stageOrder: 1,
        stageName: 'Learn',
        curriculumId: 'mishnayos',
      );
      await _insertCompletion(
        db,
        trackId: trackId,
        curriculumId: 'mishnayos',
        sefariaRef: 'Mishnah Berakhot 1:1',
        stageOrder: 1,
      );

      final container = _makeContainer(
        db,
        totalItemsBycurriculum: {CurriculumId.mishnayos: 0},
      );
      addTearDown(container.dispose);

      final pct = await container.read(
        dashboardCompletionPercentageProvider(CurriculumId.mishnayos).future,
      );
      expect(pct, 0.0, reason: 'zero totalItems → 0.0');
    });

    test('partial stage completion does not count the item', () async {
      // Track has two required stages; ref only has learn done.
      final trackId = await _insertTrack(db, curriculumId: 'mishnayos');
      await _insertStage(
        db,
        trackId: trackId,
        stageOrder: 3,
        stageName: 'Learn',
        curriculumId: 'mishnayos',
      );
      await _insertStage(
        db,
        trackId: trackId,
        stageOrder: 5,
        stageName: 'Chazara',
        curriculumId: 'mishnayos',
      );

      await _insertCompletion(
        db,
        trackId: trackId,
        curriculumId: 'mishnayos',
        sefariaRef: 'Mishnah Berakhot 1:1',
        stageOrder: 3, // learn only, chazara missing
      );

      final container = _makeContainer(
        db,
        totalItemsBycurriculum: {CurriculumId.mishnayos: 5},
      );
      addTearDown(container.dispose);

      final pct = await container.read(
        dashboardCompletionPercentageProvider(CurriculumId.mishnayos).future,
      );
      expect(pct, 0.0,
          reason: 'item missing chazara stage must not be counted');
    });

    test('counts item only when ALL required stages have completions', () async {
      final trackId = await _insertTrack(db, curriculumId: 'mishnayos');
      await _insertStage(
        db,
        trackId: trackId,
        stageOrder: 1,
        stageName: 'Learn',
        curriculumId: 'mishnayos',
      );
      await _insertStage(
        db,
        trackId: trackId,
        stageOrder: 2,
        stageName: 'Chazara',
        curriculumId: 'mishnayos',
      );

      const ref1 = 'Mishnah Berakhot 1:1'; // fully done
      await _insertCompletion(
        db,
        trackId: trackId,
        curriculumId: 'mishnayos',
        sefariaRef: ref1,
        stageOrder: 1,
        completedAt: DateTime.utc(2026, 1, 1),
      );
      await _insertCompletion(
        db,
        trackId: trackId,
        curriculumId: 'mishnayos',
        sefariaRef: ref1,
        stageOrder: 2,
        completedAt: DateTime.utc(2026, 1, 2),
      );

      const ref2 = 'Mishnah Berakhot 1:2'; // only learn done
      await _insertCompletion(
        db,
        trackId: trackId,
        curriculumId: 'mishnayos',
        sefariaRef: ref2,
        stageOrder: 1,
        completedAt: DateTime.utc(2026, 1, 3),
      );

      final container = _makeContainer(
        db,
        totalItemsBycurriculum: {CurriculumId.mishnayos: 5},
      );
      addTearDown(container.dispose);

      final pct = await container.read(
        dashboardCompletionPercentageProvider(CurriculumId.mishnayos).future,
      );
      // 1 done (ref1) / 5 total = 0.2
      expect(pct, closeTo(1 / 5, 0.0001),
          reason: 'only ref1 fully done; ref2 partial');
    });

    /// CRITICAL — Finding 1 guard (Option-B, per-curriculum scoping).
    ///
    /// A completion recorded under curriculumId='mishnayos' must NOT appear
    /// in the dashboardCompletionPercentage result for CurriculumId.bavli.
    test(
        'completion under curriculum A is NOT counted for curriculum B '
        '(Option-B regression guard — Finding 1)',
        () async {
      // Mishnayos track, fully-done item.
      final mishTrackId = await _insertTrack(db, curriculumId: 'mishnayos');
      await _insertStage(
        db,
        trackId: mishTrackId,
        stageOrder: 1,
        stageName: 'Learn',
        curriculumId: 'mishnayos',
      );
      await _insertCompletion(
        db,
        trackId: mishTrackId,
        curriculumId: 'mishnayos',
        sefariaRef: 'Mishnah Berakhot 1:1',
        stageOrder: 1,
      );

      final container = _makeContainer(
        db,
        totalItemsBycurriculum: {
          CurriculumId.mishnayos: 3,
          CurriculumId.bavli: 3,
        },
      );
      addTearDown(container.dispose);

      // Mishnayos should see 1/3.
      final mishPct = await container.read(
        dashboardCompletionPercentageProvider(CurriculumId.mishnayos).future,
      );
      expect(mishPct, closeTo(1 / 3, 0.0001),
          reason: 'mishnayos curriculum must count its own completion');

      // Bavli must stay at 0.0.
      final bavliPct = await container.read(
        dashboardCompletionPercentageProvider(CurriculumId.bavli).future,
      );
      expect(bavliPct, 0.0,
          reason: 'bavli curriculum must not count a mishnayos completion');
    });

    /// id ≠ stageOrder regression guard for curriculum-level provider.
    test('uses stageOrder (not stage row id) to match completions', () async {
      // Insert dummy stages first to push the auto-increment id forward.
      final dummyTrackId = await _insertTrack(db, curriculumId: 'bavli');
      await _insertStage(
        db,
        trackId: dummyTrackId,
        stageOrder: 1,
        stageName: 'Dummy A',
        curriculumId: 'bavli',
      );
      await _insertStage(
        db,
        trackId: dummyTrackId,
        stageOrder: 2,
        stageName: 'Dummy B',
        curriculumId: 'bavli',
      );

      // Real mishnayos track: stageOrder=1 but auto-increment id ≥ 3.
      final trackId = await _insertTrack(db, curriculumId: 'mishnayos');
      await _insertStage(
        db,
        trackId: trackId,
        stageOrder: 1,
        stageName: 'Learn',
        curriculumId: 'mishnayos',
      );

      await _insertCompletion(
        db,
        trackId: trackId,
        curriculumId: 'mishnayos',
        sefariaRef: 'Mishnah Berakhot 1:1',
        stageOrder: 1, // matches stageOrder, NOT db id (≥3)
      );

      final container = _makeContainer(
        db,
        totalItemsBycurriculum: {CurriculumId.mishnayos: 1},
      );
      addTearDown(container.dispose);

      final pct = await container.read(
        dashboardCompletionPercentageProvider(CurriculumId.mishnayos).future,
      );
      // If provider used id (≥3) instead of stageOrder (1) → 0.0.
      expect(pct, closeTo(1.0, 0.0001),
          reason: 'must use stageOrder, not the stage DB row id');
    });
  });
}
