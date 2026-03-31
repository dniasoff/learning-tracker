# Story 19.2b: Content DB Runtime Upgrade Flow

Status: ready-for-dev

## Story

As a user who updates the app,
I want the Content DB to seamlessly upgrade to the latest bundled version,
So that I always have the most current text content and calendar data without any manual action.

## Acceptance Criteria

**AC-1: First launch extraction**
**Given** the app is launched for the first time (no `content.db` on device)
**When** `SeedManager.ensureContentDb()` runs during startup
**Then** it decompresses `assets/db/content.db.gz` into `content.db` in the app documents directory
**And** the resulting file is a valid SQLite database with a readable `SeedMetadata` row

**AC-2: App update with newer seed triggers atomic replacement**
**Given** `content.db` exists with `SeedMetadata.version = N`
**And** the bundled `BUNDLED_SEED_VERSION` constant is `N+1`
**When** `SeedManager.ensureContentDb()` runs
**Then** the existing `content.db` is renamed to `content.db.bak`
**And** `seed.db.gz` is decompressed to a new `content.db`
**And** the new `content.db` is verified (SeedMetadata readable)
**And** `content.db.bak` is deleted
**And** the content database provider is re-initialized with the new file

**AC-3: Same-version seed skipped with zero overhead**
**Given** `content.db` exists with `SeedMetadata.version = N`
**And** `BUNDLED_SEED_VERSION` is also `N`
**When** `SeedManager.ensureContentDb()` runs
**Then** it returns the existing path immediately without any file I/O beyond the version read
**And** total elapsed time is < 50ms

**AC-4: Interrupted upgrade recovery via .bak detection**
**Given** `content.db.bak` exists on launch (indicating a previous upgrade was interrupted)
**When** `SeedManager.ensureContentDb()` runs
**Then** it deletes the partial/corrupt `content.db` (if present)
**And** renames `content.db.bak` back to `content.db`
**And** retries the upgrade from scratch

**AC-5: Corrupted seed fallback to existing content.db**
**Given** `content.db` exists with valid data
**And** decompression of the new `seed.db.gz` fails (gzip error, disk full, etc.)
**When** `SeedManager.ensureContentDb()` runs
**Then** it logs the error
**And** falls back to the existing `content.db` (restoring from `.bak` if needed)
**And** the app continues to function with the older content version

**AC-6: No content.db AND corrupted seed shows error UI**
**Given** no `content.db` exists on device (first launch)
**And** decompression of `seed.db.gz` fails
**When** `SeedManager.ensureContentDb()` runs
**Then** it throws a `SeedManagerException` with a user-facing message
**And** the app displays a "Content unavailable" error screen with a retry button

**AC-7: Decompression performance**
**Given** `seed.db.gz` is ~30-60MB compressed
**When** decompression runs
**Then** it completes in < 5 seconds on a mid-range device
**And** uses streaming gzip decompression (bounded memory, not loading entire file into RAM)

**AC-8: SeedManager runs before any content queries**
**Given** the app startup sequence
**When** `main()` executes
**Then** `SeedManager.ensureContentDb()` completes before `contentDatabaseProvider` is initialized
**And** no content query can race against the seed check

**AC-9: SeedMetadata.version correctly read and compared**
**Given** `content.db` exists
**When** SeedManager reads the version
**Then** it opens the database, reads `SELECT version FROM seed_metadata WHERE id = 1`
**And** compares the result against `BUNDLED_SEED_VERSION` using integer comparison (`>`)

**AC-10: Loading indicator during decompression**
**Given** decompression is required (first launch or upgrade)
**When** decompression takes > 500ms
**Then** a brief splash/loading indicator is shown to the user
**And** normal launches (no upgrade needed) show no indicator

**AC-11: All code paths tested**
**Given** the test suite
**When** tests run
**Then** the following paths are covered: first launch, upgrade, same version, interrupted upgrade, corrupted seed with fallback, corrupted seed without fallback

## Tasks / Subtasks

### T1: Create seed_version.dart Constants File

**File:** `lib/core/database/seed_version.dart`

- [ ] Create the file with the bundled seed version constant:

```dart
/// The version of the bundled seed database asset (assets/db/content.db.gz).
///
/// This constant is updated by the seed build pipeline (tool/seed_content_db.dart)
/// whenever a new seed is built. SeedManager compares this against
/// SeedMetadata.version in the installed content.db to determine if an
/// upgrade is needed.
///
/// Increment this value each time a new seed.db.gz is committed to the repo.
const int BUNDLED_SEED_VERSION = 1;
```

- [ ] Ensure the file has no Flutter imports (pure Dart) so it can be imported by both the CLI build tool and the runtime SeedManager

### T2: Create SeedManagerException

**File:** `lib/core/database/seed_manager.dart` (same file as SeedManager, or separate if preferred)

- [ ] Define a typed exception for seed management failures:

```dart
/// Exception thrown when SeedManager cannot provide a usable content database.
///
/// This is a fatal exception for first-launch scenarios where no fallback
/// content.db exists. The app should display an error UI with a retry option.
class SeedManagerException implements Exception {
  const SeedManagerException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'SeedManagerException: $message'
      '${cause != null ? ' (cause: $cause)' : ''}';
}
```

### T3: Create SeedManager Core Class

**File:** `lib/core/database/seed_manager.dart`

- [ ] Create the `SeedManager` class with dependency injection for testability:

