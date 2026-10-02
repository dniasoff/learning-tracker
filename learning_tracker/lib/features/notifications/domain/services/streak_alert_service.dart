/// The per-curriculum streak-at-risk alert (DNI-479, AD-40 surfaces).
///
/// `LearnerState` has no profile-wide streak: each evaluated curriculum
/// whose streak is at risk gets its own alert, at most once per
/// learner-local civil day per curriculum, and none inside a lock window
/// (AD-36 `lockWindows`).
library;

import 'dart:async';

import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/lock_filter.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/notifications/domain/services/curriculum_streak_alerts.dart';

/// What one curriculum's evaluation did.
enum StreakAlertOutcome {
  /// An alert is now scheduled for today.
  scheduled,

  /// Today's alert was already scheduled at this time; nothing changed.
  alreadyScheduled,

  /// No streak to protect, or it is already kept today: no alert.
  notAtRisk,

  /// Today's alert time has passed; nothing is scheduled, and an alert
  /// still pending from an earlier alert time is cancelled.
  tooLate,

  /// Now or the alert time is inside a lock window: no alert.
  lockSuppressed,
}

/// Evaluates and schedules one profile's per-curriculum streak alerts.
class StreakAlertService {
  /// Creates the service for [profileId].
  StreakAlertService({
    required StreakAlertNotifications notifications,
    required StreakAlertMarkers markers,
    required String profileId,
    DateTime Function()? clock,
    AnalyticsService? analytics,
  }) : _notifications = notifications,
       _markers = markers,
       _profileId = profileId,
       _clock = clock ?? DateTimeFactory.nowUtc,
       _analytics = analytics ?? const NullAnalyticsService();

  final StreakAlertNotifications _notifications;
  final StreakAlertMarkers _markers;
  final String _profileId;
  final DateTime Function() _clock;
  final AnalyticsService _analytics;

  /// Evaluates every curriculum of [state]: each evaluated curriculum with
  /// a streak is evaluated on its own ([evaluate]); every other curriculum
  /// in [state] has its alert cancelled.
  ///
  /// [title] and [localizedBody] are the locale-resolved copy (UX-DR7);
  /// [localizedBody] is a function of the curriculum's current streak.
  Future<Map<String, StreakAlertOutcome>> evaluateAll({
    required LearnerState state,
    required LearnerSettingsHistory settingsHistory,
    required int hour,
    required int minute,
    String? title,
    String Function(int currentStreak)? localizedBody,
  }) async {
    final outcomes = <String, StreakAlertOutcome>{};
    for (final MapEntry(key: curriculumId, value: curriculum)
        in state.curricula.entries) {
      if (!curriculum.evaluated) {
        await cancel(curriculumId);
        continue;
      }
      outcomes[curriculumId] = await evaluate(
        curriculumId: curriculumId,
        streak: curriculum.streak,
        settingsHistory: settingsHistory,
        hour: hour,
        minute: minute,
        title: title,
        localizedBody: localizedBody,
      );
    }
    return outcomes;
  }

  /// Evaluates [curriculumId]'s alert from its [streak] at the alert time
  /// [hour]:[minute] on the learner's civil day (AD-41 zone from
  /// [settingsHistory]).
  ///
  /// The streak is at risk when it is running (`current > 0`) and today is
  /// not yet a streak day. A lock window holding now or the alert time
  /// suppresses the alert; a failure computing the lock windows cancels it
  /// and is rethrown (fail closed). Re-evaluating on the same civil day at
  /// the same time schedules nothing new.
  Future<StreakAlertOutcome> evaluate({
    required String curriculumId,
    required CurriculumStreak? streak,
    required LearnerSettingsHistory settingsHistory,
    required int hour,
    required int minute,
    String? title,
    String Function(int currentStreak)? localizedBody,
  }) async {
    final now = _clock().toUtc();
    final today = civilDate(now, settingsHistory);
    if (streak == null || streak.current == 0 || streak.lastDay == today) {
      await cancel(curriculumId);
      return StreakAlertOutcome.notAtRisk;
    }

    final zone = LearnerZone.of(settingsHistory.at(now).timeZone);
    final fireAt = zone.at(parseCivilDay(today), hour: hour, minute: minute);
    if (!fireAt.isAfter(now)) {
      // An alert scheduled under an earlier config (a later alert time, or
      // an earlier day) may still be pending: the current config schedules
      // nothing, so it must not fire. One that already fired is left in
      // the tray.
      if (await _pendingAlertFromMarker(curriculumId, zone, now)) {
        await cancel(curriculumId);
      }
      return StreakAlertOutcome.tooLate;
    }

    final List<LockWindow> locks;
    try {
      locks = lockWindows(settingsHistory, now, fireAt);
    } catch (_) {
      await cancel(curriculumId);
      rethrow;
    }
    if (insideLock(locks, now) || insideLock(locks, fireAt)) {
      await cancel(curriculumId);
      return StreakAlertOutcome.lockSuppressed;
    }

    final marker = '$today@$hour:$minute';
    if (await _markers.read(_profileId, curriculumId) == marker) {
      return StreakAlertOutcome.alreadyScheduled;
    }
    await _notifications.schedule(
      profileId: _profileId,
      curriculumId: curriculumId,
      fireAtUtc: fireAt,
      title: title ?? 'Streak at Risk!',
      body: localizedBody?.call(streak.current) ?? buildBody(streak.current),
    );
    await _markers.write(_profileId, curriculumId, marker);
    // Story 27.14 (DNI-390): one event per scheduled alert.
    unawaited(
      _analytics.logNotificationFired(notificationType: 'streak_alert'),
    );
    return StreakAlertOutcome.scheduled;
  }

  /// Whether [curriculumId]'s marker records an alert whose fire time is
  /// still ahead of [now]. An unreadable marker counts as pending, so the
  /// caller cancels it (fail closed).
  Future<bool> _pendingAlertFromMarker(
    String curriculumId,
    LearnerZone zone,
    DateTime now,
  ) async {
    final marker = await _markers.read(_profileId, curriculumId);
    if (marker == null) return false;
    final match = _markerPattern.firstMatch(marker);
    if (match == null) return true;
    final firedAt = zone.at(
      parseCivilDay(match.group(1)!),
      hour: int.parse(match.group(2)!),
      minute: int.parse(match.group(3)!),
    );
    return firedAt.isAfter(now);
  }

  /// The `<civil day>@<hour>:<minute>` marker written by [evaluate].
  static final _markerPattern = RegExp(
    r'^(\d{4}-\d{2}-\d{2})@(\d{1,2}):(\d{1,2})$',
  );

  /// Cancels [curriculumId]'s alert and forgets its marker.
  Future<void> cancel(String curriculumId) async {
    await _notifications.cancel(
      profileId: _profileId,
      curriculumId: curriculumId,
    );
    await _markers.clear(_profileId, curriculumId);
  }

  /// Cancels every streak alert of the profile and forgets its markers.
  Future<void> cancelAlert() async {
    await _notifications.cancelAll(_profileId);
    await _markers.clearAll(_profileId);
  }

  /// The English fallback body.
  static String buildBody(int currentStreak) {
    return 'Your $currentStreak-day streak is at risk!';
  }
}
