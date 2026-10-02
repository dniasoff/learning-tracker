/// DNI-513 ruling B4: the Change history reaches the data ring only
/// through this re-export, and re-exports the providers themselves — no
/// second declaration of the C0 ports, the learner scope or the sub-track
/// read.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart'
    as ring;
import 'package:learning_tracker/features/change_history/data/repositories/change_history_sources.dart'
    as sources;

void main() {
  test('every source is the data ring provider itself', () {
    expect(
      identical(
        sources.activeLearnerScopeProvider,
        ring.activeLearnerScopeProvider,
      ),
      isTrue,
    );
    expect(
      identical(
        sources.changeLogRepositoryProvider,
        ring.changeLogRepositoryProvider,
      ),
      isTrue,
    );
    expect(
      identical(
        sources.learningEventRepositoryProvider,
        ring.learningEventRepositoryProvider,
      ),
      isTrue,
    );
    expect(
      identical(
        sources.subTrackRepositoryProvider,
        ring.subTrackRepositoryProvider,
      ),
      isTrue,
    );
  });
}
