// Story 1.24 (DNI-486) AC-3 + edge AC-3 — a tutor corrects or removes a
// wrongly ticked mishna from Mishna history. Remove and every correction
// (place, source, date) run through tutorVoidLearning; the row changes only
// after the callable succeeds (no optimistic overlay for a tutor); a
// rejected or malformed correction leaves the row and list unchanged and
// shows the rollback snackbar (UX-DR-142), with no capture analytics.

@Tags(['tutor_mode'])
library;

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/models/mishna_history_item.dart';
import 'package:learning_tracker/features/learning/presentation/screens/mishna_history_screen.dart';

import '../../helpers/learner_state/mishna_history_fixtures.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/tutoring/tutor_learning_harness.dart';

const _rolledBack = "Couldn't save that change — the entry is back as it was.";

Finder _row(int n) => find.byKey(ValueKey('mishnaHistoryRow-${eid(n)}'));

Finder _action(String name) => find.byKey(Key('mishnaHistoryAction-$name'));

void main() {
  late HistoryPorts ports;
  late TutorHarness h;

  setUp(() {
    ports = HistoryPorts();
    final events = [historyLearn(1, day: 1), historyLearn(2, day: 3)];
    ports.events.seed(ports.scope, events);
    h = TutorHarness(events: events);
  });
  tearDown(() async {
    h.dispose();
    await ports.dispose();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      pumpApp(
        child: const MishnaHistoryScreen(
          curriculumId: historyCurriculum,
          leafRef: historyLeaf,
        ),
        overrides: [
          ...historyOverrides(
            ports,
            state: historyState(counted: {eid(1), eid(2)}),
            commands: h.commands,
            viewer: MishnaHistoryViewer.tutor,
            withLock: false,
          ),
          ...tutoredOverrides(selection: h.selection, withScope: false),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Remove calls tutorVoidLearning; the row changes only after '
      'success', (tester) async {
    final pending = Completer<void>();
    h.invoker.respond = (call) async {
      await pending.future;
      return h.invoker.successFor(call);
    };
    await pump(tester);
    expect(find.text('Learning events: 2'), findsOneWidget);

    await tester.tap(_row(2));
    await tester.pumpAndSettle();
    await tester.tap(_action('remove'));
    await tester.pump();
    await tester.pump();

    final call = h.invoker.calls.single;
    expect(call.fn, 'tutorVoidLearning');
    expect(call.args['targetId'], eid(2));
    expect(call.args.containsKey('replacement'), isFalse);
    // In flight: nothing optimistic on the row.
    expect(
      find.descendant(of: _row(2), matching: find.text('Saving…')),
      findsNothing,
    );
    expect(
      find.descendant(of: _row(2), matching: find.text('Removed')),
      findsNothing,
    );

    pending.complete();
    await tester.pump();
    await tester.pump();

    expect(
      find.descendant(of: _row(2), matching: find.text('Removed')),
      findsOneWidget,
      reason: 'applied after success, pending until the history reads it',
    );
    expect(find.text(_rolledBack), findsNothing);
  });

  testWidgets('a source correction is ONE tutorVoidLearning call carrying '
      'the corrected learn event', (tester) async {
    await pump(tester);

    await tester.tap(_row(2));
    await tester.pumpAndSettle();
    await tester.tap(_action('changeSource'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mishnaHistorySource-before')));
    await tester.pumpAndSettle();

    final call = h.invoker.calls.single;
    expect(call.fn, 'tutorVoidLearning');
    expect(call.args['targetId'], eid(2));
    final fields = (call.args['replacement'] as Map)['fields'] as Map;
    expect(fields['date_state'], 'before_tracking');
    expect(fields['learned_on'], isNull);
    expect(fields['source'], 'main');
  });

  for (final (code, message) in [
    ('permission-denied', 'Grant lacks can_edit_learning'),
    ('invalid-argument', 'A void must target a learn event'),
  ]) {
    testWidgets('a rejected correction ($code) leaves the row and list '
        'unchanged and shows the rollback snackbar', (tester) async {
      h.invoker.respond = (_) =>
          throw FirebaseFunctionsException(code: code, message: message);
      await pump(tester);

      await tester.tap(_row(2));
      await tester.pumpAndSettle();
      await tester.tap(_action('remove'));
      await tester.pumpAndSettle();

      expect(h.invoker.calls, hasLength(1));
      expect(find.text(_rolledBack), findsOneWidget);
      expect(
        find.descendant(of: _row(2), matching: find.text('Removed')),
        findsNothing,
      );
      expect(find.text('Learning events: 2'), findsOneWidget);
      expect(h.analytics.captures, isEmpty);
    });
  }

  group('place and date corrections (commands level)', () {
    test(
      'a place correction replaces the ref through tutorVoidLearning',
      () async {
        await h.commands.replace(
          eid(2),
          const EventReplacement(ref: historySibling),
        );
        final call = h.invoker.calls.single;
        expect(call.fn, 'tutorVoidLearning');
        expect(
          ((call.args['replacement'] as Map)['fields'] as Map)['ref'],
          historySibling,
        );
      },
    );

    test(
      'a date correction replaces learned_on through tutorVoidLearning',
      () async {
        final result = await h.commands.replace(
          eid(2),
          const EventReplacement(learnedOn: '2026-09-02'),
        );
        expect(result, isA<CaptureSuccess>());
        final call = h.invoker.calls.single;
        expect(call.fn, 'tutorVoidLearning');
        expect(
          ((call.args['replacement'] as Map)['fields'] as Map)['learned_on'],
          '2026-09-02',
        );
      },
    );

    test('voiding a void is refused before any call', () async {
      h.eventLog.add(historyVoid(3, eid(1)));
      expect(
        await h.commands.voidEvent(eid(3)),
        const CaptureResult.rejected(CaptureRejection.voidTargetNotLearn),
      );
      expect(h.invoker.calls, isEmpty);
      expect(h.analytics.captures, isEmpty);
    });
  });
}
