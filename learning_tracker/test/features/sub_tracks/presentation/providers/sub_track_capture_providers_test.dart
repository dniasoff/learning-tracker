// Story 2.10 (DNI-501) T3: the pending-capture overlay that moves a row on
// in the same frame and rolls it back on Undo or a rejected write.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/sub_track_capture_sources.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_capture_providers.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/fake_learner_state.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state/learner_state_overrides.dart';
import '../../../../helpers/pump_app.dart';

final _scope = c0Scope();

/// A sibling profile of the same owner (cross-profile isolation).
final _sibling = LearnerScope(
  ownerUid: 'owner-uid',
  profileId: '01ARZ3NDEKTSV4RRFFQ69G5FB0',
);

/// The active learner, switchable mid-test (a profile switch).
final class _ActiveScope extends Notifier<LearnerScope?> {
  @override
  LearnerScope? build() => _scope;

  void select(LearnerScope? scope) => state = scope;
}

final _activeScope = NotifierProvider<_ActiveScope, LearnerScope?>(
  _ActiveScope.new,
);
const _c = 'mishnayos';
const _school = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
const _a = 'Mishnah Berakhot 1:1';
const _b = 'Mishnah Berakhot 1:2';
const _e1 = '01ARZ3NDEKTSV4RRFFQ69G0001';
const _e2 = '01ARZ3NDEKTSV4RRFFQ69G0002';
const _d = 'Mishnah Berakhot 1:3';
const _e3 = '01ARZ3NDEKTSV4RRFFQ69G0003';

