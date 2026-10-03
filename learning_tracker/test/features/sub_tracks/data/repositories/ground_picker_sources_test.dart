// Mirror test for
// `lib/features/sub_tracks/data/repositories/ground_picker_sources.dart`
// (Story 2.7 / DNI-498): the picker's repository layer re-exports the
// learner-scope and port providers — the same instances, no second
// declaration (ruling B4).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart'
    as data;
import 'package:learning_tracker/features/sub_tracks/data/repositories/ground_picker_sources.dart'
    as sources;

void main() {
  test('re-exports the data-layer providers unchanged', () {
    expect(
      identical(
        sources.activeLearnerScopeProvider,
        data.activeLearnerScopeProvider,
      ),
      isTrue,
    );
    expect(
      identical(
        sources.subTrackRepositoryProvider,
        data.subTrackRepositoryProvider,
      ),
      isTrue,
    );
    expect(
      identical(
        sources.governedIntentRepositoryProvider,
        data.governedIntentRepositoryProvider,
      ),
      isTrue,
    );
  });
}
