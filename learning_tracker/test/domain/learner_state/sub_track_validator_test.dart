// Mirror test for `lib/domain/learner_state/sub_track_validator.dart`: the
// AD-45 limits, calendar-program rules and AC-5 intent-shape checks as pure
// functions (the shared JSON fixture suite is sub_track_limits_test.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

const _today = '2026-09-07';

SubTrack _track(
  int n, {
  SubTrackType type = SubTrackType.ongoing,
  String curriculumId = engineCurriculum,
  String windowStart = '2026-09-01',
  String? windowEnd,
  int? academicYear,
  double ratePerWeek = 1,
  double weeksPerYear = 40,
  List<NodeEntry> ground = const [],
  DateTime? endedAt,
}) => SubTrack(
  id: engineUlid(n),
  curriculumId: curriculumId,
  name: 'Track $n',
  type: type,
  academicYear: academicYear,
  windowStart: windowStart,
  windowEnd: windowEnd,
  ratePerWeek: ratePerWeek,
  weeksPerYear: weeksPerYear,
  learnsOnShabbos: true,
  ground: ground,
  lastChangeId: engineUlid(900),
  endedAt: endedAt,
);

SubTrack _school(
  int n, {
  int year = 2026,
  String start = '2026-09-01',
  String end = '2027-06-30',
  DateTime? endedAt,
}) => _track(
  n,
  type: SubTrackType.schoolYear,
  academicYear: year,
  windowStart: start,
  windowEnd: end,
  endedAt: endedAt,
);

List<String> _limits(
  SubTrack candidate, {
  SubTrack? prior,
  List<SubTrack> siblings = const [],
  String? program,
}) => subTrackViolationCodes(
  subTrackLimitViolations(
    candidate: candidate,
    prior: prior,
    siblings: siblings,
    today: _today,
    calendarProgramId: program,
  ),
);

