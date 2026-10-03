// Story 4.2 (DNI-510) T3 — the tutor's LearningCommands route every
// sub-track write the shared Epic 2 surfaces make through the typed
// TutorWriteService methods (Story 4.1): create / edit (reorder, remove,
// ground append) / end / delete → `tutorUpsertSubTrack`; a capture on a
// sub-track → `tutorRecordLearning` with the sub-track ULID as source; a
// correction of a main-track event to a sub-track → ONE atomic
// `tutorVoidLearning` replace whose copy carries the sub-track source. The
// result comes only from the callable's answer, the preflight blocks any
// call first, and a retried save replays the same client ULIDs.

@Tags(['tutor_mode'])
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state_fixtures.dart';
import '../../../../helpers/tutoring/tutor_learning_harness.dart';

const _rebbeId = '01JT7T0SV0RRRRRRRRRRRRRRRA';

/// The groundless ongoing "Rebbe" sub-track (5 per week) of AC-3.
const _rebbeDraft = SubTrackDraft(
  curriculumId: engineCurriculum,
  name: 'Rebbe',
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: 5,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: [],
);

SubTrack _rebbe({
  List<NodeEntry> ground = const [],
  DateTime? endedAt,
  String id = _rebbeId,
}) => SubTrack(
  id: id,
  curriculumId: engineCurriculum,
  name: 'Rebbe',
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: 5,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: ground,
  endedAt: endedAt,
  endReason: endedAt == null ? null : SubTrackEndReason.ended,
  lastChangeId: ulidC,
);

TutorHarness _harness({
  List<SubTrack>? subTracks = const [],
  bool canEditLearning = true,
  bool online = true,
  List<LearningEvent>? events,
}) {
  final h = TutorHarness(
    canEditLearning: canEditLearning,
    online: online,
    subTracks: subTracks == null ? null : [...subTracks],
    corpora: {engineCurriculum: mishnayosCorpus()},
    events: events,
  );
  addTearDown(h.dispose);
  return h;
}

Map<String, Object?> _fields(TutorCall call) =>
    Map<String, Object?>.from(call.args['fields'] as Map);

List<Map<String, Object?>> _eventFields(TutorCall call) => [
  for (final e in call.args['events'] as List)
    Map<String, Object?>.from((e as Map)['fields'] as Map),
];

