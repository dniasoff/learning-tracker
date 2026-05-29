/// Logic tests for dashboard_providers.dart.
///
/// Covers:
///   • [dashboardUserModeProvider]               — adult/child/missing profile
///   • [dashboardActiveCurriculaProvider]         — empty, single, multi, unknown
///   • [dashboardActiveCurriculaStreamProvider]   — emits via reactive watch
///   • [dashboardLastCompletionProvider]          — empty, latest selected
///   • [dashboardGlobalPointsProvider]            — adult→0, child→balance
///   • [dashboardStreakProvider]                  — stream: 0/1 (no-dispose)
///   • [dashboardStreakRecoveryProvider]          — adult→no-op, child
///   • [dashboardHasProgramEnrollmentProvider]    — missing/present
///   • [dashboardActiveTracksStreamProvider]      — empty, active, archived
///   • [trackHasChazaraProvider]                  — single vs multi-stage
///   • [anyActiveTrackHasChazaraProvider]         — any-true gates
///   • Product rule: adults have no points
///   • Product rule: chazara only when stage count > 1
library;

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _profileId = 1;
const _childProfileId = 2;

// ── Seed helpers ──────────────────────────────────────────────────────────────

Future<void> _seedProfile(UserDatabase db, {String mode = 'adult'}) async {
  final now = DateTime.utc(2026, 1, 1);
  final accountId = await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: 'test@example.com',
          tier: 'localBorn',
          displayName: 'Test User',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await db
      .into(db.learnerProfiles)
      .insert(
        LearnerProfilesCompanion.insert(
          accountId: accountId,
          displayName: 'Test User',
          mode: mode,
          createdAt: now,
          updatedAt: now,
        ),
      );
}

/// Seeds a child profile (id=2) under the same account as the adult (id=1).
Future<void> _seedChildProfile(UserDatabase db) async {
  final now = DateTime.utc(2026, 1, 1);
  await db
      .into(db.learnerProfiles)
      .insert(
        LearnerProfilesCompanion.insert(
          accountId: 1,
          displayName: 'Child',
          mode: 'child',
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<int> _insertTrack(
  UserDatabase db, {
  required String curriculumId,
  int profileId = _profileId,
  String state = TrackState.active,
}) async {
  final now = DateTime.utc(2026, 1, 1);
  return db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          state: Value(state),
          stateChangedAt: now,
          activatedAt: now,
        ),
      );
}

Future<void> _insertStage(
  UserDatabase db, {
  required int trackId,
  required int stageOrder,
  required String stageName,
  required String curriculumId,
  int profileId = _profileId,
}) async {
  await db
      .into(db.stageDefinitions)
      .insert(
        StageDefinitionsCompanion.insert(
          profileId: profileId,
          trackId: trackId,
          curriculumId: curriculumId,
          stageOrder: stageOrder,
          stageName: stageName,
          schedule: const Value('{"type":"delay","delay_days":0}'),
        ),
      );
}

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
  await db
      .into(db.completionEvents)
      .insert(
        CompletionEventsCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: stageOrder,
          trackType: 'personal',
          trackId: Value(trackId),
          eventTimestamp: ts,
        ),
        mode: InsertMode.insertOrIgnore,
      );
}

// ── Container factory ─────────────────────────────────────────────────────────

