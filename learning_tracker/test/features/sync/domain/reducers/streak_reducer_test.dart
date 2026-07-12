import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/streak/streak_log_event.dart';
import 'package:learning_tracker/features/gamification/streak/streak_reducer.dart';

void main() {
  const reducer = StreakReducer();
  const profileId = 1;

  /// Build a UTC [StreakLogEvent] of type `completion` on [day] (2026-based).
  StreakLogEvent completion(DateTime day) => StreakLogEvent(
    profileId: profileId,
    eventType: 'completion',
    eventTimestamp: DateTime.utc(day.year, day.month, day.day, 12),
  );

  /// Today anchor used across tests.
  final today = DateTime.utc(2026, 5, 14);
  final yesterday = today.subtract(const Duration(days: 1));
  final twoDaysAgo = today.subtract(const Duration(days: 2));
  final threeDaysAgo = today.subtract(const Duration(days: 3));

  group('StreakReducer', () {
    test('1 — empty event list yields streak = 0', () {
      final state = reducer.reduce([], today: today);
      expect(state.currentStreak, 0);
      expect(state.maxStreak, 0);
      expect(state.lastCompletionDayLocal, isNull);
    });

    test('2 — single event today yields current streak = 1', () {
      final state = reducer.reduce([completion(today)], today: today);
      expect(state.currentStreak, 1);
      expect(state.maxStreak, 1);
    });

    test(
      '3 — single event yesterday yields current streak = 1 (streak alive)',
      () {
        final state = reducer.reduce([completion(yesterday)], today: today);
        expect(state.currentStreak, 1);
        expect(state.maxStreak, 1);
      },
    );

    test('4 — three consecutive days yields streak = 3', () {
      final events = [
        completion(threeDaysAgo),
        completion(twoDaysAgo),
        completion(yesterday),
      ];
      final state = reducer.reduce(events, today: today);
      expect(state.currentStreak, 3);
      expect(state.maxStreak, 3);
    });

    test(
      '5 — gap of 2+ days with no recent event yields current streak = 0',
      () {
        // Last completion was 3 days ago — gap to today is 3 which is > 1.
        final state = reducer.reduce([completion(threeDaysAgo)], today: today);
        expect(state.currentStreak, 0);
        // maxStreak captures the historical run (1 day).
        expect(state.maxStreak, 1);
      },
    );

    test(
      '6 — multiple completions on the same day count as one streak day',
      () {
        final events = [
          StreakLogEvent(
            profileId: profileId,
            eventType: 'completion',
            eventTimestamp: DateTime.utc(today.year, today.month, today.day, 8),
          ),
          StreakLogEvent(
            profileId: profileId,
            eventType: 'completion',
            eventTimestamp: DateTime.utc(
              today.year,
              today.month,
              today.day,
              20,
            ),
          ),
        ];
        final state = reducer.reduce(events, today: today);
        expect(state.currentStreak, 1);
        expect(state.maxStreak, 1);
      },
    );

    test('7 — non-completion events are ignored', () {
      final events = [
        StreakLogEvent(
          profileId: profileId,
          eventType: 'day_boundary',
          eventTimestamp: DateTime.utc(today.year, today.month, today.day, 0),
        ),
      ];
      final state = reducer.reduce(events, today: today);
      expect(state.currentStreak, 0);
      expect(state.maxStreak, 0);
    });

    test('8 — max streak survives after current streak lapses', () {
      // Build a 3-day run that ended 5 days ago, with no recent event.
      final fiveDaysAgo = today.subtract(const Duration(days: 5));
      final fourDaysAgo = today.subtract(const Duration(days: 4));
      final events = [
        completion(today.subtract(const Duration(days: 6))),
        completion(fiveDaysAgo),
        completion(fourDaysAgo),
      ];
      final state = reducer.reduce(events, today: today);
      expect(state.currentStreak, 0);
      expect(state.maxStreak, 3);
    });

    // ── D16: buckets by LOCAL day, not UTC ─────────────────────────────────
    test(
      'D16: two completions on consecutive LOCAL days that share one UTC day '
      'count as TWO streak days (local bucketing), not one (UTC bucketing)',
      () {
        // Simulate US-Pacific (UTC-8), independent of the host timezone:
        //   Mon 23:00 PT = Tue 07:00 UTC
        //   Tue 01:00 PT = Tue 09:00 UTC   ← same UTC day, different LOCAL day
        DateTime pacificDay(DateTime t) {
          final pt = t.toUtc().subtract(const Duration(hours: 8));
          return DateTime.utc(pt.year, pt.month, pt.day);
        }

        DateTime utcDay(DateTime t) {
          final u = t.toUtc();
          return DateTime.utc(u.year, u.month, u.day);
        }

        final events = [
          StreakLogEvent(
            profileId: profileId,
            eventType: 'completion',
            eventTimestamp: DateTime.utc(2026, 5, 12, 7), // Mon 23:00 PT
          ),
          StreakLogEvent(
            profileId: profileId,
            eventType: 'completion',
            eventTimestamp: DateTime.utc(2026, 5, 12, 9), // Tue 01:00 PT
          ),
        ];
        final anchor = DateTime.utc(2026, 5, 12, 9);

        // The fix — LOCAL day bucketing keeps the two days distinct.
        final local = reducer.reduce(events, today: anchor, dayOf: pacificDay);
        expect(local.currentStreak, 2);
        expect(local.maxStreak, 2);

        // The bug — UTC bucketing merges them into a single day.
        final utc = reducer.reduce(events, today: anchor, dayOf: utcDay);
        expect(utc.currentStreak, 1);
      },
    );
  });
}
