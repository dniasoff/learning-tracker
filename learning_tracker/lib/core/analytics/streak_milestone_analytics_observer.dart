/// Riverpod provider that watches streak state and fires
/// [AnalyticsEvent.streakMilestoneReached] the first time the
/// currentStreak crosses each milestone threshold (7, 30, 100 days).
///
/// Lives in [core/analytics/] so all analytics calls are confined to this
/// layer (Story 27.14, DNI-390).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/gamification/streak/streak_state_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';

/// Stays active while watched to monitor streak milestones for the active
/// profile.
///
/// Reads the streak stream and fires [AnalyticsEvent.streakMilestoneReached]
/// the first time [currentStreak] reaches or crosses each milestone value in
/// [kStreakMilestones] within this app session.
///
/// "First time in session" semantics prevent duplicate events when the
/// provider is re-read: the set of already-fired milestones resets on
/// provider disposal (i.e. when the active profile changes or the app
/// restarts).
///
/// Wire via: `ref.watch(streakMilestoneAnalyticsObserverProvider)` in the
/// app shell to activate.
///
/// Error handling: the observer is a fire-and-forget background effect. Any
/// [Exception] from the streak source or from the analytics call is
/// swallowed (logged at WARNING level) so a transient failure never
/// propagates to the host [StreamProvider] or crashes the app-shell build.
/// The one `Error` subtype swallowed the same way is the [StateError] Drift
/// throws when a query hits a database that closed mid-teardown (the D17
/// profile/account-swap race) — an anticipated condition, not a bug. Every
/// other `Error` subtype (`NoSuchMethodError`, `TypeError`, `RangeError`,
/// ...) is a genuine programming bug and is intentionally left uncaught so
/// it propagates to the zone's `onError` handler instead of being
/// downgraded to a warning log line (EH-4, AUD-core-analytics-04).
final streakMilestoneAnalyticsObserverProvider =
    StreamProvider.autoDispose<void>((ref) async* {
      final profileId = ref.watch(activeProfileIdProvider);
      final analytics = ref.watch(analyticsServiceProvider);
      final logger = AppLogger.instance;

      final stateProvider = StreakStateService(
        ref: ref,
        clock: ref.watch(localDayClockProvider),
      );

      final firedMilestones = <int>{};

      try {
        await for (final state in stateProvider.watch()) {
          try {
            final current = state.currentStreak;
            for (final milestone in kStreakMilestones) {
              if (current >= milestone &&
                  !firedMilestones.contains(milestone)) {
                firedMilestones.add(milestone);
                unawaited(
                  analytics
                      .logStreakMilestoneReached(milestone: milestone)
                      .catchError((Object e, StackTrace st) {
                        logger.warning(
                          event: 'streak_milestone_analytics_log_failed',
                          fields: {'milestone': milestone},
                          exception: e,
                          stackTrace: st,
                        );
                      }),
                );
              }
            }
          } on Exception catch (e, st) {
            // A bad tick (e.g. unexpected state shape) must not kill the loop.
            // AUD-core-analytics-04: typed to `on Exception` (EH-4) — a bare
            // `Error` here (NoSuchMethodError, TypeError, RangeError, ...)
            // signals a real bug and must propagate, not be downgraded to a
            // warning log line.
            logger.warning(
              event: 'streak_milestone_analytics_tick_error',
              exception: e,
              stackTrace: st,
            );
          }
        }
      } on Exception catch (e, st) {
        // The streak source stream itself errored (e.g. clock failure).  Log
        // and return — the generator yields nothing further but the
        // StreamProvider stays in the data/loading state it last held rather
        // than entering error state.
        // AUD-core-analytics-04: typed to `on Exception` (EH-4); see the
        // `on StateError` clause below for the one anticipated `Error`
        // subtype this observer also swallows.
        logger.warning(
          event: 'streak_milestone_analytics_stream_error',
          exception: e,
          stackTrace: st,
        );
      } on StateError catch (e, st) {
        // AUD-core-analytics-04: the closed-database race (D17 profile/
        // account-swap teardown window — restoreIfEmpty or a live query
        // hitting a Drift handle mid-close) throws `StateError`, an `Error`
        // subtype. It is the one Error EH-4's "never catch Error subtypes"
        // is deliberately *not* applied to here: it is an anticipated,
        // already-regression-tested condition (see
        // streak_milestone_analytics_observer_test.dart, R6-3 test 1), not a
        // programming bug. Every other Error subtype is intentionally left
        // uncaught above.
        logger.warning(
          event: 'streak_milestone_analytics_stream_error',
          exception: e,
          stackTrace: st,
        );
      }
    });
