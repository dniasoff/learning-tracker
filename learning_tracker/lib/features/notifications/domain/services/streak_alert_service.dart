import 'dart:async';

import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
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
  StreakAlertService({
    required UserDatabase db,
    required NotificationGateway notificationService,
    required int profileId,
    DateTime Function()? clock,
    AnalyticsService? analytics,
    LocalDayClock? streakClock,
  }) : _db = db,
       _notificationService = notificationService,
       _profileId = profileId,
       _clock = clock ?? DateTimeFactory.nowUtc,
       _analytics = analytics ?? const NullAnalyticsService(),
       _streakProvider = StreakStateService(
         db: db,
         clock: streakClock ?? const SystemLocalDayClock(),
       );

  final UserDatabase _db;
  final NotificationGateway _notificationService;
  final int _profileId;
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
    final streakState = await _streakProvider.read(profileId: _profileId);

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

    return await _db.completionDao.hasCompletionsInDateRangeByProfile(
      startOfDay,
      endOfDay,
      _profileId,
    );
  }

  static String buildBody(int currentStreak) {
    return 'Your $currentStreak-day streak is at risk!';
  }
}
