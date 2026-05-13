import 'dart:io';

import 'package:learning_tracker/core/database/seed_manager.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:sqlite3/sqlite3.dart';

/// Checks the health of the content database and attempts recovery when
/// corruption is detected.
///
/// Wraps content DB queries in try/catch, running `PRAGMA integrity_check`
/// on SQLite exceptions. If the check fails, triggers a full re-extraction
/// from the bundled seed database.
class ContentDbHealthChecker {
  /// Creates a [ContentDbHealthChecker].
  ///
  /// [seedManager] is used to re-extract the seed when corruption is found.
  /// [logger] is used for logging recovery actions.
  ContentDbHealthChecker({required SeedManager seedManager, AppLogger? logger})
    : _seedManager = seedManager,
      _logger = logger;

  final SeedManager _seedManager;
  final AppLogger? _logger;

  /// Checks the content database integrity and attempts recovery if corrupted.
  ///
  /// Returns `true` if the database is healthy (or was successfully repaired),
  /// `false` if recovery failed.
  Future<bool> checkAndRecover(String dbDirectory) async {
    final dbPath = '$dbDirectory/content.db';
    final dbFile = File(dbPath);

    if (!dbFile.existsSync()) {
      _logger?.warning(
        event: 'content_db_health_db_missing',
        fields: {'dbPath': dbPath},
      );
      return _attemptRecovery();
    }

    final isHealthy = _runIntegrityCheck(dbPath);
    if (isHealthy) {
      _logger?.debug(event: 'content_db_health_integrity_passed');
      return true;
    }

    _logger?.error(event: 'content_db_health_integrity_failed_recovering');
    return _attemptRecovery();
  }

  /// Runs `PRAGMA integrity_check` on the database at [dbPath].
  ///
  /// Returns `true` when the result is `'ok'`.
  bool _runIntegrityCheck(String dbPath) {
    Database? db;
    try {
      db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
      final result = db.select('PRAGMA integrity_check');

      // PRAGMA integrity_check returns a single row with column
      // 'integrity_check' set to 'ok' when the database is healthy.
      if (result.isNotEmpty) {
        final value = result.first.values.first?.toString();
        return value == 'ok';
      }
      return false;
    } on SqliteException catch (e, st) {
      _logger?.error(
        event: 'content_db_health_integrity_check_threw',
        exception: e,
        stackTrace: st,
      );
      return false;
    } finally {
      db?.dispose();
    }
  }

  /// Attempts to recover the content database by re-extracting from the seed.
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> _attemptRecovery() async {
    try {
      _logger?.info(event: 'content_db_health_recovery_reextracting');
      await _seedManager.forceReExtract();
      _logger?.info(event: 'content_db_health_recovery_succeeded');
      return true;
    } catch (e, st) {
      _logger?.error(
        event: 'content_db_health_recovery_failed',
        exception: e,
        stackTrace: st,
      );
      return false;
    }
  }
}
