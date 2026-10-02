// Story 1.24 (DNI-486) AC-1 — every tutor learning command routes through
// ONE typed TutorWriteService method (the Story 1.23 callables), and the
// preflight blocks a write before any callable when the grant, the
// connection or the target learner's lock does not allow it.

@Tags(['tutor_mode'])
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_learning_commands.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/tutoring/tutor_learning_harness.dart';

const _curriculum = engineCurriculum;

void main() {
  group('capture → tutorRecordLearning', () {
    test('a dated leaf capture is one call carrying the learner-local date '
        'and the client ULIDs it returns', () async {
      final h = TutorHarness();
      addTearDown(h.dispose);

      final result = await h.commands.capture(
        curriculumId: _curriculum,
        refs: const ['Mishnah Berakhot 2:1', 'Mishnah Berakhot 2:2'],
        source: LearningEvent.sourceMain,
        dateState: DateState.dated,
        stage: 1,
      );

      final call = h.invoker.calls.single;
      expect(call.fn, 'tutorRecordLearning');
      final ids = [
        for (final e in call.args['events'] as List) (e as Map)['id'],
      ];
      expect(result, CaptureResult.success(eventIds: ids.cast<String>()));
      expect(call.args['actionId'], ids.first);
      final fields = ((call.args['events'] as List).first as Map)['fields'];
      expect((fields as Map)['learned_on'], '2026-10-01');
    });

    test(
      'a before-tracking node capture sends the node ref and level',
      () async {
        final h = TutorHarness();
        addTearDown(h.dispose);

        await h.commands.capture(
          curriculumId: _curriculum,
          nodes: const [berakhot],
          source: LearningEvent.sourceMain,
          dateState: DateState.beforeTracking,
        );

        final fields =
            ((h.invoker.calls.single.args['events'] as List).single
                    as Map)['fields']
                as Map;
        expect(fields['ref'], berakhot.ref);
        expect(fields['level'], berakhot.level);
        expect(fields['date_state'], 'before_tracking');
        expect(fields['learned_on'], isNull);
      },
    );

    test('a sub-track source or a catch-up capture is refused before any '
        'call (Epic 1 tutor scope)', () async {
      final h = TutorHarness();
      addTearDown(h.dispose);

      expect(
        await h.commands.capture(
          curriculumId: _curriculum,
          refs: const ['Mishnah Berakhot 2:1'],
          source: engineUlid(9),
          dateState: DateState.dated,
        ),
        isA<CaptureRejected>(),
      );
      expect(
        await h.commands.capture(
          curriculumId: _curriculum,
          refs: const ['Mishnah Berakhot 2:1'],
          source: LearningEvent.sourceMain,
          dateState: DateState.catchUp,
        ),
        isA<CaptureRejected>(),
      );
      expect(h.invoker.calls, isEmpty);
    });
  });

  group('corrections → tutorVoidLearning', () {
    test('voidEvent voids the learn target', () async {
      final h = TutorHarness(
        events: [engineLearn(1, 'Mishnah Berakhot 2:1', minutes: 5)],
      );
      addTearDown(h.dispose);

      final result = await h.commands.voidEvent(engineUlid(1));

      final call = h.invoker.calls.single;
      expect(call.fn, 'tutorVoidLearning');
      expect(call.args['targetId'], engineUlid(1));
      expect(call.args.containsKey('replacement'), isFalse);
      expect(
        result,
        CaptureResult.success(eventIds: [call.args['eventId'] as String]),
      );
    });

    test('replace sends ONE void-plus-learn call with the corrected place, '
        'keeping the main source and stage', () async {
      final h = TutorHarness(
        events: [engineLearn(1, 'Mishnah Berakhot 2:1', minutes: 5, stage: 1)],
      );
      addTearDown(h.dispose);

      await h.commands.replace(
        engineUlid(1),
        const EventReplacement(ref: 'Mishnah Berakhot 2:2'),
      );

      final call = h.invoker.calls.single;
      expect(call.fn, 'tutorVoidLearning');
      expect(call.args['targetId'], engineUlid(1));
      final fields = (call.args['replacement'] as Map)['fields'] as Map;
      expect(fields['ref'], 'Mishnah Berakhot 2:2');
      expect(fields['source'], 'main');
      expect(fields['stage'], 1);
      expect(fields['learned_on'], '2026-09-01');
    });

    test('voiding a void is refused before any call (AD-31)', () async {
      final h = TutorHarness(
        events: [
          engineLearn(1, 'Mishnah Berakhot 2:1', minutes: 5),
          engineVoid(2, 1, minutes: 6),
        ],
      );
      addTearDown(h.dispose);

      expect(
        await h.commands.voidEvent(engineUlid(2)),
        const CaptureResult.rejected(CaptureRejection.voidTargetNotLearn),
      );
      expect(h.invoker.calls, isEmpty);
    });

    test('Undo of a tutor capture voids each of its events', () async {
      final h = TutorHarness();
      addTearDown(h.dispose);
      final captured =
          await h.commands.capture(
                curriculumId: _curriculum,
                refs: const ['Mishnah Berakhot 2:1', 'Mishnah Berakhot 2:2'],
                source: LearningEvent.sourceMain,
                dateState: DateState.dated,
              )
              as CaptureSuccess;
      h.invoker.calls.clear();

      await h.commands.undoEvents(captured.eventIds);

      expect(h.invoker.calls.map((c) => c.fn), [
        'tutorVoidLearning',
        'tutorVoidLearning',
      ]);
      expect(h.invoker.calls.map((c) => c.args['targetId']), captured.eventIds);
    });
  });

  group('reset / unmark → tutorUnlearn (ruling B9 client plan)', () {
    test('un-learning a leaf under a before-tracking perek voids it and '
        're-issues the rest of the perek', () async {
      final h = TutorHarness(
        events: [engineGround(1, berakhot2, minutes: 5)],
        corpora: {_curriculum: mishnayosCorpus()},
      );
      addTearDown(h.dispose);

      await h.commands.unlearn(_curriculum, {'Mishnah Berakhot 2:1'});

      final call = h.invoker.calls.single;
      expect(call.fn, 'tutorUnlearn');
      expect(call.args['curriculumId'], _curriculum);
      expect(call.args['leafSet'], ['Mishnah Berakhot 2:1']);
      final plan = (call.args['nodeReissues'] as List).single as Map;
      expect(plan['targetEventId'], engineUlid(1));
      expect(
        [for (final r in plan['reissues'] as List) (r as Map)['ref']],
        ['Mishnah Berakhot 2:2'],
      );
      expect(call.args['leafEventIds'], isEmpty);
    });

    test('AC-7: a lock-window learn that is stored but not counted is never '
        'voided — only the counted event ids are sent', () async {
      const leaf = 'Mishnah Berakhot 2:1';
      final h = TutorHarness(
        events: [
          engineLearn(1, leaf),
          // Recorded inside the talmid's Shabbos lock: stored, not counted.
          engineLearn(2, leaf, minutes: 6000),
        ],
        corpora: {_curriculum: mishnayosCorpus()},
      );
      addTearDown(h.dispose);

      final result = await h.commands.unlearn(_curriculum, {leaf});

      expect(result, isA<CaptureSuccess>());
      final call = h.invoker.calls.single;
      expect(call.fn, 'tutorUnlearn');
      expect(call.args['leafSet'], [leaf]);
      expect(call.args['leafEventIds'], [engineUlid(1)]);
      expect(call.args['leafEventIds'], isNot(contains(engineUlid(2))));
    });

    test('an unlearn the server answers without a validated success is '
        'not shown as done: notSaved, parked for an identical retry', () async {
      final h = TutorHarness(
        events: [engineLearn(1, 'Mishnah Berakhot 2:1')],
        corpora: {_curriculum: mishnayosCorpus()},
      );
      addTearDown(h.dispose);
      h.invoker.respond = (call) => {'success': false};

      final result = await h.commands.unlearn(_curriculum, {
        'Mishnah Berakhot 2:1',
      });

      expect(result, const CaptureResult.rejected(CaptureRejection.notSaved));
      final pending = (await h.commands.watchPendingFailures().first).single;
      final first = h.invoker.calls.single;
      h.invoker.respond = null;
      expect(await h.commands.retry(pending.id), isA<CaptureSuccess>());
      expect(h.invoker.calls.last.args, first.args);
    });
  });

  group('a chunked capture is all or nothing (AC-5)', () {
    // One more ref than a chunk holds: two tutorRecordLearning calls.
    final refs = [
      for (var i = 0; i <= tutorCaptureChunkSize; i++) 'Mishnah Berakhot 1:$i',
    ];
    Future<CaptureResult> capture(TutorHarness h) => h.commands.capture(
      curriculumId: _curriculum,
      refs: refs,
      source: LearningEvent.sourceMain,
      dateState: DateState.dated,
    );
    List<String> idsOf(TutorCall call) =>
        RecordingTutorInvoker.eventIdsOf(call);

    test('a later chunk that times out reports notSaved, not success, and '
        'the retry re-sends EVERY chunk with the same ULIDs', () async {
      final h = TutorHarness();
      addTearDown(h.dispose);
      h.invoker.respond = (call) => h.invoker.calls.length == 2
          ? throw FirebaseFunctionsException(
              code: 'deadline-exceeded',
              message: 'timeout',
            )
          : h.invoker.successFor(call);

      final result = await capture(h);

      expect(result, const CaptureResult.rejected(CaptureRejection.notSaved));
      final sent = [for (final c in h.invoker.calls) ...idsOf(c)];
      expect(sent, hasLength(refs.length));
      final failure = (await h.commands.watchPendingFailures().first).single;
      // The pending action is the whole capture, written prefix included.
      expect(failure.eventIds, sent);

      h.invoker.respond = null;
      final retried = await h.commands.retry(failure.id);

      final resent = h.invoker.calls.skip(2).toList();
      expect(
        [for (final c in resent) c.args['actionId']],
        [for (final c in h.invoker.calls.take(2)) c.args['actionId']],
      );
      expect([for (final c in resent) ...idsOf(c)], sent);
      expect(retried, CaptureResult.success(eventIds: sent));
      expect(await h.commands.watchPendingFailures().first, isEmpty);
    });

    test('a later chunk the server refuses reports the refusal and keeps '
        'the partly written action pending', () async {
      final h = TutorHarness();
      addTearDown(h.dispose);
      h.invoker.respond = (call) => h.invoker.calls.length == 2
          ? throw FirebaseFunctionsException(
              code: 'failed-precondition',
              message: 'refused',
            )
          : h.invoker.successFor(call);

      final result = await capture(h);

      expect(result, isA<CaptureRejected>());
      expect(result, isNot(isA<CaptureSuccess>()));
      final failure = (await h.commands.watchPendingFailures().first).single;
      expect(failure.reason, PendingFailureReason.failedPrecondition);
      expect(failure.eventIds, [for (final c in h.invoker.calls) ...idsOf(c)]);
    });

    test('a single call the server refuses is not kept pending', () async {
      final h = TutorHarness();
      addTearDown(h.dispose);
      h.invoker.respond = (_) => throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'refused',
      );

      final result = await h.commands.capture(
        curriculumId: _curriculum,
        refs: const ['Mishnah Berakhot 2:1'],
        source: LearningEvent.sourceMain,
        dateState: DateState.dated,
      );

      expect(result, isA<CaptureRejected>());
      expect(await h.commands.watchPendingFailures().first, isEmpty);
    });
  });

  group('DNI-487 AC-6: the parent turned editing off mid-session', () {
    FirebaseFunctionsException turnedOff() => FirebaseFunctionsException(
      code: 'permission-denied',
      message: 'Grant lacks can_edit_learning',
    );

    test('a capture the callable refuses for the grant is reported as '
        'editing turned off, and nothing stays pending', () async {
      final h = TutorHarness();
      addTearDown(h.dispose);
      h.invoker.respond = (_) => throw turnedOff();

      final result = await h.commands.capture(
        curriculumId: _curriculum,
        refs: const ['Mishnah Berakhot 2:1'],
        source: LearningEvent.sourceMain,
        dateState: DateState.dated,
      );

      expect(
        result,
        const CaptureResult.rejected(CaptureRejection.editingTurnedOff),
      );
      expect(h.invoker.calls, hasLength(1));
      expect(await h.commands.watchPendingFailures().first, isEmpty);
    });

    test('a correction the callable refuses for the grant is reported as '
        'editing turned off', () async {
      final h = TutorHarness(
        events: [engineLearn(1, 'Mishnah Berakhot 2:1', minutes: 5)],
      );
      addTearDown(h.dispose);
      h.invoker.respond = (_) => throw turnedOff();

      expect(
        await h.commands.voidEvent(engineUlid(1)),
        const CaptureResult.rejected(CaptureRejection.editingTurnedOff),
      );
    });

    test('any other permission-denied stays a plain rejection', () async {
      final h = TutorHarness();
      addTearDown(h.dispose);
      h.invoker.respond = (_) => throw FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'Grant is not active',
      );

      final result = await h.commands.capture(
        curriculumId: _curriculum,
        refs: const ['Mishnah Berakhot 2:1'],
        source: LearningEvent.sourceMain,
        dateState: DateState.dated,
      );

      expect(result, isA<CaptureRejected>());
      expect(
        result,
        isNot(const CaptureResult.rejected(CaptureRejection.editingTurnedOff)),
      );
    });
  });

  group('AC-4/AC-5/AC-6 preflight: nothing is invoked', () {
    Future<CaptureResult> capture(TutorHarness h) => h.commands.capture(
      curriculumId: _curriculum,
      refs: const ['Mishnah Berakhot 2:1'],
      source: LearningEvent.sourceMain,
      dateState: DateState.dated,
    );

    test('without can_edit_learning', () async {
      final h = TutorHarness(canEditLearning: false);
      addTearDown(h.dispose);
      // The control was enabled when tapped, so the parent turned editing
      // off since (DNI-487 AC-6): the surface names that, not a bad input.
      expect(
        await capture(h),
        const CaptureResult.rejected(CaptureRejection.editingTurnedOff),
      );
      expect(h.invoker.calls, isEmpty);
    });

    test('offline (no positive probe)', () async {
      final h = TutorHarness(online: false);
      addTearDown(h.dispose);
      expect(await capture(h), const CaptureResult.onlineRequired());
      expect(h.invoker.calls, isEmpty);
    });

    test('inside the TARGET learner\'s lock', () async {
      final window = LockWindow(
        DateTime.utc(2026, 10, 1, 8),
        DateTime.utc(2026, 10, 1, 20),
      );
      final h = TutorHarness(gate: FakeCaptureGate.locked(window));
      addTearDown(h.dispose);
      expect(await capture(h), CaptureResult.locked(window));
      expect(h.invoker.calls, isEmpty);
      // The gate judged the talmid's settings history, never the device's.
      expect((h.gate as FakeCaptureGate).checks.single.$1, same(h.history));
    });
  });
}
