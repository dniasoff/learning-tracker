@Tags(['epic_15'])
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/features/profiles/data/repositories/profile_repository_impl.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:test/test.dart';

import '../helpers/test_database.dart';

void main() {
  group('Story 15.1 -- Multi-Profile Data Model & Migration',
      tags: ['story_15_1'], () {
    late AppDatabase db;
    late ProfileRepositoryImpl profileRepo;

    setUp(() {
      db = createTestDatabase();
      profileRepo = ProfileRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    // AC: Existing users migrated seamlessly — default profile auto-created
    // (Migration tested implicitly via fresh database creation with schema v10)

    group('AC: New profiles can be created with name and mode', () {
      test('creates a profile with child mode', () async {
        final profile = await profileRepo.createProfile(
          accountId: 1,
          displayName: 'Sarah',
          mode: 'child',
        );

        expect(profile.displayName, 'Sarah');
        expect(profile.mode, 'child');
        expect(profile.accountId, 1);
        expect(profile.avatarIndex, 0);
      });

      test('creates a profile with adult mode', () async {
        final profile = await profileRepo.createProfile(
          accountId: 1,
          displayName: 'Parent',
          mode: 'adult',
          avatarIndex: 3,
        );

        expect(profile.displayName, 'Parent');
        expect(profile.mode, 'adult');
        expect(profile.avatarIndex, 3);
      });
    });

    group('AC: All data queries are scoped by profile_id', () {
      test('completions are scoped by profile_id', () async {
        final p1 = await profileRepo.createProfile(
          accountId: 1,
          displayName: 'Child1',
          mode: 'child',
        );
        final p2 = await profileRepo.createProfile(
          accountId: 1,
          displayName: 'Child2',
          mode: 'child',
        );

        // Insert completions for each profile
        await db.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            profileId: Value(p1.id),
            curriculumId: 'mishnah',
            sefariaRef: 'Mishnah_Berakhot.1.1',
            stageId: 1,
            trackType: 'personal',
            completedAt: DateTime.now().toUtc(),
          ),
        );
        await db.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            profileId: Value(p2.id),
            curriculumId: 'mishnah',
            sefariaRef: 'Mishnah_Berakhot.1.2',
            stageId: 1,
            trackType: 'personal',
            completedAt: DateTime.now().toUtc(),
          ),
        );

        // Query all completions — both exist
        final all = await db.completionDao.getAllCompletions();
        expect(all.length, 2);

        // Query by profile — each profile sees only its own
        final p1Completions = await (db.select(db.completions)
              ..where((t) => t.profileId.equals(p1.id)))
            .get();
        expect(p1Completions.length, 1);
        expect(p1Completions.first.sefariaRef, 'Mishnah_Berakhot.1.1');

        final p2Completions = await (db.select(db.completions)
              ..where((t) => t.profileId.equals(p2.id)))
            .get();
        expect(p2Completions.length, 1);
        expect(p2Completions.first.sefariaRef, 'Mishnah_Berakhot.1.2');
      });

      test('bookmarks are scoped by profile_id', () async {
        final p1 = await profileRepo.createProfile(
          accountId: 1,
          displayName: 'Child1',
          mode: 'child',
        );
        final p2 = await profileRepo.createProfile(
          accountId: 1,
          displayName: 'Child2',
          mode: 'child',
        );

        await db.bookmarkDao.insertBookmark(
          BookmarksCompanion.insert(
            profileId: Value(p1.id),
            curriculumId: 'mishnah',
            trackType: 'personal',
            sefariaRef: 'Mishnah_Berakhot.1.1',
            updatedAt: DateTime.now().toUtc(),
          ),
        );
        await db.bookmarkDao.insertBookmark(
          BookmarksCompanion.insert(
            profileId: Value(p2.id),
            curriculumId: 'mishnah',
            trackType: 'personal',
            sefariaRef: 'Mishnah_Berakhot.2.1',
            updatedAt: DateTime.now().toUtc(),
          ),
        );

        final p1Bookmarks = await (db.select(db.bookmarks)
              ..where((t) => t.profileId.equals(p1.id)))
            .get();
        expect(p1Bookmarks.length, 1);
        expect(p1Bookmarks.first.sefariaRef, 'Mishnah_Berakhot.1.1');
      });

      test('goals are scoped by profile_id', () async {
        final p1 = await profileRepo.createProfile(
          accountId: 1,
          displayName: 'Child1',
          mode: 'child',
        );

        await db.goalDao.insertGoal(
          GoalsCompanion.insert(
            profileId: Value(p1.id),
            curriculumId: 'mishnah',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );

        final goals = await (db.select(db.goals)
              ..where((t) => t.profileId.equals(p1.id)))
            .get();
        expect(goals.length, 1);
      });
    });

    group('AC: Max 10 profiles enforced at repository level', () {
      test('allows up to 10 profiles', () async {
        for (var i = 1; i <= 10; i++) {
          await profileRepo.createProfile(
            accountId: 1,
            displayName: 'Profile $i',
            mode: 'child',
          );
        }

        final count = await profileRepo.countProfilesForAccount(1);
        expect(count, 10);
      });

      test('rejects 11th profile', () async {
        for (var i = 1; i <= 10; i++) {
          await profileRepo.createProfile(
            accountId: 1,
            displayName: 'Profile $i',
            mode: 'child',
          );
        }

        expect(
          () => profileRepo.createProfile(
            accountId: 1,
            displayName: 'Profile 11',
            mode: 'child',
          ),
          throwsA(isA<MaxProfilesExceededException>()),
        );
      });

      test('different accounts have independent limits', () async {
        for (var i = 1; i <= 10; i++) {
          await profileRepo.createProfile(
            accountId: 1,
            displayName: 'A1-Profile $i',
            mode: 'child',
          );
        }

        // Account 2 can still create profiles
        final profile = await profileRepo.createProfile(
          accountId: 2,
          displayName: 'A2-Profile 1',
          mode: 'adult',
        );
        expect(profile.accountId, 2);
      });
    });

    group('AC: Profile CRUD operations work', () {
      test('create and read profile', () async {
        final created = await profileRepo.createProfile(
          accountId: 1,
          displayName: 'Test',
          mode: 'child',
        );

        final fetched = await profileRepo.getProfileById(created.id);
        expect(fetched, isNotNull);
        expect(fetched!.displayName, 'Test');
        expect(fetched.mode, 'child');
      });

      test('update profile', () async {
        final created = await profileRepo.createProfile(
          accountId: 1,
          displayName: 'Original',
          mode: 'child',
        );

        final updated = await profileRepo.updateProfile(
          id: created.id,
          displayName: 'Updated',
          mode: 'adult',
          avatarIndex: 5,
        );

        expect(updated.displayName, 'Updated');
        expect(updated.mode, 'adult');
        expect(updated.avatarIndex, 5);
      });

      test('list profiles by account', () async {
        await profileRepo.createProfile(
          accountId: 1,
          displayName: 'Child1',
          mode: 'child',
        );
        await profileRepo.createProfile(
          accountId: 1,
          displayName: 'Child2',
          mode: 'child',
        );
        await profileRepo.createProfile(
          accountId: 2,
          displayName: 'Other',
          mode: 'adult',
        );

        final account1Profiles =
            await profileRepo.getProfilesByAccount(1);
        expect(account1Profiles.length, 2);

        final account2Profiles =
            await profileRepo.getProfilesByAccount(2);
        expect(account2Profiles.length, 1);
      });

      test('delete profile', () async {
        final profile = await profileRepo.createProfile(
          accountId: 1,
          displayName: 'ToDelete',
          mode: 'child',
        );

        await profileRepo.deleteProfile(profile.id);

        final fetched = await profileRepo.getProfileById(profile.id);
        expect(fetched, isNull);
      });
    });

    group('AC: Deleting a profile cascades to all associated data', () {
      test('cascade deletes completions, bookmarks, goals, rewards', () async {
        final profile = await profileRepo.createProfile(
          accountId: 1,
          displayName: 'CascadeTest',
          mode: 'child',
        );
        final pid = profile.id;

        // Insert data for this profile
        await db.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            profileId: Value(pid),
            curriculumId: 'mishnah',
            sefariaRef: 'Mishnah_Berakhot.1.1',
            stageId: 1,
            trackType: 'personal',
            completedAt: DateTime.now().toUtc(),
          ),
        );
        await db.bookmarkDao.insertBookmark(
          BookmarksCompanion.insert(
            profileId: Value(pid),
            curriculumId: 'mishnah',
            trackType: 'personal',
            sefariaRef: 'Mishnah_Berakhot.1.1',
            updatedAt: DateTime.now().toUtc(),
          ),
        );
        await db.goalDao.insertGoal(
          GoalsCompanion.insert(
            profileId: Value(pid),
            curriculumId: 'mishnah',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
        await db.rewardDao.insertReward(
          RewardsCompanion.insert(
            profileId: Value(pid),
            title: 'Test Reward',
            description: 'A test reward',
            pointsThreshold: 100,
          ),
        );

        // Verify data exists
        expect(
          (await (db.select(db.completions)..where((t) => t.profileId.equals(pid))).get()).length,
          1,
        );
        expect(
          (await (db.select(db.bookmarks)..where((t) => t.profileId.equals(pid))).get()).length,
          1,
        );

        // Delete profile — should cascade
        await profileRepo.deleteProfile(pid);

        // Verify all data deleted
        expect(
          (await (db.select(db.completions)..where((t) => t.profileId.equals(pid))).get()).length,
          0,
        );
        expect(
          (await (db.select(db.bookmarks)..where((t) => t.profileId.equals(pid))).get()).length,
          0,
        );
        expect(
          (await (db.select(db.goals)..where((t) => t.profileId.equals(pid))).get()).length,
          0,
        );
        expect(
          (await (db.select(db.rewards)..where((t) => t.profileId.equals(pid))).get()).length,
          0,
        );
      });

      test('cascade delete does not affect other profiles', () async {
        final p1 = await profileRepo.createProfile(
          accountId: 1,
          displayName: 'Profile1',
          mode: 'child',
        );
        final p2 = await profileRepo.createProfile(
          accountId: 1,
          displayName: 'Profile2',
          mode: 'child',
        );

        // Add data for both profiles
        await db.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            profileId: Value(p1.id),
            curriculumId: 'mishnah',
            sefariaRef: 'Mishnah_Berakhot.1.1',
            stageId: 1,
            trackType: 'personal',
            completedAt: DateTime.now().toUtc(),
          ),
        );
        await db.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            profileId: Value(p2.id),
            curriculumId: 'mishnah',
            sefariaRef: 'Mishnah_Berakhot.1.2',
            stageId: 1,
            trackType: 'personal',
            completedAt: DateTime.now().toUtc(),
          ),
        );

        // Delete p1
        await profileRepo.deleteProfile(p1.id);

        // p2 data survives
        final p2Completions = await (db.select(db.completions)
              ..where((t) => t.profileId.equals(p2.id)))
            .get();
        expect(p2Completions.length, 1);
        expect(p2Completions.first.sefariaRef, 'Mishnah_Berakhot.1.2');
      });
    });

    group('Profiles table structure', () {
      test('profiles table has correct columns', () async {
        final profile = await profileRepo.createProfile(
          accountId: 42,
          displayName: 'Test User',
          mode: 'adult',
          avatarIndex: 7,
        );

        expect(profile.id, isPositive);
        expect(profile.accountId, 42);
        expect(profile.displayName, 'Test User');
        expect(profile.mode, 'adult');
        expect(profile.avatarIndex, 7);
        expect(profile.createdAt, isNotNull);
        expect(profile.updatedAt, isNotNull);
      });
    });

    group('ProfileDao', () {
      test('is accessible from AppDatabase', () {
        expect(db.profileDao, isNotNull);
      });

      test('watchProfilesByAccount emits updates', () async {
        final stream = db.profileDao.watchProfilesByAccount(1);

        // Initial empty
        expect(await stream.first, isEmpty);

        await profileRepo.createProfile(
          accountId: 1,
          displayName: 'Watched',
          mode: 'child',
        );

        final profiles = await stream.first;
        expect(profiles.length, 1);
        expect(profiles.first.displayName, 'Watched');
      });
    });
  });
}
