/// Unit tests for gamification_service_providers.dart.
///
/// AUD-gamification-11 (SM-7): [rewardMilestoneServiceProvider],
/// [streakStateProvider], and [streakServiceProvider] replaced ad-hoc
/// `RewardMilestoneService(db, profileId: ...)` /
/// `StreakService(db, profileId: ...)` /
/// `StreakStateProvider(db: ..., clock: ...)` construction at 9+ call sites
/// across `features/gamification/` and `features/dashboard/`. Coverage:
///   - each provider wires to userDatabaseProvider/activeProfileIdProvider
///     correctly (default, non-overridden wiring)
///   - each provider can be overridden directly via ProviderScope — the
///     override, not a freshly-constructed instance, is what callers read
///   - streakServiceProvider's StreakService reuses the (possibly
///     overridden) streakStateProvider instance rather than building its own
@Tags(['gamification'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/streak_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart';
import 'package:learning_tracker/features/gamification/streak/streak_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/drift_memory.dart';

/// Seeds a single streak event for [profileId] on the current UTC day.
Future<void> _seedStreakEventToday(
  UserDatabase db, {
  required int profileId,
}) async {
  final today = DateTime.now().toUtc();
  await db.streakEventDao.appendEvent(
    StreakEventsCompanion.insert(
      profileId: profileId,
      eventType: 'completion',
      dayUtc: DateTime.utc(today.year, today.month, today.day),
      eventTimestamp: today,
      clientDeviceId: const Value(null),
    ),
  );
}

void main() {
  setUp(() {
    // RewardMilestoneService config is SharedPreferences-backed.
    SharedPreferences.setMockInitialValues({});
  });

  group('rewardMilestoneServiceProvider', () {
    test(
      'wires to userDatabaseProvider/activeProfileIdProvider by default',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);

        final container = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWithValue(db),
            activeProfileIdProvider.overrideWithValue(1),
          ],
        );
        addTearDown(container.dispose);

        final service = container.read(rewardMilestoneServiceProvider);
        expect(service.profileId, 1);
      },
    );

    test(
      'can be overridden — callers read the override, not a fresh instance',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);

        final override = RewardMilestoneService(db, profileId: 999);
        final container = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWithValue(db),
            activeProfileIdProvider.overrideWithValue(1),
            rewardMilestoneServiceProvider.overrideWithValue(override),
          ],
        );
        addTearDown(container.dispose);

        expect(
          identical(container.read(rewardMilestoneServiceProvider), override),
          isTrue,
        );
        // profileId comes from the OVERRIDE (999), not
        // activeProfileIdProvider (1) — proves the override wins over the
        // default wiring, not merely that a service object was returned.
        expect(container.read(rewardMilestoneServiceProvider).profileId, 999);
      },
    );
  });

  group('streakStateProvider', () {
    test('wires to userDatabaseProvider by default', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);

      final container = ProviderContainer(
        overrides: [userDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final state = await container
          .read(streakStateProvider)
          .read(profileId: 1);
      expect(state.currentStreak, 0);
    });

    test("can be overridden — reflects the override's database, not "
        'userDatabaseProvider', () async {
      final defaultDb = inMemoryDb();
      addTearDown(defaultDb.close);
      await seedProfile(defaultDb); // no streak events

      final overrideDb = inMemoryDb();
      addTearDown(overrideDb.close);
      await seedProfile(overrideDb);
      await _seedStreakEventToday(overrideDb, profileId: 1);

      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(defaultDb),
          streakStateProvider.overrideWithValue(
            StreakStateProvider(
              db: overrideDb,
              clock: const SystemLocalDayClock(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = await container
          .read(streakStateProvider)
          .read(profileId: 1);
      expect(
        state.currentStreak,
        greaterThanOrEqualTo(1),
        reason:
            'defaultDb has no streak events; only overrideDb does — '
            'a non-zero streak proves the override, not userDatabaseProvider, '
            'was read.',
      );
    });
  });

  group('streakServiceProvider', () {
    test(
      'wires to userDatabaseProvider/activeProfileIdProvider by default',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);

        final container = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWithValue(db),
            activeProfileIdProvider.overrideWithValue(1),
          ],
        );
        addTearDown(container.dispose);

        final state = await container.read(streakServiceProvider).getStreak();
        expect(state.currentStreak, 0);
      },
    );

    test(
      'reuses the (possibly overridden) streakStateProvider instance instead '
      'of constructing its own',
      () async {
        final defaultDb = inMemoryDb();
        addTearDown(defaultDb.close);
        await seedProfile(defaultDb); // no streak events

        final overrideDb = inMemoryDb();
        addTearDown(overrideDb.close);
        await seedProfile(overrideDb);
        await _seedStreakEventToday(overrideDb, profileId: 1);

        final container = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWithValue(defaultDb),
            activeProfileIdProvider.overrideWithValue(1),
            streakStateProvider.overrideWithValue(
              StreakStateProvider(
                db: overrideDb,
                clock: const SystemLocalDayClock(),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final state = await container.read(streakServiceProvider).getStreak();
        expect(
          state.currentStreak,
          greaterThanOrEqualTo(1),
          reason:
              'streakServiceProvider must read through the overridden '
              'streakStateProvider rather than building its own '
              'StreakStateProvider(db: userDatabaseProvider, ...).',
        );
      },
    );

    test('can be overridden wholesale — callers read the override', () async {
      final db = inMemoryDb();
      addTearDown(db.close);

      final override = StreakService(db, profileId: 999);
      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          activeProfileIdProvider.overrideWithValue(1),
          streakServiceProvider.overrideWithValue(override),
        ],
      );
      addTearDown(container.dispose);

      expect(
        identical(container.read(streakServiceProvider), override),
        isTrue,
      );
    });
  });
}
