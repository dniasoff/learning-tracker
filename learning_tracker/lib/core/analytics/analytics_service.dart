/// Analytics service abstraction for the Learning Tracker.
///
/// All Firebase Analytics calls are confined to this layer (Story 27.14,
/// DNI-390). Production code fires named events through [AnalyticsService].
/// Tests inject [FakeAnalyticsService] to assert events without touching any
/// real Firebase SDK.
///
/// Firebase Analytics can be wired in [LoggingAnalyticsService] once
/// `firebase_analytics` is added to the pubspec (not yet included — no new
/// pub dependencies for this story). Until then the service logs via
/// [AppLogger] so the structured-log trail is preserved.
library;

import 'package:learning_tracker/core/logging/logger.dart';

/// Named analytics event constants (Story 27.14, DNI-390).
///
/// AUD-core-analytics-01: this catalog is the ONLY source of event names
/// accepted by [AnalyticsService.logEvent] — every `.logEvent(` call site in
/// `lib/` must pass an `AnalyticsEvent.*` member as the event name (checked
/// by `dart run tool/check_analytics_catalog.dart`, wired into `make audit`).
/// [LogEvents] (core/logging/log_events.dart) remains a separate catalog for
/// [AppLogger] structured logs and MUST NOT be passed to `logEvent` directly.
abstract final class AnalyticsEvent {
  static const appLaunch = 'app_launch';
  static const completionRecorded = 'completion_recorded';
  static const bulkMarkPriorUsed = 'bulk_mark_prior_used';
  static const trackAdded = 'track_added';
  static const streakMilestoneReached = 'streak_milestone_reached';
  static const syncFailed = 'sync_failed';
  static const pinLockedOut = 'pin_locked_out';
  static const parentModeEntered = 'parent_mode_entered';
  static const notificationFired = 'notification_fired';
  static const notificationSuppressedSacredTime =
      'notification_suppressed_sacred_time';
  static const cloudRestoreCompleted = 'cloud_restore_completed';
  static const crashReported = 'crash_reported';

  // W7.5–W7.11 events — promoted into the catalog by AUD-core-analytics-01.
  // These were previously fired via bare `LogEvents.*` strings, bypassing
  // this catalog and its PV-1 review entirely.
  static const syncMergeRowSkipped = 'sync_merge_row_skipped';
  static const syncMergeRouterHalt = 'sync_merge_router_halt';
  static const syncOutboxDeadLettered = 'sync_outbox_dead_lettered';
  static const syncPullStarted = 'sync_pull_started';
  static const syncPullCompleted = 'sync_pull_completed';
  static const syncPullFailed = 'sync_pull_failed';
  static const syncListenerError = 'sync_listener_error';
  static const syncPermissionDenied = 'sync_permission_denied';
  static const tutorPinSet = 'tutor_pin_set';
  static const tutorActionRecorded = 'tutor_action_recorded';
  static const tutorInviteSent = 'tutor_invite_sent';
  static const tutorInviteAccepted = 'tutor_invite_accepted';
  static const tutorInviteDeclined = 'tutor_invite_declined';
  static const tutorGrantRescinded = 'tutor_grant_rescinded';
  static const tutorGrantRevoked = 'tutor_grant_revoked';
  static const tutorResigned = 'tutor_resigned';
  static const tutorLiveMarkBlocked = 'tutor_live_mark_blocked';
  static const bulkEngagementSkipped = 'bulk_engagement_skipped';
  static const lifetimeAchievementSkipped = 'lifetime_achievement_skipped';
}

/// Milestone thresholds for [AnalyticsEvent.streakMilestoneReached].
const kStreakMilestones = <int>[7, 30, 100];

/// Sole public surface for firing analytics events.
///
/// Firebase Analytics calls MUST only be in [core/analytics/] — see
/// `docs/coding-standards.md` and Story 27.14 (DNI-390).
abstract class AnalyticsService {
  const AnalyticsService();

  /// Log a named event with optional parameters.
  Future<void> logEvent(String name, {Map<String, Object?>? parameters});

  /// Convenience helpers for the 12 Story 27.14 events.

  Future<void> logAppLaunch() => logEvent(AnalyticsEvent.appLaunch);

