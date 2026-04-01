/// Test database helper for creating in-memory Drift databases
/// No file I/O, fast test execution, clean teardown
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

/// Creates an in-memory test UserDatabase
UserDatabase createTestDatabase() {
  return UserDatabase(NativeDatabase.memory());
}

/// Creates an in-memory test UserDatabase (explicit name)
UserDatabase createTestUserDatabase() {
  return UserDatabase(NativeDatabase.memory());
}

/// Creates an in-memory test ContentDatabase
ContentDatabase createTestContentDatabase() {
  return ContentDatabase(NativeDatabase.memory());
}

/// Creates an in-memory test database with custom executor
UserDatabase createTestDatabaseWithExecutor(QueryExecutor executor) {
  return UserDatabase(executor);
}

/// Helper for batch inserting test data
///
/// Wraps insertions in a transaction for speed.
Future<void> batchInsert<T extends Table, D extends DataClass>(
  UserDatabase db,
  TableInfo<T, D> table,
  List<Insertable<D>> rows,
) async {
  await db.transaction(() async {
    for (final row in rows) {
      await db.into(table).insert(row);
    }
  });
}
