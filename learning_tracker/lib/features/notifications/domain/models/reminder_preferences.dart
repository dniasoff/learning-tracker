import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'reminder_preferences.freezed.dart';

/// Immutable snapshot of all notification preference settings for one profile.
///
/// Aggregates daily reminder, streak alert, and reward notification flags + times
/// into a single value object so preferences are read and written atomically
/// rather than via scattered SharedPreferences key-by-key calls.
@freezed
abstract class ReminderPreferences with _$ReminderPreferences {
  // Private const constructor required for the custom reminderTime /
  // streakAlertTime getters and the defaults() factory below.
  const ReminderPreferences._();

  const factory ReminderPreferences({
    required bool reminderEnabled,
    required int reminderHour,
    required int reminderMinute,
    required bool streakAlertEnabled,
    required int streakAlertHour,
    required int streakAlertMinute,
    required bool rewardNotificationEnabled,
  }) = _ReminderPreferences;

  /// Factory: applies all defaults (used when no preferences have been stored).
  factory ReminderPreferences.defaults() => const ReminderPreferences(
    reminderEnabled: true,
    reminderHour: defaultReminderHour,
    reminderMinute: defaultReminderMinute,
    streakAlertEnabled: true,
    streakAlertHour: defaultStreakAlertHour,
    streakAlertMinute: defaultStreakAlertMinute,
    rewardNotificationEnabled: true,
  );

  /// Default reminder time: 7:00 PM.
  static const int defaultReminderHour = 19;
  static const int defaultReminderMinute = 0;

  /// Default streak alert time: 9:00 PM.
  static const int defaultStreakAlertHour = 21;
  static const int defaultStreakAlertMinute = 0;

  /// Convenience getter: daily reminder as a [TimeOfDay].
  TimeOfDay get reminderTime =>
      TimeOfDay(hour: reminderHour, minute: reminderMinute);

  /// Convenience getter: streak alert as a [TimeOfDay].
  TimeOfDay get streakAlertTime =>
      TimeOfDay(hour: streakAlertHour, minute: streakAlertMinute);
}
