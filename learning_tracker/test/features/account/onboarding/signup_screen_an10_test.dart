// Regression test for AN-10:
// Create Account form left-anchored on tablet; form does not center on wide viewports.
//
// Root cause: SignupScreen rendered the card ConstrainedBox(maxWidth: 430) inside
// a Column with default crossAxisAlignment, pinning it to the start (left) edge.
//
// Fix: wrapped the ConstrainedBox in Center() so on wide viewports the card
// is centered horizontally.
//
// Test strategy (AUD-t-account-01 / TQ-8): pump the REAL SignupScreen — not a
// hand-rolled structural replica — at a tablet-width viewport and assert on
// the actual rendered ConstrainedBox(maxWidth: 430) card. This pins real
// source behavior: removing the Center(...) wrapper, or removing/changing
// BoxConstraints(maxWidth: 430), in
// lib/features/account/onboarding/presentation/screens/signup_screen.dart
// must fail this test.
//
// A prior version of this file asserted against two hand-defined lookalike
// widgets (_CenteredCardLayout / _LeftAnchoredCardLayout) that never imported
// signup_screen.dart, so no edit to the real screen could ever fail the
// test. Those stand-ins are deleted per AUD-t-account-01's recommendation;
// this file now renders the production widget directly, wired the same way
// as test/features/account/onboarding/presentation/screens/signup_screen_l1_test.dart.

@Tags(['account', 'signup', 'an10'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/features/account/onboarding/presentation/screens/signup_screen.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_repositories.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Builds the real [SignupScreen], wired the same way as the L1 suite in
/// signup_screen_l1_test.dart, so this test exercises actual production
/// layout rather than a structural replica.
Widget _buildRealSignupScreen() {
  final router = _MockStackRouter();
  final authRepo = MockAuthRepository();

  when(() => router.replace(any())).thenAnswer((_) async => null);
  when(
    () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
  ).thenAnswer((_) async => null);
  when(() => router.replaceAll(any())).thenAnswer((_) async => []);
  when(() => router.canPop()).thenReturn(false);
  when(() => authRepo.currentUser).thenReturn(null);

  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepo),
      connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: const Scaffold(body: SignupScreen()),
      ),
    ),
  );
}

/// Locates the AN-10 card by its actual layout constraint — the
/// ConstrainedBox(maxWidth: 430) that wraps the signup form card in
/// signup_screen.dart — rather than a test-only Key, so the finder stays
/// pinned to what the real widget renders. (The screen's other
/// ConstrainedBox, further up the tree, caps minHeight and has an unbounded
/// maxWidth, so this predicate cannot ambiguously match it.)
final _card430Finder = find.byWidgetPredicate(
  (widget) => widget is ConstrainedBox && widget.constraints.maxWidth == 430,
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
    registerFallbackValue(const SignInRoute());
    registerFallbackValue(const OnboardingRoute());
  });

  group('AN-10 regression — real SignupScreen centered on tablet', () {
    testWidgets('AN-10: real SignupScreen card is capped at maxWidth 430 and '
        'centered on a wide (tablet) viewport', (tester) async {
      // 810x1080 logical pixels at devicePixelRatio 2.0 — a tablet-class
      // wide viewport, matching the AN-10 bug report's reproduction size.
      tester.view.physicalSize = const Size(810 * 2, 1080 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildRealSignupScreen());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        _card430Finder,
        findsOneWidget,
        reason:
            'AN-10: expected exactly one ConstrainedBox(maxWidth: 430) in '
            'the real SignupScreen tree — if this fails, the '
            'maxWidth: 430 card constraint was changed or removed from '
            'signup_screen.dart',
      );

      final cardRect = tester.getRect(_card430Finder);
      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;

      // Card must be capped at 430px (not stretched to full screen width).
      expect(
        cardRect.width,
        closeTo(430, 5),
        reason: 'AN-10: card must be capped at maxWidth 430',
      );

      // And it must be centered horizontally — this is the assertion that
      // fails if the Center(...) wrapper around the card is removed: an
      // uncentered ConstrainedBox(maxWidth: 430) inside signup_screen.dart's
      // Column is left-anchored, not centered, on a wide viewport.
      final expectedLeft = (screenWidth - cardRect.width) / 2;
      expect(
        cardRect.left,
        closeTo(expectedLeft, 10),
        reason:
            'AN-10: card must be centered on wide viewport '
            '(left=${cardRect.left}, expectedLeft=$expectedLeft)',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
