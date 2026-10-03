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
//   block 1: IDs 1000–1999 → daily=1000, streak=1001, batch=1010–1023
//   block N: IDs N*1000 … N*1000+999
//
// AD-24: profile identity is a ULID string, not a small sequential Drift int,
// so the block number can no longer be the profileId itself — it is now
// `1 + (stableProfileHash(profileId) % _maxBlocks)`. [stableProfileHash] is
// a hand-rolled FNV-1a, deliberately NOT `String.hashCode` — Dart does not
// guarantee `hashCode` is stable across Dart/Flutter versions or platforms,
// and a scheduled notification's ID must be re-derivable identically on a
// LATER app run purely to cancel it (there is no persisted ULID→ID map to
// consult — see the class doc comment above `NotificationGateway` for why
// a stateless hash was chosen over a persisted registry). Block 0 is
// reserved/unused (never produced by `1 + hash % _maxBlocks`) purely so a
// hash of 0 doesn't collide with any future singleton/global notification.
// `_maxBlocks` keeps every ID within Android's 32-bit signed range even at
// the largest offset: 2,000,000 * 1000 + 999 = 2,000,000,999 < 2^31-1.
//
// This does NOT guarantee zero collisions the way the old sequential-int
// scheme did — two profiles could theoretically hash to the same block —
// but the collision probability across the handful of profiles a real
// family device has is negligible, and a collision only means one profile's
// reminder silently overwrites another's until the family reports it, not a
// crash or data-safety issue.
// ---------------------------------------------------------------------------

/// Offset for the daily reminder ID within a profile's block.
const int _dailyReminderOffset = 0;

/// Offset for the streak alert ID within a profile's block.
const int _streakAlertOffset = 1;

/// Offset for the base of the batch reminder IDs within a profile's block.
const int _batchBaseOffset = 10;

/// Size of the rolling one-shot batch (14 days, IDs offset 10–23).
const int _batchSize = 14;

/// Offset for the base of the streak-alert batch IDs within a profile's
/// block (DNI-481 AC-5: 14 lock-filtered one-shots, IDs offset 30–43).
const int _streakBatchBaseOffset = 30;

/// Offset for the base of the catch-up reminder IDs within a profile's
/// block (Story 3.5, DNI-508: one-shots at a lock's end, offsets 50–69;
/// clear of the daily 0, streak 1, batches 10–23 and 30–43, and the
/// per-curriculum streak alerts from 100).
const int _catchUpBaseOffset = 50;

/// Catch-up reminder slots per profile (offsets 50–69).
const int catchUpReminderIdSlots = 20;

/// IDs per profile block (must be > _streakBatchBaseOffset + _batchSize).
const int _idsPerProfile = 1000;

/// Number of possible non-zero blocks a profile can hash into.
const int _maxBlocks = 2000000;

