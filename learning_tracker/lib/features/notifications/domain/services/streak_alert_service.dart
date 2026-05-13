import 'dart:async';

import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';

/// Service for managing streak protection alert notifications.
///
/// Scoped to a single profile so each profile's alert reflects its own
/// streak and its own completion activity.
class StreakAlertService {
  StreakAlertService({
    required UserDatabase db,
    required NotificationService notificationService,
    required int profileId,
    DateTime Function()? clock,
    AnalyticsService? analytics,
  }) : _db = db,
       _notificationService = notificationService,
       _profileId = profileId,
       _clock = clock ?? DateTimeFactory.nowUtc,
       _analytics = analytics ?? const NullAnalyticsService();

  final UserDatabase _db;
  final NotificationService _notificationService;
  final int _profileId;
  final DateTime Function() _clock;
  final AnalyticsService _analytics;

  /// Evaluate streak state and schedule or cancel the alert accordingly.
  Future<void> evaluate({required int hour, required int minute}) async {
    final streak = await _db.streakDao.getStreakByProfile(_profileId);

    if (streak == null || streak.currentStreak == 0) {
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
      currentStreak: streak.currentStreak,
    );
  }

  Future<void> scheduleAlert({
    required int hour,
    required int minute,
    required int currentStreak,
  }) async {
    final body = buildBody(currentStreak);

    await _notificationService.scheduleStreakAlert(
      hour: hour,
      minute: minute,
      body: body,
    );
    // Story 27.14 (DNI-390): fire analytics event when streak alert fires.
    unawaited(
      _analytics.logNotificationFired(notificationType: 'streak_alert'),
    );
  }

  Future<void> cancelAlert() async {
    await _notificationService.cancelStreakAlert();
  }

  Future<void> onCompletionRecorded() async {
    await cancelAlert();
  }

  Future<bool> _hasCompletionsToday() async {
    final now = _clock();
    final startOfDay = DateUtils.startOfLocalDay(now);
    final endOfDay = DateUtils.endOfLocalDay(now);

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
