import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/domain/services/streak_alert_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/drift_memory.dart' show seedCompletion;
import '../../../../helpers/test_database.dart'
    show createTestDatabase, seedProfileZero;

class MockNotificationGateway extends Mock implements NotificationGateway {}

void main() {
  late UserDatabase db;
  late MockNotificationGateway mockNotificationGateway;
  late StreakAlertService service;
  late DateTime Function() clock;
  late int trackId;

  setUp(() async {
    db = createTestDatabase();
    await seedProfileZero(db);
    mockNotificationGateway = MockNotificationGateway();

    // Default clock: noon UTC
    clock = () => DateTime.utc(2026, 3, 16, 12, 0, 0);

    final trackRow = await db
        .into(db.curriculumTracks)
        .insertReturning(
          CurriculumTracksCompanion.insert(
            profileId: 0,
            curriculumId: 'test',
            stateChangedAt: DateTime.now(),
            activatedAt: DateTime.now(),
          ),
        );
    trackId = trackRow.id;

    service = StreakAlertService(
      db: db,
      notificationService: mockNotificationGateway,
      profileId: 0,
      clock: clock,
    );

    // Stub notification service methods
    when(
      () => mockNotificationGateway.scheduleStreakAlert(
        hour: any(named: 'hour'),
        minute: any(named: 'minute'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockNotificationGateway.cancelStreakAlert(),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    await db.close();
  });

  group('StreakAlertService', () {
    test('alert fires when streak > 0 and no completions today', () async {
      // Set up a streak of 5
      await db.streakEventDao.upsertStreak(
        StreakEventsCompanion.insert(
          profileId: 1,
          currentStreak: const Value(5),
          maxStreak: const Value(5),
          lastCompletionDate: Value(DateTime.utc(2026, 3, 15, 18, 0, 0)),
        ),
      );

      await service.evaluate(hour: 21, minute: 0);

      verify(
        () => mockNotificationGateway.scheduleStreakAlert(
          hour: 21,
          minute: 0,
          body: 'Your 5-day streak is at risk!',
        ),
      ).called(1);
      verifyNever(() => mockNotificationGateway.cancelStreakAlert());
    });

    test('alert does NOT fire when completions exist today', () async {
      // Set up a streak of 3
      await db.streakEventDao.upsertStreak(
        StreakEventsCompanion.insert(
          profileId: 1,
          currentStreak: const Value(3),
          maxStreak: const Value(3),
          lastCompletionDate: Value(DateTime.utc(2026, 3, 16, 10, 0, 0)),
        ),
      );

      // Add a completion today
      await seedCompletion(
        db,
        CompletionEventsCompanion.insert(
          profileId: 0,
          curriculumId: 'test',
          sefariaRef: 'test_ref',
          stageId: 1,
          trackType: 'review',
          trackId: Value(trackId),
          eventTimestamp: DateTime.utc(2026, 3, 16, 10, 0, 0),
        ),
      );

      await service.evaluate(hour: 21, minute: 0);

      verify(() => mockNotificationGateway.cancelStreakAlert()).called(1);
      verifyNever(
        () => mockNotificationGateway.scheduleStreakAlert(
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
          body: any(named: 'body'),
        ),
      );
    });

    test('alert does NOT fire when streak is 0', () async {
      // Set up a streak of 0
      await db.streakEventDao.upsertStreak(
        StreakEventsCompanion.insert(
          profileId: 1,
          currentStreak: const Value(0),
          maxStreak: const Value(5),
          lastCompletionDate: Value(DateTime.utc(2026, 3, 10, 18, 0, 0)),
        ),
      );

      await service.evaluate(hour: 21, minute: 0);

      verify(() => mockNotificationGateway.cancelStreakAlert()).called(1);
      verifyNever(
        () => mockNotificationGateway.scheduleStreakAlert(
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
          body: any(named: 'body'),
        ),
      );
    });

    test('alert does NOT fire when no streak record exists', () async {
      await service.evaluate(hour: 21, minute: 0);

      verify(() => mockNotificationGateway.cancelStreakAlert()).called(1);
      verifyNever(
        () => mockNotificationGateway.scheduleStreakAlert(
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

      verify(() => mockNotificationGateway.cancelStreakAlert()).called(1);
    });

    test('scheduleAlert schedules with correct parameters', () async {
      await service.scheduleAlert(hour: 21, minute: 0, currentStreak: 7);

      verify(
        () => mockNotificationGateway.scheduleStreakAlert(
          hour: 21,
          minute: 0,
          body: 'Your 7-day streak is at risk!',
        ),
      ).called(1);
    });
  });
}
