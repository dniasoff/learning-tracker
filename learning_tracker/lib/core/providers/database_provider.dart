import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_provider.g.dart';

/// User database — read-write, scoped to the active account.
///
/// Epic 21: [activeDbFileName] is resolved at startup by
/// [SessionPersistenceService] and set before the provider tree
/// builds. Defaults to the legacy `learning_tracker` name so
/// tests and fresh installs work without a registry.
@Riverpod(keepAlive: true)
UserDatabase userDatabase(Ref ref) {
  final database = UserDatabase(driftDatabase(name: activeDbFileName));
  ref.onDispose(database.close);
  return database;
}

/// The active account's DB file name, set by
/// [SessionPersistenceService] or [AuthStateNotifier] before the
/// provider tree builds. Defaults to the legacy single-file name
/// so tests and fresh installs work without a registry.
///
/// This is a simple global because the provider must resolve
/// synchronously — Drift's `driftDatabase(name:)` doesn't accept
/// a Future. The async resolution happens in `main.dart` at
/// startup (or in tests via provider overrides).
String activeDbFileName = 'learning_tracker';

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
