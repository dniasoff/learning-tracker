// Mirror test for
// `lib/features/dashboard/domain/services/track_completion_service.dart`
// (DNI-474: goal progress is the engine's distinct learnt count).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/dashboard/domain/services/track_completion_service.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learner_state.dart';
import '../../../../helpers/learner_state/progress_fixtures.dart';

void main() {
  const service = TrackCompletionService();

  test('track percentage: repeats and chazara count a leaf once', () {
    final state = progressState([
      progressLearn(1, 'Mishnah Peah 1:1'),
      progressLearn(2, 'Mishnah Peah 1:1', minutes: 3, stage: 2),
      progressLearn(3, 'Mishnah Peah 1:2', minutes: 4),
    ])[engineCurriculum];
    expect(
      service.computeTrackPercentage(state: state, totalItems: 4),
      closeTo(0.5, 1e-9),
    );
  });

  test('track percentage is 0 with no state or no items, and clamps', () {
    expect(service.computeTrackPercentage(state: null, totalItems: 4), 0);
    expect(
      service.computeTrackPercentage(
        state: FakeCurriculumState(learntLeaves: const {'a', 'b'}),
        totalItems: 0,
      ),
      0,
    );
    expect(
      service.computeTrackPercentage(
        state: FakeCurriculumState(distinctLearnt: 9),
        totalItems: 4,
      ),
      1,
    );
  });

  test('curriculum percentage unions learnt leaves across curricula', () {
    expect(
      service.computeCurriculumPercentage(
        states: [
          FakeCurriculumState(learntLeaves: const {'a', 'b'}),
          FakeCurriculumState(learntLeaves: const {'b', 'c'}),
          null,
        ],
        totalItems: 6,
      ),
      closeTo(0.5, 1e-9),
    );
  });
}
