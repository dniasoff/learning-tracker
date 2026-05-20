import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/logging/logger.dart';

/// Creates the [AnalyticsService] instance shared across the app.
///
/// Currently backed by [LoggingAnalyticsService]; will be upgraded to a
/// real Firebase Analytics backend in W7.13.
AnalyticsService bootstrapAnalytics(AppLogger log) {
  return LoggingAnalyticsService(log);
}