```dart
import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/seed_version.dart';
import 'package:learning_tracker/core/logging/logger.dart';

class SeedManager {
  SeedManager({
    required String databaseDirectory,
    AssetBundle? assetBundle,
  })  : _dbDir = databaseDirectory,
        _assetBundle = assetBundle ?? rootBundle;

  final String _dbDir;
  final AssetBundle _assetBundle;

  /// Path to the content database file.
  String get _contentDbPath => '$_dbDir/content.db';

  /// Path to the backup file used during atomic upgrades.
  String get _backupPath => '$_dbDir/content.db.bak';

  /// Seed asset path inside the APK bundle.
  static const _seedAssetPath = 'assets/db/content.db.gz';
}
```

- [ ] The constructor takes `databaseDirectory` (from `getApplicationDocumentsDirectory()`) and an optional `AssetBundle` for testing
- [ ] The asset bundle default is `rootBundle` from `flutter/services.dart`

### T4: Implement ensureContentDb() Main Entry Point

**File:** `lib/core/database/seed_manager.dart`

- [ ] Implement the main orchestration method:

```dart
/// Ensures a valid content.db exists at the expected path.
///
/// Call this BEFORE initializing contentDatabaseProvider in main().
///
/// Returns the absolute path to the ready content.db file.
///
/// Throws [SeedManagerException] only when:
/// - This is a first launch (no existing content.db)
/// - AND decompression of the bundled seed fails
Future<String> ensureContentDb() async {
  final contentFile = File(_contentDbPath);
  final backupFile = File(_backupPath);

  // Step 1: Recover from interrupted upgrade
  if (backupFile.existsSync()) {
    await _recoverFromInterruptedUpgrade(contentFile, backupFile);
  }

  // Step 2: Check if content.db exists
  if (!contentFile.existsSync()) {
    // First launch — must decompress
    await _decompressSeed(contentFile);
    return _contentDbPath;
  }

  // Step 3: Version comparison
  final installedVersion = await _readInstalledVersion(contentFile);
  if (installedVersion == null) {
    // Corrupted DB — can't read version
    AppLogger.instance.warning(
      'Content DB corrupted (cannot read version), attempting re-decompress',
    );
    await _replaceContentDb(contentFile, backupFile);
    return _contentDbPath;
  }

  if (BUNDLED_SEED_VERSION > installedVersion) {
    // Upgrade needed
    AppLogger.instance.info(
      'Content DB upgrade: v$installedVersion -> v$BUNDLED_SEED_VERSION',
    );
    await _replaceContentDb(contentFile, backupFile);
    return _contentDbPath;
  }

  // Same or newer version — no action needed
  AppLogger.instance.info(
    'Content DB up to date (v$installedVersion)',
  );
  return _contentDbPath;
}
```

### T5: Implement _readInstalledVersion()

**File:** `lib/core/database/seed_manager.dart`

- [ ] Open the existing content.db, read SeedMetadata.version, close immediately:

```dart
/// Reads the seed version from an existing content.db file.
///
/// Returns null if the file is corrupted or the SeedMetadata table
/// is missing/empty.
Future<int?> _readInstalledVersion(File contentFile) async {
  NativeDatabase? db;
  try {
    db = NativeDatabase(contentFile);
    // Use raw SQL to avoid needing the full ContentDatabase class
    // just for a version check. This is intentional — we don't want
    // to open a full Drift database just to read one integer.
    final result = db.select(
      'SELECT version FROM seed_metadata WHERE id = 1',
    );
    if (result.isEmpty) return null;
    return result.first['version'] as int?;
  } catch (e) {
    AppLogger.instance.warning(
      'Failed to read content DB version: $e',
    );
    return null;
  } finally {
    db?.close();
  }
}
```

**IMPORTANT:** This uses raw SQL via `NativeDatabase` directly, NOT a full `ContentDatabase` Drift class. Opening a Drift database triggers `onCreate`/`onUpgrade` callbacks and is heavier. We only need one integer. The `NativeDatabase` from `drift/native.dart` provides low-level `select()` for this purpose.

**Alternative approach if `NativeDatabase.select()` is not available in the drift version used:** Use `sqlite3` directly:

```dart
import 'package:sqlite3/sqlite3.dart';

Future<int?> _readInstalledVersion(File contentFile) async {
  Database? db;
  try {
    db = sqlite3.open(contentFile.path);
    final result = db.select(
      'SELECT version FROM seed_metadata WHERE id = 1',
    );
    if (result.isEmpty) return null;
    return result.first['version'] as int?;
  } catch (e) {
    AppLogger.instance.warning('Failed to read content DB version: $e');
    return null;
  } finally {
    db?.dispose();
  }
}
```

- [ ] Verify which SQLite access pattern is available. The project uses `drift_flutter: ^0.2.8` which bundles `sqlite3_flutter_libs`. Check if `package:sqlite3/sqlite3.dart` is directly available or if `drift/native.dart` exposes a raw query API. If neither works cleanly, use `ContentDatabase` briefly:

```dart
Future<int?> _readInstalledVersion(File contentFile) async {
  ContentDatabase? contentDb;
  try {
    contentDb = ContentDatabase(NativeDatabase(contentFile));
    final metadata = await contentDb.seedMetadataDao.getVersion();
    return metadata?.version;
  } catch (e) {
    AppLogger.instance.warning('Failed to read content DB version: $e');
    return null;
  } finally {
    await contentDb?.close();
  }
}
```

### T6: Implement _decompressSeed() for First Launch

**File:** `lib/core/database/seed_manager.dart`

