// Story 4.1 (DNI-509) AC-1 — TutorWriteService sub-track lifecycle.
//
// createSubTrack / editSubTrack / endSubTrack / deleteSubTrack each call
// `tutorUpsertSubTrack` once with the grant routing, the sub-track ULID, the
// op, the AD-52 intent fields and the caller's client action id; the answer
// is accepted only as a validated governed receipt; `subtrack_lifecycle` is
// emitted through LearningAnalytics (enums and counts only) after a newly
// written action and never after a failure, a replay or a no-op. A tutor
// capture may carry a sub-track `source` (AC-2's client half).

@Tags(['tutor_mode'])
library;

import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_service.dart';

import '../../helpers/learner_state/fake_learning_commands.dart';

const _grantId = 'grant_1';
const _ownerUid = 'parent_uid';
const _profileId = '01JQ3K5M8N2P4R6T7V9X0Z1AB0';
const _subTrackId = '01JQ3K5M8N2P4R6T7V9X0Z1AC1';
const _nextYearId = '01JQ3K5M8N2P4R6T7V9X0Z1AC2';
const _action = '01JQ3K5M8N2P4R6T7V9X0Z1AC3';
const _event = '01JQ3K5M8N2P4R6T7V9X0Z1AC4';

const _routing = {
  'grantId': _grantId,
  'ownerUid': _ownerUid,
  'profileId': _profileId,
};

/// Records every invocation and answers from [respond].
final class _Invoker {
  _Invoker([this.respond]);

  Object? Function(String fn, Map<String, dynamic> args)? respond;
  final calls = <({String fn, Map<String, dynamic> args})>[];

  Future<Object?> call(String fn, Map<String, dynamic> args) async {
    calls.add((fn: fn, args: args));
    return respond?.call(fn, args);
  }
}

/// A validated writeWithChangeLog success for [args].
Map<String, Object?> _written(
  Map<String, dynamic> args, {
  bool replayed = false,
}) => {
  'success': true,
  'action_id': args['actionId'],
  'change_ids': [args['actionId']],
  'event_ids': <String>[],
  'at': '2026-10-03T09:00:00.000Z',
  'recorded_at': null,
  'replayed': replayed,
  'noop': false,
};

/// Answers every call with [_written].
Object? _ok(String _, Map<String, dynamic> args) => _written(args);

TutorWriteService _service(_Invoker invoker, {LearningAnalytics? analytics}) =>
    TutorWriteService(invoker: invoker.call, analytics: analytics);

const _ground = [
  NodeEntry(level: 'masechta', ref: 'Berakhot'),
  NodeEntry(level: 'masechta', ref: 'Peah'),
];

const _draft = SubTrackDraft(
  curriculumId: 'shas',
  name: 'Rebbe Gemara',
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: 5,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: _ground,
);

SubTrack _stored({
  SubTrackType type = SubTrackType.ongoing,
  int? academicYear,
  String? windowEnd,
}) => SubTrack(
  id: _subTrackId,
  curriculumId: 'shas',
  name: 'Rebbe Gemara',
  type: type,
  academicYear: academicYear,
  windowStart: '2026-09-01',
  windowEnd: windowEnd,
  ratePerWeek: 5,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: _ground,
  lastChangeId: _subTrackId,
);

Future<TutorWriteResult> _create(TutorWriteService s, {String? actionId}) =>
    s.createSubTrack(
      grantId: _grantId,
      ownerUid: _ownerUid,
      profileId: _profileId,
      subTrackId: _subTrackId,
      draft: _draft,
      actionId: actionId,
    );

Future<TutorWriteResult> _edit(
  TutorWriteService s,
  SubTrackEdit edit, {
  SubTrack? current,
}) => s.editSubTrack(
  grantId: _grantId,
  ownerUid: _ownerUid,
  profileId: _profileId,
  current: current ?? _stored(),
  edit: edit,
  actionId: _action,
);