/// Builds a [ProviderContainer] with:
///   - in-memory [UserDatabase]
///   - [activeProfileIdProvider] fixed to [profileId] (default: [_profileId])
///   - [syncWriteFacadeProvider] → null (no Firestore)
///   - [scopedItemCountProvider] for every [CurriculumId] fixed to 0
///     (overridable per-curriculum via [totalItemsMap])
ProviderContainer _makeContainer(
  UserDatabase db, {
  Map<CurriculumId, int> totalItemsMap = const {},
  int profileId = _profileId,
}) {
  return ProviderContainer(
    overrides: [
      userDatabaseProvider.overrideWithValue(db),
      activeProfileIdProvider.overrideWithValue(profileId),
      syncWriteFacadeProvider.overrideWithValue(null),
      for (final c in CurriculumId.values)
        scopedItemCountProvider(
          c,
        ).overrideWith((ref) => Future.value(totalItemsMap[c] ?? 0)),
    ],
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late UserDatabase db;

  setUp(() async {
    db = UserDatabase(NativeDatabase.memory());
    await _seedProfile(db); // creates learner_profiles(id=1, mode='adult')
  });

  tearDown(() async {
    await db.close();
  });

  // ── dashboardUserModeProvider ─────────────────────────────────────────────

  group('dashboardUserModeProvider', () {
    test('returns adult when profile mode is adult', () async {
      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final mode = await container.read(dashboardUserModeProvider.future);
      expect(mode, ProfileMode.adult);
    });

    test('returns child when active profile mode is child', () async {
      await _seedChildProfile(db); // id=2, mode='child'

      final container = _makeContainer(db, profileId: _childProfileId);
      addTearDown(container.dispose);

      final mode = await container.read(dashboardUserModeProvider.future);
      expect(mode, ProfileMode.child);
    });

    test('defaults to adult when no profile row matches active id', () async {
      final container = _makeContainer(db, profileId: 9999);
      addTearDown(container.dispose);

      final mode = await container.read(dashboardUserModeProvider.future);
      expect(
        mode,
        ProfileMode.adult,
        reason: 'missing profile row → fallback adult',
      );
    });
  });

  // ── dashboardActiveCurriculaProvider ──────────────────────────────────────

  group('dashboardActiveCurriculaProvider', () {
    test('returns empty list when no tracks exist', () async {
      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final curricula = await container.read(
        dashboardActiveCurriculaProvider.future,
      );
      expect(curricula, isEmpty);
    });

    test('returns the active curriculum for a single active track', () async {
      await _insertTrack(db, curriculumId: 'mishnayos');

      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final curricula = await container.read(
        dashboardActiveCurriculaProvider.future,
      );
      expect(curricula, contains(CurriculumId.mishnayos));
      expect(curricula, hasLength(1));
    });

    test(
      'returns multiple curricula when multiple active tracks exist',
      () async {
        await _insertTrack(db, curriculumId: 'mishnayos');
        await _insertTrack(db, curriculumId: 'bavli');

        final container = _makeContainer(db);
        addTearDown(container.dispose);

        final curricula = await container.read(
          dashboardActiveCurriculaProvider.future,
        );
        expect(
          curricula,
          containsAll([CurriculumId.mishnayos, CurriculumId.bavli]),
        );
        expect(curricula.length, 2);
      },
    );

    test('does NOT include retired tracks', () async {
      await _insertTrack(
        db,
        curriculumId: 'mishnayos',
        state: TrackState.retired,
      );

      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final curricula = await container.read(
        dashboardActiveCurriculaProvider.future,
      );
      expect(curricula, isEmpty, reason: 'retired track should not appear');
    });

    test('skips unknown storage keys gracefully', () async {
      // Insert a track with a made-up curriculum id that is not a known
      // CurriculumId storageKey.
      final now = DateTime.utc(2026, 1, 1);
      await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: _profileId,
              curriculumId: 'unknown_curriculum_xyz',
              state: const Value(TrackState.active),
              stateChangedAt: now,
              activatedAt: now,
            ),
          );

      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final curricula = await container.read(
        dashboardActiveCurriculaProvider.future,
      );
      // The unknown key should be silently skipped rather than throw.
      expect(curricula, isEmpty);
    });

    test(
      'includes each active curriculum exactly once even with multiple profiles',
      () async {
        // Insert tracks for two different profiles. Only our profile's tracks
        // should appear.
        await _insertTrack(
          db,
          curriculumId: 'mishnayos',
          profileId: _profileId,
        );
        await _seedChildProfile(db); // creates learner_profiles(id=2)
        await _insertTrack(
          db,
          curriculumId: 'bavli',
          profileId: _childProfileId,
        );

        final container = _makeContainer(db);
        addTearDown(container.dispose);

        final curricula = await container.read(
          dashboardActiveCurriculaProvider.future,
        );
        // Only mishnayos belongs to profileId=1.
        expect(curricula, contains(CurriculumId.mishnayos));
        expect(curricula, isNot(contains(CurriculumId.bavli)));
      },
    );
  });

  // ── dashboardActiveCurriculaStreamProvider ────────────────────────────────

  group('dashboardActiveCurriculaStreamProvider', () {
    test('emits empty list when no active tracks', () async {
      final container = _makeContainer(db);
      addTearDown(container.dispose);

      // Keep a listener so the autoDispose provider is not immediately GC'd.
      final values = <List<CurriculumId>>[];
      final sub = container.listen(dashboardActiveCurriculaStreamProvider, (
        _,
        next,
      ) {
        if (next.hasValue) values.add(next.requireValue);
      });
      addTearDown(sub.close);

      final value = await container.read(
        dashboardActiveCurriculaStreamProvider.future,
      );
      expect(value, isEmpty);
    });

    test('emits the active curriculum when a track is present', () async {
      await _insertTrack(db, curriculumId: 'mishnayos');

      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final sub = container.listen(
        dashboardActiveCurriculaStreamProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      final value = await container.read(
        dashboardActiveCurriculaStreamProvider.future,
      );
      expect(value, contains(CurriculumId.mishnayos));
    });
  });

  // ── dashboardLastCompletionProvider ──────────────────────────────────────

  group('dashboardLastCompletionProvider', () {
    test('returns null when no completions exist', () async {
      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final last = await container.read(
        dashboardLastCompletionProvider(CurriculumId.mishnayos).future,
      );
      expect(last, isNull);
    });

    test(
      'returns the latest completedAt when multiple completions exist',
      () async {
        final trackId = await _insertTrack(db, curriculumId: 'mishnayos');
        await _insertStage(
          db,
          trackId: trackId,
          stageOrder: 1,
          stageName: 'Learn',
          curriculumId: 'mishnayos',
        );

        // Three distinct UTC timestamps.
        final t1 = DateTime.utc(2026, 1, 1);
        final t2 = DateTime.utc(2026, 3, 15); // latest
        final t3 = DateTime.utc(2026, 2, 7);

        await _insertCompletion(
          db,
          trackId: trackId,
          curriculumId: 'mishnayos',
          sefariaRef: 'Ref1',
          stageOrder: 1,
          completedAt: t1,
        );
        await _insertCompletion(
          db,
          trackId: trackId,
          curriculumId: 'mishnayos',
          sefariaRef: 'Ref2',
          stageOrder: 1,
          completedAt: t3,
        );
        await _insertCompletion(
          db,
          trackId: trackId,
          curriculumId: 'mishnayos',
          sefariaRef: 'Ref3',
          stageOrder: 1,
          completedAt: t2,
        );

        final container = _makeContainer(db);
        addTearDown(container.dispose);

        final last = await container.read(
          dashboardLastCompletionProvider(CurriculumId.mishnayos).future,
        );
        // Provider returns whatever timestamp the DAO stored; Drift stores UTC
        // but may restore as local. Compare as UTC.
        expect(
          last!.toUtc(),
          t2,
          reason: 'should return the most recent completedAt',
        );
      },
    );

    test(
      'is scoped to the requested curriculum (does not bleed across)',
      () async {
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
          sefariaRef: 'MishRef1',
          stageOrder: 1,
          completedAt: DateTime.utc(2026, 5, 1),
        );

        final container = _makeContainer(db);
        addTearDown(container.dispose);

        // Bavli should still return null.
        final bavliLast = await container.read(
          dashboardLastCompletionProvider(CurriculumId.bavli).future,
        );
        expect(bavliLast, isNull, reason: 'bavli has no completions');
      },
    );

    test('returns non-null for a single completion', () async {
      final trackId = await _insertTrack(db, curriculumId: 'mishnayos');
      await _insertStage(
        db,
        trackId: trackId,
        stageOrder: 1,
        stageName: 'Learn',
        curriculumId: 'mishnayos',
      );
      final ts = DateTime.utc(2026, 4, 10);
      await _insertCompletion(
        db,
        trackId: trackId,
        curriculumId: 'mishnayos',
        sefariaRef: 'Ref1',
        stageOrder: 1,
        completedAt: ts,
      );

      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final last = await container.read(
        dashboardLastCompletionProvider(CurriculumId.mishnayos).future,
      );
      expect(last, isNotNull);
      expect(last!.toUtc(), ts);
    });
  });

  // ── dashboardGlobalPointsProvider ────────────────────────────────────────

  group('dashboardGlobalPointsProvider', () {
    test(
      'returns 0 for an adult profile (Rule: adults have no points)',
      () async {
        // The seeded profile in setUp has mode='adult'.
        final container = _makeContainer(db);
        addTearDown(container.dispose);

        // Ensure dashboardUserMode resolves to adult first.
        final mode = await container.read(dashboardUserModeProvider.future);
        expect(mode, ProfileMode.adult);

        final points = await container.read(
          dashboardGlobalPointsProvider.future,
        );
        expect(
          points,
          0,
          reason: 'adults must never accrue points (product rule)',
        );
      },
    );

    test('returns actual balance for a child profile', () async {
      await _seedChildProfile(db); // id=2, mode='child'

      // Seed a balance row for the child profile.
      final now = DateTime.utc(2026, 1, 1);
      await db
          .into(db.pointsBalance)
          .insert(
            PointsBalanceCompanion.insert(
              profileId: const Value(_childProfileId),
              balance: const Value(250),
              updatedAt: now,
            ),
          );

      final container = _makeContainer(db, profileId: _childProfileId);
      addTearDown(container.dispose);

      // Resolve user mode first so the guard has a value.
      final mode = await container.read(dashboardUserModeProvider.future);
      expect(mode, ProfileMode.child);

      final points = await container.read(dashboardGlobalPointsProvider.future);
      expect(points, 250);
    });

    test('returns 0 for child with no balance row', () async {
      await _seedChildProfile(db); // id=2, mode='child'

      final container = _makeContainer(db, profileId: _childProfileId);
      addTearDown(container.dispose);

      final mode = await container.read(dashboardUserModeProvider.future);
      expect(mode, ProfileMode.child);

      final points = await container.read(dashboardGlobalPointsProvider.future);
      expect(points, 0, reason: 'no balance row → 0 for child');
    });
  });

  // ── dashboardStreakProvider ───────────────────────────────────────────────

  group('dashboardStreakProvider', () {
    test('emits zero streak when no streak events exist', () async {
      final container = _makeContainer(db);
      addTearDown(container.dispose);

      // Keep a listener alive to prevent autoDispose before future resolves.
      final sub = container.listen(dashboardStreakProvider, (_, __) {});
      addTearDown(sub.close);

      final value = await container.read(dashboardStreakProvider.future);
      expect(value.currentStreak, 0);
      expect(value.maxStreak, 0);
    });

    test('emits streak >= 1 after a streak event for today', () async {
      final today = DateTime.now().toUtc();
      await db.streakEventDao.appendEvent(
        StreakEventsCompanion.insert(
          profileId: _profileId,
          eventType: 'completion',
          dayUtc: DateTime.utc(today.year, today.month, today.day),
          eventTimestamp: today,
          clientDeviceId: const Value(null),
        ),
      );

      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final sub = container.listen(dashboardStreakProvider, (_, __) {});
      addTearDown(sub.close);

      final value = await container.read(dashboardStreakProvider.future);
      expect(value.currentStreak, greaterThanOrEqualTo(1));
    });

    test('emits non-negative currentStreak and maxStreak', () async {
      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final sub = container.listen(dashboardStreakProvider, (_, __) {});
      addTearDown(sub.close);

      final value = await container.read(dashboardStreakProvider.future);
      expect(value.currentStreak, greaterThanOrEqualTo(0));
      expect(value.maxStreak, greaterThanOrEqualTo(0));
    });
  });

  // ── dashboardStreakRecoveryProvider ───────────────────────────────────────

  group('dashboardStreakRecoveryProvider', () {
    test('returns wasRecovered=false for an adult profile', () async {
      // Adult profile is seeded in setUp.
      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final info = await container.read(dashboardStreakRecoveryProvider.future);
      expect(info.wasRecovered, isFalse);
      // Adult short-circuit: currentStreak should be 0.
      expect(info.currentStreak, 0, reason: 'adult fallback: streak is 0');
    });

    test(
      'returns wasRecovered=false for child (grace period not implemented)',
      () async {
        await _seedChildProfile(db); // id=2, mode='child'

        final container = _makeContainer(db, profileId: _childProfileId);
        addTearDown(container.dispose);

        final mode = await container.read(dashboardUserModeProvider.future);
        expect(mode, ProfileMode.child);

        final info = await container.read(
          dashboardStreakRecoveryProvider.future,
        );
        // Grace period is not implemented; wasRecovered always false post-W3.20.
        expect(info.wasRecovered, isFalse);
      },
    );
  });

  // ── dashboardHasProgramEnrollmentProvider ─────────────────────────────────

  group('dashboardHasProgramEnrollmentProvider', () {
    test('returns false when no enrollment exists', () async {
      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final has = await container.read(
        dashboardHasProgramEnrollmentProvider(CurriculumId.mishnayos).future,
      );
      expect(has, isFalse);
    });

    test('returns true when an enrollment is present', () async {
      await db.profileProgramDao.insertProfileProgram(
        ProfileProgramsCompanion.insert(
          profileId: _profileId,
          curriculumType: CurriculumId.mishnayos.storageKey,
          programId: 1,
        ),
      );

      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final has = await container.read(
        dashboardHasProgramEnrollmentProvider(CurriculumId.mishnayos).future,
      );
      expect(has, isTrue);
    });

    test(
      'returns false for a different curriculum when only mishnayos enrolled',
      () async {
        await db.profileProgramDao.insertProfileProgram(
          ProfileProgramsCompanion.insert(
            profileId: _profileId,
            curriculumType: CurriculumId.mishnayos.storageKey,
            programId: 1,
          ),
        );

        final container = _makeContainer(db);
        addTearDown(container.dispose);

        final has = await container.read(
          dashboardHasProgramEnrollmentProvider(CurriculumId.bavli).future,
        );
        expect(has, isFalse);
      },
    );
  });

  // ── dashboardActiveTracksStreamProvider ──────────────────────────────────

  group('dashboardActiveTracksStreamProvider', () {
    test('emits empty list when no tracks exist', () async {
      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final sub = container.listen(
        dashboardActiveTracksStreamProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      final tracks = await container.read(
        dashboardActiveTracksStreamProvider.future,
      );
      expect(tracks, isEmpty);
    });

    test('emits only active tracks (not retired)', () async {
      await _insertTrack(db, curriculumId: 'mishnayos');
      // Retired track: db enforces unique (profileId, curriculumId), so use
      // bavli for the retired one.
      await _insertTrack(db, curriculumId: 'bavli', state: TrackState.retired);

      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final sub = container.listen(
        dashboardActiveTracksStreamProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      final tracks = await container.read(
        dashboardActiveTracksStreamProvider.future,
      );
      expect(tracks, hasLength(1));
      expect(tracks.first.curriculumId, 'mishnayos');
    });

    test('emits multiple active tracks', () async {
      await _insertTrack(db, curriculumId: 'mishnayos');
      await _insertTrack(db, curriculumId: 'bavli');

      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final sub = container.listen(
        dashboardActiveTracksStreamProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      final tracks = await container.read(
        dashboardActiveTracksStreamProvider.future,
      );
      expect(tracks, hasLength(2));
      final ids = tracks.map((t) => t.curriculumId).toList();
      expect(ids, containsAll(['mishnayos', 'bavli']));
    });

    test(
      'is scoped to the active profile (does not include other profiles)',
      () async {
        // Insert a track for our profile and one for another profile.
        await _insertTrack(
          db,
          curriculumId: 'mishnayos',
          profileId: _profileId,
        );
        await _seedChildProfile(db); // id=2
        await _insertTrack(
          db,
          curriculumId: 'bavli',
          profileId: _childProfileId,
        );

        final container = _makeContainer(db, profileId: _profileId);
        addTearDown(container.dispose);

        final sub = container.listen(
          dashboardActiveTracksStreamProvider,
          (_, __) {},
        );
        addTearDown(sub.close);

        final tracks = await container.read(
          dashboardActiveTracksStreamProvider.future,
        );
        expect(tracks, hasLength(1));
        expect(tracks.first.profileId, _profileId);
      },
    );
  });

  // ── trackHasChazaraProvider ───────────────────────────────────────────────

  group('trackHasChazaraProvider', () {
    test('returns false when track has no stages', () async {
      final trackId = await _insertTrack(db, curriculumId: 'mishnayos');

      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final hasChazara = await container.read(
        trackHasChazaraProvider(trackId).future,
      );
      expect(hasChazara, isFalse);
    });

    test(
      'returns false when track has exactly one stage (learn-only)',
      () async {
        final trackId = await _insertTrack(db, curriculumId: 'mishnayos');
        await _insertStage(
          db,
          trackId: trackId,
          stageOrder: 1,
          stageName: 'Learn',
          curriculumId: 'mishnayos',
        );

        final container = _makeContainer(db);
        addTearDown(container.dispose);

        final hasChazara = await container.read(
          trackHasChazaraProvider(trackId).future,
        );
        // Single-stage track → no chazara UI should be shown (product rule).
        expect(
          hasChazara,
          isFalse,
          reason: 'single-stage track has no chazara (product rule)',
        );
      },
    );

    test('returns true when track has two or more stages', () async {
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

      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final hasChazara = await container.read(
        trackHasChazaraProvider(trackId).future,
      );
      expect(hasChazara, isTrue);
    });

    test('returns true for a track with three stages', () async {
      final trackId = await _insertTrack(db, curriculumId: 'mishnayos');
      for (var i = 1; i <= 3; i++) {
        await _insertStage(
          db,
          trackId: trackId,
          stageOrder: i,
          stageName: 'Stage $i',
          curriculumId: 'mishnayos',
        );
      }

      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final hasChazara = await container.read(
        trackHasChazaraProvider(trackId).future,
      );
      expect(hasChazara, isTrue);
    });
  });

  // ── anyActiveTrackHasChazaraProvider ─────────────────────────────────────

  group('anyActiveTrackHasChazaraProvider', () {
    test('returns false when no active tracks exist', () async {
      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final result = await container.read(
        anyActiveTrackHasChazaraProvider.future,
      );
      expect(result, isFalse);
    });

    test('returns false when all active tracks are single-stage', () async {
      final trackId = await _insertTrack(db, curriculumId: 'mishnayos');
      await _insertStage(
        db,
        trackId: trackId,
        stageOrder: 1,
        stageName: 'Learn',
        curriculumId: 'mishnayos',
      );

      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final result = await container.read(
        anyActiveTrackHasChazaraProvider.future,
      );
      expect(
        result,
        isFalse,
        reason: 'all tracks have single stage → no chazara',
      );
    });

    test(
      'returns true when at least one active track has multi-stage',
      () async {
        // Track 1: single stage (mishnayos).
        final t1 = await _insertTrack(db, curriculumId: 'mishnayos');
        await _insertStage(
          db,
          trackId: t1,
          stageOrder: 1,
          stageName: 'Learn',
          curriculumId: 'mishnayos',
        );
        // Track 2: two stages (bavli).
        final t2 = await _insertTrack(db, curriculumId: 'bavli');
        await _insertStage(
          db,
          trackId: t2,
          stageOrder: 1,
          stageName: 'Learn',
          curriculumId: 'bavli',
        );
        await _insertStage(
          db,
          trackId: t2,
          stageOrder: 2,
          stageName: 'Chazara',
          curriculumId: 'bavli',
        );

        final container = _makeContainer(db);
        addTearDown(container.dispose);

        final result = await container.read(
          anyActiveTrackHasChazaraProvider.future,
        );
        expect(result, isTrue);
      },
    );

    test('ignores retired tracks when determining chazara', () async {
      // A retired track with two stages should NOT trigger the "any" flag.
      final retiredTrackId = await _insertTrack(
        db,
        curriculumId: 'mishnayos',
        state: TrackState.retired,
      );
      await _insertStage(
        db,
        trackId: retiredTrackId,
        stageOrder: 1,
        stageName: 'Learn',
        curriculumId: 'mishnayos',
      );
      await _insertStage(
        db,
        trackId: retiredTrackId,
        stageOrder: 2,
        stageName: 'Chazara',
        curriculumId: 'mishnayos',
      );

      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final result = await container.read(
        anyActiveTrackHasChazaraProvider.future,
      );
      expect(
        result,
        isFalse,
        reason: 'retired track stages do not enable chazara',
      );
    });
  });

  // ── Product-rule guards ───────────────────────────────────────────────────

  group('Product rules', () {
    test(
      'adults have no points — dashboardGlobalPoints returns 0 always',
      () async {
        // Explicitly set up a balance row for the adult profile — provider must
        // still return 0 because adults are gated out by dashboardUserMode.
        final now = DateTime.utc(2026, 1, 1);
        await db
            .into(db.pointsBalance)
            .insert(
              PointsBalanceCompanion.insert(
                profileId: const Value(_profileId),
                balance: const Value(999),
                updatedAt: now,
              ),
            );

        final container = _makeContainer(db);
        addTearDown(container.dispose);

        // Confirm profile is adult.
        final mode = await container.read(dashboardUserModeProvider.future);
        expect(mode, ProfileMode.adult);

        // Even with a balance row, adults should receive 0.
        final points = await container.read(
          dashboardGlobalPointsProvider.future,
        );
        expect(
          points,
          0,
          reason: 'adults must ALWAYS receive 0 points — product rule',
        );
      },
    );

    test(
      'chazara UI gated: single-stage track does not expose chazara',
      () async {
        final trackId = await _insertTrack(db, curriculumId: 'mishnayos');
        await _insertStage(
          db,
          trackId: trackId,
          stageOrder: 1,
          stageName: 'Learn',
          curriculumId: 'mishnayos',
        );

        final container = _makeContainer(db);
        addTearDown(container.dispose);

        // Both per-track and cross-track gates should be false.
        final perTrack = await container.read(
          trackHasChazaraProvider(trackId).future,
        );
        final anyTrack = await container.read(
          anyActiveTrackHasChazaraProvider.future,
        );

        expect(perTrack, isFalse);
        expect(anyTrack, isFalse);
      },
    );

    test('child profile has independent points from adult', () async {
      await _seedChildProfile(db); // id=2, mode='child'

      final now = DateTime.utc(2026, 1, 1);
      // Seed balance for child only.
      await db
          .into(db.pointsBalance)
          .insert(
            PointsBalanceCompanion.insert(
              profileId: const Value(_childProfileId),
              balance: const Value(500),
              updatedAt: now,
            ),
          );

      final childContainer = _makeContainer(db, profileId: _childProfileId);
      addTearDown(childContainer.dispose);
      final adultContainer = _makeContainer(db, profileId: _profileId);
      addTearDown(adultContainer.dispose);

      // Ensure mode resolves before reading points.
      await childContainer.read(dashboardUserModeProvider.future);
      await adultContainer.read(dashboardUserModeProvider.future);

      final childPoints = await childContainer.read(
        dashboardGlobalPointsProvider.future,
      );
      final adultPoints = await adultContainer.read(
        dashboardGlobalPointsProvider.future,
      );

      expect(childPoints, 500, reason: 'child should see their balance');
      expect(adultPoints, 0, reason: 'adult should always see 0');
    });
  });
}
