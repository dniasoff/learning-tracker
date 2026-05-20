import 'dart:async';

import 'package:flutter/material.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/features/notifications/data/services/sacred_window_repository.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_location.dart';
import 'package:timezone/timezone.dart' as tz;

/// Number of days in the rolling one-shot batch (DNI-367, Story 26.24).
const int kBatchDays = 14;

/// Orchestrates scheduling/cancelling the daily reminder notification.
///
/// DNI-367 (Story 26.24): scheduleReminder() replaces the old repeating
/// schedule with a rolling 14-day batch of pre-filtered one-shots. Each
/// fire-time is checked against [SacredWindowRepository.isWindowActive] and
/// suppressed if it falls inside a Sacred Time block.
///
/// Pure logic — no Riverpod dependency. Providers call these methods.
class NotificationScheduler {
  NotificationScheduler({
    required this.service,
    SacredWindowRepository? sacredWindowRepository,
    AnalyticsService? analytics,
  }) : _sacredWindowRepository = sacredWindowRepository,
       _analytics = analytics ?? const NullAnalyticsService();

  final NotificationGateway service;
  final SacredWindowRepository? _sacredWindowRepository;
  final AnalyticsService _analytics;

  /// Schedule (or reschedule) the daily reminder as a rolling 14-day batch of
  /// pre-filtered one-shot notifications.
  ///
  /// [title] and [body] should be locale-resolved at call time (UX-DR7).
  /// [location] and [inIsrael] are used to filter Sacred Time windows.
  ///
  /// Each of the next 14 days is checked: if the fire-time for that day falls
  /// inside a Sacred Time block, it is silently suppressed.
  ///
  /// Fires [AnalyticsEvent.notificationFired] after scheduling succeeds
  /// (Story 27.14, DNI-390).
  Future<void> scheduleReminder({
    required TimeOfDay time,
    required String title,
    required String body,
    SacredLocation? location,
    bool inIsrael = false,
  }) async {
    final fireTimes = buildFireTimesForTest(
      time: time,
      location: location,
      inIsrael: inIsrael,
      fromDay: null,
    );

    await service.scheduleBatchReminders(
      fireTimes: fireTimes,
      title: title,
      body: body,
    );

    unawaited(
      _analytics.logNotificationFired(notificationType: 'daily_reminder'),
    );
  }

  /// Legacy schedule method — kept for backwards compatibility with existing
  /// providers and tests. Delegates to [scheduleReminder] with a generic body
  /// that does NOT support locale.
  ///
  /// Prefer [scheduleReminder] for new call sites.
  Future<void> schedule({
    required TimeOfDay time,
    required int taskCount,
    required int curriculumCount,
    SacredLocation? location,
    bool inIsrael = false,
  }) async {
    final body =
        'You have $taskCount '
        'task${taskCount == 1 ? '' : 's'} across '
        '$curriculumCount curricul${curriculumCount == 1 ? 'um' : 'a'} today';
    await scheduleReminder(
      time: time,
      title: 'Learning Reminder',
      body: body,
      location: location,
      inIsrael: inIsrael,
    );
  }

  /// Schedule cancelled due to sacred time — fire suppression event.
  ///
  /// Fires [AnalyticsEvent.notificationSuppressedSacredTime] (Story 27.14).
  Future<void> cancelForSacredTime() async {
    await service.cancelBatchReminders();
    await service.cancelDailyReminder();
    unawaited(
      _analytics.logNotificationSuppressedSacredTime(
        notificationType: 'daily_reminder',
      ),
    );
  }

  /// Cancel all daily reminder notifications (legacy + batch).
  Future<void> cancel() async {
    await service.cancelDailyReminder();
    await service.cancelBatchReminders();
  }

  /// Visible-for-testing: builds and returns the filtered list of
  /// [tz.TZDateTime] fire-times for the next [kBatchDays] days.
  ///
  /// [fromDay] overrides "today" for deterministic test scenarios. When null,
  /// uses [tz.TZDateTime.now(tz.local)].
  List<tz.TZDateTime> buildFireTimesForTest({
    required TimeOfDay time,
    required SacredLocation? location,
    required bool inIsrael,
    required DateTime? fromDay,
  }) {
    final result = <tz.TZDateTime>[];
    final now = fromDay != null
        ? tz.TZDateTime(tz.local, fromDay.year, fromDay.month, fromDay.day)
        : tz.TZDateTime.now(tz.local);

    for (var day = 0; day < kBatchDays; day++) {
      // Start from tomorrow (day=0 is tomorrow since we skip today).
      final candidate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + day + 1,
        time.hour,
        time.minute,
      );

      // Check against Sacred Time block windows if repository is available.
      // candidate is a TZDateTime — .toUtc() converts using the tz library's
      // local timezone (correctly set by NotificationInitializer).
      if (_sacredWindowRepository != null) {
        final suppressed = _sacredWindowRepository.isWindowActive(
          candidate.toUtc(),
          location: location,
          inIsrael: inIsrael,
        );

        if (suppressed) continue;
      }

      result.add(candidate);
    }

    return result;
  }
}
