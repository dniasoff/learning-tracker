/// Story 2.8 (DNI-499) AC-1, AC-2: the *Add next year* prefill and its
/// availability (pure; the widget and command paths have their own tests).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/domain/school_year_sub_track_form_validation.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_lifecycle.dart';

import '../../../helpers/learner_state_fixtures.dart';

const _today = '2026-10-01';

SubTrack _school({
  String id = ulidA,
  String curriculumId = 'shas',
  int academicYear = 2026,
  String windowStart = '2026-09-01',
  String? windowEnd = '2027-07-31',
  SubTrackEndReason? endReason,
}) => SubTrack(
  id: id,
  curriculumId: curriculumId,
  name: 'School',
  type: SubTrackType.schoolYear,
  academicYear: academicYear,
  windowStart: windowStart,
  windowEnd: windowEnd,
  ratePerWeek: 7.5,
  weeksPerYear: 34,
  learnsOnShabbos: true,
  ground: const [NodeEntry(level: 'masechta', ref: 'Berakhot')],
  lastChangeId: ulidE,
  endedAt: endReason == null ? null : t1,
  endReason: endReason,
);

void main() {
  group('nextYearSubTrackDraft (AC-1)', () {
    test('copies name, rate, weeks, Shabbos flag and months into Y+1 with '
        'empty ground', () {
      final draft = nextYearSubTrackDraft(_school());
      expect(draft.curriculumId, 'shas');
      expect(draft.name, 'School');
      expect(draft.type, SubTrackType.schoolYear);
      expect(draft.academicYear, 2027);
      expect(draft.windowStart, '2027-09-01');
      expect(draft.windowEnd, '2028-07-31');
      expect(draft.ratePerWeek, 7.5);
      expect(draft.weeksPerYear, 34);
      expect(draft.learnsOnShabbos, isTrue);
      expect(draft.ground, isEmpty);
    });

    test('edited month boundaries are kept: Oct–Jun', () {
      final draft = nextYearSubTrackDraft(
        _school(windowStart: '2026-10-01', windowEnd: '2027-06-30'),
      );
      expect(draft.windowStart, '2027-10-01');
      expect(draft.windowEnd, '2028-06-30');
    });

    test('a February end lands on the leap day when Y+2 is a leap year', () {
      final draft = nextYearSubTrackDraft(_school(windowEnd: '2027-02-28'));
      expect(draft.windowEnd, '2028-02-29');
      final back = nextYearSubTrackDraft(
        _school(
          academicYear: 2027,
          windowStart: '2027-09-01',
          windowEnd: '2028-02-29',
        ),
      );
      expect(back.windowEnd, '2029-02-28');
    });

    test('a window inside one civil year (Jan–Jun) moves one year', () {
      final draft = nextYearSubTrackDraft(
        _school(windowStart: '2027-01-01', windowEnd: '2027-06-30'),
      );
      expect(draft.windowStart, '2028-01-01');
      expect(draft.windowEnd, '2028-06-30');
    });

    test('an open-ended school year stays open-ended', () {
      expect(nextYearSubTrackDraft(_school(windowEnd: null)).windowEnd, isNull);
    });

    test('the source is not changed', () {
      final source = _school();
      final stored = source.toStorage();
      nextYearSubTrackDraft(source);
      expect(source.toStorage(), stored);
    });

    test('an ongoing source is refused', () {
      final ongoing = SubTrack(
        id: ulidB,
        curriculumId: 'shas',
        name: 'Night seder',
        type: SubTrackType.ongoing,
        windowStart: '2026-09-01',
        ratePerWeek: 5,
        weeksPerYear: 40,
        learnsOnShabbos: false,
        ground: const [],
        lastChangeId: ulidE,
      );
      expect(() => nextYearSubTrackDraft(ongoing), throwsArgumentError);
    });
  });

  group('nextYearAvailability (AC-2)', () {
    test('available when Y+1 is free and in range', () {
      final source = _school();
      expect(
        nextYearAvailability(source: source, siblings: [source], today: _today),
        NextYearAvailability.available,
      );
    });

    test('Y+1 used by a live school year of the same curriculum', () {
      final source = _school();
      final next = _school(
        id: ulidB,
        academicYear: 2027,
        windowStart: '2027-09-01',
        windowEnd: '2028-07-31',
      );
      expect(
        nextYearAvailability(
          source: source,
          siblings: [source, next],
          today: _today,
        ),
        NextYearAvailability.yearUsed,
      );
    });

    test('Y+1 of another curriculum does not count', () {
      final source = _school();
      final other = _school(
        id: ulidB,
        curriculumId: 'mishnayos',
        academicYear: 2027,
        windowStart: '2027-09-01',
        windowEnd: '2028-07-31',
      );
      expect(
        nextYearAvailability(
          source: source,
          siblings: [source, other],
          today: _today,
        ),
        NextYearAvailability.available,
      );
    });

    test('beyond the picker: past the deadline year', () {
      final source = _school();
      expect(
        nextYearAvailability(
          source: source,
          siblings: [source],
          today: _today,
          deadline: '2027-06-30',
        ),
        NextYearAvailability.beyondPickerRange,
      );
      expect(
        nextYearAvailability(
          source: source,
          siblings: [source],
          today: _today,
          deadline: '2027-09-01',
        ),
        NextYearAvailability.available,
      );
    });

    test('beyond the picker without a deadline: current + 2 is the last', () {
      final far = _school(
        academicYear: 2028,
        windowStart: '2028-09-01',
        windowEnd: '2029-07-31',
      );
      expect(
        nextYearAvailability(source: far, siblings: [far], today: _today),
        NextYearAvailability.beyondPickerRange,
      );
      final near = _school(
        academicYear: 2027,
        windowStart: '2027-09-01',
        windowEnd: '2028-07-31',
      );
      expect(
        nextYearAvailability(source: near, siblings: [near], today: _today),
        NextYearAvailability.available,
      );
    });

    test('not offered on a tombstoned source (read-only detail)', () {
      for (final reason in SubTrackEndReason.values) {
        final ended = _school(endReason: reason);
        expect(
          nextYearAvailability(source: ended, siblings: [ended], today: _today),
          NextYearAvailability.notOffered,
          reason: reason.storage,
        );
      }
    });

    test('still offered once the window passed with no action (UJ-3)', () {
      final elapsed = _school(
        academicYear: 2025,
        windowStart: '2025-09-01',
        windowEnd: '2026-07-31',
      );
      expect(
        nextYearAvailability(
          source: elapsed,
          siblings: [elapsed],
          today: _today,
        ),
        NextYearAvailability.available,
      );
    });
  });

  test('the picker range is the school-year form\'s (DNI-495): the last '
      'pickable year agrees with academicYearOptions', () {
    expect(lastPickableAcademicYear(_today), 2028);
    expect(lastPickableAcademicYear(_today, deadline: '2025-01-01'), 2026);
    expect(
      lastPickableAcademicYear(_today, deadline: '2030-03-01'),
      academicYearOptions(today: _today, deadline: '2030-03-01').last,
    );
  });
}
