// Mirror test for `lib/domain/learner_state/ordered_leaves.dart`
// (C0, DNI-524).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/ordered_leaves.dart';

import '../../helpers/learner_state/c0_stub_matcher.dart';

void main() {
  test('orderedLeaves is a C0 stub owned by DNI-467', () {
    expect(
      () => orderedLeaves(InMemoryCorpus('c', const []), const []),
      throwsC0Stub('DNI-467', 'orderedLeaves'),
    );
  });
}
