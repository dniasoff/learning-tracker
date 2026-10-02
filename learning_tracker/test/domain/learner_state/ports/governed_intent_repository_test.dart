// Mirror test for
// `lib/domain/learner_state/ports/governed_intent_repository.dart`
// (C0, DNI-524).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';

import '../../../helpers/learner_state/c0_fixtures.dart';

void main() {
  test('LearnerIntent holds unmodifiable copies of its maps', () {
    final goals = <String, CurriculumGoals>{
      'mishnayos': const CurriculumGoals(),
    };
    final intent = LearnerIntent(
      settings: c0Settings,
      mainTracks: const <String, MainTrackIntent>{},
      goals: goals,
    );
    goals.clear();
    expect(intent.settings, c0Settings);
    expect(intent.goals.keys, ['mishnayos']);
    expect(
      () => intent.goals['x'] = const CurriculumGoals(),
      throwsUnsupportedError,
    );
  });
}
