// Extra coverage for GoalDao — tests methods not exercised by goal_dao_test.dart:
//   - getAllGoals (after insertions)
//   - getGoalsByProfile
//   - getGoalsByTrack
//   - deleteGoalsForTrack
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late int trackId;

  const profileId = 1;

  setUp(() async {
    db = inMemoryDb();
    trackId = await db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: 'mishnayos',
            trackType: 'personal',
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  final now = DateTime.utc(2026, 1, 1);

  Future<int> insertGoal({
    int pid = profileId,
    int? tId,
    String curriculumId = 'mishnayos',
    DateTime? targetDate,
  }) => db.goalDao.insertGoal(
    GoalsCompanion.insert(
      profileId: pid,
      curriculumId: curriculumId,
      trackId: tId ?? trackId,
      createdAt: now,
      updatedAt: now,
      targetDate: Value(targetDate),
    ),
  );

  // =========================================================================
  // getAllGoals — post-insertion
  // =========================================================================

  group('GoalDao.getAllGoals', () {
    test('returns all goals across profiles and curricula', () async {
      await insertGoal();
      await insertGoal(pid: 2, curriculumId: 'bavli');

      final all = await db.goalDao.getAllGoals();

      expect(all, hasLength(2));
    });
  });

  // =========================================================================
  // getGoalsByProfile
  // =========================================================================

  group('GoalDao.getGoalsByProfile', () {
    test('returns goals only for the specified profile', () async {
      await insertGoal(pid: 1);
      await insertGoal(pid: 1);
      // Insert for profile 2 — needs its own track.
      final track2 = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 2,
              curriculumId: 'bavli',
              trackType: 'personal',
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      await insertGoal(pid: 2, tId: track2, curriculumId: 'bavli');

      final goals1 = await db.goalDao.getGoalsByProfile(1);
      final goals2 = await db.goalDao.getGoalsByProfile(2);

      expect(goals1, hasLength(2));
      expect(goals2, hasLength(1));
    });

    test('returns empty list for profile with no goals', () async {
      final goals = await db.goalDao.getGoalsByProfile(99);
      expect(goals, isEmpty);
    });
  });

  // =========================================================================
  // getGoalsByTrack
  // =========================================================================

  group('GoalDao.getGoalsByTrack', () {
    test('returns goals for the given track in targetDate order', () async {
      await insertGoal(targetDate: DateTime.utc(2026, 6, 1));
      await insertGoal(targetDate: DateTime.utc(2026, 3, 1));

      final goals = await db.goalDao.getGoalsByTrack(trackId);

      expect(goals, hasLength(2));
      // Ordered by targetDate ascending — compare just the day portions.
      expect(goals.first.targetDate!.month, 3);
      expect(goals.last.targetDate!.month, 6);
    });

    test('returns empty list for a track with no goals', () async {
      final goals = await db.goalDao.getGoalsByTrack(999);
      expect(goals, isEmpty);
    });

    test('does not include goals from other tracks', () async {
      final track2 = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackType: 'personal',
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      await insertGoal(); // track 1
      await insertGoal(tId: track2, curriculumId: 'bavli'); // track 2

      final goals = await db.goalDao.getGoalsByTrack(trackId);
      expect(goals, hasLength(1));
    });
  });

  // =========================================================================
  // deleteGoalsForTrack
  // =========================================================================

  group('GoalDao.deleteGoalsForTrack', () {
    test('deletes all goals for the specified track', () async {
      await insertGoal();
      await insertGoal();

      final deleted = await db.goalDao.deleteGoalsForTrack(trackId);

      expect(deleted, 2);
      final remaining = await db.goalDao.getGoalsByTrack(trackId);
      expect(remaining, isEmpty);
    });

    test('returns 0 when no goals exist for the track', () async {
      final deleted = await db.goalDao.deleteGoalsForTrack(999);
      expect(deleted, 0);
    });

    test('does not delete goals from other tracks', () async {
      final track2 = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackType: 'personal',
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      await insertGoal(); // track 1
      await insertGoal(tId: track2, curriculumId: 'bavli'); // track 2

      await db.goalDao.deleteGoalsForTrack(trackId);

      final track2Goals = await db.goalDao.getGoalsByTrack(track2);
      expect(track2Goals, hasLength(1));
    });
  });
}
