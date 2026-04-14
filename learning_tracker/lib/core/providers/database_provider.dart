import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'database_provider.g.dart';

/// User database — read-write, scoped to the active account.
///
/// Epic 21: reads `lastActiveAccountId` from SharedPreferences (fast)
/// or the device registry, then opens that account's DB file
/// (`user_acc_{id}.db`). When the active account changes, this
/// provider invalidates and the entire downstream tree rebuilds
/// with the new account's data.
///
/// Falls back to the legacy single-file `learning_tracker.db` name
/// when no registry exists yet (fresh install before first signup,
/// or tests that override this provider).
@Riverpod(keepAlive: true)
UserDatabase userDatabase(Ref ref) {
  final registry = ref.watch(deviceRegistryProvider);

  // Fast path: read SharedPreferences for the active account ID
  // (available before Drift fully initialises on a cold start).
  final dbName = _resolveDbName(registry);

  final database = UserDatabase(driftDatabase(name: dbName));
  ref.onDispose(database.close);
  return database;
}

/// Resolve which database file to open.
///
/// 1. Look up lastActiveAccountId in the registry.
/// 2. If found, use that account's `dbFileName`.
/// 3. If not found (fresh install / tests), fall back to the
///    legacy name so existing tests and first-run still work.
String _resolveDbName(DeviceRegistryDatabase registry) {
  // Synchronous read isn't possible with Drift futures, so we
  // rely on SharedPreferences which IS synchronous-ish after
  // getInstance(). The registry provider is keepAlive, so it's
  // already open by the time this runs.
  //
  // The actual async resolution of the active account happens in
  // AuthStateNotifier._init() (story 21.3). Here we just need
  // the file name to open, and SharedPreferences gives us the
  // accountId fast enough.
  //
  // For the MVP: return the legacy name. Story 21.3 will wire
  // the full SharedPreferences → registry → dbFileName chain.
  // This keeps every existing test and the current single-account
  // flow working while the multi-account infrastructure lands.
  return 'learning_tracker';
}

/// Filesystem path for the bundled content database.
///
/// Overridden in `main.dart` with the path resolved by `SeedManager`
/// (Story 19.2b T13). Tests leave this unset and rely on the content
/// provider override with an in-memory database.
@Riverpod(keepAlive: true)
String contentDbPath(Ref ref) {
  throw UnimplementedError(
    'contentDbPathProvider must be overridden before any content lookup. '
    'main.dart calls SeedManager.ensureContentDb() at startup and provides '
    'the resolved path via ProviderScope overrides.',
  );
}

/// Content database — read-only, bundled seed content.
///
/// Opens the content.db file prepared by [SeedManager] at startup with
/// `PRAGMA query_only = ON` enforced at the SQLite level (Story 19.3 AC-10).
/// Tests typically override this with an in-memory database via
/// `createTestContentDatabase()` instead of relying on [contentDbPath].
@Riverpod(keepAlive: true)
ContentDatabase contentDatabase(Ref ref) {
  final path = ref.watch(contentDbPathProvider);
  final database = ContentDatabase.openReadOnly(File(path));
  ref.onDispose(database.close);
  return database;
}

/// Legacy alias — will be removed after full migration.
/// DO NOT use in new code.
@Deprecated('Use userDatabaseProvider or contentDatabaseProvider instead')
@Riverpod(keepAlive: true)
UserDatabase appDatabase(Ref ref) {
  return ref.watch(userDatabaseProvider);
}
