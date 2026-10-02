// Story 1.24 (DNI-486) AC-1, AC-5 edge — TutorWriteService learning and
// governed command dispatch.
//
// Each typed method calls its Story 1.23 / Story 1.10 callable exactly once
// with the typed input and the caller's client ULIDs; a failure comes back
// as the typed failure; a retry re-sends a byte-for-byte identical payload.

@Tags(['tutor_mode', 'dni_486'])
library;

import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_service.dart';

import '../../helpers/learner_state/fake_learning_commands.dart';

const _grantId = 'grant_1';
const _ownerUid = 'parent_uid';
const _profileId = '01JQ3K5M8N2P4R6T7V9X0Z1AB0';
const _e1 = '01JQ3K5M8N2P4R6T7V9X0Z1AB1';
const _e2 = '01JQ3K5M8N2P4R6T7V9X0Z1AB2';
const _void = '01JQ3K5M8N2P4R6T7V9X0Z1AB3';
const _action = '01JQ3K5M8N2P4R6T7V9X0Z1AB4';

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

TutorWriteService _service(_Invoker invoker, {LearningAnalytics? analytics}) =>
    TutorWriteService(invoker: invoker.call, analytics: analytics);

const _dated1 = TutorLearnEvent(
  id: _e1,
  curriculumId: 'mishnayos',
  ref: 'Mishnah Berakhot 2:1',
  dateState: DateState.dated,
  learnedOn: '2026-10-01',
  stage: 1,
);
const _dated2 = TutorLearnEvent(
  id: _e2,
  curriculumId: 'mishnayos',
  ref: 'Mishnah Berakhot 2:2',
  dateState: DateState.dated,
  learnedOn: '2026-10-01',
  stage: 1,
);

Future<TutorWriteResult> _record(TutorWriteService s) => s.recordLearning(
  grantId: _grantId,
  ownerUid: _ownerUid,
  profileId: _profileId,
  events: const [_dated1, _dated2],
);

