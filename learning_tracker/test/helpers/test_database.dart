/// Test database helper for creating in-memory Drift databases
/// No file I/O, fast test execution, clean teardown
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

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

/// Seeds a minimal account + learner profile into [db].
///
/// Required before any FK-constrained insert into completions,
/// completion_events, streak_events, etc.
Future<void> seedProfile(UserDatabase db) async {
  final accountId = await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: 'test@example.com',
          tier: 'localBorn',
          displayName: 'Test User',
          userMode: 'adult',
          createdAt: DateTimeFactory.nowUtc(),
          updatedAt: DateTimeFactory.nowUtc(),
        ),
      );
  await db
      .into(db.learnerProfiles)
      .insert(
        LearnerProfilesCompanion.insert(
          accountId: accountId,
          displayName: 'Test User',
          mode: 'adult',
          createdAt: DateTimeFactory.nowUtc(),
          updatedAt: DateTimeFactory.nowUtc(),
        ),
      );
}

/// Seeds a learner profile with id = 0 into [db].
///
/// Required by code that hardcodes profileId = 0 (e.g.
/// [StageDefinitionRepositoryImpl.initializeDefaults] — DNI-322). Call
/// this alongside [seedProfile] in any setUp that exercises such code.
Future<void> seedProfileZero(UserDatabase db) async {
  await db
      .into(db.accounts)
      .insert(
        AccountsCompanion(
          id: const Value(0),
          email: const Value('test0@example.com'),
          tier: const Value('localBorn'),
          displayName: const Value('Test User 0'),
          userMode: const Value('adult'),
          createdAt: Value(DateTimeFactory.nowUtc()),
          updatedAt: Value(DateTimeFactory.nowUtc()),
        ),
        mode: InsertMode.insertOrIgnore,
      );
  await db
      .into(db.learnerProfiles)
      .insert(
        LearnerProfilesCompanion(
          id: const Value(0),
          accountId: const Value(0),
          displayName: const Value('Test User 0'),
          mode: const Value('adult'),
          createdAt: Value(DateTimeFactory.nowUtc()),
          updatedAt: Value(DateTimeFactory.nowUtc()),
        ),
        mode: InsertMode.insertOrIgnore,
      );
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
