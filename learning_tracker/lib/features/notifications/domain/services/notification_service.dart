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

/// Service for scheduling and managing local notifications.
class NotificationService {
  NotificationService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

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
    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final result = await _plugin.initialize(
      settings,
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
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    // iOS: request via Darwin implementation
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
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
      dailyReminderId,
      'Learning Reminder',
      body,
      scheduledTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: dailyReminderPayload,
    );
  }

  /// Cancel the daily reminder notification.
  Future<void> cancelDailyReminder() async {
    await _plugin.cancel(dailyReminderId);
  }

  /// Get the next instance of the given time (today or tomorrow).
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
