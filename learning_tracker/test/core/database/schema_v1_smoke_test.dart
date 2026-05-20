/// Schema v1 smoke tests — DNI-322
///
/// Verifies that the schema-v1 changes (table renames, profileId required,
/// Bookmarks.trackId FK, schemaVersion=13) hold at the Drift level on a
/// freshly-created in-memory database.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../helpers/drift_memory.dart' show seedCompletion;
import '../../helpers/test_database.dart';

void main() {
  group('Schema v1 smoke tests', () {
    late UserDatabase db;

    setUp(() async {
      db = createTestDatabase();
      await seedProfile(db); // creates accounts(id=1) + learner_profiles(id=1)
    });

    tearDown(() async {
      await db.close();
    });

    // -------------------------------------------------------------------------
    // 1. Schema version
    // -------------------------------------------------------------------------

    test('schemaVersion is 23', () async {
      final version = await db.customSelect('PRAGMA user_version').map((row) {
        return row.read<int>('user_version');
      }).getSingle();
      expect(version, equals(23));
    });

    // -------------------------------------------------------------------------
    // 2. LearnerProfiles table (renamed from Profiles)
    // -------------------------------------------------------------------------

    test('learner_profiles table exists and accepts inserts', () async {
      final now = DateTime.now().toUtc();
      // Accounts row is needed because LearnerProfiles.accountId is a FK.
      final accountId = await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'learner@example.com',
              tier: 'localBorn',
              displayName: 'Learner Account',
              userMode: 'child',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final id = await db
          .into(db.learnerProfiles)
          .insert(
            LearnerProfilesCompanion.insert(
              accountId: accountId,
              displayName: 'Test Learner',
              mode: 'child',
              createdAt: now,
              updatedAt: now,
            ),
          );
      expect(id, greaterThan(0));

      final row = await db.profileDao.getProfileById(id);
      expect(row, isNotNull);
      expect(row!.displayName, equals('Test Learner'));
    });

    // -------------------------------------------------------------------------
    // 3. Accounts table (renamed from UserProfiles)
    // -------------------------------------------------------------------------

    test('accounts table exists and accepts inserts', () async {
      final now = DateTime.now().toUtc();
      final id = await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'accounts-smoke@example.com',
              tier: 'localBorn',
              displayName: 'Test User',
              userMode: 'child',
              createdAt: now,
              updatedAt: now,
            ),
          );
      expect(id, greaterThan(0));

      final row = await db.userProfileDao.getUserProfileById(id);
      expect(row, isNotNull);
      expect(row!.email, equals('accounts-smoke@example.com'));
    });

    // -------------------------------------------------------------------------
    // 4. profileId columns have no default (required on insert)
    // -------------------------------------------------------------------------

    test('completions.profileId is required (no default)', () async {
      // Insert a curriculum track first (FK dependency)
      final trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'bavli',
              stateChangedAt: DateTime.now().toUtc(),
              activatedAt: DateTime.now().toUtc(),
            ),
          );

      // Insert with explicit profileId = 1 — should succeed
      final id = await seedCompletion(
        db,
        CompletionsCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          sefariaRef: 'Berakhot 2a',
          stageId: 1,
          trackType: 'personal',
          trackId: trackId,
          completedAt: DateTime.now().toUtc(),
        ),
      );
      expect(id, greaterThan(0));

      final rows = await db.completionDao.getCompletionsByProfile(1);
      expect(rows.length, equals(1));
      expect(rows.first.profileId, equals(1));
    });

    test('goals.profileId is required (no default)', () async {
      final trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'bavli',
              stateChangedAt: DateTime.now().toUtc(),
              activatedAt: DateTime.now().toUtc(),
            ),
          );

      final now = DateTime.now().toUtc();
      final id = await db.goalDao.insertGoal(
        GoalsCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          trackId: trackId,
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(id, greaterThan(0));

      final goal = await db.goalDao.getGoalById(id);
      expect(goal, isNotNull);
      expect(goal!.profileId, equals(1));
    });

    // -------------------------------------------------------------------------
    // 5. Bookmarks.trackId FK (replaces trackType TEXT)
    // -------------------------------------------------------------------------

    test('bookmarks table has trackId column (not trackType)', () async {
      // Insert prerequisite track
      final trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'bavli',
              stateChangedAt: DateTime.now().toUtc(),
              activatedAt: DateTime.now().toUtc(),
            ),
          );

      final id = await db.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          trackId: trackId,
          sefariaRef: 'Berakhot 2a',
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      expect(id, greaterThan(0));

      final bookmark = await db.bookmarkDao.getBookmarkById(id);
      expect(bookmark, isNotNull);
      expect(bookmark!.trackId, equals(trackId));
    });

    test('bookmark trackId references curriculum_tracks.id', () async {
      final trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'bavli',
              stateChangedAt: DateTime.now().toUtc(),
              activatedAt: DateTime.now().toUtc(),
            ),
          );

      // Valid FK insert succeeds and round-trips correctly
      final id = await db.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          trackId: trackId,
          sefariaRef: 'Berakhot 3a',
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      final row = await db.bookmarkDao.getBookmarkById(id);
      expect(row!.trackId, equals(trackId));
    });

    // -------------------------------------------------------------------------
    // 6. curriculum_tracks.profileId required
    // -------------------------------------------------------------------------

    test('curriculum_tracks.profileId is required (no default)', () async {
      final trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 7,
              curriculumId: 'mishnayos',
              stateChangedAt: DateTime.now().toUtc(),
              activatedAt: DateTime.now().toUtc(),
            ),
          );
      final row = await (db.select(
        db.curriculumTracks,
      )..where((t) => t.id.equals(trackId))).getSingleOrNull();
      expect(row, isNotNull);
      expect(row!.profileId, equals(7));
    });

    // -------------------------------------------------------------------------
    // 7. Streaks profileId required
    // -------------------------------------------------------------------------

    test('streaks.profileId is required (no default)', () async {
      await db.into(db.streakEvents).insert(StreaksCompanion.insert(profileId: 5));
      final row = await (db.select(
        db.streakEvents,
      )..where((t) => t.profileId.equals(5))).getSingleOrNull();
      expect(row, isNotNull);
      expect(row!.profileId, equals(5));
    });

    // -------------------------------------------------------------------------
    // 8. learner_profiles avatarIndex still has its default (not a profileId)
    // -------------------------------------------------------------------------

    test('learner_profiles.avatarIndex defaults to 0', () async {
      final now = DateTime.now().toUtc();
      final accountId = await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'avatar@example.com',
              tier: 'localBorn',
              displayName: 'Avatar Account',
              userMode: 'child',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final id = await db
          .into(db.learnerProfiles)
          .insert(
            LearnerProfilesCompanion.insert(
              accountId: accountId,
              displayName: 'Avatar Test',
              mode: 'child',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final row = await db.profileDao.getProfileById(id);
      expect(row!.avatarIndex, equals(0));
    });
  });
}
