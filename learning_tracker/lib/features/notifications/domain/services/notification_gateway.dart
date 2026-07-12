import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Payload used when notification is tapped.
const String dailyReminderPayload = 'daily_reminder';

/// Notification channel for daily reminders.
const String _channelId = 'daily_reminders';
const String _channelName = 'Daily Reminders';
const String _channelDescription = 'Daily learning reminder notifications';

// ---------------------------------------------------------------------------
// Per-profile notification ID allocation (WS5.key-prefs)
//
// Each profile is allocated a block of 1000 IDs:
//   profile 0: IDs 0–999    → daily=0, streak=1, batch=10–23
//   profile 1: IDs 1000–1999 → daily=1000, streak=1001, batch=1010–1023
//   profile N: IDs N*1000 … N*1000+999
//
// This guarantees no collisions across profiles (up to 1000 profiles, well
// beyond any real-world use). The block scheme is the sole source of
// notification IDs — the old singleton constants (dailyReminderId=0,
// streakAlertId=1, batchBaseId=10) and their non-profile scheduling methods
// were removed once WS5.per-profile's *ForProfile equivalents took over
// every production call site (AUD-notifications-04).
// ---------------------------------------------------------------------------

/// Offset for the daily reminder ID within a profile's block.
const int _dailyReminderOffset = 0;

/// Offset for the streak alert ID within a profile's block.
const int _streakAlertOffset = 1;

/// Offset for the base of the batch reminder IDs within a profile's block.
const int _batchBaseOffset = 10;

/// Size of the rolling one-shot batch (14 days, IDs offset 10–23).
const int _batchSize = 14;

/// IDs per profile block (must be > _batchBaseOffset + _batchSize).
const int _idsPerProfile = 1000;

// ---------------------------------------------------------------------------
// Per-profile ID helpers — used instead of the old singleton constants.
// ---------------------------------------------------------------------------

/// Returns the notification ID for the daily reminder of [profileId].
int dailyReminderIdForProfile(int profileId) =>
    profileId * _idsPerProfile + _dailyReminderOffset;

/// Returns the notification ID for the streak alert of [profileId].
int streakAlertIdForProfile(int profileId) =>
    profileId * _idsPerProfile + _streakAlertOffset;

/// Returns the base notification ID for the batch reminders of [profileId].
int batchBaseIdForProfile(int profileId) =>
    profileId * _idsPerProfile + _batchBaseOffset;

/// Payload used when a streak protection notification is tapped.
const String streakAlertPayload = 'streak_protection';

/// Notification channel for streak alerts.
const String _streakChannelId = 'streak_alerts';
const String _streakChannelName = 'Streak Alerts';
const String _streakChannelDescription =
    'Alerts when your learning streak is at risk';

/// Payload used when a reward milestone notification is tapped.
const String rewardMilestonePayload = 'reward_earned';

/// Service for scheduling and managing local notifications.
class NotificationGateway {
  NotificationGateway({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

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

  /// Request notification permission on Android 13+ and exact-alarm permission
  /// on Android 12+.
  ///
  /// Returns true if the POST_NOTIFICATIONS permission was granted (or not
  /// required). Exact-alarm permission is best-effort — the schedule still
  /// works at ~windowed accuracy without it.
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final granted = await android.requestNotificationsPermission() ?? false;
      await android.requestExactAlarmsPermission();
      return granted;
    }
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

  /// Check whether the app currently has notification permission.
  ///
  /// Returns `true` if POST_NOTIFICATIONS is granted (Android 13+) or if
  /// no permission is required (older Android / iOS after request). On iOS
  /// this is always best-effort as there is no dedicated pending-check API
  /// in flutter_local_notifications; falls back to `true`.
  Future<bool> hasPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    // iOS: no dedicated pending check — assume granted (permission flow is
    // handled separately at onboarding/settings).
    return true;
  }

  // ---------------------------------------------------------------------------
  // Per-profile scheduling (WS5.per-profile)
  // ---------------------------------------------------------------------------

  /// Schedule a daily reminder for [profileId] with payload
  /// `daily_reminder:<profileId>` so the tap handler can switch to the
  /// correct profile.
  Future<void> scheduleDailyReminderForProfile({
    required int profileId,
    required int hour,
    required int minute,
    required String title,
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
      id: dailyReminderIdForProfile(profileId),
      title: title,
      body: body,
      scheduledDate: scheduledTime,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: '$dailyReminderPayload:$profileId',
    );
  }

  /// Cancel the daily reminder for [profileId].
  Future<void> cancelDailyReminderForProfile(int profileId) async {
    await _plugin.cancel(id: dailyReminderIdForProfile(profileId));
  }

  /// Schedule a rolling 14-day batch of reminders for [profileId].
  Future<void> scheduleBatchRemindersForProfile({
    required int profileId,
    required List<tz.TZDateTime> fireTimes,
    required String title,
    required String body,
  }) async {
    await cancelBatchRemindersForProfile(profileId);

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    final baseId = batchBaseIdForProfile(profileId);
    for (var i = 0; i < fireTimes.length && i < _batchSize; i++) {
      await _plugin.zonedSchedule(
        id: baseId + i,
        title: title,
        body: body,
        scheduledDate: fireTimes[i],
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: '$dailyReminderPayload:$profileId',
      );
    }
  }

  /// Cancel all batch reminder notifications for [profileId].
  Future<void> cancelBatchRemindersForProfile(int profileId) async {
    final baseId = batchBaseIdForProfile(profileId);
    for (var i = 0; i < _batchSize; i++) {
      await _plugin.cancel(id: baseId + i);
    }
  }

  /// Schedule a daily streak protection alert for [profileId] at
  /// [hour]:[minute].
  ///
  /// Uses the per-profile streak-alert ID block (`profileId*1000 + 1`) and a
  /// `streak_protection:<profileId>` payload so the tap handler can switch to
  /// the correct profile. Mirrors [scheduleDailyReminderForProfile].
  Future<void> scheduleStreakAlertForProfile({
    required int profileId,
    required int hour,
    required int minute,
    required String body,
    String title = 'Streak at Risk!',
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
      id: streakAlertIdForProfile(profileId),
      title: title,
      body: body,
      scheduledDate: scheduledTime,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: '$streakAlertPayload:$profileId',
    );
  }

  /// Cancel the streak protection alert for [profileId].
  Future<void> cancelStreakAlertForProfile(int profileId) async {
    await _plugin.cancel(id: streakAlertIdForProfile(profileId));
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
