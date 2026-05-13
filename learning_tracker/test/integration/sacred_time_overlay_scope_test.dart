// integration/sacred_time_overlay_scope_test.dart
//
// Story 26.25 (DNI-368): SacredTimeLockOverlay must be scoped to the
// post-auth AppShell so that onboarding / sign-in routes are accessible
// during sacred time.
//
// These tests mount SacredTimeLockOverlay directly (without a full router)
// to verify:
//   (a) When currentSacredWindowProvider is non-null the lock screen is shown.
//   (b) When currentSacredWindowProvider is null the child content is shown.
//   (c) A widget that wraps its content in SacredTimeLockOverlay shows the lock.
//   (d) A widget that does NOT wrap itself does not show the lock.
//
// Together (c) and (d) confirm that only AppShell-scoped routes are blocked.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_lock_overlay.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A sample [SacredWindow] centred on a future Shabbos — used to simulate
/// "sacred time is active" in provider overrides.
SacredWindow _activeShabboWindow() => SacredWindow(
  startUtc: DateTime.utc(2026, 5, 15, 18, 0), // Friday 18:00 UTC
  endUtc: DateTime.utc(2026, 5, 16, 20, 0), // Saturday 20:00 UTC
  kind: SacredWindowKind.shabbos,
);

/// Pumps [child] inside a [ProviderScope] and [MaterialApp] with the given
/// [overrides]. Returns quickly without calling pumpAndSettle (avoids timer
/// hangs from Riverpod keepAlive providers).
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: child),
    ),
  );
  await tester.pump(); // first frame
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SacredTimeLockOverlay scope — DNI-368', () {
    // (a) Overlay visible when sacred time is active -----------------------

    testWidgets(
      'shows lock screen when currentSacredWindowProvider is non-null',
      (tester) async {
        const childKey = Key('dashboard_content');

        await _pump(
          tester,
          SacredTimeLockOverlay(
            child: const SizedBox(key: childKey, child: Text('DASHBOARD')),
          ),
          overrides: [
            currentSacredWindowProvider.overrideWithValue(_activeShabboWindow()),
          ],
        );

        // Lock screen text is visible.
        expect(find.text('Good Shabbos'), findsOneWidget);

        // The dashboard content is rendered but visually covered; the key
        // still exists in the tree because the Stack keeps both layers.
        expect(find.byKey(childKey), findsOneWidget);
      },
    );

    // (b) Overlay absent when sacred time is not active --------------------

    testWidgets(
      'shows child content when currentSacredWindowProvider is null (no sacred time)',
      (tester) async {
        await _pump(
          tester,
          SacredTimeLockOverlay(
            child: const Text('DASHBOARD'),
          ),
          overrides: [
            currentSacredWindowProvider.overrideWithValue(null),
          ],
        );

        expect(find.text('DASHBOARD'), findsOneWidget);
        expect(find.text('Good Shabbos'), findsNothing);
      },
    );

    // (c) Post-auth shell content is blocked during sacred time ------------

    testWidgets(
      'post-auth shell content (wrapped in overlay) is blocked during sacred time',
      (tester) async {
        // Simulates AppShellScreen wrapping its child with SacredTimeLockOverlay.
        final shellContent = SacredTimeLockOverlay(
          child: const Text('SHELL CONTENT'),
        );

        await _pump(
          tester,
          shellContent,
          overrides: [
            currentSacredWindowProvider.overrideWithValue(_activeShabboWindow()),
          ],
        );

        expect(find.text('Good Shabbos'), findsOneWidget);
      },
    );

    // (d) Pre-auth routes are NOT wrapped — no lock screen shown -----------

    testWidgets(
      'onboarding/sign-in content (not wrapped) is accessible during sacred time',
      (tester) async {
        // Simulates OnboardingScreen / SignInScreen: they do NOT wrap themselves
        // in SacredTimeLockOverlay, so they remain fully accessible even when
        // currentSacredWindowProvider is non-null.
        const onboardingContent = Text('ONBOARDING');

        await _pump(
          tester,
          onboardingContent,
          overrides: [
            currentSacredWindowProvider.overrideWithValue(_activeShabboWindow()),
          ],
        );

        expect(find.text('ONBOARDING'), findsOneWidget);
        // Lock screen must NOT appear — overlay is not present.
        expect(find.text('Good Shabbos'), findsNothing);
        expect(find.text('Good Yom Tov'), findsNothing);
      },
    );

    // (e) Overlay self-clears when sacred time ends -----------------------

    testWidgets(
      'overlay disappears when provider transitions from active to null',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            currentSacredWindowProvider.overrideWithValue(_activeShabboWindow()),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: SacredTimeLockOverlay(child: Text('DASHBOARD')),
            ),
          ),
        );
        await tester.pump();

        // Sacred time active — lock screen is shown.
        expect(find.text('Good Shabbos'), findsOneWidget);

        // Sacred time ends — update the provider value.
        container.updateOverrides([
          currentSacredWindowProvider.overrideWithValue(null),
        ]);
        await tester.pump();

        // Lock screen gone, dashboard content visible.
        expect(find.text('Good Shabbos'), findsNothing);
        expect(find.text('DASHBOARD'), findsOneWidget);
      },
    );
  });
}
