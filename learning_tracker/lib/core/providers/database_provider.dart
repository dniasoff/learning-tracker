import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_provider.g.dart';

/// User database — read-write, all user data.
@Riverpod(keepAlive: true)
UserDatabase userDatabase(Ref ref) {
  final database = UserDatabase(driftDatabase(name: 'learning_tracker'));
  ref.onDispose(database.close);
  return database;
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
