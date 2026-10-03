// Mirror test for
// `lib/features/learning/presentation/widgets/capture_feedback.dart`
// (Story 1.11, DNI-473): the Undo snackbar (AC-4, UX-DR-154) and the
// "not saved" + Retry feedback for a permanent rejection (AC-5,
// UX-DR-107/147).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/capture_feedback.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state/learner_state_overrides.dart';
import '../../../../helpers/pump_app.dart';

const _ids = ['01ARZ3NDEKTSV4RRFFQ69G0001', '01ARZ3NDEKTSV4RRFFQ69G0002'];

PendingFailure _failure(String id) => PendingFailure(
  id: id,
  eventIds: [id],
  changeIds: const [],
  reason: PendingFailureReason.permissionDenied,
);

/// A screen with one button that shows the outcome of [result].
Widget _outcomeHost(
  FakeLearningCommands commands,
  CaptureResult result, {
  VoidCallback? onUndone,
  void Function(List<String>)? onShown,
  String? learnerName,
}) => pumpApp(
  overrides: learnerStateOverrides(scope: c0Scope(), commands: commands),
  child: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () {
          final ids = showCaptureOutcome(
            context,
            result: result,
            commands: commands,
            message: 'Recorded 2',
            onUndone: onUndone,
            learnerName: learnerName,
          );
          onShown?.call(ids);
        },
        child: const Text('go'),
      ),
    ),
  ),
);

void main() {
  late FakeLearningCommands commands;

  setUp(() => commands = FakeLearningCommands());
  tearDown(() => commands.dispose());

  group('showCaptureOutcome', () {
    testWidgets('a success offers Undo, which voids exactly the batch ids '
        'and then reports undone', (tester) async {
      var undone = 0;
      List<String>? shown;
      await tester.pumpWidget(
        _outcomeHost(
          commands,
          const CaptureResult.success(eventIds: _ids),
          onUndone: () => undone++,
          onShown: (ids) => shown = ids,
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(shown, _ids);
      expect(find.text('Recorded 2'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(commands.calls.single.name, 'undoEvents');
      expect(commands.calls.single.args['eventIds'], _ids);
      expect(undone, 1);
    });

    testWidgets('a tutor write refused because the parent turned editing '
        'off names the learner (DNI-487 AC-6)', (tester) async {
      await tester.pumpWidget(
        _outcomeHost(
          commands,
          const CaptureResult.rejected(CaptureRejection.editingTurnedOff),
          learnerName: 'Moshe',
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(
        find.text("Moshe's parent has turned off editing"),
        findsOneWidget,
      );
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('editing turned off without a learner name falls back to '
        'the generic permission copy', (tester) async {
      await tester.pumpWidget(
        _outcomeHost(
          commands,
          const CaptureResult.rejected(CaptureRejection.editingTurnedOff),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(
        find.text("You don't have permission to make this edit"),
        findsOneWidget,
      );
    });

    testWidgets('a success that wrote nothing offers no Undo', (tester) async {
      await tester.pumpWidget(
        _outcomeHost(commands, const CaptureResult.success()),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Recorded 2'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('the Undo snackbar closes on its own', (tester) async {
      await tester.pumpWidget(
        _outcomeHost(commands, const CaptureResult.success(eventIds: _ids)),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Undo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Undo'), findsNothing);
      expect(commands.calls, isEmpty, reason: 'no undo without a tap');
    });

    testWidgets('an undo that is not saved says so and does not report '
        'undone', (tester) async {
      var undone = 0;
      commands.nextResult = const CaptureResult.rejected(
        CaptureRejection.notSaved,
      );
      await tester.pumpWidget(
        _outcomeHost(
          commands,
          const CaptureResult.success(eventIds: _ids),
          onUndone: () => undone++,
        ),
      );
      // The scripted result is consumed by the undo, not by the outcome.
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(undone, 0);
      expect(
        find.text('Not saved — your learning was not recorded.'),
        findsOneWidget,
      );
    });

    testWidgets('a locked capture shows the lock notice and returns no '
        'ids', (tester) async {
      List<String>? shown;
      await tester.pumpWidget(
        _outcomeHost(
          commands,
          CaptureResult.locked(
            LockWindow(DateTime.utc(2026, 9, 4), DateTime.utc(2026, 9, 5)),
          ),
          onShown: (ids) => shown = ids,
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(shown, isEmpty);
      expect(
        find.text('Not recorded — the app is closed for Shabbos and Yom Tov.'),
        findsOneWidget,
      );
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('an invalid capture says not saved', (tester) async {
      await tester.pumpWidget(
        _outcomeHost(
          commands,
          const CaptureResult.rejected(CaptureRejection.invalid),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(
        find.text('Not saved — your learning was not recorded.'),
        findsOneWidget,
      );
    });

    testWidgets('a batch rejected for good is left to the pending-failure '
        'listener (no duplicate notice)', (tester) async {
      await tester.pumpWidget(
        _outcomeHost(
          commands,
          const CaptureResult.rejected(CaptureRejection.notSaved),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('PendingCaptureFailureListener', () {
    Widget host({
      void Function(PendingFailure)? onFailure,
      void Function(PendingFailure)? onRetried,
      bool twice = false,
    }) => pumpApp(
      overrides: learnerStateOverrides(scope: c0Scope(), commands: commands),
      child: Scaffold(
        body: PendingCaptureFailureListener(
          onFailure: onFailure,
          onRetried: onRetried,
          child: twice
              ? const PendingCaptureFailureListener(child: Text('screen'))
              : const Text('screen'),
        ),
      ),
    );

    testWidgets('a permanent rejection rolls back once, says not saved and '
        'retries the same failure', (tester) async {
      final failed = <PendingFailure>[];
      final retried = <PendingFailure>[];
      await tester.pumpWidget(
        host(onFailure: failed.add, onRetried: retried.add),
      );
      await tester.pumpAndSettle();

      commands.pendingFailures.add([_failure(_ids.first)]);
      await tester.pumpAndSettle();
      expect(failed, [_failure(_ids.first)]);
      expect(
        find.text('Not saved — your learning was not recorded.'),
        findsOneWidget,
      );

      // The same list again is not a new failure.
      commands.pendingFailures.add([_failure(_ids.first)]);
      await tester.pump();
      expect(failed, hasLength(1));

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      final retry = commands.calls.where((c) => c.name == 'retry').single;
      expect(retry.args['pendingFailureId'], _ids.first);
      expect(retried, [_failure(_ids.first)]);
    });

    testWidgets("an undo's failure says the undo couldn't be saved "
        '(DNI-514 AC-9)', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      commands.pendingFailures.add([
        PendingFailure(
          id: _ids.first,
          eventIds: [_ids.first],
          changeIds: const [],
          reason: PendingFailureReason.permissionDenied,
          isUndo: true,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text("The undo couldn't be saved"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('two mounted listeners announce one failure once', (
      tester,
    ) async {
      await tester.pumpWidget(host(twice: true));
      await tester.pumpAndSettle();
      commands.pendingFailures.add([_failure(_ids.last)]);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      ScaffoldMessenger.of(
        tester.element(find.text('screen')),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing, reason: 'none queued');
    });

    testWidgets('no learner means no feed and no error', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          overrides: [
            ...learnerStateOverrides(),
            learningCommandsProvider.overrideWith((ref) async => null),
          ],
          child: const Scaffold(
            body: PendingCaptureFailureListener(child: Text('screen')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('screen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
