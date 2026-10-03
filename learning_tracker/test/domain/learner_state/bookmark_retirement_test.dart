// DNI-478 AC-3: retired position persistence is covered by engine inputs.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

void main() {
  test('counted capture advances derived position; void restores it', () {
    const engine = LearnerStateEngine();
    CurriculumState state(List<LearningEvent> events) =>
        engine.run(engineInputs(events: events))[engineCurriculum]!;

    final before = state(const []);
    final captured = engineLearn(
      1,
      'Mishnah Berakhot 1:1',
      stage: 1,
      minutes: 5,
    );
    final afterCapture = state([captured]);
    final afterVoid = state([captured, engineVoid(2, 1, minutes: 6)]);

    expect(before.mainTrackPosition, 'Mishnah Berakhot 1:1');
    expect(afterCapture.mainTrackPosition, 'Mishnah Berakhot 1:2');
    expect(afterVoid.mainTrackPosition, before.mainTrackPosition);
    expect(afterVoid.learntLeaves, isEmpty);
  });

  test(
    'prior learning excludes its leaf without anchoring the current unit',
    () {
      final state = const LearnerStateEngine().run(
        engineInputs(
          events: [
            engineLearn(
              1,
              'Mishnah Peah 1:1',
              dateState: DateState.beforeTracking,
            ),
          ],
        ),
      )[engineCurriculum]!;

      expect(state.learntLeaves, {'Mishnah Peah 1:1'});
      expect(state.mainTrackPosition, 'Mishnah Berakhot 1:1');
    },
  );
}
