/// Extended tests for StreakService covering getRecoveryInfo, getStreak,
/// and watchStreak — methods not exercised by streak_service_test.dart.
///
/// W3.22: streak_events uses event-log model. upsertStreakByProfile removed.
/// Seed streak via appendEvent loops instead.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/gamification/domain/services/streak_service.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late StreakService service;
  const profileId = 1;

  setUp(() async {
    db = inMemoryDb();
    service = StreakService(db, profileId: profileId);
    await seedProfile(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── helpers ───────────────────────────────────────────────────────────────

  /// Seeds [count] consecutive daily completion events ending on [lastDay]
  /// (defaults to today UTC).
  Future<void> seedStreakEvents({int count = 5, DateTime? lastDay}) async {
    final now = DateTime.now().toUtc();
    final base = lastDay ?? DateTime.utc(now.year, now.month, now.day);
    for (var i = count - 1; i >= 0; i--) {
      final day = base.subtract(Duration(days: i));
      await db.streakEventDao.appendEvent(
        StreakEventsCompanion.insert(
          profileId: profileId,
          eventType: 'completion',
          dayUtc: day,
          eventTimestamp: day,
        ),
      );
    }
  }

  // ── getStreak ─────────────────────────────────────────────────────────────

  group('StreakService.getStreak', () {
    test('returns StreakState.empty when no events exist', () async {
      final streak = await service.getStreak();
      expect(streak.currentStreak, 0);
      expect(streak.maxStreak, 0);
    });

    test('returns correct currentStreak after seeding events', () async {
      await seedStreakEvents(count: 7);

      final streak = await service.getStreak();
      expect(streak.currentStreak, greaterThanOrEqualTo(1));
      expect(streak.maxStreak, greaterThanOrEqualTo(streak.currentStreak));
    });
  });

  // ── watchStreak ───────────────────────────────────────────────────────────

  group('StreakService.watchStreak', () {
    test('emits StreakState when no events exist', () async {
      final streak = await service.watchStreak().first;
      expect(streak.currentStreak, 0);
    });

    test('emits updated streak after events are appended', () async {
      await seedStreakEvents(count: 3);

      final streak = await service.watchStreak().first;
      expect(streak.currentStreak, greaterThanOrEqualTo(1));
    });
  });

  // ── getRecoveryInfo ───────────────────────────────────────────────────────

  group('StreakService.getRecoveryInfo', () {
    test(
      'returns wasRecovered=false and currentStreak=0 when no events',
      () async {
        final info = await service.getRecoveryInfo();
        expect(info.wasRecovered, isFalse);
        expect(info.currentStreak, 0);
        expect(info.missedDate, isNull);
      },
    );

    test(
      'returns wasRecovered=false (grace period removed in W3.22)',
      () async {
        await seedStreakEvents(count: 5);

        final info = await service.getRecoveryInfo();
        // graceUsedDate removed in W3.22; wasRecovered always false
        expect(info.wasRecovered, isFalse);
        expect(info.currentStreak, greaterThanOrEqualTo(1));
      },
    );

    test('returns correct currentStreak even without recovery', () async {
      await seedStreakEvents(count: 15);

      final info = await service.getRecoveryInfo();
      expect(info.currentStreak, greaterThanOrEqualTo(1));
      expect(info.wasRecovered, isFalse);
    });
  });
}
