// Mirror test for `lib/domain/learner_state/tri_state.dart` (DNI-465 T3:
// FR-15 tri-state).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/tri_state.dart';

void main() {
  test('none, some and all learnt map to empty, partial, complete', () {
    expect(triStateOf(['a', 'b'], {}), TriState.empty);
    expect(triStateOf(['a', 'b'], {'a'}), TriState.partial);
    expect(triStateOf(['a', 'b'], {'a', 'b', 'z'}), TriState.complete);
  });

  test('a node with no leaves is empty', () {
    expect(triStateOf(const [], {'a'}), TriState.empty);
  });
}
