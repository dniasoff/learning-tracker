/// Integration tests for [dashboardTrackCompletionPercentageProvider] and
/// [dashboardCompletionPercentageProvider].
///
/// Every test drives the REAL providers through a [ProviderContainer] over an
/// fake Firestore database. There are NO mirror/helper functions that
/// re-implement the logic under test (Finding 3).
///
/// Finding 1 guard: the production code already scopes completions to the
/// track's curriculum via the DAO layer.  Tests below verify this invariant
/// so a future regression would fail the suite.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

const _uid = 'dashboard-completion-test';

AccountFirebaseHandles _handles(FakeFirebaseFirestore firestore) {
  return AccountFirebaseHandles(
    app: _MockFirebaseApp(),
    firestore: firestore,
    auth: _MockFirebaseAuth(),
    uid: _uid,
  );
}

// ── Constants ─────────────────────────────────────────────────────────────────

/// The profile document id seeded into every test database via [_seedProfile].
const _profileId = '01J6Q2H4A8M7K3P9R5T6V8WXYB';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Seeds a minimal account + learner profile (id = 1) into [db].
///
/// Required before any FK-constrained insert into completion_events or
/// curriculum_tracks.
Future<void> _seedProfile(FakeFirebaseFirestore firestore) async {
  await seedAccount(firestore, uid: _uid);
  await seedProfile(
    firestore,
    uid: _uid,
    profileId: _profileId,
    mode: ProfileMode.adult,
  );
}

/// Creates a track row and returns its auto-generated id.
Future<CurriculumId> _insertTrack(
  FakeFirebaseFirestore firestore, {
  required String curriculumId,
  String profileId = _profileId,
}) async {
  final curriculum = CurriculumId.fromStorageKey(curriculumId);
  if (curriculum == null) {
    throw ArgumentError.value(curriculumId, 'curriculumId');
  }
  await seedTrack(
    firestore,
    uid: _uid,
    profileId: profileId,
    curriculumId: curriculum,
  );
  return curriculum;
}

/// Inserts a stage definition row with an explicit [stageOrder].
///
/// [autoIncrementOffset] is NOT used — the auto-increment id will differ from
/// [stageOrder] whenever more than one row has been inserted, which is the
/// deliberate id≠stageOrder discipline required by the task brief.
Future<void> _insertStage(
  FakeFirebaseFirestore firestore, {
  Object? trackId,
  required int stageOrder,
  required String stageName,
  required String curriculumId,
  String profileId = _profileId,
}) async {
  final curriculum = CurriculumId.fromStorageKey(curriculumId);
  if (curriculum == null) {
    throw ArgumentError.value(curriculumId, 'curriculumId');
  }
  await seedStageDefinitions(
    firestore,
    uid: _uid,
    profileId: profileId,
    curriculumId: curriculum,
    stages: [
      StageDefinition(
        curriculumId: curriculum,
        stageOrder: stageOrder,
        stageName: stageName,
        delayDays: 0,
        isDefault: false,
        scheduleType: ScheduleType.delay,
      ),
    ],
  );
}

/// Records a completion event for the given [sefariaRef] + [stageOrder] pair.
///
/// [stageOrder] is what gets stored in [CompletionEvents.stageId] — the value
/// the dashboard providers look up against [StageDefinition.stageOrder].
Future<void> _insertCompletion(
  FakeFirebaseFirestore firestore, {
  Object? trackId,
  required String curriculumId,
  required String sefariaRef,
  required int stageOrder,
  String profileId = _profileId,
  DateTime? completedAt,
}) async {
  final curriculum = CurriculumId.fromStorageKey(curriculumId);
  if (curriculum == null) {
    throw ArgumentError.value(curriculumId, 'curriculumId');
  }
  await seedCompletion(
    firestore,
    uid: _uid,
    profileId: profileId,
    curriculumId: curriculum,
    sefariaRef: sefariaRef,
    stageId: stageOrder,
    completedAt: completedAt,
  );
}

