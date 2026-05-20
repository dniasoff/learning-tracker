import 'package:drift_flutter/drift_flutter.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/account/domain/services/pending_local_signup.dart';
import 'package:learning_tracker/features/account/domain/services/session_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolves the active account and sets [activeDbFileName] before the
/// provider tree is built.
///
/// Epic 21: [userDatabaseProvider] reads [activeDbFileName] synchronously,
/// so it must be set here. Non-fatal on error — app starts without an
/// active account.
Future<void> bootstrapAccount({
  required String databasesPath,
  required AppLogger log,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await PendingLocalSignupStore.cleanupStaleOnStartup(
      prefs: prefs,
      databasesPath: databasesPath,
    );
    final registry = DeviceRegistryDatabase(
      driftDatabase(name: 'device_registry'),
    );
    final sessionService = SessionPersistenceService(
      prefs: prefs,
      registry: registry,
    );
    final accountId = await sessionService.resolveActiveAccountId();
    if (accountId != null) {
      final account = await registry.findById(accountId);
      if (account != null) {
        activeDbFileName = account.dbFileName;
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
    await registry.close();
  } catch (e, stack) {
    log.error(
      event: 'active_account_resolution_failed',
      exception: e,
      stackTrace: stack,
    );
  }
}
