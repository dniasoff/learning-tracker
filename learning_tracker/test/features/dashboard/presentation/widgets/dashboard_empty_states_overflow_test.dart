// Overflow guard tests for the dashboard empty-state surfaces, which centre a
// fixed pile of content vertically (mainAxisAlignment.center) and previously
// had no scroll escape valve.
//
// Each surface is rendered across the full device/text-scale matrix
// (including the small viewport × 2.0 text corner) via
// [expectNoOverflowAcrossDevices]; a RenderFlex overflow at any corner fails
// the test. The bodies are now wrapped in
// LayoutBuilder + SingleChildScrollView + ConstrainedBox(minHeight) +
// IntrinsicHeight, so they stay centred on a normal screen yet scroll instead
// of clipping on short screens / large text.
//
// Surfaces guarded:
//   • EmptyDashboard               — "no tracks yet" empty state (adult + child).
//   • SkippedOnboardingCtaBanner   — "get started" CTA banner after skipping
//                                    onboarding (with onboardingSkipState
//                                    overridden so the banner body renders).
@Tags(['dashboard', 'overflow'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/empty_dashboard.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/skipped_onboarding_cta_banner.dart';

import '../../../../helpers/overflow_harness.dart';

void main() {
  testWidgets('EmptyDashboard (adult) does not overflow across devices', (
    tester,
  ) async {
    await expectNoOverflowAcrossDevices(
      tester,
      () => const EmptyDashboard(
        name: 'Yael Goldberg',
        greeting: 'Good evening',
        isChildMode: false,
      ),
    );
  });

  testWidgets('EmptyDashboard (child) does not overflow across devices', (
    tester,
  ) async {
    await expectNoOverflowAcrossDevices(
      tester,
      () => const EmptyDashboard(
        name: 'Yael Goldberg',
        greeting: 'Good evening',
        isChildMode: true,
      ),
    );
  });

  testWidgets('SkippedOnboardingCtaBanner does not overflow across devices', (
    tester,
  ) async {
    await expectNoOverflowAcrossDevices(
      tester,
      () => const SkippedOnboardingCtaBanner(),
      overrides: [
        onboardingSkipStateProvider.overrideWith(
          (ref) async => (skipped: true, joinedToTutor: false),
        ),
      ],
    );
  });
}
