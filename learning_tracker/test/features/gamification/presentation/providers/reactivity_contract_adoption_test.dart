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
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/points_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/drift_memory.dart';
import '../../../../helpers/reactivity_contract.dart';

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
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);

      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          activeProfileIdProvider.overrideWithValue(1),
        ],
      );
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
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);

      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          activeProfileIdProvider.overrideWithValue(1),
        ],
      );
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
