// Mirror test for
// `lib/features/progress/presentation/providers/journey_providers.dart`
// (DNI-474 AC-4: the siyumim journey comes from the engine's completed
// units; one timeline row per completion number).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/progress_fixtures.dart';
import '../../../../helpers/learner_state/provider_settle.dart';

class _UseHebrewTermsOverride extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _VariantOverride extends CurrentTransliterationVariant {
  @override
  TransliterationVariant build() => TransliterationVariant.ashkenazi;
}

ProviderContainer _container(
  LearnerState? state, {
  MilestoneLevel granularity = MilestoneLevel.unit,
  bool learner = true,
}) => ProviderContainer.test(
  overrides: [
    ...progressOverrides(state, learner: learner),
    useHebrewTermsProvider.overrideWith(_UseHebrewTermsOverride.new),
    currentTransliterationVariantProvider.overrideWith(_VariantOverride.new),
    activeCurriculaProvider.overrideWith(
      (ref) async => const [CurriculumId.mishnayos],
    ),
    curriculumContentProvider(
      CurriculumId.mishnayos,
    ).overrideWith((ref) async => progressContent()),
    siyumGranularityProvider(
      CurriculumId.mishnayos,
    ).overrideWithValue(granularity),
  ],
);

List<LearningEvent> _wholeMishnayos() => [
  progressGround(1, 'Seder Zeraim', 'seder', minutes: 1),
  progressGround(2, 'Seder Moed', 'seder', minutes: 2),
];

void main() {
  test('JourneySortModeValue toggles between grouped and chronological', () {
    final container = ProviderContainer.test();
    expect(
      container.read(journeySortModeProvider),
      JourneySortModeValue.grouped,
    );
    container.read(journeySortModeProvider.notifier).toggle();
    expect(
      container.read(journeySortModeProvider),
      JourneySortModeValue.chronological,
    );
  });

  group('journeyViewModel', () {
    test('no completed unit: zero milestones at every level', () async {
      final vm = await readFuture(
        _container(progressState([progressLearn(1, 'Mishnah Peah 1:1')])),
        journeyViewModelProvider.future,
      );
      expect(vm.unitLevelSiyumimCount, 0);
      expect(vm.aggregateLevelSiyumimCount, 0);
      expect(vm.curriculumLevelSiyumimCount, 0);
      expect(vm.curricula.single.totalUnitsAvailable, 3);
    });

    test('a masechta completed live is one unit-level siyum dated at the '
        'completing event', () async {
      final vm = await readFuture(
        _container(
          progressState([
            progressLearn(1, 'Mishnah Peah 1:1', minutes: 1),
            progressLearn(2, 'Mishnah Peah 1:2', minutes: 2),
          ]),
        ),
        journeyViewModelProvider.future,
      );
      expect(vm.unitLevelSiyumimCount, 1);
      final milestone = vm.curricula.single.milestones.single;
      expect(milestone.unitKey, 'Mishnah Peah');
      expect(milestone.achievedAt, engineAt(2));
      expect(vm.totalCompletions, 1);
      expect(vm.curricula.single.uniqueUnitsCompleted, 1);
    });

    test('the whole curriculum: 3 unit, 2 aggregate and 1 curriculum '
        'siyumim', () async {
      final vm = await readFuture(
        _container(progressState(_wholeMishnayos())),
        journeyViewModelProvider.future,
      );
      expect(vm.unitLevelSiyumimCount, 3);
      expect(vm.aggregateLevelSiyumimCount, 2);
      expect(vm.curriculumLevelSiyumimCount, 1);
    });

    test('a second full completion is a second timeline row (k = 2) but not '
        'a second counted siyum', () async {
      final vm = await readFuture(
        _container(
          progressState([
            progressLearn(1, 'Mishnah Peah 1:1', minutes: 1),
            progressLearn(2, 'Mishnah Peah 1:2', minutes: 2),
            progressLearn(3, 'Mishnah Peah 1:1', minutes: 3),
            progressLearn(4, 'Mishnah Peah 1:2', minutes: 4),
          ]),
        ),
        journeyViewModelProvider.future,
      );
      expect(vm.curricula.single.milestones.map((m) => m.completionNumber), [
        2,
        1,
      ]);
      expect(vm.unitLevelSiyumimCount, 1);
    });

    test('a void that breaks the unit removes its siyum', () async {
      final vm = await readFuture(
        _container(
          progressState([
            progressLearn(1, 'Mishnah Peah 1:1', minutes: 1),
            progressLearn(2, 'Mishnah Peah 1:2', minutes: 2),
            engineVoid(3, 2, minutes: 3),
          ]),
        ),
        journeyViewModelProvider.future,
      );
      expect(vm.curricula.single.milestones, isEmpty);
    });

    test('granularity = aggregate hides unit siyumim', () async {
      final vm = await readFuture(
        _container(
          progressState(_wholeMishnayos()),
          granularity: MilestoneLevel.aggregate,
        ),
        journeyViewModelProvider.future,
      );
      expect(vm.unitLevelSiyumimCount, 0);
      expect(vm.aggregateLevelSiyumimCount, 2);
      expect(vm.curriculumLevelSiyumimCount, 1);
    });

    test('granularity = curriculum keeps only the whole siyum', () async {
      final vm = await readFuture(
        _container(
          progressState(_wholeMishnayos()),
          granularity: MilestoneLevel.curriculum,
        ),
        journeyViewModelProvider.future,
      );
      expect(
        (
          vm.unitLevelSiyumimCount,
          vm.aggregateLevelSiyumimCount,
          vm.curriculumLevelSiyumimCount,
        ),
        (0, 0, 1),
      );
    });

    test('no active learner fails loudly', () async {
      final value = await settledAsync(
        _container(null, learner: false),
        journeyViewModelProvider,
      );
      expect(value.error, isA<JourneyNoActiveProfileException>());
    });
  });

  test('availableSiyumTiers offers the aggregate tier for a multi-seder '
      'Mishnayos', () async {
    final tiers = await readFuture(
      _container(progressState(const [])),
      availableSiyumTiersProvider(CurriculumId.mishnayos).future,
    );
    expect(tiers, [
      MilestoneLevel.unit,
      MilestoneLevel.aggregate,
      MilestoneLevel.curriculum,
    ]);
  });
}
