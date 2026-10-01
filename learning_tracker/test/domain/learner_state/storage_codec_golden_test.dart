/// AC-2 (DNI-464): each AD-52 model encodes exactly its schema keys and
/// decodes the golden map. Edge: unknown fields and invalid enum values
/// cannot silently widen the contract.
///
/// [_schemaTable] below is this test's copy of the spine's Storage Schema
/// table (ARCHITECTURE-SPINE.md "Storage Schema"). Each type's declared
/// `storageKeys` must equal its row set, so adding, renaming or dropping a
/// field in code without editing that table (and this copy) fails here.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../../helpers/learner_state_fixtures.dart';

const Map<String, Set<String>> _schemaTable = {
  'LearningEvent': {
    'kind',
    'curriculum_id',
    'ref',
    'level',
    'source',
    'date_state',
    'learned_on',
    'stage',
    'target_id',
    'reverts_action_id',
    'original_recorded_at',
    'recorded_at',
    'actor',
  },
  'Actor': {'uid', 'role', 'display_name'},
  'NodeEntry': {'level', 'ref'},
  'SubTrack': {
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
  },
  'ChangeLogEntry': {
    'entity',
    'entity_id',
    'action_id',
    'reverts_action_id',
    'before',
    'after',
    'at',
    'actor',
    'original_at',
  },
  'LearnerSettings': {
    'latitude',
    'longitude',
    'time_zone',
    'in_israel',
    'last_change_id',
  },
  'MainTrack': {'state', 'curriculum_id', 'last_change_id', 'ended_at'},
  'MainTrackProgram': {
    'program_id',
    'tracking_start_date',
    'tracking_start_ref',
    'curriculum_id',
    'last_change_id',
    'ended_at',
  },
  'MainTrackOrderEntry': {
    'curriculum_id',
    'level',
    'ref',
    'user_sort_order',
    'last_change_id',
    'ended_at',
  },
};

Map<String, Object?> _subTrackGolden() => {
  'curriculum_id': 'mishnayos',
  'name': 'Shiur Mishnayos',
  'type': 'school_year',
  'academic_year': 2026,
  'window_start': '2026-09-01',
  'window_end': '2027-06-30',
  'rate_per_week': 7.0,
  'weeks_per_year': 40.0,
  'learns_on_shabbos': false,
  'ground': [
    {'level': 'masechta', 'ref': 'Mishnah Berakhot'},
    {'level': 'perek', 'ref': 'Mishnah Peah 1'},
  ],
  'ended_at': t1,
  'end_reason': 'ended',
  'last_change_id': ulidC,
};

Map<String, Object?> _changeLogGolden() => {
  'entity': 'subTrack',
  'entity_id': ulidB,
  'action_id': ulidD,
  'reverts_action_id': ulidE,
  'before': {
    'sub_tracks/$ulidB.rate_per_week': 5,
    'sub_tracks/$ulidB.ended_at': null,
  },
  'after': {
    'sub_tracks/$ulidB.rate_per_week': 7,
    'sub_tracks/$ulidB.ended_at': t1,
  },
  'at': t0,
  'actor': Map<String, Object?>.of(parentActorMap),
  'original_at': t2,
};

Map<String, Object?> _settingsGolden() => {
  'latitude': 31.778,
  'longitude': 35.235,
  'time_zone': 'Asia/Jerusalem',
  'in_israel': true,
  'last_change_id': ulidC,
};

