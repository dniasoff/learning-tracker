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

/// Inserts a single test completion via the canonical event log.
///
/// NOTE (W3.20): The `completions` legacy table was dropped. This helper
/// now works directly with [CompletionEventsCompanion].
Future<int> seedCompletion(UserDatabase db, CompletionEventsCompanion c) =>
    db.completionEventDao.appendEvent(c);

/// Inserts multiple test completions via the canonical event log.
Future<void> seedCompletionsBatch(
  UserDatabase db,
  List<CompletionEventsCompanion> entries,
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

/// Seeds a minimal curriculum track row for [profileId] + [curriculumId].
///
/// Replaces the old pattern of constructing [CurriculumTracksCompanion.insert]
/// inline in each test. W3.22/W3.28 removed `trackType` and replaced
/// `isActive`/`deletedAt` with `state`+`stateChangedAt`.
///
/// Returns the newly inserted track id.
Future<int> seedTrack(
  UserDatabase db, {
  required int profileId,
  String curriculumId = 'mishnayos',
  DateTime? activatedAt,
}) async {
  return db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          stateChangedAt: activatedAt ?? DateTimeFactory.nowUtc(),
          activatedAt: activatedAt ?? DateTimeFactory.nowUtc(),
        ),
      );
}

/// Deletes every row from every user-scoped table in [db], in one
/// transaction, with exactly one delete call per table.
///
/// Intended for round-trip tests that need to prove import restores state
/// from a clean slate (e.g. export → wipe → import → compare). Centralising
/// the wipe sequence here means a newly added table only needs updating in
/// one place, instead of drifting across independently copy-pasted blocks
/// (AUD-t-story-acceptance-29).
Future<void> wipeAllUserTables(UserDatabase db) => db.transaction(() async {
  await db.delete(db.streakEvents).go();
  await db.delete(db.completionEvents).go();
  await db.delete(db.learningLedger).go();
  await db.delete(db.dailyPlans).go();
  await db.delete(db.trackLearningOrder).go();
  await db.delete(db.learningOrder).go();
  await db.delete(db.bookmarks).go();
  await db.delete(db.goals).go();
  await db.delete(db.studyDayConfigs).go();
  await db.delete(db.pointConfigs).go();
  await db.delete(db.stageDefinitions).go();
  await db.delete(db.profilePrograms).go();
  await db.delete(db.curriculumScopes).go();
  await db.delete(db.curriculumTracks).go();
  await db.delete(db.learnerProfiles).go();
  await db.delete(db.accounts).go();
});

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
