// Mirror test for `lib/domain/learner_state/streak.dart` (DNI-466 AC-6).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/streak.dart';

import '../../helpers/learner_state/c0_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';

void main() {
  test('a same-day dated main learn counts on learned_on', () {
    expect(
      streakDay(
        datedLearn(),
        settingsHistory: c0SettingsHistory(),
        locks: const [],
      ),
      '2026-09-01',
    );
  });

  test('a sub-track learn never counts', () {
    expect(
      streakDay(
        datedLearn(source: ulidD),
        settingsHistory: c0SettingsHistory(),
        locks: const [],
      ),
      isNull,
    );
  });
}