- [ ] Implement streaming gzip decompression from bundled asset:

```dart
/// Decompresses seed.db.gz from bundled assets to the content.db path.
///
/// Uses streaming decompression to bound memory usage. The compressed
/// seed is ~30-60MB; uncompressed is ~200-300MB. Loading the entire
/// uncompressed file into memory would risk OOM on low-end devices.
///
/// Throws [SeedManagerException] if decompression fails AND no
/// fallback content.db exists.
Future<void> _decompressSeed(File targetFile) async {
  try {
    AppLogger.instance.info('Decompressing content seed...');
    final stopwatch = Stopwatch()..start();

    // Load compressed bytes from asset bundle
    final compressedData = await _assetBundle.load(_seedAssetPath);
    final compressedBytes = compressedData.buffer.asUint8List(
      compressedData.offsetInBytes,
      compressedData.lengthInBytes,
    );

    // Stream-decompress to file
    final inputStream = Stream.value(compressedBytes);
    final decompressed = inputStream.transform(gzip.decoder);
    final sink = targetFile.openWrite();
    await decompressed.pipe(sink);

    stopwatch.stop();
    AppLogger.instance.info(
      'Content seed decompressed in ${stopwatch.elapsedMilliseconds}ms '
      '(${targetFile.lengthSync()} bytes)',
    );

    // Verify the decompressed file is valid SQLite
    await _verifyContentDb(targetFile);
  } catch (e) {
    // Clean up partial file on failure
    if (targetFile.existsSync()) {
      try {
        targetFile.deleteSync();
      } catch (_) {
        // Best effort cleanup
      }
    }
    rethrow;
  }
}
```

- [ ] Add the `dart:io` import for `gzip` (from `dart:io` — specifically `GZipCodec`)
- [ ] Note: `rootBundle.load()` returns a `ByteData`. The `.buffer.asUint8List()` call extracts the raw bytes for the gzip decoder stream

### T7: Implement _verifyContentDb()

**File:** `lib/core/database/seed_manager.dart`

- [ ] Verify the decompressed file is a valid SQLite database with the expected metadata:

```dart
/// Verifies a content.db file is valid by reading its SeedMetadata.
///
/// Throws if the file is not a valid SQLite database or SeedMetadata
/// is missing.
Future<void> _verifyContentDb(File contentFile) async {
  final version = await _readInstalledVersion(contentFile);
  if (version == null) {
    throw SeedManagerException(
      'Decompressed content.db has no valid SeedMetadata',
    );
  }
  AppLogger.instance.info('Verified content.db: seed version $version');
}
```

### T8: Implement _replaceContentDb() for Atomic Upgrade

**File:** `lib/core/database/seed_manager.dart`

- [ ] Implement the atomic replacement flow with backup/rollback:

```dart
/// Atomically replaces content.db with a fresh decompression from seed.db.gz.
///
/// Flow:
/// 1. Rename content.db -> content.db.bak (rollback safety net)
/// 2. Decompress seed.db.gz -> content.db
/// 3. Verify the new content.db
/// 4. Delete content.db.bak
///
/// If step 2 or 3 fails, restores from .bak and continues with old version.
Future<void> _replaceContentDb(File contentFile, File backupFile) async {
  // Step 1: Backup existing (if it exists and is not already backed up)
  if (contentFile.existsSync() && !backupFile.existsSync()) {
    contentFile.renameSync(_backupPath);
    AppLogger.instance.info('Backed up content.db -> content.db.bak');
  }

  // Step 2: Decompress new seed
  try {
    await _decompressSeed(contentFile);
  } catch (e) {
    AppLogger.instance.error(
      'Seed decompression failed during upgrade, restoring backup',
      e,
    );
    // Restore from backup
    await _restoreFromBackup(contentFile, backupFile);
    return;
  }

  // Step 3: Verify (already done inside _decompressSeed via _verifyContentDb)

  // Step 4: Clean up backup
  if (backupFile.existsSync()) {
    backupFile.deleteSync();
    AppLogger.instance.info('Upgrade complete, deleted content.db.bak');
  }
}
```

### T9: Implement _recoverFromInterruptedUpgrade()

**File:** `lib/core/database/seed_manager.dart`

- [ ] Detect and recover from interrupted upgrade (`.bak` file present on launch):

```dart
/// Recovers from an interrupted upgrade detected by the presence of .bak.
///
/// If content.db.bak exists, a previous upgrade was interrupted (app killed
/// during decompression). We restore the backup and retry the upgrade.
Future<void> _recoverFromInterruptedUpgrade(
  File contentFile,
  File backupFile,
) async {
  AppLogger.instance.warning(
    'Detected interrupted content DB upgrade (content.db.bak exists)',
  );

  // Delete the partial/corrupt content.db (may not exist if crash
  // happened before decompression started)
  if (contentFile.existsSync()) {
    contentFile.deleteSync();
    AppLogger.instance.info('Deleted partial content.db');
  }

  // Restore backup as the current content.db
  backupFile.renameSync(_contentDbPath);
  AppLogger.instance.info('Restored content.db from backup');

  // The caller (ensureContentDb) will now proceed with the normal
  // version check, which will detect the version mismatch and
  // retry the upgrade.
}
```

### T10: Implement _restoreFromBackup()

**File:** `lib/core/database/seed_manager.dart`

- [ ] Restore from backup when upgrade decompression fails:

