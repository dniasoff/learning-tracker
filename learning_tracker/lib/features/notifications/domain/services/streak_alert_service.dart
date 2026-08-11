import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/gamification/streak/streak_state_service.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';


/// Service for managing streak protection alert notifications.
///
/// Scoped to a single profile so each profile's alert reflects its own
/// streak and its own completion activity.
///
/// W3.20: `streaks` table dropped; streak state derived from
/// [StreakStateService] (streak_events → StreakReducer).
class StreakAlertService {
  /// [ref] replaces the former `UserDatabase db`: [StreakStateService]
  /// resolves its Firestore repository through Riverpod now. `db` was used here
  /// ONLY to build that service — verified before the change.
  StreakAlertService({
    required Ref ref,
    required NotificationGateway notificationService,
    required String profileId,
    DateTime Function()? clock,
    AnalyticsService? analytics,
    LocalDayClock? streakClock,
    required Future<bool> Function(DateTime start, DateTime end)
    hasCompletionsInRange,
  }) : _hasCompletionsInRange = hasCompletionsInRange,
       _notificationService = notificationService,
       _profileId = profileId,
       _clock = clock ?? DateTimeFactory.nowUtc,
       _analytics = analytics ?? const NullAnalyticsService(),
       _streakProvider = StreakStateService(
         ref: ref,
         clock: streakClock ?? const SystemLocalDayClock(),
       );

  /// Answers "did this profile complete anything in `[start, end]`?".
  ///
  /// Injected rather than resolved here: the Firestore equivalent
  /// (`FirestoreCompletionRepository.hasCompletionsInDateRange`) lives in the
  /// data-access ring, which AD-23/AD-28 forbid a `domain/` file from
  /// importing, and the domain `CompletionRepository` interface exposes no
  /// date-range read. A callback keeps the dependency at the composition root
  /// and lets tests supply one with no database at all.
  final Future<bool> Function(DateTime start, DateTime end)
  _hasCompletionsInRange;
  final NotificationGateway _notificationService;
  final String _profileId;
  final DateTime Function() _clock;
  final AnalyticsService _analytics;
  final StreakStateService _streakProvider;

  /// Evaluate streak state and schedule or cancel the alert accordingly.
  ///
  /// [title] and [localizedBody] are optional locale-resolved strings (UX-DR7).
  /// [localizedBody] is a function of the current streak length; when omitted,
  /// the service falls back to the English [buildBody]/"Streak at Risk!" copy.
  Future<void> evaluate({
    required int hour,
    required int minute,
    String? title,
    String Function(int currentStreak)? localizedBody,
  }) async {
    final streakState = await _streakProvider.read();

    if (streakState.currentStreak == 0) {
      await cancelAlert();
      return;
    }

    if (await _hasCompletionsToday()) {
      await cancelAlert();
      return;
    }

    await scheduleAlert(
      hour: hour,
      minute: minute,
      currentStreak: streakState.currentStreak,
      title: title,
      localizedBody: localizedBody,
    );
  }

  Future<void> scheduleAlert({
    required int hour,
    required int minute,
    required int currentStreak,
    String? title,
    String Function(int currentStreak)? localizedBody,
  }) async {
    final body = localizedBody?.call(currentStreak) ?? buildBody(currentStreak);

    // H2 fix: schedule under this profile's per-profile streak-alert ID block
    // (profileId*1000 + 1) so each profile keeps an independent alert and a
    // profile switch no longer overwrites the single legacy id=1 schedule.
    await _notificationService.scheduleStreakAlertForProfile(
      profileId: _profileId,
      hour: hour,
      minute: minute,
      body: body,
      title: title ?? 'Streak at Risk!',
    );
    // Story 27.14 (DNI-390): fire analytics event when streak alert fires.
    unawaited(
      _analytics.logNotificationFired(notificationType: 'streak_alert'),
    );
  }

  Future<void> cancelAlert() async {
    // H2 fix: cancel the per-profile streak-alert id (profileId*1000 + 1).
    await _notificationService.cancelStreakAlertForProfile(_profileId);
  }

  Future<void> onCompletionRecorded() async {
    await cancelAlert();
  }

  Future<bool> _hasCompletionsToday() async {
    final now = _clock();
    final startOfDay = LocalDayUtils.startOfLocalDay(now);
    final endOfDay = LocalDayUtils.endOfLocalDay(now);

    return _hasCompletionsInRange(startOfDay, endOfDay);
  }

  static String buildBody(int currentStreak) {
    return 'Your $currentStreak-day streak is at risk!';
  }
}
