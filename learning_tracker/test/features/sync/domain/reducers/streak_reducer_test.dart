import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/streak/streak_event.dart';
import 'package:learning_tracker/features/gamification/streak/streak_reducer.dart';

void main() {
  const reducer = StreakReducer();
  const profileId = 1;

  /// Build a UTC [StreakEvent] of type `completion` on [day] (2026-based).
  StreakEvent completion(DateTime day) => StreakEvent(
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
      expect(state.lastCompletionDayUtc, isNull);
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
          StreakEvent(
            profileId: profileId,
            eventType: 'completion',
            eventTimestamp: DateTime.utc(today.year, today.month, today.day, 8),
          ),
          StreakEvent(
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
        StreakEvent(
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
  });
}
