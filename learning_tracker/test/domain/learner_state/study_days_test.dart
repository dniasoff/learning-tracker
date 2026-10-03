// Mirror test for `lib/domain/learner_state/study_days.dart` (AD-35 study
// days, AD-44 `studyDaysToDeadline`). September 2026: the 1st is a Tuesday,
// the 5th a Saturday, the 7th a Monday.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/study_days.dart';

Map<String, Object?> _doc(Object? dow, Object? type) => {
  dayOfWeekKey: dow,
  dayTypeKey: type,
};

void main() {
  group('weekdayOf / shiftCivilDate', () {
    test('weekdayOf is ISO (1 = Monday ... 7 = Sunday)', () {
      expect(weekdayOf('2026-09-07'), DateTime.monday);
      expect(weekdayOf('2026-09-01'), DateTime.tuesday);
      expect(weekdayOf('2026-09-06'), DateTime.sunday);
    });

    test('shiftCivilDate crosses month and year bounds, both directions', () {
      expect(shiftCivilDate('2026-09-30', 1), '2026-10-01');
      expect(shiftCivilDate('2026-12-31', 1), '2027-01-01');
      expect(shiftCivilDate('2026-03-01', -1), '2026-02-28');
      expect(shiftCivilDate('2026-09-07', 0), '2026-09-07');
    });
  });

  group('StudyDays.everyDay', () {
    final days = StudyDays.everyDay();

    test('every weekday is a study day and active', () {
      expect(days.studyWeekdays, {1, 2, 3, 4, 5, 6, 7});
      expect(days.activeWeekdays, {1, 2, 3, 4, 5, 6, 7});
      expect(days.isStudyDay('2026-09-05'), isTrue);
    });

    test('countStudyDays is the inclusive day span', () {
      expect(days.countStudyDays('2026-09-07', '2026-09-07'), 1);
      expect(days.countStudyDays('2026-09-07', '2026-09-13'), 7);
      expect(days.countStudyDays('2026-09-01', '2026-09-30'), 30);
    });
  });

  group('StudyDays.fromFields', () {
    test('no readable doc defaults to every day', () {
      expect(StudyDays.fromFields(const []), StudyDays.everyDay());
      expect(
        StudyDays.fromFields([_doc(0, 'study'), _doc(8, 'study')]),
        StudyDays.everyDay(),
      );
    });

    test('skips docs without an int 1-7 weekday or a string type', () {
      final days = StudyDays.fromFields([
        _doc('1', 'study'),
        _doc(2, null),
        _doc(3, 5),
        {dayTypeKey: 'study'},
        _doc(4, 'study'),
      ]);
      expect(days.studyWeekdays, {4});
      expect(days.activeWeekdays, {4});
    });

    test('study days are study; other types are review-only but active', () {
      final days = StudyDays.fromFields([
        _doc(1, 'study'),
        _doc(5, 'review'),
        _doc(6, 'review'),
      ]);
      expect(days.studyWeekdays, {1});
      expect(days.activeWeekdays, {1, 5, 6});
      expect(days.isStudyDay('2026-09-07'), isTrue);
      expect(days.isStudyDay('2026-09-05'), isFalse);
    });

    test('all-review config has no study weekday', () {
      final days = StudyDays.fromFields([_doc(1, 'review')]);
      expect(days.studyWeekdays, isEmpty);
      expect(days.countStudyDays('2026-09-01', '2026-09-30'), 0);
    });

    test('the sets are unmodifiable and study days are always active', () {
      final days = StudyDays(studyWeekdays: {2}, activeWeekdays: {3});
      expect(days.activeWeekdays, {2, 3});
      expect(() => days.studyWeekdays.add(1), throwsUnsupportedError);
      expect(() => days.activeWeekdays.add(1), throwsUnsupportedError);
    });
  });

  group('StudyDays.fromDocs', () {
    MainTrackConfigDoc doc(int dow, String type, {DateTime? endedAt}) =>
        MainTrackConfigDoc(
          collection: MainTrackConfigDoc.studyDays,
          docId: 'mishnayos_$dow',
          curriculumId: 'mishnayos',
          fields: {dayOfWeekKey: dow, dayTypeKey: type},
          endedAt: endedAt,
        );

    test('ended docs are ignored', () {
      final days = StudyDays.fromDocs([
        doc(1, 'study'),
        doc(2, 'study', endedAt: DateTime.utc(2026, 9)),
      ]);
      expect(days.studyWeekdays, {1});
    });

    test('only ended docs fall back to every day', () {
      final days = StudyDays.fromDocs([
        doc(1, 'review', endedAt: DateTime.utc(2026, 9)),
      ]);
      expect(days, StudyDays.everyDay());
    });
  });

  group('countStudyDays', () {
    final monWed = StudyDays(studyWeekdays: {1, 3}, activeWeekdays: {1, 3});

    test('counts matching weekdays in a partial week', () {
      // Mon 7th .. Sun 13th: Mon + Wed.
      expect(monWed.countStudyDays('2026-09-07', '2026-09-13'), 2);
      // Tue 8th .. Thu 10th: Wed only.
      expect(monWed.countStudyDays('2026-09-08', '2026-09-10'), 1);
    });

    test('whole weeks plus a remainder starting mid-week', () {
      // Tue 1st .. Mon 21st = 21 days = 3 weeks: 3 * 2 = 6 (Mon 21st is
      // inside the span: Tue 1st + 20 = Mon 21st).
      expect(monWed.countStudyDays('2026-09-01', '2026-09-21'), 6);
      // Tue 1st .. Fri 25th = 25 days: 3 weeks (6) + Tue..Fri remainder
      // days 22-25 are Tue,Wed,Thu,Fri -> Wed counts: 7.
      expect(monWed.countStudyDays('2026-09-01', '2026-09-25'), 7);
    });

    test('matches a day-by-day count over a long span', () {
      var expected = 0;
      for (var d = 0; d < 100; d++) {
        if (monWed.isStudyDay(shiftCivilDate('2026-09-02', d))) expected++;
      }
      expect(monWed.countStudyDays('2026-09-02', '2026-12-10'), expected);
    });

    test('is 0 when from is after to', () {
      expect(monWed.countStudyDays('2026-09-08', '2026-09-07'), 0);
    });
  });

  group('nextActiveOnOrAfter', () {
    test('returns the date itself when every weekday is active', () {
      expect(
        StudyDays.everyDay().nextActiveOnOrAfter('2026-09-05'),
        '2026-09-05',
      );
    });

    test('returns the date itself when it is already active', () {
      final days = StudyDays(studyWeekdays: {1}, activeWeekdays: {1, 3});
      expect(days.nextActiveOnOrAfter('2026-09-09'), '2026-09-09');
    });

    test('skips forward to the next active weekday, over a week edge', () {
      final days = StudyDays(studyWeekdays: {1}, activeWeekdays: {1, 2});
      // Sat 5th -> Mon 7th.
      expect(days.nextActiveOnOrAfter('2026-09-05'), '2026-09-07');
      // Wed 9th -> next Mon 14th.
      expect(days.nextActiveOnOrAfter('2026-09-09'), '2026-09-14');
    });

    test('an empty config does not loop and returns the date', () {
      final days = StudyDays(studyWeekdays: {}, activeWeekdays: {});
      expect(days.nextActiveOnOrAfter('2026-09-05'), '2026-09-05');
    });
  });

  group('equality', () {
    test('compares weekday sets by value', () {
      final a = StudyDays(studyWeekdays: {1, 2}, activeWeekdays: {1, 2, 3});
      final b = StudyDays(studyWeekdays: {2, 1}, activeWeekdays: {3, 2, 1});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(StudyDays(studyWeekdays: {1}, activeWeekdays: {1, 2, 3})),
      );
      expect(
        a,
        isNot(StudyDays(studyWeekdays: {1, 2}, activeWeekdays: {1, 2})),
      );
      expect(a.toString(), contains('study'));
    });
  });
}
