import 'dart:async';

import 'package:flutter/material.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';

/// Orchestrates scheduling/cancelling the daily reminder notification.
///
/// Pure logic — no Riverpod dependency. Providers call these methods.
class NotificationScheduler {
  const NotificationScheduler({
    required this.service,
    AnalyticsService? analytics,
  }) : _analytics = analytics ?? const NullAnalyticsService();

  final NotificationService service;
  final AnalyticsService _analytics;

  /// Schedule (or reschedule) the daily reminder.
  ///
  /// Fires [AnalyticsEvent.notificationFired] after scheduling succeeds
  /// (Story 27.14, DNI-390).
  Future<void> schedule({
    required TimeOfDay time,
    required int taskCount,
    required int curriculumCount,
  }) async {
    final body =
        'You have $taskCount '
        'task${taskCount == 1 ? '' : 's'} across '
        '$curriculumCount curricul${curriculumCount == 1 ? 'um' : 'a'} today';
    await service.scheduleDailyReminder(
      hour: time.hour,
      minute: time.minute,
      body: body,
    );
    // Story 27.14 (DNI-390): fire analytics event when notification fires.
    unawaited(
      _analytics.logNotificationFired(notificationType: 'daily_reminder'),
    );
  }

  /// Schedule cancelled due to sacred time — fire suppression event.
  ///
  /// Fires [AnalyticsEvent.notificationSuppressedSacredTime] (Story 27.14).
  Future<void> cancelForSacredTime() async {
    await service.cancelDailyReminder();
    unawaited(
      _analytics.logNotificationSuppressedSacredTime(
        notificationType: 'daily_reminder',
      ),
    );
  }

  /// Cancel the daily reminder.
  Future<void> cancel() async {
    await service.cancelDailyReminder();
  }
}
