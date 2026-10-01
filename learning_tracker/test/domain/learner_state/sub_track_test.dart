/// Unit tests for [SubTrack].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../../helpers/learner_state_fixtures.dart';

SubTrack _track({
  SubTrackType type = SubTrackType.ongoing,
  int? academicYear,
  String windowStart = '2026-09-01',
  String? windowEnd,
  double rate = 7,
  DateTime? endedAt,
  SubTrackEndReason? endReason,
  String lastChangeId = ulidC,
}) => SubTrack(
  id: ulidB,
  curriculumId: 'mishnayos',
  name: 'Shiur',
  type: type,
  academicYear: academicYear,
  windowStart: windowStart,
  windowEnd: windowEnd,
  ratePerWeek: rate,
  weeksPerYear: 40,
  learnsOnShabbos: true,
  ground: const [NodeEntry(level: 'seder', ref: 'Zeraim')],
  endedAt: endedAt,
  endReason: endReason,
  lastChangeId: lastChangeId,
);

void main() {
  test('round-trips through storage', () {
    final t = _track(endedAt: t1, endReason: SubTrackEndReason.deleted);
    expect(SubTrack.fromStorage(ulidB, t.toStorage()), t);
    expect(t.isEnded, isTrue);
  });

  test('academic_year required for school_year, forbidden for ongoing', () {
    expect(
      _track(type: SubTrackType.schoolYear).toStorage,
      throwsA(isA<StorageFormatException>()),
    );
    expect(
      _track(academicYear: 2026).toStorage,
      throwsA(isA<StorageFormatException>()),
    );
    expect(
      _track(
        type: SubTrackType.schoolYear,
        academicYear: 2026,
      ).toStorage()['academic_year'],
      2026,
    );
  });

  test('window dates are civil dates and ordered', () {
    expect(
      _track(windowStart: '2026-9-1').toStorage,
      throwsA(isA<StorageFormatException>()),
    );
    expect(
      _track(windowEnd: '2026-08-31').toStorage,
      throwsA(isA<StorageFormatException>()),
    );
    expect(
      _track(windowEnd: '2026-09-01').toStorage()['window_end'],
      '2026-09-01',
    );
  });

  test('ended_at and end_reason are consistent', () {
    expect(
      _track(endedAt: t1).toStorage,
      throwsA(isA<StorageFormatException>()),
    );
    expect(
      _track(endReason: SubTrackEndReason.ended).toStorage,
      throwsA(isA<StorageFormatException>()),
    );
  });

  test('numbers non-negative; last_change_id a ULID', () {
    expect(_track(rate: -1).toStorage, throwsA(isA<StorageFormatException>()));
    expect(
      _track(lastChangeId: 'x').toStorage,
      throwsA(isA<StorageFormatException>()),
    );
  });

  test('end_reason storage values', () {
    expect(SubTrackEndReason.byStorage.keys.toSet(), {
      'ended',
      'deleted',
      'undo',
      'track_deleted',
    });
  });

  group('validateGovernedField', () {
    test('accepts well-typed values and nullable clears', () {
      SubTrack.validateGovernedField('rate_per_week', 3);
      SubTrack.validateGovernedField('window_end', null);
      SubTrack.validateGovernedField('ended_at', null);
      SubTrack.validateGovernedField('end_reason', 'track_deleted');
      SubTrack.validateGovernedField('ground', [
        {'level': 'perek', 'ref': 'x'},
      ]);
    });

    test('rejects non-governed keys and bad values', () {
      for (final (key, value) in <(String, Object?)>[
        ('last_change_id', ulidA),
        ('updated_at', t0),
        ('name', null),
        ('type', 'summer'),
        ('window_start', '2026-02-30'),
        ('rate_per_week', -2),
        ('learns_on_shabbos', 'yes'),
        (
          'ground',
          [
            {'level': 'perek'},
          ],
        ),
        ('ended_at', '2026-01-01'),
        ('end_reason', 'purged'),
      ]) {
        expect(
          () => SubTrack.validateGovernedField(key, value),
          throwsA(isA<StorageFormatException>()),
          reason: key,
        );
      }
    });
  });
}
