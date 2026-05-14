/// Extended tests for StreakService covering getRecoveryInfo, getStreak,
/// and watchStreak — methods not exercised by streak_service_test.dart.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/gamification/domain/services/streak_service.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late StreakService service;
  const profileId = 1;

  setUp(() {
    db = inMemoryDb();
    service = StreakService(db, profileId: profileId);
  });

  tearDown(() async {
    await db.close();
  });

  // ── helpers ───────────────────────────────────────────────────────────────

  Future<void> upsertStreak({
    int current = 5,
    int max = 10,
    DateTime? lastCompletion,
    DateTime? graceUsedDate,
  }) async {
    await db.streakDao.upsertStreakByProfile(
      profileId,
      StreaksCompanion(
        currentStreak: Value(current),
        maxStreak: Value(max),
        lastCompletionDate: Value(lastCompletion),
        graceUsedDate: Value(graceUsedDate),
      ),
    );
  }

  // ── getStreak ─────────────────────────────────────────────────────────────

  group('StreakService.getStreak', () {
    test('returns null when no streak exists', () async {
      final streak = await service.getStreak();
      expect(streak, isNull);
    });

    test('returns the streak row for the profile', () async {
      await upsertStreak(current: 7, max: 12);

      final streak = await service.getStreak();
      expect(streak, isNotNull);
      expect(streak!.currentStreak, 7);
      expect(streak.maxStreak, 12);
      expect(streak.profileId, profileId);
    });
  });

  // ── watchStreak ───────────────────────────────────────────────────────────

  group('StreakService.watchStreak', () {
    test('emits null when no streak exists', () async {
      final streak = await service.watchStreak().first;
      expect(streak, isNull);
    });

    test('emits the streak when one is inserted', () async {
      await upsertStreak(current: 3, max: 5);

      final streak = await service.watchStreak().first;
      expect(streak, isNotNull);
      expect(streak!.currentStreak, 3);
    });

    test('emits updated value when streak changes', () async {
      final emitted = <int?>[];
      final sub = service.watchStreak().listen(
        (s) => emitted.add(s?.currentStreak),
      );
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(emitted, isNotEmpty);

      await upsertStreak(current: 8, max: 8);
      await Future<void>.delayed(Duration.zero);

      expect(emitted.last, 8);
    });
  });

  // ── getRecoveryInfo ───────────────────────────────────────────────────────

  group('StreakService.getRecoveryInfo', () {
    test('returns wasRecovered=false and currentStreak=0 when no streak',
        () async {
      final info = await service.getRecoveryInfo();
      expect(info.wasRecovered, isFalse);
      expect(info.currentStreak, 0);
      expect(info.missedDate, isNull);
    });

    test('returns wasRecovered=false when graceUsedDate is null', () async {
      await upsertStreak(current: 5, max: 5);

      final info = await service.getRecoveryInfo();
      expect(info.wasRecovered, isFalse);
      expect(info.currentStreak, 5);
    });

    test('returns wasRecovered=false when graceUsedDate was on a different day',
        () async {
      // graceUsedDate set to a past day, not today
      await upsertStreak(
        current: 5,
        max: 5,
        graceUsedDate: DateTime.utc(2020, 1, 1),
      );

      final info = await service.getRecoveryInfo();
      expect(info.wasRecovered, isFalse);
    });

    test('returns correct currentStreak even without recovery', () async {
      await upsertStreak(current: 15, max: 20);

      final info = await service.getRecoveryInfo();
      expect(info.currentStreak, 15);
      expect(info.wasRecovered, isFalse);
    });
  });
}