  /// PV-1: parameters are a coarse, low-cardinality category
  /// (`curriculum_id` + `track_type`) — NEVER the specific `sefaria_ref` a
  /// child studied. "Which religious text a specific child studied" is
  /// sensitive per-child content history (docs/coding-standards.md PV-1);
  /// this event may only signal THAT a completion happened, in which
  /// curriculum, never the precise ref within it.
  Future<void> logCompletionRecorded({
    required String curriculumId,
    required String trackType,
  }) => logEvent(
    AnalyticsEvent.completionRecorded,
    parameters: {'curriculum_id': curriculumId, 'track_type': trackType},
  );

  Future<void> logBulkMarkPriorUsed({
    required int itemCount,
    required int completionCount,
  }) => logEvent(
    AnalyticsEvent.bulkMarkPriorUsed,
    parameters: {'item_count': itemCount, 'completion_count': completionCount},
  );

  Future<void> logTrackAdded({required String curriculumId}) => logEvent(
    AnalyticsEvent.trackAdded,
    parameters: {'curriculum_id': curriculumId},
  );

  Future<void> logStreakMilestoneReached({required int milestone}) => logEvent(
    AnalyticsEvent.streakMilestoneReached,
    parameters: {'milestone': milestone},
  );

  Future<void> logSyncFailed({required String reason}) =>
      logEvent(AnalyticsEvent.syncFailed, parameters: {'reason': reason});

  /// PV-1: no per-child identifier — this event signals only THAT a lockout
  /// occurred, never WHICH profile (docs/coding-standards.md PV-1).
  Future<void> logPinLockedOut() => logEvent(AnalyticsEvent.pinLockedOut);

  /// PV-1: no per-child identifier — this event signals only THAT parent
  /// mode was entered, never WHICH profile (docs/coding-standards.md PV-1).
  Future<void> logParentModeEntered() =>
      logEvent(AnalyticsEvent.parentModeEntered);

  Future<void> logNotificationFired({required String notificationType}) =>
      logEvent(
        AnalyticsEvent.notificationFired,
        parameters: {'notification_type': notificationType},
      );

  Future<void> logNotificationSuppressedSacredTime({
    required String notificationType,
  }) => logEvent(
    AnalyticsEvent.notificationSuppressedSacredTime,
    parameters: {'notification_type': notificationType},
  );

  Future<void> logCloudRestoreCompleted({required int stepsRestored}) =>
      logEvent(
        AnalyticsEvent.cloudRestoreCompleted,
        parameters: {'steps_restored': stepsRestored},
      );

  Future<void> logCrashReported({required bool fatal}) =>
      logEvent(AnalyticsEvent.crashReported, parameters: {'fatal': fatal});
}

/// No-op implementation used in tests and when analytics is unavailable.
class NullAnalyticsService extends AnalyticsService {
  const NullAnalyticsService();

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?>? parameters,
  }) async {}
}

/// Production implementation that logs events via [AppLogger] structured
/// logging. Swap out for a `firebase_analytics`-backed impl once the
/// package is added to pubspec.
class LoggingAnalyticsService extends AnalyticsService {
  LoggingAnalyticsService(this._logger);

  final AppLogger _logger;

  @override
  Future<void> logEvent(String name, {Map<String, Object?>? parameters}) async {
    _logger.info(
      event: 'analytics_event',
      fields: <String, Object?>{
        'event_name': name,
        if (parameters != null) ...parameters,
      },
    );
  }
}

/// Test double that records every event fired.
///
/// Use in acceptance/unit tests to assert events fire exactly once per trigger.
class FakeAnalyticsService extends AnalyticsService {
  final List<_FiredEvent> _events = [];

  List<_FiredEvent> get events => List.unmodifiable(_events);

  /// Returns all event names fired, in order.
  List<String> get eventNames => _events.map((e) => e.name).toList();

  /// Returns the number of times [name] was fired.
  int countOf(String name) => _events.where((e) => e.name == name).length;

  /// Returns parameters of the last [name] event, or null if none fired.
  Map<String, Object?>? lastParamsOf(String name) =>
      _events.lastWhereOrNull((e) => e.name == name)?.parameters;

  void clear() => _events.clear();

  @override
  Future<void> logEvent(String name, {Map<String, Object?>? parameters}) async {
    _events.add(_FiredEvent(name: name, parameters: parameters ?? {}));
  }
}

class _FiredEvent {
  const _FiredEvent({required this.name, required this.parameters});

  final String name;
  final Map<String, Object?> parameters;
}

extension _ListExt<T> on List<T> {
  T? lastWhereOrNull(bool Function(T) test) {
    for (var i = length - 1; i >= 0; i--) {
      if (test(this[i])) return this[i];
    }
    return null;
  }
}
