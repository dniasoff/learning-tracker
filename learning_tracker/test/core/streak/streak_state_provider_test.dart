/// Tests for StreakStateProvider covering read() and watch().
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/streak/streak_state_provider.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';

import '../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late FakeLocalDayClock clock;
  late StreakStateProvider provider;
  const profileId = 1;

  // Helper to insert a streak event.
  Future<void> insertEvent(UserDatabase db, DateTime timestamp) async {
    await db.streakEventDao.appendEvent(
      StreakEventsCompanion.insert(
        profileId: profileId,
        eventType: 'completion',
        dayUtc: DateTime.utc(timestamp.year, timestamp.month, timestamp.day),
        eventTimestamp: timestamp,
        clientDeviceId: const Value(null),
      ),
    );
  }

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db); // creates learner_profiles(id=1)
    // Insert a second profile so streak_events with profileId=2 can satisfy FK.
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        email: 'test2@example.com',
        tier: 'localBorn',
        displayName: 'Test User 2',
        userMode: 'adult',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await db.into(db.learnerProfiles).insert(
      LearnerProfilesCompanion.insert(
        accountId: 2,
        displayName: 'Test User 2',
        mode: 'adult',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    clock = FakeLocalDayClock(DateTime.utc(2026, 5, 14, 12));
    provider = StreakStateProvider(db: db, clock: clock);
  });

  tearDown(() async {
    await db.close();
  });

  // ── read() ────────────────────────────────────────────────────────────────

  group('StreakStateProvider.read', () {
    test('returns zero streak when no events exist', () async {
      final state = await provider.read(profileId: profileId);
      expect(state.currentStreak, 0);
    });

    test('returns empty state when no events', () async {
      final state = await provider.read(profileId: profileId);
      expect(state.currentStreak, 0);
      expect(state.maxStreak, 0);
      expect(state.lastCompletionDayUtc, isNull);
    });

    test('returns streak of 1 for a single completion today', () async {
      await insertEvent(db, DateTime.utc(2026, 5, 14));

      final state = await provider.read(profileId: profileId);
      expect(state.currentStreak, 1);
      expect(state.maxStreak, 1);
    });

    test(
      'returns streak of 2 for completions on two consecutive days',
      () async {
        await insertEvent(db, DateTime.utc(2026, 5, 13));
        await insertEvent(db, DateTime.utc(2026, 5, 14));

        final state = await provider.read(profileId: profileId);
        expect(state.currentStreak, 2);
        expect(state.maxStreak, 2);
      },
    );

    test('streak lapses when last completion was 2+ days ago', () async {
      // Last completion 3 days ago, today is May 14.
      await insertEvent(db, DateTime.utc(2026, 5, 11));

      final state = await provider.read(profileId: profileId);
      expect(state.currentStreak, 0);
      expect(state.maxStreak, 1);
    });

    test('does not count events from another profile', () async {
      // Insert event for profile 2.
      await db.streakEventDao.appendEvent(
        StreakEventsCompanion.insert(
          profileId: 2,
          eventType: 'completion',
          dayUtc: DateTime.utc(2026, 5, 14),
          eventTimestamp: DateTime.utc(2026, 5, 14),
          clientDeviceId: const Value(null),
        ),
      );

      final state = await provider.read(profileId: profileId);
      expect(state.currentStreak, 0);
    });
  });

  // ── watch() ───────────────────────────────────────────────────────────────

  group('StreakStateProvider.watch', () {
    test('emits streak state as a stream', () async {
      // First emission should be the initial state (no events = 0 streak).
      final firstState = await provider.watch(profileId: profileId).first;
      expect(firstState.currentStreak, 0);
    });

    test('emits empty state when no events', () async {
      final state = await provider.watch(profileId: profileId).first;
      expect(state.currentStreak, 0);
      expect(state.maxStreak, 0);
    });

    test('emits zero streak when profile has no events', () async {
      final states = provider.watch(profileId: 99);
      final first = await states.first;
      expect(first.currentStreak, 0);
    });

    test('emits updated state after event is inserted', () async {
      await insertEvent(db, DateTime.utc(2026, 5, 14));

      final state = await provider.watch(profileId: profileId).first;
      expect(state.currentStreak, 1);
      expect(state.maxStreak, 1);
    });

    test('stream emits new value when event is added while watching', () async {
      final states = <int>[];
      final sub = provider
          .watch(profileId: profileId)
          .listen((s) => states.add(s.currentStreak));
      addTearDown(sub.cancel);

      // Give the first emission time to arrive.
      await Future<void>.delayed(Duration.zero);
      expect(states, isNotEmpty); // zero at start

      await insertEvent(db, DateTime.utc(2026, 5, 14));
      await Future<void>.delayed(Duration.zero);

      // Should have received at least 2 emissions.
      expect(states.length, greaterThanOrEqualTo(2));
      expect(states.last, 1);
    });
  });
}
