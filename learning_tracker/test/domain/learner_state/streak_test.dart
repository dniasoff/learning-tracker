// Mirror test for `lib/domain/learner_state/streak.dart` (C0, DNI-524).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/streak.dart';

import '../../helpers/learner_state/c0_fixtures.dart';
import '../../helpers/learner_state/c0_stub_matcher.dart';
import '../../helpers/learner_state_fixtures.dart';

void main() {
  test('streakDay is a C0 stub owned by DNI-466', () {
    expect(
      () => streakDay(
        datedLearn(),
        settingsHistory: c0SettingsHistory(),
        locks: const [],
      ),
      throwsC0Stub('DNI-466', 'streakDay'),
    );
  });
}
