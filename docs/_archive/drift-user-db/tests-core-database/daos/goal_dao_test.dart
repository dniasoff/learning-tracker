import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase database;
  late int trackId;

  setUp(() async {
    database = inMemoryDb();
    await seedProfile(database);
    trackId = await seedTrack(
      database,
      profileId: 1,
      curriculumId: 'bavli',
      activatedAt: DateTimeFactory.nowUtc(),
    );
  });

  tearDown(() async {
    await database.close();
  });

  final now = DateTime(2024, 6, 15);

  Future<int> insertTestGoal({
    String curriculumId = 'bavli',
    String description = 'Finish Berakhot',
    double targetPercent = 100.0,
    DateTime? targetDate,
  }) {
    return database.goalDao.insertGoal(
      GoalsCompanion.insert(
        profileId: 1,
        curriculumId: curriculumId,
        trackId: trackId,
        description: Value(description),
        targetPercent: Value(targetPercent),
        targetDate: Value(targetDate),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  group('GoalDao', () {
    test('getAllGoals returns empty list initially', () async {
      final goals = await database.goalDao.getAllGoals();
      expect(goals, isEmpty);
    });

    test('insertGoal and getGoalById', () async {
      final id = await insertTestGoal();

      final goal = await database.goalDao.getGoalById(id);
      expect(goal, isNotNull);
      expect(goal!.curriculumId, 'bavli');
      expect(goal.description, 'Finish Berakhot');
      expect(goal.targetPercent, 100.0);
    });

    test('getGoalsByCurriculum filters and orders by targetDate', () async {
      await insertTestGoal(
        targetDate: DateTime(2025, 1, 1),
        description: 'Later goal',
      );
      await insertTestGoal(
        targetDate: DateTime(2024, 7, 1),
        description: 'Earlier goal',
      );
      await insertTestGoal(
        curriculumId: 'yerushalmi',
        description: 'Other curriculum',
      );

      final goals = await database.goalDao.getGoalsByCurriculum('bavli');
      expect(goals, hasLength(2));
      expect(goals.first.description, 'Earlier goal');
    });

    test('updateGoal modifies existing goal', () async {
      final id = await insertTestGoal();

      await database.goalDao.updateGoal(
        GoalsCompanion(
          id: Value(id),
          profileId: const Value(1),
          curriculumId: const Value('bavli'),
          trackId: Value(trackId),
          description: const Value('Updated goal'),
          targetPercent: const Value(50.0),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final goal = await database.goalDao.getGoalById(id);
      expect(goal!.description, 'Updated goal');
      expect(goal.targetPercent, 50.0);
    });

    test('deleteGoal removes the goal', () async {
      final id = await insertTestGoal();

      final deleted = await database.goalDao.deleteGoal(id);
      expect(deleted, 1);

      final goal = await database.goalDao.getGoalById(id);
      expect(goal, isNull);
    });

    test('deleteGoalsByCurriculum removes all goals for curriculum', () async {
      await insertTestGoal(description: 'Goal 1');
      await insertTestGoal(description: 'Goal 2');
      await insertTestGoal(curriculumId: 'yerushalmi', description: 'Other');

      final deleted = await database.goalDao.deleteGoalsByCurriculum(
        'bavli',
        1,
      );
      expect(deleted, 2);

      final all = await database.goalDao.getAllGoals();
      expect(all, hasLength(1));
      expect(all.first.curriculumId, 'yerushalmi');
    });

    // Regression (AUD-guardrails-01): deleteGoalsByCurriculum() previously
    // filtered only by curriculumId, so two profiles sharing a curriculum
    // (e.g. two children both on 'bavli') would have BOTH of their goals
    // deleted by one profile's cleanup call. Multiple profiles CAN share a
    // curriculumId — this is not a hypothetical.
    test('deleteGoalsByCurriculum does not delete another profile\'s goal '
        'when two profiles share a curriculumId', () async {
      // profile 1 (id=1) is seeded in setUp with a 'bavli' track.
      await insertTestGoal(description: 'Profile 1 goal');

      // Second profile, independently on the same curriculum. Uses its own
      // account (seedProfile() can't be called twice — accounts.email is
      // UNIQUE) but that mirrors two sibling child profiles under the same
      // parent equally well: only learner_profiles.id needs to differ.
      final account2 = await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'test2@example.com',
              tier: 'localBorn',
              displayName: 'Test User 2',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await database
          .into(database.learnerProfiles)
          .insert(
            LearnerProfilesCompanion.insert(
              accountId: account2,
              displayName: 'Test User 2',
              mode: 'child',
              createdAt: now,
              updatedAt: now,
            ),
          ); // profile id=2
      final track2 = await seedTrack(
        database,
        profileId: 2,
        curriculumId: 'bavli',
        activatedAt: now,
      );
      await database.goalDao.insertGoal(
        GoalsCompanion.insert(
          profileId: 2,
          curriculumId: 'bavli',
          trackId: track2,
          description: const Value('Profile 2 goal'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Profile 1 cleans up its own 'bavli' goals.
      final deleted = await database.goalDao.deleteGoalsByCurriculum(
        'bavli',
        1,
      );
      expect(deleted, 1);

      // Profile 2's goal on the same curriculum must survive untouched.
      final remaining = await database.goalDao.getAllGoals();
      expect(remaining, hasLength(1));
      expect(remaining.first.profileId, 2);
      expect(remaining.first.description, 'Profile 2 goal');
    });

    test('upsertGoalByTrack inserts when no existing goal', () async {
      await database.goalDao.upsertGoalByTrack(
        profileId: 1,
        curriculumId: 'bavli',
        trackId: trackId,
        description: 'New goal',
        targetPercent: 75.0,
        targetDate: DateTime(2025, 1, 1),
        createdAt: now,
        updatedAt: now,
      );

      final goals = await database.goalDao.getGoalsByCurriculum('bavli');
      expect(goals, hasLength(1));
      expect(goals.first.description, 'New goal');
      expect(goals.first.targetPercent, 75.0);
    });

    test('upsertGoalByTrack updates when newer timestamp', () async {
      final older = DateTime(2024, 1, 1);
      final newer = DateTime(2024, 6, 1);

      await database.goalDao.upsertGoalByTrack(
        profileId: 1,
        curriculumId: 'bavli',
        trackId: trackId,
        description: 'My goal',
        targetPercent: 50.0,
        targetDate: null,
        createdAt: older,
        updatedAt: older,
      );

      await database.goalDao.upsertGoalByTrack(
        profileId: 1,
        curriculumId: 'bavli',
        trackId: trackId,
        description: 'My goal',
        targetPercent: 75.0,
        targetDate: DateTime(2025, 1, 1),
        createdAt: older,
        updatedAt: newer,
      );

      final goals = await database.goalDao.getGoalsByCurriculum('bavli');
      expect(goals, hasLength(1));
      expect(goals.first.targetPercent, 75.0);
    });

    test('upsertGoalByTrack does not update when older timestamp', () async {
      final older = DateTime(2024, 1, 1);
      final newer = DateTime(2024, 6, 1);

      await database.goalDao.upsertGoalByTrack(
        profileId: 1,
        curriculumId: 'bavli',
        trackId: trackId,
        description: 'My goal',
        targetPercent: 75.0,
        targetDate: null,
        createdAt: older,
        updatedAt: newer,
      );

      await database.goalDao.upsertGoalByTrack(
        profileId: 1,
        curriculumId: 'bavli',
        trackId: trackId,
        description: 'My goal',
        targetPercent: 50.0,
        targetDate: null,
        createdAt: older,
        updatedAt: older,
      );

      final goals = await database.goalDao.getGoalsByCurriculum('bavli');
      expect(goals, hasLength(1));
      expect(goals.first.targetPercent, 75.0);
    });
  });
}