/// Deterministic, cross-version-stable 32-bit hash of [profileId] (FNV-1a).
///
/// Exposed (not private) so tests can assert a pinned known-ULID → known-ID
/// canary — if this algorithm ever changes, every notification already
/// scheduled on a user's device becomes uncancellable (the whole reason it
/// is hand-rolled instead of `String.hashCode`, see the block comment
/// above), so a silent behavioural change here must fail a test.
int stableProfileHash(String profileId) {
  var hash = 0x811c9dc5;
  for (final codeUnit in profileId.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// Returns the deterministic notification-id block number for [profileId].
/// Never 0 (see the block comment above).
int _blockForProfile(String profileId) =>
    1 + (stableProfileHash(profileId) % _maxBlocks);

// ---------------------------------------------------------------------------
// Per-profile ID helpers — used instead of the old singleton constants.
// ---------------------------------------------------------------------------

/// The first notification ID of [profileId]'s block; every per-profile ID
/// is this plus a fixed offset (the per-curriculum streak alerts use
/// offsets 100 and up, DNI-479).
int notificationBlockBaseForProfile(String profileId) =>
    _blockForProfile(profileId) * _idsPerProfile;

/// Returns the notification ID for the daily reminder of [profileId].
int dailyReminderIdForProfile(String profileId) =>
    _blockForProfile(profileId) * _idsPerProfile + _dailyReminderOffset;

/// Returns the notification ID for the streak alert of [profileId].
int streakAlertIdForProfile(String profileId) =>
    _blockForProfile(profileId) * _idsPerProfile + _streakAlertOffset;

/// Returns the base notification ID for the batch reminders of [profileId].
int batchBaseIdForProfile(String profileId) =>
    _blockForProfile(profileId) * _idsPerProfile + _batchBaseOffset;

/// Returns the base notification ID for the streak-alert batch of
/// [profileId] (offsets 30–43 of its block).
int streakAlertBatchBaseIdForProfile(String profileId) =>
    _blockForProfile(profileId) * _idsPerProfile + _streakBatchBaseOffset;

/// The notification ID of [profileId]'s catch-up reminder [slot]
/// (`0 <= slot < catchUpReminderIdSlots`; offsets 50–69 of its block).
int catchUpReminderIdForProfile(String profileId, int slot) {
  RangeError.checkValueInInterval(slot, 0, catchUpReminderIdSlots - 1, 'slot');
  return _blockForProfile(profileId) * _idsPerProfile +
      _catchUpBaseOffset +
      slot;
}

/// The next [days] daily fire-times at [hour]:[minute] from [now] — the
/// first one today when still ahead of [now], else tomorrow — minus every
/// one inside a Sacred Time lock ([isLockedAt], judged on the UTC instant;
/// bounds inclusive). DNI-481 AC-5: a recurring notification is scheduled
/// as these one-shots, so no occurrence fires inside a future lock even
/// while the app stays closed.
List<tz.TZDateTime> lockFilteredDailyFireTimes({
  required tz.TZDateTime now,
  required int hour,
  required int minute,
  int days = _batchSize,
  bool Function(DateTime utc)? isLockedAt,
}) {
  final first = tz.TZDateTime(
    now.location,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );
  final startDay = first.isBefore(now) ? 1 : 0;
  final result = <tz.TZDateTime>[];
  for (var day = startDay; day < startDay + days; day++) {
    final candidate = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day + day,
      hour,
      minute,
    );
    if (isLockedAt?.call(candidate.toUtc()) ?? false) continue;
    result.add(candidate);
  }
  return result;
}

/// Payload used when a streak protection notification is tapped.
const String streakAlertPayload = 'streak_protection';

/// Notification channel for streak alerts.
const String _streakChannelId = 'streak_alerts';
const String _streakChannelName = 'Streak Alerts';
const String _streakChannelDescription =
    'Alerts when your learning streak is at risk';

/// Payload prefix of a catch-up reminder (Story 3.5, DNI-508): the full
/// payload is `catch_up_reminder:<profileId>` — the profile routing id
/// only, never a lock, card or learning detail (AC-9).
const String catchUpReminderPayload = 'catch_up_reminder';

/// Notification channel for catch-up reminders.
const String _catchUpChannelId = 'catch_up_reminders';
const String _catchUpChannelName = 'Catch-up reminders';
const String _catchUpChannelDescription =
    'One reminder when a catch-up card is ready after Shabbos or Yom Tov';

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
    required String profileId,
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
  Future<void> cancelDailyReminderForProfile(String profileId) async {
    await _plugin.cancel(id: dailyReminderIdForProfile(profileId));
  }

  /// Schedule a rolling 14-day batch of reminders for [profileId].
  ///
  /// Any earlier schedule is cancelled first: the batch (offsets 10–23) AND
  /// the legacy REPEATING daily reminder (offset 0, scheduled by
  /// [scheduleDailyReminderForProfile] on builds before DNI-367). A repeating
  /// reminder is never lock-filtered, so one left behind on an upgraded
  /// device would keep firing inside every Sacred Time lock (DNI-481 AC-5).
  Future<void> scheduleBatchRemindersForProfile({
    required String profileId,
    required List<tz.TZDateTime> fireTimes,
    required String title,
    required String body,
  }) async {
    await cancelDailyReminderForProfile(profileId);
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
  Future<void> cancelBatchRemindersForProfile(String profileId) async {
    final baseId = batchBaseIdForProfile(profileId);
    for (var i = 0; i < _batchSize; i++) {
      await _plugin.cancel(id: baseId + i);
    }
  }

  /// Schedule the streak protection alert for [profileId] at
  /// [hour]:[minute] as a rolling batch of one-shots: the next [_batchSize]
  /// daily occurrences (the first today when still ahead), minus every one
  /// that falls inside a Sacred Time lock ([isLockedAt]; DNI-481 AC-5 — the
  /// same predicate as the lock overlay). A repeating alert would fire
  /// inside a future lock while the app stays closed; these never do.
  ///
  /// Uses the per-profile streak-alert batch ID block
  /// (`block*1000 + 30..43`) and a `streak_protection:<profileId>` payload
  /// so the tap handler can switch to the correct profile. Any earlier
  /// schedule (batch or the legacy repeating id) is cancelled first.
  Future<void> scheduleStreakAlertForProfile({
    required String profileId,
    required int hour,
    required int minute,
    required String body,
    String title = 'Streak at Risk!',
    bool Function(DateTime utc)? isLockedAt,
  }) async {
    await cancelStreakAlertForProfile(profileId);
    final fireTimes = lockFilteredDailyFireTimes(
      now: tz.TZDateTime.now(tz.local),
      hour: hour,
      minute: minute,
      isLockedAt: isLockedAt,
    );

    const androidDetails = AndroidNotificationDetails(
      _streakChannelId,
      _streakChannelName,
      channelDescription: _streakChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    final baseId = streakAlertBatchBaseIdForProfile(profileId);
    for (var i = 0; i < fireTimes.length && i < _batchSize; i++) {
      await _plugin.zonedSchedule(
        id: baseId + i,
        title: title,
        body: body,
        scheduledDate: fireTimes[i],
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: '$streakAlertPayload:$profileId',
      );
    }
  }

  /// Cancel the streak protection alert for [profileId]: its one-shot
  /// batch and the legacy repeating alert id (`block*1000 + 1`).
  Future<void> cancelStreakAlertForProfile(String profileId) async {
    await _plugin.cancel(id: streakAlertIdForProfile(profileId));
    final baseId = streakAlertBatchBaseIdForProfile(profileId);
    for (var i = 0; i < _batchSize; i++) {
      await _plugin.cancel(id: baseId + i);
    }
  }

  // ---------------------------------------------------------------------------
  // Catch-up reminders (Story 3.5, DNI-508)
  // ---------------------------------------------------------------------------

  /// Schedules one catch-up reminder [id] (from
  /// [catchUpReminderIdForProfile]) for [profileId] at [fireAtUtc] (a
  /// lock's end), replacing any pending one with that id.
  ///
  /// A one-shot: never repeating, never snoozed. It is inexact (allowed
  /// while idle), so it needs no exact-alarm permission and is never shown
  /// before [fireAtUtc]. It never requests a permission (AC-8).
  Future<void> scheduleCatchUpReminder({
    required int id,
    required String profileId,
    required DateTime fireAtUtc,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _catchUpChannelId,
      _catchUpChannelName,
      channelDescription: _catchUpChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(fireAtUtc.toUtc(), tz.UTC),
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '$catchUpReminderPayload:$profileId',
    );
  }

  /// Cancels the catch-up reminder [id].
  Future<void> cancelCatchUpReminder(int id) => _plugin.cancel(id: id);

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
