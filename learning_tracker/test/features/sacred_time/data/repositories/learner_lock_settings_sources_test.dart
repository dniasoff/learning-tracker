// Mirror test for
// `lib/features/sacred_time/data/repositories/learner_lock_settings_sources.dart`
// (DNI-470): the bridge re-exports the data-ring providers themselves, not
// copies (ruling B4: one declaration each).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart'
    as ring;
import 'package:learning_tracker/features/sacred_time/data/repositories/learner_lock_settings_sources.dart';

void main() {
  test('re-exports the identical provider instances', () {
    expect(changeLogRepositoryProvider, same(ring.changeLogRepositoryProvider));
    expect(
      learnerSettingsReaderProvider,
      same(ring.learnerSettingsReaderProvider),
    );
  });
}
