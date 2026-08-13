/// R5 reactivity-contract adoption — gamification aggregates.
///
/// Drives [curriculumBreakdownProvider] (DG-BRKD-01) and
/// [achievementsOverviewProvider] through the shared `expectRebuildsOn`
/// helper (`test/helpers/reactivity_contract.dart`) instead of each growing
/// its own hand-rolled "count AsyncLoading transitions" assertion (see
/// `curriculum_breakdown_staleness_test.dart`, which stays in place
/// unmodified as a detailed regression guard). Neither provider needs real
/// completion data seeded — the contract under test is "does ticking
/// completionCommittedProvider force a re-execution at all", which
/// `expectRebuildsOn`'s build-count signal captures without a DB fixture.
@Tags(['gamification', 'riverpod', 'contract'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/points_providers.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/reactivity_contract.dart';

class _MockCompletionRepository extends Mock implements CompletionRepository {}

class _AlwaysEligible implements CurriculumRewardEligibility {
  @override
  Future<bool> isEligible(CurriculumId curriculumId) async => true;
}

class _ZeroBalance implements PointsBalanceReader, PointsLifetimeEarnedReader {
  @override
  Future<int> getBalance() async => 0;

  @override
  Future<int> getLifetimeEarned() async => 0;
}

List<Override> _overrides() {
  final repository = _MockCompletionRepository();
  when(
    () => repository.getCompletionsByCurriculum(any()),
  ).thenAnswer((_) async => const []);
  return [
    completionRepositoryProvider.overrideWithValue(repository),
    pointsServiceProvider.overrideWithValue(
      PointsService(
        eligibility: _AlwaysEligible(),
        balanceReader: _ZeroBalance(),
      ),
    ),
    rewardMilestoneServiceProvider.overrideWithValue(
      RewardMilestoneService(
        balanceReader: _ZeroBalance(),
        lifetimeEarnedReader: _ZeroBalance(),
        profileId: '01J0000000000000000000000C',
      ),
    ),
  ];
}

Future<void> _tick(ProviderContainer container) async {
  container.read(completionCommittedProvider.notifier).increment();
}

void main() {
  // achievementsOverviewProvider reads RewardMilestoneService, which is
  // backed by SharedPreferences (milestone template storage) — needs the
  // plugin mock initialized before any test touches it.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('gamification providers rebuild on completionCommittedProvider', () {
    test('curriculumBreakdownProvider (DG-BRKD-01)', () async {
      final container = ProviderContainer(overrides: _overrides());
      addTearDown(container.dispose);

      await expectRebuildsOn(
        container,
        curriculumBreakdownProvider,
        () => _tick(container),
        reason:
            'DG-BRKD-01: curriculumBreakdownProvider must watch '
            'completionCommittedProvider so the per-curriculum chips update '
            'live',
      );
    });

    test('achievementsOverviewProvider', () async {
      final container = ProviderContainer(overrides: _overrides());
      addTearDown(container.dispose);

      await expectRebuildsOn(
        container,
        achievementsOverviewProvider,
        () => _tick(container),
        reason:
            'achievementsOverviewProvider must watch '
            'completionCommittedProvider so the achievements list updates '
            'live',
      );
    });
  });
}
