/// DNI-514 T5: the Change history Undo affordance runs the row's undo
/// through `LearningCommands` and shows its outcome (AC-1, AC-3, AC-8,
/// AC-9).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/features/change_history/domain/undo/history_undo_status.dart';
import 'package:learning_tracker/features/change_history/presentation/undo/change_history_undo_button.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/undo_result.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/capture_feedback.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state/learner_state_overrides.dart';
import '../../../../helpers/learner_state_fixtures.dart';
import '../../../../helpers/pump_app.dart';

const _rav = Actor(uid: 'rav', role: ActorRole.tutor, displayName: 'Rav Cohen');
const _deadline = ChangedFieldKey('goals', 'g', 'target_date');

void main() {
  late FakeLearningCommands commands;

  setUp(() => commands = FakeLearningCommands());
  tearDown(() => commands.dispose());

  Widget host(
    HistoryUndoStatus status, {
    ChangeHistoryUndoTarget target = const GovernedUndoTarget(ulidA),
    bool needsOnline = false,
    bool isOnline = true,
    void Function(UndoResult?)? onResult,
  }) => pumpApp(
    overrides: learnerStateOverrides(scope: c0Scope(), commands: commands),
    child: Scaffold(
      body: PendingCaptureFailureListener(
        child: Center(
          child: ChangeHistoryUndoButton(
            status: status,
            target: target,
            needsOnline: needsOnline,
            isOnline: isOnline,
            onResult: onResult,
          ),
        ),
      ),
    ),
  );

  testWidgets('AC-1: Undo runs the governed undo once and says it is done', (
    tester,
  ) async {
    UndoResult? outcome;
    await tester.pumpWidget(
      host(HistoryUndoStatus.offered, onResult: (r) => outcome = r),
    );
    await tester.pumpAndSettle();
    final undo = find.widgetWithText(TextButton, 'Undo');
    expect(tester.getSize(undo).height, greaterThanOrEqualTo(48));

    await tester.tap(undo);
    await tester.pumpAndSettle();

    expect(commands.calls.where((c) => c.name == 'undoAction').single.args, {
      'actionId': ulidA,
    });
    expect(outcome, isA<UndoApplied>());
    expect(find.text('Change undone'), findsOneWidget);
  });

  testWidgets('a capture row undoes its events', (tester) async {
    await tester.pumpWidget(
      host(
        HistoryUndoStatus.offered,
        target: const CaptureUndoTarget([ulidB, ulidC]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(commands.calls.where((c) => c.name == 'undoEvents').single.args, {
      'eventIds': [ulidB, ulidC],
    });
  });

  testWidgets('AC-3: nothing eligible says "Nothing to undo — changed '
      'since" and names who changed what', (tester) async {
    commands.nextResult = const CaptureResult.success(
      changedSince: [ChangedSinceField(_deadline, _rav)],
    );
    await tester.pumpWidget(host(HistoryUndoStatus.offered));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing to undo — changed since'), findsOneWidget);
    expect(find.text('Deadline — changed since by Rav Cohen'), findsOneWidget);
  });

  testWidgets('AC-3: a partial undo lists the fields left alone', (
    tester,
  ) async {
    commands.nextResult = const CaptureResult.success(
      changeIds: [ulidB],
      actionId: ulidB,
      changedSince: [ChangedSinceField(_deadline, _rav)],
    );
    await tester.pumpWidget(host(HistoryUndoStatus.offered));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(
      find.text('Undone, except: Deadline — changed since by Rav Cohen'),
      findsOneWidget,
    );
  });

  testWidgets('AC-8: an online-only undo is disabled offline with "Online '
      'required"', (tester) async {
    await tester.pumpWidget(
      host(HistoryUndoStatus.offered, needsOnline: true, isOnline: false),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Undo'),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Online required'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(commands.calls.where((c) => c.name == 'undoAction'), isEmpty);
  });

  testWidgets('AC-8: online it runs; a callable that finds the device '
      'offline says "Online required"', (tester) async {
    commands.nextResult = const CaptureResult.onlineRequired();
    await tester.pumpWidget(host(HistoryUndoStatus.offered, needsOnline: true));
    await tester.pumpAndSettle();
    expect(find.text('Online required'), findsNothing);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Online required'), findsOneWidget);
  });

  testWidgets('AC-9: a queued undo shows as applied; a later permanent '
      'rejection says the undo could not be saved, with Retry', (tester) async {
    commands.nextResult = const CaptureResult.success(
      changeIds: [ulidB],
      actionId: ulidB,
      queued: true,
    );
    await tester.pumpWidget(host(HistoryUndoStatus.offered));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Change undone'), findsOneWidget);

    commands.pendingFailures.add([
      const PendingFailure(
        id: ulidB,
        eventIds: [],
        changeIds: [ulidB],
        reason: PendingFailureReason.permissionDenied,
        isUndo: true,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text("The undo couldn't be saved"), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(commands.calls.where((c) => c.name == 'retry').single.args, {
      'pendingFailureId': ulidB,
    });
  });

  testWidgets('Undone shows a tag and no Undo; a revert, a seed and a '
      'lock-ignored row show nothing', (tester) async {
    await tester.pumpWidget(host(HistoryUndoStatus.undone));
    await tester.pumpAndSettle();
    expect(find.text('Undone'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);

    for (final status in [
      HistoryUndoStatus.revert,
      HistoryUndoStatus.notOffered,
    ]) {
      await tester.pumpWidget(host(status));
      await tester.pumpAndSettle();
      expect(find.text('Undo'), findsNothing);
      expect(find.text('Undone'), findsNothing);
    }
  });
}
