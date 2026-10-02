// Mirror test for
// `lib/features/sub_tracks/data/repositories/sub_track_detail_sources.dart`
// (DNI-497): the bridge re-exports the data-ring providers themselves, not
// copies (ruling B4: one declaration each).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart'
    as ring;
import 'package:learning_tracker/features/sub_tracks/data/repositories/sub_track_detail_sources.dart';

void main() {
  test('re-exports the identical provider instances', () {
    expect(activeLearnerScopeProvider, same(ring.activeLearnerScopeProvider));
    expect(
      learningEventRepositoryProvider,
      same(ring.learningEventRepositoryProvider),
    );
    expect(subTrackRepositoryProvider, same(ring.subTrackRepositoryProvider));
  });
}
