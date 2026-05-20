// core/providers/crashlytics_provider.dart — W7.16
//
// Riverpod provider for [CrashlyticsService].
//
// main.dart overrides this with the fully-wired [AnalyticsWrappedCrashlyticsService]
// created during bootstrap so all code inside the Riverpod tree sees the same
// instance that FlutterError.onError / PlatformDispatcher.onError use.
//
// Code outside Riverpod (e.g. the runZonedGuarded error handler) uses the
// module-level `_crashlytics` variable in main.dart directly.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/crashlytics_service.dart';

/// Provides the single [CrashlyticsService] instance for the whole app.
///
/// Defaults to [NullCrashlyticsService]; main.dart overrides this in the
/// [ProviderContainer] after bootstrap so the real Firebase-backed service is
/// used in production.
final crashlyticsServiceProvider = Provider<CrashlyticsService>(
  (_) => const NullCrashlyticsService(),
);
