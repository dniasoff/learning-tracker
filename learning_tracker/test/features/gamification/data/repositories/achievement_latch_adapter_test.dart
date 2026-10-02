// Mirror test for
// `lib/features/gamification/data/repositories/achievement_latch_adapter.dart`
// (DNI-480): the latch reads the totals only from a learner state that has
// seen the write, and gives up after its wait.
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/gamification/data/repositories/achievement_latch_adapter.dart';

LearnerState _state(Set<String> counted, {Set<String> locked = const {}}) =>
    LearnerState(
      nowUtc: DateTime.utc(2026, 9),
      curricula: const {},
      countedEventIds: counted,
      lockIgnoredEventIds: locked,
    );

void main() {
  test('the latest state is used when it has seen the write', () async {
    final now = _state({'a', 'b'});
    final feed = LearnerStateFeed(
      latest: () => now,
      changes: const Stream.empty(),
    );
    expect(await feed.including({'a'}, const Duration(seconds: 1)), now);
  });

  test('otherwise it waits for a later state that has seen it', () async {
    final changes = StreamController<LearnerState>.broadcast();
    addTearDown(changes.close);
    final feed = LearnerStateFeed(
      latest: () => _state({'a'}),
      changes: changes.stream,
    );
    final result = feed.including({'b', 'c'}, const Duration(seconds: 5));
    changes
      ..add(_state({'a', 'b'}))
      ..add(_state({'a', 'b'}, locked: {'c'}));
    expect((await result).lockIgnoredEventIds, {'c'});
  });

  test('a state that never arrives times out', () {
    fakeAsync((async) {
      final silent = StreamController<LearnerState>.broadcast();
      final feed = LearnerStateFeed(latest: () => null, changes: silent.stream);
      Object? error;
      feed
          .including({'a'}, const Duration(seconds: 30))
          .then<void>((_) {}, onError: (Object e) => error = e);
      async.elapse(const Duration(seconds: 29));
      expect(error, isNull);
      async.elapse(const Duration(seconds: 2));
      expect(error, isA<TimeoutException>());
      unawaited(silent.close());
    });
  });
}
