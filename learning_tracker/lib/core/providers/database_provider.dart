import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_provider.g.dart';

/// Active account's DB file name — a mutable notifier so sign-in/signup
/// flows can swap accounts without a global side-effect.
///
/// Bootstrapped in `main.dart` via a [ProviderScope] override with the
/// value resolved by [bootstrapAccount]. Defaults to `'learning_tracker'`
/// so tests and fresh installs work without an override.
///
/// When the notifier's state changes, [userDatabaseProvider] rebuilds
/// automatically and opens the new database file.
@Riverpod(keepAlive: true)
class AccountDbFileName extends _$AccountDbFileName {
  @override
  String build() => 'learning_tracker';

  /// Swap to a different account's database file.
  void setFileName(String name) => state = name;
}

/// User database — read-write, scoped to the active account.
///
/// Watches [accountDbFileNameProvider] so the database is automatically
/// swapped when a new account is selected during sign-in or sign-up.
@Riverpod(keepAlive: true)
UserDatabase userDatabase(Ref ref) {
  final dbName = ref.watch(accountDbFileNameProvider);
  final database = UserDatabase(driftDatabase(name: dbName));
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
