/// Story acceptance tests for Epic 8 -- Gamification.
@Tags(['epic_8'])
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/streak_service.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/completion_feedback_controller.dart';
import 'package:test/test.dart';

import '../helpers/test_database.dart';

void main() {
  // ── Story 8.1: Points system ──────────────────────────────────

  group('Story 8.1 -- Points system', tags: ['story_8_1'], () {
    late AppDatabase db;
    late PointsService pointsService;

    setUp(() {
      db = createTestDatabase();
      pointsService = PointsService(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> insertCompletion({
      required String curriculumId,
      required String sefariaRef,
      required int stageId,
      required int points,
      String trackType = 'personal',
    }) async {
      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: stageId,
          trackType: trackType,
          completedAt: DateTime.now(),
          points: Value(points),
        ),
      );
    }

    test('completing a content item awards points', () async {
      await insertCompletion(
        curriculumId: CurriculumId.mishnayos.storageKey,
        sefariaRef: 'Mishnah Berachos 1.1',
        stageId: 1,
        points: 10,
      );

      final total = await pointsService.getCurriculumTotal(
        CurriculumId.mishnayos.storageKey,
      );
      expect(total, 10);
    });

    test('points vary by stage (later stages worth more)', () async {
      // Default: Learn=10, Chazara1=5, Chazara2=3
      final learn = await pointsService.getPointsForStage(
        curriculumId: CurriculumId.mishnayos.storageKey,
        stageOrder: 1,
      );
      final chazara1 = await pointsService.getPointsForStage(
        curriculumId: CurriculumId.mishnayos.storageKey,
        stageOrder: 2,
      );
      final chazara2 = await pointsService.getPointsForStage(
        curriculumId: CurriculumId.mishnayos.storageKey,
        stageOrder: 3,
      );

      expect(learn, 10);
      expect(chazara1, 5);
      expect(chazara2, 3);
    });

    test('total points aggregated across all curricula', () async {
      await insertCompletion(
        curriculumId: CurriculumId.mishnayos.storageKey,
        sefariaRef: 'Mishnah Berachos 1.1',
        stageId: 1,
        points: 10,
      );
      await insertCompletion(
        curriculumId: CurriculumId.bavli.storageKey,
        sefariaRef: 'Berakhot 2a',
        stageId: 1,
        points: 10,
      );
      await insertCompletion(
        curriculumId: CurriculumId.mishnayos.storageKey,
        sefariaRef: 'Mishnah Berachos 1.2',
        stageId: 1,
        points: 10,
      );

      // Per-curriculum
      final mishnayosTotal = await pointsService.getCurriculumTotal(
        CurriculumId.mishnayos.storageKey,
      );
      expect(mishnayosTotal, 20);

      final bavliTotal = await pointsService.getCurriculumTotal(
        CurriculumId.bavli.storageKey,
      );
      expect(bavliTotal, 10);

      // Global
      final globalTotal = await pointsService.getGlobalTotal();
      expect(globalTotal, 30);
    });
  });

  // ── Story 8.2: Global Streak Tracking ────────────────────────

  group('Story 8.2 -- Global Streak Tracking', tags: ['story_8_2'], () {
    late AppDatabase db;
    late StreakService streakService;

    setUp(() {
      db = createTestDatabase();
      streakService = StreakService(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('complete items on 3 consecutive days, verify streak=3; '
        'skip a day, complete again, verify streak=4 and max=4', () async {
      final day1 = DateTimeFactory.utc(2026, 3, 10, 12);
      final day2 = DateTimeFactory.utc(2026, 3, 11, 14);
      final day3 = DateTimeFactory.utc(2026, 3, 12, 9);

      await streakService.recordCompletion(day1);
      await streakService.recordCompletion(day2);
      var streak = await streakService.recordCompletion(day3);
      expect(streak.currentStreak, 3);
      expect(streak.maxStreak, 3);

      // Skip day 4 (March 13), complete on day 5 (dayGap=2, grace applies)
      final day5 = DateTimeFactory.utc(2026, 3, 14, 12);
      streak = await streakService.recordCompletion(day5);
      // Grace period preserves the streak and increments it
      expect(streak.currentStreak, 4);
      expect(streak.maxStreak, 4);
    });

    test('streak does not double-increment on same day', () async {
      final morning = DateTimeFactory.utc(2026, 3, 10, 8);
      final evening = DateTimeFactory.utc(2026, 3, 10, 20);

      await streakService.recordCompletion(morning);
      final streak = await streakService.recordCompletion(evening);
      expect(streak.currentStreak, 1);
    });

    test('streak calendar returns active dates for range', () async {
      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: 'test',
          sefariaRef: 'Genesis.1',
          stageId: 1,
          trackType: 'primary',
          completedAt: DateTimeFactory.utc(2026, 3, 10, 12),
        ),
      );
      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: 'test',
          sefariaRef: 'Genesis.2',
          stageId: 1,
          trackType: 'primary',
          completedAt: DateTimeFactory.utc(2026, 3, 12, 12),
        ),
      );

      final calendar = await streakService.getStreakCalendar(
        startUtc: DateTimeFactory.utc(2026, 3, 9),
        endUtc: DateTimeFactory.utc(2026, 3, 13),
      );
      expect(calendar.length, 2);
    });
  });

  // ── Story 8.3: Mystery Rewards System ────────────────────────

  group('Story 8.3 -- Mystery Rewards System', tags: ['story_8_3'], () {
    late AppDatabase db;
    late RewardService rewardService;

    setUp(() {
      db = createTestDatabase();
      rewardService = RewardService(db, PointsService(db));
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> insertCompletion({
      required String curriculumId,
      required String sefariaRef,
      required int stageId,
      required int points,
    }) async {
      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: stageId,
          trackType: 'personal',
          completedAt: DateTime.now(),
          points: Value(points),
        ),
      );
    }

    Future<void> addReward({
      required String title,
      required int threshold,
      bool isVisible = true,
    }) async {
      await rewardService.addReward(
        title: title,
        description: 'Reward at $threshold points',
        pointsThreshold: threshold,
        isVisible: isVisible,
      );
    }

    test('marks reward as earned when global points reach threshold', () async {
      await addReward(title: 'Bronze', threshold: 50);

      // Add 50 points
      for (var i = 0; i < 5; i++) {
        await insertCompletion(
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Mishnah Berachos 1.${i + 1}',
          stageId: 1,
          points: 10,
        );
      }

      final earned = await rewardService.checkAndAwardRewards(
        userMode: UserMode.child,
      );
      expect(earned, hasLength(1));
      expect(earned.first.title, 'Bronze');
      expect(earned.first.isEarned, isTrue);
    });

    test('identifies next unearned reward (lowest threshold)', () async {
      await addReward(title: 'Bronze', threshold: 50);
      await addReward(title: 'Silver', threshold: 100);
      await addReward(title: 'Gold', threshold: 200);

      final next = await rewardService.getNextReward();
      expect(next, isNotNull);
      expect(next!.title, 'Bronze');
    });

    test('calculates progress percentage toward next reward', () async {
      await addReward(title: 'Bronze', threshold: 100);

      // Add 25 points (25% progress)
      for (var i = 0; i < 5; i++) {
        await insertCompletion(
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Mishnah Berachos 1.${i + 1}',
          stageId: 2, // 5 points each
          points: 5,
        );
      }

      final progress = await rewardService.getProgressToNextReward();
      expect(progress, closeTo(0.25, 0.01));
    });

    test('reveal toggling works (parent reveals)', () async {
      await addReward(title: 'Bronze', threshold: 10, isVisible: false);

      // Earn it in child mode (not auto-revealed)
      await insertCompletion(
        curriculumId: CurriculumId.mishnayos.storageKey,
        sefariaRef: 'Mishnah Berachos 1.1',
        stageId: 1,
        points: 10,
      );
      await rewardService.checkAndAwardRewards(userMode: UserMode.child);

      // Check it's earned but not revealed
      var rewards = await rewardService.getEarnedRewards();
      expect(rewards.first.isEarned, isTrue);
      expect(rewards.first.isRevealed, isFalse);

      // Parent reveals
      await rewardService.revealReward(rewards.first.id);

      rewards = await rewardService.getEarnedRewards();
      expect(rewards.first.isRevealed, isTrue);
    });

    test(
      'multiple rewards at different thresholds processed in order',
      () async {
        await addReward(title: 'Bronze', threshold: 10);
        await addReward(title: 'Silver', threshold: 20);
        await addReward(title: 'Gold', threshold: 30);

        // Add 30 points to earn all
        for (var i = 0; i < 3; i++) {
          await insertCompletion(
            curriculumId: CurriculumId.mishnayos.storageKey,
            sefariaRef: 'Mishnah Berachos 1.${i + 1}',
            stageId: 1,
            points: 10,
          );
        }

        final earned = await rewardService.checkAndAwardRewards(
          userMode: UserMode.child,
        );
        expect(earned, hasLength(3));
        expect(earned[0].title, 'Bronze');
        expect(earned[1].title, 'Silver');
        expect(earned[2].title, 'Gold');
      },
    );

    test(
      'adult mode: reward is_revealed defaults to true on earning',
      () async {
        await addReward(title: 'Bronze', threshold: 10);

        await insertCompletion(
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Mishnah Berachos 1.1',
          stageId: 1,
          points: 10,
        );

        final earned = await rewardService.checkAndAwardRewards(
          userMode: UserMode.adult,
        );
        expect(earned.first.isRevealed, isTrue);
      },
    );

    test('earned rewards history viewable', () async {
      await addReward(title: 'Bronze', threshold: 10);
      await addReward(title: 'Silver', threshold: 20);
      await addReward(title: 'Gold', threshold: 100);

      // Earn first two
      for (var i = 0; i < 2; i++) {
        await insertCompletion(
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Mishnah Berachos 1.${i + 1}',
          stageId: 1,
          points: 10,
        );
      }
      await rewardService.checkAndAwardRewards(userMode: UserMode.adult);

      final earned = await rewardService.getEarnedRewards();
      expect(earned, hasLength(2));

      // Gold should not be in earned list
      final all = await rewardService.getAllRewards();
      final unearned = all.where((r) => !r.isEarned).toList();
      expect(unearned, hasLength(1));
      expect(unearned.first.title, 'Gold');
    });

    test('next reward updates after earning current one', () async {
      await addReward(title: 'Bronze', threshold: 10);
      await addReward(title: 'Silver', threshold: 20);

      await insertCompletion(
        curriculumId: CurriculumId.mishnayos.storageKey,
        sefariaRef: 'Mishnah Berachos 1.1',
        stageId: 1,
        points: 10,
      );
      await rewardService.checkAndAwardRewards(userMode: UserMode.child);

      final next = await rewardService.getNextReward();
      expect(next, isNotNull);
      expect(next!.title, 'Silver');
    });

    test('progress bar resets to next reward after earning', () async {
      await addReward(title: 'Bronze', threshold: 10);
      await addReward(title: 'Silver', threshold: 20);

      // Earn 15 points - enough for Bronze, 50% toward Silver
      await insertCompletion(
        curriculumId: CurriculumId.mishnayos.storageKey,
        sefariaRef: 'Mishnah Berachos 1.1',
        stageId: 1,
        points: 10,
      );
      await rewardService.checkAndAwardRewards(userMode: UserMode.child);

      await insertCompletion(
        curriculumId: CurriculumId.mishnayos.storageKey,
        sefariaRef: 'Mishnah Berachos 1.2',
        stageId: 2,
        points: 5,
      );

      // Progress toward Silver: (15 - 10) / (20 - 10) = 0.5
      final progress = await rewardService.getProgressToNextReward();
      expect(progress, closeTo(0.5, 0.01));
    });

    test('no rewards configured returns null next and 0 progress', () async {
      final next = await rewardService.getNextReward();
      expect(next, isNull);

      final progress = await rewardService.getProgressToNextReward();
      expect(progress, 0.0);
    });
  });

  // ── Story 8.4: Completion Feedback & Animations (Unit) ────────

  group(
    'Story 8.4 -- Completion Feedback & Animations',
    tags: ['story_8_4'],
    () {
      group('CompletionFeedbackController', () {
        late CompletionFeedbackController controller;

        setUp(() {
          controller = CompletionFeedbackController();
        });

        tearDown(() {
          controller.dispose();
        });

        test('starts idle, becomes active on start()', () {
          expect(controller.phase, CompletionFeedbackPhase.idle);
          expect(controller.isActive, false);

          controller.start(
            const CompletionFeedbackData(
              pointsAwarded: 10,
              progressBefore: 0.5,
              progressAfter: 0.6,
              userMode: UserMode.child,
            ),
          );

          expect(controller.phase, CompletionFeedbackPhase.checkmark);
          expect(controller.isActive, true);
        });

        test('child mode: checkmark → pointsPopup → progressFill → idle', () {
          controller.start(
            const CompletionFeedbackData(
              pointsAwarded: 10,
              progressBefore: 0.5,
              progressAfter: 0.6,
              userMode: UserMode.child,
            ),
          );

          expect(controller.phase, CompletionFeedbackPhase.checkmark);
          controller.advance();
          expect(controller.phase, CompletionFeedbackPhase.pointsPopup);
          controller.advance();
          expect(controller.phase, CompletionFeedbackPhase.progressFill);
          controller.advance();
          expect(controller.phase, CompletionFeedbackPhase.idle);
          expect(controller.isActive, false);
        });

        test(
          'adult mode: checkmark → progressFill → idle (skips points popup)',
          () {
            controller.start(
              const CompletionFeedbackData(
                pointsAwarded: 10,
                progressBefore: 0.5,
                progressAfter: 0.6,
                userMode: UserMode.adult,
              ),
            );

            expect(controller.phase, CompletionFeedbackPhase.checkmark);
            controller.advance();
            expect(controller.phase, CompletionFeedbackPhase.progressFill);
            controller.advance();
            expect(controller.phase, CompletionFeedbackPhase.idle);
          },
        );

        test('streak increment adds streakBump phase', () {
          controller.start(
            const CompletionFeedbackData(
              pointsAwarded: 10,
              progressBefore: 0.5,
              progressAfter: 0.6,
              streakBefore: 2,
              streakAfter: 3,
              userMode: UserMode.child,
            ),
          );

          controller.advance(); // → pointsPopup
          controller.advance(); // → progressFill
          controller.advance(); // → streakBump
          expect(controller.phase, CompletionFeedbackPhase.streakBump);
          controller.advance(); // → idle
          expect(controller.phase, CompletionFeedbackPhase.idle);
        });

        test('cancel() immediately returns to idle', () {
          controller.start(
            const CompletionFeedbackData(
              pointsAwarded: 10,
              progressBefore: 0.5,
              progressAfter: 0.6,
              userMode: UserMode.child,
            ),
          );

          expect(controller.isActive, true);
          controller.cancel();
          expect(controller.phase, CompletionFeedbackPhase.idle);
          expect(controller.isActive, false);
          // Drift's isNull conflicts with matcher's isNull — use direct check
          expect(controller.data == null, true);
        });

        test('points popup displays correct point value from data', () {
          controller.start(
            const CompletionFeedbackData(
              pointsAwarded: 25,
              progressBefore: 0.3,
              progressAfter: 0.4,
              userMode: UserMode.child,
            ),
          );

          expect(controller.data!.pointsAwarded, 25);
        });

        test('notifies listeners on phase transitions', () {
          var notifyCount = 0;
          controller.addListener(() => notifyCount++);

          controller.start(
            const CompletionFeedbackData(
              pointsAwarded: 10,
              progressBefore: 0,
              progressAfter: 0.1,
              userMode: UserMode.child,
            ),
          );
          expect(notifyCount, 1);

          controller.advance();
          expect(notifyCount, 2);
        });
      });

      group('Integration: completion feedback sequence', () {
        test(
          'child mode full sequence: checkmark → points → progress → streak',
          () {
            final controller = CompletionFeedbackController();

            controller.start(
              const CompletionFeedbackData(
                pointsAwarded: 10,
                progressBefore: 0.5,
                progressAfter: 0.6,
                streakBefore: 2,
                streakAfter: 3,
                userMode: UserMode.child,
              ),
            );

            final phases = <CompletionFeedbackPhase>[controller.phase];
            while (controller.isActive) {
              controller.advance();
              phases.add(controller.phase);
            }

            expect(phases, [
              CompletionFeedbackPhase.checkmark,
              CompletionFeedbackPhase.pointsPopup,
              CompletionFeedbackPhase.progressFill,
              CompletionFeedbackPhase.streakBump,
              CompletionFeedbackPhase.idle,
            ]);

            controller.dispose();
          },
        );

        test('adult mode sequence: checkmark → progress → idle', () {
          final controller = CompletionFeedbackController();

          controller.start(
            const CompletionFeedbackData(
              pointsAwarded: 10,
              progressBefore: 0.5,
              progressAfter: 0.6,
              userMode: UserMode.adult,
            ),
          );

          final phases = <CompletionFeedbackPhase>[controller.phase];
          while (controller.isActive) {
            controller.advance();
            phases.add(controller.phase);
          }

          expect(phases, [
            CompletionFeedbackPhase.checkmark,
            CompletionFeedbackPhase.progressFill,
            CompletionFeedbackPhase.idle,
          ]);

          controller.dispose();
        });
      });
    },
  );
}
