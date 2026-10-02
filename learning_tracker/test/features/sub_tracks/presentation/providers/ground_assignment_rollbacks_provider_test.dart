/// Story 2.7 (DNI-498) AC-4, UX-DR-127: a queued ground assignment the
/// server later refuses is counted once per sub-track, from the commands'
/// pending-failure feed, and announced by exactly one listener.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/ground_assignment_rollbacks_provider.dart';

import '../../../../helpers/learner_state/fake_learning_commands.dart';

PendingFailure _failure(String changeId) => PendingFailure(
  id: changeId,
  eventIds: const [],
  changeIds: [changeId],
  reason: PendingFailureReason.permissionDenied,
);

void main() {
  late ProviderContainer container;
  late FakeLearningCommands commands;

  GroundAssignmentRollbacks notifier() =>
      container.read(groundAssignmentRollbacksProvider.notifier);
  Map<String, int> state() => container.read(groundAssignmentRollbacksProvider);

  setUp(() {
    container = ProviderContainer();
    commands = FakeLearningCommands();
  });

  tearDown(() async {
    container.dispose();
    await commands.dispose();
  });

  test('a refused queued assignment is counted once for its sub-track and '
      'taken once', () async {
    notifier().trackQueued(
      commands,
      'school',
      const CaptureSuccess(changeIds: ['c1'], actionId: 'c1', queued: true),
    );
    commands.pendingFailures.add([_failure('other'), _failure('c1')]);
    await pumpEventQueue();
    expect(state(), {'school': 1});
    // The feed re-lists the same failure: not counted again.
    commands.pendingFailures.add([_failure('c1')]);
    await pumpEventQueue();
    expect(state(), {'school': 1});
    expect(notifier().take('school'), isTrue);
    expect(notifier().take('school'), isFalse);
    expect(state(), isEmpty);
  });

  test('a confirmed (not queued) assignment is not tracked', () async {
    notifier().trackQueued(
      commands,
      'school',
      const CaptureSuccess(changeIds: ['c1'], actionId: 'c1'),
    );
    expect(commands.pendingFailures.hasListener, isFalse);
    commands.pendingFailures.add([_failure('c1')]);
    await pumpEventQueue();
    expect(state(), isEmpty);
  });

  test('one feed per commands instance, several sub-tracks', () async {
    notifier()
      ..trackQueued(
        commands,
        'school',
        const CaptureSuccess(changeIds: ['c1'], actionId: 'c1', queued: true),
      )
      ..trackQueued(
        commands,
        'shiur',
        const CaptureSuccess(changeIds: ['c2'], actionId: 'c2', queued: true),
      );
    final watches = commands.calls
        .where((c) => c.name == 'watchPendingFailures')
        .length;
    expect(watches, 1);
    commands.pendingFailures.add([_failure('c1'), _failure('c2')]);
    await pumpEventQueue();
    expect(state(), {'school': 1, 'shiur': 1});
  });
}
