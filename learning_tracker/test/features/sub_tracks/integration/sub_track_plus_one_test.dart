// Story 2.9 (DNI-500) AC-2, AC-5 — +1 records one sub-track learn event
// through LearningCommands, the row derives its next position from the
// engine in the same frame, Undo voids, the gate's refusal writes nothing,
// and a capture the engine later finds lock-stamped is kept, not counted.
//
// The engine and commands are test stand-ins (sub_track_test_engine.dart):
// DNI-465/469/474 fill the real ones behind the same providers (C0).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_session.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/also_learning_section.dart';

import '../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/sub_tracks/sub_track_home_fixtures.dart';
import '../../../helpers/sub_tracks/sub_track_test_engine.dart';

Finder _plusOne(String id) => find.byKey(Key('subTrackHomePlusOne-$id'));
Finder _line(String id) => find.byKey(Key('subTrackHomeRowLine-$id'));

String _lineText(WidgetTester tester, String id) =>
    tester.widget<Text>(_line(id)).data!;

List<LearningCommandCall> _captures(EngineBackedCommands c) =>
    c.inner.calls.where((call) => call.name == 'capture').toList();

Future<(SubTrackTestEngine, EngineBackedCommands)> _pump(
  WidgetTester tester, {
  SubTrackViewerRole role = SubTrackViewerRole.child,
}) async {
  final engine = SubTrackTestEngine();
  addTearDown(engine.dispose);
  final commands = EngineBackedCommands(engine);
  await tester.pumpWidget(
    pumpApp(
      overrides: subTrackEngineOverrides(
        engine: engine,
        commands: commands,
        role: role,
      ),
      child: const Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: AlsoLearningSection(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (engine, commands);
}

void main() {
  testWidgets('AC-2: one tap records one dated learn event for School at its '
      'position, with no stage and no source prompt; the row advances, other '
      'tracks do not move, and Undo voids it', (tester) async {
    final (engine, commands) = await _pump(tester);
    expect(_lineText(tester, schoolId), 'Next: Berachos 1:4');
    expect(_lineText(tester, rebbeId), 'Next: Peah 2:1');

    await tester.tap(_plusOne(schoolId)); // NFR-15: one tap per leaf.
    await tester.pump();

    final captures = _captures(commands);
    expect(captures, hasLength(1));
    expect(
      captures.single,
      const LearningCommandCall('capture', {
        'curriculumId': mishnayos,
        'refs': [berachos14],
        'nodes': <Object>[],
        'source': schoolId,
        'dateState': DateState.dated,
        // learned_on defaults to the learner's civil today in the command
        // (DNI-469 AC-2); no stage, so no points entry (AD-50).
        'learnedOn': null,
        'stage': null,
      }),
    );
    expect(find.byType(Dialog), findsNothing); // no source prompt
    expect(find.byType(BottomSheet), findsNothing);

    // Same frame as the engine's emission: the next leaf (its display label
    // resolves a microtask later), count and fill.
    expect(_lineText(tester, schoolId), matches(RegExp(r'^Next: .*1[.:]5$')));
    await tester.pump();
    expect(_lineText(tester, schoolId), 'Next: Berachos 1:5');
    expect(
      engine.state[mishnayos]!.subTracks[schoolId]!.ticked,
      4,
      reason: 'distinct ticked count comes from the engine',
    );
    expect(_lineText(tester, rebbeId), 'Next: Peah 2:1'); // FR-13

    await tester.pump(const Duration(milliseconds: 750));
    expect(find.text('Recorded 1'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    final undo = commands.inner.calls.last;
    expect(undo.name, 'undoEvents');
    final eventId = (undo.args['eventIds']! as List).single;
    expect(engine.state.countedEventIds, isNot(contains(eventId)));
    expect(_lineText(tester, schoolId), 'Next: Berachos 1:4');
    // Only capture + undo: the rows write nothing else (no streak, no pts_).
    expect(commands.inner.calls.map((c) => c.name), ['capture', 'undoEvents']);
  });

  testWidgets('rapid repeated taps while the first +1 is in flight record '
      'once', (tester) async {
    final (_, commands) = await _pump(tester);
    commands.gate = Completer<void>();
    await tester.tap(_plusOne(schoolId));
    await tester.tap(_plusOne(schoolId));
    await tester.pump();
    await tester.tap(_plusOne(schoolId));
    commands.gate!.complete();
    await tester.pumpAndSettle();
    expect(_captures(commands), hasLength(1));
    expect(_lineText(tester, schoolId), 'Next: Berachos 1:5');
  });

  testWidgets('a second +1 after the engine advanced records the next leaf', (
    tester,
  ) async {
    final (_, commands) = await _pump(tester);
    await tester.tap(_plusOne(schoolId));
    await tester.pumpAndSettle();
    await tester.tap(_plusOne(schoolId));
    await tester.pumpAndSettle();
    expect(_captures(commands).map((c) => (c.args['refs']! as List).single), [
      berachos14,
      'Mishnah_Berakhot_1.5',
    ]);
    expect(find.text('All ground recorded'), findsOneWidget);
  });

  testWidgets('AC-5: offline the capture is optimistic (queued) and the row '
      'updates at once', (tester) async {
    final (_, commands) = await _pump(tester);
    commands.inner.nextResult = const CaptureResult.success(
      eventIds: ['01FAKE0000000000000000QUED'],
      queued: true,
    );
    // The stand-in only applies successes carrying an event id it can map;
    // the scripted id still flows to the engine like a queued write.
    await tester.tap(_plusOne(schoolId));
    await tester.pumpAndSettle();
    expect(_lineText(tester, schoolId), 'Next: Berachos 1:5');
    expect(find.text('Recorded 1'), findsOneWidget);
  });

  testWidgets('AC-5 / AD-30: a queued +1 the server later refuses replaces '
      '"Recorded 1 · Undo" with "not saved", stays listed with Retry, and '
      'Retry re-sends it', (tester) async {
    final (_, commands) = await _pump(tester);
    addTearDown(commands.inner.dispose);
    const queuedId = '01FAKE0000000000000000QUED';
    commands.inner.nextResult = const CaptureResult.success(
      eventIds: [queuedId],
      queued: true,
    );
    await tester.tap(_plusOne(schoolId));
    await tester.pumpAndSettle();
    expect(find.text('Recorded 1'), findsOneWidget);

    commands.inner.pendingFailures.add(const [
      PendingFailure(
        id: 'f1',
        eventIds: [queuedId],
        changeIds: [],
        reason: PendingFailureReason.permissionDenied,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Recorded 1'), findsNothing);
    expect(find.text('Undo'), findsNothing);
    final entry = find.byKey(const Key('subTrackNotSaved-f1'));
    expect(entry, findsOneWidget);
    // The snackbar and the section's own entry.
    expect(find.text('Not saved: +1 for School'), findsNWidgets(2));

    await tester.tap(find.descendant(of: entry, matching: find.text('Retry')));
    await tester.pumpAndSettle();
    expect(
      commands.inner.calls.last,
      const LearningCommandCall('retry', {'pendingFailureId': 'f1'}),
    );
    expect(entry, findsNothing);
  });

  testWidgets('an Undo that does not go through says so, offers Retry, and '
      'the capture stands until it does', (tester) async {
    final (_, commands) = await _pump(tester);
    await tester.tap(_plusOne(schoolId));
    await tester.pumpAndSettle();
    expect(_lineText(tester, schoolId), 'Next: Berachos 1:5');

    commands.inner.nextResult = const CaptureResult.onlineRequired();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't undo"), findsOneWidget);
    expect(_lineText(tester, schoolId), 'Next: Berachos 1:5');

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(commands.inner.calls.map((c) => c.name), [
      'capture',
      'undoEvents',
      'undoEvents',
    ]);
    expect(_lineText(tester, schoolId), 'Next: Berachos 1:4');
    expect(find.text("Couldn't undo"), findsNothing);
  });

  testWidgets('AC-5: a write the CaptureGate refuses is not written and '
      'shows nothing (the lock overlay covers the app)', (tester) async {
    final (engine, commands) = await _pump(tester);
    commands.inner.nextResult = CaptureResult.locked(
      LockWindow(DateTime.utc(2026, 9, 4, 17), DateTime.utc(2026, 9, 5, 19)),
    );
    await tester.tap(_plusOne(schoolId));
    await tester.pumpAndSettle();
    expect(engine.state.countedEventIds, isEmpty);
    expect(_lineText(tester, schoolId), 'Next: Berachos 1:4');
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('AC-5: a capture later found lock-stamped is kept, not counted, '
      'and the learner is told once', (tester) async {
    final (engine, _) = await _pump(tester);
    engine.lockStampNext = true;
    await tester.tap(_plusOne(schoolId));
    await tester.pumpAndSettle();
    expect(engine.state.lockIgnoredEventIds, hasLength(1));
    expect(_lineText(tester, schoolId), 'Next: Berachos 1:4');
    expect(
      find.text('Kept, not counted — recorded during Shabbos'),
      findsOneWidget,
    );
    expect(find.text('Recorded 1'), findsNothing);
  });

  testWidgets('AC-5: the lock crosses before an offline capture syncs: after '
      'sync the row reflects the engine and the learner is told once', (
    tester,
  ) async {
    final (engine, _) = await _pump(tester);
    engine.holdPending = true;
    await tester.tap(_plusOne(schoolId));
    await tester.pumpAndSettle();
    expect(find.text('Recorded 1'), findsOneWidget);
    expect(_lineText(tester, schoolId), 'Next: Berachos 1:4');

    engine.syncPending(lockStamped: true);
    await tester.pumpAndSettle();
    expect(_lineText(tester, schoolId), 'Next: Berachos 1:4');
    expect(
      find.text('Kept, not counted — recorded during Shabbos'),
      findsOneWidget,
    );
    // Told once: a later emission does not repeat it.
    engine.syncPending();
    await tester.pump();
    expect(find.text('Recorded 1'), findsNothing);
  });

  testWidgets('a queued capture that syncs normally needs no further '
      'message', (tester) async {
    final (engine, _) = await _pump(tester);
    engine.holdPending = true;
    await tester.tap(_plusOne(schoolId));
    await tester.pumpAndSettle();
    engine.syncPending();
    await tester.pumpAndSettle();
    expect(_lineText(tester, schoolId), 'Next: Berachos 1:5');
    expect(
      find.text('Kept, not counted — recorded during Shabbos'),
      findsNothing,
    );
  });

  testWidgets('a refused capture shows the retry message and writes nothing', (
    tester,
  ) async {
    final (engine, commands) = await _pump(tester);
    commands.inner.nextResult = const CaptureResult.rejected(
      CaptureRejection.invalid,
    );
    await tester.tap(_plusOne(schoolId));
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't record that. Please try again."),
      findsOneWidget,
    );
    expect(engine.state.countedEventIds, isEmpty);
  });

  testWidgets('a tutor device never attempts a sub-track write (deviation '
      '#3: tutor capture stays disabled, online or offline)', (tester) async {
    final (_, commands) = await _pump(tester, role: SubTrackViewerRole.tutor);
    await tester.tap(_plusOne(schoolId), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(commands.inner.calls, isEmpty);
  });
}
