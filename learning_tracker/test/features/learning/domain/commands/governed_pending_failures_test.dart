// Mirror test for
// `lib/features/learning/domain/commands/governed_pending_failures.dart`
// (DNI-470: AD-54 Recovery for governed writes).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/governed_pending_failures.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_failure_reporter.dart';

GovernedWriteUnit _unit(
  Future<void> Function() send, {
  bool queueable = true,
}) => GovernedWriteUnit(
  id: 'e1',
  actionId: 'a1',
  changeIds: const ['e1'],
  writeCount: 2,
  queueable: queueable,
  send: send,
);

void main() {
  test('the reason is the permanent rejection code, else other', () {
    expect(
      GovernedPendingFailures.reasonOf(
        const PermanentWriteRejection('invalid-argument'),
      ),
      PendingFailureReason.invalidArgument,
    );
    expect(
      GovernedPendingFailures.reasonOf(StateError('x')),
      PendingFailureReason.other,
    );
  });

  test('a queued retry is withheld while in flight, then cleared on the '
      'late acknowledgement', () async {
    final failures = GovernedPendingFailures(
      ackWait: const Duration(milliseconds: 10),
    );
    addTearDown(failures.dispose);
    final ack = Completer<void>();
    var sends = 0;
    failures.record(
      LearningCommandKind.governedChange,
      _unit(() {
        sends++;
        return ack.future;
      }),
      const PermanentWriteRejection('permission-denied'),
    );
    expect(failures.pendingFailures.single.changeIds, ['e1']);

    final first = await failures.retry('e1');
    expect(
      first,
      const CaptureResult.success(
        changeIds: ['e1'],
        actionId: 'a1',
        queued: true,
      ),
    );
    expect(failures.pendingFailures, isEmpty, reason: 'in flight');
    expect(await failures.retry('e1'), first, reason: 'nothing re-sent');
    expect(sends, 1);

    ack.complete();
    await pumpEventQueue();
    expect(failures.pendingFailures, isEmpty);
    expect(await failures.retry('e1'), isNull);
  });

  test('a queued retry refused later is pending again', () async {
    final failures = GovernedPendingFailures(
      ackWait: const Duration(milliseconds: 10),
    );
    addTearDown(failures.dispose);
    final ack = Completer<void>();
    failures.record(
      LearningCommandKind.undoAction,
      _unit(() => ack.future),
      StateError('x'),
    );
    await failures.retry('e1');
    ack.completeError(const PermanentWriteRejection('failed-precondition'));
    await pumpEventQueue();
    expect(
      failures.pendingFailures.single.reason,
      PendingFailureReason.failedPrecondition,
    );
  });
}
