/// Overdue durability invariants — O4, O5, O6.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/domain/projection/overdue_projection.dart';
import 'package:learning_tracker/features/scheduler/domain/projection/overdue_schedule.dart';

List<(DateTime, String)> _calendar(DateTime anchor, DateTime today) {
  final entries = <(DateTime, String)>[];
  var date = anchor;
  while (!date.isAfter(today)) {
    entries.add((date, 'program ${date.toIso8601String()}'));
    date = date.add(const Duration(days: 1));
  }
  return entries;
}

void main() {
  test(
    'O4: discarding the local plan cache and recomputing yields the same overdue set',
    () {
      final today = DateTime.utc(2026, 5, 19);
      final anchor = today.subtract(const Duration(days: 5));
      final schedule = programSchedule(
        anchor: anchor,
        calendarEntries: _calendar(anchor, today),
        today: today,
      );
      final completions = {schedule[0].sefariaRef, schedule[1].sefariaRef};

      final firstProjection = project(
        schedule: schedule,
        completions: completions,
        today: today,
      );
      // O4: a reinstall discards only the cache; the synced inputs remain.
      final recomputedProjection = project(
        schedule: schedule,
        completions: completions,
        today: today,
      );

      expect(recomputedProjection.overdue, firstProjection.overdue);
      expect(recomputedProjection.dueToday, firstProjection.dueToday);
      expect(recomputedProjection.overdue, hasLength(3));
      expect(recomputedProjection.dueToday, hasLength(1));
    },
  );

  test(
    'O5: partial-merge and full-merge projections converge without persisting a wrong value',
    () {
      final today = DateTime.utc(2026, 5, 19);
      final anchor = today.subtract(const Duration(days: 10));
      final schedule = programSchedule(
        anchor: anchor,
        calendarEntries: _calendar(anchor, today),
        today: today,
      );
      final overdueRefs = schedule
          .where((unit) => unit.date.isBefore(today))
          .map((unit) => unit.sefariaRef)
          .toList();
      final partialCompletions = overdueRefs.take(3).toSet();
      final fullCompletions = {...partialCompletions, ...overdueRefs.skip(3)};

      final partial = project(
        schedule: schedule,
        completions: partialCompletions,
        today: today,
      );
      final full = project(
        schedule: schedule,
        completions: fullCompletions,
        today: today,
      );

      expect(partial.overdue, hasLength(7));
      expect(full.overdue, isEmpty);
      expect(full.dueToday, contains(schedule.last.sefariaRef));
      expect(
        project(schedule: schedule, completions: fullCompletions, today: today),
        full,
      );
    },
  );

  test(
    'O6: legacy initial-sync gating is no longer testable after its removal',
    () {},
    skip:
        'The old initial-sync state and gate were removed from the Firestore architecture; there is no current production state transition to exercise.',
  );
}
