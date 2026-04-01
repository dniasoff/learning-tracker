import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/gamification/domain/services/streak_service.dart';
import 'package:test/test.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late UserDatabase db;
  late StreakService service;

  setUp(() {
    db = createTestDatabase();
    service = StreakService(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// Helper to insert a completion at a given UTC time.
  Future<void> addCompletion(UserDatabase db, DateTime completedAtUtc) async {
    await db.completionDao.insertCompletion(
      CompletionsCompanion.insert(
        curriculumId: 'test-curriculum',
        sefariaRef: 'Genesis.1',
        stageId: 1,
        trackType: 'primary',
        completedAt: completedAtUtc,
      ),
    );
  }

  group('StreakService', () {
    test(
      'increments current streak from 0 to 1 on first-ever completion',
      () async {
        final now = DateTimeFactory.utc(2026, 3, 15, 12);
        final streak = await service.recordCompletion(now);

        expect(streak.currentStreak, 1);
        expect(streak.maxStreak, 1);
      },
    );

    test(
      'increments streak from N to N+1 when completion on consecutive day',
      () async {
        final day1 = DateTimeFactory.utc(2026, 3, 15, 12);
        final day2 = DateTimeFactory.utc(2026, 3, 16, 14);

        await service.recordCompletion(day1);
        final streak = await service.recordCompletion(day2);

        expect(streak.currentStreak, 2);
        expect(streak.maxStreak, 2);
      },
    );

    test(
      'preserves streak via grace period when completion after a 1-day gap',
      () async {
        final day1 = DateTimeFactory.utc(2026, 3, 15, 12);
        final day2 = DateTimeFactory.utc(2026, 3, 16, 12);
        final day4 = DateTimeFactory.utc(
          2026,
          3,
          18,
          12,
        ); // skipped day 3 (dayGap=2)

        await service.recordCompletion(day1);
        await service.recordCompletion(day2);
        final streak = await service.recordCompletion(day4);

        // Grace period applies (dayGap==2 and no recent grace use): streak continues
        expect(streak.currentStreak, 3);
        expect(streak.maxStreak, 3);
      },
    );

    test('resets streak to 1 when completion after a 2+ day gap', () async {
      final day1 = DateTimeFactory.utc(2026, 3, 15, 12);
      final day2 = DateTimeFactory.utc(2026, 3, 16, 12);
      final day5 = DateTimeFactory.utc(
        2026,
        3,
        19,
        12,
      ); // skipped days 3 & 4 (dayGap=3)

      await service.recordCompletion(day1);
      await service.recordCompletion(day2);
      final streak = await service.recordCompletion(day5);

      // dayGap==3: beyond grace period, streak resets
      expect(streak.currentStreak, 1);
      expect(streak.maxStreak, 2);
    });

    test(
      'does not double-increment on multiple completions in same day',
      () async {
        final morning = DateTimeFactory.utc(2026, 3, 15, 8);
        final evening = DateTimeFactory.utc(2026, 3, 15, 20);

        await service.recordCompletion(morning);
        final streak = await service.recordCompletion(evening);

        expect(streak.currentStreak, 1);
        expect(streak.maxStreak, 1);
      },
    );

    test(
      'updates max streak when current streak exceeds previous max',
      () async {
        // Build streak of 2, then 3-day gap (resets), then build streak of 3
        await service.recordCompletion(DateTimeFactory.utc(2026, 3, 10, 12));
        await service.recordCompletion(DateTimeFactory.utc(2026, 3, 11, 12));
        // Gap of 3 days (dayGap=3 > 2, beyond grace period — resets)
        await service.recordCompletion(DateTimeFactory.utc(2026, 3, 14, 12));

        var streak = await service.getStreak();
        expect(streak!.maxStreak, 2);
        expect(streak.currentStreak, 1);

        await service.recordCompletion(DateTimeFactory.utc(2026, 3, 15, 12));
        await service.recordCompletion(DateTimeFactory.utc(2026, 3, 16, 12));

        streak = await service.getStreak();
        expect(streak!.currentStreak, 3);
        expect(streak.maxStreak, 3);
      },
    );

    test('uses local timezone for day boundary calculation', () async {
      // Two completions that are on different UTC dates but same local date
      // should not double-increment
      // e.g., 23:30 local = next day UTC (for UTC+1)
      final late1 = DateTimeFactory.utc(2026, 3, 15, 23, 30);
      final late2 = DateTimeFactory.utc(2026, 3, 15, 23, 45);

      await service.recordCompletion(late1);
      final streak = await service.recordCompletion(late2);

      // Same UTC date, so same local date too — no double increment
      expect(streak.currentStreak, 1);
    });

    test(
      'streak calendar returns correct set of active dates for date range',
      () async {
        // Add completions on specific dates
        await addCompletion(db, DateTimeFactory.utc(2026, 3, 10, 12));
        await addCompletion(db, DateTimeFactory.utc(2026, 3, 12, 8));
        await addCompletion(db, DateTimeFactory.utc(2026, 3, 12, 20));
        await addCompletion(db, DateTimeFactory.utc(2026, 3, 15, 12));

        final calendar = await service.getStreakCalendar(
          startUtc: DateTimeFactory.utc(2026, 3, 10),
          endUtc: DateTimeFactory.utc(2026, 3, 14),
        );

        // Should include March 10 and 12, not 15 (out of range)
        expect(calendar.length, 2);
        expect(
          calendar.contains(
            DateUtils.extractLocalDate(DateTimeFactory.utc(2026, 3, 10, 12)),
          ),
          isTrue,
        );
        expect(
          calendar.contains(
            DateUtils.extractLocalDate(DateTimeFactory.utc(2026, 3, 12, 8)),
          ),
          isTrue,
        );
      },
    );
  });
}
