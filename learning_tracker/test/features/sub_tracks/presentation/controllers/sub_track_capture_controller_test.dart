// Story 2.9 (DNI-500) T3 — the +1 controller's guards, outcomes and the
// lock-stamped reconciliation (AC-2, AC-5, AC-9).
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
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
    expect(await _controller(c).undo(ids), isTrue);
    expect(commands.calls.last.name, 'undoEvents');
    expect(commands.calls.last.args['eventIds'], ids);
    expect(c.read(subTrackCaptureControllerProvider).awaitingEngine, isEmpty);
    expect(await _controller(_container(noCommands: true)).undo(ids), isFalse);
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
}
