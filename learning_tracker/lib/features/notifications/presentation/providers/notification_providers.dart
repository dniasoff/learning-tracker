import 'package:flutter/material.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_scheduler.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';
import 'package:learning_tracker/features/notifications/domain/services/shabbos_time_service.dart';
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

/// SharedPreferences keys for reward notification settings.
const String _rewardNotificationEnabledKey = 'reward_notification_enabled';

/// SharedPreferences keys for Shabbos mode settings.
const String _shabbosModeEnabledKey = 'shabbos_mode_enabled';
const String _shabbosModeUseLocationKey = 'shabbos_mode_use_location';
const String _shabbosModeLatitudeKey = 'shabbos_mode_latitude';
const String _shabbosModeLongitudeKey = 'shabbos_mode_longitude';
const String _shabbosModeFixedStartHourKey = 'shabbos_mode_fixed_start_hour';
const String _shabbosModeFixedStartMinuteKey =
    'shabbos_mode_fixed_start_minute';
const String _shabbosModeFixedEndHourKey = 'shabbos_mode_fixed_end_hour';
const String _shabbosModeFixedEndMinuteKey = 'shabbos_mode_fixed_end_minute';

/// Default reminder time: 7:00 PM.
const int defaultReminderHour = 19;
const int defaultReminderMinute = 0;

/// Default streak alert time: 9:00 PM.
const int defaultStreakAlertHour = 21;
const int defaultStreakAlertMinute = 0;

/// Default fixed Shabbos times: Friday 18:00 – Saturday 20:00.
const int defaultShabbosStartHour = 18;
const int defaultShabbosStartMinute = 0;
const int defaultShabbosEndHour = 20;
const int defaultShabbosEndMinute = 0;

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

/// Manages the reward notification enabled state.
@riverpod
class RewardNotificationEnabled extends _$RewardNotificationEnabled {
  @override
  bool build() {
    _loadFromPrefs();
    return true; // default enabled
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    state = prefs.getBool(_rewardNotificationEnabledKey) ?? true;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rewardNotificationEnabledKey, state);
  }
}

/// Manages the Shabbos mode enabled state.
@riverpod
class ShabbosModeEnabled extends _$ShabbosModeEnabled {
  @override
  bool build() {
    _loadFromPrefs();
    return false; // default disabled
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    state = prefs.getBool(_shabbosModeEnabledKey) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shabbosModeEnabledKey, state);
  }
}

/// Manages whether Shabbos mode uses location-based or fixed times.
@riverpod
class ShabbosModeUseLocation extends _$ShabbosModeUseLocation {
  @override
  bool build() {
    _loadFromPrefs();
    return false; // default: fixed times
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    state = prefs.getBool(_shabbosModeUseLocationKey) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shabbosModeUseLocationKey, state);
  }
}

/// Manages the stored latitude for location-based Shabbos mode.
@riverpod
class ShabbosModeLatitude extends _$ShabbosModeLatitude {
  @override
  double build() {
    _loadFromPrefs();
    return 0.0;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    state = prefs.getDouble(_shabbosModeLatitudeKey) ?? 0.0;
  }

  Future<void> setValue(double value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_shabbosModeLatitudeKey, value);
  }
}

/// Manages the stored longitude for location-based Shabbos mode.
@riverpod
class ShabbosModeLongitude extends _$ShabbosModeLongitude {
  @override
  double build() {
    _loadFromPrefs();
    return 0.0;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    state = prefs.getDouble(_shabbosModeLongitudeKey) ?? 0.0;
  }

  Future<void> setValue(double value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_shabbosModeLongitudeKey, value);
  }
}

