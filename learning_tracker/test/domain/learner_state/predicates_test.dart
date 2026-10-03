// DNI-467 AC-2: the AD-34 sub-track predicates over ended, future, active
// and open-ended windows.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/predicates.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

SubTrack _track({
  required String start,
  String? end,
  bool ended = false,
  SubTrackEndReason reason = SubTrackEndReason.ended,
}) => SubTrack(
  id: engineUlid(500),
  curriculumId: engineCurriculum,
  name: 'Shiur',
  type: SubTrackType.ongoing,
  windowStart: start,
  windowEnd: end,
  ratePerWeek: 2,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: const [NodeEntry(level: 'masechta', ref: 'Mishnah Peah')],
  lastChangeId: engineUlid(501),
  endedAt: ended ? engineAt(1) : null,
  endReason: ended ? reason : null,
);

void main() {
  const today = '2026-10-01';

  // name → (track, holdsGround, onHome, inForecast with deadline
  // 2026-12-31, inForecast with no deadline).
  final matrix = <String, (SubTrack, bool, bool, bool, bool)>{
    'active, bounded': (
      _track(start: '2026-09-01', end: '2027-06-30'),
      true,
      true,
      true,
      true,
    ),
    'active, open-ended': (_track(start: '2026-09-01'), true, true, true, true),
    'future start, bounded': (
      _track(start: '2026-11-01', end: '2027-06-30'),
      true,
      false,
      true,
      true,
    ),
    'future start, open-ended': (
      _track(start: '2027-02-01'),
      true,
      false,
      // Capacity interval [2027-02-01, deadline 2026-12-31] is empty.
      false,
      true,
    ),
    'window already over': (
      _track(start: '2026-01-01', end: '2026-09-30'),
      false,
      false,
      false,
      false,
    ),
    'ended (tombstoned), still inside its window': (
      _track(start: '2026-09-01', end: '2027-06-30', ended: true),
      false,
      false,
      false,
      false,
    ),
    'ended, open-ended': (
      _track(start: '2026-09-01', ended: true),
      false,
      false,
      false,
      false,
    ),
  };

  for (final MapEntry(key: name, value: row) in matrix.entries) {
    final (track, holds, home, forecast, forecastNoDeadline) = row;
    group(name, () {
      test('holdsGround', () => expect(holdsGround(track, today), holds));
      test('onHome', () => expect(onHome(track, today), home));
      test('inForecast with a deadline', () {
        expect(inForecast(track, today, deadline: '2026-12-31'), forecast);
      });
      test('inForecast with no deadline', () {
        expect(inForecast(track, today, deadline: null), forecastNoDeadline);
      });
    });
  }

  group('window bounds are inclusive civil dates', () {
    final track = _track(start: '2026-10-01', end: '2026-10-31');

    test('on window_start and on window_end', () {
      for (final day in ['2026-10-01', '2026-10-31']) {
        expect(holdsGround(track, day), isTrue, reason: day);
        expect(onHome(track, day), isTrue, reason: day);
      }
    });

    test('the day after window_end holds nothing', () {
      expect(holdsGround(track, '2026-11-01'), isFalse);
      expect(onHome(track, '2026-11-01'), isFalse);
      expect(inForecast(track, '2026-11-01', deadline: null), isFalse);
    });

    test('a deadline on today keeps a one-day capacity interval', () {
      expect(inForecast(track, '2026-10-05', deadline: '2026-10-05'), isTrue);
      expect(inForecast(track, '2026-10-05', deadline: '2026-10-04'), isFalse);
    });
  });

  test('a null window_end is +∞ far in the future', () {
    final track = _track(start: '2026-09-01');
    expect(holdsGround(track, '2099-12-31'), isTrue);
    expect(onHome(track, '2099-12-31'), isTrue);
  });

  test('DNI-493 AC-1/AC-5: every tombstone (ended, deleted, undo, '
      'track_deleted) holds no ground and shows nowhere', () {
    for (final reason in SubTrackEndReason.values) {
      final track = _track(
        start: '2026-09-01',
        end: '2027-06-30',
        ended: true,
        reason: reason,
      );
      expect(holdsGround(track, today), isFalse, reason: reason.storage);
      expect(onHome(track, today), isFalse, reason: reason.storage);
      expect(
        inForecast(track, today, deadline: '2026-12-31'),
        isFalse,
        reason: reason.storage,
      );
    }
  });

  test('DNI-493 AC-1: the day before window_start holds ground but is not '
      'on home', () {
    final track = _track(start: '2026-10-02', end: '2026-10-31');
    expect(holdsGround(track, today), isTrue);
    expect(onHome(track, today), isFalse);
    expect(onHome(track, '2026-10-02'), isTrue);
  });
}
