import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:talker/talker.dart';

/// Provides the application-wide [Talker] singleton instance.
///
/// This provider wraps the [AppLogger] singleton so that it can be overridden
/// in tests:
/// ```dart
/// final container = ProviderContainer(overrides: [
///   talkerProvider.overrideWithValue(MockTalker()),
/// ]);
/// ```
///
/// Use this provider to access the logger from any Riverpod-aware context:
/// ```dart
/// final talker = ref.read(talkerProvider);
/// talker.info('User performed action');
/// ```
final talkerProvider = Provider<Talker>((ref) {
  return AppLogger.instance;
});
