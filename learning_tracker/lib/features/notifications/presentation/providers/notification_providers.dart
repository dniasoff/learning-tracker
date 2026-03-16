import 'package:flutter/material.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'notification_providers.g.dart';

/// SharedPreferences keys for reminder settings.
const String _reminderEnabledKey = 'daily_reminder_enabled';
const String _reminderHourKey = 'daily_reminder_hour';
const String _reminderMinuteKey = 'daily_reminder_minute';

/// Default reminder time: 7:00 PM.
const int defaultReminderHour = 19;
const int defaultReminderMinute = 0;

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
