import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/seed_version.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:sqlite3/sqlite3.dart';

/// Exception thrown when the seed database cannot be initialized.
class SeedManagerException implements Exception {
  SeedManagerException(this.message);
  final String message;

  @override
  String toString() => 'SeedManagerException: $message';
}

/// Manages the Content DB lifecycle on startup.
///
/// Handles:
/// - First launch: decompress seed.db.gz → content.db
/// - App update: atomic replacement when bundled version > installed
/// - Interrupted upgrade recovery via .bak file detection
/// - Corrupted seed fallback
class SeedManager {
  /// Creates a SeedManager.
  ///
  /// [dbDirectory] is the path where content.db will be stored
  /// (typically from `getApplicationDocumentsDirectory()`).
  SeedManager({required String dbDirectory, AppLogger? logger})
    : _dbDirectory = dbDirectory,
      _logger = logger;

  final String _dbDirectory;
  final AppLogger? _logger;

  static const String _contentDbName = 'content.db';
  static const String _backupSuffix = '.bak';
  static const String _seedAssetPath = 'assets/db/content.db.gz';

  String get _dbPath => '$_dbDirectory/$_contentDbName';
  String get _bakPath => '$_dbPath$_backupSuffix';

  /// The resolved path to content.db after [ensureContentDb] completes.
  String get contentDbPath => _dbPath;

  /// Ensures the content database is ready.
  ///
  /// Returns the path to the content.db file. Must be called BEFORE
  /// any content providers are initialized.
  Future<String> ensureContentDb() async {
    final dbFile = File(_dbPath);
    final bakFile = File(_bakPath);

    // Step 1: Check for interrupted upgrade
    if (bakFile.existsSync()) {
      _logger?.warning(event: 'seed_manager_interrupted_upgrade_detected');
      await _recoverFromInterruptedUpgrade();
    }

    // Step 2: Check if content.db exists
    if (!dbFile.existsSync()) {
      _logger?.info(event: 'seed_manager_first_launch_extract');
      await _extractSeedDb(_dbPath);
      return _dbPath;
    }

    // Step 3: Check version (uses raw sqlite3 to avoid triggering Drift
    // migrations on a DB that may be immediately replaced).
    //
    // Two version concepts must agree before we trust the on-device DB:
    //   - seed_metadata.version: bumped by the build pipeline, tracked in
    //     [bundledSeedVersion]. Detects fresh content/asset releases.
    //   - PRAGMA user_version: the Drift schema version. Detects
    //     incompatible schemas — Drift would otherwise try to ALTER the
    //     read-only seed at runtime and crash.
    //
    // Either mismatch forces an atomic replace from the bundled asset.
    final installedVersion = _readInstalledVersion(_dbPath);
    final installedSchema = _readSchemaVersion(_dbPath);
    const expectedSchema = ContentDatabase.expectedSchemaVersion;
    final needsReplace =
        installedVersion == null ||
        bundledSeedVersion > installedVersion ||
        installedSchema == null ||
        installedSchema != expectedSchema;
    if (needsReplace) {
      _logger?.info(
        event: 'seed_manager_replacing_content_db',
        fields: {
          'installedVersion': installedVersion,
          'installedSchema': installedSchema,
          'bundledVersion': bundledSeedVersion,
          'expectedSchema': expectedSchema,
        },
      );
      await _atomicReplace();
    } else {
      _logger?.debug(
        event: 'seed_manager_content_db_up_to_date',
        fields: {
          'installedVersion': installedVersion,
          'installedSchema': installedSchema,
        },
      );
    }

    return _dbPath;
  }

  /// Read the Drift schema version (`PRAGMA user_version`) from the
  /// installed content.db without triggering migrations.
  int? _readSchemaVersion(String dbPath) {
    Database? db;
    try {
      db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
      final row = db.select('PRAGMA user_version').firstOrNull;
      return row?['user_version'] as int?;
    } catch (e) {
      _logger?.error(
        event: 'seed_manager_read_schema_version_failed',
        exception: e,
      );
      return null;
    } finally {
      db?.dispose();
    }
  }

  /// Read the installed seed version from an existing content.db.
  ///
  /// Uses raw sqlite3 instead of Drift to avoid triggering schema migrations
  /// on a database that may be immediately replaced.
  int? _readInstalledVersion(String dbPath) {
    Database? db;
    try {
      db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
      final result = db.select('SELECT version FROM seed_metadata LIMIT 1');
      if (result.isEmpty) return null;
      return result.first['version'] as int?;
    } catch (e) {
      _logger?.error(
        event: 'seed_manager_read_seed_version_failed',
        exception: e,
      );
      return null;
    } finally {
      db?.dispose();
    }
  }

