// Mirror test for
// `lib/features/learner_state/data/repositories/learner_state_sources.dart`
// (C0, DNI-524): the bridge re-exports the data-ring providers themselves,
// not copies (ruling B4: one declaration each).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart'
    as ring;
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';

void main() {
  test('re-exports the identical provider instances', () {
    expect(activeLearnerScopeProvider, same(ring.activeLearnerScopeProvider));
    expect(
      learningEventRepositoryProvider,
      same(ring.learningEventRepositoryProvider),
    );
    expect(subTrackRepositoryProvider, same(ring.subTrackRepositoryProvider));
    expect(changeLogRepositoryProvider, same(ring.changeLogRepositoryProvider));
    expect(
      governedIntentRepositoryProvider,
      same(ring.governedIntentRepositoryProvider),
    );
    expect(learningWritePortProvider, same(ring.learningWritePortProvider));
    expect(
      oversizedGovernedWritePortProvider,
      same(ring.oversizedGovernedWritePortProvider),
    );
  });
}
