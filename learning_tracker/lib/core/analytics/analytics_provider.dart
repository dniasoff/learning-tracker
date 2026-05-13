/// Riverpod provider for [AnalyticsService].
///
/// Defaults to [LoggingAnalyticsService] backed by [AppLogger].
/// Tests override via [ProviderContainer] or [ProviderScope] overrides with
/// a [FakeAnalyticsService] instance.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/talker_provider.dart';

/// Provides the single [AnalyticsService] instance for the whole app.
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final talker = ref.watch(talkerProvider);
  return LoggingAnalyticsService(AppLogger(talker));
});
