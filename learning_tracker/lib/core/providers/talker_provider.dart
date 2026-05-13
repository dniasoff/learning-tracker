import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Provides the application-wide [Talker] singleton instance.
///
/// Most call sites should depend on [appLoggerProvider] instead. This provider
/// is retained only for third-party integrations that require the raw [Talker]
/// type (e.g. `TalkerDioLogger`).
///
/// In tests, override via:
/// ```dart
/// final container = ProviderContainer(overrides: [
///   talkerProvider.overrideWithValue(MockTalker()),
/// ]);
/// ```
final talkerProvider = Provider<Talker>((ref) {
  return AppLogger.instance;
});

/// Provides the application-wide [AppLogger] singleton.
///
/// Prefer this over [talkerProvider] in application code so the structured,
/// PII-redacting named-parameter API (`info(event:, fields:)`) is used.
///
/// In tests, inject a fake by overriding:
/// ```dart
/// ProviderContainer(overrides: [
///   appLoggerProvider.overrideWithValue(AppLogger(Talker())),
/// ]);
/// ```
final appLoggerProvider = Provider<AppLogger>((ref) {
  return AppLogger(ref.watch(talkerProvider));
});
