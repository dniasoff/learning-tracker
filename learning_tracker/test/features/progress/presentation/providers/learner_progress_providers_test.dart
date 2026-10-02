// Mirror test for
// `lib/features/progress/presentation/providers/learner_progress_providers.dart`
// (DNI-474: the one learner-state read every progress provider uses).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/learner_progress_providers.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/learner_state_overrides.dart';
import '../../../../helpers/learner_state/progress_fixtures.dart';
import '../../../../helpers/learner_state/provider_settle.dart';

/// Exposes [watchActiveLearnerState] as a provider.
final _probe = FutureProvider.autoDispose<LearnerState?>(
  watchActiveLearnerState,
);

void main() {
  test('resolves to the active learner state', () async {
    final state = progressState([progressLearn(1, 'Mishnah Peah 1:1')]);
    final container = ProviderContainer.test(
      overrides: progressOverrides(state),
    );
    expect(await readFuture(container, _probe.future), same(state));
  });

  test('null with no active learner', () async {
    final container = ProviderContainer.test(
      overrides: progressOverrides(null, learner: false),
    );
    expect(await readFuture(container, _probe.future), isNull);
  });

  test('stays loading while the state pages in, never partial', () async {
    final container = ProviderContainer.test(
      overrides: progressOverrides(null),
    );
    final value = await settledAsync(container, _probe);
    expect(value.isLoading, isTrue);
  });

  test("forwards the state's error", () async {
    final container = ProviderContainer.test(
      overrides: [
        ...learnerStateOverrides(scope: c0Scope()),
        learnerStateProvider.overrideWith(
          (ref, _) => Stream.error(StateError('engine')),
        ),
      ],
      retry: (_, _) => null,
    );
    final value = await settledAsync(container, _probe);
    expect(value.error, isA<StateError>());
  });

  test('progressCorpusProvider and the node-progress index', () async {
    final container = ProviderContainer.test(
      overrides: progressOverrides(
        progressState([progressLearn(1, 'Mishnah Peah 1:1')]),
      ),
    );
    final corpus = await readFuture(
      container,
      progressCorpusProvider(CurriculumId.mishnayos).future,
    );
    expect(corpus!.leaves, hasLength(9));
    expect(
      await readFuture(
        container,
        progressCorpusProvider(CurriculumId.bavli).future,
      ),
      isNull,
    );
    final index = await readFuture(
      container,
      curriculumProgressIndexProvider(CurriculumId.mishnayos).future,
    );
    expect(index!.nodeProgress('Mishnah Peah')!.state, TriState.partial);
  });
}
