/// AC-3 (DNI-464): invalid event field combinations are rejected during
/// encoding (and, symmetrically, during decoding).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

import '../../helpers/learner_state_fixtures.dart';

Matcher _rejects(String field) => throwsA(
  isA<StorageFormatException>().having((e) => e.field, 'field', field),
);

LearningEvent _learn({
  DateState dateState = DateState.dated,
  String? learnedOn = '2026-09-01',
  String source = LearningEvent.sourceMain,
  String? level,
  int? stage,
  String? targetId,
  String? revertsActionId,
}) => LearningEvent.learn(
  id: ulidA,
  curriculumId: 'mishnayos',
  ref: 'Mishnah Berakhot 1:1',
  source: source,
  dateState: dateState,
  learnedOn: learnedOn,
  level: level,
  stage: stage,
  targetId: targetId,
  revertsActionId: revertsActionId,
  recordedAt: t0,
  actor: parentActor,
);

void main() {
  group('invalid event field combinations are rejected during encoding', () {
    test('void without target_id', () {
      // The voidOf constructor requires a target; a decoded map is the only
      // way to reach a void without one.
      expect(
        () => LearningEvent.fromStorage(ulidA, {
          'kind': 'void',
          'recorded_at': t0,
          'actor': Map<String, Object?>.of(parentActorMap),
        }),
        _rejects('target_id'),
      );
    });

    test('learn with target_id', () {
      expect(() => _learn(targetId: ulidB).toStorage(), _rejects('target_id'));
    });

    test('level on a non-before_tracking event', () {
      for (final state in [DateState.dated, DateState.catchUp]) {
        expect(
          () => _learn(dateState: state, level: 'perek').toStorage(),
          _rejects('level'),
        );
      }
    });

    test('stage on a source != main event', () {
      expect(
        () => _learn(source: ulidC, stage: 1).toStorage(),
        _rejects('stage'),
      );
    });

    test(r'learned_on not matching ^\d{4}-\d{2}-\d{2}$', () {
      for (final bad in ['2026-9-1', '01-09-2026', '2026/09/01', '', 'x']) {
        expect(
          () => _learn(learnedOn: bad).toStorage(),
          _rejects('learned_on'),
          reason: bad,
        );
      }
    });

    test('learned_on matching the pattern but not a real calendar date', () {
      for (final bad in [
        '2026-02-30',
        '2026-13-01',
        '2026-00-10',
        '2025-02-29',
      ]) {
        expect(
          () => _learn(learnedOn: bad).toStorage(),
          _rejects('learned_on'),
          reason: bad,
        );
      }
      // Leap day is fine.
      expect(
        _learn(learnedOn: '2024-02-29').toStorage()['learned_on'],
        '2024-02-29',
      );
    });

    test('learned_on == null unless date_state == before_tracking', () {
      for (final state in [DateState.dated, DateState.catchUp]) {
        expect(
          () => _learn(dateState: state, learnedOn: null).toStorage(),
          _rejects('learned_on'),
        );
      }
    });

    test('actor.role outside {parent, child, tutor}', () {
      expect(
        () => LearningEvent.fromStorage(
          ulidA,
          datedLearnMap()
            ..['actor'] = {'uid': 'u', 'role': 'admin', 'display_name': 'x'},
        ),
        throwsA(
          isA<StorageFormatException>()
              .having((e) => e.type, 'type', 'Actor')
              .having((e) => e.field, 'field', 'role'),
        ),
      );
    });

    test('a void carrying learn-only fields', () {
      expect(
        () => LearningEvent.voidOf(
          id: ulidA,
          targetId: ulidB,
          recordedAt: t0,
          actor: parentActor,
          curriculumId: 'mishnayos',
        ).toStorage(),
        _rejects('curriculum_id'),
      );
      expect(
        () => LearningEvent.fromStorage(ulidA, {
          'kind': 'void',
          'target_id': ulidB,
          'learned_on': null,
          'recorded_at': t0,
          'actor': Map<String, Object?>.of(parentActorMap),
        }),
        _rejects('learned_on'),
      );
      for (final key in LearningEvent.learnOnlyKeys) {
        expect(
          () => LearningEvent.fromStorage(ulidA, {
            'kind': 'void',
            'target_id': ulidB,
            key: null,
            'recorded_at': t0,
            'actor': Map<String, Object?>.of(parentActorMap),
          }),
          _rejects(key),
          reason: key,
        );
      }
    });

    test('reverts_action_id on a learn event', () {
      expect(
        () => _learn(revertsActionId: ulidC).toStorage(),
        _rejects('reverts_action_id'),
      );
    });

    test('source that is neither main nor a ULID', () {
      expect(() => _learn(source: 'sub-1').toStorage(), _rejects('source'));
    });

    test('non-ULID event id never reaches storage', () {
      final event = LearningEvent.learn(
        id: '',
        curriculumId: 'mishnayos',
        ref: 'r',
        source: 'main',
        dateState: DateState.dated,
        learnedOn: '2026-09-01',
        recordedAt: t0,
        actor: parentActor,
      );
      expect(event.toStorage, _rejects('<id>'));
    });

    test('decode applies the same combination rules', () {
      expect(
        () => LearningEvent.fromStorage(
          ulidA,
          datedLearnMap()..['level'] = 'perek',
        ),
        _rejects('level'),
      );
      expect(
        () => LearningEvent.fromStorage(
          ulidA,
          datedLearnMap()..['learned_on'] = '2026-02-30',
        ),
        _rejects('learned_on'),
      );
      expect(
        () => LearningEvent.fromStorage(
          ulidA,
          datedLearnMap()..remove('learned_on'),
        ),
        _rejects('learned_on'),
      );
    });
  });

  group('valid examples encode', () {
    test('void', () {
      final map = LearningEvent.voidOf(
        id: ulidA,
        targetId: ulidB,
        recordedAt: t0,
        actor: parentActor,
      ).toStorage();
      expect(map, {
        'kind': 'void',
        'target_id': ulidB,
        'recorded_at': t0,
        'actor': parentActorMap,
      });
    });

    test('before_tracking node event with level and null learned_on', () {
      final map = _learn(
        dateState: DateState.beforeTracking,
        learnedOn: null,
        level: 'masechta',
      ).toStorage();
      expect(map['level'], 'masechta');
      expect(map.containsKey('learned_on'), isTrue);
      expect(map['learned_on'], isNull);
    });

    test('catch_up sub-track event without stage', () {
      final map = _learn(
        dateState: DateState.catchUp,
        source: ulidC,
      ).toStorage();
      expect(map['source'], ulidC);
      expect(map.containsKey('stage'), isFalse);
    });

    test('child and tutor actors are valid roles', () {
      for (final role in ['child', 'tutor']) {
        final event = LearningEvent.fromStorage(
          ulidA,
          datedLearnMap()
            ..['actor'] = {'uid': 'u', 'role': role, 'display_name': ''},
        );
        expect(event.actor.role.storage, role);
      }
    });
  });
}
