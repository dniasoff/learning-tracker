import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/seed_version.dart';
import 'package:talker/talker.dart';

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
  SeedManager({
    required String dbDirectory,
    Talker? talker,
  })  : _dbDirectory = dbDirectory,
        _talker = talker;

  final String _dbDirectory;
  final Talker? _talker;

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
      _talker?.warning(
        'SeedManager: Found .bak file — recovering from interrupted upgrade',
      );
      await _recoverFromInterruptedUpgrade();
    }

    // Step 2: Check if content.db exists
    if (!dbFile.existsSync()) {
      _talker?.info('SeedManager: First launch — extracting seed database');
      await _extractSeedDb(_dbPath);
      return _dbPath;
    }

    // Step 3: Check version
    final installedVersion = await _readInstalledVersion(_dbPath);
    if (installedVersion == null || bundledSeedVersion > installedVersion) {
      _talker?.info(
        'SeedManager: Upgrading content DB '
        '(installed: $installedVersion → bundled: $bundledSeedVersion)',
      );
      await _atomicReplace();
    } else {
      _talker?.debug('SeedManager: Content DB up to date (v$installedVersion)');
    }

    return _dbPath;
  }

  /// Read the installed seed version from an existing content.db.
  Future<int?> _readInstalledVersion(String dbPath) async {
    try {
      final db = ContentDatabase(NativeDatabase(File(dbPath)));
      try {
        final meta = await db.seedMetadataDao.getVersion();
        return meta?.version;
      } finally {
        await db.close();
      }
    } catch (e) {
      _talker?.error('SeedManager: Failed to read seed version', e);
      return null;
    }
  }

  /// Extract seed.db.gz from assets to the target path.
  Future<void> _extractSeedDb(String targetPath) async {
    try {
      final compressed = await rootBundle.load(_seedAssetPath);
      final decompressed = gzip.decode(compressed.buffer.asUint8List());
      await File(targetPath).writeAsBytes(decompressed, flush: true);
      _talker?.info(
        'SeedManager: Seed extracted '
        '(${(decompressed.length / 1024 / 1024).toStringAsFixed(1)} MB)',
      );
    } catch (e) {
      _talker?.error('SeedManager: Failed to extract seed database', e);
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
      final newVersion = await _readInstalledVersion(_dbPath);
      if (newVersion == null) {
        throw SeedManagerException('New seed database has no version metadata');
      }

      // Step 4: Delete backup
      if (bakFile.existsSync()) {
        await bakFile.delete();
      }

      _talker?.info('SeedManager: Upgrade complete (v$newVersion)');
    } catch (e) {
      // Extraction or verification failed — rollback
      _talker?.error('SeedManager: Upgrade failed, rolling back', e);
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
      _talker?.info('SeedManager: Restored backup after interrupted upgrade');
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
      _talker?.info('SeedManager: Rolled back to previous version');
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
    Talker? talker,
  }) async {
    final manager = SeedManager(dbDirectory: dbDirectory, talker: talker);
    talker?.info('SeedManager: repairContentDatabase requested');
    return manager.forceReExtract();
  }
}
