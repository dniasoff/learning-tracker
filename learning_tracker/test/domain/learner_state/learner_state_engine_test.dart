// Mirror test for `lib/domain/learner_state/learner_state_engine.dart`
// (C0, DNI-524).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

import '../../helpers/learner_state/c0_fixtures.dart';
import '../../helpers/learner_state/c0_stub_matcher.dart';

void main() {
  test('run is a C0 stub owned by DNI-465', () {
    final inputs = LearnerStateInputs(
      events: const [],
      subTracks: const [],
      mainTrackIntent: const {},
      goals: const {},
      intentHistory: const [],
      settingsHistory: c0SettingsHistory(),
      calendars: const {},
      corpora: const {},
      nowUtc: DateTime.utc(2026, 9, 1),
    );
    expect(
      () => const LearnerStateEngine().run(inputs),
      throwsC0Stub('DNI-465', 'LearnerStateEngine.run'),
    );
  });

  test('CalendarAssignment compares by value', () {
    const node = NodeEntry(level: 'daf', ref: 'Berakhot 2');
    expect(
      const CalendarAssignment('2026-09-01', node),
      const CalendarAssignment('2026-09-01', node),
    );
    expect(
      const CalendarAssignment('2026-09-01', node),
      isNot(const CalendarAssignment('2026-09-02', node)),
    );
  });
}
