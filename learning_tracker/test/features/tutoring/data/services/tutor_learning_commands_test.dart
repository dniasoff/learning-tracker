// Story 1.24 (DNI-486) AC-1 — every tutor learning command routes through
// ONE typed TutorWriteService method (the Story 1.23 callables), and the
// preflight blocks a write before any callable when the grant, the
// connection or the target learner's lock does not allow it.

@Tags(['tutor_mode'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';

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
      expect(await capture(h), isA<CaptureRejected>());
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
