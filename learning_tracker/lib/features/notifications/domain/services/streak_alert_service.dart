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
import 'package:learning_tracker/domain/learner_state/catch_up_card_projection.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/lock_filter.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/notifications/domain/services/curriculum_streak_alerts.dart';
import 'package:learning_tracker/features/notifications/domain/services/today_learning_done.dart';

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

  /// The streak's only gap is locked days whose catch-up card is still
  /// pending at the alert time: no alert, so the child gets the one
  /// catch-up reminder and no streak pressure (DNI-508 AC-10, NFR-18).
  catchUpPending,
}

/// Whether [curriculumId]'s [streak] is at risk only because of locked
/// days whose catch-up is still pending at [atUtc] (DNI-508 AC-10): every
/// civil day after the streak's last day and before [today] is a locked
/// day of a catch-up card pending at [atUtc] ([catchUpCardWindowsAt],
/// AD-40) that this curriculum has not caught up ([catchUpRecorded]), and
/// there is at least one such day (or [today] is one, on the night the
/// lock ends). A gap with any other day — or no gap at all — is not
/// covered, so other curricula and other gaps follow the independent
/// alert rule.
bool catchUpCoversStreakGap({
  required String curriculumId,
  required CurriculumStreak streak,
  required CivilDate today,
  required LearnerSettingsHistory settingsHistory,
  required LearnerState state,
  required DateTime atUtc,
}) {
  final last = streak.lastDay;
  if (last == null) return false;
  final end = parseCivilDay(today);
  final gap = <CivilDate>[
    for (
      var d = addCivilDays(parseCivilDay(last), 1);
      d.isBefore(end);
      d = addCivilDays(d, 1)
    )
      formatCivilDay(d),
  ];
  final pending = <CivilDate>{
    for (final card in catchUpCardWindowsAt(settingsHistory, atUtc))
      if (!catchUpRecorded(card, curriculumId, state)) ...card.allLockedDays,
  };
  // Motzei Shabbos: today is itself the pending locked day.
  if (gap.isEmpty && !pending.contains(today)) return false;
  return gap.every(pending.contains);
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
    bool Function(DateTime utc)? isLockedAt,
  }) : _notifications = notifications,
       _markers = markers,
       _profileId = profileId,
       _clock = clock ?? DateTimeFactory.nowUtc,
       _isLockedAt = isLockedAt,
       _analytics = analytics ?? const NullAnalyticsService();

  final StreakAlertNotifications _notifications;
  final StreakAlertMarkers _markers;
  final String _profileId;
  final DateTime Function() _clock;
  final bool Function(DateTime utc)? _isLockedAt;
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
    final today = civilDate(_clock().toUtc(), settingsHistory);
    for (final MapEntry(key: curriculumId, value: curriculum)
        in state.curricula.entries) {
      if (!curriculum.evaluated) {
        await cancel(curriculumId);
        continue;
      }
      outcomes[curriculumId] = await evaluate(
        curriculumId: curriculumId,
        streak: curriculum.streak,
        state: state,
        settingsHistory: settingsHistory,
        hour: hour,
        minute: minute,
        title: title,
        localizedBody: localizedBody,
        // DNI-482 AC-5: today's learning is read from LearnerState only.
        doneToday: learnedToday(
          state,
          settingsHistory,
          day: today,
          curriculumId: curriculumId,
        ),
      );
    }
    return outcomes;
  }

  /// Evaluates [curriculumId]'s alert from its [streak] at the alert time
  /// [hour]:[minute] on the learner's civil day (AD-41 zone from
  /// [settingsHistory]).
  ///
  /// The streak is at risk when it is running (`current > 0`), today is
  /// not yet a streak day and today's learning is not done ([doneToday]:
  /// a counted learning event of the curriculum on today's civil date,
  /// from `LearnerState`, DNI-482). A lock window holding now or the alert time
  /// suppresses the alert; a failure computing the lock windows cancels it
  /// and is rethrown (fail closed). Re-evaluating on the same civil day at
  /// the same time schedules nothing new. With [state], a streak whose
  /// only gap is a pending catch-up is not alerted ([catchUpCoversStreakGap],
  /// DNI-508 AC-10).
  Future<StreakAlertOutcome> evaluate({
    required String curriculumId,
    required CurriculumStreak? streak,
    LearnerState? state,
    required LearnerSettingsHistory settingsHistory,
    required int hour,
    required int minute,
    String? title,
    String Function(int currentStreak)? localizedBody,
    bool doneToday = false,
  }) async {
    final now = _clock().toUtc();
    final today = civilDate(now, settingsHistory);
    if (streak == null ||
        streak.current == 0 ||
        streak.lastDay == today ||
        doneToday) {
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
    if (insideLock(locks, now) ||
        insideLock(locks, fireAt) ||
        (_isLockedAt?.call(fireAt) ?? false)) {
      await cancel(curriculumId);
      return StreakAlertOutcome.lockSuppressed;
    }

    if (state != null &&
        catchUpCoversStreakGap(
          curriculumId: curriculumId,
          streak: streak,
          today: today,
          settingsHistory: settingsHistory,
          state: state,
          atUtc: fireAt,
        )) {
      await cancel(curriculumId);
      return StreakAlertOutcome.catchUpPending;
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