Map<String, Map<String, Object?>> _intentGolden() => {
  'curriculum_tracks/mishnayos': {
    'state': 'active',
    'curriculum_id': 'mishnayos',
    'last_change_id': ulidA,
  },
  'profile_programs/mishnayos': {
    'program_id': 'mishna_yomit',
    'tracking_start_date': '2026-09-01',
    'tracking_start_ref': 'Mishnah Berakhot 1:1',
    'curriculum_id': 'mishnayos',
    'last_change_id': ulidB,
  },
  'track_learning_order/mishnayos_masechta_Mishnah Berakhot': {
    'level': 'masechta',
    'ref': 'Mishnah Berakhot',
    'user_sort_order': 0,
    'curriculum_id': 'mishnayos',
    'last_change_id': ulidC,
    'ended_at': t1,
  },
  'study_day_configs/mishnayos_0': {
    'day_of_week': 0,
    'curriculum_id': 'mishnayos',
  },
  'stage_definitions/mishnayos_1': {
    'stage_order': 1,
    'curriculum_id': 'mishnayos',
    'last_change_id': ulidD,
  },
  'curriculum_scopes/mishnayos': {
    'scope_level': 'seder',
    'scope_value': 'Zeraim',
    'curriculum_id': 'mishnayos',
  },
};

void _expectExact(Map<String, Object?> encoded, Map<String, Object?> golden) {
  expect(encoded.keys.toSet(), golden.keys.toSet());
  expect(encoded, equals(golden));
}

