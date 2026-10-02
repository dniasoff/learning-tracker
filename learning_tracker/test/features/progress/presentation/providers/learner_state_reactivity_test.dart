// DNI-474: the progress readers recompute from each new LearnerState (a
// capture, void or correction from any device), replacing the retired
// completion-committed reactivity tests (R15).
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/progress/data/repositories/progress_points_awards_source.dart';
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/recent_activity_providers.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';

import '../../../../helpers/learner_state/progress_fixtures.dart';

class _NoStages extends Fake implements StageDefinitionRepository {
  @override
  Future<List<StageDefinition>> getStagesForCurriculum(CurriculumId c) async =>
      const [];
}

/// Emits two states and returns the provider's value after each.
Future<(T?, T?)> _twoStates<T>(
  ProviderListenable<AsyncValue<T>> provider,
) async {
  final states = StreamController<LearnerState>.broadcast();
  addTearDown(states.close);
  final container = ProviderContainer.test(
    overrides: [
      ...progressOverrides(null, states: states.stream),
      stageDefinitionRepositoryProvider.overrideWith((ref, c) => _NoStages()),
      progressPointsAwardsProvider.overrideWith((ref) async => const []),
    ],
  );
  final sub = container.listen(provider, (_, _) {});
  addTearDown(sub.close);
  await pumpEventQueue();
  states.add(progressState([progressLearn(1, 'Mishnah Peah 1:1')]));
  await pumpEventQueue();
  final first = sub.read().value;
  states.add(
    progressState([
      progressLearn(1, 'Mishnah Peah 1:1'),
      progressLearn(2, 'Mishnah Peah 1:2', minutes: 1),
    ]),
  );
  await pumpEventQueue();
  return (first, sub.read().value);
}

void main() {
  test('curriculumProgress', () async {
    final (a, b) = await _twoStates(curriculumProgressProvider('mishnayos'));
    expect(a!.hierarchyLevels.first.completedItems, 1);
    expect(b!.hierarchyLevels.first.completedItems, 2);
  });

  test('itemsLearnedData', () async {
    final (a, b) = await _twoStates(
      itemsLearnedDataProvider(CurriculumId.mishnayos),
    );
    expect(a!.learnedLeafCount, 1);
    expect(b!.learnedLeafCount, 2);
  });

  test('progressOverviewStats', () async {
    final (a, b) = await _twoStates(progressOverviewStatsProvider);
    expect(a!.totalUniqueItems, 1);
    expect(b!.totalUniqueItems, 2);
  });

  test('recent activity limudim', () async {
    final day = DateTime(2026, 9, 1);
    final (a, b) = await _twoStates(
      recentActivityLimudimChazarosProvider(
        RecentActivityWindow(startDate: day, endDate: day),
      ),
    );
    expect(a!.single.limudCount, 1);
    expect(b!.single.limudCount, 2);
  });
}
