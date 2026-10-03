// Story 2.9 (DNI-500) T3 — the +1 controller's guards, outcomes and the
// lock-stamped reconciliation (AC-2, AC-5, AC-9).
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_home_projection.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/controllers/sub_track_capture_controller.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_session.dart';

import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/sub_tracks/sub_track_home_fixtures.dart';

const _item = SubTrackHomeItem(
  subTrackId: schoolId,
  curriculumId: mishnayos,
  name: 'School',
  kind: SubTrackRowKind.active,
  position: berachos14,
);

ProviderContainer _container({
  LearningCommands? commands,
  bool noCommands = false,
  SubTrackViewerRole role = SubTrackViewerRole.child,
  Future<LearningCommands?> Function()? commandsFactory,
}) {
  final container = ProviderContainer(
    overrides: [
      subTrackViewerRoleProvider.overrideWithValue(role),
      learningCommandsProvider.overrideWith(
        (ref) =>
            commandsFactory?.call() ??
            Future.value(noCommands ? null : commands),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

SubTrackCaptureController _controller(ProviderContainer c) =>
    c.read(subTrackCaptureControllerProvider.notifier);

void main() {
  test('records the position with source, dated, no stage, default '
      'learned_on, and tracks the event for the engine', () async {
    final commands = FakeLearningCommands();
    final c = _container(commands: commands);
    final outcome = await _controller(c).plusOne(_item);
    expect(outcome, isA<PlusOneRecorded>());
    final call = commands.calls.single;
    expect(call.args['refs'], [berachos14]);
    expect(call.args['source'], schoolId);
    expect(call.args['stage'], isNull);
    expect(call.args['learnedOn'], isNull);
    final ids = (outcome as PlusOneRecorded).eventIds;
    expect(c.read(subTrackCaptureControllerProvider).awaitingEngine, ids);
    expect(c.read(subTrackCaptureControllerProvider).inFlight, isEmpty);
  });

  test('ignores a row that cannot capture, a tutor, and a second tap in '
      'flight', () async {
    final commands = FakeLearningCommands();
    expect(
      await _controller(_container(commands: commands)).plusOne(
        const SubTrackHomeItem(
          subTrackId: schoolId,
          curriculumId: mishnayos,
          name: 'School',
          kind: SubTrackRowKind.groundless,
        ),
      ),
      isA<PlusOneIgnored>(),
    );
    expect(
      await _controller(
        _container(commands: commands, role: SubTrackViewerRole.tutor),
      ).plusOne(_item),
      isA<PlusOneIgnored>(),
    );
    expect(commands.calls, isEmpty);

    final slow = Completer<LearningCommands?>();
    final c = _container(commandsFactory: () => slow.future);
    final first = _controller(c).plusOne(_item);
    expect(c.read(subTrackCaptureControllerProvider).inFlight, {schoolId});
    expect(await _controller(c).plusOne(_item), isA<PlusOneIgnored>());
    slow.complete(commands);
    expect(await first, isA<PlusOneRecorded>());
    expect(commands.calls, hasLength(1));
  });

  test(
    'locked, refused, missing commands and a throw map to outcomes',
    () async {
      final commands = FakeLearningCommands()
        ..nextResult = CaptureResult.locked(
          LockWindow(DateTime.utc(2026, 9, 4), DateTime.utc(2026, 9, 5)),
        );
      final c = _container(commands: commands);
      expect(await _controller(c).plusOne(_item), isA<PlusOneLocked>());
      for (final result in const [
        CaptureResult.childLimit(),
        CaptureResult.onlineRequired(),
        CaptureResult.rejected(CaptureRejection.invalid),
      ]) {
        commands.nextResult = result;
        expect(await _controller(c).plusOne(_item), isA<PlusOneFailed>());
      }
      expect(
        await _controller(_container(noCommands: true)).plusOne(_item),
        isA<PlusOneFailed>(),
      );
      expect(
        await _controller(
          _container(commandsFactory: () => Future.error(StateError('x'))),
        ).plusOne(_item),
        isA<PlusOneFailed>(),
      );
      expect(c.read(subTrackCaptureControllerProvider).inFlight, isEmpty);
    },
  );

  test('undo voids the captured events', () async {
    final commands = FakeLearningCommands();
    final c = _container(commands: commands);
    final ids =
        ((await _controller(c).plusOne(_item)) as PlusOneRecorded).eventIds;
    expect(await _controller(c).undo(_item, ids), UndoOutcome.undone);
    expect(commands.calls.last.name, 'undoEvents');
    expect(commands.calls.last.args['eventIds'], ids);
    expect(c.read(subTrackCaptureControllerProvider).awaitingEngine, isEmpty);
  });

  test('a failed or refused undo is reported and keeps the capture tracked '
      'for the engine', () async {
    final commands = FakeLearningCommands();
    final c = _container(commands: commands);
    final ids =
        ((await _controller(c).plusOne(_item)) as PlusOneRecorded).eventIds;

    commands.nextResult = const CaptureResult.onlineRequired();
    expect(await _controller(c).undo(_item, ids), UndoOutcome.failed);
    commands.nextResult = const CaptureResult.rejected(
      CaptureRejection.lockIgnoredTarget,
    );
    expect(await _controller(c).undo(_item, ids), UndoOutcome.refused);
    commands.nextResult = CaptureResult.locked(
      LockWindow(DateTime.utc(2026, 9, 4), DateTime.utc(2026, 9, 5)),
    );
    expect(await _controller(c).undo(_item, ids), UndoOutcome.locked);
    expect(c.read(subTrackCaptureControllerProvider).awaitingEngine, ids);
    // The capture is still reconciled after the failed undos (AC-5).
    expect(
      _controller(
        c,
      ).reconcile(homeLearnerState(const [], lockIgnoredEventIds: {...ids})),
      ids,
    );

    expect(
      await _controller(_container(noCommands: true)).undo(_item, ids),
      UndoOutcome.failed,
    );
    expect(
      await _controller(
        _container(commandsFactory: () => Future.error(StateError('x'))),
      ).undo(_item, ids),
      UndoOutcome.failed,
    );

    // A retried undo that goes through settles it.
    expect(await _controller(c).undo(_item, ids), UndoOutcome.undone);
    expect(c.read(subTrackCaptureControllerProvider).awaitingEngine, isEmpty);
  });

  group('queued writes the server later refuses (AD-30)', () {
    const captured = '01FAKE0000000000000000QUE1';
    const voided = '01FAKE0000000000000000QUV1';

    PendingFailure failure(String id, List<String> eventIds) => PendingFailure(
      id: id,
      eventIds: eventIds,
      changeIds: const [],
      reason: PendingFailureReason.permissionDenied,
    );

    Future<(FakeLearningCommands, ProviderContainer)> queuedPlusOne() async {
      final commands = FakeLearningCommands();
      addTearDown(commands.dispose);
      final c = _container(commands: commands);
      commands.nextResult = const CaptureResult.success(
        eventIds: [captured],
        queued: true,
      );
      expect(await _controller(c).plusOne(_item), isA<PlusOneRecorded>());
      return (commands, c);
    }

    test('a confirmed (not queued) capture does not follow pending '
        'failures', () async {
      final commands = FakeLearningCommands();
      final c = _container(commands: commands);
      await _controller(c).plusOne(_item);
      expect(commands.calls.map((call) => call.name), ['capture']);
    });

    test('a refused queued +1 becomes one not-saved entry and is no longer '
        'awaited; other writes\' failures are ignored', () async {
      final (commands, c) = await queuedPlusOne();
      expect(commands.calls.map((call) => call.name), [
        'capture',
        'watchPendingFailures',
      ]);
      expect(c.read(subTrackCaptureControllerProvider).awaitingEngine, {
        captured,
      });

      commands.pendingFailures.add([
        failure('other', const ['01FAKE0000000000000000ZZZZ']),
      ]);
      await pumpEventQueue();
      expect(c.read(subTrackCaptureControllerProvider).notSaved, isEmpty);

      commands.pendingFailures.add([
        failure('other', const ['01FAKE0000000000000000ZZZZ']),
        failure('f1', const [captured]),
      ]);
      await pumpEventQueue();
      final state = c.read(subTrackCaptureControllerProvider);
      expect(state.notSaved, const [
        SubTrackNotSaved(
          failureId: 'f1',
          kind: SubTrackWriteKind.plusOne,
          subTrackId: schoolId,
          subTrackName: 'School',
          eventIds: [captured],
        ),
      ]);
      expect(state.awaitingEngine, isEmpty);

      // The same feed again adds nothing.
      commands.pendingFailures.add([
        failure('f1', const [captured]),
      ]);
      await pumpEventQueue();
      expect(c.read(subTrackCaptureControllerProvider).notSaved, hasLength(1));
    });

    test('Retry re-sends the failure, clears the entry and awaits the '
        'capture again; a refused retry keeps it', () async {
      final (commands, c) = await queuedPlusOne();
      commands.pendingFailures.add([
        failure('f1', const [captured]),
      ]);
      await pumpEventQueue();

      commands.nextResult = const CaptureResult.rejected(
        CaptureRejection.targetNotFound,
      );
      expect(await _controller(c).retryNotSaved('f1'), isFalse);
      expect(c.read(subTrackCaptureControllerProvider).notSaved, hasLength(1));

      expect(await _controller(c).retryNotSaved('f1'), isTrue);
      expect(commands.calls.last.name, 'retry');
      expect(commands.calls.last.args['pendingFailureId'], 'f1');
      final state = c.read(subTrackCaptureControllerProvider);
      expect(state.notSaved, isEmpty);
      expect(state.awaitingEngine, {captured});
      expect(await _controller(c).retryNotSaved('unknown'), isFalse);
    });

    test('an entry resolved elsewhere leaves the list', () async {
      final (commands, c) = await queuedPlusOne();
      commands.pendingFailures.add([
        failure('f1', const [captured]),
      ]);
      await pumpEventQueue();
      commands.pendingFailures.add(const []);
      await pumpEventQueue();
      expect(c.read(subTrackCaptureControllerProvider).notSaved, isEmpty);
    });

    test('a refused queued undo becomes an undo not-saved entry', () async {
      final (commands, c) = await queuedPlusOne();
      commands.nextResult = const CaptureResult.success(
        eventIds: [voided],
        queued: true,
      );
      expect(
        await _controller(c).undo(_item, const [captured]),
        UndoOutcome.undone,
      );
      expect(c.read(subTrackCaptureControllerProvider).awaitingEngine, isEmpty);
      // The voided capture is no longer followed; its undo is.
      commands.pendingFailures.add([
        failure('fc', const [captured]),
        failure('fv', const [voided]),
      ]);
      await pumpEventQueue();
      final notSaved = c.read(subTrackCaptureControllerProvider).notSaved;
      expect(notSaved.single.failureId, 'fv');
      expect(notSaved.single.kind, SubTrackWriteKind.undo);
      expect(notSaved.single.eventIds, [voided]);
    });
  });

  group('learner scope (bound to the active commands)', () {
    const captured = '01FAKE0000000000000000QUE1';
    const voided = '01FAKE0000000000000000QUV1';

    PendingFailure failure(String id, List<String> eventIds) => PendingFailure(
      id: id,
      eventIds: eventIds,
      changeIds: const [],
      reason: PendingFailureReason.permissionDenied,
    );

    /// A container whose active commands can be switched, like a learner
    /// (or tutored session) change re-binding `learningCommandsProvider`.
    (ProviderContainer, void Function(LearningCommands?)) switchable(
      LearningCommands? initial,
    ) {
      final container = ProviderContainer(
        overrides: [
          subTrackViewerRoleProvider.overrideWithValue(
            SubTrackViewerRole.child,
          ),
          _activeCommandsProvider.overrideWith(() => _ActiveCommands(initial)),
          learningCommandsProvider.overrideWith(
            (ref) async => ref.watch(_activeCommandsProvider),
          ),
        ],
      );
      addTearDown(container.dispose);
      // The Learn section watches the controller, keeping it active.
      container.listen(subTrackCaptureControllerProvider, (_, _) {});
      return (
        container,
        (next) => container.read(_activeCommandsProvider.notifier).set(next),
      );
    }

    FakeLearningCommands fake() {
      final commands = FakeLearningCommands();
      addTearDown(commands.dispose);
      return commands;
    }

    test('a learner switch drops the previous learner\'s not-saved +1 and '
        'Undo entries, awaited captures and failure feed', () async {
      final learnerA = fake();
      final learnerB = fake();
      final (c, switchTo) = switchable(learnerA);
      // Two queued +1s; the second is undone (queued too).
      learnerA.nextResult = const CaptureResult.success(
        eventIds: [captured],
        queued: true,
      );
      expect(await _controller(c).plusOne(_item), isA<PlusOneRecorded>());
      learnerA.nextResult = const CaptureResult.success(
        eventIds: ['01FAKE0000000000000000QUE2'],
        queued: true,
      );
      await _controller(c).plusOne(_item);
      learnerA.nextResult = const CaptureResult.success(
        eventIds: [voided],
        queued: true,
      );
      expect(
        await _controller(c).undo(_item, const ['01FAKE0000000000000000QUE2']),
        UndoOutcome.undone,
      );
      learnerA.pendingFailures.add([
        failure('fa', const [captured]),
        failure('fv', const [voided]),
      ]);
      await pumpEventQueue();
      expect(c.read(subTrackCaptureControllerProvider).notSaved, hasLength(2));

      switchTo(learnerB);
      await pumpEventQueue();
      var state = c.read(subTrackCaptureControllerProvider);
      expect(state.notSaved, isEmpty);
      expect(state.awaitingEngine, isEmpty);
      expect(state.inFlight, isEmpty);

      // The previous learner's feed no longer reaches this session.
      learnerA.pendingFailures.add([
        failure('fa2', const [captured]),
      ]);
      await pumpEventQueue();
      expect(c.read(subTrackCaptureControllerProvider).notSaved, isEmpty);

      // Retry of a stale entry and Undo of the previous learner's capture
      // write nothing under the new learner.
      expect(await _controller(c).retryNotSaved('fa'), isFalse);
      expect(
        await _controller(c).undo(_item, const [captured]),
        UndoOutcome.refused,
      );
      expect(learnerB.calls, isEmpty);

      // The new learner's own writes work as before.
      learnerB.nextResult = const CaptureResult.success(
        eventIds: ['01FAKE0000000000000000BBB1'],
      );
      expect(await _controller(c).plusOne(_item), isA<PlusOneRecorded>());
      state = c.read(subTrackCaptureControllerProvider);
      expect(state.awaitingEngine, {'01FAKE0000000000000000BBB1'});

      // Leaving to no learner clears it too.
      switchTo(null);
      await pumpEventQueue();
      expect(c.read(subTrackCaptureControllerProvider).awaitingEngine, isEmpty);
    });

    test('a capture that settles after the switch is not tracked or '
        'offered for Undo', () async {
      final learnerA = _SlowCommands();
      final learnerB = fake();
      final (c, switchTo) = switchable(learnerA);
      final pending = _controller(c).plusOne(_item);
      await pumpEventQueue();
      expect(c.read(subTrackCaptureControllerProvider).inFlight, {schoolId});

      switchTo(learnerB);
      await pumpEventQueue();
      learnerA.release.complete(
        const CaptureResult.success(eventIds: [captured], queued: true),
      );
      expect(await pending, isA<PlusOneIgnored>());
      final state = c.read(subTrackCaptureControllerProvider);
      expect(state.awaitingEngine, isEmpty);
      expect(state.inFlight, isEmpty);
      expect(learnerA.calls, ['capture']);
    });

    test('a refused retry made under the old learner is not resent after '
        'the switch', () async {
      final learnerA = fake();
      final learnerB = fake();
      final (c, switchTo) = switchable(learnerA);
      learnerA.nextResult = const CaptureResult.success(
        eventIds: [captured],
        queued: true,
      );
      await _controller(c).plusOne(_item);
      learnerA.pendingFailures.add([
        failure('fa', const [captured]),
      ]);
      await pumpEventQueue();
      final entry = c.read(subTrackCaptureControllerProvider).notSaved.single;
      switchTo(learnerB);
      await pumpEventQueue();
      expect(await _controller(c).retryNotSaved(entry.failureId), isFalse);
      expect(learnerA.calls.map((call) => call.name), isNot(contains('retry')));
      expect(learnerB.calls, isEmpty);
    });
  });

  test('a refused Undo or retry under several queued writes keeps every '
      'other capture awaited', () async {
    final commands = FakeLearningCommands();
    addTearDown(commands.dispose);
    final c = _container(commands: commands);
    const first = '01FAKE0000000000000000MUL1';
    const second = '01FAKE0000000000000000MUL2';
    const voided = '01FAKE0000000000000000MULV';
    for (final id in const [first, second]) {
      commands.nextResult = CaptureResult.success(eventIds: [id], queued: true);
      await _controller(c).plusOne(_item);
    }
    commands.nextResult = const CaptureResult.success(
      eventIds: [voided],
      queued: true,
    );
    expect(
      await _controller(c).undo(_item, const [second]),
      UndoOutcome.undone,
    );
    commands.pendingFailures.add([
      const PendingFailure(
        id: 'fv',
        eventIds: [voided],
        changeIds: [],
        reason: PendingFailureReason.permissionDenied,
      ),
    ]);
    await pumpEventQueue();
    expect(c.read(subTrackCaptureControllerProvider).awaitingEngine, {first});
    expect(await _controller(c).retryNotSaved('fv'), isTrue);
    expect(c.read(subTrackCaptureControllerProvider).awaitingEngine, {first});
  });

  test('reconcile returns lock-ignored captures once and settles counted '
      'ones', () async {
    final commands = FakeLearningCommands();
    final c = _container(commands: commands);
    final a = ((await _controller(c).plusOne(_item)) as PlusOneRecorded)
        .eventIds
        .single;
    final b = ((await _controller(c).plusOne(_item)) as PlusOneRecorded)
        .eventIds
        .single;
    expect(_controller(c).reconcile(homeLearnerState(const [])), isEmpty);
    final lockIgnored = _controller(c).reconcile(
      homeLearnerState(
        const [],
        countedEventIds: {a},
        lockIgnoredEventIds: {b},
      ),
    );
    expect(lockIgnored, [b]);
    expect(c.read(subTrackCaptureControllerProvider).awaitingEngine, isEmpty);
    expect(
      _controller(
        c,
      ).reconcile(homeLearnerState(const [], lockIgnoredEventIds: {b})),
      isEmpty,
    );
  });

  test(
    'a replayed capture (same event id) is tracked and reported once',
    () async {
      final commands = FakeLearningCommands();
      final c = _container(commands: commands);
      commands.nextResult = const CaptureResult.success(
        eventIds: ['01FAKE0000000000000000REPL'],
      );
      await _controller(c).plusOne(_item);
      commands.nextResult = const CaptureResult.success(
        eventIds: ['01FAKE0000000000000000REPL'],
      );
      await _controller(c).plusOne(_item);
      expect(c.read(subTrackCaptureControllerProvider).awaitingEngine, {
        '01FAKE0000000000000000REPL',
      });
      final state = homeLearnerState(
        const [],
        lockIgnoredEventIds: {'01FAKE0000000000000000REPL'},
      );
      expect(_controller(c).reconcile(state), ['01FAKE0000000000000000REPL']);
      expect(_controller(c).reconcile(state), isEmpty);
    },
  );
}

/// The active learner's commands, switchable in a test.
final _activeCommandsProvider =
    NotifierProvider<_ActiveCommands, LearningCommands?>(
      () => _ActiveCommands(null),
    );

class _ActiveCommands extends Notifier<LearningCommands?> {
  _ActiveCommands(this._initial);

  final LearningCommands? _initial;

  @override
  LearningCommands? build() => _initial;

  void set(LearningCommands? next) => state = next;
}

/// Commands whose capture settles only when [release] completes.
class _SlowCommands implements LearningCommands {
  final release = Completer<CaptureResult>();

  /// The method names called, in order.
  final List<String> calls = [];

  @override
  Future<CaptureResult> capture({
    required String curriculumId,
    List<LeafRef> refs = const [],
    List<NodeEntry> nodes = const [],
    required String source,
    required DateState dateState,
    CivilDate? learnedOn,
    int? stage,
    bool skipRecorded = false,
  }) {
    calls.add('capture');
    return release.future;
  }

  @override
  Stream<List<PendingFailure>> watchPendingFailures() {
    calls.add('watchPendingFailures');
    return const Stream.empty();
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
