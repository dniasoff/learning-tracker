// Mirror test for `lib/domain/learner_state/expand_ground.dart` (C0, DNI-524).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/expand_ground.dart';

import '../../helpers/learner_state/c0_stub_matcher.dart';

void main() {
  test('expandGround is a C0 stub owned by DNI-465', () {
    expect(
      () => expandGround(const [], InMemoryCorpus('c', const [])),
      throwsC0Stub('DNI-465', 'expandGround'),
    );
  });
}