/// Manages fixed Shabbos start time (candle lighting).
@riverpod
class ShabbosModeFixedStartTime extends _$ShabbosModeFixedStartTime {
  @override
  TimeOfDay build() {
    _loadFromPrefs();
    return const TimeOfDay(
      hour: defaultShabbosStartHour,
      minute: defaultShabbosStartMinute,
    );
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final hour =
        prefs.getInt(_shabbosModeFixedStartHourKey) ?? defaultShabbosStartHour;
    final minute =
        prefs.getInt(_shabbosModeFixedStartMinuteKey) ??
        defaultShabbosStartMinute;
    state = TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> setTime(TimeOfDay time) async {
    state = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_shabbosModeFixedStartHourKey, time.hour);
    await prefs.setInt(_shabbosModeFixedStartMinuteKey, time.minute);
  }
}

/// Manages fixed Shabbos end time (havdalah).
@riverpod
class ShabbosModeFixedEndTime extends _$ShabbosModeFixedEndTime {
  @override
  TimeOfDay build() {
    _loadFromPrefs();
    return const TimeOfDay(
      hour: defaultShabbosEndHour,
      minute: defaultShabbosEndMinute,
    );
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final hour =
        prefs.getInt(_shabbosModeFixedEndHourKey) ?? defaultShabbosEndHour;
    final minute =
        prefs.getInt(_shabbosModeFixedEndMinuteKey) ?? defaultShabbosEndMinute;
    state = TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> setTime(TimeOfDay time) async {
    state = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_shabbosModeFixedEndHourKey, time.hour);
    await prefs.setInt(_shabbosModeFixedEndMinuteKey, time.minute);
  }
}

/// Provides the [ShabbosTimeService] singleton.
@riverpod
ShabbosTimeService shabbosTimeService(Ref ref) {
  return const ShabbosTimeService();
}

/// Returns true if notifications should currently be suppressed due to
/// Shabbos/Yom Tov quiet mode.
@riverpod
bool isShabbosQuietActive(Ref ref) {
  final enabled = ref.watch(shabbosModeEnabledProvider);
  if (!enabled) return false;

  final useLocation = ref.watch(shabbosModeUseLocationProvider);
  final service = ref.watch(shabbosTimeServiceProvider);
  final now = DateTime.now();

  if (useLocation) {
    final lat = ref.watch(shabbosModeLatitudeProvider);
    final lon = ref.watch(shabbosModeLongitudeProvider);
    if (lat == 0.0 && lon == 0.0) return false; // no location set
    return service.isDuringShabbosWithLocation(
      dateTime: now,
      latitude: lat,
      longitude: lon,
    );
  } else {
    final startTime = ref.watch(shabbosModeFixedStartTimeProvider);
    final endTime = ref.watch(shabbosModeFixedEndTimeProvider);
    return service.isDuringShabbosWithFixedTimes(
      dateTime: now,
      startHour: startTime.hour,
      startMinute: startTime.minute,
      endHour: endTime.hour,
      endMinute: endTime.minute,
    );
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
/// Also respects Shabbos quiet mode — cancels notifications during Shabbos.
@riverpod
Future<void> reminderSyncEffect(Ref ref) async {
  final enabled = ref.watch(reminderEnabledProvider);
  final time = ref.watch(reminderTimeProvider);
  final scheduler = ref.watch(notificationSchedulerProvider);
  final shabbosQuiet = ref.watch(isShabbosQuietActiveProvider);

  if (!enabled || shabbosQuiet) {
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
  return StreakAlertService(db: db, notificationService: notifService);
}

/// Watches streak alert settings and evaluates whether to schedule or cancel
/// the streak protection alert.
///
/// Also respects Shabbos quiet mode — cancels alerts during Shabbos.
@riverpod
Future<void> streakAlertSyncEffect(Ref ref) async {
  final enabled = ref.watch(streakAlertEnabledProvider);
  final time = ref.watch(streakAlertTimeProvider);
  final service = ref.watch(streakAlertServiceProvider);
  final shabbosQuiet = ref.watch(isShabbosQuietActiveProvider);

  if (!enabled || shabbosQuiet) {
    await service.cancelAlert();
    return;
  }

  await service.evaluate(hour: time.hour, minute: time.minute);
}
