/// Extended tests for GoalDao covering methods not exercised by goal_dao_test.dart:
/// - getGoalsByCurriculumAndProfile
/// - getGoalsByProfile
/// - getGoalsByTrack
/// - deleteGoalsForTrack
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;

  setUp(() {
    db = inMemoryDb();
  });

  tearDown(() async {
    await db.close();
  });

  // ── helpers ──────────────────────────────────────────────────────────────

  final _now = DateTime.utc(2026, 1, 1);

  Future<int> _insertTrack({
    int profileId = 1,
    String curriculumId = 'mishnayos',
  }) {
    return db.into(db.curriculumTracks).insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: curriculumId,
            trackType: 'personal',
            activatedAt: _now,
          ),
        );
  }

  Future<int> _insertGoal({
    int profileId = 1,
    String curriculumId = 'mishnayos',
    int trackId = 0,
    DateTime? targetDate,
  }) {
    return db.goalDao.insertGoal(
      GoalsCompanion.insert(
        profileId: profileId,
        curriculumId: curriculumId,
        trackId: trackId,
        targetDate: Value(targetDate),
        createdAt: _now,
        updatedAt: _now,
      ),
    );
  }

  // ── getGoalsByCurriculumAndProfile ────────────────────────────────────────

  group('GoalDao.getGoalsByCurriculumAndProfile', () {
    test('returns only goals matching both curriculum and profile', () async {
      final trackId1 = await _insertTrack(profileId: 1, curriculumId: 'mishnayos');
      final trackId2 = await _insertTrack(profileId: 2, curriculumId: 'mishnayos');
      final trackId3 = await _insertTrack(profileId: 1, curriculumId: 'bavli');

      await _insertGoal(profileId: 1, curriculumId: 'mishnayos', trackId: trackId1);
      await _insertGoal(profileId: 2, curriculumId: 'mishnayos', trackId: trackId2);
      await _insertGoal(profileId: 1, curriculumId: 'bavli', trackId: trackId3);

      final goals = await db.goalDao.getGoalsByCurriculumAndProfile(
        'mishnayos',
        1,
      );
      expect(goals, hasLength(1));
      expect(goals.first.curriculumId, 'mishnayos');
      expect(goals.first.profileId, 1);
    });

    test('returns empty list when no matching goals', () async {
      final goals = await db.goalDao.getGoalsByCurriculumAndProfile(
        'bavli',
        99,
      );
      expect(goals, isEmpty);
    });

    test('orders results by targetDate ascending', () async {
      // Use a single track and insert two goals with different targetDates.
      final trackId1 = await _insertTrack(profileId: 1, curriculumId: 'bavli');

      final d1 = DateTime.utc(2026, 12, 31);
      final d2 = DateTime.utc(2026, 6, 1);

      // Insert later date first, then earlier — expect ascending order in result.
      await _insertGoal(
        profileId: 1,
        curriculumId: 'bavli',
        trackId: trackId1,
        targetDate: d1,
      );
      await _insertGoal(
        profileId: 1,
        curriculumId: 'bavli',
        trackId: trackId1,
        targetDate: d2,
      );

      final goals = await db.goalDao.getGoalsByCurriculumAndProfile('bavli', 1);
      expect(goals, hasLength(2));
      // Earlier date first — compare as milliseconds to avoid UTC/local mismatch.
      final firstMs = goals.first.targetDate!.millisecondsSinceEpoch;
      final lastMs = goals.last.targetDate!.millisecondsSinceEpoch;
      expect(firstMs, lessThan(lastMs));
    });
  });

  // ── getGoalsByProfile ─────────────────────────────────────────────────────

  group('GoalDao.getGoalsByProfile', () {
    test('returns all goals for a profile', () async {
      final t1 = await _insertTrack(profileId: 1, curriculumId: 'mishnayos');
      final t2 = await _insertTrack(profileId: 1, curriculumId: 'bavli');
      final t3 = await _insertTrack(profileId: 2, curriculumId: 'mishnayos');

      await _insertGoal(profileId: 1, curriculumId: 'mishnayos', trackId: t1);
      await _insertGoal(profileId: 1, curriculumId: 'bavli', trackId: t2);
      await _insertGoal(profileId: 2, curriculumId: 'mishnayos', trackId: t3);

      final goals = await db.goalDao.getGoalsByProfile(1);
      expect(goals, hasLength(2));
      expect(goals.every((g) => g.profileId == 1), isTrue);
    });

    test('returns empty list when profile has no goals', () async {
      final goals = await db.goalDao.getGoalsByProfile(999);
      expect(goals, isEmpty);
    });
  });

  // ── getGoalsByTrack ───────────────────────────────────────────────────────

  group('GoalDao.getGoalsByTrack', () {
    test('returns goals for a specific track', () async {
      final trackId = await _insertTrack(profileId: 1, curriculumId: 'mishnayos');
      final other = await _insertTrack(profileId: 1, curriculumId: 'bavli');

      await _insertGoal(profileId: 1, curriculumId: 'mishnayos', trackId: trackId);
      await _insertGoal(profileId: 1, curriculumId: 'bavli', trackId: other);

      final goals = await db.goalDao.getGoalsByTrack(trackId);
      expect(goals, hasLength(1));
      expect(goals.first.trackId, trackId);
    });

    test('returns empty when no goals for track', () async {
      final goals = await db.goalDao.getGoalsByTrack(9999);
      expect(goals, isEmpty);
    });
  });

  // ── deleteGoalsForTrack ───────────────────────────────────────────────────

  group('GoalDao.deleteGoalsForTrack', () {
    test('deletes all goals for the specified track', () async {
      final trackId = await _insertTrack(profileId: 1, curriculumId: 'mishnayos');
      final other = await _insertTrack(profileId: 1, curriculumId: 'bavli');

      await _insertGoal(profileId: 1, curriculumId: 'mishnayos', trackId: trackId);
      await _insertGoal(profileId: 1, curriculumId: 'bavli', trackId: other);

      final deleted = await db.goalDao.deleteGoalsForTrack(trackId);
      expect(deleted, 1);

      final remaining = await db.goalDao.getAllGoals();
      expect(remaining, hasLength(1));
      expect(remaining.first.trackId, other);
    });

    test('is a no-op when no goals exist for track', () async {
      final deleted = await db.goalDao.deleteGoalsForTrack(9999);
      expect(deleted, 0);
    });
  });
}
