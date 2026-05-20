/// Riverpod provider for [AnalyticsService].
///
/// In debug builds, falls back to [LoggingAnalyticsService] backed by
/// [AppLogger] so test runs and debug sessions don't fire real events.
///
/// In release/profile builds, uses [FirebaseAnalyticsService] backed by
/// [FirebaseAnalytics.instance].
///
/// Tests override via [ProviderContainer] or [ProviderScope] overrides with
/// a [FakeAnalyticsService] instance.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/analytics/firebase_analytics_service.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/talker_provider.dart';

/// Provides the single [AnalyticsService] instance for the whole app.
///
/// Release/profile: [FirebaseAnalyticsService] (real Firebase Analytics).
/// Debug: [LoggingAnalyticsService] (structured log fallback — no real events).
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  if (kDebugMode) {
    final talker = ref.watch(talkerProvider);
    return LoggingAnalyticsService(AppLogger(talker));
  }
  return FirebaseAnalyticsService();
});