```dart
/// Restores content.db from .bak after a failed upgrade attempt.
///
/// If no backup exists (first launch failure), throws SeedManagerException.
Future<void> _restoreFromBackup(File contentFile, File backupFile) async {
  // Clean up failed decompression
  if (contentFile.existsSync()) {
    try {
      contentFile.deleteSync();
    } catch (_) {}
  }

  if (backupFile.existsSync()) {
    backupFile.renameSync(_contentDbPath);
    AppLogger.instance.warning(
      'Restored content.db from backup (using older seed version)',
    );
  } else {
    // No backup AND decompression failed = fatal for first launch
    throw const SeedManagerException(
      'Failed to decompress content database and no backup available. '
      'Please restart the app to try again.',
    );
  }
}
```

### T11: Implement repairContentDatabase() Public Method

**File:** `lib/core/database/seed_manager.dart`

- [ ] Add a public repair method for the retry button in error UI:

```dart
/// Force re-decompresses the content database from bundled assets.
///
/// Use this when the user taps "Retry" on the error screen, or when
/// content corruption is detected at runtime.
Future<String> repairContentDatabase() async {
  final contentFile = File(_contentDbPath);
  final backupFile = File(_backupPath);

  // Delete everything and start fresh
  if (contentFile.existsSync()) contentFile.deleteSync();
  if (backupFile.existsSync()) backupFile.deleteSync();

  await _decompressSeed(contentFile);
  return _contentDbPath;
}
```

### T12: Integrate SeedManager into main.dart Startup

**File:** `lib/main.dart`

- [ ] Add `SeedManager.ensureContentDb()` call to `main()`, BEFORE `ProviderContainer` creation:

```dart
import 'package:learning_tracker/core/database/seed_manager.dart';
import 'package:path_provider/path_provider.dart';
```

- [ ] Insert the SeedManager call into the startup sequence. The new `main()` should have this structure:

```dart
void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // ... existing Firebase / GoogleSignIn / Logger init ...

      // Ensure content DB is ready BEFORE any providers that query it
      final appDir = await getApplicationDocumentsDirectory();
      final seedManager = SeedManager(databaseDirectory: appDir.path);
      late final String contentDbPath;
      try {
        contentDbPath = await seedManager.ensureContentDb();
      } on SeedManagerException catch (e, stack) {
        talker.error('Content DB setup failed (fatal)', e, stack);
        // Run app with error state — show retry UI
        runApp(
          ContentDbErrorApp(
            onRetry: () async {
              final path = await seedManager.repairContentDatabase();
              // Restart app or reinitialize providers
            },
          ),
        );
        return;
      }

      final container = ProviderContainer(
        overrides: [
          contentDbPathProvider.overrideWithValue(contentDbPath),
        ],
        observers: [ /* ... existing observers ... */ ],
      );

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const LearningTrackerApp(),
        ),
      );
    },
    // ... existing error handler ...
  );
}
```

- [ ] Add `path_provider` to `pubspec.yaml` dependencies (if not already present as a direct dependency):

```yaml
dependencies:
  path_provider: ^2.1.0
```

- [ ] Note: `path_provider` is currently a transitive dependency (present in pubspec.lock) but NOT a direct dependency in pubspec.yaml. It must be added explicitly.

### T13: Create contentDbPathProvider

**File:** `lib/core/providers/database_provider.dart`

- [ ] Add a provider that holds the content DB file path, overridden in `main()`:

```dart
/// The filesystem path to the ready content.db file.
///
/// This provider MUST be overridden in main() with the path returned
/// by SeedManager.ensureContentDb(). Accessing it without an override
/// throws an UnimplementedError.
final contentDbPathProvider = Provider<String>((ref) {
  throw UnimplementedError(
    'contentDbPathProvider must be overridden in ProviderScope',
  );
});
```

- [ ] This provider will be consumed by the `contentDatabaseProvider` (created in story 19.2):

```dart
@Riverpod(keepAlive: true)
ContentDatabase contentDatabase(Ref ref) {
  final path = ref.watch(contentDbPathProvider);
  final database = ContentDatabase(
    NativeDatabase(
      File(path),
      setup: (db) {
        db.execute('PRAGMA query_only = ON');
      },
    ),
  );
  ref.onDispose(database.close);
  return database;
}
```

### T14: Add Seed Asset to pubspec.yaml

**File:** `learning_tracker/pubspec.yaml`

- [ ] Add the seed database asset path to the flutter assets section:

```yaml
flutter:
  assets:
    - assets/images/
    - assets/fonts/
    - assets/content/hierarchy/
    - assets/db/content.db.gz       # <-- ADD THIS
```

- [ ] Create the `assets/db/` directory (it will contain `content.db.gz` once the build tool from 19.3 produces it)
- [ ] For development/testing before 19.3 is complete, create a minimal placeholder `content.db.gz`:
  - Create a SQLite DB in memory with just a `seed_metadata` table and one row (`version = 1`)
  - Gzip compress it
  - Place at `assets/db/content.db.gz`

### T15: Create ContentDbErrorApp Widget for Fatal Errors

**File:** `lib/core/presentation/content_db_error_app.dart`

- [ ] Create a minimal MaterialApp that shows when content DB setup fails on first launch:

