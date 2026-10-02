// Story 2.10 (DNI-501): the Learn tab's Up to… / +1 rollback listener —
// a pending failure rolls back exactly its leaves and is announced once
// with Retry; it stays mounted when scrolled out of a lazy list.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_capture_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/pending_capture_rollback.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/fake_learner_state.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state/learner_state_overrides.dart';
import '../../../../helpers/pump_app.dart';

const _c = 'mishnayos';
const _a = 'Mishnah Berakhot 1:1';
const _b = 'Mishnah Berakhot 1:2';
const _e1 = '01ARZ3NDEKTSV4RRFFQ69G0001';
const _e2 = '01ARZ3NDEKTSV4RRFFQ69G0002';

PendingFailure _failure(List<String> ids) => PendingFailure(
  id: ids.first,
  eventIds: ids,
  changeIds: const [],
  reason: PendingFailureReason.permissionDenied,
);

Future<(FakeLearningCommands, ProviderContainer)> _pump(
  WidgetTester tester, {
  required Widget body,
}) async {
  final commands = FakeLearningCommands();
  addTearDown(commands.dispose);
  await tester.pumpWidget(
    pumpApp(
      overrides: learnerStateOverrides(
        scope: c0Scope(),
        state: fakeLearnerState(),
        commands: commands,
      ),
      child: Scaffold(body: body),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(Scaffold)),
  );
  return (commands, container);
}

void main() {
  testWidgets('a failure rolls back exactly its leaves and offers Retry; a '
      'saved retry lets the leaves bind again', (tester) async {
    final (commands, container) = await _pump(
      tester,
      body: const PendingCaptureRollback(),
    );
    final pending = container.read(pendingCapturesProvider.notifier);
    final token = pending.add(_c, 'main', [_a, _b]);
    pending.bind(token, [_e1, _e2]);

    commands.pendingFailures.add([
      _failure([_e2]),
    ]);
    await tester.pumpAndSettle();
    expect(container.read(pendingCapturesProvider).refsOf(_c, 'main'), {_a});
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(commands.calls.where((c) => c.name == 'retry').single.args, {
      'pendingFailureId': _e2,
    });
    final again = pending.add(_c, 'main', [_b]);
    pending.bind(again, [_e2]);
    expect(container.read(pendingCapturesProvider).refsOf(_c, 'main'), {
      _a,
      _b,
    });
  });

  testWidgets('it stays mounted when scrolled out of a lazy list', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final (commands, container) = await _pump(
      tester,
      body: ListView(
        controller: controller,
        children: [
          const PendingCaptureRollback(),
          for (var i = 0; i < 40; i++) SizedBox(height: 200, child: Text('$i')),
        ],
      ),
    );
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final pending = container.read(pendingCapturesProvider.notifier);
    final token = pending.add(_c, 'main', [_a]);
    pending.bind(token, [_e1]);

    commands.pendingFailures.add([
      _failure([_e1]),
    ]);
    await tester.pumpAndSettle();
    expect(container.read(pendingCapturesProvider).entries, isEmpty);
    expect(find.text('Retry'), findsOneWidget);
  });
}