void main() {
  group('recordLearning', () {
    test('calls tutorRecordLearning once with the typed storage-shaped '
        'events and the first event id as the action id', () async {
      final invoker = _Invoker();
      await _record(_service(invoker));

      final call = invoker.calls.single;
      expect(call.fn, 'tutorRecordLearning');
      expect(call.args, {
        'grantId': _grantId,
        'ownerUid': _ownerUid,
        'profileId': _profileId,
        'actionId': _e1,
        'events': [
          {
            'id': _e1,
            'fields': {
              'kind': 'learn',
              'curriculum_id': 'mishnayos',
              'ref': 'Mishnah Berakhot 2:1',
              'source': 'main',
              'date_state': 'dated',
              'learned_on': '2026-10-01',
              'stage': 1,
            },
          },
          {
            'id': _e2,
            'fields': {
              'kind': 'learn',
              'curriculum_id': 'mishnayos',
              'ref': 'Mishnah Berakhot 2:2',
              'source': 'main',
              'date_state': 'dated',
              'learned_on': '2026-10-01',
              'stage': 1,
            },
          },
        ],
      });
    });

    test('a before_tracking node event carries level and learned_on null, '
        'never actor or recorded_at', () async {
      final invoker = _Invoker();
      await _service(invoker).recordLearning(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        events: const [
          TutorLearnEvent(
            id: _e1,
            curriculumId: 'mishnayos',
            ref: 'Mishnah Berakhot',
            level: 'masechet',
            dateState: DateState.beforeTracking,
          ),
        ],
      );
      final fields =
          ((invoker.calls.single.args['events'] as List).single
                  as Map)['fields']
              as Map;
      expect(fields, {
        'kind': 'learn',
        'curriculum_id': 'mishnayos',
        'ref': 'Mishnah Berakhot',
        'source': 'main',
        'date_state': 'before_tracking',
        'learned_on': null,
        'level': 'masechet',
      });
      expect(fields.containsKey('actor'), isFalse);
      expect(fields.containsKey('recorded_at'), isFalse);
    });

    test('decodes the server-stamped recorded_at, event ids and replay '
        'flag', () async {
      final invoker = _Invoker(
        (_, __) => {
          'success': true,
          'action_id': _e1,
          'event_ids': [_e1, _e2],
          'recorded_at': '2026-10-02T15:20:00.000Z',
          'replayed': false,
        },
      );
      final result = await _record(_service(invoker));

      expect(result, isA<TutorLearningWritten>());
      final written = result as TutorLearningWritten;
      expect(written.actionId, _e1);
      expect(written.eventIds, [_e1, _e2]);
      expect(written.recordedAt, DateTime.utc(2026, 10, 2, 15, 20));
      expect(written.replayed, isFalse);
    });

    test('a callable rejection is the typed failure, never a throw', () async {
      final invoker = _Invoker((_, __) {
        throw FirebaseFunctionsException(
          code: 'invalid-argument',
          message: 'source must be main',
        );
      });
      final result = await _record(_service(invoker));
      expect(result, isA<TutorWriteFailure>());
      expect((result as TutorWriteFailure).code, 'invalid-argument');
      expect(result.isRetryable, isFalse);
    });

    test(
      'a parent turning editing off maps to TutorWriteEditingTurnedOff',
      () async {
        final invoker = _Invoker((_, __) {
          throw FirebaseFunctionsException(
            code: 'permission-denied',
            message: 'Grant lacks can_edit_learning',
          );
        });
        expect(
          await _record(_service(invoker)),
          isA<TutorWriteEditingTurnedOff>(),
        );
      },
    );
  });

  group('Edge AC-1/AC-5: retry after an ambiguous timeout', () {
    test('a timeout is a retryable failure and the retry payload is '
        'byte-for-byte identical (same ULIDs)', () async {
      var attempt = 0;
      final invoker = _Invoker((_, __) {
        attempt++;
        if (attempt == 1) {
          throw FirebaseFunctionsException(
            code: 'deadline-exceeded',
            message: 'timeout',
          );
        }
        return {
          'action_id': _e1,
          'event_ids': [_e1, _e2],
          'recorded_at': '2026-10-02T15:20:00.000Z',
          'replayed': true,
        };
      });
      final service = _service(invoker);

      final first = await _record(service);
      expect(first, isA<TutorWriteFailure>());
      expect((first as TutorWriteFailure).isRetryable, isTrue);

      final second = await _record(service);
      expect(second, isA<TutorLearningWritten>());
      expect((second as TutorLearningWritten).replayed, isTrue);

      expect(invoker.calls, hasLength(2));
      expect(
        jsonEncode(invoker.calls[1].args),
        jsonEncode(invoker.calls[0].args),
      );
    });

    test('an unexpected client error (no network) is retryable', () async {
      final invoker = _Invoker((_, __) => throw Exception('socket closed'));
      final result = await _record(_service(invoker));
      expect((result as TutorWriteFailure).isRetryable, isTrue);
    });
  });

  group('voidLearning / replaceLearning / unlearn', () {
    test('voidLearning calls tutorVoidLearning with the void id as the '
        'action id and no replacement', () async {
      final invoker = _Invoker();
      await _service(invoker).voidLearning(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        eventId: _void,
        targetId: _e1,
      );
      expect(invoker.calls.single.fn, 'tutorVoidLearning');
      expect(invoker.calls.single.args, {
        'grantId': _grantId,
        'ownerUid': _ownerUid,
        'profileId': _profileId,
        'actionId': _void,
        'eventId': _void,
        'targetId': _e1,
      });
    });

    test('replaceLearning is ONE tutorVoidLearning call carrying the '
        'corrected learn event', () async {
      final invoker = _Invoker();
      await _service(invoker).replaceLearning(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        eventId: _void,
        targetId: _e1,
        replacement: _dated2,
      );
      final call = invoker.calls.single;
      expect(call.fn, 'tutorVoidLearning');
      expect(call.args['targetId'], _e1);
      expect(call.args['replacement'], _dated2.toWire());
    });

    test('unlearn calls tutorUnlearn with the leaf set and the client '
        'unlearn plan (ruling B9)', () async {
      final invoker = _Invoker();
      await _service(invoker).unlearn(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        actionId: _action,
        curriculumId: 'mishnayos',
        leafSet: const ['Mishnah Berakhot 2:1'],
        nodeReissues: const [
          TutorNodeReissue(
            targetEventId: _e1,
            reissues: [
              (eventId: _e2, ref: 'Mishnah Berakhot 1', level: 'perek'),
            ],
          ),
        ],
      );
      expect(invoker.calls.single.fn, 'tutorUnlearn');
      expect(invoker.calls.single.args, {
        'grantId': _grantId,
        'ownerUid': _ownerUid,
        'profileId': _profileId,
        'actionId': _action,
        'curriculumId': 'mishnayos',
        'leafSet': ['Mishnah Berakhot 2:1'],
        'nodeReissues': [
          {
            'targetEventId': _e1,
            'reissues': [
              {'eventId': _e2, 'ref': 'Mishnah Berakhot 1', 'level': 'perek'},
            ],
          },
        ],
      });
    });
  });

  group('main-track governed methods (Story 1.10 callables)', () {
    test('a client actionId is forwarded and the result decodes the '
        'change-log ids', () async {
      final invoker = _Invoker(
        (_, __) => {
          'action_id': _action,
          'change_ids': [_action],
          'at': '2026-10-02T15:20:00.000Z',
          'replayed': false,
        },
      );
      final result = await _service(invoker).upsertStudyDayConfig(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        configId: 'mishnayos_1',
        configData: const {'curriculum_id': 'mishnayos', 'day_of_week': 1},
        actionId: _action,
      );
      expect(invoker.calls.single.fn, 'tutorUpsertStudyDayConfig');
      expect(invoker.calls.single.args['actionId'], _action);
      final written = result as TutorGovernedWritten;
      expect(written.actionId, _action);
      expect(written.changeIds, [_action]);
      expect(written.at, DateTime.utc(2026, 10, 2, 15, 20));
    });

    test('without an actionId the legacy request shape is unchanged', () async {
      final invoker = _Invoker();
      await _service(invoker).deleteGoal(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        goalId: 'mishnayos_pace',
      );
      expect(invoker.calls.single.args.containsKey('actionId'), isFalse);
    });
  });
  group('AC-1: capture analytics after a successful callable only', () {
    Map<String, Object?> written({bool replayed = false}) => {
      'action_id': _e1,
      'event_ids': [_e1, _e2],
      'recorded_at': '2026-10-02T15:20:00.000Z',
      'replayed': replayed,
    };

    test('success emits ONE registered capture event: enums and a count, '
        'no ref or learner identity', () async {
      final analytics = RecordingLearningAnalytics();
      await _record(
        _service(_Invoker((_, __) => written()), analytics: analytics),
      );
      expect(analytics.captures, [
        (
          curriculumId: 'mishnayos',
          sourceKind: CaptureSourceKind.main,
          dateState: DateState.dated,
          count: 2,
        ),
      ]);
    });

    test('a failed callable emits nothing', () async {
      final analytics = RecordingLearningAnalytics();
      await _record(
        _service(
          _Invoker((_, __) {
            throw FirebaseFunctionsException(
              code: 'permission-denied',
              message: 'denied',
            );
          }),
          analytics: analytics,
        ),
      );
      expect(analytics.captures, isEmpty);
    });

    test('a replayed action (retry after a lost answer) emits no second '
        'capture', () async {
      final analytics = RecordingLearningAnalytics();
      await _record(
        _service(
          _Invoker((_, __) => written(replayed: true)),
          analytics: analytics,
        ),
      );
      expect(analytics.captures, isEmpty);
    });

    test('voids, replacements and un-learns are not captures', () async {
      final analytics = RecordingLearningAnalytics();
      final service = _service(
        _Invoker((_, __) => written()),
        analytics: analytics,
      );
      await service.voidLearning(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        eventId: _void,
        targetId: _e1,
      );
      await service.replaceLearning(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        eventId: _void,
        targetId: _e1,
        replacement: _dated2,
      );
      await service.unlearn(
        grantId: _grantId,
        ownerUid: _ownerUid,
        profileId: _profileId,
        actionId: _action,
        curriculumId: 'mishnayos',
        leafSet: const ['Mishnah Berakhot 2:1'],
      );
      expect(analytics.captures, isEmpty);
    });
  });
}
