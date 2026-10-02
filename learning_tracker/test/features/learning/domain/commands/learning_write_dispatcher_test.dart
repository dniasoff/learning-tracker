// Mirror test for
// `lib/features/learning/domain/commands/learning_write_dispatcher.dart`
// (DNI-469 AC-7 recovery, AC-9 queued local success).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_failure_reporter.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_write_dispatcher.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';

LearningWriteChunk _chunk(int first, {int size = 2}) => LearningWriteChunk(
  events: [for (var i = 0; i < size; i++) engineLearn(first + i, 'r$i')],
  awards: [
    PointsAward(eventId: engineUlid(first), amount: 10, createdAt: engineAt(0)),
  ],
);

void main() {
  late InMemoryLearningWritePort port;
  late RecordingLearningFailureReporter reporter;
  late LearningWriteDispatcher dispatcher;

  setUp(() {
    port = InMemoryLearningWritePort();
    reporter = RecordingLearningFailureReporter();
    dispatcher = LearningWriteDispatcher(
      scope: c0Scope(),
      port: port,
      reporter: reporter,
      ackWait: const Duration(milliseconds: 40),
    );
  });
  tearDown(() => dispatcher.dispose());

  test('acknowledged chunks: every event id, not queued', () async {
    final outcome = await dispatcher.dispatch(LearningCommandKind.capture, [
      _chunk(1),
      _chunk(10),
    ]);
    expect(outcome.eventIds, [
      engineUlid(1),
      engineUlid(2),
      engineUlid(10),
      engineUlid(11),
    ]);
    expect(outcome.queued, isFalse);
    expect(outcome.allRejected, isFalse);
    expect(port.chunks, hasLength(2));
  });

  test('AC-9: an unacknowledged (SDK-queued) chunk returns queued local '
      'success without waiting for the server', () async {
    port.holdNext();
    final outcome = await dispatcher.dispatch(LearningCommandKind.capture, [
      _chunk(1),
    ]);
    expect(outcome.queued, isTrue);
    expect(outcome.eventIds, [engineUlid(1), engineUlid(2)]);
    expect(dispatcher.pendingFailures, isEmpty);
    port.release();
    await pumpEventQueue();
    expect(dispatcher.pendingFailures, isEmpty, reason: 'no app-level queue');
  });

  test('AC-7: a chunk rejected for good within the window is a pending '
      'failure, reported with enums only', () async {
    port.failNextWith(const PermanentWriteRejection('permission-denied'));
    final chunk = _chunk(1);
    final outcome = await dispatcher.dispatch(LearningCommandKind.capture, [
      chunk,
    ]);
    expect(outcome.allRejected, isTrue);
    expect(outcome.eventIds, isEmpty);
    expect(dispatcher.pendingFailures, [
      PendingFailure(
        id: engineUlid(1),
        eventIds: [engineUlid(1), engineUlid(2)],
        changeIds: const [],
        reason: PendingFailureReason.permissionDenied,
      ),
    ]);
    expect(reporter.reports, [
      (
        command: LearningCommandKind.capture,
        reason: PendingFailureReason.permissionDenied,
        writeCount: 3,
      ),
    ]);
  });

  test('AC-7: a queued chunk the server rejects later becomes a pending '
      'failure then; retry re-sends the identical chunk', () async {
    port.holdNext();
    final chunk = _chunk(1);
    final seen = <List<PendingFailure>>[];
    final sub = dispatcher.watchPendingFailures().listen(seen.add);
    addTearDown(sub.cancel);

    await dispatcher.dispatch(LearningCommandKind.capture, [chunk]);
    port.reject(const PermanentWriteRejection('invalid-argument'));
    await pumpEventQueue();
    expect(seen.last.single.reason, PendingFailureReason.invalidArgument);

    final retried = await dispatcher.retry(engineUlid(1));
    expect(retried!.queued, isFalse);
    expect(identical(port.attempts.last, chunk), isTrue);
    expect(port.chunks.single, same(chunk), reason: 'same ids and times');
    expect(dispatcher.pendingFailures, isEmpty);
    expect(seen.last, isEmpty);
  });

  test('a retry rejected again stays pending under the same id', () async {
    port.failNextWith(const PermanentWriteRejection('failed-precondition'));
    await dispatcher.dispatch(LearningCommandKind.voidEvent, [_chunk(1)]);
    port.failNextWith(const PermanentWriteRejection('failed-precondition'));
    final outcome = await dispatcher.retry(engineUlid(1));
    expect(outcome!.allRejected, isTrue);
    expect(dispatcher.pendingFailures.single.id, engineUlid(1));
    expect(reporter.reports.last.command, LearningCommandKind.retry);
  });

  test('a retry that fails without an acknowledgement keeps the failure; '
      'a second retry saves it', () async {
    port.failNextWith(const PermanentWriteRejection('permission-denied'));
    final chunk = _chunk(1);
    await dispatcher.dispatch(LearningCommandKind.capture, [chunk]);
    final seen = <List<PendingFailure>>[];
    final sub = dispatcher.watchPendingFailures().listen(seen.add);
    addTearDown(sub.cancel);

    port.holdNext();
    final first = dispatcher.retry(engineUlid(1));
    await pumpEventQueue();
    expect(dispatcher.pendingFailures, isEmpty, reason: 'retry in flight');
    port.reject(StateError('unavailable'));
    await expectLater(first, throwsStateError);
    expect(dispatcher.pendingFailures.single.id, engineUlid(1));
    await pumpEventQueue();
    expect(seen.last.single.id, engineUlid(1), reason: 'observers see it');

    final second = await dispatcher.retry(engineUlid(1));
    expect(second!.allRejected, isFalse);
    expect(second.queued, isFalse);
    expect(port.chunks.single, same(chunk));
    expect(dispatcher.pendingFailures, isEmpty);
    await pumpEventQueue();
    expect(seen.last, isEmpty);
  });

  test('a retry still unacknowledged after the window is queued; a later '
      'non-permanent failure restores the failure for another retry', () async {
    port.failNextWith(const PermanentWriteRejection('permission-denied'));
    final chunk = _chunk(1);
    await dispatcher.dispatch(LearningCommandKind.capture, [chunk]);

    port.holdNext();
    final queued = await dispatcher.retry(engineUlid(1));
    expect(queued!.queued, isTrue);
    expect(queued.eventIds, [engineUlid(1), engineUlid(2)]);
    expect(dispatcher.pendingFailures, isEmpty);

    final again = await dispatcher.retry(engineUlid(1));
    expect(again!.queued, isTrue, reason: 'still in flight');
    expect(port.attempts, hasLength(2), reason: 'nothing re-sent');

    port.reject(StateError('lost'));
    await pumpEventQueue();
    expect(dispatcher.pendingFailures.single.id, engineUlid(1));

    final saved = await dispatcher.retry(engineUlid(1));
    expect(saved!.queued, isFalse);
    expect(port.chunks.single, same(chunk));
    expect(dispatcher.pendingFailures, isEmpty);
  });

  test(
    'a queued retry the server later rejects for good is pending again',
    () async {
      port.failNextWith(const PermanentWriteRejection('permission-denied'));
      await dispatcher.dispatch(LearningCommandKind.capture, [_chunk(1)]);
      port.holdNext();
      await dispatcher.retry(engineUlid(1));
      port.reject(const PermanentWriteRejection('failed-precondition'));
      await pumpEventQueue();
      expect(
        dispatcher.pendingFailures.single.reason,
        PendingFailureReason.failedPrecondition,
      );
    },
  );

  test('retry of an unknown id is null', () async {
    expect(await dispatcher.retry(engineUlid(77)), isNull);
  });

  test('a non-permanent failure is not app-queued: rethrown within the '
      'window, never a pending failure', () async {
    final throwing = LearningWriteDispatcher(
      scope: c0Scope(),
      port: _ThrowingPort(StateError('boom')),
      reporter: reporter,
    );
    addTearDown(throwing.dispose);
    await expectLater(
      throwing.dispatch(LearningCommandKind.capture, [_chunk(1)]),
      throwsStateError,
    );
    expect(throwing.pendingFailures, isEmpty);
    expect(reporter.reports, isEmpty);
  });

  test('pendingFailureReasonOf maps server codes', () {
    expect(
      pendingFailureReasonOf('permission-denied'),
      PendingFailureReason.permissionDenied,
    );
    expect(
      pendingFailureReasonOf('invalid-argument'),
      PendingFailureReason.invalidArgument,
    );
    expect(
      pendingFailureReasonOf('failed-precondition'),
      PendingFailureReason.failedPrecondition,
    );
    expect(pendingFailureReasonOf('not-found'), PendingFailureReason.other);
  });

  test('the reported error carries enums and a count only', () {
    const error = LearningWriteRejectedError(
      command: LearningCommandKind.unlearn,
      reason: PendingFailureReason.permissionDenied,
      writeCount: 4,
    );
    expect(
      error.toString(),
      'LearningWriteRejected(command: unlearn, reason: permissionDenied, '
      'writes: 4)',
    );
  });
}

final class _ThrowingPort implements LearningWritePort {
  _ThrowingPort(this.error);

  final Error error;

  @override
  Future<void> commit(LearnerScope scope, LearningWriteChunk chunk) async =>
      throw error;
}
