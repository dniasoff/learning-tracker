/// Test database helper for creating in-memory Drift databases
/// No file I/O, fast test execution, clean teardown
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

// AUD-t-cross-12: seedProfile/seedProfileZero used to be redefined here
// byte-for-byte identically to drift_memory.dart's versions.
// drift_memory.dart's own doc comment already names itself canonical — this
// re-export keeps both files' public surface unchanged (callers that only
// import test_database.dart keep working unqualified) while there being
// exactly one definition. Since both `import`-paths now resolve to the SAME
// declaration, importing drift_memory.dart and test_database.dart together
// (as ~23 test files do) no longer triggers Dart's ambiguous-import error on
// these two names, so the show/hide combinators those files used purely to
// dodge that collision are no longer needed.
export 'drift_memory.dart' show seedProfile, seedProfileZero;

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

/// Seeds an account + learner profile with explicit [accountId] and
/// [profileId] into [db].
///
/// Used by navigation/guard tests that hard-code `getSelectedProfileId()` /
/// `getAccountId()` to a specific id — the ProfileGuard validates the selected
/// id exists in the current DB (R1o-C2), so the seeded profile must carry the
/// matching id.
Future<void> seedProfileWithIds(
  UserDatabase db, {
  required int accountId,
  required int profileId,
  String mode = 'adult',
}) async {
  await db
      .into(db.accounts)
      .insert(
        AccountsCompanion(
          id: Value(accountId),
          email: Value('test$accountId@example.com'),
          tier: const Value('localBorn'),
          displayName: const Value('Test User'),
          createdAt: Value(DateTimeFactory.nowUtc()),
          updatedAt: Value(DateTimeFactory.nowUtc()),
        ),
      );
  await db
      .into(db.learnerProfiles)
      .insert(
        LearnerProfilesCompanion(
          id: Value(profileId),
          accountId: Value(accountId),
          displayName: const Value('Test User'),
          mode: Value(mode),
          createdAt: Value(DateTimeFactory.nowUtc()),
          updatedAt: Value(DateTimeFactory.nowUtc()),
          // T-45 / P2-19: P2-2's eager-mint policy means a real seeded
          // profile always has a ulid; a null one now hard-throws out of
          // `ProfileModel.fromDriftRow` (P2-3). Derived from [profileId] so
          // callers seeding more than one profile per test (e.g.
          // `stage_definition_repository_impl_26_26_test.dart`) still get
          // distinct, meaningful ulids per profile rather than a shared
          // literal — mirrors `seedProfile`/`seedProfileZero`
          // (`drift_memory.dart`), which carry the equivalent fixed
          // literals for the same reason (T-41).
          ulid: Value('ulid-seed-profile-$profileId'),
        ),
      );
}

/// Seeds a minimal account (no profile) into [db] and returns the account id.
///
/// Use when tests need an account row for FK purposes but manage their own
/// profiles (e.g. multi-profile tests that count profiles from 0).
Future<int> seedAccount(UserDatabase db) async {
  return db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: 'test@example.com',
          tier: 'localBorn',
          displayName: 'Test User',
          createdAt: DateTimeFactory.nowUtc(),
          updatedAt: DateTimeFactory.nowUtc(),
        ),
      );
}

/// Seeds a second account (id auto-assigned) for multi-account tests.
Future<int> seedAccount2(UserDatabase db) async {
  return db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: 'test2@example.com',
          tier: 'localBorn',
          displayName: 'Test User 2',
          createdAt: DateTimeFactory.nowUtc(),
          updatedAt: DateTimeFactory.nowUtc(),
        ),
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
