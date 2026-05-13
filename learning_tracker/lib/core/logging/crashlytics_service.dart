import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';

/// Thin wrapper around [FirebaseCrashlytics] that can be substituted in tests.
///
/// All Crashlytics interactions go through this class so that unit tests can
/// inject a [NullCrashlyticsService] without touching the real Firebase SDK.
///
/// Story 27.14 (DNI-390): [recordError] fires [AnalyticsEvent.crashReported]
/// via the injected [AnalyticsService]. Inject [NullAnalyticsService] in
/// tests or when analytics is not yet wired.
abstract class CrashlyticsService {
  /// Enables or disables Crashlytics collection.
  Future<void> setCrashlyticsCollectionEnabled(bool enabled);

  /// Records a Flutter framework error as a fatal crash.
  Future<void> recordFlutterFatalError(FlutterErrorDetails details);

  /// Records an uncaught Dart/Platform error as a fatal crash.
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  });

  /// Sets the numeric user identifier (profileId).
  ///
  /// Pass [null] to clear the identifier (user signed out).
  Future<void> setUserIdentifier(int? profileId);
}

/// Production implementation backed by [FirebaseCrashlytics].
class FirebaseCrashlyticsService implements CrashlyticsService {
  FirebaseCrashlyticsService(this._crashlytics, {AnalyticsService? analytics})
    : _analytics = analytics ?? const NullAnalyticsService();

  final FirebaseCrashlytics _crashlytics;
  final AnalyticsService _analytics;

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) =>
      _crashlytics.setCrashlyticsCollectionEnabled(enabled);

  @override
  Future<void> recordFlutterFatalError(FlutterErrorDetails details) =>
      _crashlytics.recordFlutterFatalError(details);

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) {
    // Story 27.14 (DNI-390): fire crash_reported event alongside Crashlytics.
    unawaited(_analytics.logCrashReported(fatal: fatal));
    return _crashlytics.recordError(error, stack, fatal: fatal);
  }

  @override
  Future<void> setUserIdentifier(int? profileId) =>
      _crashlytics.setUserIdentifier(profileId == null ? '' : '$profileId');
}

/// No-op implementation used when Crashlytics is unavailable (tests, CI).
class NullCrashlyticsService implements CrashlyticsService {
  const NullCrashlyticsService();

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {}

  @override
  Future<void> recordFlutterFatalError(FlutterErrorDetails details) async {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) async {}

  @override
  Future<void> setUserIdentifier(int? profileId) async {}
}

/// Crashlytics service backed by a [NullAnalyticsService] analytics instance.
///
/// Used in production before analytics is wired or in test environments.
/// Replace [_analytics] with a real [AnalyticsService] once firebase_analytics
/// is added to pubspec.
class AnalyticsWrappedCrashlyticsService extends FirebaseCrashlyticsService {
  AnalyticsWrappedCrashlyticsService(
    super.crashlytics, {
    required AnalyticsService analytics,
  }) : super(analytics: analytics);
}
