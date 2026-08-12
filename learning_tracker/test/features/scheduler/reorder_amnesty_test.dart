/// Pure reorder-amnesty projection tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/domain/projection/amnesty_cutoff.dart';
import 'package:learning_tracker/features/scheduler/domain/projection/overdue_projection.dart';
import 'package:learning_tracker/features/scheduler/domain/projection/overdue_schedule.dart';
import 'package:learning_tracker/features/scheduler/domain/projection/overdue_types.dart';

List<String> _refs(int count) => List.generate(count, (i) => 'unit-$i');

void main() {
  test(
    'projection amnesty keeps overdue items scheduled on or after the reorder day',
    () {
      final today = DateTime.utc(2026, 5, 20);
      final anchor = today.subtract(const Duration(days: 4));
      final refs = _refs(5);
      final schedule = selfPacedSchedule(
        anchor: anchor,
        pace: 1,
        studyDayPattern: StudyDayPattern.everyDay,
        orderedRefs: refs,
        today: today,
      );
      final projection = project(
        schedule: schedule,
        completions: const {},
        today: today,
      );
      final reorderAt = anchor.add(const Duration(days: 2, hours: 15));
      final cutoff = amnestyDayCutoffUtc(reorderAt);
      final scheduleIndex = {
        for (final unit in schedule) unit.sefariaRef: unit.date,
      };

      final amnestied = projection.overdue.where((ref) {
        final scheduled = scheduleIndex[ref];
        return scheduled != null && scheduled.isBefore(cutoff);
      }).toSet();
      final remaining = projection.overdue.difference(amnestied);

      expect(amnestied, {'unit-0', 'unit-1'});
      expect(remaining, {'unit-2', 'unit-3'});
    },
  );

  test('mid-day reorder does not amnesty the same local calendar day', () {
    final today = DateTime.utc(2026, 5, 21);
    final yesterday = DateTime.utc(2026, 5, 20);
    final schedule = [
      ScheduledUnit(date: yesterday, sefariaRef: 'yesterday'),
      ScheduledUnit(date: today, sefariaRef: 'today'),
    ];
    final projection = project(
      schedule: schedule,
      completions: const {},
      today: today,
    );

    final cutoff = amnestyDayCutoffUtc(DateTime.utc(2026, 5, 20, 15));
    final amnestied = projection.overdue.where((ref) {
      final scheduled = schedule
          .firstWhere((unit) => unit.sefariaRef == ref)
          .date;
      return scheduled.isBefore(cutoff);
    });

    expect(amnestied, isEmpty);
    expect(projection.overdue, {'yesterday'});
  });

  test('program back-date clamp preserves the intended overdue window', () {
    final today = DateTime.utc(2026, 5, 25);
    final anchor = today.subtract(const Duration(days: 4));
    final refs = ['D21', 'D22', 'D23', 'D24', 'D25'];
    final schedule = programSchedule(
      anchor: anchor,
      calendarEntries: [
        for (var i = 0; i < refs.length; i++)
          (anchor.add(Duration(days: i)), refs[i]),
      ],
      today: today,
    );
    final projection = project(
      schedule: schedule,
      completions: const {},
      today: today,
    );
    final rawCutoff = amnestyDayCutoffUtc(today);
    final clampedCutoff = clampAmnestyCutoffToAnchor(rawCutoff, anchor);
    final scheduleIndex = {
      for (final unit in schedule) unit.sefariaRef: unit.date,
    };

    final clampedAmnestied = projection.overdue.where((ref) {
      return scheduleIndex[ref]!.isBefore(clampedCutoff);
    });
    final unclampedAmnestied = projection.overdue.where((ref) {
      return scheduleIndex[ref]!.isBefore(rawCutoff);
    });

    expect(clampedAmnestied, isEmpty);
    expect(unclampedAmnestied, {'D21', 'D22', 'D23', 'D24'});
  });

  test(
    'legacy persistence stamping is not part of the pure projection contract',
    () {},
    skip:
        'Possible production gap: the old Drift learning-order write stamped lastReorderAt, but the Firestore learning-order adapter has no equivalent stamp method; this file covers the portable projection/amnesty rules directly.',
  );
}
