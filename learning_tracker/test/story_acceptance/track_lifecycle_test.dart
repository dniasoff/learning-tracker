/// Pure track-lifecycle projection acceptance tests.
@Tags(['track_lifecycle'])
library;

import 'package:learning_tracker/features/scheduler/domain/projection/projection.dart';
import 'package:test/test.dart';

void main() {
  group('A — overdue detection via pure projection', tags: ['track_lifecycle'], () {
    final anchor = DateTime.utc(2026, 5, 14);
    final today = DateTime.utc(2026, 5, 17);
    final refs = List.generate(10, (i) => 'ref_$i');
    const weekdays = StudyDayPattern({1, 2, 3, 4, 5});

    test('elapsed study days become overdue tasks', () {
      final result = project(
        schedule: selfPacedSchedule(
          anchor: anchor,
          pace: 1,
          studyDayPattern: weekdays,
          orderedRefs: refs,
          today: today,
        ),
        completions: {},
        today: today,
      );
      expect(result.overdue.length, 2);
    });

    test('today is represented in dueToday on a study day', () {
      final monday = DateTime.utc(2026, 5, 18);
      final result = project(
        schedule: selfPacedSchedule(
          anchor: DateTime.utc(2026, 5, 11),
          pace: 1,
          studyDayPattern: weekdays,
          orderedRefs: refs,
          today: monday,
        ),
        completions: {},
        today: monday,
      );
      expect(result.dueToday, hasLength(1));
    });

    test('completed references leave the overdue projection', () {
      final result = project(
        schedule: selfPacedSchedule(
          anchor: anchor,
          pace: 1,
          studyDayPattern: weekdays,
          orderedRefs: refs,
          today: today,
        ),
        completions: {'ref_0', 'ref_1'},
        today: today,
      );
      expect(result.overdue, isEmpty);
    });

    test('missing pace is rejected for self-paced schedules', () {
      expect(
        () => selfPacedSchedule(
          anchor: anchor,
          pace: null,
          studyDayPattern: weekdays,
          orderedRefs: refs,
          today: today,
        ),
        throwsA(isA<MissingPaceError>()),
      );
    });

    test('non-positive pace is rejected as invalid input', () {
      expect(
        () => selfPacedSchedule(
          anchor: anchor,
          pace: 0,
          studyDayPattern: weekdays,
          orderedRefs: refs,
          today: today,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('B–E — persisted track lifecycle', tags: ['track_lifecycle'], skip:
      'Blocked: delete/restore, daily-plan cache, aggregate-count, and multi-profile isolation tests directly call Drift TrackDao/CompletionDao/DailyPlanDao. Firestore track/ledger repositories do not expose these aggregate lifecycle contracts yet.',
      () {
    test('placeholder for the pending Firestore track-lifecycle seam', () {});
  });
}
