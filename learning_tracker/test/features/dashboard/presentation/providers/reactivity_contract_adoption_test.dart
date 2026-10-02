/// Reactivity of the dashboard percentage aggregates (DNI-474): both read
/// the active learner's LearnerState, so a new engine state (a capture, a
/// void, a correction on any device) recomputes them live, without
/// pull-to-refresh or a completion-committed signal.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';

import '../../../../helpers/learner_state/progress_fixtures.dart';

void main() {
  for (final (name, provider) in [
    (
      'dashboardTrackCompletionPercentageProvider',
      dashboardTrackCompletionPercentageProvider(CurriculumId.mishnayos),
    ),
    (
      'dashboardCompletionPercentageProvider',
      dashboardCompletionPercentageProvider(CurriculumId.mishnayos),
    ),
  ]) {
    test('$name recomputes on a new learner state', () async {
      final states = StreamController<LearnerState>.broadcast();
      addTearDown(states.close);
      final container = ProviderContainer.test(
        overrides: [
          ...progressOverrides(null, states: states.stream),
          scopedItemCountProvider.overrideWith((ref, c) async => 9),
        ],
      );
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      await pumpEventQueue();

      states.add(progressState([progressLearn(1, 'Mishnah Peah 1:1')]));
      await pumpEventQueue();
      expect(sub.read().value, closeTo(1 / 9, 1e-9));

      states.add(
        progressState([
          progressLearn(1, 'Mishnah Peah 1:1'),
          progressLearn(2, 'Mishnah Peah 1:2', minutes: 1),
        ]),
      );
      await pumpEventQueue();
      expect(sub.read().value, closeTo(2 / 9, 1e-9));
    });
  }
}
