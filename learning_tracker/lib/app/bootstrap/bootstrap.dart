import 'dart:async';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/bootstrap/account_bootstrap.dart';
import 'package:learning_tracker/app/bootstrap/analytics_bootstrap.dart';
import 'package:learning_tracker/app/bootstrap/crashlytics_bootstrap.dart';
import 'package:learning_tracker/app/bootstrap/firebase_bootstrap.dart';
import 'package:learning_tracker/app/bootstrap/notifications_bootstrap.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/logging/crashlytics_service.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/crashlytics_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger.dart';

/// Result of the bootstrap sequence.
typedef BootstrapResult = ({
  ProviderContainer container,
  CrashlyticsService crashlytics,
});

/// Seeds the restored account only when the live default-app Firebase session
/// matches that account's persisted registry [firebaseUid].
///
/// The device registry is local persistence and can outlive Firebase Auth
/// (for example after sign-out, reinstall, or an auth-session reset). Seeding
/// an id in that state, or for a different account, poisons
/// [activeAccountFirebaseProvider] with an [AccountNotAuthenticatedException]
/// before the user has a chance to sign in again. A successful sign-in
/// establishes the account session and calls [ActiveAccountId.set] through
/// its normal flow instead.
void seedRestoredActiveAccount({
  required ProviderContainer container,
  required String? accountId,
  required String? authenticatedUserId,
  required String? restoredFirebaseUid,
}) {
  if (accountId == null ||
      authenticatedUserId == null ||
      restoredFirebaseUid == null ||
      authenticatedUserId != restoredFirebaseUid) {
    return;
  }
  container.read(activeAccountIdProvider.notifier).set(accountId);
}

Future<String?> _readRestoredFirebaseUid(String accountId) async {
  final registry = DeviceRegistryDatabase(
    driftDatabase(name: 'device_registry'),
  );
  try {
    return (await registry.findById(accountId))?.firebaseUid;
  } finally {
    await registry.close();
  }
}

/// Orchestrates the full app bootstrap sequence.
///
/// Initialises Firebase, logging, analytics, Crashlytics, account resolution,
/// and the Riverpod [ProviderContainer]. Seed-DB extraction is deferred to
/// [contentDatabaseProvider] so [runApp] fires after ~1-2 s (Firebase +
/// account only). Wires the resolved profile listener for Crashlytics. Runs
/// the notification bootstrap as a side-effect against the built container.
///
/// Returns a [BootstrapResult] whose [container] is ready for
/// [UncontrolledProviderScope] and whose [crashlytics] is suitable for the
/// zone error handler (W7.14).
Future<BootstrapResult> bootstrap() async {
  // AUD-app-06: initialise the logger BEFORE Firebase so the AppLogger.init()
  // call below doesn't discard Talker history that bootstrapFirebase()'s own
  // (non-fatal) catch blocks may already have logged via AppLogger.instance
  // — AppLogger.init() replaces the singleton Talker wholesale, so logging
  // through the lazy pre-init instance and then re-initialising would wipe
  // that very entry from the ring buffer before "Send Diagnostic Logs" (or
  // any other consumer) ever sees it.
  final talker = AppLogger.init();
  final log = AppLogger(talker);
  var crashlytics = await bootstrapFirebase();
  final analytics = bootstrapAnalytics(log);
  crashlytics = bootstrapCrashlyticsHandlers(
    crashlytics: crashlytics,
    analytics: analytics,
  );

  log.info(event: 'app_starting_local_first');

  // Seed extraction (SeedManager.ensureContentDb) runs lazily inside
  // contentDbPathProvider / contentDatabaseProvider — no await here.
  // runApp is called after only Firebase + account init (~1-2 s), and
  // content-DB-dependent screens show their loading state until seeding
  // completes.
  final docsDir = await getApplicationDocumentsDirectory();
  final accountBootstrap = await bootstrapAccount(
    databasesPath: docsDir.path,
    log: log,
  );

  unawaited(analytics.logAppLaunch());

  final container = ProviderContainer(
    overrides: [
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

  // Seed the resolved Firestore account id into its provider.
  // bootstrapAccount completed before runApp so this is effectively
  // synchronous from the provider tree's perspective.
  if (accountBootstrap.accountId != null) {
    final bootstrapUser = container.read(authRepositoryProvider).currentUser;
    String? restoredFirebaseUid;
    if (bootstrapUser != null) {
      try {
        restoredFirebaseUid = await _readRestoredFirebaseUid(
          accountBootstrap.accountId!,
        );
      } on Exception catch (error, stackTrace) {
        log.warning(
          event: 'active_account_session_match_failed',
          exception: error,
          stackTrace: stackTrace,
        );
      }
    }
    seedRestoredActiveAccount(
      container: container,
      accountId: accountBootstrap.accountId,
      authenticatedUserId: bootstrapUser?.uid,
      restoredFirebaseUid: restoredFirebaseUid,
    );
  }

  container.listen<String?>(selectedProfileIdProvider, (_, id) {
    crashlytics.setUserIdentifier(id);
  }, fireImmediately: true);

  await bootstrapNotifications(container: container, log: log);

  return (container: container, crashlytics: crashlytics);
}