  /// Extract seed.db.gz from assets to the target path.
  ///
  /// The bundled asset is gzipped — `dart:io`'s `gzip.decode` is C-native
  /// (zlib) and decodes a ~110 MB blob in 1–2 s on a mid-range phone, so
  /// no worker isolate is needed.
  ///
  /// Source-of-truth in the repo is `assets/db/content.db.xz` (smaller,
  /// fits under GitHub's 100 MB hard limit). The build pipeline converts
  /// xz → gz via `tool/prepare_asset.dart` before `flutter build`.
  Future<void> _extractSeedDb(String targetPath) async {
    try {
      final compressed = await rootBundle.load(_seedAssetPath);
      final decompressed = gzip.decode(compressed.buffer.asUint8List());
      await File(targetPath).writeAsBytes(decompressed, flush: true);
      _logger?.info(
        event: 'seed_manager_seed_extracted',
        fields: {'sizeMb': (decompressed.length / 1024 / 1024).toStringAsFixed(1)},
      );
    } catch (e) {
      _logger?.error(
        event: 'seed_manager_extract_failed',
        exception: e,
      );
      throw SeedManagerException(
        'Failed to extract content database. '
        'Please restart the app or reinstall.',
      );
    }
  }

  /// Atomic replacement: backup → extract → verify → cleanup.
  Future<void> _atomicReplace() async {
    final dbFile = File(_dbPath);
    final bakFile = File(_bakPath);

    // Step 1: Backup current content.db
    if (dbFile.existsSync()) {
      await dbFile.rename(_bakPath);
    }

    // Step 2: Extract new seed
    try {
      await _extractSeedDb(_dbPath);

      // Step 3: Verify the new database is valid
      final newVersion = _readInstalledVersion(_dbPath);
      if (newVersion == null) {
        throw SeedManagerException('New seed database has no version metadata');
      }

      // Step 4: Delete backup
      if (bakFile.existsSync()) {
        await bakFile.delete();
      }

      _logger?.info(
        event: 'seed_manager_upgrade_complete',
        fields: {'newVersion': newVersion},
      );
    } catch (e) {
      // Extraction or verification failed — rollback
      _logger?.error(
        event: 'seed_manager_upgrade_failed',
        exception: e,
      );
      await _rollback();
      // If rollback succeeded, we're on the old version (acceptable)
      // If no old version existed, re-throw
      if (!File(_dbPath).existsSync()) {
        throw SeedManagerException(
          'Content database upgrade failed and no previous version available. '
          'Please restart the app or reinstall.',
        );
      }
    }
  }

  /// Recover from an interrupted upgrade.
  Future<void> _recoverFromInterruptedUpgrade() async {
    final dbFile = File(_dbPath);
    final bakFile = File(_bakPath);

    // Delete partial content.db if it exists
    if (dbFile.existsSync()) {
      await dbFile.delete();
    }

    // Restore backup
    if (bakFile.existsSync()) {
      await bakFile.rename(_dbPath);
      _logger?.info(event: 'seed_manager_backup_restored_after_interrupt');
    }
  }

  /// Rollback a failed upgrade by restoring the backup.
  Future<void> _rollback() async {
    final dbFile = File(_dbPath);
    final bakFile = File(_bakPath);

    // Delete the failed new file
    if (dbFile.existsSync()) {
      try {
        await dbFile.delete();
      } catch (_) {
        // Best effort
      }
    }

    // Restore backup
    if (bakFile.existsSync()) {
      await bakFile.rename(_dbPath);
      _logger?.info(event: 'seed_manager_rolled_back_to_previous_version');
    }
  }

  /// Force re-extraction of the seed database.
  /// Used by error recovery UI when the user taps "Retry".
  Future<String> forceReExtract() async {
    final dbFile = File(_dbPath);

    if (dbFile.existsSync()) {
      await dbFile.delete();
    }

    await _extractSeedDb(_dbPath);
    return _dbPath;
  }

  /// Deletes the existing content database and re-extracts from the seed.
  ///
  /// Convenience static factory that creates a temporary [SeedManager] and
  /// calls [forceReExtract]. Use this when you need a one-shot repair without
  /// holding a [SeedManager] instance.
  static Future<String> repairContentDatabase({
    required String dbDirectory,
    AppLogger? logger,
  }) async {
    final manager = SeedManager(dbDirectory: dbDirectory, logger: logger);
    logger?.info(event: 'seed_manager_repair_requested');
    return manager.forceReExtract();
  }
}