void main() {
  late ProviderContainer c;
  late PendingCapturesNotifier pending;

  ProviderContainer container({Set<String> counted = const {}}) {
    final out = ProviderContainer(
      overrides: learnerStateOverrides(
        scope: c0Scope(),
        state: fakeLearnerState(countedEventIds: counted),
      ),
    );
    addTearDown(out.dispose);
    return out;
  }

  setUp(() {
    c = container();
    pending = c.read(pendingCapturesProvider.notifier);
  });

  test('add marks the leaves pending for that source only, at once', () {
    pending.add(_scope, _c, _school, [_a, _b]);
    final state = c.read(pendingCapturesProvider);
    expect(state.refsOf(_scope, _c, _school), {_a, _b});
    expect(state.refsOf(_scope, _c, 'main'), isEmpty);
    expect(state.refsOf(_scope, 'bavli', _school), isEmpty);
  });

  test('a refused capture drops its token', () {
    final token = pending.add(_scope, _c, _school, [_a, _b]);
    pending.dropToken(token);
    expect(
      c.read(pendingCapturesProvider).refsOf(_scope, _c, _school),
      isEmpty,
    );
  });

  test('bound event ids roll back one by one (Undo, a rejected chunk)', () {
    final token = pending.add(_scope, _c, _school, [_a, _b]);
    pending
      ..bind(token, [_e1, _e2])
      ..dropEvents([_e2]);
    expect(c.read(pendingCapturesProvider).refsOf(_scope, _c, _school), {_a});
    pending.dropEvents([_e1]);
    expect(c.read(pendingCapturesProvider).entries, isEmpty);
  });

  test('a partly rejected capture keeps only its saved leaves, each bound '
      'to its own event', () {
    final token = pending.add(_scope, _c, _school, [_a, _b, _d]);
    // The first chunk (_a, _b) was rejected; only _e3 was saved.
    pending.bind(token, [_e1, _e2, _e3], notSaved: [_e1, _e2]);
    expect(c.read(pendingCapturesProvider).refsOf(_scope, _c, _school), {_d});
    expect(c.read(pendingCapturesProvider).entries.single.refs, {_e3: _d});
    pending.dropEvents([_e3]);
    expect(c.read(pendingCapturesProvider).entries, isEmpty);
  });

  test('a failure reported before its capture binds is never bound as '
      'recorded', () {
    final token = pending.add(_scope, _c, _school, [_a, _b]);
    pending
      ..rollBack([_e2])
      ..bind(token, [_e1, _e2]);
    expect(c.read(pendingCapturesProvider).refsOf(_scope, _c, _school), {_a});
    // A saved retry forgets the failure.
    pending.retried([_e2]);
    final again = pending.add(_scope, _c, _school, [_b]);
    pending.bind(again, [_e2]);
    expect(c.read(pendingCapturesProvider).refsOf(_scope, _c, _school), {
      _a,
      _b,
    });
  });

  test('a later rejection rolls back exactly its leaves', () {
    final token = pending.add(_scope, _c, _school, [_a, _b]);
    pending
      ..bind(token, [_e1, _e2])
      ..rollBack([_e1]);
    expect(c.read(pendingCapturesProvider).refsOf(_scope, _c, _school), {_b});
  });

  test('leaves the log already recorded (a stale picker, DNI-501 AC-2) '
      'leave the capture before the plan is lined up', () {
    final token = pending.add(_scope, _c, _school, [_a, _b, _d]);
    // Another device recorded _b while the picker was open: the command
    // planned events for _a and _d only.
    pending.bind(token, [_e1, _e3], alreadyRecorded: [_b]);
    expect(c.read(pendingCapturesProvider).entries.single.refs, {
      _e1: _a,
      _e3: _d,
    });
  });

  test('a plan that does not match the leaves one to one drops the '
      'capture', () {
    final token = pending.add(_scope, _c, _school, [_a, _b]);
    pending.bind(token, [_e1]);
    expect(c.read(pendingCapturesProvider).entries, isEmpty);
  });

  test('entries are pruned once the engine counts their events', () async {
    final counted = container(counted: {_e1});
    final notifier = counted.read(pendingCapturesProvider.notifier);
    final sub = counted.listen(pendingCapturesProvider, (_, _) {});
    addTearDown(sub.close);
    final token = notifier.add(_scope, _c, _school, [_a, _b]);
    notifier.bind(token, [_e1, _e2]);
    // The engine state arrives: _e1 is counted, _e2 not yet.
    await pumpEventQueue();
    expect(counted.read(pendingCapturesProvider).refsOf(_scope, _c, _school), {
      _b,
    });
  });

  group('cross-profile isolation: a pending capture belongs to its '
      'learner', () {
    test('leaves pending for one profile never read as pending for '
        'another', () {
      pending.add(_scope, _c, _school, [_a]);
      final state = c.read(pendingCapturesProvider);
      expect(state.refsOf(_scope, _c, _school), {_a});
      expect(state.refsOf(_sibling, _c, _school), isEmpty);
      expect(state.refsOf(null, _c, _school), isEmpty);
    });

    ProviderContainer switchingContainer() {
      final out = ProviderContainer(
        overrides: [
          // The overlay prunes on the active learner's engine state.
          learnerStateProvider.overrideWith(
            (ref, _) => Stream.value(fakeLearnerState()),
          ),
          activeLearnerScopeProvider.overrideWith(
            (ref) async => ref.watch(_activeScope),
          ),
        ],
      );
      addTearDown(out.dispose);
      return out;
    }

    Future<void> select(ProviderContainer c, LearnerScope? scope) async {
      c.read(_activeScope.notifier).select(scope);
      await c.read(activeLearnerScopeProvider.future);
      await pumpEventQueue();
    }

    test('a capture still queued for learner A is not recorded for '
        'learner B after a profile switch, and the switch drops it: A\'s '
        'commands, the only feed of its rejections, are gone', () async {
      final switching = switchingContainer();
      const key = (curriculumId: _c, source: 'main');
      final refs = switching.listen(activePendingRefsProvider(key), (_, _) {});
      addTearDown(refs.close);
      await switching.read(activeLearnerScopeProvider.future);

      // Learner A records a run; its write is queued (bound, not counted).
      final notifier = switching.read(pendingCapturesProvider.notifier);
      final token = notifier.add(_scope, _c, 'main', [_a, _b]);
      notifier.bind(token, [_e1, _e2]);
      expect(refs.read(), {_a, _b});

      // Switch to learner B: the same curriculum and source shows nothing
      // pending, and A's entry is gone (a rejection of it while B is
      // active would never be heard).
      await select(switching, _sibling);
      expect(refs.read(), isEmpty);
      expect(switching.read(pendingCapturesProvider).entries, isEmpty);

      // Back to A: the rows read A's engine state only, which holds a
      // queued write and not a rejected one; the overlay keeps nothing.
      await select(switching, _scope);
      expect(refs.read(), isEmpty);
    });

    test('a capture for A whose command answers after a switch binds '
        'nothing', () async {
      final switching = switchingContainer();
      final sub = switching.listen(pendingCapturesProvider, (_, _) {});
      addTearDown(sub.close);
      await switching.read(activeLearnerScopeProvider.future);
      final notifier = switching.read(pendingCapturesProvider.notifier);
      final token = notifier.add(_scope, _c, _school, [_a]);

      await select(switching, _sibling);
      notifier.bind(token, [_e1]);
      expect(switching.read(pendingCapturesProvider).entries, isEmpty);
    });

    test('the active learner\'s own entries survive its scope '
        're-resolving to the same learner', () async {
      final switching = switchingContainer();
      final sub = switching.listen(pendingCapturesProvider, (_, _) {});
      addTearDown(sub.close);
      await switching.read(activeLearnerScopeProvider.future);
      final notifier = switching.read(pendingCapturesProvider.notifier);
      notifier.add(_scope, _c, _school, [_a]);

      switching.invalidate(activeLearnerScopeProvider);
      await switching.read(activeLearnerScopeProvider.future);
      await pumpEventQueue();
      expect(
        switching.read(pendingCapturesProvider).refsOf(_scope, _c, _school),
        {_a},
      );
    });
  });

  testWidgets('a profile switch while the commands resolve writes nothing: '
      'the capture is not saved and its overlay entry is dropped', (
    tester,
  ) async {
    final resolving = Completer<LearningCommands?>();
    final commands = FakeLearningCommands();
    late ProviderContainer scope;
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          learnerStateProvider.overrideWith(
            (ref, _) => Stream.value(fakeLearnerState()),
          ),
          activeLearnerScopeProvider.overrideWith(
            (ref) async => ref.watch(_activeScope),
          ),
          learningCommandsProvider.overrideWith((ref) => resolving.future),
        ],
        child: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              scope = ProviderScope.containerOf(context);
              ref.watch(pendingCapturesProvider);
              return TextButton(
                onPressed: () => captureLeaves(
                  context,
                  ref,
                  curriculumId: _c,
                  source: _school,
                  refs: const [_a, _b],
                ),
                child: const Text('record'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('record'));
    await tester.pump();
    expect(scope.read(pendingCapturesProvider).refsOf(_scope, _c, _school), {
      _a,
      _b,
    });

    // The child switches to a sibling profile before the commands resolve;
    // they resolve bound to the sibling.
    scope.read(_activeScope.notifier).select(_sibling);
    await tester.pump();
    resolving.complete(commands);
    await tester.pumpAndSettle();

    expect(commands.calls, isEmpty, reason: 'nothing written to B');
    expect(scope.read(pendingCapturesProvider).entries, isEmpty);
    expect(find.textContaining('Not saved'), findsOneWidget);
  });
}