```dart
import 'package:flutter/material.dart';

/// Shown when SeedManager fails to provide a content database
/// on first launch (no fallback available).
class ContentDbErrorApp extends StatelessWidget {
  const ContentDbErrorApp({
    required this.onRetry,
    super.key,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Content Unavailable',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The app could not load its content database. '
                  'This may be caused by insufficient storage space.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

### T16: Create Placeholder Seed for Development

**Purpose:** Allow development and testing of SeedManager before the full seed build tool (19.3) produces a real `content.db.gz`.

- [ ] Create a Dart script `tool/create_dev_seed.dart` that:
  1. Creates an in-memory SQLite database
  2. Creates the `seed_metadata` table with the expected schema
  3. Inserts one row: `{id: 1, version: 1, built_at: '...', build_id: 'dev', text_cache_count: 0, calendar_cycle_count: 0}`
  4. Exports to `assets/db/content.db`
  5. Gzip compresses to `assets/db/content.db.gz`
  6. Deletes the uncompressed file

```dart
// tool/create_dev_seed.dart
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final dbFile = File('assets/db/content.db');
  final gzFile = File('assets/db/content.db.gz');

  // Ensure directory exists
  dbFile.parent.createSync(recursive: true);

  // Create minimal seed DB
  final db = sqlite3.open(dbFile.path);
  db.execute('''
    CREATE TABLE seed_metadata (
      id INTEGER PRIMARY KEY DEFAULT 1,
      version INTEGER NOT NULL,
      built_at TEXT NOT NULL,
      build_id TEXT NOT NULL,
      text_cache_count INTEGER NOT NULL,
      calendar_cycle_count INTEGER NOT NULL
    )
  ''');
  db.execute('''
    INSERT INTO seed_metadata (version, built_at, build_id, text_cache_count, calendar_cycle_count)
    VALUES (1, '${DateTime.now().toUtc().toIso8601String()}', 'dev-placeholder', 0, 0)
  ''');
  db.execute('VACUUM');
  db.dispose();

  // Compress
  final bytes = dbFile.readAsBytesSync();
  gzFile.writeAsBytesSync(gzip.encode(bytes));
  dbFile.deleteSync();

  print('Created placeholder seed at ${gzFile.path} (${gzFile.lengthSync()} bytes)');
}
```

- [ ] Add a Makefile target:

```makefile
dev-seed:
	dart run tool/create_dev_seed.dart
```

### T17: Unit Tests -- SeedManager

**File:** `test/core/database/seed_manager_test.dart`

- [ ] **Test: First launch decompresses seed**
  - Set up a temp directory with no `content.db`
  - Create a test `seed.db.gz` (tiny valid SQLite with seed_metadata)
  - Mock the asset bundle to serve the test seed
  - Call `ensureContentDb()`
  - Assert `content.db` exists in the temp directory
  - Assert it contains `seed_metadata` with the expected version

```dart
test('first launch decompresses seed.db.gz to content.db', () async {
  final tempDir = await Directory.systemTemp.createTemp('seed_test_');
  final testSeedGz = _createTestSeedGz(version: 1);
  final mockBundle = _MockAssetBundle(testSeedGz);

  final seedManager = SeedManager(
    databaseDirectory: tempDir.path,
    assetBundle: mockBundle,
  );

  final path = await seedManager.ensureContentDb();

  expect(File(path).existsSync(), isTrue);
  final version = _readVersionFromDb(path);
  expect(version, equals(1));

  tempDir.deleteSync(recursive: true);
});
```

- [ ] **Test: Same version skips decompression**
  - Place a valid `content.db` with version 1 in temp dir
  - Set `BUNDLED_SEED_VERSION = 1`
  - Call `ensureContentDb()`
  - Assert the file was not modified (check `lastModifiedSync()`)

- [ ] **Test: Newer version triggers replacement**
  - Place `content.db` with version 1
  - Create seed.db.gz with version 2
  - Call `ensureContentDb()`
  - Assert `content.db` now has version 2
  - Assert `content.db.bak` does NOT exist (cleanup succeeded)

- [ ] **Test: Interrupted upgrade recovery**
  - Place both `content.db.bak` (version 1, valid) and `content.db` (partial/empty)
  - Call `ensureContentDb()`
  - Assert `content.db.bak` is gone
  - Assert `content.db` is valid (restored then upgraded, or restored if version matches)

- [ ] **Test: Corrupted content.db triggers re-decompress**
  - Write random bytes to `content.db` path
  - Create seed.db.gz with version 1
  - Call `ensureContentDb()`
  - Assert `content.db` is now valid

- [ ] **Test: Decompression failure falls back to existing content.db**
  - Place valid `content.db` with version 1
  - Provide a corrupt seed.db.gz (invalid gzip data)
  - Set bundled version to 2 (to trigger upgrade attempt)
  - Call `ensureContentDb()`
  - Assert `content.db` still has version 1 (fallback succeeded)

- [ ] **Test: First launch with corrupt seed throws SeedManagerException**
  - No `content.db` in temp dir
  - Provide a corrupt seed.db.gz
  - Call `ensureContentDb()`
  - Assert `SeedManagerException` is thrown

- [ ] **Test: repairContentDatabase() force re-decompresses**
  - Place a corrupted `content.db`
  - Call `repairContentDatabase()`
  - Assert `content.db` is now valid

### T18: Create MockAssetBundle Test Helper

**File:** `test/helpers/mock_asset_bundle.dart`

- [ ] Create a test helper that serves a gzipped seed from memory:

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:sqlite3/sqlite3.dart';

/// A mock AssetBundle that serves a pre-built test seed.db.gz.
class MockAssetBundle extends CachingAssetBundle {
  MockAssetBundle(this._seedGzBytes);

  final Uint8List _seedGzBytes;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'assets/db/content.db.gz') {
      return ByteData.view(_seedGzBytes.buffer);
    }
    throw FlutterError('Asset not found: $key');
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    throw FlutterError('loadString not supported in MockAssetBundle');
  }
}

/// Creates a minimal gzipped SQLite database with a seed_metadata table.
Uint8List createTestSeedGz({required int version}) {
  final tempFile = File('${Directory.systemTemp.path}/test_seed_${DateTime.now().millisecondsSinceEpoch}.db');
  final db = sqlite3.open(tempFile.path);

  db.execute('''
    CREATE TABLE seed_metadata (
      id INTEGER PRIMARY KEY DEFAULT 1,
      version INTEGER NOT NULL,
      built_at TEXT NOT NULL,
      build_id TEXT NOT NULL,
      text_cache_count INTEGER NOT NULL,
      calendar_cycle_count INTEGER NOT NULL
    )
  ''');
  db.execute('''
    INSERT INTO seed_metadata (version, built_at, build_id, text_cache_count, calendar_cycle_count)
    VALUES ($version, '${DateTime.now().toUtc().toIso8601String()}', 'test', 0, 0)
  ''');
  db.dispose();

  final dbBytes = tempFile.readAsBytesSync();
  final gzBytes = gzip.encode(dbBytes);
  tempFile.deleteSync();

  return Uint8List.fromList(gzBytes);
}
```

