import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';

AppDatabase _createInMemoryDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = _createInMemoryDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('CompletionDao.completionExists', () {
    test('returns false when no matching completion exists', () async {
      final exists = await db.completionDao.completionExists(
        curriculumId: 'mishnayos',
        contentItemId: 1,
        stageId: 1,
        trackType: 'personal',
        completedAt: DateTime.utc(2026, 2, 9, 12, 0, 0),
      );

      expect(exists, isFalse);
    });

    test('returns true when matching completion exists', () async {
      final completedAt = DateTime.utc(2026, 2, 9, 12, 0, 0);
      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: 'mishnayos',
          contentItemId: 1,
          stageId: 1,
          trackType: 'personal',
          completedAt: completedAt,
        ),
      );

      final exists = await db.completionDao.completionExists(
        curriculumId: 'mishnayos',
        contentItemId: 1,
        stageId: 1,
        trackType: 'personal',
        completedAt: completedAt,
      );

      expect(exists, isTrue);
    });

    test('returns false when different curriculum', () async {
      final completedAt = DateTime.utc(2026, 2, 9, 12, 0, 0);
      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: 'mishnayos',
          contentItemId: 1,
          stageId: 1,
          trackType: 'personal',
          completedAt: completedAt,
        ),
      );

      final exists = await db.completionDao.completionExists(
        curriculumId: 'bavli', // different
        contentItemId: 1,
        stageId: 1,
        trackType: 'personal',
        completedAt: completedAt,
      );

      expect(exists, isFalse);
    });

    test('returns false when different stage', () async {
      final completedAt = DateTime.utc(2026, 2, 9, 12, 0, 0);
      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: 'mishnayos',
          contentItemId: 1,
          stageId: 1,
          trackType: 'personal',
          completedAt: completedAt,
        ),
      );

      final exists = await db.completionDao.completionExists(
        curriculumId: 'mishnayos',
        contentItemId: 1,
        stageId: 2, // different stage
        trackType: 'personal',
        completedAt: completedAt,
      );

      expect(exists, isFalse);
    });

    test('returns false when different completedAt', () async {
      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: 'mishnayos',
          contentItemId: 1,
          stageId: 1,
          trackType: 'personal',
          completedAt: DateTime.utc(2026, 2, 9, 12, 0, 0),
        ),
      );

      final exists = await db.completionDao.completionExists(
        curriculumId: 'mishnayos',
        contentItemId: 1,
        stageId: 1,
        trackType: 'personal',
        completedAt: DateTime.utc(2026, 2, 9, 13, 0, 0), // different time
      );

      expect(exists, isFalse);
    });
  });

  group('BookmarkDao.upsertBookmark', () {
    test('inserts when no bookmark exists', () async {
      await db.bookmarkDao.upsertBookmark(
        curriculumId: 'mishnayos',
        trackType: 'personal',
        contentItemId: 42,
        updatedAt: DateTime.utc(2026, 2, 9),
      );

      final bookmark = await db.bookmarkDao.getBookmarkByCurriculumAndTrack(
        'mishnayos',
        'personal',
      );
      expect(bookmark, isNotNull);
      expect(bookmark!.contentItemId, 42);
    });

    test('updates when remote is newer', () async {
      await db.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          curriculumId: 'mishnayos',
          trackType: 'personal',
          contentItemId: 10,
          updatedAt: DateTime.utc(2026, 2, 8),
        ),
      );

      await db.bookmarkDao.upsertBookmark(
        curriculumId: 'mishnayos',
        trackType: 'personal',
        contentItemId: 42,
        updatedAt: DateTime.utc(2026, 2, 9), // newer
      );

      final bookmark = await db.bookmarkDao.getBookmarkByCurriculumAndTrack(
        'mishnayos',
        'personal',
      );
      expect(bookmark!.contentItemId, 42);
    });

    test('does not update when remote is older', () async {
      await db.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          curriculumId: 'mishnayos',
          trackType: 'personal',
          contentItemId: 99,
          updatedAt: DateTime.utc(2026, 2, 10),
        ),
      );

      await db.bookmarkDao.upsertBookmark(
        curriculumId: 'mishnayos',
        trackType: 'personal',
        contentItemId: 42,
        updatedAt: DateTime.utc(2026, 2, 8), // older
      );

      final bookmark = await db.bookmarkDao.getBookmarkByCurriculumAndTrack(
        'mishnayos',
        'personal',
      );
      expect(bookmark!.contentItemId, 99); // unchanged
    });

    test('does not update when timestamps are equal', () async {
      final timestamp = DateTime.utc(2026, 2, 9);
      await db.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          curriculumId: 'mishnayos',
          trackType: 'personal',
          contentItemId: 10,
          updatedAt: timestamp,
        ),
      );

      await db.bookmarkDao.upsertBookmark(
        curriculumId: 'mishnayos',
        trackType: 'personal',
        contentItemId: 42,
        updatedAt: timestamp, // equal
      );

      final bookmark = await db.bookmarkDao.getBookmarkByCurriculumAndTrack(
        'mishnayos',
        'personal',
      );
      expect(bookmark!.contentItemId, 10); // unchanged
    });
  });

  group('StageDao.replaceStagesForCurriculum', () {
    test('replaces all stages for a curriculum', () async {
      // Insert original stages
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          curriculumId: 'mishnayos',
          stageOrder: 1,
          stageName: 'Old Learn',
          delayDays: 0,
        ),
      );

      // Replace with new stages
      await db.stageDao.replaceStagesForCurriculum('mishnayos', [
        StageDefinitionsCompanion.insert(
          curriculumId: 'mishnayos',
          stageOrder: 1,
          stageName: 'Learn',
          delayDays: 0,
        ),
        StageDefinitionsCompanion.insert(
          curriculumId: 'mishnayos',
          stageOrder: 2,
          stageName: 'Chazara 1',
          delayDays: 1,
        ),
        StageDefinitionsCompanion.insert(
          curriculumId: 'mishnayos',
          stageOrder: 3,
          stageName: 'Chazara 2',
          delayDays: 7,
        ),
      ]);

      final stages = await db.stageDao.getStageDefinitionsByCurriculum(
        'mishnayos',
      );
      expect(stages.length, 3);
      expect(stages[0].stageName, 'Learn');
      expect(stages[1].stageName, 'Chazara 1');
      expect(stages[2].stageName, 'Chazara 2');
    });

    test('does not affect other curricula', () async {
      // Insert stages for two curricula
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          curriculumId: 'mishnayos',
          stageOrder: 1,
          stageName: 'Learn',
          delayDays: 0,
        ),
      );
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          curriculumId: 'bavli',
          stageOrder: 1,
          stageName: 'Learn Bavli',
          delayDays: 0,
        ),
      );

      // Replace only mishnayos
      await db.stageDao.replaceStagesForCurriculum('mishnayos', [
        StageDefinitionsCompanion.insert(
          curriculumId: 'mishnayos',
          stageOrder: 1,
          stageName: 'New Learn',
          delayDays: 0,
        ),
      ]);

      // Bavli should be unchanged
      final bavliStages = await db.stageDao.getStageDefinitionsByCurriculum(
        'bavli',
      );
      expect(bavliStages.length, 1);
      expect(bavliStages.first.stageName, 'Learn Bavli');
    });

    test('handles empty replacement list', () async {
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          curriculumId: 'mishnayos',
          stageOrder: 1,
          stageName: 'Learn',
          delayDays: 0,
        ),
      );

      await db.stageDao.replaceStagesForCurriculum('mishnayos', []);

      final stages = await db.stageDao.getStageDefinitionsByCurriculum(
        'mishnayos',
      );
      expect(stages, isEmpty);
    });
  });

  group('UserProfileDao.upsertProfile', () {
    test('inserts when no profile exists', () async {
      await db.userProfileDao.upsertProfile(
        firebaseUid: 'uid-123',
        displayName: 'Yisroel',
        userMode: 'child',
        updatedAt: DateTime.utc(2026, 2, 9),
      );

      final profile = await db.userProfileDao.getUserProfileByFirebaseUid(
        'uid-123',
      );
      expect(profile, isNotNull);
      expect(profile!.displayName, 'Yisroel');
      expect(profile.userMode, 'child');
    });

    test('updates when remote is newer', () async {
      await db.userProfileDao.insertUserProfile(
        UserProfilesCompanion.insert(
          firebaseUid: 'uid-123',
          displayName: 'Old Name',
          userMode: 'adult',
          createdAt: DateTime.utc(2026, 2, 7),
          updatedAt: DateTime.utc(2026, 2, 7),
        ),
      );

      await db.userProfileDao.upsertProfile(
        firebaseUid: 'uid-123',
        displayName: 'New Name',
        userMode: 'child',
        updatedAt: DateTime.utc(2026, 2, 9), // newer
      );

      final profile = await db.userProfileDao.getUserProfileByFirebaseUid(
        'uid-123',
      );
      expect(profile!.displayName, 'New Name');
      expect(profile.userMode, 'child');
    });

    test('does not update when remote is older', () async {
      await db.userProfileDao.insertUserProfile(
        UserProfilesCompanion.insert(
          firebaseUid: 'uid-123',
          displayName: 'Current Name',
          userMode: 'adult',
          createdAt: DateTime.utc(2026, 2, 9),
          updatedAt: DateTime.utc(2026, 2, 9),
        ),
      );

      await db.userProfileDao.upsertProfile(
        firebaseUid: 'uid-123',
        displayName: 'Old Name',
        userMode: 'child',
        updatedAt: DateTime.utc(2026, 2, 7), // older
      );

      final profile = await db.userProfileDao.getUserProfileByFirebaseUid(
        'uid-123',
      );
      expect(profile!.displayName, 'Current Name'); // unchanged
    });
  });
}
