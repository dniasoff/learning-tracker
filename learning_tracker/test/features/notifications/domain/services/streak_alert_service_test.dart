import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';
import 'package:learning_tracker/features/notifications/domain/services/streak_alert_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_database.dart';

class MockNotificationService extends Mock implements NotificationService {}

void main() {
  late UserDatabase db;
  late MockNotificationService mockNotificationService;
  late StreakAlertService service;
  late DateTime Function() clock;
  late int trackId;

  setUp(() async {
    db = createTestDatabase();
    mockNotificationService = MockNotificationService();

    // Default clock: noon UTC
    clock = () => DateTime.utc(2026, 3, 16, 12, 0, 0);

    final trackRow = await db
        .into(db.curriculumTracks)
        .insertReturning(
          CurriculumTracksCompanion.insert(
            curriculumId: 'test',
            trackType: 'review',
            activatedAt: DateTime.now(),
          ),
        );
    trackId = trackRow.id;

    service = StreakAlertService(
      db: db,
      notificationService: mockNotificationService,
      clock: clock,
    );

    // Stub notification service methods
    when(
      () => mockNotificationService.scheduleStreakAlert(
        hour: any(named: 'hour'),
        minute: any(named: 'minute'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockNotificationService.cancelStreakAlert(),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    await db.close();
  });

  group('StreakAlertService', () {
    test('alert fires when streak > 0 and no completions today', () async {
      // Set up a streak of 5
      await db.streakDao.upsertStreak(
        StreaksCompanion.insert(
          currentStreak: const Value(5),
          maxStreak: const Value(5),
          lastCompletionDate: Value(DateTime.utc(2026, 3, 15, 18, 0, 0)),
        ),
      );

      await service.evaluate(hour: 21, minute: 0);

      verify(
        () => mockNotificationService.scheduleStreakAlert(
          hour: 21,
          minute: 0,
          body: 'Your 5-day streak is at risk!',
        ),
      ).called(1);
      verifyNever(() => mockNotificationService.cancelStreakAlert());
    });

    test('alert does NOT fire when completions exist today', () async {
      // Set up a streak of 3
      await db.streakDao.upsertStreak(
        StreaksCompanion.insert(
          currentStreak: const Value(3),
          maxStreak: const Value(3),
          lastCompletionDate: Value(DateTime.utc(2026, 3, 16, 10, 0, 0)),
        ),
      );

      // Add a completion today
      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: 'test',
          sefariaRef: 'test_ref',
          stageId: 1,
          trackType: 'review',
          trackId: trackId,
          completedAt: DateTime.utc(2026, 3, 16, 10, 0, 0),
        ),
      );

      await service.evaluate(hour: 21, minute: 0);

      verify(() => mockNotificationService.cancelStreakAlert()).called(1);
      verifyNever(
        () => mockNotificationService.scheduleStreakAlert(
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
          body: any(named: 'body'),
        ),
      );
    });

    test('alert does NOT fire when streak is 0', () async {
      // Set up a streak of 0
      await db.streakDao.upsertStreak(
        StreaksCompanion.insert(
          currentStreak: const Value(0),
          maxStreak: const Value(5),
          lastCompletionDate: Value(DateTime.utc(2026, 3, 10, 18, 0, 0)),
        ),
      );

      await service.evaluate(hour: 21, minute: 0);

      verify(() => mockNotificationService.cancelStreakAlert()).called(1);
      verifyNever(
        () => mockNotificationService.scheduleStreakAlert(
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
          body: any(named: 'body'),
        ),
      );
    });

    test('alert does NOT fire when no streak record exists', () async {
      await service.evaluate(hour: 21, minute: 0);

      verify(() => mockNotificationService.cancelStreakAlert()).called(1);
      verifyNever(
        () => mockNotificationService.scheduleStreakAlert(
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
          body: any(named: 'body'),
        ),
      );
    });

    test('alert body includes correct streak count', () {
      expect(StreakAlertService.buildBody(5), 'Your 5-day streak is at risk!');
      expect(StreakAlertService.buildBody(1), 'Your 1-day streak is at risk!');
      expect(
        StreakAlertService.buildBody(100),
        'Your 100-day streak is at risk!',
      );
    });

    test('onCompletionRecorded cancels the alert', () async {
      await service.onCompletionRecorded();

      verify(() => mockNotificationService.cancelStreakAlert()).called(1);
    });

    test('scheduleAlert schedules with correct parameters', () async {
      await service.scheduleAlert(hour: 21, minute: 0, currentStreak: 7);

      verify(
        () => mockNotificationService.scheduleStreakAlert(
          hour: 21,
          minute: 0,
          body: 'Your 7-day streak is at risk!',
        ),
      ).called(1);
    });
  });
}
