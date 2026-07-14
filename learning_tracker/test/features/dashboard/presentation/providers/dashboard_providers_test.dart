/// Logic tests for dashboard_providers.dart.
///
/// Covers:
///   • [dashboardUserModeProvider]               — adult/child/missing profile
///   • [dashboardUserModeProvider] (R3-1)        — tutor session → always adult
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
///   • [dashboardChildNextRewardProvider] (R3-12) — happy-path after await
///   • Product rule: adults have no points
///   • Product rule: chazara only when stage count > 1
///   • Product rule (R3-1): tutor sees adult view even when child profile active
library;

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/streak_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart';
import 'package:learning_tracker/features/gamification/streak/streak_state_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  TrackState state = TrackState.active,
}) async {
  final now = DateTime.utc(2026, 1, 1);
  return db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          state: Value(state.storageKey),
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
  List<Override> extraOverrides = const [],
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
      ...extraOverrides,
    ],
  );
}

/// Reads [dashboardGlobalPointsProvider] while holding a listener.
///
/// It is an autoDispose StreamProvider whose build awaits the user-mode future;
/// reading `.future` without a listener lets the provider autoDispose during
/// its loading state ("disposed during loading"). The production dashboard
/// always holds a `ref.watch` listener — this mirrors that.
Future<int> _readGlobalPoints(ProviderContainer container) async {
  final sub = container.listen(dashboardGlobalPointsProvider, (_, __) {});
  try {
    return await container.read(dashboardGlobalPointsProvider.future);
  } finally {
    sub.close();
  }
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
              state: Value(TrackState.active.storageKey),
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

        final points = await _readGlobalPoints(container);
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

      final points = await _readGlobalPoints(container);
      expect(points, 250);
    });

    test('returns 0 for child with no balance row', () async {
      await _seedChildProfile(db); // id=2, mode='child'

      final container = _makeContainer(db, profileId: _childProfileId);
      addTearDown(container.dispose);

      final mode = await container.read(dashboardUserModeProvider.future);
      expect(mode, ProfileMode.child);

      final points = await _readGlobalPoints(container);
      expect(points, 0, reason: 'no balance row → 0 for child');
    });

    test('reflects balance changes reactively without invalidate '
        '(D2: watchBalance stream, not a stale one-shot future)', () async {
      await _seedChildProfile(db); // id=2, mode='child'
      final now = DateTime.utc(2026, 1, 1);
      await db
          .into(db.pointsBalance)
          .insert(
            PointsBalanceCompanion.insert(
              profileId: const Value(_childProfileId),
              balance: const Value(100),
              updatedAt: now,
            ),
          );

      final container = _makeContainer(db, profileId: _childProfileId);
      addTearDown(container.dispose);

      expect(
        await container.read(dashboardUserModeProvider.future),
        ProfileMode.child,
      );

      // Hold a listener (mirrors the mounted dashboard's ref.watch) BEFORE
      // reading, so the autoDispose stream provider is not torn down during its
      // loading state. The OLD one-shot future would stay at 100 forever; the
      // reactive stream must emit the debited value.
      final sub = container.listen(dashboardGlobalPointsProvider, (_, __) {});
      addTearDown(sub.close);

      expect(await container.read(dashboardGlobalPointsProvider.future), 100);

      // A redemption debit (any balance mutation) writes the balance row.
      await (db.update(db.pointsBalance)
            ..where((t) => t.profileId.equals(_childProfileId)))
          .write(const PointsBalanceCompanion(balance: Value(70)));

      // No manual invalidate — the stream emits the new balance.
      var latest = container.read(dashboardGlobalPointsProvider).value;
      for (var i = 0; i < 50 && latest != 70; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        latest = container.read(dashboardGlobalPointsProvider).value;
      }
      expect(latest, 70, reason: 'dashboard points must reflect the debit');
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
      // AUD-t-dashboard-05 (TQ-6): a fixed instant, not the real wall clock,
      // both seeds the event's day AND anchors the provider's own "today"
      // (via the FakeLocalDayClock override below) — so the two reads can
      // never straddle a real UTC-midnight rollover and flake.
      final fixedToday = DateTime.utc(2026, 5, 20);
      await db.streakEventDao.appendEvent(
        StreakEventsCompanion.insert(
          profileId: _profileId,
          eventType: 'completion',
          dayUtc: DateTime.utc(
            fixedToday.year,
            fixedToday.month,
            fixedToday.day,
          ),
          eventTimestamp: fixedToday,
          clientDeviceId: const Value(null),
        ),
      );

      final container = _makeContainer(
        db,
        extraOverrides: [
          streakStateProvider.overrideWithValue(
            StreakStateService(
              db: db,
              clock: FakeLocalDayClock(fixedToday),
              dayOf: (dt) => DateTime.utc(
                dt.toUtc().year,
                dt.toUtc().month,
                dt.toUtc().day,
              ),
            ),
          ),
        ],
      );
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

    // AUD-gamification-11 (SM-7): dashboardStreak used to construct its own
    // `StreakStateService(db: db, clock: ...)` ad hoc on every rebuild —
    // there was no way for a test (or a caller) to substitute a fake without
    // also faking the whole `UserDatabase`. It must now read through the
    // shared `streakStateProvider` seam.
    test(
      'AUD-gamification-11: reads through an overridden streakStateProvider '
      'instead of constructing its own StreakStateService(db: db, ...)',
      () async {
        // A second database, seeded with a streak event for _profileId. `db`
        // (the container's userDatabaseProvider override) has NO events for
        // _profileId — so a non-zero streak can only come from the override.
        final overrideDb = UserDatabase(NativeDatabase.memory());
        addTearDown(overrideDb.close);
        await _seedProfile(
          overrideDb,
        ); // creates learner_profiles(id=1, mode='adult') — FK for streak_events
        // AUD-t-dashboard-05 (TQ-6): a fixed instant, not the real wall
        // clock, both seeds the event's day AND anchors the override
        // service's own "today" — see the identical rationale above.
        final fixedToday = DateTime.utc(2026, 5, 20);
        await overrideDb.streakEventDao.appendEvent(
          StreakEventsCompanion.insert(
            profileId: _profileId,
            eventType: 'completion',
            dayUtc: DateTime.utc(
              fixedToday.year,
              fixedToday.month,
              fixedToday.day,
            ),
            eventTimestamp: fixedToday,
            clientDeviceId: const Value(null),
          ),
        );

        final container = _makeContainer(
          db,
          extraOverrides: [
            streakStateProvider.overrideWithValue(
              StreakStateService(
                db: overrideDb,
                clock: FakeLocalDayClock(fixedToday),
                dayOf: (dt) => DateTime.utc(
                  dt.toUtc().year,
                  dt.toUtc().month,
                  dt.toUtc().day,
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final sub = container.listen(dashboardStreakProvider, (_, __) {});
        addTearDown(sub.close);

        final value = await container.read(dashboardStreakProvider.future);
        expect(
          value.currentStreak,
          greaterThanOrEqualTo(1),
          reason:
              '`db` has no streak events for _profileId; only the '
              'overridden streakStateProvider (bound to overrideDb) does — '
              'a non-zero streak proves dashboardStreak read the override.',
        );
      },
    );
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

    // AUD-gamification-11 (SM-7): dashboardStreakRecovery used to construct
    // its own `StreakService(db, profileId: profileId)` ad hoc — a test
    // could only fake the service by faking the whole `UserDatabase`, never
    // by a single `ProviderScope` override. It must now read through the
    // shared `streakServiceProvider` seam.
    test(
      'AUD-gamification-11: reads through an overridden streakServiceProvider '
      'instead of constructing its own StreakService(db, profileId: ...)',
      () async {
        await _seedChildProfile(db); // id=2, mode='child'

        // A second database, seeded with a streak event for the CHILD
        // profile. `db` (the container's userDatabaseProvider override) has
        // no events for that profile — so a recovered currentStreak can only
        // come from the override.
        final overrideDb = UserDatabase(NativeDatabase.memory());
        addTearDown(overrideDb.close);
        await _seedProfile(overrideDb); // id=1 — creates account id=1
        await _seedChildProfile(
          overrideDb,
        ); // id=2 — FK for streak_events(profile_id=2)
        // AUD-t-dashboard-05 (TQ-6): a fixed instant, not the real wall
        // clock, both seeds the event's day AND anchors the override
        // service's own "today" — see the identical rationale above.
        final fixedToday = DateTime.utc(2026, 5, 20);
        await overrideDb.streakEventDao.appendEvent(
          StreakEventsCompanion.insert(
            profileId: _childProfileId,
            eventType: 'completion',
            dayUtc: DateTime.utc(
              fixedToday.year,
              fixedToday.month,
              fixedToday.day,
            ),
            eventTimestamp: fixedToday,
            clientDeviceId: const Value(null),
          ),
        );

        final container = _makeContainer(
          db,
          profileId: _childProfileId,
          extraOverrides: [
            streakServiceProvider.overrideWithValue(
              StreakService(
                overrideDb,
                profileId: _childProfileId,
                streakStateProvider: StreakStateService(
                  db: overrideDb,
                  clock: FakeLocalDayClock(fixedToday),
                  dayOf: (dt) => DateTime.utc(
                    dt.toUtc().year,
                    dt.toUtc().month,
                    dt.toUtc().day,
                  ),
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Pre-resolve dashboardUserModeProvider — dashboardStreakRecovery
        // reads it synchronously via `.asData?.value`, which is null until
        // the future has resolved at least once (same pattern as the
        // 'returns wasRecovered=false for child' test above).
        final mode = await container.read(dashboardUserModeProvider.future);
        expect(mode, ProfileMode.child);

        final info = await container.read(
          dashboardStreakRecoveryProvider.future,
        );
        expect(
          info.currentStreak,
          greaterThanOrEqualTo(1),
          reason:
              '`db` has no streak events for the child profile; only the '
              'overridden streakServiceProvider (bound to overrideDb) does — '
              'a non-zero streak proves dashboardStreakRecovery read the '
              'override.',
        );
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
        final points = await _readGlobalPoints(container);
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

      final childPoints = await _readGlobalPoints(childContainer);
      final adultPoints = await _readGlobalPoints(adultContainer);

      expect(childPoints, 500, reason: 'child should see their balance');
      expect(adultPoints, 0, reason: 'adult should always see 0');
    });
  });

  // ── R3-1 (UPDATED 2026-06-02): tutor dashboard follows the tutored profile's
  // mode — a tutor viewing a CHILD sees the child's view (incl. points/rewards),
  // because "a tutor sees everything the child sees" (owner ruling). Parent/
  // management access is gated separately by route + PIN guards, not by
  // dashboardUserMode, so showing child gamification does not remove management.
  // (Supersedes the original R3-1 "tutor always adult" rule, which wrongly hid
  // the child's points from the tutor.)

  group('dashboardUserModeProvider — tutor session (R3-1)', () {
    /// Returns a [TutoredProfileSelection] stub suitable for overriding the
    /// provider in tests.  Uses a read-only permission set to avoid pulling in
    /// full-permission logic that is irrelevant to the mode test.
    TutoredProfileSelection stubTutoredSelection() =>
        const TutoredProfileSelection(
          profileId: 'talmid-remote-id',
          ownerUid: 'parent-uid',
          grantId: 'grant-abc',
          permissions: TutorPermissions(),
        );

    test('returns ProfileMode.child when tutor session is active '
        'and the tutored profile is a child (sees the child view)', () async {
      // Seed a child profile (id=2) that the tutor is viewing.
      await _seedChildProfile(db); // id=2, mode='child'

      // Override activeTutoredProfileSelectionProvider to non-null to
      // simulate an active tutor session. activeProfileId points at the
      // child profile as the tutored mirror.
      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          activeProfileIdProvider.overrideWithValue(_childProfileId),
          syncWriteFacadeProvider.overrideWithValue(null),
          activeTutoredProfileSelectionProvider.overrideWithValue(
            stubTutoredSelection(),
          ),
          for (final c in CurriculumId.values)
            scopedItemCountProvider(c).overrideWith((ref) => Future.value(0)),
        ],
      );
      addTearDown(container.dispose);

      final mode = await container.read(dashboardUserModeProvider.future);
      expect(
        mode,
        ProfileMode.child,
        reason:
            'R3-1 (updated): tutor viewing a child sees the child view '
            '(incl. points); management is route/PIN-gated, not mode-gated',
      );
    });

    test('returns ProfileMode.adult when tutor session is active '
        'even if there is no matching DB profile row', () async {
      // No profile seeded for id=9999 — the tutor session guard must fire
      // before the DB lookup so we never hit a missing-profile fallback path
      // via the DB.
      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          activeProfileIdProvider.overrideWithValue(9999),
          syncWriteFacadeProvider.overrideWithValue(null),
          activeTutoredProfileSelectionProvider.overrideWithValue(
            stubTutoredSelection(),
          ),
          for (final c in CurriculumId.values)
            scopedItemCountProvider(c).overrideWith((ref) => Future.value(0)),
        ],
      );
      addTearDown(container.dispose);

      final mode = await container.read(dashboardUserModeProvider.future);
      expect(
        mode,
        ProfileMode.adult,
        reason: 'tutor guard fires before DB lookup',
      );
    });

    test(
      'does NOT apply tutor override when activeTutoredProfileSelection is null '
      '(normal own-profile mode)',
      () async {
        // A child profile viewed by its owner must still return child mode.
        await _seedChildProfile(db); // id=2, mode='child'

        final container = _makeContainer(db, profileId: _childProfileId);
        addTearDown(container.dispose);

        // activeTutoredProfileSelectionProvider is not overridden here;
        // the default ProviderContainer leaves it null.
        final mode = await container.read(dashboardUserModeProvider.future);
        expect(
          mode,
          ProfileMode.child,
          reason:
              'no tutor session active — child profile must return child mode',
        );
      },
    );
  });

  // ── R3-12: dashboardChildNextReward happy path ────────────────────────────
  //
  // Deterministically triggering disposal during the async gap of an autoDispose
  // provider is difficult in unit tests (the gap is one microtask). We therefore
  // test the happy path: with no active tracks and a child profile, the provider
  // resolves to null (no milestones) without throwing. This confirms the
  // ref.mounted guard did not regress the normal completion path.

  group('dashboardChildNextReward — mounted-guard (R3-12)', () {
    test(
      'happy path: returns null for a child profile with no tracks/milestones',
      () async {
        // Seed child profile (id=2).
        await _seedChildProfile(db); // id=2, mode='child'

        final container = _makeContainer(db, profileId: _childProfileId);
        addTearDown(container.dispose);

        // Confirm the provider resolves to null without throwing.  If the
        // ref.mounted guard incorrectly returned a non-null sentinel we would
        // detect it here; if it threw, the future would complete with an error.
        final result = await container.read(
          dashboardChildNextRewardProvider.future,
        );
        expect(
          result,
          isNull,
          reason:
              'no tracks/milestones → null; mounted guard must not break the '
              'normal resolution path',
        );
      },
    );

    test('returns null immediately for adult profile '
        '(mode guard before the await gap)', () async {
      // Adult profile (id=1) seeded in setUp. userMode != child → early null
      // before the await, so the mounted guard is never reached.
      final container = _makeContainer(db);
      addTearDown(container.dispose);

      final result = await container.read(
        dashboardChildNextRewardProvider.future,
      );
      expect(result, isNull, reason: 'adult mode → null before async gap');
    });

    // AUD-gamification-11 (SM-7): dashboardChildNextReward used to construct
    // its own `RewardMilestoneService(db, profileId: profileId)` ad hoc — a
    // test could only fake the service by faking the whole `UserDatabase`,
    // never by a single `ProviderScope` override. It must now read through
    // the shared `rewardMilestoneServiceProvider` seam.
    test('AUD-gamification-11: reads through an overridden '
        'rewardMilestoneServiceProvider instead of constructing its own '
        'RewardMilestoneService(db, profileId: ...)', () async {
      // RewardMilestoneService config is SharedPreferences-backed.
      SharedPreferences.setMockInitialValues({});
      await _seedChildProfile(db); // id=2, mode='child'

      // A service scoped to a DIFFERENT profileId (999 — no learner_profiles
      // row, so no points-balance FK to satisfy; getGlobalPointsForRewards
      // reads 0 for a profile with no balance row), pre-seeded with a
      // global milestone. The active profile (2) has no milestones seeded,
      // so `NextRewardResult` can only come from the override.
      final overrideService = RewardMilestoneService(db, profileId: 999);
      await overrideService.upsertMilestone(
        trackId: RewardMilestone.kGlobalTrackSentinel,
        title: 'Override Reward',
        thresholdPoints: 50,
        milestoneId: 'ms-override',
      );

      final container = _makeContainer(
        db,
        profileId: _childProfileId,
        extraOverrides: [
          rewardMilestoneServiceProvider.overrideWithValue(overrideService),
        ],
      );
      addTearDown(container.dispose);

      // Pre-resolve dashboardUserModeProvider — dashboardChildNextReward
      // reads it synchronously via `.asData?.value`, which is null until
      // the future has resolved at least once.
      final mode = await container.read(dashboardUserModeProvider.future);
      expect(mode, ProfileMode.child);

      final result = await container.read(
        dashboardChildNextRewardProvider.future,
      );
      expect(
        result,
        isNotNull,
        reason:
            'the active profile (2) has no milestones/balance seeded — a '
            'non-null result proves dashboardChildNextReward read the '
            'overridden rewardMilestoneServiceProvider (profile 999) '
            'rather than constructing its own service for profile 2.',
      );
      expect(result!.threshold, 50);
      expect(result.trackPoints, 0);
      expect(result.isGlobal, isTrue);
    });
  });

  // ── AUD-dashboard-06 (SM-4): ref.mounted guards after in-flight awaits ────
  //
  // dashboardTrackCompletionPercentage, dashboardCompletionPercentage,
  // stripStockMilestonesEffect, and dashboardPaceStatus each did a
  // ref.watch/ref.read AFTER an earlier `await` (a Drift DB read) with no
  // `ref.mounted` guard in between. If the autoDispose provider loses its
  // last listener (or its container is torn down — e.g. the user swipes the
  // active-tracks carousel past a card, or navigates away) while that DB
  // read is still in flight, the later ref call throws
  // UnmountedRefException — an uncaught exception inside the async provider
  // body.
  //
  // Each test below calls the annotated top-level function DIRECTLY (not
  // through the generated provider) with a `Ref` sourced from a host
  // `Provider<void>`, exactly mirroring the AUD-sync-04 reference fix's test
  // (sync_providers_test.dart `outboxDrainAndRecordAttempt` group). Calling
  // the function returns control to the test at its first `await`
  // (synchronous-until-suspend, per Dart async semantics); disposing the
  // container immediately afterward — before that DB await resolves —
  // deterministically simulates "torn down mid-await" without any
  // timing-dependent Completer/fake_async machinery.
  group(
    'AUD-dashboard-06 (SM-4): ref.mounted guards after in-flight awaits',
    () {
      /// Builds a real [Ref] sourced from [container] (the same technique
      /// `outboxDrainAndRecordAttempt`'s regression test uses) so
      /// `capturedRef.mounted` reflects the real Riverpod 3 framework
      /// disposal state, not a fake.
      Ref captureRef(ProviderContainer container) {
        late Ref capturedRef;
        final hostProvider = Provider<void>((ref) {
          capturedRef = ref;
        });
        container.read(hostProvider);
        return capturedRef;
      }

      test(
        'dashboardTrackCompletionPercentage: container disposed mid-track-read '
        '— no UnmountedRefException, resolves to 0.0',
        () async {
          final trackId = await _insertTrack(db, curriculumId: 'mishnayos');

          final container = _makeContainer(db);
          final capturedRef = captureRef(container);

          // Runs synchronously up to `await db.trackDao.getTrackById(trackId)`,
          // then suspends and returns control here.
          final resultFuture = dashboardTrackCompletionPercentage(
            capturedRef,
            trackId,
          );

          // Simulate the carousel card being swiped away / dashboard left
          // while that DB read is still in flight.
          container.dispose();
          expect(
            capturedRef.mounted,
            isFalse,
            reason:
                'container.dispose() must tear down the captured ref — '
                'this is the exact staleness this test simulates',
          );

          await expectLater(
            resultFuture,
            completes,
            reason:
                'no UnmountedRefException (or any exception) may reach '
                'the caller',
          );
          expect(await resultFuture, 0.0);
        },
      );

      test(
        'dashboardCompletionPercentage: container disposed mid-completions-read '
        '— no UnmountedRefException, resolves to 0.0',
        () async {
          final container = _makeContainer(db);
          final capturedRef = captureRef(container);

          // Runs synchronously up to
          // `await db.completionDao.getCompletionsByCurriculumAndProfile(...)`,
          // then suspends.
          final resultFuture = dashboardCompletionPercentage(
            capturedRef,
            CurriculumId.mishnayos,
          );

          container.dispose();
          expect(capturedRef.mounted, isFalse);

          await expectLater(resultFuture, completes);
          expect(await resultFuture, 0.0);
        },
      );

      test('stripStockMilestonesEffect: container disposed mid-strip — no '
          'UnmountedRefException, the gamification-settings push is safely '
          'skipped', () async {
        SharedPreferences.setMockInitialValues({});
        // A stock-ladder milestone so stripStockTemplateMilestones()
        // resolves `true` — without that, the original buggy code never
        // reaches the unguarded `ref.read(syncWriteFacadeProvider)` at all,
        // and this test would pass whether or not the guard exists.
        final milestoneService = RewardMilestoneService(
          db,
          profileId: _profileId,
        );
        await milestoneService.upsertMilestone(
          trackId: 10,
          title: 'Bronze Star',
          thresholdPoints: 500,
          milestoneId: 'stock-1',
        );

        final container = _makeContainer(
          db,
          extraOverrides: [
            rewardMilestoneServiceProvider.overrideWithValue(milestoneService),
          ],
        );
        final capturedRef = captureRef(container);

        // Runs synchronously up to
        // `await milestoneService.stripStockTemplateMilestones()`, then
        // suspends.
        final resultFuture = stripStockMilestonesEffect(capturedRef);

        container.dispose();
        expect(capturedRef.mounted, isFalse);

        await expectLater(resultFuture, completes);
      });

      test('dashboardPaceStatus: container disposed mid-goals-read — no '
          'UnmountedRefException', () async {
        final trackId = await _insertTrack(db, curriculumId: 'mishnayos');
        final now = DateTime.utc(2026, 1, 1);
        // A real goal so the function proceeds past the first `if
        // (goals.isEmpty) return null;` short-circuit and reaches the
        // second (unguarded) await -> ref.watch hazard.
        await db.goalDao.insertGoal(
          GoalsCompanion.insert(
            profileId: _profileId,
            curriculumId: 'mishnayos',
            trackId: trackId,
            targetDate: Value(DateTime.utc(2026, 6, 1)),
            createdAt: now,
            updatedAt: now,
          ),
        );

        final container = _makeContainer(db);
        final capturedRef = captureRef(container);

        // Runs synchronously up to
        // `await db.goalDao.getGoalsByCurriculumAndProfile(...)`, then
        // suspends.
        final resultFuture = dashboardPaceStatus(
          capturedRef,
          CurriculumId.mishnayos,
        );

        container.dispose();
        expect(capturedRef.mounted, isFalse);

        await expectLater(resultFuture, completes);
      });
    },
  );
}
