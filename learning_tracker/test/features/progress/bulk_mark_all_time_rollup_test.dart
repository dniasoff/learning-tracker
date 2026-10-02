/// Run-8 P2 regression guard, ported to the engine (DNI-474): before-
/// tracking marks roll up into the Lifetime Knowledge header exactly as into
/// the body, and stay out of the dated activity charts (they have no day).
@Tags(['progress'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';

import '../../helpers/learner_state/progress_fixtures.dart';

void main() {
  final state = progressState([
    progressGround(1, 'Mishnah Peah', 'masechta'),
    progressLearn(2, 'Mishnah Berakhot 1:1', minutes: 1),
  ]);

  test('header itemsLearned equals the body learned count, before-tracking '
      'marks included', () async {
    final container = ProviderContainer.test(
      overrides: progressOverrides(state),
    );
    final body = await readFuture(
      container,
      lifetimeViewDataProvider(CurriculumId.mishnayos).future,
    );
    final header = await readFuture(
      container,
      lifetimeHeaderCountersProvider.future,
    );

    expect(body?.learnedLeafCount, 3);
    expect(header.itemsLearned, body?.learnedLeafCount);
  });

  test('the dated activity feed leaves before-tracking marks out', () {
    final points = const ChartDataService().getCumulativeProgress(
      state,
      startDate: DateTime(2026, 8, 25),
      endDate: DateTime(2026, 9, 1),
      corpusFor: (_) => progressCorpus(),
    );
    expect(points.last.total, 1);
  });
}
