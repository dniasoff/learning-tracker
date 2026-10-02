/// Story 2.4 (DNI-495) AC-5, AC-7, AC-8 and the edge cases: the school-year
/// form's pure window, academic-year and field validation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';
import 'package:learning_tracker/features/sub_tracks/domain/school_year_sub_track_form_validation.dart';

import '../../../helpers/sub_tracks/sub_track_harness.dart';

SchoolYearFormValues _values({
  String name = 'School',
  int? academicYear = 2027,
  int startMonth = 9,
  int endMonth = 7,
  String rate = '10',
  String weeks = '39',
  bool shabbos = false,
}) => SchoolYearFormValues(
  name: name,
  academicYear: academicYear,
  startMonth: startMonth,
  endMonth: endMonth,
  rateText: rate,
  weeksText: weeks,
  learnsOnShabbos: shabbos,
);

Map<SchoolYearFormField, SchoolYearFormError> _validate(
  SchoolYearFormValues values, {
  List<SubTrack> subTracks = const [],
  String? editingId,
}) => validateSchoolYearForm(
  values,
  curriculumId: subTrackTestCurriculum,
  subTracks: subTracks,
  editingId: editingId,
);

void main() {
  group('academic year boundary (AC-5)', () {
    test('1 September starts the new academic year', () {
      expect(academicYearOf('2026-09-01'), 2026);
    });

    test('31 August still belongs to the prior academic year', () {
      expect(academicYearOf('2026-08-31'), 2025);
    });

    test('January is in the year that started the previous September', () {
      expect(academicYearOf('2027-01-15'), 2026);
    });
  });

  group('academic year options (AC-5)', () {
    test('without a deadline: the current year plus the next two', () {
      expect(academicYearOptions(today: '2026-10-02'), [2026, 2027, 2028]);
    });

    test('with a deadline: current through the year holding target_date', () {
      expect(academicYearOptions(today: '2026-10-02', deadline: '2029-08-31'), [
        2026,
        2027,
        2028,
      ]);
      expect(academicYearOptions(today: '2026-10-02', deadline: '2029-09-01'), [
        2026,
        2027,
        2028,
        2029,
      ]);
    });

    test('a deadline inside the current year offers only that year', () {
      expect(academicYearOptions(today: '2026-10-02', deadline: '2027-03-01'), [
        2026,
      ]);
    });

    test('a past deadline still offers the current year', () {
      expect(academicYearOptions(today: '2026-10-02', deadline: '2025-01-01'), [
        2026,
      ]);
    });

    test("an edited track's own (earlier) year stays on offer", () {
      expect(academicYearOptions(today: '2026-10-02', include: 2025), [
        2025,
        2026,
        2027,
        2028,
      ]);
    });
  });

  group('window bounds (AC-7)', () {
    test('default September to July spans academic_year to +1', () {
      expect(schoolYearWindowStart(2026, 9), '2026-09-01');
      expect(schoolYearWindowEnd(2026, 7), '2027-07-31');
    });

    test('a February end month uses the leap day when there is one', () {
      expect(schoolYearWindowEnd(2027, 2), '2028-02-29');
      expect(schoolYearWindowEnd(2026, 2), '2027-02-28');
    });

    test('a 30-day end month ends on the 30th', () {
      expect(schoolYearWindowEnd(2026, 6), '2027-06-30');
    });

    test('a January start falls in academic_year + 1', () {
      expect(schoolYearWindowStart(2026, 1), '2027-01-01');
    });

    test('values derive window dates as YYYY-MM-DD', () {
      final v = _values(academicYear: 2026, startMonth: 10, endMonth: 8);
      expect(v.windowStart, '2026-10-01');
      expect(v.windowEnd, '2027-08-31');
      expect(_values(academicYear: null).windowStart, isNull);
    });
  });

  group('year states (AC-5, AC-8)', () {
    final tracks = [
      storedSchoolYear('01JHARN0000000000000000001', academicYear: 2026),
      storedSchoolYear(
        '01JHARN0000000000000000002',
        academicYear: 2027,
        ended: true,
      ),
      storedSchoolYear(
        '01JHARN0000000000000000003',
        academicYear: 2028,
        curriculumId: 'bavli',
      ),
      storedOngoing('01JHARN0000000000000000004'),
    ];

    test('only a non-ended school-year track of the curriculum is Used', () {
      final used = usedAcademicYears(
        tracks,
        curriculumId: subTrackTestCurriculum,
      );
      expect(used, {2026});
      expect(
        academicYearState(2026, used: used, currentYear: 2026),
        AcademicYearState.used,
      );
      expect(
        academicYearState(2027, used: used, currentYear: 2026),
        AcademicYearState.open,
      );
    });

    test('the current free year is Active', () {
      expect(
        academicYearState(2026, used: const {}, currentYear: 2026),
        AcademicYearState.active,
      );
    });

    test("while editing, the track's own year is not Used", () {
      expect(
        usedAcademicYears(
          tracks,
          curriculumId: subTrackTestCurriculum,
          exceptId: '01JHARN0000000000000000001',
        ),
        isEmpty,
      );
    });
  });

  group('field validation (AC-7)', () {
    test('a complete form has no error', () {
      expect(_validate(_values()), isEmpty);
    });

    test('an empty or whitespace name is required', () {
      expect(
        _validate(_values(name: ''))[SchoolYearFormField.name],
        SchoolYearFormError.nameRequired,
      );
      expect(
        _validate(_values(name: '   '))[SchoolYearFormField.name],
        SchoolYearFormError.nameRequired,
      );
    });

    test('no academic year is an error', () {
      expect(
        _validate(
          _values(academicYear: null),
        )[SchoolYearFormField.academicYear],
        SchoolYearFormError.yearRequired,
      );
    });

    for (final bad in ['', ' ', '0', '-3', 'abc', 'NaN', 'Infinity', '1e999']) {
      test('rate and weeks "$bad" are rejected', () {
        final errors = _validate(_values(rate: bad, weeks: bad));
        expect(
          errors[SchoolYearFormField.rate],
          SchoolYearFormError.notPositive,
        );
        expect(
          errors[SchoolYearFormField.weeks],
          SchoolYearFormError.notPositive,
        );
      });
    }

    test('decimal rates parse, with a comma separator too', () {
      expect(parsePositiveNumber('2.5'), 2.5);
      expect(parsePositiveNumber('2,5'), 2.5);
      expect(_validate(_values(rate: '0.5', weeks: '36.5')), isEmpty);
    });

    test('a start month after the end month is reversed', () {
      expect(
        _validate(
          _values(startMonth: 7, endMonth: 6),
        )[SchoolYearFormField.window],
        SchoolYearFormError.windowReversed,
      );
      expect(
        _validate(
          _values(startMonth: 1, endMonth: 12),
        )[SchoolYearFormField.window],
        SchoolYearFormError.windowReversed,
      );
    });

    test('a corrected value clears its error', () {
      expect(_validate(_values(rate: '0')), isNotEmpty);
      expect(_validate(_values(rate: '3')), isEmpty);
    });
  });

  group('used year and overlapping windows (AC-7, AD-45)', () {
    final existing2026 = storedSchoolYear(
      '01JHARN0000000000000000001',
      academicYear: 2026,
    );

    test('a used year blocks save', () {
      expect(
        _validate(
          _values(academicYear: 2026),
          subTracks: [existing2026],
        )[SchoolYearFormField.academicYear],
        SchoolYearFormError.yearUsed,
      );
    });

    test('a window touching another on one day overlaps', () {
      // It runs to 2027-09-01, the day the 2027 window starts.
      final touching = storedSchoolYear(
        '01JHARN0000000000000000005',
        academicYear: 2026,
        windowEnd: '2027-09-01',
      );
      expect(
        _validate(
          _values(academicYear: 2027),
          subTracks: [touching],
        )[SchoolYearFormField.window],
        SchoolYearFormError.windowOverlap,
      );
    });

    test('an overlap counts even when the academic year differs', () {
      final longTrack = storedSchoolYear(
        '01JHARN0000000000000000006',
        academicYear: 2026,
        windowEnd: '2028-06-30',
      );
      final errors = _validate(
        _values(academicYear: 2027),
        subTracks: [longTrack],
      );
      expect(
        errors[SchoolYearFormField.window],
        SchoolYearFormError.windowOverlap,
      );
      expect(errors.containsKey(SchoolYearFormField.academicYear), isFalse);
    });

    test('adjacent non-overlapping years are fine', () {
      expect(
        _validate(_values(academicYear: 2027), subTracks: [existing2026]),
        isEmpty,
      );
    });

    test('ended tracks, other curricula and ongoing tracks never block', () {
      expect(
        _validate(
          _values(academicYear: 2026),
          subTracks: [
            storedSchoolYear(
              '01JHARN0000000000000000007',
              academicYear: 2026,
              ended: true,
            ),
            storedSchoolYear(
              '01JHARN0000000000000000008',
              academicYear: 2026,
              curriculumId: 'bavli',
            ),
            storedOngoing('01JHARN0000000000000000009'),
          ],
        ),
        isEmpty,
      );
    });

    test('editing a track never conflicts with itself (AC-8)', () {
      expect(
        _validate(
          _values(academicYear: 2026),
          subTracks: [existing2026],
          editingId: existing2026.id,
        ),
        isEmpty,
      );
    });
  });

  group('mapping to the Story 2.1 commands', () {
    test('a draft carries the AD-52 school-year fields and empty ground', () {
      final draft = schoolYearDraft(
        _values(name: '  Cheder  ', rate: '12', weeks: '36', shabbos: true),
        curriculumId: subTrackTestCurriculum,
      );
      expect(draft.curriculumId, subTrackTestCurriculum);
      expect(draft.name, 'Cheder');
      expect(draft.type, SubTrackType.schoolYear);
      expect(draft.academicYear, 2027);
      expect(draft.windowStart, '2027-09-01');
      expect(draft.windowEnd, '2028-07-31');
      expect(draft.ratePerWeek, 12);
      expect(draft.weeksPerYear, 36);
      expect(draft.learnsOnShabbos, isTrue);
      expect(draft.ground, isEmpty);
    });

    test('an edit carries only the changed fields (AC-8)', () {
      final current = storedSchoolYear('01JHARN0000000000000000001');
      final values = SchoolYearFormValues.of(current);
      expect(schoolYearEdit(current, values), isNull);

      final edit = schoolYearEdit(
        current,
        SchoolYearFormValues(
          name: values.name,
          academicYear: values.academicYear,
          startMonth: values.startMonth,
          endMonth: 6,
          rateText: '12',
          weeksText: values.weeksText,
          learnsOnShabbos: values.learnsOnShabbos,
        ),
      )!;
      expect(edit.ratePerWeek, 12);
      expect(edit.windowEnd, '2027-06-30');
      expect(edit.name, isNull);
      expect(edit.academicYear, isNull);
      expect(edit.windowStart, isNull);
      expect(edit.weeksPerYear, isNull);
      expect(edit.learnsOnShabbos, isNull);
    });

    test('a no-op edit of an open-ended row writes nothing (AC-8)', () {
      final current = storedSchoolYear(
        '01JHARN0000000000000000001',
        openEnd: true,
      );
      final values = SchoolYearFormValues.of(current);
      expect(values.endMonth, isNull);
      expect(values.windowEnd, isNull);
      expect(_validate(values, editingId: current.id), isEmpty);
      expect(schoolYearEdit(current, values), isNull);
    });

    test('an open-ended row keeps its open end when another field changes', () {
      final current = storedSchoolYear(
        '01JHARN0000000000000000001',
        openEnd: true,
      );
      final values = SchoolYearFormValues.of(current);
      final edit = schoolYearEdit(
        current,
        SchoolYearFormValues(
          name: values.name,
          academicYear: values.academicYear,
          startMonth: values.startMonth,
          endMonth: values.endMonth,
          rateText: '12',
          weeksText: values.weeksText,
          learnsOnShabbos: values.learnsOnShabbos,
        ),
      )!;
      expect(edit.ratePerWeek, 12);
      expect(edit.windowEnd, isNull);
      expect(edit.clearWindowEnd, isFalse);
    });

    test('choosing an end month on an open-ended row bounds it', () {
      final current = storedSchoolYear(
        '01JHARN0000000000000000001',
        openEnd: true,
      );
      final values = SchoolYearFormValues.of(current);
      final edit = schoolYearEdit(
        current,
        SchoolYearFormValues(
          name: values.name,
          academicYear: values.academicYear,
          startMonth: values.startMonth,
          endMonth: 6,
          rateText: values.rateText,
          weeksText: values.weeksText,
          learnsOnShabbos: values.learnsOnShabbos,
        ),
      )!;
      expect(edit.windowEnd, '2027-06-30');
      expect(edit.clearWindowEnd, isFalse);
      expect(edit.ratePerWeek, isNull);
    });

    test('clearing the end month of a bounded row opens it explicitly', () {
      final current = storedSchoolYear('01JHARN0000000000000000001');
      final values = SchoolYearFormValues.of(current);
      final edit = schoolYearEdit(
        current,
        SchoolYearFormValues(
          name: values.name,
          academicYear: values.academicYear,
          startMonth: values.startMonth,
          endMonth: null,
          rateText: values.rateText,
          weeksText: values.weeksText,
          learnsOnShabbos: values.learnsOnShabbos,
        ),
      )!;
      expect(edit.clearWindowEnd, isTrue);
      expect(edit.windowEnd, isNull);
    });

    test('an open-ended window overlaps every later school window', () {
      final open = storedSchoolYear(
        '01JHARN0000000000000000002',
        academicYear: 2025,
        openEnd: true,
      );
      expect(_validate(_values(academicYear: 2028), subTracks: [open]), {
        SchoolYearFormField.window: SchoolYearFormError.windowOverlap,
      });
    });

    test('values of a stored track round-trip its months and numbers', () {
      final v = SchoolYearFormValues.of(
        storedSchoolYear(
          '01JHARN0000000000000000001',
          windowStart: '2026-10-01',
          windowEnd: '2027-06-30',
          rate: 2.5,
        ),
      );
      expect(v.startMonth, 10);
      expect(v.endMonth, 6);
      expect(v.rateText, '2.5');
      expect(v.weeksText, '39');
    });

    test('AD-45 violations from the command map onto fields', () {
      expect(
        schoolYearErrorsFromViolations(const [
          SubTrackViolation(SubTrackLimit.schoolYearDuplicate, subject: 'x'),
          SubTrackViolation(SubTrackLimit.schoolYearOverlap, subject: 'x'),
          SubTrackViolation(SubTrackLimit.nonPositiveRate),
          SubTrackViolation(SubTrackLimit.nonPositiveWeeks),
          SubTrackViolation(SubTrackLimit.calendarProgramCurriculum),
        ]),
        {
          SchoolYearFormField.academicYear: SchoolYearFormError.yearUsed,
          SchoolYearFormField.window: SchoolYearFormError.windowOverlap,
          SchoolYearFormField.rate: SchoolYearFormError.notPositive,
          SchoolYearFormField.weeks: SchoolYearFormError.notPositive,
        },
      );
    });
  });
}
