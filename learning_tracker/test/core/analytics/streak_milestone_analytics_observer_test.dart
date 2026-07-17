/// Regression tests for R6-3:
/// [streakMilestoneAnalyticsObserverProvider] must swallow errors from the
/// streak source stream and from analytics calls without propagating to the
/// host StreamProvider or crashing the app-shell build.
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/analytics/streak_milestone_analytics_observer.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';

import '../../helpers/drift_memory.dart';

void main() {
  group('streakMilestoneAnalyticsObserverProvider — error resilience (R6-3)', () {
    // ── 1. stream source errors ───────────────────────────────────────────────

    test('when the streak source stream emits an error the provider does NOT '
        'enter an error state', () async {
      final analytics = FakeAnalyticsService();
      // Close the DB before the observer opens it so restoreIfEmpty throws
      // and StreakStateService.watch surfaces a stream error.
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

    test('happy path: milestone fires when streak reaches threshold '
        '(AUD-core-analytics-02)', () async {
      final analytics = _MilestoneAwaitingAnalyticsService();
      final db = inMemoryDb();
      await seedProfile(db);

      // Fixed clock instead of DateTime.now() — the observer now watches
      // localDayClockProvider (mirrors outbox_providers.dart's
      // localDayClockProvider seam) instead of hardcoding
      // `const SystemLocalDayClock()`, so "today" is deterministic and the
      // seeded data no longer needs to be anchored to the real wall clock.
      // Noon UTC keeps the local-day conversion inside the same calendar
      // date across any host machine timezone (max UTC offset is ±14h).
      final clock = FakeLocalDayClock(DateTime.utc(2026, 5, 31, 12));

      // Seed 7 consecutive streak events ENDING on the fixed "today" so
      // currentStreak == 7.
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
          localDayClockProvider.overrideWithValue(clock),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(db.close);

      final sub = container.listen(
        streakMilestoneAnalyticsObserverProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      // Event-driven wait instead of a wall-clock polling loop: the fake
      // analytics service completes a Completer the instant
      // logStreakMilestoneReached fires, so this resolves as soon as the
      // streak-state stream's first emission lands (near-instant), with a
      // bounded timeout only as a safety net against a genuine hang.
      await analytics.milestoneFired.timeout(
        const Duration(seconds: 5),
        onTimeout: () => fail(
          'milestone=7 did not fire within 5s of a deterministic '
          'fixed-clock seed',
        ),
      );

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

  group(
    'streakMilestoneAnalyticsObserverProvider — EH-4 (AUD-core-analytics-04)',
    () {
      test('a genuine programming-error Error (not Exception, not the '
          'anticipated closed-db StateError) propagates to the StreamProvider '
          'error state instead of being swallowed as a warning', () async {
        final buggyAnalytics = _BuggyAnalyticsService();
        final db = inMemoryDb();
        await seedProfile(db);

        // Seed 7 consecutive streak events ENDING TODAY so currentStreak
        // == 7 and the milestone loop actually calls the (buggy) analytics
        // service, which throws a bare `Error` subtype synchronously — the
        // exact "real bug, not a recoverable runtime condition" scenario
        // EH-4 says must never be caught by a bare `catch (e, st)`.
        // Anchored relative to "now" (see the happy-path test above) —
        // a hardcoded past date stops being a *current* streak once the
        // calendar advances past it.
        final todayUtc = DateTime.now().toUtc();
        final base = DateTime.utc(
          todayUtc.year,
          todayUtc.month,
          todayUtc.day,
        ).subtract(const Duration(days: 6));
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
            analyticsServiceProvider.overrideWithValue(buggyAnalytics),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(db.close);

        final sub = container.listen(
          streakMilestoneAnalyticsObserverProvider,
          (_, __) {},
        );
        addTearDown(sub.close);

        // Poll until the provider settles into an error state or the
        // milestone has clearly had a chance to fire and be swallowed.
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        var state = container.read(streakMilestoneAnalyticsObserverProvider);
        while (DateTime.now().isBefore(deadline) && !state.hasError) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          state = container.read(streakMilestoneAnalyticsObserverProvider);
        }

        expect(
          state.hasError,
          isTrue,
          reason:
              'a bare Error subtype (a genuine programming bug, not '
              'Exception and not the anticipated closed-db StateError) '
              'must propagate to the StreamProvider error state — '
              'swallowing it as a logger.warning() masks real bugs '
              '(EH-4)',
        );
        expect(state.error, isA<_SimulatedBugError>());
      });
    },
  );
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

/// A [FakeAnalyticsService] that additionally exposes [milestoneFired] — a
/// future that completes the instant `AnalyticsEvent.streakMilestoneReached`
/// is logged. Lets the happy-path test await the exact event instead of
/// polling `DateTime.now()` on a fixed interval.
class _MilestoneAwaitingAnalyticsService extends AnalyticsService {
  final FakeAnalyticsService _delegate = FakeAnalyticsService();
  final Completer<void> _milestoneFired = Completer<void>();

  Future<void> get milestoneFired => _milestoneFired.future;

  int countOf(String name) => _delegate.countOf(name);

  Map<String, Object?>? lastParamsOf(String name) =>
      _delegate.lastParamsOf(name);

  @override
  Future<void> logEvent(String name, {Map<String, Object?>? parameters}) async {
    await _delegate.logEvent(name, parameters: parameters);
    if (name == AnalyticsEvent.streakMilestoneReached &&
        !_milestoneFired.isCompleted) {
      _milestoneFired.complete();
    }
  }
}

/// A bare `Error` — never `Exception`, never `StateError` — standing in for
/// a genuine programming bug (e.g. `NoSuchMethodError`, `TypeError`,
/// `RangeError`). EH-4 requires this class of failure to propagate rather
/// than be swallowed as a warning.
class _SimulatedBugError extends Error {
  @override
  String toString() => 'simulated real bug (not Exception, not StateError)';
}

/// An [AnalyticsService] whose [logEvent] throws a bare [_SimulatedBugError]
/// *synchronously* (not via a failed [Future]) — the same call shape as
/// [AnalyticsService.logStreakMilestoneReached]'s non-`async` delegation to
/// [logEvent], so the throw happens before `.catchError` is ever attached
/// and is caught by the observer's own `try`/`catch`.
class _BuggyAnalyticsService extends AnalyticsService {
  @override
  Future<void> logEvent(String name, {Map<String, Object?>? parameters}) {
    throw _SimulatedBugError();
  }
}
