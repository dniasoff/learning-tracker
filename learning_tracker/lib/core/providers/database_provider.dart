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

/// Content database — read-only, bundled content.
///
/// In production, this opens a pre-built seed file. In tests, it uses
/// an in-memory database. The seed file is managed by SeedManager.
@Riverpod(keepAlive: true)
ContentDatabase contentDatabase(Ref ref) {
  final database = ContentDatabase(
    driftDatabase(name: 'content'),
  );
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
