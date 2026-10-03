/// Story 2.8 (DNI-499), AD-54 Recovery: a queued End, Delete or Add next
/// year stays pending across a rebuild of `learningCommandsProvider` (a
/// parent-PIN, profile or clock change) and across switching learners and
/// back; a settle in flight still lands and a refused write is retried
/// through the current commands. A queued result that arrives after the
/// parent switched learners is tracked, settled and retried under the
/// learner the write was issued for, never the newly active one.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/sub_track_sources.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_lifecycle_sync_provider.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';

/// Bumped to rebuild `learningCommandsProvider` with fresh commands.
class _Generation extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// The active learner scope.
class _Scope extends Notifier<LearnerScope> {
  _Scope(this.initial);

  final LearnerScope initial;

  @override
  LearnerScope build() => initial;

  void set(LearnerScope scope) => state = scope;
}

const _changeId = '01JWXDGT000000000000000777';

void main() {
  final scopeA = c0Scope();
  final scopeB = c0Scope(ownerUid: 'other-owner');
  late List<FakeLearningCommands> built;
  late ProviderContainer c;
  late NotifierProvider<_Generation, int> generation;
  late NotifierProvider<_Scope, LearnerScope> activeScope;

  setUp(() {
    built = [];
    generation = NotifierProvider<_Generation, int>(_Generation.new);
    activeScope = NotifierProvider<_Scope, LearnerScope>(() => _Scope(scopeA));
    c = ProviderContainer.test(
      overrides: [
        activeLearnerScopeProvider.overrideWith(
          (ref) async => ref.watch(activeScope),
        ),
        learningCommandsProvider.overrideWith((ref) async {
          ref.watch(generation);
          ref.watch(activeScope);
          final commands = FakeLearningCommands();
          built.add(commands);
          return commands;
        }),
      ],
    );
    c.listen(subTrackLifecycleSyncProvider, (_, _) {});
  });

  tearDown(() async {
    for (final commands in built) {
      await commands.dispose();
    }
  });

  Future<FakeLearningCommands> commands() async {
    await c.read(activeLearnerScopeProvider.future);
    return (await c.read(learningCommandsProvider.future))!
        as FakeLearningCommands;
  }

  Future<void> rebuildCommands() async {
    c.read(generation.notifier).bump();
    await commands();
    await pumpEventQueue();
  }

  SubTrackLifecycleSyncStatus? status() =>
      c.read(subTrackLifecycleSyncProvider)[_changeId]?.status;

  Future<FakeLearningCommands> trackQueued({required bool accepted}) async {
    final first = await commands();
    final verdict = Completer<bool>();
    first.subTrackConfirmations[_changeId] = verdict;
    c
        .read(subTrackLifecycleSyncProvider.notifier)
        .track(
          const SubTrackLifecycleSync(
            changeId: _changeId,
            write: SubTrackLifecycleWrite.end,
            name: 'School',
          ),
          SubTrackLifecycleOrigin(scope: scopeA, commands: first),
        );
    expect(status(), SubTrackLifecycleSyncStatus.waiting);

    await rebuildCommands();
    expect(built, hasLength(2), reason: 'the commands were rebuilt');
    expect(
      status(),
      SubTrackLifecycleSyncStatus.waiting,
      reason: 'a commands rebuild keeps the pending write',
    );

    verdict.complete(accepted);
    await pumpEventQueue();
    return first;
  }

  test('a write queued before a commands rebuild settles as saved', () async {
    await trackQueued(accepted: true);
    expect(status(), SubTrackLifecycleSyncStatus.saved);
  });

  test('a write refused after a commands rebuild is not saved, and its retry '
      'goes through the current commands', () async {
    final first = await trackQueued(accepted: false);
    expect(status(), SubTrackLifecycleSyncStatus.notSaved);

    await c
        .read(subTrackLifecycleSyncProvider.notifier)
        .retry(c.read(subTrackLifecycleSyncProvider)[_changeId]!);
    expect(status(), SubTrackLifecycleSyncStatus.saved);
    expect(first.calls.map((call) => call.name), [
      'whenSubTrackChangeConfirmed',
    ]);
    expect(built.last.calls.map((call) => call.name), ['retry']);
  });

  test('switching learners shows that learner\'s writes; switching back '
      'restores the pending one', () async {
    final first = await commands();
    final verdict = Completer<bool>();
    first.subTrackConfirmations[_changeId] = verdict;
    c
        .read(subTrackLifecycleSyncProvider.notifier)
        .track(
          const SubTrackLifecycleSync(
            changeId: _changeId,
            write: SubTrackLifecycleWrite.delete,
            name: 'School',
          ),
          SubTrackLifecycleOrigin(scope: scopeA, commands: first),
        );

    c.read(activeScope.notifier).set(scopeB);
    await commands();
    await pumpEventQueue();
    expect(c.read(subTrackLifecycleSyncProvider), isEmpty);

    c.read(activeScope.notifier).set(scopeA);
    await commands();
    await pumpEventQueue();
    expect(status(), SubTrackLifecycleSyncStatus.waiting);

    verdict.complete(true);
    await pumpEventQueue();
    expect(status(), SubTrackLifecycleSyncStatus.saved);
  });

  Map<String, SubTrackLifecycleSync> storeOf(LearnerScope scope) =>
      c.read(subTrackLifecycleSyncStoreProvider(scope)).writes;

  test('a queued result that arrives after a learner switch stays with the '
      'learner it was issued for, and retries through that learner\'s '
      'commands', () async {
    // The origin is captured before the command runs.
    final origin = (await resolveSubTrackLifecycleOrigin(c.read))!;
    expect(origin.scope, scopeA);
    final commandsA = origin.commands as FakeLearningCommands;
    final verdict = Completer<bool>();
    commandsA.subTrackConfirmations[_changeId] = verdict;

    // The parent switches to B while the command awaits the server.
    c.read(activeScope.notifier).set(scopeB);
    final commandsB = await commands();
    await pumpEventQueue();
    expect(commandsB, isNot(same(commandsA)));

    // The queued result arrives now, with B active.
    c
        .read(subTrackLifecycleSyncProvider.notifier)
        .track(
          const SubTrackLifecycleSync(
            changeId: _changeId,
            write: SubTrackLifecycleWrite.end,
            name: 'School',
          ),
          origin,
        );
    await pumpEventQueue();
    expect(storeOf(scopeB), isEmpty, reason: 'never in the active store');
    expect(c.read(subTrackLifecycleSyncProvider), isEmpty);
    expect(
      storeOf(scopeA)[_changeId]?.status,
      SubTrackLifecycleSyncStatus.waiting,
    );

    // A refuses it; settlement went through A's commands only.
    verdict.complete(false);
    await pumpEventQueue();
    expect(
      storeOf(scopeA)[_changeId]?.status,
      SubTrackLifecycleSyncStatus.notSaved,
    );
    expect(commandsB.calls, isEmpty);

    // A retry of A's write while B is active never resends through B's
    // commands.
    await c
        .read(subTrackLifecycleSyncProvider.notifier)
        .retry(storeOf(scopeA)[_changeId]!);
    expect(commandsB.calls, isEmpty);
    expect(
      storeOf(scopeA)[_changeId]?.status,
      SubTrackLifecycleSyncStatus.notSaved,
    );

    // Back on A: the pending recovery state is shown and its retry goes
    // through A's commands.
    c.read(activeScope.notifier).set(scopeA);
    final commandsA2 = await commands();
    await pumpEventQueue();
    expect(status(), SubTrackLifecycleSyncStatus.notSaved);
    expect(c.read(subTrackLifecycleSyncProvider)[_changeId]?.scope, scopeA);
    await c
        .read(subTrackLifecycleSyncProvider.notifier)
        .retry(c.read(subTrackLifecycleSyncProvider)[_changeId]!);
    expect(status(), SubTrackLifecycleSyncStatus.saved);
    expect(commandsA2.calls.map((call) => call.name), ['retry']);
    expect(commandsB.calls, isEmpty);
    expect(storeOf(scopeB), isEmpty);
  });

  test('removing a write after a learner switch removes it only from the '
      'learner it was issued for', () async {
    final first = await commands();
    first.subTrackConfirmations[_changeId] = Completer<bool>()..complete(true);
    c
        .read(subTrackLifecycleSyncProvider.notifier)
        .track(
          const SubTrackLifecycleSync(
            changeId: _changeId,
            write: SubTrackLifecycleWrite.delete,
            name: 'School',
          ),
          SubTrackLifecycleOrigin(scope: scopeA, commands: first),
        );
    await pumpEventQueue();
    expect(status(), SubTrackLifecycleSyncStatus.saved);
    // The record the panel holds when it shows A's confirmation.
    final shown = c.read(subTrackLifecycleSyncProvider)[_changeId]!;

    c.read(activeScope.notifier).set(scopeB);
    await commands();
    await pumpEventQueue();
    c
        .read(subTrackLifecycleSyncStoreProvider(scopeB))
        .track(
          const SubTrackLifecycleSync(
            changeId: _changeId,
            write: SubTrackLifecycleWrite.end,
            name: 'Other',
          ),
          built.last,
        );

    // The panel forgets A's write after B became active.
    c.read(subTrackLifecycleSyncProvider.notifier).remove(shown);
    expect(storeOf(scopeA), isEmpty);
    expect(storeOf(scopeB), contains(_changeId));
  });

  test('no origin resolves while no learner commands exist', () async {
    final none = ProviderContainer.test(
      overrides: [
        activeLearnerScopeProvider.overrideWith((ref) async => scopeA),
        learningCommandsProvider.overrideWith((ref) async => null),
      ],
    );
    expect(await resolveSubTrackLifecycleOrigin(none.read), isNull);
  });
}
