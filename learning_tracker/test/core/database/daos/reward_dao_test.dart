import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  final now = DateTime(2024, 6, 15);

  Future<int> insertTestReward({
    String title = 'Ice Cream',
    String description = 'A treat',
    int pointsThreshold = 100,
    bool isEarned = false,
    bool isRevealed = false,
  }) {
    return database.rewardDao.insertReward(
      RewardsCompanion.insert(
        title: title,
        description: description,
        pointsThreshold: pointsThreshold,
        isEarned: Value(isEarned),
        isRevealed: Value(isRevealed),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  group('RewardDao', () {
    test('getAllRewards returns empty list initially', () async {
      final rewards = await database.rewardDao.getAllRewards();
      expect(rewards, isEmpty);
    });

    test('getAllRewards orders by pointsThreshold ascending', () async {
      await insertTestReward(title: 'Big', pointsThreshold: 500);
      await insertTestReward(title: 'Small', pointsThreshold: 50);
      await insertTestReward(title: 'Medium', pointsThreshold: 200);

      final rewards = await database.rewardDao.getAllRewards();
      expect(rewards[0].title, 'Small');
      expect(rewards[1].title, 'Medium');
      expect(rewards[2].title, 'Big');
    });

    test('getRewardById returns matching reward', () async {
      final id = await insertTestReward();

      final reward = await database.rewardDao.getRewardById(id);
      expect(reward, isNotNull);
      expect(reward!.title, 'Ice Cream');
    });

    test('getEarnedRewards returns only earned rewards', () async {
      await insertTestReward(title: 'Earned', isEarned: true);
      await insertTestReward(title: 'Not earned', isEarned: false);

      final earned = await database.rewardDao.getEarnedRewards();
      expect(earned, hasLength(1));
      expect(earned.first.title, 'Earned');
    });

    test('getUnearnedRewards returns only unearned rewards', () async {
      await insertTestReward(title: 'Earned', isEarned: true);
      await insertTestReward(title: 'Not earned', isEarned: false);

      final unearned = await database.rewardDao.getUnearnedRewards();
      expect(unearned, hasLength(1));
      expect(unearned.first.title, 'Not earned');
    });

    test('markEarned marks reward as earned with timestamp', () async {
      final id = await insertTestReward();
      final earnedAt = DateTime(2024, 7, 1);

      await database.rewardDao.markEarned(id, earnedAt: earnedAt);

      final reward = await database.rewardDao.getRewardById(id);
      expect(reward!.isEarned, isTrue);
      expect(reward.earnedAt, earnedAt);
    });

    test('revealReward sets isRevealed to true', () async {
      final id = await insertTestReward();

      await database.rewardDao.revealReward(id);

      final reward = await database.rewardDao.getRewardById(id);
      expect(reward!.isRevealed, isTrue);
    });

    test('deleteReward removes the reward', () async {
      final id = await insertTestReward();

      final deleted = await database.rewardDao.deleteReward(id);
      expect(deleted, 1);

      final reward = await database.rewardDao.getRewardById(id);
      expect(reward, isNull);
    });

    test('watchAllRewards emits updates', () async {
      final stream = database.rewardDao.watchAllRewards();

      expect(
        stream,
        emitsInOrder([
          <Reward>[], // Initial empty state
          hasLength(1), // After insertion
        ]),
      );

      await Future<void>.delayed(Duration.zero);
      await insertTestReward();
    });

    test('upsertReward inserts when no existing reward', () async {
      await database.rewardDao.upsertReward(
        title: 'New Reward',
        description: 'Desc',
        pointsThreshold: 100,
        isRevealed: false,
        isEarned: false,
        earnedAt: null,
        createdAt: now,
        updatedAt: now,
        curriculumId: null,
      );

      final rewards = await database.rewardDao.getAllRewards();
      expect(rewards, hasLength(1));
      expect(rewards.first.title, 'New Reward');
    });

    test('upsertReward updates when remote is newer', () async {
      final older = DateTime(2024, 1, 1);
      final newer = DateTime(2024, 6, 1);

      await database.rewardDao.upsertReward(
        title: 'Reward',
        description: 'Desc',
        pointsThreshold: 100,
        isRevealed: false,
        isEarned: false,
        earnedAt: null,
        createdAt: older,
        updatedAt: older,
        curriculumId: null,
      );

      await database.rewardDao.upsertReward(
        title: 'Reward',
        description: 'Desc',
        pointsThreshold: 100,
        isRevealed: true,
        isEarned: true,
        earnedAt: newer,
        createdAt: older,
        updatedAt: newer,
        curriculumId: null,
      );

      final rewards = await database.rewardDao.getAllRewards();
      expect(rewards, hasLength(1));
      expect(rewards.first.isEarned, isTrue);
      expect(rewards.first.isRevealed, isTrue);
    });

    test('upsertReward does not update when remote is older', () async {
      final older = DateTime(2024, 1, 1);
      final newer = DateTime(2024, 6, 1);

      await database.rewardDao.upsertReward(
        title: 'Reward',
        description: 'Desc',
        pointsThreshold: 100,
        isRevealed: true,
        isEarned: true,
        earnedAt: newer,
        createdAt: older,
        updatedAt: newer,
        curriculumId: null,
      );

      await database.rewardDao.upsertReward(
        title: 'Reward',
        description: 'Desc',
        pointsThreshold: 100,
        isRevealed: false,
        isEarned: false,
        earnedAt: null,
        createdAt: older,
        updatedAt: older,
        curriculumId: null,
      );

      final rewards = await database.rewardDao.getAllRewards();
      expect(rewards.first.isEarned, isTrue);
      expect(rewards.first.isRevealed, isTrue);
    });

    test('upsertReward uses most-progress-wins on equal timestamps', () async {
      final ts = DateTime(2024, 6, 1);

      await database.rewardDao.upsertReward(
        title: 'Reward',
        description: 'Desc',
        pointsThreshold: 100,
        isRevealed: false,
        isEarned: false,
        earnedAt: null,
        createdAt: ts,
        updatedAt: ts,
        curriculumId: null,
      );

      await database.rewardDao.upsertReward(
        title: 'Reward',
        description: 'Desc',
        pointsThreshold: 100,
        isRevealed: true,
        isEarned: false,
        earnedAt: null,
        createdAt: ts,
        updatedAt: ts,
        curriculumId: null,
      );

      final rewards = await database.rewardDao.getAllRewards();
      expect(rewards.first.isRevealed, isTrue);
    });
  });
}
