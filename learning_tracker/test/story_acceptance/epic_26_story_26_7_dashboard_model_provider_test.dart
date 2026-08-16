/// Story acceptance coverage for Story 26.7 (DNI-350) —
/// centralized onTrackChanged invalidation.
@Tags(['epic_26', 'story_26_7'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart'
    hide expect, group, setUp, tearDown, test;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/after_track_change_invalidation.dart';
import 'package:test/test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('onTrackChanged invalidates a live dashboard provider', (
    tester,
  ) async {
    var globalPointsBuilds = 0;
    final container = ProviderContainer(
      overrides: [
        dashboardGlobalPointsProvider.overrideWith((ref) async {
          globalPointsBuilds++;
          return 0;
        }),
        // onTrackChanged reads this provider after invalidating the broad
        // dashboard set. Keep that read on a deterministic, real provider
        // path rather than allowing it to reach Firebase in this test.
        dashboardActiveCurriculaProvider.overrideWith(
          (ref) async => const <CurriculumId>[],
        ),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      dashboardGlobalPointsProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    late WidgetRef capturedRef;
    await tester.pumpWidget(
      pumpApp(
        container: container,
        child: Consumer(
          builder: (context, ref, child) {
            capturedRef = ref;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();

    final buildsBeforeChange = globalPointsBuilds;
    expect(buildsBeforeChange, greaterThanOrEqualTo(1));

    await onTrackChanged(capturedRef);
    // The widget scope supplies Riverpod's Flutter vsync. Reading the
    // observed provider schedules its rebuild; the following Flutter pump
    // flushes that invalidation deterministically.
    container.read(dashboardGlobalPointsProvider);
    await tester.pump();

    expect(
      globalPointsBuilds,
      greaterThan(buildsBeforeChange),
      reason:
          'onTrackChanged must invalidate the live dashboard provider so '
          'the dashboard re-reads after a track change',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
