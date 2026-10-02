/// Story 2.8 (DNI-499) AC-5: the active / ended split of the learner's
/// sub-tracks on the learner's civil today, and the AD-45 limits ignoring
/// ended and elapsed-window records.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_lifecycle.dart';

import '../../../helpers/learner_state/c0_fixtures.dart';
import '../../../helpers/learner_state/in_memory_ports.dart';
import '../../../helpers/learner_state_fixtures.dart';

const _today = '2026-10-01';

String _id(int n) => '01JTEST0000000000000000${n.toString().padLeft(3, '0')}';

SubTrack _track(
  int n, {
  String curriculumId = 'shas',
  SubTrackType type = SubTrackType.ongoing,
  int? academicYear,
  String windowStart = '2026-09-01',
  String? windowEnd,
  SubTrackEndReason? endReason,
}) => SubTrack(
  id: _id(n),
  curriculumId: curriculumId,
  name: 'Track $n',
  type: type,
  academicYear: academicYear,
  windowStart: windowStart,
  windowEnd: windowEnd,
  ratePerWeek: 5,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: const [NodeEntry(level: 'masechta', ref: 'Berakhot')],
  lastChangeId: ulidE,
  endedAt: endReason == null ? null : t1,
  endReason: endReason,
);

void main() {
  group('active / ended split on the learner civil today', () {
    final live = _track(1);
    final future = _track(2, windowStart: '2027-01-01');
    final lastDay = _track(3, windowEnd: _today);
    final elapsed = _track(4, windowEnd: '2026-09-30');
    final ended = _track(5, endReason: SubTrackEndReason.ended);
    final deleted = _track(6, endReason: SubTrackEndReason.deleted);
    final endedFuture = _track(
      7,
      windowStart: '2027-01-01',
      endReason: SubTrackEndReason.ended,
    );
    final open = _track(8);
    final all = [live, future, lastDay, elapsed, ended, deleted, endedFuture];

    test('ended and elapsed tracks are ended; the rest are active, in '
        'order', () {
      final groups = groupSubTracksByLifecycle(all, _today);
      expect(groups.active, [live, future, lastDay]);
      expect(groups.ended, [elapsed, ended, deleted, endedFuture]);
      expect(groups.all, [...groups.active, ...groups.ended]);
    });

    test('window_end is inclusive; the next day ends it', () {
      expect(isEndedSubTrack(lastDay, _today), isFalse);
      expect(isEndedSubTrack(lastDay, '2026-10-02'), isTrue);
    });

    test('a stored ended_at wins over a future window', () {
      expect(isEndedSubTrack(endedFuture, _today), isTrue);
    });

    test('a null window_end stays open', () {
      expect(isEndedSubTrack(open, '2099-12-31'), isFalse);
    });

    test('the curriculum filter keeps one curriculum', () {
      final other = _track(9, curriculumId: 'mishnayos');
      final groups = groupSubTracksByLifecycle(
        [live, other, elapsed],
        _today,
        curriculumId: 'shas',
      );
      expect(groups.active, [live]);
      expect(groups.ended, [elapsed]);
    });

    test('empty input is two empty groups', () {
      final groups = groupSubTracksByLifecycle(const [], _today);
      expect(groups.active, isEmpty);
      expect(groups.ended, isEmpty);
    });

    test('the split reads the repository complete read, live and ended, '
        'without writing', () async {
      final scope = c0Scope();
      final repo = InMemorySubTrackRepository()..seed(scope, all);
      final read = await repo
          .watchAll(scope)
          .firstWhere((r) => r is CompleteReadReady<SubTrack>);
      final items = (read as CompleteReadReady<SubTrack>).items;
      final groups = groupSubTracksByLifecycle(items, _today);
      expect(groups.active.map((t) => t.id).toSet(), {
        live.id,
        future.id,
        lastDay.id,
      });
      expect(groups.ended, hasLength(4));
      expect(repo.calls, isEmpty);
      expect(repo.entries, isEmpty);
      await repo.dispose();
    });
  });

  group('ended and elapsed records do not consume AD-45 limits', () {
    test('five ongoing: two of them ended / elapsed leave room for more', () {
      final siblings = [
        _track(1),
        _track(2),
        _track(3),
        _track(4, windowEnd: '2026-09-30'),
        _track(5, endReason: SubTrackEndReason.ended),
      ];
      final violations = subTrackLimitViolations(
        candidate: _track(10),
        prior: null,
        siblings: siblings,
        today: _today,
        calendarProgramId: null,
      );
      expect(violations, isEmpty);
      for (final s in siblings.skip(3)) {
        expect(countsTowardSubTrackLimits(s, _today), isFalse);
        expect(isEndedSubTrack(s, _today), isTrue);
      }
    });

    test('an ended school year frees its academic year', () {
      final endedYear = _track(
        1,
        type: SubTrackType.schoolYear,
        academicYear: 2026,
        windowEnd: '2027-07-31',
        endReason: SubTrackEndReason.deleted,
      );
      final violations = subTrackLimitViolations(
        candidate: _track(
          2,
          type: SubTrackType.schoolYear,
          academicYear: 2026,
          windowEnd: '2027-07-31',
        ),
        prior: null,
        siblings: [endedYear],
        today: _today,
        calendarProgramId: null,
      );
      expect(violations, isEmpty);
    });

    test('ended and elapsed rows never make Add next year "used"', () {
      final source = _track(
        1,
        type: SubTrackType.schoolYear,
        academicYear: 2026,
        windowEnd: '2027-07-31',
      );
      final endedNext = _track(
        2,
        type: SubTrackType.schoolYear,
        academicYear: 2027,
        windowStart: '2027-09-01',
        windowEnd: '2028-07-31',
        endReason: SubTrackEndReason.deleted,
      );
      expect(
        nextYearAvailability(
          source: source,
          siblings: [source, endedNext],
          today: _today,
        ),
        NextYearAvailability.available,
      );
    });
  });
}
