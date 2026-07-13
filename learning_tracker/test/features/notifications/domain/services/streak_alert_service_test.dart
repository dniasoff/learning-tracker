import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/domain/services/streak_alert_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/drift_memory.dart';
import '../../../../helpers/test_database.dart'
    show createTestDatabase, seedProfileZero;

class MockNotificationGateway extends Mock implements NotificationGateway {}

/// The fixed "today" used across streak tests: 2026-03-16 UTC.
const _today = (year: 2026, month: 3, day: 16);

/// Insert [count] consecutive `completion` streak events ending yesterday
/// (relative to _today = 2026-03-16), so currentStreak == count.
Future<void> _seedStreak(UserDatabase db, int profileId, int count) async {
  // Last day with a completion is yesterday (3/15). Go back [count] days.
  final base = DateTime.utc(_today.year, _today.month, _today.day - 1);
  for (var i = count - 1; i >= 0; i--) {
    final day = base.subtract(Duration(days: i));
    await db.streakEventDao.appendEvent(
      StreakEventsCompanion.insert(
        profileId: profileId,
        eventType: 'completion',
        dayUtc: day,
        eventTimestamp: day.copyWith(hour: 18),
      ),
    );
  }
}

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

    final testDay = DateTime.utc(2026, 3, 16, 12, 0, 0);
    service = StreakAlertService(
      db: db,
      notificationService: mockNotificationGateway,
      profileId: 0,
      clock: clock,
      streakClock: FakeLocalDayClock(testDay),
    );

    // Stub notification service methods (per-profile, H2 fix).
    when(
      () => mockNotificationGateway.scheduleStreakAlertForProfile(
        profileId: any(named: 'profileId'),
        hour: any(named: 'hour'),
        minute: any(named: 'minute'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockNotificationGateway.cancelStreakAlertForProfile(any()),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    await db.close();
  });

  group('StreakAlertService', () {
    test('alert fires when streak > 0 and no completions today', () async {
      // Set up a streak of 5: events on 3/11-3/15 (yesterday relative to 3/16)
      await _seedStreak(db, 0, 5);

      await service.evaluate(hour: 21, minute: 0);

      verify(
        () => mockNotificationGateway.scheduleStreakAlertForProfile(
          profileId: 0,
          hour: 21,
          minute: 0,
          body: 'Your 5-day streak is at risk!',
        ),
      ).called(1);
      verifyNever(
        () => mockNotificationGateway.cancelStreakAlertForProfile(any()),
      );
    });

    test('alert does NOT fire when completions exist today', () async {
      // Set up a streak of 3: events on 3/13-3/15 (streak alive via yesterday)
      await _seedStreak(db, 0, 3);

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

      verify(
        () => mockNotificationGateway.cancelStreakAlertForProfile(0),
      ).called(1);
      verifyNever(
        () => mockNotificationGateway.scheduleStreakAlertForProfile(
          profileId: any(named: 'profileId'),
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
          body: any(named: 'body'),
        ),
      );
    });

    test('alert does NOT fire when streak is 0', () async {
      // Set up a lapsed streak: last event 6 days ago (gap > 1 → currentStreak=0)
      final oldDay = DateTime.utc(2026, 3, 10, 18, 0, 0);
      await db.streakEventDao.appendEvent(
        StreakEventsCompanion.insert(
          profileId: 0,
          eventType: 'completion',
          dayUtc: oldDay,
          eventTimestamp: oldDay,
        ),
      );

      await service.evaluate(hour: 21, minute: 0);

      verify(
        () => mockNotificationGateway.cancelStreakAlertForProfile(0),
      ).called(1);
      verifyNever(
        () => mockNotificationGateway.scheduleStreakAlertForProfile(
          profileId: any(named: 'profileId'),
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
          body: any(named: 'body'),
        ),
      );
    });

    test('alert does NOT fire when no streak record exists', () async {
      await service.evaluate(hour: 21, minute: 0);

      verify(
        () => mockNotificationGateway.cancelStreakAlertForProfile(0),
      ).called(1);
      verifyNever(
        () => mockNotificationGateway.scheduleStreakAlertForProfile(
          profileId: any(named: 'profileId'),
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

      verify(
        () => mockNotificationGateway.cancelStreakAlertForProfile(0),
      ).called(1);
    });

    test('scheduleAlert schedules with correct parameters', () async {
      await service.scheduleAlert(hour: 21, minute: 0, currentStreak: 7);

      verify(
        () => mockNotificationGateway.scheduleStreakAlertForProfile(
          profileId: 0,
          hour: 21,
          minute: 0,
          body: 'Your 7-day streak is at risk!',
        ),
      ).called(1);
    });
  });
}
