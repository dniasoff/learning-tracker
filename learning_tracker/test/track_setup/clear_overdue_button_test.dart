/// Clear-overdue projection coverage.
///
/// The projection assertions are backend-independent. The write-through case
/// remains an individual skip because EditTrackScreen still combines the
/// Firestore profile-program adapter with calendarProgramServiceProvider,
/// whose LocalCalendarEngine is backed by the local content database rather
/// than a Firestore calendar seam.
library;
// ignore_for_file: directives_ordering, unused_element_parameter, prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/domain/projection/projection.dart';

List<(DateTime, String)> _calendar(DateTime start, DateTime end) {
  final values = <(DateTime, String)>[];
  for (
    var day = start;
    !day.isAfter(end);
    day = day.add(const Duration(days: 1))
  ) {
    values.add((day, 'program ${day.toIso8601String()}'));
  }
  return values;
}

void main() {
  final today = DateTime.utc(2026, 5, 19);
  final anchor = today.subtract(const Duration(days: 4));

  test('anchored program has four overdue units and one today unit', () {
    final projection = project(
      schedule: programSchedule(
        anchor: anchor,
        calendarEntries: _calendar(anchor, today),
        today: today,
      ),
      completions: {},
      today: today,
    );
    expect(projection.overdue, hasLength(4));
    expect(projection.dueToday, hasLength(1));
  });

  test('re-anchoring the pure projection to today clears overdue work', () {
    final projection = project(
      schedule: programSchedule(
        anchor: today,
        calendarEntries: _calendar(today, today),
        today: today,
      ),
      completions: {},
      today: today,
    );
    expect(projection.overdue, isEmpty);
    expect(projection.dueToday, hasLength(1));
  });

  test(
    'Firestore profile-program write/readback is an individual skip',
    () {},
    skip:
        'EditTrackScreen._clearOverdue has a Firestore profile-program adapter, but its calendarProgramServiceProvider still resolves through the local content database; no Firestore-backed calendar seam is available within the requested test-only scope.',
  );
}
