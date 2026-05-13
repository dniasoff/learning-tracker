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

  Future<void> logCompletionRecorded({
    required String sefariaRef,
    required String trackType,
  }) => logEvent(
    AnalyticsEvent.completionRecorded,
    parameters: {'sefaria_ref': sefariaRef, 'track_type': trackType},
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

  Future<void> logPinLockedOut({required int profileId}) => logEvent(
    AnalyticsEvent.pinLockedOut,
    parameters: {'profile_id': profileId},
  );

  Future<void> logParentModeEntered({required int profileId}) => logEvent(
    AnalyticsEvent.parentModeEntered,
    parameters: {'profile_id': profileId},
  );

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
