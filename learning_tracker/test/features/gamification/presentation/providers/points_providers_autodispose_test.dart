/// Regression test for AUD-gamification-13 (SM-6: parameterized/family
/// providers stay autoDispose).
///
/// `curriculumPointsProvider` and `pointsHistoryProvider` are both classic
/// `FutureProvider.family` declarations. Without `.autoDispose`, Riverpod
/// keeps each family member's state alive for the container's entire
/// lifetime once first read — even after the last listener unsubscribes.
/// Because `CurriculumId` is a small finite enum this is a bounded leak, but
/// it is inconsistent with SM-6 (docs/coding-standards.md) and with every
/// other family/parameterized provider in this feature.
///
/// This test drives each provider through a `ProviderContainer`, closes the
/// only subscription, lets the disposal scheduler run one event-loop tick
/// (Riverpod's autoDispose teardown is scheduled via `Timer(Duration.zero)`
/// in `ProviderScheduler`), then asserts the provider element no longer
/// exists in the container. Without `.autoDispose` this fails — the element
/// is retained forever.
@Tags(['gamification', 'riverpod', 'autodispose'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/points_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';

import '../../../../helpers/drift_memory.dart';

void main() {
  group('points_providers — SM-6 autoDispose (AUD-gamification-13)', () {
    test('curriculumPointsProvider disposes its state once the last listener '
        'unsubscribes (must be .autoDispose)', () async {
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

      final provider = curriculumPointsProvider(CurriculumId.mishnayos);

      final sub = container.listen(provider, (_, _) {});
      // Force the provider to build so it has state to dispose.
      await container.read(provider.future);
      expect(
        container.exists(provider),
        isTrue,
        reason: 'provider must exist immediately after being read',
      );

      // Remove the only listener — an autoDispose provider schedules
      // teardown for the end of the next event-loop tick.
      sub.close();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.exists(provider),
        isFalse,
        reason:
            'curriculumPointsProvider must be .autoDispose — once the '
            'last listener unsubscribes its state must be torn down, not '
            'retained for the container\'s lifetime (SM-6).',
      );
    });

    test('pointsHistoryProvider disposes its state once the last listener '
        'unsubscribes (must be .autoDispose)', () async {
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

      final provider = pointsHistoryProvider(CurriculumId.mishnayos);

      final sub = container.listen(provider, (_, _) {});
      await container.read(provider.future);
      expect(
        container.exists(provider),
        isTrue,
        reason: 'provider must exist immediately after being read',
      );

      sub.close();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.exists(provider),
        isFalse,
        reason:
            'pointsHistoryProvider must be .autoDispose — once the last '
            'listener unsubscribes its state must be torn down, not '
            'retained for the container\'s lifetime (SM-6).',
      );
    });
  });
}
