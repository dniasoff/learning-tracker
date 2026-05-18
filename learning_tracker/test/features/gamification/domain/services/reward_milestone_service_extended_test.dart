/// Extended tests for RewardMilestoneService covering methods that query
/// the UserDatabase: getGlobalPointsForRewards, getTrackPointsTotal,
/// trackCountsTowardRewardPoints, getTrackPointsTotalForRewards,
/// evaluateUnlocksForTrack, evaluateUnlocksForGlobal (with milestones),
/// getAllUnlocks (with stored data).
library;

import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late RewardMilestoneService service;
  const profileId = 1;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = inMemoryDb();
    await seedProfile(db);
    // Seed a second learner profile (profileId = 2) for cross-profile tests.
    await db.into(db.accounts).insert(
      AccountsCompanion(
        id: const Value(2),
        email: const Value('test2@example.com'),
        tier: const Value('localBorn'),
        displayName: const Value('Test User 2'),
        userMode: const Value('adult'),
        createdAt: Value(DateTime.utc(2026, 1, 1)),
        updatedAt: Value(DateTime.utc(2026, 1, 1)),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    await db.into(db.learnerProfiles).insert(
      LearnerProfilesCompanion(
        id: const Value(2),
        accountId: const Value(2),
        displayName: const Value('Test User 2'),
        mode: const Value('adult'),
        createdAt: Value(DateTime.utc(2026, 1, 1)),
        updatedAt: Value(DateTime.utc(2026, 1, 1)),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    service = RewardMilestoneService(db, profileId: profileId);
  });

  tearDown(() async {
    await db.close();
  });

  // ── helpers ──────────────────────────────────────────────────────────────

  Future<int> insertTrack({
    String curriculumId = 'mishnayos',
    bool isActive = true,
  }) {
    return db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: curriculumId,
            trackType: 'personal',
            isActive: Value(isActive),
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
  }

  Future<void> insertCompletion({
    required int trackId,
    String curriculumId = 'mishnayos',
    String sefariaRef = 'Berakhot 1:1',
    int stageId = 1,
    int points = 10,
    DateTime? completedAt,
  }) => seedCompletion(
    db,
    CompletionsCompanion.insert(
      profileId: profileId,
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      stageId: stageId,
      trackType: 'personal',
      trackId: trackId,
      completedAt: completedAt ?? DateTime.utc(2026, 5, 14),
      points: Value(points),
    ),
  ).then((_) {});

  Future<void> insertGoal(int trackId) async {
    await db
        .into(db.goals)
        .insert(
          GoalsCompanion.insert(
            profileId: profileId,
            curriculumId: 'mishnayos',
            trackId: trackId,
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
  }

  // ── getTrackPointsTotal ───────────────────────────────────────────────────

  group('RewardMilestoneService.getTrackPointsTotal', () {
    test('returns 0 when no completions for track', () async {
      final total = await service.getTrackPointsTotal(999);
      expect(total, 0);
    });

    test('sums points for a given track', () async {
      final trackId = await insertTrack();
      await insertCompletion(trackId: trackId, points: 5);
      await insertCompletion(
        trackId: trackId,
        sefariaRef: 'Berakhot 1:2',
        points: 15,
      );

      final total = await service.getTrackPointsTotal(trackId);
      expect(total, 20);
    });

    test('does not include points from other profiles', () async {
      final trackId = await insertTrack();
      // Insert a completion for profile 2 in the same track.
      await seedCompletion(
        db,
        CompletionsCompanion.insert(
          profileId: 2,
          curriculumId: 'mishnayos',
          sefariaRef: 'Berakhot 1:1',
          stageId: 1,
          trackType: 'personal',
          trackId: trackId,
          completedAt: DateTime.utc(2026, 5, 14),
        ),
      );
      await insertCompletion(trackId: trackId, points: 7);

      final total = await service.getTrackPointsTotal(trackId);
      // Service is scoped to profileId=1, so only the 7-point completion counts.
      expect(total, 7);
    });
  });

  // ── trackCountsTowardRewardPoints ─────────────────────────────────────────

  group('RewardMilestoneService.trackCountsTowardRewardPoints', () {
    test('returns false for non-existent track', () async {
      final result = await service.trackCountsTowardRewardPoints(9999);
      expect(result, isFalse);
    });

    test('returns true when track has a learning goal', () async {
      final trackId = await insertTrack(curriculumId: 'mishnayos');
      await insertGoal(trackId);

      final result = await service.trackCountsTowardRewardPoints(trackId);
      expect(result, isTrue);
    });

    test('returns false for track with no goal and no program', () async {
      final trackId = await insertTrack(curriculumId: 'mishnayos');

      final result = await service.trackCountsTowardRewardPoints(trackId);
      expect(result, isFalse);
    });
  });

  // ── getTrackPointsTotalForRewards ─────────────────────────────────────────

  group('RewardMilestoneService.getTrackPointsTotalForRewards', () {
    test('returns 0 for non-reward-eligible track', () async {
      final trackId = await insertTrack(curriculumId: 'mishnayos');
      await insertCompletion(trackId: trackId, points: 50);

      // No goal → not reward-eligible → returns 0
      final total = await service.getTrackPointsTotalForRewards(trackId);
      expect(total, 0);
    });

    test(
      'returns total points for reward-eligible track (with goal)',
      () async {
        final trackId = await insertTrack(curriculumId: 'mishnayos');
        await insertGoal(trackId);
        await insertCompletion(trackId: trackId, points: 30);
        await insertCompletion(
          trackId: trackId,
          sefariaRef: 'Berakhot 1:2',
          points: 20,
        );

        final total = await service.getTrackPointsTotalForRewards(trackId);
        expect(total, 50);
      },
    );
  });

  // ── getGlobalPointsForRewards ─────────────────────────────────────────────

  group('RewardMilestoneService.getGlobalPointsForRewards', () {
    test('returns 0 when profile has no completions', () async {
      final total = await service.getGlobalPointsForRewards();
      expect(total, 0);
    });

    test('returns 0 for completions on non-reward-eligible track', () async {
      final trackId = await insertTrack(curriculumId: 'mishnayos');
      await insertCompletion(trackId: trackId, points: 100);
      // No goal → not eligible → 0
      final total = await service.getGlobalPointsForRewards();
      expect(total, 0);
    });

    test('sums points across eligible tracks', () async {
      final trackId = await insertTrack(curriculumId: 'mishnayos');
      await insertGoal(trackId);
      await insertCompletion(trackId: trackId, points: 25);
      await insertCompletion(
        trackId: trackId,
        sefariaRef: 'Berakhot 1:2',
        points: 25,
      );

      final total = await service.getGlobalPointsForRewards();
      expect(total, 50);
    });
  });

  // ── evaluateUnlocksForTrack ───────────────────────────────────────────────

  group('RewardMilestoneService.evaluateUnlocksForTrack', () {
    test('returns empty when track is not reward-eligible (no goal)', () async {
      final trackId = await insertTrack(curriculumId: 'mishnayos');
      await service.upsertMilestone(
        trackId: trackId,
        title: 'Test',
        thresholdPoints: 10,
      );

      final unlocks = await service.evaluateUnlocksForTrack(trackId);
      expect(unlocks, isEmpty);
    });

    test('returns empty when no milestones configured for track', () async {
      final trackId = await insertTrack(curriculumId: 'mishnayos');
      await insertGoal(trackId);

      final unlocks = await service.evaluateUnlocksForTrack(trackId);
      expect(unlocks, isEmpty);
    });

    test('unlocks milestone when points exceed threshold', () async {
      final trackId = await insertTrack(curriculumId: 'mishnayos');
      await insertGoal(trackId);
      await insertCompletion(trackId: trackId, points: 50);

      await service.upsertMilestone(
        trackId: trackId,
        title: 'Bronze',
        thresholdPoints: 30,
        milestoneId: 'bronze-1',
      );

      final unlocks = await service.evaluateUnlocksForTrack(trackId);
      expect(unlocks, hasLength(1));
      expect(unlocks.first.milestoneId, 'bronze-1');
      expect(unlocks.first.pointsAtUnlock, 50);
    });

    test('does not unlock milestone when points are below threshold', () async {
      final trackId = await insertTrack(curriculumId: 'mishnayos');
      await insertGoal(trackId);
      await insertCompletion(trackId: trackId, points: 10);

      await service.upsertMilestone(
        trackId: trackId,
        title: 'Gold',
        thresholdPoints: 100,
        milestoneId: 'gold-1',
      );

      final unlocks = await service.evaluateUnlocksForTrack(trackId);
      expect(unlocks, isEmpty);
    });

    test('does not re-unlock an already-unlocked milestone', () async {
      final trackId = await insertTrack(curriculumId: 'mishnayos');
      await insertGoal(trackId);
      await insertCompletion(trackId: trackId, points: 50);

      await service.upsertMilestone(
        trackId: trackId,
        title: 'Silver',
        thresholdPoints: 30,
        milestoneId: 'silver-1',
      );

      // First evaluation unlocks it.
      final first = await service.evaluateUnlocksForTrack(trackId);
      expect(first, hasLength(1));

      // Second evaluation — already unlocked, nothing new.
      final second = await service.evaluateUnlocksForTrack(trackId);
      expect(second, isEmpty);
    });

    test('skips disabled milestones', () async {
      final trackId = await insertTrack(curriculumId: 'mishnayos');
      await insertGoal(trackId);
      await insertCompletion(trackId: trackId, points: 100);

      await service.upsertMilestone(
        trackId: trackId,
        title: 'Disabled',
        thresholdPoints: 50,
        milestoneId: 'disabled-1',
        isEnabled: false,
      );

      final unlocks = await service.evaluateUnlocksForTrack(trackId);
      expect(unlocks, isEmpty);
    });
  });

  // ── evaluateUnlocksForGlobal ──────────────────────────────────────────────

  group(
    'RewardMilestoneService.evaluateUnlocksForGlobal (with milestones)',
    () {
      test(
        'unlocks global milestone when global points exceed threshold',
        () async {
          final trackId = await insertTrack(curriculumId: 'mishnayos');
          await insertGoal(trackId);
          await insertCompletion(trackId: trackId, points: 200);

          await service.upsertMilestone(
            trackId: RewardMilestone.kGlobalTrackSentinel,
            title: 'Global Bronze',
            thresholdPoints: 100,
            milestoneId: 'global-bronze',
          );

          final unlocks = await service.evaluateUnlocksForGlobal();
          expect(unlocks, hasLength(1));
          expect(unlocks.first.milestoneId, 'global-bronze');
          expect(unlocks.first.trackId, RewardMilestone.kGlobalTrackSentinel);
        },
      );

      test(
        'does not re-unlock global milestone on second evaluation',
        () async {
          final trackId = await insertTrack(curriculumId: 'mishnayos');
          await insertGoal(trackId);
          await insertCompletion(trackId: trackId, points: 200);

          await service.upsertMilestone(
            trackId: RewardMilestone.kGlobalTrackSentinel,
            title: 'Global Bronze',
            thresholdPoints: 100,
            milestoneId: 'global-bronze',
          );

          await service.evaluateUnlocksForGlobal();
          final second = await service.evaluateUnlocksForGlobal();
          expect(second, isEmpty);
        },
      );
    },
  );

  // ── getAllUnlocks (with stored data) ──────────────────────────────────────

  group('RewardMilestoneService.getAllUnlocks (with stored data)', () {
    test('returns stored unlock records sorted newest-first', () async {
      final older = DateTime.utc(2026, 1, 1);
      final newer = DateTime.utc(2026, 5, 14);

      final records = [
        RewardUnlockRecord(
          milestoneId: 'id-1',
          profileId: profileId,
          trackId: 1,
          title: 'First',
          thresholdPoints: 50,
          pointsAtUnlock: 60,
          unlockedAt: older,
        ),
        RewardUnlockRecord(
          milestoneId: 'id-2',
          profileId: profileId,
          trackId: 1,
          title: 'Second',
          thresholdPoints: 100,
          pointsAtUnlock: 110,
          unlockedAt: newer,
        ),
      ];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'reward_milestones_unlocks_v1_$profileId',
        jsonEncode(records.map((r) => r.toJson()).toList()),
      );

      final unlocks = await service.getAllUnlocks();
      expect(unlocks, hasLength(2));
      // Sorted newest-first.
      expect(unlocks.first.milestoneId, 'id-2');
      expect(unlocks.last.milestoneId, 'id-1');
    });

    test('returns empty when prefs key is missing', () async {
      final unlocks = await service.getAllUnlocks();
      expect(unlocks, isEmpty);
    });

    test(
      'returns empty when prefs value is not a list (invalid JSON)',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'reward_milestones_unlocks_v1_$profileId',
          'not json',
        );
        final unlocks = await service.getAllUnlocks();
        expect(unlocks, isEmpty);
      },
    );

    test('filters out records for other profiles', () async {
      final records = [
        RewardUnlockRecord(
          milestoneId: 'mine',
          profileId: profileId,
          trackId: 1,
          title: 'Mine',
          thresholdPoints: 50,
          pointsAtUnlock: 60,
          unlockedAt: DateTime.utc(2026, 5, 1),
        ),
        RewardUnlockRecord(
          milestoneId: 'theirs',
          profileId: 999,
          trackId: 1,
          title: 'Theirs',
          thresholdPoints: 50,
          pointsAtUnlock: 60,
          unlockedAt: DateTime.utc(2026, 5, 1),
        ),
      ];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'reward_milestones_unlocks_v1_$profileId',
        jsonEncode(records.map((r) => r.toJson()).toList()),
      );

      final unlocks = await service.getAllUnlocks();
      expect(unlocks, hasLength(1));
      expect(unlocks.first.milestoneId, 'mine');
    });
  });
}
