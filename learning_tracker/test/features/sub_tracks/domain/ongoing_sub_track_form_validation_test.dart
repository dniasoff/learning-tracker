// DNI-496 (Story 2.5): validation and storage mapping of the ongoing form
// (AC-2, AC-3, AC-5, AC-6 and the edge table).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';
import 'package:learning_tracker/features/sub_tracks/domain/ongoing_sub_track_form_state.dart';
import 'package:learning_tracker/features/sub_tracks/domain/ongoing_sub_track_form_validation.dart';

const _today = '2026-09-07';
const _curriculum = 'mishnayos';

String _ulid(int n) => '01J${n.toString().padLeft(23, '0')}';

SubTrack _track(
  int id, {
  String curriculumId = _curriculum,
  SubTrackType type = SubTrackType.ongoing,
  String start = '2026-09-01',
  String? end,
  bool ended = false,
}) => SubTrack(
  id: _ulid(id),
  curriculumId: curriculumId,
  name: 'Rebbe $id',
  type: type,
  academicYear: type == SubTrackType.schoolYear ? 2026 : null,
  windowStart: start,
  windowEnd: end,
  ratePerWeek: 5,
  weeksPerYear: 52,
  learnsOnShabbos: false,
  ground: const [],
  lastChangeId: _ulid(id + 500),
  endedAt: ended ? DateTime.utc(2026, 9, 2) : null,
  endReason: ended ? SubTrackEndReason.ended : null,
);

OngoingFormValidation _validate({
  String name = 'Rebbe Cohen',
  String rate = '5',
  String weeks = '52',
  String? start,
  String? end,
  bool shabbos = false,
}) => validateOngoingSubTrackForm(
  OngoingSubTrackFormInput(
    name: name,
    rateText: rate,
    weeksText: weeks,
    start: start,
    end: end,
    learnsOnShabbos: shabbos,
  ),
  today: _today,
);