void main() {
  group('AD-52 schema table matches each type\'s declared key set', () {
    test('every type', () {
      expect(LearningEvent.storageKeys, _schemaTable['LearningEvent']);
      expect(Actor.storageKeys, _schemaTable['Actor']);
      expect(NodeEntry.storageKeys, _schemaTable['NodeEntry']);
      expect(SubTrack.storageKeys, _schemaTable['SubTrack']);
      expect(ChangeLogEntry.storageKeys, _schemaTable['ChangeLogEntry']);
      expect(LearnerSettings.storageKeys, _schemaTable['LearnerSettings']);
      expect(MainTrack.storageKeys, _schemaTable['MainTrack']);
      expect(MainTrackProgram.storageKeys, _schemaTable['MainTrackProgram']);
      expect(
        MainTrackOrderEntry.storageKeys,
        _schemaTable['MainTrackOrderEntry'],
      );
    });
  });

  group('each AD-52 model encodes exactly its schema keys and decodes the '
      'golden map', () {
    test('Actor', () {
      final decoded = Actor.fromStorage(parentActorMap);
      expect(decoded, parentActor);
      _expectExact(decoded.toStorage(), parentActorMap);
    });

    test('NodeEntry', () {
      const golden = {'level': 'perek', 'ref': 'Mishnah Peah 1'};
      final decoded = NodeEntry.fromStorage(golden);
      _expectExact(decoded.toStorage(), golden);
    });

    test('LearningEvent — learn, every optional field present', () {
      final golden = {
        'kind': 'learn',
        'curriculum_id': 'mishnayos',
        'ref': 'Mishnah Berakhot',
        'level': 'masechta',
        'source': 'main',
        'date_state': 'before_tracking',
        'learned_on': null,
        'stage': 1,
        'original_recorded_at': t2,
        'recorded_at': t0,
        'actor': Map<String, Object?>.of(parentActorMap),
      };
      final decoded = LearningEvent.fromStorage(ulidA, golden);
      _expectExact(decoded.toStorage(), golden);
      expect(
        golden.keys.toSet().difference(_schemaTable['LearningEvent']!),
        isEmpty,
      );
    });

    test('LearningEvent — learn, optional fields omitted; learned_on kept '
        'as an explicit key', () {
      final golden = datedLearnMap()..remove('stage');
      final decoded = LearningEvent.fromStorage(ulidA, golden);
      final encoded = decoded.toStorage();
      _expectExact(encoded, golden);
      expect(encoded.containsKey('level'), isFalse);
      expect(encoded.containsKey('original_recorded_at'), isFalse);
      expect(encoded.containsKey('target_id'), isFalse);
    });

    test('LearningEvent — void with undo metadata', () {
      final golden = {
        'kind': 'void',
        'target_id': ulidB,
        'reverts_action_id': ulidC,
        'original_recorded_at': t2,
        'recorded_at': t0,
        'actor': Map<String, Object?>.of(parentActorMap),
      };
      final decoded = LearningEvent.fromStorage(ulidA, golden);
      _expectExact(decoded.toStorage(), golden);
    });

    test('SubTrack — every field, tombstoned', () {
      final golden = _subTrackGolden();
      final decoded = SubTrack.fromStorage(ulidB, golden);
      _expectExact(decoded.toStorage(), golden);
      expect(golden.keys.toSet(), _schemaTable['SubTrack']);
    });

    test('SubTrack — ongoing, open window: window_end kept as explicit null, '
        'academic_year / ended_at / end_reason omitted', () {
      final golden = _subTrackGolden()
        ..['type'] = 'ongoing'
        ..remove('academic_year')
        ..['window_end'] = null
        ..remove('ended_at')
        ..remove('end_reason');
      final decoded = SubTrack.fromStorage(ulidB, golden);
      _expectExact(decoded.toStorage(), golden);
    });

    test('ChangeLogEntry — every field', () {
      final golden = _changeLogGolden();
      final decoded = ChangeLogEntry.fromStorage(ulidA, golden);
      _expectExact(decoded.toStorage(), golden);
      expect(golden.keys.toSet(), _schemaTable['ChangeLogEntry']);
    });

    test('ChangeLogEntry — optional fields omitted', () {
      final golden = _changeLogGolden()
        ..remove('reverts_action_id')
        ..remove('original_at');
      final decoded = ChangeLogEntry.fromStorage(ulidA, golden);
      _expectExact(decoded.toStorage(), golden);
    });

    test('LearnerSettings — every field', () {
      final golden = _settingsGolden();
      final decoded = LearnerSettings.fromProfileDoc(profileUlid, golden);
      _expectExact(decoded.toStorage(), golden);
    });

    test('LearnerSettings — no location: only time_zone is required', () {
      const golden = {'time_zone': 'America/New_York'};
      final decoded = LearnerSettings.fromProfileDoc(profileUlid, golden);
      _expectExact(decoded.toStorage(), golden);
      expect(decoded.hasLocation, isFalse);
    });

    test('MainTrackIntent — assembled from its governed docs, each doc '
        'round-trips exactly', () {
      final golden = _intentGolden();
      final intent = MainTrackIntent.fromStorageDocs('mishnayos', golden);
      final encoded = intent.toStorageDocs();
      expect(encoded.keys.toSet(), golden.keys.toSet());
      for (final key in golden.keys) {
        _expectExact(encoded[key]!, golden[key]!);
      }
      expect(intent.isEvaluated, isTrue);
      expect(intent.order.single.endedAt, t1);
    });
  });

  group('unknown fields and invalid enum values cannot silently widen the '
      'contract', () {
    final strictCases = <String, void Function()>{
      'LearningEvent unknown key': () =>
          LearningEvent.fromStorage(ulidA, datedLearnMap()..['points'] = 3),
      'LearningEvent invalid kind': () =>
          LearningEvent.fromStorage(ulidA, datedLearnMap()..['kind'] = 'redo'),
      'LearningEvent invalid date_state': () => LearningEvent.fromStorage(
        ulidA,
        datedLearnMap()..['date_state'] = 'late',
      ),
      'LearningEvent missing recorded_at': () => LearningEvent.fromStorage(
        ulidA,
        datedLearnMap()..remove('recorded_at'),
      ),
      'LearningEvent recorded_at wrong type': () => LearningEvent.fromStorage(
        ulidA,
        datedLearnMap()..['recorded_at'] = '2026-09-01T00:00:00Z',
      ),
      'LearningEvent non-ULID id': () =>
          LearningEvent.fromStorage('not-a-ulid', datedLearnMap()),
      'Actor unknown key': () =>
          Actor.fromStorage({...parentActorMap, 'email': 'x@example.com'}),
      'NodeEntry unknown key': () =>
          NodeEntry.fromStorage({'level': 'perek', 'ref': 'x', 'title': 'y'}),
      'SubTrack unknown key': () =>
          SubTrack.fromStorage(ulidB, _subTrackGolden()..['updated_at'] = t0),
      'SubTrack invalid type': () =>
          SubTrack.fromStorage(ulidB, _subTrackGolden()..['type'] = 'summer'),
      'SubTrack invalid end_reason': () => SubTrack.fromStorage(
        ulidB,
        _subTrackGolden()..['end_reason'] = 'purged',
      ),
      'SubTrack ground entry with unknown key': () => SubTrack.fromStorage(
        ulidB,
        _subTrackGolden()
          ..['ground'] = [
            {'level': 'perek', 'ref': 'x', 'extra': 1},
          ],
      ),
      'ChangeLogEntry unknown key': () => ChangeLogEntry.fromStorage(
        ulidA,
        _changeLogGolden()..['note'] = 'hi',
      ),
      'ChangeLogEntry invalid entity': () => ChangeLogEntry.fromStorage(
        ulidA,
        _changeLogGolden()..['entity'] = 'bookmark',
      ),
      'ChangeLogEntry changed field outside its collection': () =>
          ChangeLogEntry.fromStorage(
            ulidA,
            _changeLogGolden()
              ..['before'] = {'goals/x.target_date': null}
              ..['after'] = {'goals/x.target_date': '2027-01-01'},
          ),
      'ChangeLogEntry malformed changed-field key': () =>
          ChangeLogEntry.fromStorage(
            ulidA,
            _changeLogGolden()
              ..['before'] = {'rate_per_week': null}
              ..['after'] = {'rate_per_week': 7},
          ),
      'ChangeLogEntry before/after key mismatch': () =>
          ChangeLogEntry.fromStorage(
            ulidA,
            _changeLogGolden()..['before'] = <String, Object?>{},
          ),
      'MainTrack invalid state': () => MainTrackIntent.fromStorageDocs(
        'mishnayos',
        _intentGolden()
          ..['curriculum_tracks/mishnayos'] = {
            'state': 'paused',
            'curriculum_id': 'mishnayos',
          },
      ),
      'MainTrackIntent foreign collection': () =>
          MainTrackIntent.fromStorageDocs(
            'mishnayos',
            _intentGolden()..['bookmarks/mishnayos'] = {'x': 1},
          ),
      'MainTrackIntent curriculum mismatch': () =>
          MainTrackIntent.fromStorageDocs(
            'mishnayos',
            _intentGolden()
              ..['study_day_configs/tanach_0'] = {'curriculum_id': 'tanach'},
          ),
      'LearnerSettings bad time_zone': () => LearnerSettings.fromProfileDoc(
        profileUlid,
        _settingsGolden()..['time_zone'] = '+02:00',
      ),
    };
    for (final entry in strictCases.entries) {
      test(entry.key, () {
        expect(entry.value, throwsA(isA<StorageFormatException>()));
      });
    }

    test('projected docs (shared, pre-existing collections) drop unknown '
        'keys instead of re-emitting them', () {
      final profileDoc = {
        ..._settingsGolden(),
        'display_name': 'Moshe',
        'avatar': 'lion',
      };
      final settings = LearnerSettings.fromProfileDoc(profileUlid, profileDoc);
      expect(settings.toStorage().keys.toSet(), _settingsGolden().keys.toSet());

      final docs = _intentGolden()
        ..['curriculum_tracks/mishnayos'] = {
          'state': 'active',
          'curriculum_id': 'mishnayos',
          'purged': false,
          'state_changed_at': t0,
        }
        ..['study_day_configs/mishnayos_0'] = {
          'day_of_week': 0,
          'curriculum_id': 'mishnayos',
          'updated_at': t0,
          'synced_at': t0,
        };
      final intent = MainTrackIntent.fromStorageDocs('mishnayos', docs);
      final encoded = intent.toStorageDocs();
      expect(encoded['curriculum_tracks/mishnayos']!.keys.toSet(), {
        'state',
        'curriculum_id',
      });
      expect(encoded['study_day_configs/mishnayos_0']!.keys.toSet(), {
        'day_of_week',
        'curriculum_id',
      });
    });
  });
}
