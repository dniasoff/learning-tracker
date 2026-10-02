// Story 2.9 (DNI-500) — the sub-tracks feature reaches the data-access ring
// only through its repository layer (AD-23), re-exporting the DNI-464
// providers rather than declaring new ones (ruling B4).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart'
    as ring;
import 'package:learning_tracker/features/sub_tracks/data/repositories/sub_track_sources.dart';

void main() {
  test('re-exports the single DNI-464 provider instances', () {
    expect(
      identical(activeLearnerScopeProvider, ring.activeLearnerScopeProvider),
      isTrue,
    );
    expect(
      identical(subTrackRepositoryProvider, ring.subTrackRepositoryProvider),
      isTrue,
    );
  });
}
