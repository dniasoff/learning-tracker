import 'package:flutter/material.dart';

/// Immutable snapshot of all notification preference settings for one profile.
///
/// Aggregates daily reminder, streak alert, and reward notification flags + times
/// into a single value object so preferences are read and written atomically
/// rather than via scattered SharedPreferences key-by-key calls.
class ReminderPreferences {
  const ReminderPreferences({
    required this.reminderEnabled,
    required this.reminderHour,
    required this.reminderMinute,
    required this.streakAlertEnabled,
    required this.streakAlertHour,
    required this.streakAlertMinute,
    required this.rewardNotificationEnabled,
  });

  /// Default reminder time: 7:00 PM.
  static const int defaultReminderHour = 19;
  static const int defaultReminderMinute = 0;

  /// Default streak alert time: 9:00 PM.
  static const int defaultStreakAlertHour = 21;
  static const int defaultStreakAlertMinute = 0;

  /// Factory: applies all defaults (used when no preferences have been stored).
  const ReminderPreferences.defaults()
    : reminderEnabled = true,
      reminderHour = defaultReminderHour,
      reminderMinute = defaultReminderMinute,
      streakAlertEnabled = true,
      streakAlertHour = defaultStreakAlertHour,
      streakAlertMinute = defaultStreakAlertMinute,
      rewardNotificationEnabled = true;

  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;

  final bool streakAlertEnabled;
  final int streakAlertHour;
  final int streakAlertMinute;

  final bool rewardNotificationEnabled;

  /// Convenience getter: daily reminder as a [TimeOfDay].
  TimeOfDay get reminderTime =>
      TimeOfDay(hour: reminderHour, minute: reminderMinute);

  /// Convenience getter: streak alert as a [TimeOfDay].
  TimeOfDay get streakAlertTime =>
      TimeOfDay(hour: streakAlertHour, minute: streakAlertMinute);

  ReminderPreferences copyWith({
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    bool? streakAlertEnabled,
    int? streakAlertHour,
    int? streakAlertMinute,
    bool? rewardNotificationEnabled,
  }) => ReminderPreferences(
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderHour: reminderHour ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
    streakAlertEnabled: streakAlertEnabled ?? this.streakAlertEnabled,
    streakAlertHour: streakAlertHour ?? this.streakAlertHour,
    streakAlertMinute: streakAlertMinute ?? this.streakAlertMinute,
    rewardNotificationEnabled:
        rewardNotificationEnabled ?? this.rewardNotificationEnabled,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderPreferences &&
          runtimeType == other.runtimeType &&
          reminderEnabled == other.reminderEnabled &&
          reminderHour == other.reminderHour &&
          reminderMinute == other.reminderMinute &&
          streakAlertEnabled == other.streakAlertEnabled &&
          streakAlertHour == other.streakAlertHour &&
          streakAlertMinute == other.streakAlertMinute &&
          rewardNotificationEnabled == other.rewardNotificationEnabled;

  @override
  int get hashCode => Object.hash(
    reminderEnabled,
    reminderHour,
    reminderMinute,
    streakAlertEnabled,
    streakAlertHour,
    streakAlertMinute,
    rewardNotificationEnabled,
  );
}
