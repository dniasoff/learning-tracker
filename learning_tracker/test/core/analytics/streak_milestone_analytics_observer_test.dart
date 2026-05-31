/// Regression tests for R6-3:
/// [streakMilestoneAnalyticsObserverProvider] must swallow errors from the
/// streak source stream and from analytics calls without propagating to the
/// host StreamProvider or crashing the app-shell build.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/analytics/streak_milestone_analytics_observer.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';

import '../../helpers/drift_memory.dart';

void main() {
  group('streakMilestoneAnalyticsObserverProvider — error resilience (R6-3)', () {
    // ── 1. stream source errors ───────────────────────────────────────────────

    test('when the streak source stream emits an error the provider does NOT '
        'enter an error state', () async {
      final analytics = FakeAnalyticsService();
      // Close the DB before the observer opens it so restoreIfEmpty throws
      // and StreakStateProvider.watch surfaces a stream error.
      final db = inMemoryDb();
      await seedProfile(db); // profile id = 1
      await db.close(); // force an error when the observer tries to watch

      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          activeProfileIdProvider.overrideWithValue(1),
          analyticsServiceProvider.overrideWithValue(analytics),
        ],
      );
      addTearDown(container.dispose);

      // Listen to the provider to activate the async* generator.
      final sub = container.listen(
        streakMilestoneAnalyticsObserverProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      // Give the async* generator time to run the await-for and catch the
      // error from the closed DB.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(streakMilestoneAnalyticsObserverProvider);

      // The provider MUST NOT be in the error state — it should be loading
      // or data (void), never error.
      expect(
        state.hasError,
        isFalse,
        reason:
            'a streak source error must be swallowed by the observer, '
            'not propagated to the StreamProvider',
      );
    });

    // ── 2. analytics call errors ──────────────────────────────────────────────

    test('when analytics.logStreakMilestoneReached throws the provider does NOT '
        'enter an error state and the error is swallowed', () async {
      // A FakeAnalyticsService that throws on logEvent.
      final throwingAnalytics = _ThrowingAnalyticsService();
      final db = inMemoryDb();
      await seedProfile(db);

      // Seed 7 events so the milestone fires and the throwing service is called.
      final base = DateTime.utc(2026, 5, 25);
      for (var i = 0; i < 7; i++) {
        final day = base.add(Duration(days: i));
        await db.streakEventDao.appendEvent(
          StreakEventsCompanion.insert(
            profileId: 1,
            eventType: 'completion',
            dayUtc: day,
            eventTimestamp: day,
            clientDeviceId: const Value(null),
          ),
        );
      }

      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          activeProfileIdProvider.overrideWithValue(1),
          analyticsServiceProvider.overrideWithValue(throwingAnalytics),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(db.close);

      final sub = container.listen(
        streakMilestoneAnalyticsObserverProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(streakMilestoneAnalyticsObserverProvider);

      expect(
        state.hasError,
        isFalse,
        reason:
            'a throwing analytics call must not propagate to the '
            'StreamProvider error state',
      );
    });

    // ── 3. happy-path milestones still fire ───────────────────────────────────

    test('happy path: milestone fires when streak reaches threshold', () async {
      final analytics = FakeAnalyticsService();
      final db = inMemoryDb();
      await seedProfile(db);

      // Seed 7 consecutive streak events so currentStreak == 7.
      final base = DateTime.utc(2026, 5, 25);
      for (var i = 0; i < 7; i++) {
        final day = base.add(Duration(days: i));
        await db.streakEventDao.appendEvent(
          StreakEventsCompanion.insert(
            profileId: 1,
            eventType: 'completion',
            dayUtc: day,
            eventTimestamp: day,
            clientDeviceId: const Value(null),
          ),
        );
      }

      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          activeProfileIdProvider.overrideWithValue(1),
          analyticsServiceProvider.overrideWithValue(analytics),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(db.close);

      final sub = container.listen(
        streakMilestoneAnalyticsObserverProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      // Give the stream a full event loop cycle to emit + process.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        analytics.countOf(AnalyticsEvent.streakMilestoneReached),
        greaterThanOrEqualTo(1),
        reason: 'milestone=7 must fire when streak reaches 7',
      );
      expect(
        analytics.lastParamsOf(AnalyticsEvent.streakMilestoneReached),
        containsPair('milestone', 7),
      );
    });
  });
}

// ── Test doubles ──────────────────────────────────────────────────────────────

/// An [AnalyticsService] whose [logEvent] always throws.
///
/// Used to verify that a throwing analytics call is absorbed by the observer
/// and does NOT propagate to the StreamProvider.
class _ThrowingAnalyticsService extends AnalyticsService {
  @override
  Future<void> logEvent(String name, {Map<String, Object?>? parameters}) {
    throw Exception('analytics unavailable (test double)');
  }
}