void main() {
  group('AC-3: optional dates', () {
    test(
      'a missing start is the learner civil today; a missing end is open',
      () {
        final v = _validate().values!;
        expect(v.windowStart, _today);
        expect(v.windowEnd, isNull);
      },
    );

    test('a future start and an end are passed unchanged', () {
      final v = _validate(start: '2026-11-01', end: '2027-06-30').values!;
      expect(v.windowStart, '2026-11-01');
      expect(v.windowEnd, '2027-06-30');
    });

    test('an end before the start blocks save on the end field', () {
      final r = _validate(start: '2026-11-01', end: '2026-10-31');
      expect(r.isValid, isFalse);
      expect(r.values, isNull);
      expect(r.errors, {OngoingFormField.end: OngoingFormError.endBeforeStart});
    });

    test('an end before today with no start is before the default start', () {
      final r = _validate(end: '2026-09-06');
      expect(r.errors[OngoingFormField.end], OngoingFormError.endBeforeStart);
    });

    test('equal start and end is a valid one-day window', () {
      final v = _validate(start: _today, end: _today).values!;
      expect(v.windowStart, v.windowEnd);
    });

    test('a past end not before a past start is allowed (AC-6)', () {
      final v = _validate(start: '2026-01-01', end: '2026-09-06').values!;
      expect(v.windowEnd, '2026-09-06');
    });

    test('a leap day is an ordinary civil date', () {
      final v = _validate(start: '2028-02-29', end: '2028-03-01').values!;
      expect(v.windowStart, '2028-02-29');
    });
  });

  group('edge: name and numbers', () {
    for (final blank in ['', '   ', '\t']) {
      test('blank name "${blank.codeUnits}" is required', () {
        expect(
          _validate(name: blank).errors[OngoingFormField.name],
          OngoingFormError.nameRequired,
        );
      });
    }

    test('the name is trimmed', () {
      expect(_validate(name: '  Chavrusa  ').values!.name, 'Chavrusa');
    });

    for (final bad in ['0', '-1', '', 'abc', 'Infinity', 'NaN', '-0.5']) {
      test('rate "$bad" and weeks "$bad" are not positive', () {
        final r = _validate(rate: bad, weeks: bad);
        expect(r.errors[OngoingFormField.rate], OngoingFormError.notPositive);
        expect(r.errors[OngoingFormField.weeks], OngoingFormError.notPositive);
      });
    }

    test('decimal rates and weeks, with a comma or spaces, are accepted', () {
      final v = _validate(rate: ' 2,5 ', weeks: '44.5').values!;
      expect(v.ratePerWeek, 2.5);
      expect(v.weeksPerYear, 44.5);
    });

    test('a corrected value clears its error', () {
      expect(_validate(rate: '0').isValid, isFalse);
      expect(_validate(rate: '1').isValid, isTrue);
    });
  });

  group('AC-2: the draft carries weeks_per_year and no switch', () {
    test('the bein-hazmanim prefill reaches only weeks_per_year', () {
      final prefill = const OngoingWeeksPrefill.initial().toggleBeinHazmanim(
        on: true,
      );
      final draft = _validate(
        weeks: prefill.weeksText,
      ).values!.toDraft(_curriculum);
      expect(draft.weeksPerYear, 44);
      expect(draft.type, SubTrackType.ongoing);
      expect(draft.academicYear, isNull);
      expect(draft.ground, isEmpty);
      expect(draft.curriculumId, _curriculum);
    });

    test('a stored ongoing sub-track has no bein-hazmanim field', () {
      expect(
        SubTrack.storageKeys.where((k) => k.contains('hazmanim')),
        isEmpty,
      );
    });
  });

  group('AC-6: editSubTrack receives only changed fields', () {
    final current = _track(1, start: '2026-09-01');

    test('no change → no edit', () {
      final v = _validate(
        name: current.name,
        start: current.windowStart,
        weeks: '52',
      ).values!;
      expect(v.editFrom(current), isNull);
    });

    test('a past end date alone is the only changed field', () {
      final v = _validate(
        name: current.name,
        start: current.windowStart,
        end: '2026-09-05',
      ).values!;
      final edit = v.editFrom(current)!;
      expect(edit.windowEnd, '2026-09-05');
      expect(edit.name, isNull);
      expect(edit.ratePerWeek, isNull);
      expect(edit.weeksPerYear, isNull);
      expect(edit.windowStart, isNull);
      expect(edit.learnsOnShabbos, isNull);
      expect(edit.clearWindowEnd, isFalse);
    });

    test('removing a stored end opens the window', () {
      final bounded = _track(2, end: '2027-01-01');
      final v = _validate(
        name: bounded.name,
        start: bounded.windowStart,
      ).values!;
      final edit = v.editFrom(bounded)!;
      expect(edit.clearWindowEnd, isTrue);
      expect(edit.windowEnd, isNull);
    });

    test('name, rate, weeks and shabbos changes are each carried', () {
      final v = _validate(
        name: 'New',
        rate: '7',
        weeks: '44',
        start: current.windowStart,
        shabbos: true,
      ).values!;
      final edit = v.editFrom(current)!;
      expect(edit.name, 'New');
      expect(edit.ratePerWeek, 7);
      expect(edit.weeksPerYear, 44);
      expect(edit.learnsOnShabbos, isTrue);
      expect(edit.windowStart, isNull);
    });
  });

  group('AC-5: ongoing usage count', () {
    test('counts live, current and future-start ongoing tracks only', () {
      final tracks = [
        _track(1),
        _track(2, start: '2026-12-01'), // future start counts
        _track(3, end: _today), // inclusive end today counts
        _track(4, ended: true), // ended does not count
        _track(5, end: '2026-09-06'), // passed window does not count
        _track(6, curriculumId: 'chumash'), // other curriculum
        _track(7, type: SubTrackType.schoolYear, end: '2027-07-31'),
      ];
      expect(
        ongoingSubTracksInUse(tracks, curriculumId: _curriculum, today: _today),
        3,
      );
    });

    test('the edited track is excluded when asked', () {
      expect(
        ongoingSubTracksInUse(
          [_track(1), _track(2)],
          curriculumId: _curriculum,
          today: _today,
          excludingId: _ulid(1),
        ),
        1,
      );
    });

    test('a create is allowed below five and refused at five', () {
      expect(kMaxOngoingSubTracks, 5);
      expect(ongoingCreateAllowed(0), isTrue);
      expect(ongoingCreateAllowed(4), isTrue);
      expect(ongoingCreateAllowed(5), isFalse);
      expect(ongoingCreateAllowed(6), isFalse);
    });

    test('agrees with the shared AD-45 validator on the fifth and sixth', () {
      final four = [for (var i = 1; i <= 4; i++) _track(i)];
      final five = [...four, _track(5)];
      expect(
        subTrackLimitViolations(
          candidate: _track(20),
          prior: null,
          siblings: four,
          today: _today,
          calendarProgramId: null,
        ),
        isEmpty,
      );
      expect(
        ongoingCreateAllowed(
          ongoingSubTracksInUse(four, curriculumId: _curriculum, today: _today),
        ),
        isTrue,
      );
      expect(
        subTrackViolationCodes(
          subTrackLimitViolations(
            candidate: _track(20),
            prior: null,
            siblings: five,
            today: _today,
            calendarProgramId: null,
          ),
        ),
        ['ongoing_limit'],
      );
      expect(
        ongoingCreateAllowed(
          ongoingSubTracksInUse(five, curriculumId: _curriculum, today: _today),
        ),
        isFalse,
      );
    });
  });

  test('command violations map to their form fields', () {
    expect(
      ongoingFieldForViolation(SubTrackLimit.windowReversed),
      OngoingFormField.end,
    );
    expect(
      ongoingFieldForViolation(SubTrackLimit.nonPositiveRate),
      OngoingFormField.rate,
    );
    expect(
      ongoingFieldForViolation(SubTrackLimit.nonPositiveWeeks),
      OngoingFormField.weeks,
    );
    expect(ongoingFieldForViolation(SubTrackLimit.ongoingLimit), isNull);
  });
}
