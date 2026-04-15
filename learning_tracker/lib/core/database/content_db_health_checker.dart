import 'dart:io';

import 'package:learning_tracker/core/database/seed_manager.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:talker/talker.dart';

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
  /// [talker] is used for logging recovery actions.
  ContentDbHealthChecker({required SeedManager seedManager, Talker? talker})
    : _seedManager = seedManager,
      _talker = talker;

  final SeedManager _seedManager;
  final Talker? _talker;

  /// Checks the content database integrity and attempts recovery if corrupted.
  ///
  /// Returns `true` if the database is healthy (or was successfully repaired),
  /// `false` if recovery failed.
  Future<bool> checkAndRecover(String dbDirectory) async {
    final dbPath = '$dbDirectory/content.db';
    final dbFile = File(dbPath);

    if (!dbFile.existsSync()) {
      _talker?.warning(
        'ContentDbHealthChecker: content.db not found at $dbPath',
      );
      return _attemptRecovery();
    }

    final isHealthy = _runIntegrityCheck(dbPath);
    if (isHealthy) {
      _talker?.debug('ContentDbHealthChecker: integrity check passed');
      return true;
    }

    _talker?.error(
      'ContentDbHealthChecker: integrity check FAILED — '
      'attempting recovery',
    );
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
      _talker?.error('ContentDbHealthChecker: integrity check threw', e, st);
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
      _talker?.info(
        'ContentDbHealthChecker: re-extracting content DB from seed',
      );
      await _seedManager.forceReExtract();
      _talker?.info('ContentDbHealthChecker: recovery succeeded');
      return true;
    } catch (e, st) {
      _talker?.error('ContentDbHealthChecker: recovery FAILED', e, st);
      return false;
    }
  }
}
