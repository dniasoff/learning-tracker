import 'dart:async';

import 'package:flutter/material.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:timezone/timezone.dart' as tz;

/// Number of days in the rolling one-shot batch (DNI-367, Story 26.24).
const int kBatchDays = 14;

/// Orchestrates scheduling/cancelling the daily reminder notification.
///
/// DNI-367 (Story 26.24): scheduleReminderForProfile() replaces the old repeating
/// schedule with a rolling 14-day batch of pre-filtered one-shots. Each
/// fire-time is checked against [isLockedAt] and suppressed if it falls
/// inside a Sacred Time lock.
///
/// DNI-481 (AD-36): [isLockedAt] is the device lock predicate — the SAME
/// union of `lockWindows` over the account's learners that drives the lock
/// overlay (`deviceLockPredicateProvider`), fail-closed for a learner whose
/// settings cannot be read. There is no fail-open "no location" branch.
///
/// Pure logic — no Riverpod dependency. Providers call these methods.
class NotificationScheduler {
  NotificationScheduler({
    required this.service,
    this.isLockedAt,
    AnalyticsService? analytics,
  }) : _analytics = analytics ?? const NullAnalyticsService();

  final NotificationGateway service;

  /// Whether a UTC instant is inside a Sacred Time lock; null schedules
  /// without lock filtering (tests that do not exercise the lock).
  final bool Function(DateTime utc)? isLockedAt;
  final AnalyticsService _analytics;

  /// Schedule (or reschedule) the daily reminder as a rolling 14-day batch of
  /// pre-filtered one-shot notifications.
  ///
  /// [title] and [body] should be locale-resolved at call time (UX-DR7).
  ///
  /// Each of the next 14 days is checked: if the fire-time for that day falls
  /// inside a Sacred Time lock ([isLockedAt]), it is silently suppressed.
  ///
  /// Fires [AnalyticsEvent.notificationFired] after scheduling succeeds
  /// (Story 27.14, DNI-390).
  Future<void> scheduleReminder({
    required TimeOfDay time,
    required String title,
    required String body,
  }) async {
    final fireTimes = buildFireTimesForTest(time: time, fromDay: null);

    // (AUD-notifications-04) Routed through a fixed placeholder block of the
    // *ForProfile gateway API — the non-profile scheduleBatchReminders /
    // cancelBatchReminders / cancelDailyReminder methods this used to call
    // were deleted as dead code (WS5.per-profile's *ForProfile equivalents
    // are the sole production call sites; see scheduleReminderForProfile
    // below).
    await service.scheduleBatchRemindersForProfile(
      profileId: 'legacy',
      fireTimes: fireTimes,
      title: title,
      body: body,
    );

    unawaited(
      _analytics.logNotificationFired(notificationType: 'daily_reminder'),
    );
  }

  /// Schedule (or reschedule) the daily reminder for [profileId] as a rolling
  /// 14-day batch of pre-filtered one-shots, using that profile's per-profile
  /// batch ID block (`profileId*1000 + 10..23`).
  ///
  /// (H1 fix) This is the single canonical daily-reminder scheme for ALL
  /// profiles — active and inactive alike — so no profile ever ends up with
  /// two competing schedules in different ID spaces. Each fire-time is filtered
  /// against the Sacred Time lock exactly like [scheduleReminder] (L2 fix).
  Future<void> scheduleReminderForProfile({
    required String profileId,
    required TimeOfDay time,
    required String title,
    required String body,
  }) async {
    final fireTimes = buildFireTimesForTest(time: time, fromDay: null);

    await service.scheduleBatchRemindersForProfile(
      profileId: profileId,
      fireTimes: fireTimes,
      title: title,
      body: body,
    );

    unawaited(
      _analytics.logNotificationFired(notificationType: 'daily_reminder'),
    );
  }

  /// Cancel the daily reminder for [profileId] (per-profile batch + legacy
  /// single-shot id within the profile's block).
  Future<void> cancelForProfile(String profileId) async {
    await service.cancelDailyReminderForProfile(profileId);
    await service.cancelBatchRemindersForProfile(profileId);
  }

  /// Cancel due to sacred time for [profileId] — fire suppression event.
  Future<void> cancelForProfileSacredTime(String profileId) async {
    await service.cancelDailyReminderForProfile(profileId);
    await service.cancelBatchRemindersForProfile(profileId);
    unawaited(
      _analytics.logNotificationSuppressedSacredTime(
        notificationType: 'daily_reminder',
      ),
    );
  }

  /// Visible-for-testing: builds and returns the filtered list of
  /// [tz.TZDateTime] fire-times for the next [kBatchDays] days.
  ///
  /// [fromDay] overrides "today" for deterministic test scenarios. When null,
  /// uses [tz.TZDateTime.now(tz.local)].
  List<tz.TZDateTime> buildFireTimesForTest({
    required TimeOfDay time,
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

      // Check against the Sacred Time lock (bounds inclusive). candidate is
      // a TZDateTime — .toUtc() converts using the tz library's local
      // timezone (correctly set by NotificationInitializer); the lock
      // itself is computed in each learner's own IANA zone (AD-41).
      if (isLockedAt?.call(candidate.toUtc()) ?? false) continue;

      result.add(candidate);
    }

    return result;
  }
}
