// Story 2.10 (DNI-501) T3: the pending-capture overlay that moves a row on
// in the same frame and rolls it back on Undo or a rejected write.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_capture_providers.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/fake_learner_state.dart';
import '../../../../helpers/learner_state/learner_state_overrides.dart';

const _c = 'mishnayos';
const _school = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
const _a = 'Mishnah Berakhot 1:1';
const _b = 'Mishnah Berakhot 1:2';
const _e1 = '01ARZ3NDEKTSV4RRFFQ69G0001';
const _e2 = '01ARZ3NDEKTSV4RRFFQ69G0002';

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
    pending.add(_c, _school, [_a, _b]);
    final state = c.read(pendingCapturesProvider);
    expect(state.refsOf(_c, _school), {_a, _b});
    expect(state.refsOf(_c, 'main'), isEmpty);
    expect(state.refsOf('bavli', _school), isEmpty);
  });

  test('a refused capture drops its token', () {
    final token = pending.add(_c, _school, [_a, _b]);
    pending.dropToken(token);
    expect(c.read(pendingCapturesProvider).refsOf(_c, _school), isEmpty);
  });

  test('bound event ids roll back one by one (Undo, a rejected chunk)', () {
    final token = pending.add(_c, _school, [_a, _b]);
    pending
      ..bind(token, [_e1, _e2])
      ..dropEvents([_e2]);
    expect(c.read(pendingCapturesProvider).refsOf(_c, _school), {_a});
    pending.dropEvents([_e1]);
    expect(c.read(pendingCapturesProvider).entries, isEmpty);
  });

  test('entries are pruned once the engine counts their events', () async {
    final counted = container(counted: {_e1});
    final notifier = counted.read(pendingCapturesProvider.notifier);
    final sub = counted.listen(pendingCapturesProvider, (_, _) {});
    addTearDown(sub.close);
    final token = notifier.add(_c, _school, [_a, _b]);
    notifier.bind(token, [_e1, _e2]);
    // The engine state arrives: _e1 is counted, _e2 not yet.
    await pumpEventQueue();
    expect(counted.read(pendingCapturesProvider).refsOf(_c, _school), {_b});
  });
}