/// Builds a [ProviderContainer] that:
/// - wires [activeAccountFirebaseProvider] → [firestore]
/// - selects [activeProfileIdProvider] → [_profileId]
/// - fixes [scopedItemCountProvider] for every [CurriculumId] to [totalItems]
///
/// The [globalStageRepositoryProvider] is NOT overridden; it resolves through
/// the real [StageDefinitionRepositoryImpl] backed by the in-memory DB.
ProviderContainer _makeContainer(
  FakeFirebaseFirestore firestore, {
  Map<CurriculumId, int> totalItemsBycurriculum = const {},
}) {
  final container = ProviderContainer(
    overrides: [
      activeAccountFirebaseProvider.overrideWith(
        (ref) async => _handles(firestore),
      ),
      for (final curriculum in CurriculumId.values)
        scopedItemCountProvider(curriculum).overrideWith(
          (ref) => Future.value(totalItemsBycurriculum[curriculum] ?? 0),
        ),
    ],
  );
  container.read(selectedProfileIdProvider.notifier).select(_profileId);
  return container;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late FakeFirebaseFirestore db;

  setUp(() async {
    db = createFakeFirestore(authenticatedUid: _uid);
    await _seedProfile(db);
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
        dashboardTrackCompletionPercentageProvider(
          CurriculumId.mishnayos,
        ).future,
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
        dashboardTrackCompletionPercentageProvider(
          CurriculumId.mishnayos,
        ).future,
      );
      expect(pct, 0.0, reason: 'zero-item track must return 0.0');
    });

    test(
      'item is NOT done when only learn stage is completed (partial)',
      () async {
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
          dashboardTrackCompletionPercentageProvider(
            CurriculumId.mishnayos,
          ).future,
        );
        expect(
          pct,
          0.0,
          reason: 'item missing chazara stage must not be counted',
        );
      },
    );

    test(
      'item IS done only when ALL required stages have completions',
      () async {
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
          dashboardTrackCompletionPercentageProvider(
            CurriculumId.mishnayos,
          ).future,
        );
        // 1 done / 4 total = 0.25
        expect(
          pct,
          closeTo(1 / 4, 0.0001),
          reason: 'only ref1 fully done; ref2 partial',
        );
      },
    );

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
          dashboardTrackCompletionPercentageProvider(
            CurriculumId.mishnayos,
          ).future,
        );
        expect(
          mishPct,
          closeTo(1 / 3, 0.0001),
          reason: 'mishnayos track must count its own completion',
        );

        // Bavli track must return 0.0 — the mishnayos completion must NOT bleed over.
        final bavliPct = await container.read(
          dashboardTrackCompletionPercentageProvider(CurriculumId.bavli).future,
        );
        expect(
          bavliPct,
          0.0,
          reason: 'bavli track must not count a mishnayos completion',
        );
      },
    );

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
        dashboardTrackCompletionPercentageProvider(
          CurriculumId.mishnayos,
        ).future,
      );
      // If provider used stage id (≥3) instead of stageOrder (1), pct = 0.0.
      expect(
        pct,
        closeTo(1.0, 0.0001),
        reason: 'provider must use stageOrder, not the stage DB row id',
      );
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
      expect(
        pct,
        0.0,
        reason: 'item missing chazara stage must not be counted',
      );
    });

    test(
      'counts item only when ALL required stages have completions',
      () async {
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
        expect(
          pct,
          closeTo(1 / 5, 0.0001),
          reason: 'only ref1 fully done; ref2 partial',
        );
      },
    );

    /// CRITICAL — Finding 1 guard (Option-B, per-curriculum scoping).
    ///
    /// A completion recorded under curriculumId='mishnayos' must NOT appear
    /// in the dashboardCompletionPercentage result for CurriculumId.bavli.
    test('completion under curriculum A is NOT counted for curriculum B '
        '(Option-B regression guard — Finding 1)', () async {
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
      expect(
        mishPct,
        closeTo(1 / 3, 0.0001),
        reason: 'mishnayos curriculum must count its own completion',
      );

      // Bavli must stay at 0.0.
      final bavliPct = await container.read(
        dashboardCompletionPercentageProvider(CurriculumId.bavli).future,
      );
      expect(
        bavliPct,
        0.0,
        reason: 'bavli curriculum must not count a mishnayos completion',
      );
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
      expect(
        pct,
        closeTo(1.0, 0.0001),
        reason: 'must use stageOrder, not the stage DB row id',
      );
    });
  });
}
