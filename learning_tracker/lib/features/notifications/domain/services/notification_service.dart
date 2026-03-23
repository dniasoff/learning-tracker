import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Payload used when notification is tapped.
const String dailyReminderPayload = 'daily_reminder';

/// Notification channel for daily reminders.
const String _channelId = 'daily_reminders';
const String _channelName = 'Daily Reminders';
const String _channelDescription = 'Daily learning reminder notifications';

/// Notification ID for the daily reminder (single repeating notification).
const int dailyReminderId = 0;

/// Payload used when a streak protection notification is tapped.
const String streakAlertPayload = 'streak_protection';

/// Notification channel for streak alerts.
const String _streakChannelId = 'streak_alerts';
const String _streakChannelName = 'Streak Alerts';
const String _streakChannelDescription =
    'Alerts when your learning streak is at risk';

/// Notification ID for the streak protection alert.
const int streakAlertId = 1;

/// Payload used when a reward milestone notification is tapped.
const String rewardMilestonePayload = 'reward_earned';

/// Notification channel for reward milestones.
const String _rewardChannelId = 'reward_milestones';
const String _rewardChannelName = 'Reward Milestones';
const String _rewardChannelDescription =
    'Notifications when reward point thresholds are reached';

/// Base notification ID for reward milestones.
/// Uses incrementing IDs starting from 100 to avoid conflicts.
const int _rewardMilestoneBaseId = 100;

/// Service for scheduling and managing local notifications.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  int _rewardNotificationCounter = 0;

  /// Initialize the notification plugin.
  ///
  /// [onNotificationTap] is called when a notification is tapped.
  Future<bool> initialize({
    void Function(String? payload)? onNotificationTap,
  }) async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final result = await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap?.call(response.payload);
      },
    );
    return result ?? false;
  }

  /// Request notification permission on Android 13+.
  ///
  /// Returns true if permission was granted.
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    // iOS: request via Darwin implementation
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  /// Schedule a daily repeating notification at [time].
  ///
  /// [body] is the notification text, e.g. "You have 5 tasks across 2 curricula today".
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String body,
  }) async {
    final scheduledTime = _nextInstanceOfTime(hour, minute);

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id: dailyReminderId,
      title: 'Learning Reminder',
      body: body,
      scheduledDate: scheduledTime,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: dailyReminderPayload,
    );
  }

  /// Cancel the daily reminder notification.
  Future<void> cancelDailyReminder() async {
    await _plugin.cancel(id: dailyReminderId);
  }

  /// Schedule a daily streak protection alert at [hour]:[minute].
  ///
  /// [body] is the notification text, e.g. "Your 5-day streak is at risk!"
  Future<void> scheduleStreakAlert({
    required int hour,
    required int minute,
    required String body,
  }) async {
    final scheduledTime = _nextInstanceOfTime(hour, minute);

    const androidDetails = AndroidNotificationDetails(
      _streakChannelId,
      _streakChannelName,
      channelDescription: _streakChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id: streakAlertId,
      title: 'Streak at Risk!',
      body: body,
      scheduledDate: scheduledTime,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: streakAlertPayload,
    );
  }

  /// Cancel the streak protection alert.
  Future<void> cancelStreakAlert() async {
    await _plugin.cancel(id: streakAlertId);
  }

  /// Show an immediate notification for a reward milestone.
  ///
  /// [body] is the notification text, varying by user mode.
  Future<void> showRewardMilestone({required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      _rewardChannelId,
      _rewardChannelName,
      channelDescription: _rewardChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    final id = _rewardMilestoneBaseId + _rewardNotificationCounter;
    _rewardNotificationCounter++;

    await _plugin.show(
      id: id,
      title: 'Reward Milestone',
      body: body,
      notificationDetails: notificationDetails,
      payload: rewardMilestonePayload,
    );
  }

  /// Get the next instance of the given time (today or tomorrow).
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
