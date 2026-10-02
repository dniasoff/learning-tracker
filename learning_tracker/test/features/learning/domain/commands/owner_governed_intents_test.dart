/// DNI-476 (Story 1.14): the pure owner governed-intent builders — AD-43
/// fixed goal ids, `mainTrack*` docs carrying `curriculum_id`, tombstones
/// instead of deletes, and the AD-38 remove / re-add track actions.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/owner_governed_intents.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';

const _cid = 'mishnayos';
final _at = DateTime.utc(2026, 9, 10, 12);

SubTrack _subTrack(int n, {String curriculumId = _cid, DateTime? endedAt}) =>
    SubTrack(
      id: engineUlid(n),
      curriculumId: curriculumId,
      name: 'Sub $n',
      type: SubTrackType.ongoing,
      windowStart: '2026-09-01',
      ratePerWeek: 5,
      weeksPerYear: 50,
      learnsOnShabbos: false,
      ground: const [],
      lastChangeId: engineUlid(900 + n),
      endedAt: endedAt,
      endReason: endedAt == null ? null : SubTrackEndReason.ended,
    );

void main() {
  group('goals (AD-43)', () {
    test('the doc id is {curriculumId}_{kind} and parses back', () {
      expect(goalDocId(_cid, GoalKind.deadline), 'mishnayos_deadline');
      expect(goalDocId(_cid, GoalKind.pace), 'mishnayos_pace');
      expect(parseGoalDocId('mishnayos_deadline'), (
        curriculumId: 'mishnayos',
        kind: GoalKind.deadline,
      ));
      expect(parseGoalDocId('bavli_pace'), (
        curriculumId: 'bavli',
        kind: GoalKind.pace,
      ));
      expect(parseGoalDocId('mishnayos_2026'), isNull);
      expect(parseGoalDocId('_pace'), isNull);
    });

    test('setGoal stamps goal_type, curriculum_id and a cleared ended_at', () {
      final change = OwnerGovernedIntents.setGoal(
        curriculumId: _cid,
        kind: GoalKind.pace,
        fields: {'pace_value': 2, 'pace_unit': 'day'},
      );
      expect(change.entity, GovernedEntity.goal);
      expect(change.entityId, 'mishnayos_pace');
      expect(
        change.docs.single,
        const GovernedDocPatch(
          collection: 'goals',
          docId: 'mishnayos_pace',
          fields: {
            'pace_value': 2,
            'pace_unit': 'day',
            'goal_type': 'pace',
            'curriculum_id': _cid,
            'ended_at': null,
          },
        ),
      );
    });

    test('setGoal refuses governance keys and a mismatched type or '
        'curriculum', () {
      for (final fields in <Map<String, Object?>>[
        {'last_change_id': engineUlid(1)},
        {'ended_at': _at},
        {'goal_type': 'pace'},
        {'curriculum_id': 'bavli'},
      ]) {
        expect(
          () => OwnerGovernedIntents.setGoal(
            curriculumId: _cid,
            kind: GoalKind.deadline,
            fields: fields,
          ),
          throwsArgumentError,
          reason: '$fields',
        );
      }
    });

    test('endGoal is an ended_at tombstone of an existing doc', () {
      final change = OwnerGovernedIntents.endGoal(
        curriculumId: _cid,
        kind: GoalKind.deadline,
        at: _at,
      );
      expect(change.docs.single.fields, {'ended_at': _at});
      expect(change.docs.single.mode, DocMode.update);
    });
  });

  group('mainTrack* docs', () {
    test('every doc carries the curriculum_id; entity id is the '
        'curriculum', () {
      final change = OwnerGovernedIntents.mainTrackDocs(
        entity: GovernedEntity.mainTrackStudyDays,
        curriculumId: _cid,
        docs: {
          'a': {'day_of_week': 1},
          'b': {'day_of_week': 2},
        },
      );
      expect(change.entityId, _cid);
      expect(change.docs.map((d) => d.docId), ['a', 'b']);
      expect(
        change.docs.map((d) => d.fields['curriculum_id']),
        everyElement(_cid),
      );
      expect(
        change.docs.map((d) => d.collection),
        everyElement('study_day_configs'),
      );
    });

    test('refuses a non-mainTrack entity, no docs, last_change_id or a '
        'foreign curriculum_id', () {
      expect(
        () => OwnerGovernedIntents.mainTrackDocs(
          entity: GovernedEntity.goal,
          curriculumId: _cid,
          docs: {
            'x': {'a': 1},
          },
        ),
        throwsArgumentError,
      );
      expect(
        () => OwnerGovernedIntents.mainTrackDocs(
          entity: GovernedEntity.mainTrackScope,
          curriculumId: _cid,
          docs: const {},
        ),
        throwsArgumentError,
      );
      expect(
        () => OwnerGovernedIntents.mainTrackDocs(
          entity: GovernedEntity.mainTrackScope,
          curriculumId: _cid,
          docs: {
            'x': {'last_change_id': engineUlid(1)},
          },
        ),
        throwsArgumentError,
      );
      expect(
        () => OwnerGovernedIntents.mainTrackDocs(
          entity: GovernedEntity.mainTrackScope,
          curriculumId: _cid,
          docs: {
            'x': {'curriculum_id': 'bavli'},
          },
        ),
        throwsArgumentError,
      );
    });

    test('endMainTrackDocs tombstones each doc', () {
      final change = OwnerGovernedIntents.endMainTrackDocs(
        entity: GovernedEntity.mainTrackOrder,
        curriculumId: _cid,
        docIds: ['a', 'b'],
        at: _at,
      );
      expect(change.docs.map((d) => d.fields), [
        {'ended_at': _at, 'curriculum_id': _cid},
        {'ended_at': _at, 'curriculum_id': _cid},
      ]);
    });
  });

  group('track lifecycle (AD-38)', () {
    test('remove: one mainTrack ended_at entry, then one subTrack tombstone '
        'per non-ended sub-track of the curriculum, in id order', () {
      final action = OwnerGovernedIntents.removeTrack(
        curriculumId: _cid,
        subTracks: [
          _subTrack(3),
          _subTrack(1),
          _subTrack(2, endedAt: _at), // already ended: not tombstoned again
          _subTrack(4, curriculumId: 'bavli'), // another curriculum
        ],
        at: _at,
      );
      expect(action.changes.map((c) => (c.entity, c.entityId)), [
        (GovernedEntity.mainTrack, _cid),
        (GovernedEntity.subTrack, engineUlid(1)),
        (GovernedEntity.subTrack, engineUlid(3)),
      ]);
      expect(action.changes.first.docs.single.fields, {
        'ended_at': _at,
        'curriculum_id': _cid,
      });
      for (final c in action.changes.skip(1)) {
        expect(c.docs.single.collection, 'sub_tracks');
        expect(c.docs.single.fields, {
          'ended_at': _at,
          'end_reason': 'track_deleted',
        });
      }
    });

    test('remove with no sub-tracks is the mainTrack entry alone', () {
      final action = OwnerGovernedIntents.removeTrack(
        curriculumId: _cid,
        subTracks: const [],
        at: _at,
      );
      expect(action.changes.single.entity, GovernedEntity.mainTrack);
    });

    test('re-add clears ended_at only', () {
      final change = OwnerGovernedIntents.reAddTrack(_cid);
      expect(change.entity, GovernedEntity.mainTrack);
      expect(change.docs.single.docId, _cid);
      expect(change.docs.single.fields, {
        'ended_at': null,
        'curriculum_id': _cid,
      });
    });
  });
}
