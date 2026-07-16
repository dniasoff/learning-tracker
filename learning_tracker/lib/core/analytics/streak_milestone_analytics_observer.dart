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

/// Keeps alive to monitor streak milestones for the active profile.
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
/// Error handling: the observer is a fire-and-forget background effect.
/// Any error from the streak source or from the analytics call is swallowed
/// (logged at WARNING level) so a transient failure never propagates to the
/// host [StreamProvider] or crashes the app-shell build.
final streakMilestoneAnalyticsObserverProvider =
    StreamProvider.autoDispose<void>((ref) async* {
      final db = ref.watch(userDatabaseProvider);
      final profileId = ref.watch(activeProfileIdProvider);
      final analytics = ref.watch(analyticsServiceProvider);
      final logger = AppLogger.instance;

      final stateProvider = StreakStateService(
        db: db,
        clock: ref.watch(localDayClockProvider),
      );

      final firedMilestones = <int>{};

      try {
        await for (final state in stateProvider.watch(profileId: profileId)) {
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
          } catch (e, st) {
            // A bad tick (e.g. unexpected state shape) must not kill the loop.
            logger.warning(
              event: 'streak_milestone_analytics_tick_error',
              exception: e,
              stackTrace: st,
            );
          }
        }
      } catch (e, st) {
        // The streak source stream itself errored (e.g. database closed, clock
        // failure).  Log and return — the generator yields nothing further but
        // the StreamProvider stays in the data/loading state it last held
        // rather than entering error state.
        logger.warning(
          event: 'streak_milestone_analytics_stream_error',
          exception: e,
          stackTrace: st,
        );
      }
    });
