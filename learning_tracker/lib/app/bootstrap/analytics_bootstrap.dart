import 'package:flutter/foundation.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/analytics/firebase_analytics_service.dart';
import 'package:learning_tracker/core/logging/logger.dart';

/// Creates the [AnalyticsService] instance shared across the app.
///
/// Release/profile builds: [FirebaseAnalyticsService] backed by Firebase.
/// Debug builds: [LoggingAnalyticsService] so no real events are fired during
/// development or tests.
AnalyticsService bootstrapAnalytics(AppLogger log) {
  if (kDebugMode) {
    return LoggingAnalyticsService(log);
  }
  return FirebaseAnalyticsService();
}