void main() {
  group('createSubTrack → tutorUpsertSubTrack create', () {
    test(
      'a groundless Rebbe track is one create call with the grant routing '
      'and the AD-52 intent; the result carries the server receipt',
      () async {
        final h = _harness();

        final result = await h.commands.createSubTrack(
          _rebbeDraft,
          subTrackId: _rebbeId,
        );

        final call = h.invoker.calls.single;
        expect(call.fn, 'tutorUpsertSubTrack');
        expect(call.args['grantId'], tutorFixtureGrantId);
        expect(call.args['ownerUid'], tutorFixtureOwnerUid);
        expect(call.args['profileId'], profileUlid);
        expect(call.args['subTrackId'], _rebbeId);
        expect(call.args['op'], 'create');
        expect(call.args['actionId'], _rebbeId);
        expect(_fields(call), containsPair(SubTrack.kName, 'Rebbe'));
        expect(_fields(call), containsPair(SubTrack.kRatePerWeek, 5.0));
        expect(_fields(call)[SubTrack.kGround], isEmpty);
        expect(
          result,
          const CaptureResult.success(
            changeIds: [_rebbeId],
            actionId: _rebbeId,
          ),
        );
      },
    );

    test('Add next year is a create reported as add_next_year', () async {
      final school = SubTrack(
        id: ulidD,
        curriculumId: engineCurriculum,
        name: 'School',
        type: SubTrackType.schoolYear,
        academicYear: 2026,
        windowStart: '2026-09-01',
        windowEnd: '2027-07-31',
        ratePerWeek: 8,
        weeksPerYear: 36,
        learnsOnShabbos: true,
        ground: const [],
        lastChangeId: ulidE,
      );
      final h = _harness(subTracks: [school]);

      final result = await h.commands.createSubTrack(
        const SubTrackDraft(
          curriculumId: engineCurriculum,
          name: 'School',
          type: SubTrackType.schoolYear,
          academicYear: 2027,
          windowStart: '2027-09-01',
          windowEnd: '2028-07-31',
          ratePerWeek: 8,
          weeksPerYear: 36,
          learnsOnShabbos: true,
          ground: [],
        ),
        subTrackId: _rebbeId,
        nextYearOf: ulidD,
      );

      expect(result, isA<CaptureSuccess>());
      expect(h.invoker.calls.single.args['op'], 'create');
      expect(
        h.analytics.lifecycles.single.action,
        SubTrackLifecycleAction.addNextYear,
      );
    });

    test('Add next year of a missing or ended track calls nothing', () async {
      final h = _harness(subTracks: [_rebbe(endedAt: tutorFixtureNow)]);

      for (final source in [_rebbeId, ulidA]) {
        expect(
          await h.commands.createSubTrack(_rebbeDraft, nextYearOf: source),
          const CaptureResult.rejected(CaptureRejection.targetNotFound),
        );
      }
      expect(h.invoker.calls, isEmpty);
    });

    test('an AD-45 violation is refused with its violations before any call '
        '(the same answer the owner form gets)', () async {
      final h = _harness(
        subTracks: [
          for (var i = 0; i < 5; i++) _rebbe(id: '01JT7T0SV0RRRRRRRRRRRRRRR$i'),
        ],
      );

      final result = await h.commands.createSubTrack(
        _rebbeDraft,
        subTrackId: _rebbeId,
      );

      expect(result, isA<CaptureRejected>());
      expect(
        (result as CaptureRejected).violations.map((v) => v.limit),
        contains(SubTrackLimit.ongoingLimit),
      );
      expect(h.invoker.calls, isEmpty);
    });

    test('an unreadable sub-track list answers onlineRequired and calls '
        'nothing', () async {
      final h = _harness(subTracks: null);
      expect(
        await h.commands.createSubTrack(_rebbeDraft),
        const CaptureResult.onlineRequired(),
      );
      expect(h.invoker.calls, isEmpty);
    });
  });

  group('editSubTrack → tutorUpsertSubTrack edit', () {
    test('Add ground appends the picked node to the latest ground and sends '
        'the whole new ground', () async {
      final h = _harness(subTracks: [_rebbe()]);

      final result = await h.commands.editSubTrack(
        _rebbeId,
        const SubTrackEdit(appendGround: [peah]),
      );

      final call = h.invoker.calls.single;
      expect(call.args['op'], 'edit');
      expect(call.args['subTrackId'], _rebbeId);
      expect(_fields(call).keys, [SubTrack.kGround]);
      expect(_fields(call)[SubTrack.kGround], [
        {NodeEntry.kLevel: 'masechta', NodeEntry.kRef: 'Mishnah Peah'},
      ]);
      expect(result, isA<CaptureSuccess>());
    });

    test('a reorder or removal sends the whole new ground once', () async {
      final h = _harness(
        subTracks: [
          _rebbe(ground: const [peah, berakhot1]),
        ],
      );

      await h.commands.editSubTrack(
        _rebbeId,
        const SubTrackEdit(ground: [berakhot1]),
      );

      expect(_fields(h.invoker.calls.single)[SubTrack.kGround], [
        {NodeEntry.kLevel: 'chapter', NodeEntry.kRef: 'Mishnah Berakhot 1'},
      ]);
    });

    test(
      'picked ground of another curriculum is refused before any call',
      () async {
        final h = _harness(subTracks: [_rebbe()]);
        final result = await h.commands.editSubTrack(
          _rebbeId,
          const SubTrackEdit(
            appendGround: [NodeEntry(level: 'masechta', ref: 'Berakhot')],
          ),
        );
        expect(result, isA<CaptureRejected>());
        expect(h.invoker.calls, isEmpty);
      },
    );

    test('an edit that changes nothing calls nothing', () async {
      final h = _harness(
        subTracks: [
          _rebbe(ground: const [peah]),
        ],
      );
      expect(
        await h.commands.editSubTrack(
          _rebbeId,
          const SubTrackEdit(appendGround: [peah]),
        ),
        const CaptureResult.success(),
      );
      expect(h.invoker.calls, isEmpty);
    });

    test('a missing or ended sub-track is refused without a call', () async {
      final h = _harness(subTracks: [_rebbe(endedAt: tutorFixtureNow)]);
      expect(
        await h.commands.editSubTrack(ulidA, const SubTrackEdit(name: 'X')),
        const CaptureResult.rejected(CaptureRejection.targetNotFound),
      );
      expect(
        await h.commands.editSubTrack(_rebbeId, const SubTrackEdit(name: 'X')),
        const CaptureResult.rejected(CaptureRejection.invalid),
      );
      expect(h.invoker.calls, isEmpty);
    });
  });

  group('end / delete → tutorUpsertSubTrack tombstones', () {
    test('End and Delete are one call each with their op', () async {
      final h = _harness(subTracks: [_rebbe()]);
      expect(await h.commands.endSubTrack(_rebbeId), isA<CaptureSuccess>());
      expect(await h.commands.deleteSubTrack(_rebbeId), isA<CaptureSuccess>());
      expect(
        [for (final c in h.invoker.calls) c.args['op']],
        ['end', 'delete'],
      );
      expect(h.invoker.calls.every((c) => c.args['fields'] == null), isTrue);
    });

    test('an already ended track writes nothing', () async {
      final h = _harness(subTracks: [_rebbe(endedAt: tutorFixtureNow)]);
      expect(
        await h.commands.endSubTrack(_rebbeId),
        const CaptureResult.success(),
      );
      expect(h.invoker.calls, isEmpty);
    });
  });

  group('preflight and failures', () {
    test(
      'no editing access, offline or a locked talmid: nothing is called',
      () async {
        final noAccess = _harness(
          subTracks: [_rebbe()],
          canEditLearning: false,
        );
        expect(
          await noAccess.commands.endSubTrack(_rebbeId),
          const CaptureResult.rejected(CaptureRejection.editingTurnedOff),
        );
        final offline = _harness(subTracks: [_rebbe()], online: false);
        expect(
          await offline.commands.createSubTrack(_rebbeDraft),
          const CaptureResult.onlineRequired(),
        );
        final window = LockWindow(
          DateTime.utc(2026, 10, 1, 8),
          DateTime.utc(2026, 10, 2, 20),
        );
        final locked = TutorHarness(
          gate: FakeCaptureGate.locked(window),
          subTracks: [_rebbe()],
        );
        addTearDown(locked.dispose);
        expect(
          await locked.commands.editSubTrack(
            _rebbeId,
            const SubTrackEdit(appendGround: [peah]),
          ),
          CaptureResult.locked(window),
        );
        expect([...noAccess.invoker.calls, ...offline.invoker.calls], isEmpty);
        expect(locked.invoker.calls, isEmpty);
      },
    );

    test('a retryable failure answers notSaved and a retried save replays '
        'the same action id; success releases it', () async {
      final h = _harness(subTracks: [_rebbe()]);
      var fail = true;
      h.invoker.respond = (call) {
        if (fail) {
          throw FirebaseFunctionsException(
            code: 'unavailable',
            message: 'network',
          );
        }
        return h.invoker.successFor(call);
      };

      const edit = SubTrackEdit(appendGround: [peah]);
      expect(
        await h.commands.editSubTrack(_rebbeId, edit),
        const CaptureResult.rejected(CaptureRejection.notSaved),
      );
      fail = false;
      expect(
        await h.commands.editSubTrack(_rebbeId, edit),
        isA<CaptureSuccess>(),
      );

      final ids = [for (final c in h.invoker.calls) c.args['actionId']];
      expect(ids, hasLength(2));
      expect(ids.first, ids.last, reason: 'the retry replays the action');
      expect(h.ledger.length, 0);
    });

    test('the server revoking editing access maps to editingTurnedOff and '
        'shows nothing as saved', () async {
      final h = _harness(subTracks: [_rebbe()]);
      h.invoker.respond = (_) => throw FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'Grant lacks can_edit_learning',
      );
      final result = await h.commands.createSubTrack(_rebbeDraft);
      expect(result, isA<CaptureRejected>());
      expect(result, isNot(isA<CaptureSuccess>()));
    });
  });

  group(
    'sub-track capture → tutorRecordLearning with the sub-track source',
    () {
      test('+1 / Up to… on the talmid\'s sub-track is one dated call with the '
          'sub-track ULID as source and no stage', () async {
        final h = _harness(
          subTracks: [
            _rebbe(ground: const [peah]),
          ],
        );

        final result = await h.commands.capture(
          curriculumId: engineCurriculum,
          refs: const ['Mishnah Peah 1:1'],
          source: _rebbeId,
          dateState: DateState.dated,
        );

        final call = h.invoker.calls.single;
        expect(call.fn, 'tutorRecordLearning');
        final fields = _eventFields(call).single;
        expect(fields['source'], _rebbeId);
        expect(fields['date_state'], 'dated');
        expect(fields.containsKey('stage'), isFalse);
        expect(result, isA<CaptureSuccess>());
      });

      test(
        'a sub-track capture before tracking or with a stage is refused',
        () async {
          final h = _harness();
          for (final (dateState, stage) in [
            (DateState.beforeTracking, null),
            (DateState.dated, 1),
          ]) {
            expect(
              await h.commands.capture(
                curriculumId: engineCurriculum,
                refs: const ['Mishnah Peah 1:1'],
                source: _rebbeId,
                dateState: dateState,
                stage: stage,
              ),
              const CaptureResult.rejected(CaptureRejection.invalid),
            );
          }
          expect(h.invoker.calls, isEmpty);
        },
      );

      test(
        'skipRecorded drops a leaf the log already records in that track',
        () async {
          final h = _harness(
            events: [engineLearn(1, 'Mishnah Peah 1:1', source: _rebbeId)],
          );

          final result = await h.commands.capture(
            curriculumId: engineCurriculum,
            refs: const ['Mishnah Peah 1:1', 'Mishnah Peah 1:2'],
            source: _rebbeId,
            dateState: DateState.dated,
            skipRecorded: true,
          );

          expect(_eventFields(h.invoker.calls.single).map((f) => f['ref']), [
            'Mishnah Peah 1:2',
          ]);
          expect((result as CaptureSuccess).alreadyRecordedRefs, [
            'Mishnah Peah 1:1',
          ]);
        },
      );
    },
  );

  group('Correct source → one atomic replace onto the sub-track', () {
    LearningEvent mainLearn({String source = LearningEvent.sourceMain}) =>
        engineLearn(
          1,
          'Mishnah Peah 1:1',
          source: source,
          learnedOn: '2026-09-30',
        );

    test('a main-track event corrected to a sub-track is ONE replace call '
        'whose copy is on the sub-track, keeping its date', () async {
      final h = _harness(events: [mainLearn()]);

      final result = await h.commands.replace(
        engineUlid(1),
        const EventReplacement(source: _rebbeId),
      );

      final call = h.invoker.calls.single;
      expect(call.fn, 'tutorVoidLearning');
      expect(call.args['targetId'], engineUlid(1));
      final copy = Map<String, Object?>.from(
        (call.args['replacement'] as Map)['fields'] as Map,
      );
      expect(copy['source'], _rebbeId);
      expect(copy['learned_on'], '2026-09-30');
      expect(copy['ref'], 'Mishnah Peah 1:1');
      expect(copy['date_state'], 'dated');
      expect(copy.containsKey('stage'), isFalse);
      expect(result, isA<CaptureSuccess>());
    });

    test(
      'the server refusing the sub-track (ended since the sheet opened) '
      'rejects the correction and sends no separate void or capture',
      () async {
        final h = _harness(events: [mainLearn()]);
        h.invoker.respond = (_) => throw FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Sub-track source has ended',
        );

        final result = await h.commands.replace(
          engineUlid(1),
          const EventReplacement(source: _rebbeId),
        );

        expect(result, isA<CaptureRejected>());
        expect([for (final c in h.invoker.calls) c.fn], ['tutorVoidLearning']);
      },
    );

    test('a retryable failure answers notSaved and parks the whole replace; '
        'the retry re-sends the identical call, never a lone void', () async {
      final h = _harness(events: [mainLearn()]);
      h.invoker.respond = (_) => throw FirebaseFunctionsException(
        code: 'deadline-exceeded',
        message: 'timeout',
      );

      expect(
        await h.commands.replace(
          engineUlid(1),
          const EventReplacement(source: _rebbeId),
        ),
        const CaptureResult.rejected(CaptureRejection.notSaved),
      );
      final pending = (await h.commands.watchPendingFailures().first).single;
      final first = h.invoker.calls.single;
      h.invoker.respond = null;

      expect(await h.commands.retry(pending.id), isA<CaptureSuccess>());
      expect(
        [for (final c in h.invoker.calls) c.fn],
        ['tutorVoidLearning', 'tutorVoidLearning'],
      );
      expect(h.invoker.calls.last.args, first.args);
    });

    test('a sub-track event is not corrected from a tutor device (Story 4.1 '
        'keeps tutor corrections to main-track events)', () async {
      final h = _harness(events: [mainLearn(source: _rebbeId)]);
      expect(
        await h.commands.replace(
          engineUlid(1),
          const EventReplacement(source: LearningEvent.sourceMain),
        ),
        const CaptureResult.rejected(CaptureRejection.invalid),
      );
      expect(h.invoker.calls, isEmpty);
    });
  });
}