Future<TutorWriteResult> _end(TutorWriteService s) => s.endSubTrack(
  grantId: _grantId,
  ownerUid: _ownerUid,
  profileId: _profileId,
  subTrack: _stored(),
  actionId: _action,
);

Future<TutorWriteResult> _delete(TutorWriteService s) => s.deleteSubTrack(
  grantId: _grantId,
  ownerUid: _ownerUid,
  profileId: _profileId,
  subTrack: _stored(),
  actionId: _action,
);

void main() {
  group('createSubTrack', () {
    test('calls tutorUpsertSubTrack once with the AD-52 intent fields and '
        'the sub-track ULID as the default action id', () async {
      final invoker = _Invoker(_ok);
      final result = await _create(_service(invoker));

      final call = invoker.calls.single;
      expect(call.fn, 'tutorUpsertSubTrack');
      expect(call.args, {
        ..._routing,
        'subTrackId': _subTrackId,
        'op': 'create',
        'actionId': _subTrackId,
        'fields': {
          'curriculum_id': 'shas',
          'name': 'Rebbe Gemara',
          'type': 'ongoing',
          'window_start': '2026-09-01',
          'rate_per_week': 5.0,
          'weeks_per_year': 40.0,
          'learns_on_shabbos': false,
          'ground': [
            {'level': 'masechta', 'ref': 'Berakhot'},
            {'level': 'masechta', 'ref': 'Peah'},
          ],
        },
      });
      expect(result, isA<TutorGovernedWritten>());
      expect((result as TutorGovernedWritten).actionId, _subTrackId);
      expect(result.changeIds, [_subTrackId]);
    });

    test('an explicit action id is sent and confirmed', () async {
      final invoker = _Invoker(_ok);
      final result = await _create(_service(invoker), actionId: _action);
      expect(invoker.calls.single.args['actionId'], _action);
      expect((result as TutorGovernedWritten).actionId, _action);
    });

    test(
      'Add next year is a create of a new ULID for academic_year + 1',
      () async {
        final invoker = _Invoker(_ok);
        await _service(invoker).createSubTrack(
          grantId: _grantId,
          ownerUid: _ownerUid,
          profileId: _profileId,
          subTrackId: _nextYearId,
          draft: const SubTrackDraft(
            curriculumId: 'shas',
            name: 'Yeshiva',
            type: SubTrackType.schoolYear,
            academicYear: 2027,
            windowStart: '2027-09-01',
            windowEnd: '2028-06-30',
            ratePerWeek: 3,
            weeksPerYear: 36,
            learnsOnShabbos: false,
            ground: [],
          ),
        );
        final args = invoker.calls.single.args;
        expect(args['subTrackId'], _nextYearId);
        expect(args['op'], 'create');
        final fields = args['fields'] as Map;
        expect(fields['academic_year'], 2027);
        expect(fields['window_end'], '2028-06-30');
        expect(fields['ground'], isEmpty);
      },
    );

    test('a retry re-sends a byte-for-byte identical payload', () async {
      final invoker = _Invoker(
        (_, __) => throw FirebaseFunctionsException(
          code: 'deadline-exceeded',
          message: 'timeout',
        ),
      );
      final service = _service(invoker);
      final first = await _create(service);
      expect(first, isA<TutorWriteFailure>());
      expect((first as TutorWriteFailure).isRetryable, isTrue);
      await _create(service);
      expect(
        jsonEncode(invoker.calls[1].args),
        jsonEncode(invoker.calls[0].args),
      );
    });
  });

  group('editSubTrack', () {
    test('sends only the changed fields with the edit action id', () async {
      final invoker = _Invoker(_ok);
      await _edit(
        _service(invoker),
        const SubTrackEdit(name: 'Rebbe — evening', ratePerWeek: 7),
      );
      expect(invoker.calls.single.args, {
        ..._routing,
        'subTrackId': _subTrackId,
        'op': 'edit',
        'actionId': _action,
        'fields': {'name': 'Rebbe — evening', 'rate_per_week': 7.0},
      });
    });

    test('ground add, reorder and remove send the whole new ground', () async {
      for (final ground in [
        [..._ground, const NodeEntry(level: 'perek', ref: 'Demai 1')],
        _ground.reversed.toList(),
        [_ground.first],
      ]) {
        final invoker = _Invoker(_ok);
        await _edit(_service(invoker), SubTrackEdit(ground: ground));
        expect(invoker.calls.single.args['fields'], {
          'ground': [
            for (final n in ground) {'level': n.level, 'ref': n.ref},
          ],
        });
      }
    });

    test('clearing window_end sends null; turning a school year ongoing '
        'clears academic_year', () async {
      final invoker = _Invoker(_ok);
      await _edit(
        _service(invoker),
        const SubTrackEdit(
          type: SubTrackType.ongoing,
          clearAcademicYear: true,
          clearWindowEnd: true,
        ),
        current: _stored(
          type: SubTrackType.schoolYear,
          academicYear: 2026,
          windowEnd: '2027-06-30',
        ),
      );
      expect(invoker.calls.single.args['fields'], {
        'type': 'ongoing',
        'academic_year': null,
        'window_end': null,
      });
    });

    test(
      'an edit that changes nothing calls nothing and emits nothing',
      () async {
        final invoker = _Invoker(_ok);
        final analytics = RecordingLearningAnalytics();
        final result = await _edit(
          _service(invoker, analytics: analytics),
          const SubTrackEdit(name: 'Rebbe Gemara', ratePerWeek: 5),
        );
        expect(result, isA<TutorWriteSuccess>());
        expect(invoker.calls, isEmpty);
        expect(analytics.lifecycles, isEmpty);
      },
    );
  });

  group('endSubTrack / deleteSubTrack', () {
    test('end calls op end with no fields', () async {
      final invoker = _Invoker(_ok);
      await _end(_service(invoker));
      expect(invoker.calls.single.args, {
        ..._routing,
        'subTrackId': _subTrackId,
        'op': 'end',
        'actionId': _action,
      });
    });

    test('delete calls op delete with no fields (a tombstone)', () async {
      final invoker = _Invoker(_ok);
      await _delete(_service(invoker));
      expect(invoker.calls.single.args, {
        ..._routing,
        'subTrackId': _subTrackId,
        'op': 'delete',
        'actionId': _action,
      });
    });
  });

  group('subtrack_lifecycle analytics after a successful callable only', () {
    test('create, edit, end and delete each emit ONE event with enums and '
        'counts', () async {
      final analytics = RecordingLearningAnalytics();
      final service = _service(_Invoker(_ok), analytics: analytics);
      await _create(service);
      await _edit(service, SubTrackEdit(ground: [_ground.first]));
      await _end(service);
      await _delete(service);
      expect(analytics.lifecycles, [
        (
          curriculumId: 'shas',
          type: SubTrackType.ongoing,
          action: SubTrackLifecycleAction.create,
          groundEntries: 2,
        ),
        (
          curriculumId: 'shas',
          type: SubTrackType.ongoing,
          action: SubTrackLifecycleAction.edit,
          groundEntries: 1,
        ),
        (
          curriculumId: 'shas',
          type: SubTrackType.ongoing,
          action: SubTrackLifecycleAction.end,
          groundEntries: 2,
        ),
        (
          curriculumId: 'shas',
          type: SubTrackType.ongoing,
          action: SubTrackLifecycleAction.delete,
          groundEntries: 2,
        ),
      ]);
      expect(analytics.captures, isEmpty);
    });

    test(
      'the registered payload carries no name, ref, date or learner id',
      () async {
        final sent = <(LearningAnalyticsEvent, Map<String, Object>)>[];
        final analytics = SinkLearningAnalytics((e, p) => sent.add((e, p)));
        await _create(_service(_Invoker(_ok), analytics: analytics));
        expect(sent, hasLength(1));
        final (event, payload) = sent.single;
        expect(event, LearningAnalyticsEvent.subTrackLifecycle);
        expect(payload, {
          'curriculum_id': 'shas',
          'track_type': 'ongoing',
          'action': 'create',
          'ground_entries': 2,
        });
        final text = jsonEncode(payload);
        for (final secret in [
          'Rebbe',
          'Berakhot',
          '2026-09-01',
          _profileId,
          _subTrackId,
          _ownerUid,
        ]) {
          expect(text, isNot(contains(secret)));
        }
      },
    );

    final failures = <String, Object? Function(String, Map<String, dynamic>)>{
      'an AD-45 rejection': (_, __) => throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'Sub-track rule violated: ongoing_limit',
      ),
      'a revoked permission': (_, __) => throw FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'Grant lacks can_edit_learning',
      ),
      'a malformed answer': (_, args) => {
        'success': true,
        'action_id': args['actionId'],
        'change_ids': [args['actionId']],
        'replayed': false,
      },
      'an answer for another action': (_, args) => {
        ..._written(args),
        'action_id': _event,
      },
      'a replay of a stored action': (_, args) =>
          _written(args, replayed: true),
      'a server no-op': (_, args) => {
        ..._written(args),
        'change_ids': <String>[],
        'at': null,
        'noop': true,
      },
    };
    for (final MapEntry(key: name, value: respond) in failures.entries) {
      test('$name emits nothing', () async {
        final analytics = RecordingLearningAnalytics();
        final service = _service(_Invoker(respond), analytics: analytics);
        await _create(service);
        await _edit(service, const SubTrackEdit(name: 'x'));
        await _end(service);
        await _delete(service);
        expect(analytics.lifecycles, isEmpty);
      });
    }

    test('failures map to the shared typed failures', () async {
      expect(
        await _create(_service(_Invoker(failures['an AD-45 rejection']))),
        isA<TutorWriteFailure>().having(
          (f) => f.code,
          'code',
          'failed-precondition',
        ),
      );
      expect(
        await _end(_service(_Invoker(failures['a revoked permission']))),
        isA<TutorWriteEditingTurnedOff>(),
      );
      expect(
        await _delete(_service(_Invoker(failures['a malformed answer']))),
        isA<TutorWriteInvalidResponse>(),
      );
    });
  });

  group('a capture on the sub-track row (AC-2 client half)', () {
    const subTrackEvent = TutorLearnEvent(
      id: _event,
      curriculumId: 'mishnayos',
      ref: 'Mishnah Beitzah 3:1',
      dateState: DateState.dated,
      learnedOn: '2026-10-01',
      source: _subTrackId,
    );

    test('sends the sub-track ULID as source and reports a sub_track '
        'capture', () async {
      final analytics = RecordingLearningAnalytics();
      final invoker = _Invoker(
        (_, __) => {
          'success': true,
          'action_id': _event,
          'event_ids': [_event],
          'recorded_at': '2026-10-03T09:00:00.000Z',
          'replayed': false,
        },
      );
      await _service(invoker, analytics: analytics).recordLearning(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        events: const [subTrackEvent],
      );
      final events = invoker.calls.single.args['events'] as List;
      expect((events.single as Map)['fields'], {
        'kind': 'learn',
        'curriculum_id': 'mishnayos',
        'ref': 'Mishnah Beitzah 3:1',
        'source': _subTrackId,
        'date_state': 'dated',
        'learned_on': '2026-10-01',
      });
      expect(analytics.captures, [
        (
          curriculumId: 'mishnayos',
          sourceKind: CaptureSourceKind.subTrack,
          dateState: DateState.dated,
          count: 1,
        ),
      ]);
      expect(analytics.lifecycles, isEmpty);
    });
  });
}