### T19: Integration Test -- Startup Sequence

**File:** `test/core/database/seed_manager_integration_test.dart`

- [ ] **Test: Full startup flow -- first launch**
  - Create a temp dir, mock bundle, and SeedManager
  - Call `ensureContentDb()`
  - Open the returned path with a real `ContentDatabase`
  - Verify `seedMetadataDao.getVersion()` returns version 1
  - Close the database

- [ ] **Test: Full startup flow -- upgrade cycle**
  - First call with version 1 seed -> decompresses
  - Second call with same seed -> no-op (check file timestamp)
  - Third call with version 2 seed -> replaces
  - Fourth call with same v2 seed -> no-op

### T20: Wire Up Loading Indicator for Decompression (AC-10)

**Approach:** Since `SeedManager.ensureContentDb()` runs before `runApp()`, a traditional Flutter loading widget is not available. Two options:

**Option A (Recommended): Native splash screen stays visible during decompression**
- The existing `flutter_native_splash` (if present) or default white splash screen naturally covers the decompression period
- No additional code needed -- the splash is visible until `runApp()` mounts the first frame
- On repeat launches (no decompression), splash time is ~120ms total

**Option B (If explicit indicator needed): Two-phase runApp**
```dart
// Phase 1: Show loading indicator
runApp(const MaterialApp(home: _SeedLoadingScreen()));

// Phase 2: Run seed manager
final contentDbPath = await seedManager.ensureContentDb();

// Phase 3: Replace with real app
runApp(
  UncontrolledProviderScope(
    container: container,
    child: const LearningTrackerApp(),
  ),
);
```

- [ ] Determine which approach to use based on whether `flutter_native_splash` is configured
- [ ] If Option B is chosen, create a simple `_SeedLoadingScreen` widget with a `CircularProgressIndicator`
- [ ] Note: Do NOT show a loading screen on repeat launches where no decompression occurs (< 50ms)

## Dev Notes

### Architecture

**SeedManager** is a pure Dart service class (not a provider) that runs during the `main()` function before the Riverpod `ProviderContainer` is created. This is intentional:

1. It must complete before any content provider initializes
2. It performs file I/O that should not be lazy-loaded
3. It has no Riverpod dependencies itself (only needs a filesystem path and an asset bundle)

The result (a file path string) is injected into the Riverpod graph via `contentDbPathProvider.overrideWithValue(contentDbPath)`.

**Atomic replacement strategy:**

```
content.db (current, v1)
  |
  |- rename -> content.db.bak
  |
  |- decompress seed.db.gz -> content.db (new, v2)
  |
  |- verify new content.db (read SeedMetadata)
  |
  |- delete content.db.bak
  |
  DONE (or restore .bak on any failure)
```

This ensures:
- At every point in the flow, at least one valid `content.db` or `content.db.bak` exists
- If the app is killed mid-flow, `.bak` detection on next launch triggers recovery
- No window where neither file exists (except first launch, which has no fallback by definition)

### Startup Sequence (After This Story)

```
main()
  |
  1. WidgetsFlutterBinding.ensureInitialized()
  2. Firebase.initializeApp()          // still blocking pre-19.6
  3. GoogleSignIn.instance.initialize() // still blocking pre-19.6
  4. Logger init
  5. SeedManager.ensureContentDb()     // NEW -- blocks until content ready
  6. ProviderContainer(overrides: [contentDbPath])
  7. Notification init
  8. runApp()
```

After story 19.6 (Startup Sequence Hardening), steps 2, 3, and 7 move to post-`runApp()` background tasks. SeedManager remains in the critical path.

### Key Design Decisions

1. **Simple integer version comparison** -- No semver. `BUNDLED_SEED_VERSION > installedVersion` triggers replacement. This is intentional: the seed is a monolithic blob, not a library with backward-compatible changes.

2. **File replacement, not migration** -- ContentDatabase has `schemaVersion = 1` and no `onUpgrade`. Schema changes require a full seed rebuild + file replacement. This eliminates migration complexity for read-only content.

