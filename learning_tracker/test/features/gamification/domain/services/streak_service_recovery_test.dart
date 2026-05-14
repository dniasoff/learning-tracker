// Tests for StreakService.getRecoveryInfo, getStreak, watchStreak — the
// getStreakCalendar path is already covered by streak_service_test.dart.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/gamification/domain/services/streak_service.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late StreakService service;

  setUp(() async {
    db = inMemoryDb();
    service = StreakService(db, profileId: 1);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertStreak({
    int profileId = 1,
    int currentStreak = 5,
    DateTime? graceUsedDate,
    int maxStreak = 10,
  }) async {
    await db.into(db.streaks).insert(
          StreaksCompanion.insert(
            profileId: profileId,
            currentStreak: Value(currentStreak),
            maxStreak: Value(maxStreak),
            graceUsedDate: Value(graceUsedDate),
          ),
        );
  }

  // =========================================================================
  // getRecoveryInfo
  // =========================================================================

  group('StreakService.getRecoveryInfo', () {
    test('returns wasRecovered:false and streak:0 when no streak row exists',
        () async {
      final info = await service.getRecoveryInfo();

      expect(info.wasRecovered, isFalse);
      expect(info.currentStreak, 0);
      expect(info.missedDate, isNull);
    });

    test('returns wasRecovered:false when graceUsedDate is null', () async {
      await insertStreak(graceUsedDate: null, currentStreak: 7);

      final info = await service.getRecoveryInfo();

      expect(info.wasRecovered, isFalse);
      expect(info.currentStreak, 7);
      expect(info.missedDate, isNull);
    });

    test(
      'returns wasRecovered:false when graceUsedDate is not today',
      () async {
        // Use a date clearly in the past.
        final pastDate = DateTime.utc(2020, 1, 1);
        await insertStreak(graceUsedDate: pastDate, currentStreak: 3);

        final info = await service.getRecoveryInfo();

        // The grace date is not the same local day as "now", so wasRecovered
        // is false.
        expect(info.wasRecovered, isFalse);
        expect(info.currentStreak, 3);
      },
    );

    test(
      'returns wasRecovered:true and missedDate when graceUsedDate is today',
      () async {
        // Use today's UTC date so isSameLocalDay returns true.
        final today = DateTime.now().toUtc();
        await insertStreak(graceUsedDate: today, currentStreak: 4);

        final info = await service.getRecoveryInfo();

        expect(info.wasRecovered, isTrue);
        expect(info.currentStreak, 4);
        // missedDate should be yesterday.
        expect(info.missedDate, isNotNull);
      },
    );
  });

  // =========================================================================
  // getStreak
  // =========================================================================

  group('StreakService.getStreak', () {
    test('returns null when no streak row exists', () async {
      final streak = await service.getStreak();
      expect(streak, isNull);
    });

    test('returns streak row when one exists for the profile', () async {
      await insertStreak(currentStreak: 12);

      final streak = await service.getStreak();

      expect(streak, isNotNull);
      expect(streak!.currentStreak, 12);
    });

    test('returns null for a different profileId', () async {
      await insertStreak(profileId: 2, currentStreak: 5);

      // service is scoped to profileId 1
      final streak = await service.getStreak();
      expect(streak, isNull);
    });
  });

  // =========================================================================
  // watchStreak
  // =========================================================================

  group('StreakService.watchStreak', () {
    test('emits null initially when no streak row exists', () async {
      final first = await service.watchStreak().first;
      expect(first, isNull);
    });

    test('emits streak after insertion', () async {
      await insertStreak(currentStreak: 8);

      final first = await service.watchStreak().first;
      expect(first, isNotNull);
      expect(first!.currentStreak, 8);
    });
  });
}
