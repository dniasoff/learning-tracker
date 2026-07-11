import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift_flutter/drift_flutter.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/account/domain/services/pending_local_signup.dart';
import 'package:learning_tracker/features/account/domain/services/session_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolves the active account at startup and returns the DB file name to
/// be passed to [ProviderScope] as an override for [accountDbFileNameProvider].
///
/// Returns `'learning_tracker'` (the legacy single-file default) when no
/// account is found or on error so the app starts in a usable state.
///
/// [registryExecutor] is a test-only seam: production callers never pass it,
/// so [driftDatabase] is always used for the real device registry file. Unit
/// tests inject a [QueryExecutor] (e.g. an in-memory database, optionally
/// wrapped in a `QueryInterceptor`) to control/observe the registry
/// connection without touching the filesystem.
Future<String> bootstrapAccount({
  required String databasesPath,
  required AppLogger log,
  QueryExecutor? registryExecutor,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await PendingLocalSignupStore.cleanupStaleOnStartup(
      prefs: prefs,
      databasesPath: databasesPath,
    );
    final registry = DeviceRegistryDatabase(
      registryExecutor ?? driftDatabase(name: 'device_registry'),
    );
    try {
      final sessionService = SessionPersistenceService(
        prefs: prefs,
        registry: registry,
      );
      final accountId = await sessionService.resolveActiveAccountId();
      var resolvedName = 'learning_tracker';
      if (accountId != null) {
        final account = await registry.findById(accountId);
        if (account != null) {
          resolvedName = account.dbFileName;
          log.info(
            event: 'active_account_resolved',
            fields: {
              // email is in PiiRedactor.sensitiveKeys → redacted automatically
              'email': account.email,
              'tier': account.tier,
              'db': account.dbFileName,
            },
          );
        }
      } else {
        log.info(event: 'active_account_none');
      }
      return resolvedName;
    } finally {
      // Close the registry connection on every exit path — including when
      // resolveActiveAccountId()/findById() throw and control jumps straight
      // to the outer catch below. Previously registry.close() sat at the end
      // of the try block, so an exception here leaked the Drift-backed
      // device_registry connection for the app's whole lifetime.
      await registry.close();
    }
  } catch (e, stack) {
    log.error(
      event: 'active_account_resolution_failed',
      exception: e,
      stackTrace: stack,
    );
    return 'learning_tracker';
  }
}
