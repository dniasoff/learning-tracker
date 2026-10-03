/// Story 2.1 (DNI-492) AC-1: the Story 1.2 [SubTrack] codec round-trips
/// every AD-52 `sub_tracks/{ulid}` field and enum unchanged.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../../helpers/learner_state_fixtures.dart';

const _ground = [
  NodeEntry(level: 'seder', ref: 'Zeraim'),
  NodeEntry(level: 'masechta', ref: 'Mishnah Peah'),
  NodeEntry(level: 'perek', ref: 'Mishnah Berakhot 3'),
];

Map<String, Object?> _ongoingMap() => {
  'curriculum_id': 'mishnayos',
  'name': 'Night seder',
  'type': 'ongoing',
  'window_start': '2026-09-01',
  'window_end': null,
  'rate_per_week': 3.5,
  'weeks_per_year': 40,
  'learns_on_shabbos': true,
  'ground': [
    for (final g in _ground) {'level': g.level, 'ref': g.ref},
  ],
  'last_change_id': ulidC,
};

Map<String, Object?> _schoolMap() => {
  ..._ongoingMap(),
  'type': 'school_year',
  'academic_year': 2026,
  'window_end': '2027-06-30',
};

void main() {
  test('the codec reads and writes exactly the AD-52 key set', () {
    expect(SubTrack.storageKeys, {
      'curriculum_id',
      'name',
      'type',
      'academic_year',
      'window_start',
      'window_end',
      'rate_per_week',
      'weeks_per_year',
      'learns_on_shabbos',
      'ground',
      'ended_at',
      'end_reason',
      'last_change_id',
    });
    final ended = SubTrack.fromStorage(ulidB, {
      ..._schoolMap(),
      'ended_at': t1,
      'end_reason': 'ended',
    });
    expect(ended.toStorage().keys.toSet(), SubTrack.storageKeys);
  });

  test('an ongoing sub-track with an open window round-trips', () {
    final track = SubTrack.fromStorage(ulidB, _ongoingMap());
    expect(track.windowEnd, isNull);
    expect(track.academicYear, isNull);
    final stored = track.toStorage();
    // window_end is always emitted (null = open); academic_year is not.
    expect(stored.containsKey('window_end'), isTrue);
    expect(stored['window_end'], isNull);
    expect(stored.containsKey('academic_year'), isFalse);
    expect(storageValueEquals(stored, _ongoingMap()), isTrue);
    expect(SubTrack.fromStorage(ulidB, stored), track);
  });

  test('academic_year is school-year only', () {
    final school = SubTrack.fromStorage(ulidB, _schoolMap());
    expect(school.type, SubTrackType.schoolYear);
    expect(school.toStorage()['academic_year'], 2026);
    expect(
      () => SubTrack.fromStorage(ulidB, {..._ongoingMap(), 'academic_year': 1}),
      throwsA(isA<StorageFormatException>()),
    );
    expect(
      () => SubTrack.fromStorage(
        ulidB,
        {..._schoolMap()}..remove('academic_year'),
      ),
      throwsA(isA<StorageFormatException>()),
    );
  });

  test('ground keeps its entered order through a round trip', () {
    final track = SubTrack.fromStorage(ulidB, _ongoingMap());
    expect(track.ground, _ground);
    final reordered = SubTrack.fromStorage(ulidB, {
      ..._ongoingMap(),
      'ground': [
        for (final g in _ground.reversed) {'level': g.level, 'ref': g.ref},
      ],
    });
    expect(reordered.ground, _ground.reversed.toList());
    expect(reordered, isNot(track));
    expect(SubTrack.fromStorage(ulidB, reordered.toStorage()), reordered);
  });

  for (final reason in SubTrackEndReason.values) {
    test('end_reason ${reason.storage} round-trips with ended_at', () {
      final track = SubTrack.fromStorage(ulidB, {
        ..._ongoingMap(),
        'ended_at': t1,
        'end_reason': reason.storage,
      });
      expect(track.endReason, reason);
      expect(track.endedAt, t1);
      expect(track.isEnded, isTrue);
      final stored = track.toStorage();
      expect(stored['end_reason'], reason.storage);
      expect(stored['ended_at'], t1);
      expect(SubTrack.fromStorage(ulidB, stored), track);
    });
  }

  test('every type enum round-trips by its storage string', () {
    expect(SubTrackType.values.map((t) => t.storage), [
      'school_year',
      'ongoing',
    ]);
    expect(SubTrackEndReason.values.map((r) => r.storage), [
      'ended',
      'deleted',
      'undo',
      'track_deleted',
    ]);
  });

  test('dates stay YYYY-MM-DD civil-date strings (AD-41)', () {
    final stored = SubTrack.fromStorage(ulidB, _schoolMap()).toStorage();
    expect(stored['window_start'], '2026-09-01');
    expect(stored['window_end'], '2027-06-30');
    expect(stored['window_start'], isA<String>());
    for (final bad in ['2026-9-1', '2026-09-01T00:00:00Z', '01/09/2026']) {
      expect(
        () => SubTrack.fromStorage(ulidB, {
          ..._ongoingMap(),
          'window_start': bad,
        }),
        throwsA(isA<StorageFormatException>()),
        reason: bad,
      );
    }
  });

  test('rate_per_week stays in curriculum leaf units, unconverted', () {
    final track = SubTrack.fromStorage(ulidB, _ongoingMap());
    expect(track.ratePerWeek, 3.5);
    expect(track.toStorage()['rate_per_week'], 3.5);
    expect(track.toStorage()['weeks_per_year'], 40);
  });

  test('an unknown field is rejected (the AD-52 whitelist)', () {
    expect(
      () => SubTrack.fromStorage(ulidB, {..._ongoingMap(), 'color': 'blue'}),
      throwsA(isA<StorageFormatException>()),
    );
  });
}
