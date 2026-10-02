// Story 2.10 (DNI-501): the sub-tracks feature's repository seam re-exports
// the C0 (DNI-524) data-ring providers rather than declaring its own
// (ruling B4), so every reader shares one provider instance.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart'
    as ring;
import 'package:learning_tracker/features/sub_tracks/data/repositories/sub_track_capture_sources.dart'
    as seam;

void main() {
  test('the learner scope provider is the data ring\'s own', () {
    expect(
      identical(
        seam.activeLearnerScopeProvider,
        ring.activeLearnerScopeProvider,
      ),
      isTrue,
    );
  });

  test('the sub-track repository provider is the data ring\'s own', () {
    expect(
      identical(
        seam.subTrackRepositoryProvider,
        ring.subTrackRepositoryProvider,
      ),
      isTrue,
    );
  });
}
