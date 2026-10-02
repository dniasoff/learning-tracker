// Mirror test for `lib/domain/learner_state/c0_stub.dart` (C0, DNI-524 AC-3).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/c0_stub.dart';

import '../../helpers/learner_state/c0_stub_matcher.dart';

void main() {
  test('c0Stub throws UnimplementedError naming the member and its owner '
      'story', () {
    expect(() => c0Stub('DNI-465', 'thing'), throwsC0Stub('DNI-465', 'thing'));
  });
}
