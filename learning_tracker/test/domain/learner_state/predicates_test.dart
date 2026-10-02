// Mirror test for `lib/domain/learner_state/predicates.dart` (C0, DNI-524).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/predicates.dart';

import '../../helpers/learner_state/c0_fixtures.dart';
import '../../helpers/learner_state/c0_stub_matcher.dart';

void main() {
  group('sub-track predicates are C0 stubs owned by DNI-467', () {
    const today = '2026-09-01';

    test('holdsGround', () {
      expect(
        () => holdsGround(c0SubTrack(), today),
        throwsC0Stub('DNI-467', 'holdsGround'),
      );
    });

    test('onHome', () {
      expect(
        () => onHome(c0SubTrack(), today),
        throwsC0Stub('DNI-467', 'onHome'),
      );
    });

    test('inForecast', () {
      expect(
        () => inForecast(c0SubTrack(), today, deadline: null),
        throwsC0Stub('DNI-467', 'inForecast'),
      );
    });
  });
}
