import 'package:learning_tracker/core/database/seed_manager.dart';
import 'package:learning_tracker/core/logging/logger.dart';

/// Decompresses the bundled seed content DB to a writable location and
/// returns the resolved path.
///
/// Story 19.2b / 19.6: SeedManager handles first-launch extraction,
/// version-driven upgrades, .bak rollback, and corruption recovery.
Future<String> bootstrapSeedDb({
  required String dbDirectory,
  required AppLogger log,
}) async {
  try {
    final seedManager = SeedManager(dbDirectory: dbDirectory, logger: log);
    final path = await seedManager.ensureContentDb();
    log.info(event: 'content_db_ready', fields: {'path': path});
    return path;
  } catch (e, stack) {
    log.error(
      event: 'seed_manager_init_failed',
      exception: e,
      stackTrace: stack,
    );
    rethrow;
  }
}
