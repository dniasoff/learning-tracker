import 'package:flutter/material.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_scheduler.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';
import 'package:learning_tracker/features/notifications/domain/services/streak_alert_service.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'notification_providers.g.dart';

/// SharedPreferences keys for reminder settings.
const String _reminderEnabledKey = 'daily_reminder_enabled';
const String _reminderHourKey = 'daily_reminder_hour';
const String _reminderMinuteKey = 'daily_reminder_minute';

/// SharedPreferences keys for streak alert settings.
const String _streakAlertEnabledKey = 'streak_alert_enabled';
const String _streakAlertHourKey = 'streak_alert_hour';
const String _streakAlertMinuteKey = 'streak_alert_minute';

/// Default reminder time: 7:00 PM.
const int defaultReminderHour = 19;
const int defaultReminderMinute = 0;

/// Default streak alert time: 9:00 PM.
const int defaultStreakAlertHour = 21;
const int defaultStreakAlertMinute = 0;

/// Provides the [NotificationService] singleton.
@riverpod
NotificationService notificationService(Ref ref) {
  return NotificationService();
}

/// Manages the daily reminder enabled state.
@riverpod
class ReminderEnabled extends _$ReminderEnabled {
  @override
  bool build() {
    _loadFromPrefs();
    return true; // default enabled
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    state = prefs.getBool(_reminderEnabledKey) ?? true;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reminderEnabledKey, state);
  }
}

/// Manages the daily reminder time.
@riverpod
class ReminderTime extends _$ReminderTime {
  @override
  TimeOfDay build() {
    _loadFromPrefs();
    return const TimeOfDay(
      hour: defaultReminderHour,
      minute: defaultReminderMinute,
    );
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final hour = prefs.getInt(_reminderHourKey) ?? defaultReminderHour;
    final minute = prefs.getInt(_reminderMinuteKey) ?? defaultReminderMinute;
    state = TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> setTime(TimeOfDay time) async {
    state = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderHourKey, time.hour);
    await prefs.setInt(_reminderMinuteKey, time.minute);
  }
}

/// Manages the streak alert enabled state.
@riverpod
class StreakAlertEnabled extends _$StreakAlertEnabled {
  @override
  bool build() {
    _loadFromPrefs();
    return true; // default enabled
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    state = prefs.getBool(_streakAlertEnabledKey) ?? true;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_streakAlertEnabledKey, state);
  }
}

/// Manages the streak alert time.
@riverpod
class StreakAlertTime extends _$StreakAlertTime {
  @override
  TimeOfDay build() {
    _loadFromPrefs();
    return const TimeOfDay(
      hour: defaultStreakAlertHour,
      minute: defaultStreakAlertMinute,
    );
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final hour = prefs.getInt(_streakAlertHourKey) ?? defaultStreakAlertHour;
    final minute =
        prefs.getInt(_streakAlertMinuteKey) ?? defaultStreakAlertMinute;
    state = TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> setTime(TimeOfDay time) async {
    state = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_streakAlertHourKey, time.hour);
    await prefs.setInt(_streakAlertMinuteKey, time.minute);
  }
}

/// Provides the [NotificationScheduler] instance.
@riverpod
NotificationScheduler notificationScheduler(Ref ref) {
  final service = ref.watch(notificationServiceProvider);
  return NotificationScheduler(service: service);
}

/// Watches reminder settings and daily tasks, then schedules or cancels
/// the notification accordingly.
///
/// Read this provider once (e.g. from the notifications screen or app startup)
/// to activate the watcher. It returns a [Future] that completes after the
/// initial schedule/cancel call.
@riverpod
Future<void> reminderSyncEffect(Ref ref) async {
  final enabled = ref.watch(reminderEnabledProvider);
  final time = ref.watch(reminderTimeProvider);
  final scheduler = ref.watch(notificationSchedulerProvider);

  if (!enabled) {
    await scheduler.cancel();
    return;
  }

  // Get daily tasks to determine counts for notification body.
  final tasks = await ref.watch(allDailyTasksProvider.future);
  final taskCount = tasks.length;
  final curriculumCount = tasks.map((t) => t.curriculumId).toSet().length;

  await scheduler.schedule(
    time: time,
    taskCount: taskCount,
    curriculumCount: curriculumCount,
  );
}

/// Provides the [StreakAlertService] instance.
@riverpod
StreakAlertService streakAlertService(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final notifService = ref.watch(notificationServiceProvider);
  return StreakAlertService(
    db: db,
    notificationService: notifService,
  );
}

/// Watches streak alert settings and evaluates whether to schedule or cancel
/// the streak protection alert.
///
/// Mirrors [reminderSyncEffect] — read this provider at app startup to
/// activate the watcher.
@riverpod
Future<void> streakAlertSyncEffect(Ref ref) async {
  final enabled = ref.watch(streakAlertEnabledProvider);
  final time = ref.watch(streakAlertTimeProvider);
  final service = ref.watch(streakAlertServiceProvider);

  if (!enabled) {
    await service.cancelAlert();
    return;
  }

  await service.evaluate(hour: time.hour, minute: time.minute);
}
