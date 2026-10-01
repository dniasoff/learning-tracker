/// Unit tests for the [CompleteRead] load state.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';

void main() {
  test('loading states are equal', () {
    expect(const CompleteReadLoading<int>(), const CompleteReadLoading<int>());
  });

  test('ready compares items and rejected ids; list is unmodifiable', () {
    final a = CompleteReadReady<int>([1, 2]);
    expect(a, CompleteReadReady<int>([1, 2]));
    expect(a, isNot(CompleteReadReady<int>([1])));
    expect(a.isClean, isTrue);
    expect(() => a.items.add(3), throwsUnsupportedError);
    final b = CompleteReadReady<int>(
      [1],
      rejected: [RejectedRow('d', StateError('x'))],
    );
    expect(b.isClean, isFalse);
    expect(
      b,
      CompleteReadReady<int>([1], rejected: [const RejectedRow('d', 'other')]),
    );
  });
}