3. **Streaming decompression** -- `gzip.decoder` transform on a `Stream<List<int>>`, piped to a file sink. This avoids loading the entire ~200-300MB uncompressed database into memory. Critical for low-end devices.

4. **Raw SQL for version read** -- Opening a full Drift `ContentDatabase` just to read one integer is wasteful and triggers schema verification. Using raw SQLite access (`sqlite3.open()` or `NativeDatabase.select()`) is faster and avoids side effects.

5. **Constructor injection for testability** -- `SeedManager` takes `databaseDirectory` and `AssetBundle` as constructor params. Tests inject a temp directory and mock bundle. No static methods, no singletons.

### Project Structure Notes

```
lib/core/database/
  seed_manager.dart          # NEW -- SeedManager class + SeedManagerException
  seed_version.dart          # NEW -- BUNDLED_SEED_VERSION constant
  content/
    content_database.dart    # FROM 19.2 -- ContentDatabase Drift class
    content_database.g.dart  # FROM 19.2 -- generated
    daos/
      seed_metadata_dao.dart # FROM 19.2 -- read-only DAO

lib/core/providers/
  database_provider.dart     # MODIFIED -- add contentDbPathProvider

lib/core/presentation/
  content_db_error_app.dart  # NEW -- error UI for fatal seed failure

lib/main.dart                # MODIFIED -- add SeedManager call

assets/db/
  content.db.gz              # NEW -- compressed seed database (from 19.3 build tool)

tool/
  create_dev_seed.dart       # NEW -- placeholder seed for dev/testing

test/core/database/
  seed_manager_test.dart     # NEW -- unit tests
  seed_manager_integration_test.dart  # NEW -- integration tests

test/helpers/
  mock_asset_bundle.dart     # NEW -- test helper for mock seed bundles
```

### File Inventory

**New Files:**
| File | Purpose |
|------|---------|
| `lib/core/database/seed_manager.dart` | SeedManager class, SeedManagerException, all lifecycle logic |
| `lib/core/database/seed_version.dart` | `BUNDLED_SEED_VERSION` constant |
| `lib/core/presentation/content_db_error_app.dart` | Error UI for fatal first-launch failure |
| `tool/create_dev_seed.dart` | Dev helper to create placeholder seed.db.gz |
| `test/core/database/seed_manager_test.dart` | Unit tests for all SeedManager paths |
| `test/core/database/seed_manager_integration_test.dart` | Integration tests for startup flow |
| `test/helpers/mock_asset_bundle.dart` | MockAssetBundle + createTestSeedGz helper |

**Modified Files:**
| File | Change |
|------|--------|
| `lib/main.dart` | Add SeedManager call before ProviderContainer, add contentDbPath override, add error app fallback |
| `lib/core/providers/database_provider.dart` | Add `contentDbPathProvider` |
| `learning_tracker/pubspec.yaml` | Add `path_provider` to dependencies, add `assets/db/content.db.gz` to assets |

### Dependencies

| Dependency | Purpose | Status |
|------------|---------|--------|
| `dart:io` (gzip) | Streaming decompression | Built-in |
| `flutter/services.dart` (rootBundle) | Loading bundled asset | Built-in |
| `path_provider` | `getApplicationDocumentsDirectory()` | Add to pubspec.yaml (currently transitive only) |
| `drift/native.dart` (NativeDatabase) | Low-level SQLite access for version read | Already available via drift |
| `sqlite3` | Direct SQLite access (alternative to Drift for version read) | Transitive via drift_flutter |
| ContentDatabase (from 19.2) | Schema definition, SeedMetadata table | **Prerequisite** |
| SeedMetadata table (from 19.2) | Stores version, builtAt, buildId, counts | **Prerequisite** |

### Story Dependencies

- **Requires:** DNI-184 (19.2: Two-Database Split) -- ContentDatabase class and SeedMetadata table must exist
- **Blocks:** DNI-193 (19.4: Local Calendar Engine) -- needs reliable Content DB available at runtime
- **Related to:** 19.3 (Seed Database Build Tool) -- produces the actual `content.db.gz` that SeedManager consumes
- **Related to:** 19.6 (Startup Sequence Hardening) -- will move SeedManager earlier in the startup path and defer Firebase/GoogleSignIn

### Critical Constraints

1. **SeedManager must NOT import `package:flutter` beyond `services.dart`** -- `rootBundle` is the one Flutter dependency needed for asset loading. All other logic is pure Dart.

2. **SeedManager must complete before contentDatabaseProvider initializes** -- Any content query that fires before `ensureContentDb()` returns will fail because the database file does not exist yet (or is mid-replacement).

3. **Never delete both content.db and content.db.bak simultaneously** -- The atomic replacement flow ensures one is always available (except first launch where neither exists initially).

4. **The .bak file is the source of truth for "interrupted upgrade"** -- If `.bak` exists, the previous upgrade did not complete. Always restore from `.bak` first, then retry.

5. **Do not use `File.copy()` for backup** -- Use `File.rename()` (which is `mv` under the hood, an atomic filesystem operation on the same volume). Copy is slower and not atomic.

6. **`BUNDLED_SEED_VERSION` must be manually updated** -- This constant is set by the build pipeline (19.3) when a new seed is committed. If a developer forgets to update it, the app will not detect the new seed. Consider adding a CI check that compares the constant to the version inside the committed `content.db.gz`.

7. **The `seed_metadata` table schema must match between SeedManager's raw SQL query and ContentDatabase's Drift definition** -- If the column name changes in the Drift table, the raw SQL in `_readInstalledVersion()` will break. Keep these in sync. Consider adding a compile-time or test-time assertion.

