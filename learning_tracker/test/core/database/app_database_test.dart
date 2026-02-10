import 'package:drift/drift.dart' hide isNotNull, isNull;
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

  group('AppDatabase', () {
    test('creates database successfully', () {
      expect(db, isNotNull);
      expect(db.schemaVersion, 2);
    });

    test('has all expected DAOs', () {
      expect(db.contentDao, isNotNull);
      expect(db.completionDao, isNotNull);
      expect(db.stageDao, isNotNull);
      expect(db.bookmarkDao, isNotNull);
      expect(db.learningOrderDao, isNotNull);
      expect(db.trackDao, isNotNull);
      expect(db.userProfileDao, isNotNull);
    });
  });

  group('ContentItems CRUD', () {
    test('inserts and retrieves a content item', () async {
      final id = await db.contentDao.insertContentItem(
        ContentItemsCompanion.insert(
          curriculumId: 'mishnayos',
          level1: 'Zeraim',
          level2: const Value('Berachos'),
          level3: const Value('1'),
          level4: const Value('1'),
          displayNameHe: 'ברכות א:א',
          displayNameEn: 'Berachos 1:1',
          sefariaRef: const Value('Mishnah Berakhot 1.1'),
          sortOrder: 1,
          isLeaf: true,
        ),
      );

      final item = await db.contentDao.getContentItemById(id);
      expect(item, isNotNull);
      expect(item!.curriculumId, 'mishnayos');
      expect(item.level1, 'Zeraim');
      expect(item.level2, 'Berachos');
      expect(item.displayNameHe, 'ברכות א:א');
      expect(item.isLeaf, true);
    });

    test('retrieves content items by curriculum', () async {
      await db.contentDao.insertContentItem(
        ContentItemsCompanion.insert(
          curriculumId: 'mishnayos',
          level1: 'Zeraim',
          displayNameHe: 'זרעים',
          displayNameEn: 'Zeraim',
          sortOrder: 1,
          isLeaf: false,
        ),
      );
      await db.contentDao.insertContentItem(
        ContentItemsCompanion.insert(
          curriculumId: 'other',
          level1: 'Other',
          displayNameHe: 'אחר',
          displayNameEn: 'Other',
          sortOrder: 1,
          isLeaf: false,
        ),
      );

      final items = await db.contentDao.getContentItemsByCurriculum(
        'mishnayos',
      );
      expect(items.length, 1);
      expect(items.first.curriculumId, 'mishnayos');
    });

    test('retrieves only leaf items', () async {
      await db.contentDao.insertContentItem(
        ContentItemsCompanion.insert(
          curriculumId: 'mishnayos',
          level1: 'Zeraim',
          displayNameHe: 'זרעים',
          displayNameEn: 'Zeraim',
          sortOrder: 1,
          isLeaf: false,
        ),
      );
      await db.contentDao.insertContentItem(
        ContentItemsCompanion.insert(
          curriculumId: 'mishnayos',
          level1: 'Zeraim',
          level2: const Value('Berachos'),
          level3: const Value('1'),
          level4: const Value('1'),
          displayNameHe: 'ברכות א:א',
          displayNameEn: 'Berachos 1:1',
          sortOrder: 2,
          isLeaf: true,
        ),
      );

      final leaves = await db.contentDao.getLeafItems('mishnayos');
      expect(leaves.length, 1);
      expect(leaves.first.isLeaf, true);
    });

    test('deletes a content item', () async {
      final id = await db.contentDao.insertContentItem(
        ContentItemsCompanion.insert(
          curriculumId: 'mishnayos',
          level1: 'Zeraim',
          displayNameHe: 'זרעים',
          displayNameEn: 'Zeraim',
          sortOrder: 1,
          isLeaf: false,
        ),
      );

      await db.contentDao.deleteContentItem(id);
      final item = await db.contentDao.getContentItemById(id);
      expect(item, isNull);
    });

    test('enforces unique constraint on curriculum + levels', () async {
      await db.contentDao.insertContentItem(
        ContentItemsCompanion.insert(
          curriculumId: 'mishnayos',
          level1: 'Zeraim',
          level2: const Value('Berachos'),
          level3: const Value('1'),
          level4: const Value('1'),
          displayNameHe: 'ברכות א:א',
          displayNameEn: 'Berachos 1:1',
          sortOrder: 1,
          isLeaf: true,
        ),
      );

      expect(
        () => db.contentDao.insertContentItem(
          ContentItemsCompanion.insert(
            curriculumId: 'mishnayos',
            level1: 'Zeraim',
            level2: const Value('Berachos'),
            level3: const Value('1'),
            level4: const Value('1'),
            displayNameHe: 'duplicate',
            displayNameEn: 'duplicate',
            sortOrder: 2,
            isLeaf: true,
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('CurriculumHierarchyConfig CRUD', () {
    test('inserts and retrieves config', () async {
      await db
          .into(db.curriculumHierarchyConfig)
          .insert(
            CurriculumHierarchyConfigCompanion.insert(
              curriculumId: 'mishnayos',
              level1Label: 'Seder',
              level2Label: const Value('Masechta'),
              level3Label: const Value('Perek'),
              level4Label: const Value('Mishna'),
              maxLevels: 4,
            ),
          );

      final configs = await db.select(db.curriculumHierarchyConfig).get();
      expect(configs.length, 1);
      expect(configs.first.curriculumId, 'mishnayos');
      expect(configs.first.level1Label, 'Seder');
      expect(configs.first.maxLevels, 4);
    });

    test('enforces primary key uniqueness', () async {
      await db
          .into(db.curriculumHierarchyConfig)
          .insert(
            CurriculumHierarchyConfigCompanion.insert(
              curriculumId: 'mishnayos',
              level1Label: 'Seder',
              maxLevels: 4,
            ),
          );

      expect(
        () => db
            .into(db.curriculumHierarchyConfig)
            .insert(
              CurriculumHierarchyConfigCompanion.insert(
                curriculumId: 'mishnayos',
                level1Label: 'Different',
                maxLevels: 2,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('StageDefinitions CRUD', () {
    test('inserts and retrieves stage definitions', () async {
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          curriculumId: 'mishnayos',
          stageOrder: 1,
          stageName: 'learning',
          delayDays: 0,
        ),
      );

      final stages = await db.stageDao.getStageDefinitionsByCurriculum(
        'mishnayos',
      );
      expect(stages.length, 1);
      expect(stages.first.stageName, 'learning');
      expect(stages.first.delayDays, 0);
    });

    test('returns stages ordered by stageOrder', () async {
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          curriculumId: 'mishnayos',
          stageOrder: 3,
          stageName: 'chazara2',
          delayDays: 7,
        ),
      );
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          curriculumId: 'mishnayos',
          stageOrder: 1,
          stageName: 'learning',
          delayDays: 0,
        ),
      );
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          curriculumId: 'mishnayos',
          stageOrder: 2,
          stageName: 'chazara1',
          delayDays: 1,
        ),
      );

      final stages = await db.stageDao.getStageDefinitionsByCurriculum(
        'mishnayos',
      );
      expect(stages.length, 3);
      expect(stages[0].stageName, 'learning');
      expect(stages[1].stageName, 'chazara1');
      expect(stages[2].stageName, 'chazara2');
    });

    test('enforces unique constraint on curriculum + stageOrder', () async {
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          curriculumId: 'mishnayos',
          stageOrder: 1,
          stageName: 'learning',
          delayDays: 0,
        ),
      );

      expect(
        () => db.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            curriculumId: 'mishnayos',
            stageOrder: 1,
            stageName: 'duplicate',
            delayDays: 0,
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('Completions CRUD (append-only)', () {
    test('inserts and retrieves a completion', () async {
      final now = DateTime.now().toUtc();
      final id = await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: 'mishnayos',
          contentItemId: 1,
          stageId: 1,
          trackType: 'personal',
          completedAt: now,
        ),
      );

      final completion = await db.completionDao.getCompletionById(id);
      expect(completion, isNotNull);
      expect(completion!.curriculumId, 'mishnayos');
      expect(completion.contentItemId, 1);
      expect(completion.trackType, 'personal');
      expect(completion.points, 0);
    });

    test('stores completedAt preserving timestamp value', () async {
      final utcTime = DateTime.utc(2026, 2, 9, 12, 0, 0);
      final id = await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: 'mishnayos',
          contentItemId: 1,
          stageId: 1,
          trackType: 'personal',
          completedAt: utcTime,
        ),
      );

      final completion = await db.completionDao.getCompletionById(id);
      // Drift stores as unix epoch seconds; compare epoch values
      expect(
        completion!.completedAt.millisecondsSinceEpoch,
        utcTime.millisecondsSinceEpoch,
      );
    });

    test('retrieves completions by curriculum', () async {
      final now = DateTime.now().toUtc();
      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: 'mishnayos',
          contentItemId: 1,
          stageId: 1,
          trackType: 'personal',
          completedAt: now,
        ),
      );
      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: 'other',
          contentItemId: 2,
          stageId: 1,
          trackType: 'personal',
          completedAt: now,
        ),
      );

      final completions = await db.completionDao.getCompletionsByCurriculum(
        'mishnayos',
      );
      expect(completions.length, 1);
    });

    test('retrieves completions for content item', () async {
      final now = DateTime.now().toUtc();
      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: 'mishnayos',
          contentItemId: 42,
          stageId: 1,
          trackType: 'personal',
          completedAt: now,
        ),
      );
      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: 'mishnayos',
          contentItemId: 42,
          stageId: 2,
          trackType: 'personal',
          completedAt: now,
        ),
      );

      final completions = await db.completionDao.getCompletionsForContentItem(
        42,
      );
      expect(completions.length, 2);
    });
  });

  group('Bookmarks CRUD', () {
    test('inserts and retrieves a bookmark', () async {
      final now = DateTime.now().toUtc();
      final id = await db.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          curriculumId: 'mishnayos',
          trackType: 'personal',
          contentItemId: 1,
          updatedAt: now,
        ),
      );

      final bookmark = await db.bookmarkDao.getBookmarkById(id);
      expect(bookmark, isNotNull);
      expect(bookmark!.curriculumId, 'mishnayos');
      expect(bookmark.trackType, 'personal');
    });

    test('retrieves bookmark by curriculum and track', () async {
      final now = DateTime.now().toUtc();
      await db.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          curriculumId: 'mishnayos',
          trackType: 'personal',
          contentItemId: 1,
          updatedAt: now,
        ),
      );

      final bookmark = await db.bookmarkDao.getBookmarkByCurriculumAndTrack(
        'mishnayos',
        'personal',
      );
      expect(bookmark, isNotNull);
      expect(bookmark!.contentItemId, 1);
    });

    test('returns null for non-existent bookmark', () async {
      final bookmark = await db.bookmarkDao.getBookmarkByCurriculumAndTrack(
        'nonexistent',
        'personal',
      );
      expect(bookmark, isNull);
    });

    test('deletes a bookmark', () async {
      final now = DateTime.now().toUtc();
      final id = await db.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          curriculumId: 'mishnayos',
          trackType: 'personal',
          contentItemId: 1,
          updatedAt: now,
        ),
      );

      await db.bookmarkDao.deleteBookmark(id);
      final bookmark = await db.bookmarkDao.getBookmarkById(id);
      expect(bookmark, isNull);
    });
  });

  group('LearningOrder CRUD', () {
    test('inserts and retrieves learning order', () async {
      final id = await db.learningOrderDao.insertLearningOrder(
        LearningOrderCompanion.insert(
          curriculumId: 'mishnayos',
          contentItemId: 1,
          userSortOrder: 10,
        ),
      );

      final order = await db.learningOrderDao.getLearningOrderById(id);
      expect(order, isNotNull);
      expect(order!.userSortOrder, 10);
    });

    test(
      'retrieves learning order by curriculum sorted by userSortOrder',
      () async {
        await db.learningOrderDao.insertLearningOrder(
          LearningOrderCompanion.insert(
            curriculumId: 'mishnayos',
            contentItemId: 3,
            userSortOrder: 30,
          ),
        );
        await db.learningOrderDao.insertLearningOrder(
          LearningOrderCompanion.insert(
            curriculumId: 'mishnayos',
            contentItemId: 1,
            userSortOrder: 10,
          ),
        );
        await db.learningOrderDao.insertLearningOrder(
          LearningOrderCompanion.insert(
            curriculumId: 'mishnayos',
            contentItemId: 2,
            userSortOrder: 20,
          ),
        );

        final orders = await db.learningOrderDao.getLearningOrderByCurriculum(
          'mishnayos',
        );
        expect(orders.length, 3);
        expect(orders[0].userSortOrder, 10);
        expect(orders[1].userSortOrder, 20);
        expect(orders[2].userSortOrder, 30);
      },
    );

    test('enforces unique constraint on curriculum + contentItemId', () async {
      await db.learningOrderDao.insertLearningOrder(
        LearningOrderCompanion.insert(
          curriculumId: 'mishnayos',
          contentItemId: 1,
          userSortOrder: 10,
        ),
      );

      expect(
        () => db.learningOrderDao.insertLearningOrder(
          LearningOrderCompanion.insert(
            curriculumId: 'mishnayos',
            contentItemId: 1,
            userSortOrder: 20,
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('UserProfiles CRUD', () {
    test('inserts and retrieves a user profile', () async {
      final now = DateTime.now().toUtc();
      final id = await db.userProfileDao.insertUserProfile(
        UserProfilesCompanion.insert(
          firebaseUid: 'uid-123',
          displayName: 'Yisroel Meir',
          userMode: 'child',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final profile = await db.userProfileDao.getUserProfileById(id);
      expect(profile, isNotNull);
      expect(profile!.firebaseUid, 'uid-123');
      expect(profile.displayName, 'Yisroel Meir');
      expect(profile.userMode, 'child');
    });

    test('retrieves user profile by firebase UID', () async {
      final now = DateTime.now().toUtc();
      await db.userProfileDao.insertUserProfile(
        UserProfilesCompanion.insert(
          firebaseUid: 'uid-456',
          displayName: 'Test User',
          userMode: 'parent',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final profile = await db.userProfileDao.getUserProfileByFirebaseUid(
        'uid-456',
      );
      expect(profile, isNotNull);
      expect(profile!.displayName, 'Test User');
    });

    test('returns null for non-existent user profile', () async {
      final profile = await db.userProfileDao.getUserProfileByFirebaseUid(
        'nonexistent',
      );
      expect(profile, isNull);
    });

    test('deletes a user profile', () async {
      final now = DateTime.now().toUtc();
      final id = await db.userProfileDao.insertUserProfile(
        UserProfilesCompanion.insert(
          firebaseUid: 'uid-789',
          displayName: 'Delete Me',
          userMode: 'child',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await db.userProfileDao.deleteUserProfile(id);
      final profile = await db.userProfileDao.getUserProfileById(id);
      expect(profile, isNull);
    });
  });

  group('Rewards CRUD', () {
    test('inserts and retrieves a reward', () async {
      await db
          .into(db.rewards)
          .insert(
            RewardsCompanion.insert(
              title: 'Mystery Prize',
              description: 'Complete 100 Mishnayos',
              pointsThreshold: 100,
            ),
          );

      final allRewards = await db.select(db.rewards).get();
      expect(allRewards.length, 1);
      expect(allRewards.first.title, 'Mystery Prize');
      expect(allRewards.first.isRevealed, false);
      expect(allRewards.first.isEarned, false);
      expect(allRewards.first.curriculumId, isNull);
    });

    test('supports nullable curriculumId for global rewards', () async {
      await db
          .into(db.rewards)
          .insert(
            RewardsCompanion.insert(
              title: 'Global Reward',
              description: 'For everyone',
              pointsThreshold: 50,
            ),
          );

      await db
          .into(db.rewards)
          .insert(
            RewardsCompanion.insert(
              title: 'Curriculum Reward',
              description: 'For mishnayos',
              pointsThreshold: 200,
              curriculumId: const Value('mishnayos'),
            ),
          );

      final allRewards = await db.select(db.rewards).get();
      expect(allRewards.length, 2);

      final global = allRewards.where((r) => r.curriculumId == null).toList();
      expect(global.length, 1);
      expect(global.first.title, 'Global Reward');

      final curriculum = allRewards
          .where((r) => r.curriculumId != null)
          .toList();
      expect(curriculum.length, 1);
      expect(curriculum.first.curriculumId, 'mishnayos');
    });
  });
}
