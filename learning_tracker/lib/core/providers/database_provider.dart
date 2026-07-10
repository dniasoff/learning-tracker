import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/seed_manager.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:path_provider/path_provider.dart';
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
/// Resolves the path by running [SeedManager.ensureContentDb] in the
/// background — decompresses the asset on first launch, no-ops on subsequent
/// launches. Runs independently of [runApp] so the UI is not blocked during
/// cold start (see bootstrap.dart).
///
/// Tests override [contentDatabaseProvider] directly with an in-memory DB and
/// never need to override this provider.
@Riverpod(keepAlive: true)
Future<String> contentDbPath(Ref ref) async {
  final docsDir = await getApplicationDocumentsDirectory();
  final seedManager = SeedManager(
    dbDirectory: docsDir.path,
    logger: AppLogger.instance,
  );
  return seedManager.ensureContentDb();
}

/// Content database — read-only, bundled seed content.
///
/// Awaits [contentDbPathProvider] so extraction completes before the database
/// is opened. The first read after a fresh install/clear will suspend until
/// seeding finishes; subsequent launches return immediately (already extracted).
///
/// Tests typically override this with an in-memory database via
/// `createTestContentDatabase()` instead of relying on [contentDbPath].
@Riverpod(keepAlive: true)
Future<ContentDatabase> contentDatabase(Ref ref) async {
  final path = await ref.watch(contentDbPathProvider.future);
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
