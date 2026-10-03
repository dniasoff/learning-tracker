// Story 1.24 (DNI-486) AC-7 — a tutorRecordLearning call that started just
// before the learner's lock may return a server-stamped recorded_at inside
// it. The client re-runs CaptureGate on that stamp (AD-36), reports the
// event as "Kept, not counted — Shabbos / Yom Tov had started", offers no
// Undo for it and changes no position or count for it. Unrelated events of
// the same action that were stamped outside the lock still count.

@Tags(['tutor_mode'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/capture_feedback.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_learning_commands.dart';

import '../../helpers/learner_state/c0_fixtures.dart';
import '../../helpers/learner_state/learner_state_overrides.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/tutoring/tutor_learning_harness.dart';

/// The learner's lock: from 09:00:00.500 (just after the preflight at
/// 09:00) — the call starts before it and is stamped inside it.
final _lock = LockWindow(
  DateTime.utc(2026, 10, 1, 9, 0, 0, 500),
  DateTime.utc(2026, 10, 2, 20),
);

/// A gate that is locked exactly inside [_lock].
final class _WindowGate implements CaptureGate {
  @override
  GateDecision check(LearnerSettingsHistory settingsHistory, DateTime nowUtc) =>
      _lock.contains(nowUtc) ? GateLocked(_lock) : const GateOpen();
}

void main() {
  group('server stamp re-check', () {
    test('a call stamped inside the lock succeeds but its events are kept, '
        'not counted', () async {
      final h = TutorHarness(gate: _WindowGate());
      addTearDown(h.dispose);
      h.invoker.recordedAt = DateTime.utc(2026, 10, 1, 9, 0, 1);

      final result = await h.commands.capture(
        curriculumId: 'mishnayos',
        refs: const ['Mishnah Berakhot 2:1', 'Mishnah Berakhot 2:2'],
        source: LearningEvent.sourceMain,
        dateState: DateState.dated,
      );

      expect(h.invoker.calls, hasLength(1), reason: 'the preflight passed');
      final success = result as CaptureSuccess;
      expect(success.eventIds, hasLength(2));
      expect(success.keptNotCounted, success.eventIds);
      expect(success.countedEventIds, isEmpty);
      // The write is accepted by the server: it is not a preflight refusal
      // and nothing is rolled back or parked for retry.
      expect(result, isNot(isA<CaptureLocked>()));
      expect(await h.commands.watchPendingFailures().first, isEmpty);
    });

    test('a stamp outside the lock counts', () async {
      final h = TutorHarness(gate: _WindowGate());
      addTearDown(h.dispose);
      h.invoker.recordedAt = DateTime.utc(2026, 10, 1, 9);

      final result =
          await h.commands.capture(
                curriculumId: 'mishnayos',
                refs: const ['Mishnah Berakhot 2:1'],
                source: LearningEvent.sourceMain,
                dateState: DateState.dated,
              )
              as CaptureSuccess;

      expect(result.keptNotCounted, isEmpty);
      expect(result.countedEventIds, result.eventIds);
    });

    test('per returned stamp: one locked chunk does not erase the counted '
        'chunk of the same action', () async {
      final h = TutorHarness(gate: _WindowGate());
      addTearDown(h.dispose);
      var call = 0;
      h.invoker.respond = (c) {
        call++;
        // The first chunk lands before the lock, the second inside it.
        h.invoker.recordedAt = call == 1
            ? DateTime.utc(2026, 10, 1, 9)
            : DateTime.utc(2026, 10, 1, 9, 0, 2);
        return h.invoker.successFor(c);
      };
      final refs = [
        for (var i = 0; i < tutorCaptureChunkSize + 1; i++) 'Ref $i',
      ];

      final result =
          await h.commands.capture(
                curriculumId: 'mishnayos',
                refs: refs,
                source: LearningEvent.sourceMain,
                dateState: DateState.dated,
              )
              as CaptureSuccess;

      expect(h.invoker.calls, hasLength(2));
      expect(result.eventIds, hasLength(refs.length));
      expect(result.keptNotCounted, [result.eventIds.last]);
      expect(result.countedEventIds, hasLength(tutorCaptureChunkSize));
    });
  });

  group('feedback', () {
    testWidgets('shows the exact kept-not-counted copy with no Undo', (
      tester,
    ) async {
      final h = TutorHarness();
      addTearDown(h.dispose);
      List<String>? shown;
      await tester.pumpWidget(
        pumpApp(
          overrides: learnerStateOverrides(scope: c0Scope()),
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => shown = showCaptureOutcome(
                  context,
                  result: const CaptureResult.success(
                    eventIds: ['01ARZ3NDEKTSV4RRFFQ69G0001'],
                    keptNotCounted: ['01ARZ3NDEKTSV4RRFFQ69G0001'],
                  ),
                  commands: h.commands,
                  message: 'Marked complete',
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(
        find.text('Kept, not counted — Shabbos / Yom Tov had started'),
        findsOneWidget,
      );
      expect(find.text('Marked complete'), findsNothing);
      expect(find.text('Undo'), findsNothing);
      expect(shown, isEmpty, reason: 'nothing counted, nothing to undo');
    });
  });
}
