import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/logging/crashlytics_service.dart';
import 'package:learning_tracker/core/logging/logger.dart';

/// Wires Flutter / Dart error handlers to [crashlytics] and returns a version
/// upgraded with [analytics] support.
///
/// Call after both [bootstrapFirebase] and [bootstrapLogger] complete.
CrashlyticsService bootstrapCrashlyticsHandlers({
  required CrashlyticsService crashlytics,
  required AnalyticsService analytics,
}) {
  // Upgrade to analytics-wrapped service if Firebase is available.
  final upgraded = crashlytics is FirebaseCrashlyticsService
      ? AnalyticsWrappedCrashlyticsService(
          FirebaseCrashlytics.instance,
          analytics: analytics,
        )
      : crashlytics;

  // Story 24.4: Override Flutter and Dart error hooks to report to
  // Crashlytics as the primary handler. Talker remains a secondary
  // handler for in-app diagnostics.
  FlutterError.onError = (FlutterErrorDetails details) {
    upgraded.recordFlutterFatalError(details);
    AppLogger.instance.handle(details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    upgraded.recordError(error, stack, fatal: true);
    AppLogger.instance.handle(error, stack);
    return true;
  };

  return upgraded;
}
