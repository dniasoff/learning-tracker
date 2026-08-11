import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift_flutter/drift_flutter.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/account/domain/services/session_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of [bootstrapAccount] — carries the same "which account is
/// active" fact into both of the app's account-scoped providers:
/// [dbFileName] seeds [accountDbFileNameProvider] (Drift file selection),
/// [accountId] seeds `activeAccountIdProvider`
/// (`lib/data/firestore/active_account_providers.dart`, Firestore
/// repository resolution). They are resolved together, from the same
/// device-registry row, so callers never have a DB file swapped in without
/// the matching Firestore account id (or vice versa).
///
/// [accountId] is `null` exactly when [dbFileName] is the
/// `'learning_tracker'` legacy default: either no account was ever marked
/// active on this device, the marked account id no longer has a matching
/// device-registry row, or resolution errored — see [bootstrapAccount]'s doc
/// comment.
typedef BootstrapAccountResult = ({String dbFileName, String? accountId});

/// Resolves the active account at startup and returns the DB file name +
/// account id to be seeded into [accountDbFileNameProvider] and
/// `activeAccountIdProvider` respectively (see [BootstrapAccountResult]).
///
/// Returns `(dbFileName: 'learning_tracker', accountId: null)` (the legacy
/// single-file default, no active account) when no account is found or on
/// error so the app starts in a usable state.
///
/// [registryExecutor] is a test-only seam: production callers never pass it,
/// so [driftDatabase] is always used for the real device registry file. Unit
/// tests inject a [QueryExecutor] (e.g. an in-memory database, optionally
/// wrapped in a `QueryInterceptor`) to control/observe the registry
/// connection without touching the filesystem.
Future<BootstrapAccountResult> bootstrapAccount({
  required String databasesPath,
  required AppLogger log,
  QueryExecutor? registryExecutor,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
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
      String? resolvedAccountId;
      if (accountId != null) {
        final account = await registry.findById(accountId);
        if (account != null) {
          resolvedName = account.dbFileName;
          resolvedAccountId = accountId;
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
      return (dbFileName: resolvedName, accountId: resolvedAccountId);
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
    return (dbFileName: 'learning_tracker', accountId: null);
  }
}
