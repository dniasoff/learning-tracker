/// Test database helper for creating in-memory Drift databases
/// No file I/O, fast test execution, clean teardown
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/app_database.dart';

/// Creates an in-memory test database
///
/// Usage:
/// ```dart
/// late AppDatabase db;
///
/// setUp(() {
///   db = createTestDatabase();
/// });
///
/// tearDown(() async {
///   await db.close();
/// });
/// ```
AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

/// Creates an in-memory test database with custom executor
///
/// Useful for testing database migrations or custom configurations.
AppDatabase createTestDatabaseWithExecutor(QueryExecutor executor) {
  return AppDatabase(executor);
}

/// Helper for batch inserting test data
///
/// Wraps insertions in a transaction for speed.
Future<void> batchInsert<T extends Table, D extends DataClass>(
  AppDatabase db,
  TableInfo<T, D> table,
  List<Insertable<D>> rows,
) async {
  await db.transaction(() async {
    for (final row in rows) {
      await db.into(table).insert(row);
    }
  });
}