### References

- [Linear Issue DNI-208](https://linear.app/dniasoff/issue/DNI-208/192b-content-db-runtime-upgrade-flow)
- `_bmad-output/implementation-artifacts/19-2-two-database-split.md` -- ContentDatabase, SeedMetadata table definition
- `_bmad-output/implementation-artifacts/19-3-seed-database-build-tool.md` -- SeedManager runtime section (T9, T10), seed asset format
- `_bmad-output/implementation-artifacts/19-6-startup-sequence-hardening.md` -- Startup sequence integration (T5), contentDbPathProvider
- `_bmad-output/implementation-artifacts/seed-database-build-tool-design.md` -- Schema generation strategy, ContentDatabase class design
- `_bmad-output/planning-artifacts/offline-first-analysis-2026-03-27.md` -- Section 3.2 Upgrade Flow

## Acceptance Tests

```yaml
story_19_2b:
  - id: AT-19.2b.1
    title: "First launch decompresses seed to content.db"
    test: |
      Create SeedManager with empty temp directory and mock bundle serving valid seed.db.gz (version 1).
      Call ensureContentDb().
      Assert content.db exists in the temp directory.
      Open content.db, query seed_metadata, assert version == 1.
    covers: AC-1

  - id: AT-19.2b.2
    title: "App update with newer seed replaces content.db atomically"
    test: |
      Place content.db with seed_metadata.version = 1 in temp dir.
      Create mock bundle with seed.db.gz containing version = 2.
      Set BUNDLED_SEED_VERSION = 2.
      Call ensureContentDb().
      Assert content.db now has seed_metadata.version == 2.
      Assert content.db.bak does NOT exist (cleanup succeeded).
    covers: AC-2

  - id: AT-19.2b.3
    title: "Same-version seed skips with zero overhead"
    test: |
      Place content.db with version = 1 in temp dir.
      Set BUNDLED_SEED_VERSION = 1.
      Record content.db lastModified timestamp.
      Call ensureContentDb().
      Assert content.db lastModified is unchanged.
      Assert elapsed time < 100ms.
    covers: AC-3

  - id: AT-19.2b.4
    title: "Interrupted upgrade recovery via .bak detection"
    test: |
      Place content.db.bak (valid, version 1) in temp dir.
      Place content.db (empty/partial file, 0 bytes) in temp dir.
      Create mock bundle with seed.db.gz version 2.
      Set BUNDLED_SEED_VERSION = 2.
      Call ensureContentDb().
      Assert content.db.bak does NOT exist.
      Assert content.db is valid with version 2 (restored from bak, then upgraded).
    covers: AC-4

  - id: AT-19.2b.5
    title: "Corrupted seed falls back to existing content.db"
    test: |
      Place valid content.db with version 1 in temp dir.
      Create mock bundle with INVALID seed.db.gz (random bytes).
      Set BUNDLED_SEED_VERSION = 2 (to trigger upgrade attempt).
      Call ensureContentDb().
      Assert content.db still has version 1 (fallback to backup).
      Assert no SeedManagerException thrown.
    covers: AC-5

  - id: AT-19.2b.6
    title: "No content.db AND corrupted seed throws SeedManagerException"
    test: |
      Use empty temp dir (no content.db).
      Create mock bundle with INVALID seed.db.gz (random bytes).
      Call ensureContentDb().
      Assert SeedManagerException is thrown.
      Assert exception message contains actionable text.
    covers: AC-6

  - id: AT-19.2b.7
    title: "Decompression uses streaming (bounded memory)"
    test: |
      Create mock bundle with valid seed.db.gz.
      Call ensureContentDb().
      Assert content.db file size > 0.
      (Manual verification: inspect _decompressSeed code uses Stream.transform(gzip.decoder).pipe()
       rather than gzip.decode() on full bytes).
    covers: AC-7

  - id: AT-19.2b.8
    title: "Version comparison reads SeedMetadata correctly"
    test: |
      Create content.db with seed_metadata row: id=1, version=5.
      Create SeedManager.
      Call _readInstalledVersion() (or test via ensureContentDb behavior).
      Set BUNDLED_SEED_VERSION = 5 -> assert no replacement.
      Set BUNDLED_SEED_VERSION = 6 -> assert replacement triggered.
      Set BUNDLED_SEED_VERSION = 4 -> assert no replacement (bundled older).
    covers: AC-9

  - id: AT-19.2b.9
    title: "repairContentDatabase() force re-decompresses"
    test: |
      Write random bytes to content.db path (corrupted).
      Create mock bundle with valid seed.db.gz.
      Call repairContentDatabase().
      Assert content.db is now valid with correct version.
    covers: AC-1, AC-6

  - id: AT-19.2b.10
    title: "Corrupted content.db (unreadable version) triggers re-decompress"
    test: |
      Write random bytes to content.db path.
      Create mock bundle with valid seed.db.gz (version 1).
      Call ensureContentDb().
      Assert content.db is now valid with version 1.
    covers: AC-9

  - id: AT-19.2b.11
    title: "contentDbPathProvider throws if not overridden"
    test: |
      Create a ProviderContainer with no overrides.
      Attempt to read contentDbPathProvider.
      Assert UnimplementedError is thrown.
    covers: AC-8
```

## Dev Agent Record

### Agent Model Used

_To be filled during implementation_

### Debug Log References

### Completion Notes List

### File List
