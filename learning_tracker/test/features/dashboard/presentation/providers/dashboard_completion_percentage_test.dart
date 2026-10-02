// dashboardTrackCompletionPercentage / dashboardCompletionPercentage over
// the engine (DNI-474): goal progress is the distinct learnt count (FR-14)
// over the learner's scoped leaves — repeats and chazara count once, every
// source and date state counts, and learning in one curriculum never counts
// for another.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/progress_fixtures.dart';

ProviderContainer _container(LearnerState state, {int scoped = 9}) =>
    ProviderContainer.test(
      overrides: [
        ...progressOverrides(state),
        scopedItemCountProvider.overrideWith((ref, c) async => scoped),
      ],
    );

void main() {
  final learnt = progressState([
    progressLearn(1, 'Mishnah Peah 1:1'),
    progressLearn(2, 'Mishnah Peah 1:1', minutes: 1, stage: 2),
    progressLearn(3, 'Mishnah Peah 1:1', minutes: 2),
    progressGround(4, 'Mishnah Shabbat', 'masechta', minutes: 3),
  ]);

  for (final (name, read) in [
    (
      'dashboardTrackCompletionPercentage',
      (ProviderContainer c, CurriculumId id) =>
          readFuture(c, dashboardTrackCompletionPercentageProvider(id).future),
    ),
    (
      'dashboardCompletionPercentage',
      (ProviderContainer c, CurriculumId id) =>
          readFuture(c, dashboardCompletionPercentageProvider(id).future),
    ),
  ]) {
    group(name, () {
      test('is 0 with no learning', () async {
        expect(
          await read(
            _container(progressState(const [])),
            CurriculumId.mishnayos,
          ),
          0,
        );
      });

      test('is 0 when the scope has no items', () async {
        expect(
          await read(_container(learnt, scoped: 0), CurriculumId.mishnayos),
          0,
        );
      });

      test('counts distinct learnt leaves: repeats and chazara once, '
          'before-tracking included', () async {
        expect(
          await read(_container(learnt), CurriculumId.mishnayos),
          closeTo(3 / 9, 1e-9),
        );
      });

      test('learning in one curriculum is not counted for another', () async {
        expect(await read(_container(learnt), CurriculumId.bavli), 0);
      });
    });
  }

  test('dashboardLastCompletion is the latest counted learn', () async {
    final at = await readFuture(
      _container(
        progressState([
          ...[
            progressLearn(1, 'Mishnah Peah 1:1', minutes: 1),
            progressLearn(2, 'Mishnah Peah 1:2', minutes: 5),
          ],
          engineVoid(3, 2, minutes: 6),
        ]),
      ),
      dashboardLastCompletionProvider(CurriculumId.mishnayos).future,
    );
    expect(at, engineAt(1));
  });
}
