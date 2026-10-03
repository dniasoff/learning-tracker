/// Per-curriculum streak-at-risk notifications (DNI-479, AD-40: "the
/// streak-at-risk alert fires per evaluated curriculum whose streak is at
/// risk, at most once per civil day per curriculum").
///
/// Each (profile, curriculum) has ONE notification identity. An alert is
/// a one-shot notification for one learner-local civil day — never a
/// daily-repeating schedule — so a day can never carry two alerts for the
/// same curriculum, and a day the app is not opened carries none (the
/// streak it would warn about is unknown without an evaluation).
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:timezone/timezone.dart' as tz;

/// The offset of the first per-curriculum streak alert in a profile's
/// notification-id block (the daily reminder is 0, the retired profile-wide
/// streak alert 1, the batch reminders 10–23).
const int _curriculumStreakAlertBase = 100;

/// Fixed slots per curriculum storage key. Append only: a scheduled
/// alert's id must be re-derivable on a later run to cancel it.
const Map<String, int> _curriculumSlots = {
  'chumash': 0,
  'nach': 1,
  'tanach': 2,
  'mishnayos': 3,
  'bavli': 4,
  'yerushalmi': 5,
  'mishneh_torah': 6,
  'mishna_berurah': 7,
  'mussar': 8,
};

/// The notification id of [profileId]'s streak alert for [curriculumId].
///
/// A key outside the fixed slot table hashes into block offsets 200–999,
/// clear of the fixed ones.
int streakAlertIdForCurriculum(String profileId, String curriculumId) {
  final slot =
      _curriculumSlots[curriculumId] ??
      100 + stableProfileHash(curriculumId) % 800;
  return notificationBlockBaseForProfile(profileId) +
      _curriculumStreakAlertBase +
      slot;
}

/// Schedules and cancels the per-curriculum streak alerts.
abstract interface class StreakAlertNotifications {
  /// Schedules [profileId]'s one-shot alert for [curriculumId] at
  /// [fireAtUtc], replacing any pending one for that curriculum.
  Future<void> schedule({
    required String profileId,
    required String curriculumId,
    required DateTime fireAtUtc,
    required String title,
    required String body,
  });

  /// Cancels [profileId]'s pending alert for [curriculumId].
  Future<void> cancel({
    required String profileId,
    required String curriculumId,
  });

  /// Cancels every streak alert of [profileId]: each curriculum's and the
  /// retired daily-repeating profile-wide one.
  Future<void> cancelAll(String profileId);
}

/// [StreakAlertNotifications] on `flutter_local_notifications`.
class LocalStreakAlertNotifications implements StreakAlertNotifications {
  /// Creates the notifier; [plugin] defaults to the shared plugin.
  LocalStreakAlertNotifications({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'streak_alerts',
      'Streak Alerts',
      channelDescription: 'Alerts when your learning streak is at risk',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  @override
  Future<void> schedule({
    required String profileId,
    required String curriculumId,
    required DateTime fireAtUtc,
    required String title,
    required String body,
  }) => _plugin.zonedSchedule(
    id: streakAlertIdForCurriculum(profileId, curriculumId),
    title: title,
    body: body,
    scheduledDate: tz.TZDateTime.from(fireAtUtc.toUtc(), tz.UTC),
    notificationDetails: _details,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    payload: '$streakAlertPayload:$profileId',
  );

  @override
  Future<void> cancel({
    required String profileId,
    required String curriculumId,
  }) => _plugin.cancel(id: streakAlertIdForCurriculum(profileId, curriculumId));

  @override
  Future<void> cancelAll(String profileId) async {
    await _plugin.cancel(id: streakAlertIdForProfile(profileId));
    for (final curriculumId in _curriculumSlots.keys) {
      await cancel(profileId: profileId, curriculumId: curriculumId);
    }
  }
}

/// The per-(profile, curriculum) evaluation marker: which learner-local
/// civil date and alert time an alert was last scheduled for. Device-local
/// (no Firestore persistence, story assumption).
abstract interface class StreakAlertMarkers {
  /// The marker of [profileId]'s alert for [curriculumId], if any.
  Future<String?> read(String profileId, String curriculumId);

  /// Records [marker] for [profileId]'s alert for [curriculumId].
  Future<void> write(String profileId, String curriculumId, String marker);

  /// Forgets [profileId]'s marker for [curriculumId].
  Future<void> clear(String profileId, String curriculumId);

  /// Forgets every marker of [profileId].
  Future<void> clearAll(String profileId);
}
