import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/bootstrap/account_bootstrap.dart';
import 'package:learning_tracker/app/bootstrap/analytics_bootstrap.dart';
import 'package:learning_tracker/app/bootstrap/crashlytics_bootstrap.dart';
import 'package:learning_tracker/app/bootstrap/firebase_bootstrap.dart';
import 'package:learning_tracker/app/bootstrap/notifications_bootstrap.dart';
import 'package:learning_tracker/app/bootstrap/seed_bootstrap.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/logging/crashlytics_service.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/crashlytics_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger.dart';

/// Result of the bootstrap sequence.
typedef BootstrapResult = ({
  ProviderContainer container,
  CrashlyticsService crashlytics,
});

/// Orchestrates the full app bootstrap sequence.
///
/// Initialises Firebase, logging, analytics, Crashlytics, the seed DB,
/// account resolution, and the Riverpod [ProviderContainer]. Wires the
/// resolved profile listener for Crashlytics. Runs the notification
/// bootstrap as a side-effect against the built container.
///
/// Returns a [BootstrapResult] whose [container] is ready for
/// [UncontrolledProviderScope] and whose [crashlytics] is suitable for the
/// zone error handler (W7.14).
Future<BootstrapResult> bootstrap() async {
  var crashlytics = await bootstrapFirebase();
  final talker = AppLogger.init();
  final log = AppLogger(talker);
  final analytics = bootstrapAnalytics(log);
  crashlytics = bootstrapCrashlyticsHandlers(
    crashlytics: crashlytics,
    analytics: analytics,
  );

  log.info(event: 'app_starting_local_first');

  final docsDir = await getApplicationDocumentsDirectory();
  final contentDbPath = await bootstrapSeedDb(
    dbDirectory: docsDir.path,
    log: log,
  );
  final resolvedDbFileName = await bootstrapAccount(
    databasesPath: docsDir.path,
    log: log,
  );

  unawaited(analytics.logAppLaunch());

  final container = ProviderContainer(
    overrides: [
      contentDbPathProvider.overrideWithValue(contentDbPath),
      analyticsServiceProvider.overrideWithValue(analytics),
      // W7.16: expose the bootstrapped Crashlytics service through the
      // provider tree so sync subsystems can record non-fatal errors.
      crashlyticsServiceProvider.overrideWithValue(crashlytics),
    ],
    // RP3: disable Riverpod 3's default provider auto-retry app-wide. With retry
    // on, a persistently-failing FutureProvider stays in AsyncLoading(error:) so
    // `asyncValue.when(error:)` never fires and screens show a spinner forever.
    // Surfacing AsyncError immediately restores the error+retry UI (the explicit
    // Retry button is the recovery path); matches the codegen providers, which
    // already emit `retry: null`.
    retry: (_, __) => null,
    observers: [
      TalkerRiverpodObserver(
        talker: talker,
        settings: const TalkerRiverpodLoggerSettings(
          printProviderDisposed: true,
        ),
      ),
    ],
  );

  // Seed the resolved account DB file name into the provider.
  // bootstrapAccount completed before runApp so this is effectively
  // synchronous from the provider tree's perspective.
  if (resolvedDbFileName != 'learning_tracker') {
    container
        .read(accountDbFileNameProvider.notifier)
        .setFileName(resolvedDbFileName);
  }

  container.listen<int?>(selectedProfileIdProvider, (_, id) {
    crashlytics.setUserIdentifier(id);
  }, fireImmediately: true);

  await bootstrapNotifications(container: container, log: log);

  return (container: container, crashlytics: crashlytics);
}
