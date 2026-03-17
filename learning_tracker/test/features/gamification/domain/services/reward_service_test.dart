import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_service.dart';
import 'package:learning_tracker/features/tutor_mode/domain/tutor_mode_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockPointsService extends Mock implements PointsService {}

void main() {
  late AppDatabase db;
  late MockPointsService mockPointsService;
  late RewardService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    mockPointsService = MockPointsService();
    service = RewardService(db, mockPointsService);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> _addReward({
    required String title,
    required int threshold,
  }) async {
    return service.addReward(
      title: title,
      description: 'desc',
      pointsThreshold: threshold,
    );
  }

  group('getNextReward', () {
    test('returns null when no rewards exist', () async {
      final next = await service.getNextReward();
      expect(next, isNull);
    });

    test('returns the lowest-threshold unearned reward', () async {
      await _addReward(title: 'Big', threshold: 500);
      await _addReward(title: 'Small', threshold: 100);

      final next = await service.getNextReward();
      expect(next, isNotNull);
      expect(next!.title, 'Small');
      expect(next.pointsThreshold, 100);
    });

    test('returns null when all rewards are earned', () async {
      final id = await _addReward(title: 'R1', threshold: 10);
      await db.rewardDao.markEarned(id, earnedAt: DateTime.now().toUtc());

      final next = await service.getNextReward();
      expect(next, isNull);
    });
  });

  group('getProgressToNextReward', () {
    test('returns 0.0 when no unearned rewards', () async {
      when(() => mockPointsService.getGlobalTotal()).thenAnswer((_) async => 0);
      final progress = await service.getProgressToNextReward();
      expect(progress, 0.0);
    });

    test('calculates progress from 0 base', () async {
      await _addReward(title: 'R1', threshold: 100);
      when(() => mockPointsService.getGlobalTotal())
          .thenAnswer((_) async => 50);

      final progress = await service.getProgressToNextReward();
      expect(progress, closeTo(0.5, 0.01));
    });

    test('calculates progress from previous earned threshold', () async {
      final id1 = await _addReward(title: 'R1', threshold: 100);
      await _addReward(title: 'R2', threshold: 200);
      await db.rewardDao.markEarned(id1, earnedAt: DateTime.now().toUtc());

      when(() => mockPointsService.getGlobalTotal())
          .thenAnswer((_) async => 150);

      final progress = await service.getProgressToNextReward();
      // base=100, next=200, range=100, points-base=50 => 0.5
      expect(progress, closeTo(0.5, 0.01));
    });

    test('clamps to 1.0 when points exceed threshold', () async {
      await _addReward(title: 'R1', threshold: 100);
      when(() => mockPointsService.getGlobalTotal())
          .thenAnswer((_) async => 200);

      final progress = await service.getProgressToNextReward();
      expect(progress, 1.0);
    });
  });

  group('checkAndAwardRewards', () {
    test('marks rewards as earned when points exceed threshold', () async {
      await _addReward(title: 'R1', threshold: 50);
      await _addReward(title: 'R2', threshold: 200);
      when(() => mockPointsService.getGlobalTotal())
          .thenAnswer((_) async => 100);

      final earned = await service.checkAndAwardRewards(
        userMode: UserMode.child,
      );

      expect(earned.length, 1);
      expect(earned.first.title, 'R1');
      expect(earned.first.isEarned, true);
    });

    test('auto-reveals in adult mode', () async {
      await _addReward(title: 'R1', threshold: 50);
      when(() => mockPointsService.getGlobalTotal())
          .thenAnswer((_) async => 100);

      final earned = await service.checkAndAwardRewards(
        userMode: UserMode.adult,
      );

      expect(earned.first.isRevealed, true);
    });

    test('does not auto-reveal in child mode', () async {
      await _addReward(title: 'R1', threshold: 50);
      when(() => mockPointsService.getGlobalTotal())
          .thenAnswer((_) async => 100);

      final earned = await service.checkAndAwardRewards(
        userMode: UserMode.child,
      );

      expect(earned.first.isRevealed, false);
    });

    test('returns empty when no rewards exceed threshold', () async {
      await _addReward(title: 'R1', threshold: 500);
      when(() => mockPointsService.getGlobalTotal())
          .thenAnswer((_) async => 10);

      final earned = await service.checkAndAwardRewards(
        userMode: UserMode.adult,
      );

      expect(earned, isEmpty);
    });
  });

  group('revealReward', () {
    test('reveals an earned reward', () async {
      final id = await _addReward(title: 'R1', threshold: 50);
      await db.rewardDao.markEarned(id, earnedAt: DateTime.now().toUtc());

      await service.revealReward(id);

      final reward = await db.rewardDao.getRewardById(id);
      expect(reward!.isRevealed, true);
    });

    test('throws in tutor mode', () async {
      final tutorService = RewardService(db, mockPointsService, isTutorMode: true);
      final id = await _addReward(title: 'R1', threshold: 50);

      expect(
        () => tutorService.revealReward(id),
        throwsA(isA<TutorModeReadOnlyException>()),
      );
    });
  });

  group('updateReward', () {
    test('updates an unearned reward', () async {
      final id = await _addReward(title: 'Old', threshold: 50);

      await service.updateReward(
        id: id,
        title: 'New',
        description: 'new desc',
        pointsThreshold: 75,
      );

      final reward = await db.rewardDao.getRewardById(id);
      expect(reward!.title, 'New');
      expect(reward.pointsThreshold, 75);
    });

    test('throws when editing an earned reward', () async {
      final id = await _addReward(title: 'R1', threshold: 50);
      await db.rewardDao.markEarned(id, earnedAt: DateTime.now().toUtc());

      expect(
        () => service.updateReward(
          id: id,
          title: 'Updated',
          description: 'desc',
          pointsThreshold: 100,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('throws in tutor mode', () async {
      final tutorService = RewardService(db, mockPointsService, isTutorMode: true);
      final id = await _addReward(title: 'R1', threshold: 50);

      expect(
        () => tutorService.updateReward(
          id: id,
          title: 'X',
          description: 'x',
          pointsThreshold: 10,
        ),
        throwsA(isA<TutorModeReadOnlyException>()),
      );
    });
  });

  group('deleteReward', () {
    test('deletes an unearned reward', () async {
      final id = await _addReward(title: 'R1', threshold: 50);
      await service.deleteReward(id);

      final reward = await db.rewardDao.getRewardById(id);
      expect(reward, isNull);
    });

    test('throws when deleting an earned reward', () async {
      final id = await _addReward(title: 'R1', threshold: 50);
      await db.rewardDao.markEarned(id, earnedAt: DateTime.now().toUtc());

      expect(
        () => service.deleteReward(id),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('getEarnedRewards', () {
    test('returns only earned rewards', () async {
      final id1 = await _addReward(title: 'R1', threshold: 50);
      await _addReward(title: 'R2', threshold: 100);
      await db.rewardDao.markEarned(id1, earnedAt: DateTime.now().toUtc());

      final earned = await service.getEarnedRewards();
      expect(earned.length, 1);
      expect(earned.first.title, 'R1');
    });
  });

  group('getAllRewards', () {
    test('returns all rewards', () async {
      await _addReward(title: 'R1', threshold: 50);
      await _addReward(title: 'R2', threshold: 100);

      final all = await service.getAllRewards();
      expect(all.length, 2);
    });
  });
}