void main() {
  group('SubTrackLimit / SubTrackViolation', () {
    test('wire codes are unique and round-trip through byCode', () {
      expect(
        SubTrackLimit.values.map((l) => l.code).toSet(),
        hasLength(SubTrackLimit.values.length),
      );
      for (final l in SubTrackLimit.values) {
        expect(SubTrackLimit.byCode[l.code], l);
      }
      expect(kMaxOngoingSubTracks, 5);
    });

    test('violations compare by limit and subject', () {
      const a = SubTrackViolation(SubTrackLimit.ongoingLimit, subject: 'x');
      expect(
        a,
        const SubTrackViolation(SubTrackLimit.ongoingLimit, subject: 'x'),
      );
      expect(
        a.hashCode,
        const SubTrackViolation(
          SubTrackLimit.ongoingLimit,
          subject: 'x',
        ).hashCode,
      );
      expect(a, isNot(const SubTrackViolation(SubTrackLimit.ongoingLimit)));
      expect(
        a,
        isNot(
          const SubTrackViolation(SubTrackLimit.windowReversed, subject: 'x'),
        ),
      );
      expect(a.toString(), contains('ongoing_limit'));
      expect(a.toString(), contains('x'));
      expect(
        const SubTrackViolation(SubTrackLimit.windowReversed).toString(),
        isNot(contains(',')),
      );
    });

    test('subTrackViolationCodes sorts and de-duplicates', () {
      expect(
        subTrackViolationCodes(const [
          SubTrackViolation(SubTrackLimit.windowReversed),
          SubTrackViolation(SubTrackLimit.duplicateGround, subject: 'a'),
          SubTrackViolation(SubTrackLimit.duplicateGround, subject: 'b'),
        ]),
        ['duplicate_ground', 'window_reversed'],
      );
      expect(subTrackViolationCodes(const []), isEmpty);
    });
  });

  group('countsTowardSubTrackLimits', () {
    test(
      'an open or still-running window counts, inclusive of its last day',
      () {
        expect(countsTowardSubTrackLimits(_track(1), _today), isTrue);
        expect(
          countsTowardSubTrackLimits(_track(1, windowEnd: _today), _today),
          isTrue,
        );
      },
    );

    test('a passed window or an ended track does not count', () {
      expect(
        countsTowardSubTrackLimits(_track(1, windowEnd: '2026-09-06'), _today),
        isFalse,
      );
      expect(
        countsTowardSubTrackLimits(
          _track(1, endedAt: DateTime.utc(2026, 9, 2)),
          _today,
        ),
        isFalse,
      );
    });

    test('a future-start track counts', () {
      expect(
        countsTowardSubTrackLimits(
          _track(1, windowStart: '2027-01-01'),
          _today,
        ),
        isTrue,
      );
    });
  });

  group('subTrackIntentViolations', () {
    test('a valid track has none', () {
      expect(subTrackIntentViolations(_track(1, ground: [berakhot])), isEmpty);
    });

    test('duplicate ground is reported once per repeat, by ref', () {
      final v = subTrackIntentViolations(
        _track(1, ground: [berakhot, peah, berakhot]),
      );
      expect(v, [
        SubTrackViolation(SubTrackLimit.duplicateGround, subject: berakhot.ref),
      ]);
    });

    test('cross-curriculum ground needs the corpus to be checked', () {
      const alien = NodeEntry(level: 'masechta', ref: 'Mishnah Nowhere');
      expect(subTrackIntentViolations(_track(1, ground: [alien])), isEmpty);
      final v = subTrackIntentViolations(
        _track(1, ground: [berakhot, alien]),
        corpus: mishnayosCorpus(),
      );
      expect(v, [
        SubTrackViolation(
          SubTrackLimit.crossCurriculumGround,
          subject: alien.ref,
        ),
      ]);
    });

    test('ground with the wrong level for its ref is cross-curriculum', () {
      const wrongLevel = NodeEntry(level: 'chapter', ref: 'Mishnah Berakhot');
      final v = subTrackIntentViolations(
        _track(1, ground: [wrongLevel]),
        corpus: mishnayosCorpus(),
      );
      expect(subTrackViolationCodes(v), ['cross_curriculum_ground']);
    });

    test('a track of another curriculum has all its ground flagged', () {
      final v = subTrackIntentViolations(
        _track(1, curriculumId: 'other', ground: [berakhot, peah]),
        corpus: mishnayosCorpus(),
      );
      expect(v.map((e) => e.subject), [berakhot.ref, peah.ref]);
    });

    test('a reversed window is flagged; touching bounds are not', () {
      expect(
        subTrackViolationCodes(
          subTrackIntentViolations(
            _track(1, windowStart: '2026-09-10', windowEnd: '2026-09-09'),
          ),
        ),
        ['window_reversed'],
      );
      expect(
        subTrackIntentViolations(
          _track(1, windowStart: '2026-09-10', windowEnd: '2026-09-10'),
        ),
        isEmpty,
      );
    });

    test('non-positive rate and weeks are flagged, including NaN', () {
      expect(
        subTrackViolationCodes(
          subTrackIntentViolations(_track(1, ratePerWeek: 0, weeksPerYear: -1)),
        ),
        ['non_positive_rate', 'non_positive_weeks'],
      );
      expect(
        subTrackViolationCodes(
          subTrackIntentViolations(_track(1, ratePerWeek: double.nan)),
        ),
        ['non_positive_rate'],
      );
    });
  });

  group('subTrackLimitViolations: ongoing limit', () {
    final five = [for (var i = 1; i <= 5; i++) _track(i)];

    test('the sixth counting ongoing sub-track is rejected', () {
      expect(_limits(_track(6), siblings: five), ['ongoing_limit']);
    });

    test('the fifth is accepted', () {
      expect(_limits(_track(5), siblings: five.take(4).toList()), isEmpty);
    });

    test('ended, passed-window and other-curriculum tracks do not count', () {
      final siblings = [
        _track(1),
        _track(2),
        _track(3),
        _track(4, endedAt: DateTime.utc(2026, 9, 2)),
        _track(5, windowEnd: '2026-09-06'),
        _track(7, curriculumId: 'other'),
        _track(8, curriculumId: 'other'),
      ];
      expect(_limits(_track(6), siblings: siblings), isEmpty);
    });

    test('school-year tracks do not count toward the ongoing limit', () {
      final siblings = [
        for (var i = 1; i <= 5; i++)
          _school(
            i,
            year: 2000 + i,
            start: '${2000 + i}-09-01',
            end: '${2001 + i}-06-30',
          ),
      ];
      expect(_limits(_track(6), siblings: siblings), isEmpty);
    });

    test('rows sharing the candidate id are ignored', () {
      expect(_limits(_track(1), siblings: five), isEmpty);
    });

    test(
      'an already-over-limit row can still be edited (only new violations reject)',
      () {
        final six = [for (var i = 1; i <= 6; i++) _track(i)];
        final edited = _track(6, ratePerWeek: 3);
        expect(
          _limits(edited, prior: six.last, siblings: six.take(5).toList()),
          isEmpty,
        );
        // The same row as a create is rejected.
        expect(_limits(edited, siblings: six.take(5).toList()), [
          'ongoing_limit',
        ]);
      },
    );

    test('an ended candidate never violates', () {
      expect(
        _limits(_track(6, endedAt: DateTime.utc(2026, 9, 2)), siblings: five),
        isEmpty,
      );
    });
  });

  group('subTrackLimitViolations: school year', () {
    test('a second school-year track for one academic year is rejected', () {
      final other = _school(1);
      final v = subTrackLimitViolations(
        candidate: _school(2, start: '2027-07-01', end: '2027-08-31'),
        prior: null,
        siblings: [other],
        today: _today,
        calendarProgramId: null,
      );
      expect(v, [
        SubTrackViolation(SubTrackLimit.schoolYearDuplicate, subject: other.id),
      ]);
    });

    test('overlapping windows are rejected, naming the other track', () {
      final other = _school(1, year: 2026);
      final v = subTrackLimitViolations(
        candidate: _school(
          2,
          year: 2027,
          start: '2027-06-30',
          end: '2028-06-30',
        ),
        prior: null,
        siblings: [other],
        today: _today,
        calendarProgramId: null,
      );
      expect(v, [
        SubTrackViolation(SubTrackLimit.schoolYearOverlap, subject: other.id),
      ]);
    });

    test('windows touching on one day overlap; a gap day does not', () {
      final first = _school(1, year: 2026, end: '2027-06-30');
      expect(
        _limits(
          _school(2, year: 2027, start: '2027-06-30', end: '2028-06-30'),
          siblings: [first],
        ),
        ['school_year_window_overlap'],
      );
      expect(
        _limits(
          _school(2, year: 2027, start: '2027-07-01', end: '2028-06-30'),
          siblings: [first],
        ),
        isEmpty,
      );
    });

    test('a passed or ended sibling window does not conflict', () {
      expect(
        _limits(_school(2), siblings: [_school(1, end: '2026-09-06')]),
        isEmpty,
      );
      expect(
        _limits(
          _school(2),
          siblings: [_school(1, endedAt: DateTime.utc(2026, 9, 2))],
        ),
        isEmpty,
      );
    });

    test('an ongoing sibling never conflicts with a school-year candidate', () {
      expect(_limits(_school(2), siblings: [_track(1)]), isEmpty);
    });

    test('a pre-existing duplicate does not block an unrelated edit', () {
      final other = _school(1);
      final prior = _school(2);
      final edited = _school(2, end: '2027-06-29');
      expect(_limits(edited, prior: prior, siblings: [other]), isEmpty);
    });
  });

  group('subTrackLimitViolations: calendar programs', () {
    test('a create on a calendar-program curriculum is rejected', () {
      expect(_limits(_track(1), program: 'mishnah_yomit'), [
        'calendar_program_curriculum',
      ]);
    });

    test('an edit of an existing row is not (only creates are)', () {
      expect(
        _limits(_track(1), prior: _track(1), program: 'mishnah_yomit'),
        isEmpty,
      );
    });

    test('no program means no calendar violation', () {
      expect(_limits(_track(1)), isEmpty);
    });
  });

  group('calendarProgramSetViolations', () {
    test('clearing the program is always allowed', () {
      expect(
        calendarProgramSetViolations(
          curriculumId: engineCurriculum,
          programId: null,
          subTracks: [_track(1)],
        ),
        isEmpty,
      );
    });

    test(
      'setting one is blocked by each non-ended sub-track of the curriculum',
      () {
        final live = _track(1);
        final passed = _track(2, windowEnd: '2026-09-06');
        final v = calendarProgramSetViolations(
          curriculumId: engineCurriculum,
          programId: 'mishnah_yomit',
          subTracks: [
            live,
            passed,
            _track(3, endedAt: DateTime.utc(2026, 9, 2)),
            _track(4, curriculumId: 'other'),
          ],
        );
        expect(v, [
          SubTrackViolation(
            SubTrackLimit.calendarProgramHasSubTracks,
            subject: live.id,
          ),
          SubTrackViolation(
            SubTrackLimit.calendarProgramHasSubTracks,
            subject: passed.id,
          ),
        ]);
      },
    );

    test('setting one with no sub-track is allowed', () {
      expect(
        calendarProgramSetViolations(
          curriculumId: engineCurriculum,
          programId: 'mishnah_yomit',
          subTracks: const [],
        ),
        isEmpty,
      );
    });
  });
}
