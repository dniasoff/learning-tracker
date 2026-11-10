import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kosher_dart/kosher_dart.dart';
import 'package:learning_tracker/features/shnayim_mikra/domain/shnayim_mikra_weekly_assignment.dart';

void main() {
  group('ShnayimMikraWeeklyAssignment', () {
    test('matches the upcoming Shabbos parsha in both regions', () {
      final fixture =
          jsonDecode(
                File(
                  'test/fixtures/calendar/parsha_cycle_5787_5788.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final rows = fixture['calendar'] as List<dynamic>;

      for (final raw in rows) {
        final row = raw as Map<String, dynamic>;
        final shabbos = DateTime.parse('${row['date']}T00:00:00');
        if (row['expected'] == 'NONE') continue;
        final friday = shabbos.subtract(const Duration(days: 1));
        final assignment = ShnayimMikraWeeklyAssignment.resolve(
          now: friday,
          inIsrael: row['israel'] as bool,
        );

        expect(assignment.shabbosDate, shabbos);
        expect(assignment.portionKey, row['expected']);
      }
    });

    test('skips festival Shabbos without inventing an assignment', () {
      final assignment = ShnayimMikraWeeklyAssignment.resolve(
        now: DateTime(2027, 6, 11),
        inIsrael: false,
      );

      expect(assignment.shabbosDate, DateTime(2027, 6, 19));
      expect(assignment.portionKey, 'NASSO');
    });

    test('paired parshiyos remain one assignment', () {
      final assignment = ShnayimMikraWeeklyAssignment.resolve(
        now: DateTime(2028, 3, 24),
        inIsrael: true,
      );

      expect(assignment.shabbosDate, DateTime(2028, 3, 25));
      expect(assignment.portionKey, 'VAYAKHEL_PEKUDEI');
    });

    test('overdue catch-up does not block the next weekly assignment', () {
      final projection = ShnayimMikraWeeklyAssignment.project(
        now: DateTime(2027, 6, 20),
        inIsrael: true,
      );

      expect(projection.current.shabbosDate, DateTime(2027, 6, 26));
      expect(
        projection.catchUp.any(
          (assignment) => assignment.shabbosDate == DateTime(2027, 6, 19),
        ),
        isTrue,
      );
    });

    test(
      'due Friday, then catch-up runs through Simchas Torah inclusively',
      () {
        final assignment = ShnayimMikraWeeklyAssignment.resolve(
          now: DateTime(2027, 6, 14),
          inIsrael: true,
        );

        expect(assignment.dueDate, DateTime(2027, 6, 18));
        expect(assignment.isOverdueOn(DateTime(2027, 6, 18)), isFalse);
        expect(assignment.isOverdueOn(DateTime(2027, 6, 19)), isTrue);
        final holiday = JewishCalendar.fromDateTime(assignment.catchUpThrough)
          ..inIsrael = true;
        expect(holiday.getJewishMonth(), JewishDate.TISHREI);
        expect(holiday.getJewishDayOfMonth(), 22);
        expect(
          assignment.isCatchUpAvailableOn(assignment.catchUpThrough),
          isTrue,
        );
        expect(
          assignment.isCatchUpAvailableOn(
            assignment.catchUpThrough.add(const Duration(days: 1)),
          ),
          isFalse,
        );
      },
    );
  });
}
