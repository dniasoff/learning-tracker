/// In-memory Drift database helper (DNI-377 / 27.1).
///
/// Provides a single entry point — [inMemoryDb] — that returns a fresh
/// `UserDatabase` backed by `NativeDatabase.memory()` at the current
/// `schemaVersion`. Each call returns an independent instance: tests can
/// hold two databases side-by-side without state bleeding across them.
///
/// Prefer this helper over the older `createTestDatabase()` in
/// `test_database.dart` — it documents the schema-version contract and is
/// the canonical entry point for integration tests landing in DNI-27.5
/// through 27.9.
library;

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

/// Inserts a single test completion via the canonical event log (C1 / v20).
///
/// Accepts a [CompletionsCompanion] so existing test setup code keeps the
/// same companion-construction syntax; `trackId` and `completedAt` are
/// mapped to [CompletionEventsCompanion] fields.
Future<int> seedCompletion(UserDatabase db, CompletionsCompanion c) =>
    db.completionEventDao.appendEvent(
      CompletionEventsCompanion.insert(
        profileId: c.profileId.value,
        curriculumId: c.curriculumId.value,
        sefariaRef: c.sefariaRef.value,
        stageId: c.stageId.value,
        trackType: c.trackType.value,
        trackId: c.trackId.present
            ? Value<int?>(c.trackId.value)
            : const Value<int?>.absent(),
        points: c.points.present ? Value(c.points.value) : const Value(0),
        eventTimestamp: c.completedAt.present
            ? c.completedAt.value
            : DateTime.utc(2026, 1, 1),
      ),
    );

/// Inserts multiple test completions via the canonical event log.
Future<void> seedCompletionsBatch(
  UserDatabase db,
  List<CompletionsCompanion> entries,
) async {
  for (final c in entries) {
    await seedCompletion(db, c);
  }
}

/// Returns a brand-new `UserDatabase` whose backing store lives only in
/// process memory. The migration runner executes synchronously on first
/// query, materialising the current `schemaVersion` schema.
///
/// Callers MUST `await db.close()` in `tearDown` to free the native
/// resources.
UserDatabase inMemoryDb() => UserDatabase(NativeDatabase.memory());

/// Seeds a minimal account + learner profile (id = 1) into [db].
///
/// Required by any test that inserts rows into tables with a `profileId`
/// FK referencing `learner_profiles(id)` (e.g. completions,
/// completion_events, streak_events). Call this at the top of each such
/// test or in setUp before any FK-constrained insert.
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
