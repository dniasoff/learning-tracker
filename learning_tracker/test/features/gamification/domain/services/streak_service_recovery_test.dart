// Tests for StreakService.getRecoveryInfo, getStreak, watchStreak — the
// getStreakCalendar path is already covered by streak_service_test.dart.
//
// W3.37: the `streaks` snapshot table was dropped. Streak state is derived
// from `streak_events` via StreakReducer. Seed streak via appendEvent loops.
// getRecoveryInfo always returns wasRecovered:false post-W3.20.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/gamification/domain/services/streak_service.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late StreakService service;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db); // seeds account 1 + profile 1
    // Seed a second profile (id=2) for cross-profile isolation tests.
    await db
        .into(db.learnerProfiles)
        .insert(
          LearnerProfilesCompanion.insert(
            accountId: 1,
            displayName: 'Profile 2',
            mode: 'adult',
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    service = StreakService(db, profileId: 1);
  });

  tearDown(() async {
    await db.close();
  });

  /// Seed [count] consecutive completion events so the reducer returns a
  /// streak of [count]. Events end on today's UTC day.
  Future<void> seedStreak(int count, {int profileId = 1}) async {
    final today = DateTime.now().toUtc();
    for (var i = 0; i < count; i++) {
      final day = today.subtract(Duration(days: count - 1 - i));
      final dayUtc = DateTime.utc(day.year, day.month, day.day);
      await db.streakEventDao.appendEvent(
        StreakEventsCompanion.insert(
          profileId: profileId,
          eventType: 'completion',
          dayUtc: dayUtc,
          eventTimestamp: dayUtc,
        ),
      );
    }
  }

  // =========================================================================
  // getRecoveryInfo
  // =========================================================================

  group('StreakService.getRecoveryInfo', () {
    test(
      'returns wasRecovered:false and streak:0 when no events exist',
      () async {
        final info = await service.getRecoveryInfo();

        expect(info.wasRecovered, isFalse);
        expect(info.currentStreak, 0);
        expect(info.missedDate, isNull);
      },
    );

    test('returns wasRecovered:false with currentStreak from events', () async {
      await seedStreak(7);

      final info = await service.getRecoveryInfo();

      // W3.20: grace-period is not supported; wasRecovered is always false.
      expect(info.wasRecovered, isFalse);
      expect(info.currentStreak, 7);
    });

    test(
      'returns correct currentStreak when only other profile has events',
      () async {
        // Only profile 2 has events — service is scoped to profile 1.
        await seedStreak(5, profileId: 2);

        final info = await service.getRecoveryInfo();

        expect(info.currentStreak, 0);
        expect(info.wasRecovered, isFalse);
      },
    );
  });

  // =========================================================================
  // getStreak
  // =========================================================================

  group('StreakService.getStreak', () {
    test('returns empty state when no events exist', () async {
      final streak = await service.getStreak();
      expect(streak.currentStreak, 0);
      expect(streak.maxStreak, 0);
    });

    test('returns correct streak derived from events', () async {
      await seedStreak(12);

      final streak = await service.getStreak();

      expect(streak.currentStreak, 12);
    });

    test('events for different profileId do not affect this service', () async {
      await seedStreak(5, profileId: 2);

      // service is scoped to profileId 1
      final streak = await service.getStreak();
      expect(streak.currentStreak, 0);
    });
  });

  // =========================================================================
  // watchStreak
  // =========================================================================

  group('StreakService.watchStreak', () {
    test('emits empty state initially when no events exist', () async {
      final first = await service.watchStreak().first;
      expect(first.currentStreak, 0);
    });

    test('emits correct streak after events are inserted', () async {
      await seedStreak(8);

      final first = await service.watchStreak().first;
      expect(first.currentStreak, 8);
    });
  });
}
