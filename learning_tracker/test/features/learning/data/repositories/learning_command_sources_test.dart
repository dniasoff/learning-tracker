// Mirror test for
// `lib/features/learning/data/repositories/learning_command_sources.dart`
// (DNI-469): the bridge re-exports the data-ring providers themselves, not
// copies (ruling B4: one declaration each).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart'
    as ring;
import 'package:learning_tracker/features/learning/data/repositories/learning_command_sources.dart';

void main() {
  test('re-exports the identical provider instances', () {
    expect(activeAuthUidProvider, same(ring.activeAuthUidProvider));
    expect(activeLearnerScopeProvider, same(ring.activeLearnerScopeProvider));
    expect(
      learningEventRepositoryProvider,
      same(ring.learningEventRepositoryProvider),
    );
    expect(learningWritePortProvider, same(ring.learningWritePortProvider));
    expect(pointsAmountReaderProvider, same(ring.pointsAmountReaderProvider));
  });
}
