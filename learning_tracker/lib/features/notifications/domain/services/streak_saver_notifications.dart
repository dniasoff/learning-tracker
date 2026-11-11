/// Separate 22:00 streak-saver notification with an Android countdown to midnight.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:timezone/timezone.dart' as tz;

bool shouldScheduleStreakSaver({
  required DateTime nowUtc,
  required DateTime fireAtUtc,
  required bool atRisk,
  required bool enabled,
  required bool sacredTime,
  required bool deviceLocked,
}) =>
    enabled &&
    atRisk &&
    fireAtUtc.isAfter(nowUtc) &&
    !sacredTime &&
    !deviceLocked;

int streakSaverNotificationId(String profileId) =>
    notificationBlockBaseForProfile(profileId) + 24;

class StreakSaverNotifications {
  StreakSaverNotifications({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> schedule({
    required String profileId,
    required DateTime fireAtUtc,
    required DateTime midnightUtc,
    required String title,
    required String body,
  }) => _plugin.zonedSchedule(
    id: streakSaverNotificationId(profileId),
    title: title,
    body: body,
    scheduledDate: tz.TZDateTime.from(fireAtUtc.toUtc(), tz.UTC),
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'streak_saver',
        'Streak Saver',
        channelDescription:
            'A countdown to midnight when your streak is at risk',
        importance: Importance.high,
        priority: Priority.high,
        when: midnightUtc.millisecondsSinceEpoch,
        usesChronometer: true,
        chronometerCountDown: true,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    payload: 'streak_saver:$profileId',
  );

  Future<void> cancel(String profileId) =>
      _plugin.cancel(id: streakSaverNotificationId(profileId));
}
