// DNI-496 (Story 2.5): the sub-track feature reaches the data-access ring
// only through this repository-layer re-export (AD-23 Rule A).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart'
    as ring;
import 'package:learning_tracker/features/sub_tracks/data/repositories/ongoing_sub_track_sources.dart';

void main() {
  test('re-exports the Story 2.1 providers, not copies of them', () {
    expect(
      identical(activeLearnerScopeProvider, ring.activeLearnerScopeProvider),
      isTrue,
    );
    expect(
      identical(subTrackRepositoryProvider, ring.subTrackRepositoryProvider),
      isTrue,
    );
    expect(
      identical(
        governedIntentRepositoryProvider,
        ring.governedIntentRepositoryProvider,
      ),
      isTrue,
    );
  });
}
