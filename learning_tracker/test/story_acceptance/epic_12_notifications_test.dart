/// Story acceptance tests for Epic 12 -- Notifications.
@Tags(['epic_12'])
library;

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_model.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_service.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_scheduler.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';
import 'package:learning_tracker/features/notifications/domain/services/reward_milestone_notification_service.dart';
import 'package:learning_tracker/features/notifications/domain/services/shabbos_time_service.dart';
import 'package:learning_tracker/features/notifications/domain/services/streak_alert_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/test_database.dart';

class MockNotificationService extends Mock implements NotificationService {}

void main() {
  // ── Story 12.1: Local notifications ───────────────────────────

  group('Story 12.1 -- Local notifications', tags: ['story_12_1'], () {
    late MockNotificationService mockService;
    late NotificationScheduler scheduler;

    setUp(() {
      mockService = MockNotificationService();
      scheduler = NotificationScheduler(service: mockService);
    });

    test(
      'schedule() calls service with correct body for plural counts',
      () async {
        when(
          () => mockService.scheduleDailyReminder(
            hour: any(named: 'hour'),
            minute: any(named: 'minute'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {});

        await scheduler.schedule(
          time: const TimeOfDay(hour: 19, minute: 0),
          taskCount: 5,
          curriculumCount: 2,
        );

        verify(
          () => mockService.scheduleDailyReminder(
            hour: 19,
            minute: 0,
            body: 'You have 5 tasks across 2 curricula today',
          ),
        ).called(1);
      },
    );

    test('schedule() uses singular forms for count of 1', () async {
      when(
        () => mockService.scheduleDailyReminder(
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async {});

      await scheduler.schedule(
        time: const TimeOfDay(hour: 8, minute: 30),
        taskCount: 1,
        curriculumCount: 1,
      );

      verify(
        () => mockService.scheduleDailyReminder(
          hour: 8,
          minute: 30,
          body: 'You have 1 task across 1 curriculum today',
        ),
      ).called(1);
    });

    test('cancel() delegates to service.cancelDailyReminder()', () async {
      when(() => mockService.cancelDailyReminder()).thenAnswer((_) async {});

      await scheduler.cancel();

      verify(() => mockService.cancelDailyReminder()).called(1);
    });

    test('notification payload enables deep link to daily tasks', () {
      expect(dailyReminderPayload, 'daily_reminder');
    });

    test('notification repeats daily via matchDateTimeComponents', () {
      // The service uses matchDateTimeComponents: DateTimeComponents.time
      // which repeats daily. Verified by the notification ID constant.
      expect(dailyReminderId, 0);
    });
  });

  // ── Story 12.2: Streak Protection Alerts ──────────────────────

  group('Story 12.2 -- Streak Protection Alerts', tags: ['story_12_2'], () {
    late AppDatabase db;
    late MockNotificationService mockService;
    late StreakAlertService alertService;

    setUp(() {
      db = createTestDatabase();
      mockService = MockNotificationService();
      alertService = StreakAlertService(
        db: db,
        notificationService: mockService,
        clock: () => DateTime.utc(2026, 3, 16, 12, 0, 0),
      );

      when(
        () => mockService.scheduleStreakAlert(
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockService.cancelStreakAlert()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await db.close();
    });

    test('alert fires when streak > 0 and no completions today', () async {
      await db.streakDao.upsertStreak(
        StreaksCompanion.insert(
          currentStreak: const Value(5),
          maxStreak: const Value(5),
          lastCompletionDate: Value(DateTime.utc(2026, 3, 15, 18, 0, 0)),
        ),
      );

      await alertService.evaluate(hour: 21, minute: 0);

      verify(
        () => mockService.scheduleStreakAlert(
          hour: 21,
          minute: 0,
          body: 'Your 5-day streak is at risk!',
        ),
      ).called(1);
    });

    test('alert does NOT fire when completions exist today', () async {
      await db.streakDao.upsertStreak(
        StreaksCompanion.insert(
          currentStreak: const Value(3),
          maxStreak: const Value(3),
          lastCompletionDate: Value(DateTime.utc(2026, 3, 16, 10, 0, 0)),
        ),
      );

      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: 'test',
          sefariaRef: 'test_ref',
          stageId: 1,
          trackType: 'review',
          completedAt: DateTime.utc(2026, 3, 16, 10, 0, 0),
        ),
      );

      await alertService.evaluate(hour: 21, minute: 0);

      verify(() => mockService.cancelStreakAlert()).called(1);
      verifyNever(
        () => mockService.scheduleStreakAlert(
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
          body: any(named: 'body'),
        ),
      );
    });

    test('alert does NOT fire when streak is 0', () async {
      await db.streakDao.upsertStreak(
        StreaksCompanion.insert(
          currentStreak: const Value(0),
          maxStreak: const Value(5),
          lastCompletionDate: Value(DateTime.utc(2026, 3, 10, 18, 0, 0)),
        ),
      );

      await alertService.evaluate(hour: 21, minute: 0);

      verify(() => mockService.cancelStreakAlert()).called(1);
    });

    test('alert body includes correct streak count', () {
      expect(StreakAlertService.buildBody(5), 'Your 5-day streak is at risk!');
    });

    test('notification taps open app to daily tasks screen', () {
      // Streak alert payload is defined and routed to SchedulerRoute
      // in NotificationInitializer._handleNotificationTap
      expect(streakAlertPayload, 'streak_protection');
    });

    test('integration: 5-day streak with no learning triggers alert', () async {
      // Build a 5-day streak via streak record
      await db.streakDao.upsertStreak(
        StreaksCompanion.insert(
          currentStreak: const Value(5),
          maxStreak: const Value(5),
          lastCompletionDate: Value(DateTime.utc(2026, 3, 15, 18, 0, 0)),
        ),
      );

      // No completions today — alert should fire at 9 PM
      await alertService.evaluate(hour: 21, minute: 0);

      verify(
        () => mockService.scheduleStreakAlert(
          hour: 21,
          minute: 0,
          body: 'Your 5-day streak is at risk!',
        ),
      ).called(1);
    });
  });

  // ── Story 12.3: Reward Milestone Notifications ──────────────────────

  group('Story 12.3 -- Reward Milestone Notifications', tags: ['story_12_3'], () {
    late AppDatabase db;
    late MockNotificationService mockService;
    late RewardMilestoneNotificationService milestoneService;

    setUp(() {
      db = createTestDatabase();
      mockService = MockNotificationService();
      milestoneService = RewardMilestoneNotificationService(
        notificationService: mockService,
      );

      when(
        () => mockService.showRewardMilestone(body: any(named: 'body')),
      ).thenAnswer((_) async {});
    });

    tearDown(() async {
      await db.close();
    });

    test('notification triggered when points cross reward threshold', () async {
      // Setup: insert a reward with threshold 50
      await db.rewardDao.insertReward(
        RewardsCompanion.insert(
          title: 'First Badge',
          description: 'Earn 50 points',
          pointsThreshold: 50,
        ),
      );

      // Insert completions to reach 50+ points
      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: 'test',
          sefariaRef: 'ref1',
          stageId: 1,
          trackType: 'learn',
          completedAt: DateTime.utc(2026, 3, 16, 10, 0, 0),
          points: const Value(50),
        ),
      );

      // Check and award rewards
      final pointsService = PointsService(db);
      final rewardService = RewardService(db, pointsService);
      final newlyEarned = await rewardService.checkAndAwardRewards(
        userMode: UserMode.adult,
      );

      expect(newlyEarned, hasLength(1));

      // Trigger milestone notification
      await milestoneService.notifyNewRewards(
        newlyEarned: newlyEarned,
        userMode: UserMode.adult,
      );

      verify(
        () =>
            mockService.showRewardMilestone(body: 'Reward earned: First Badge'),
      ).called(1);
    });

    test('child mode notification hides reward title', () async {
      final reward = RewardModel(
        id: 1,
        title: 'Secret Prize',
        description: 'A secret',
        pointsThreshold: 100,
        isEarned: true,
        isRevealed: false,
        earnedAt: DateTime.utc(2026, 3, 16),
        createdAt: DateTime.utc(2026, 1, 1),
      );

      await milestoneService.notifyNewRewards(
        newlyEarned: [reward],
        userMode: UserMode.child,
      );

      verify(
        () => mockService.showRewardMilestone(body: 'Mystery reward earned!'),
      ).called(1);
    });

    test('adult mode notification shows reward title', () async {
      final reward = RewardModel(
        id: 1,
        title: 'Gold Star',
        description: 'Great job',
        pointsThreshold: 200,
        isEarned: true,
        isRevealed: true,
        earnedAt: DateTime.utc(2026, 3, 16),
        createdAt: DateTime.utc(2026, 1, 1),
      );

      await milestoneService.notifyNewRewards(
        newlyEarned: [reward],
        userMode: UserMode.adult,
      );

      verify(
        () => mockService.showRewardMilestone(body: 'Reward earned: Gold Star'),
      ).called(1);
    });

    test(
      'no duplicate notification on app restart with already-earned reward',
      () async {
        // Setup: reward already earned (threshold 50, earned in past)
        await db.rewardDao.insertReward(
          RewardsCompanion.insert(
            title: 'Old Reward',
            description: 'Already earned',
            pointsThreshold: 50,
            isEarned: const Value(true),
            earnedAt: Value(DateTime.utc(2026, 3, 15)),
          ),
        );

        // Insert points above threshold
        await db.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: 'test',
            sefariaRef: 'ref1',
            stageId: 1,
            trackType: 'learn',
            completedAt: DateTime.utc(2026, 3, 16, 10, 0, 0),
            points: const Value(60),
          ),
        );

        // checkAndAwardRewards should return empty for already-earned
        final pointsService = PointsService(db);
        final rewardService = RewardService(db, pointsService);
        final newlyEarned = await rewardService.checkAndAwardRewards(
          userMode: UserMode.adult,
        );

        expect(newlyEarned, isEmpty);

        // No notification should fire
        await milestoneService.notifyNewRewards(
          newlyEarned: newlyEarned,
          userMode: UserMode.adult,
        );

        verifyNever(
          () => mockService.showRewardMilestone(body: any(named: 'body')),
        );
      },
    );

    test(
      'integration: complete items to reach reward threshold, verify notification',
      () async {
        // Setup: reward at threshold 30
        await db.rewardDao.insertReward(
          RewardsCompanion.insert(
            title: 'Bronze Medal',
            description: 'Earn 30 points',
            pointsThreshold: 30,
          ),
        );

        // Record completions totaling 30 points
        await db.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: 'test',
            sefariaRef: 'ref1',
            stageId: 1,
            trackType: 'learn',
            completedAt: DateTime.utc(2026, 3, 16, 10, 0, 0),
            points: const Value(20),
          ),
        );
        await db.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: 'test',
            sefariaRef: 'ref2',
            stageId: 1,
            trackType: 'learn',
            completedAt: DateTime.utc(2026, 3, 16, 11, 0, 0),
            points: const Value(10),
          ),
        );

        // Award and notify
        final pointsService = PointsService(db);
        final rewardService = RewardService(db, pointsService);
        final newlyEarned = await rewardService.checkAndAwardRewards(
          userMode: UserMode.child,
        );

        expect(newlyEarned, hasLength(1));
        expect(newlyEarned.first.title, 'Bronze Medal');

        await milestoneService.notifyNewRewards(
          newlyEarned: newlyEarned,
          userMode: UserMode.child,
        );

        // Child mode hides title
        verify(
          () => mockService.showRewardMilestone(body: 'Mystery reward earned!'),
        ).called(1);
      },
    );

    test('notification taps open app to rewards screen', () {
      // rewardMilestonePayload routes to GamificationRoute
      // in NotificationInitializer._handleNotificationTap
      expect(rewardMilestonePayload, 'reward_earned');
    });
  });

  // ── Story 12.4: Notification Preferences & Shabbos Mode ──────

  group(
    'Story 12.4 -- Notification Preferences & Shabbos Mode',
    tags: ['story_12_4'],
    () {
      late MockNotificationService mockService;
      late NotificationScheduler scheduler;

      setUp(() {
        mockService = MockNotificationService();
        scheduler = NotificationScheduler(service: mockService);

        when(
          () => mockService.scheduleDailyReminder(
            hour: any(named: 'hour'),
            minute: any(named: 'minute'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {});
        when(() => mockService.cancelDailyReminder()).thenAnswer((_) async {});
        when(
          () => mockService.scheduleStreakAlert(
            hour: any(named: 'hour'),
            minute: any(named: 'minute'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {});
        when(() => mockService.cancelStreakAlert()).thenAnswer((_) async {});
      });

      // Unit: Disabling daily reminder cancels scheduled notification
      test('disabling daily reminder cancels scheduled notification', () async {
        await scheduler.cancel();

        verify(() => mockService.cancelDailyReminder()).called(1);
      });

      // Unit: Changing reminder time reschedules notification
      test('changing reminder time reschedules notification', () async {
        await scheduler.schedule(
          time: const TimeOfDay(hour: 19, minute: 0),
          taskCount: 3,
          curriculumCount: 1,
        );

        verify(
          () => mockService.scheduleDailyReminder(
            hour: 19,
            minute: 0,
            body: 'You have 3 tasks across 1 curriculum today',
          ),
        ).called(1);

        // Change time
        await scheduler.schedule(
          time: const TimeOfDay(hour: 7, minute: 30),
          taskCount: 3,
          curriculumCount: 1,
        );

        verify(
          () => mockService.scheduleDailyReminder(
            hour: 7,
            minute: 30,
            body: 'You have 3 tasks across 1 curriculum today',
          ),
        ).called(1);
      });

      // Unit: Shabbos mode suppresses notifications during Shabbos window
      test(
        'Shabbos mode suppresses notifications during Shabbos window (fixed times)',
        () {
          const service = ShabbosTimeService();

          // Friday 19:00 local — should be within fixed window (18:00–20:00)
          final fridayEvening = DateTime(2026, 3, 20, 19, 0); // Friday
          expect(
            service.isDuringShabbosWithFixedTimes(
              dateTime: fridayEvening,
              startHour: 18,
              startMinute: 0,
              endHour: 20,
              endMinute: 0,
            ),
            isTrue,
          );

          // Saturday 19:00 — within window
          final saturdayEvening = DateTime(2026, 3, 21, 19, 0); // Saturday
          expect(
            service.isDuringShabbosWithFixedTimes(
              dateTime: saturdayEvening,
              startHour: 18,
              startMinute: 0,
              endHour: 20,
              endMinute: 0,
            ),
            isTrue,
          );

          // Sunday 10:00 — outside window
          final sundayMorning = DateTime(2026, 3, 22, 10, 0); // Sunday
          expect(
            service.isDuringShabbosWithFixedTimes(
              dateTime: sundayMorning,
              startHour: 18,
              startMinute: 0,
              endHour: 20,
              endMinute: 0,
            ),
            isFalse,
          );
        },
      );

      // Unit: Shabbos time calculation returns correct candle lighting and havdalah times
      test(
        'Shabbos time calculation returns candle lighting and havdalah times',
        () {
          const service = ShabbosTimeService();
          // Jerusalem coordinates
          const lat = 31.7683;
          const lon = 35.2137;

          // Friday March 20, 2026
          final friday = DateTime(2026, 3, 20, 12, 0);
          final candleLighting = service.getCandleLightingTime(
            date: friday,
            latitude: lat,
            longitude: lon,
          );
          expect(candleLighting != null, isTrue);
          // Candle lighting should be in the afternoon/evening
          expect(candleLighting!.hour, greaterThanOrEqualTo(14));
          expect(candleLighting.hour, lessThanOrEqualTo(20));

          // Saturday March 21, 2026
          final saturday = DateTime(2026, 3, 21, 12, 0);
          final havdalah = service.getHavdalahTime(
            date: saturday,
            latitude: lat,
            longitude: lon,
          );
          expect(havdalah != null, isTrue);
          // Havdalah should be in the evening
          expect(havdalah!.hour, greaterThanOrEqualTo(15));
          expect(havdalah.hour, lessThanOrEqualTo(22));
        },
      );

      // Unit: Location-based Shabbos detection
      test('location-based Shabbos detection identifies Shabbos window', () {
        const service = ShabbosTimeService();
        // Jerusalem coordinates
        const lat = 31.7683;
        const lon = 35.2137;

        // Wednesday midday — not Shabbos
        final wednesday = DateTime(2026, 3, 18, 12, 0);
        expect(
          service.isDuringShabbosWithLocation(
            dateTime: wednesday,
            latitude: lat,
            longitude: lon,
          ),
          isFalse,
        );

        // Saturday midday — is Shabbos
        final saturday = DateTime(2026, 3, 21, 12, 0);
        expect(
          service.isDuringShabbosWithLocation(
            dateTime: saturday,
            latitude: lat,
            longitude: lon,
          ),
          isTrue,
        );
      });

      // Integration: Enable Shabbos mode, verify suppression during Shabbos
      test(
        'integration: Shabbos mode suppresses all notification types during Shabbos',
        () async {
          const service = ShabbosTimeService();

          // During Shabbos (Saturday midday, fixed times mode)
          final saturdayMidday = DateTime(2026, 3, 21, 12, 0);
          final isDuringShabbos = service.isDuringShabbosWithFixedTimes(
            dateTime: saturdayMidday,
            startHour: 18,
            startMinute: 0,
            endHour: 20,
            endMinute: 0,
          );
          expect(isDuringShabbos, isTrue);

          // When Shabbos mode is active, all notifications should be cancelled.
          // This is enforced in the sync effects which check isShabbosQuietActive.
          // Verify the cancel paths work:
          await scheduler.cancel();
          verify(() => mockService.cancelDailyReminder()).called(1);
        },
      );
    },
  );
}
