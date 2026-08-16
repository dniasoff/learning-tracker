/// AG-5 mirror file for [lib/features/onboarding/presentation/screens/
/// onboarding_screen.dart].
///
/// AUD-t-onboarding-04: this file previously held the pre-L1 "Slim Flow"
/// widget suite (5 testWidgets: starts-at-profileCreation, Create Profile
/// disabled with empty name, Child Mode shows ACTIVE badge, and the two
/// childAwareText cases). The L1 rewrite (onboarding_bulk_l1_test.dart)
/// replaced every one of those scenarios line-for-line and the pre-L1
/// suite was never deleted, leaving two suites to keep in sync on every
/// future OnboardingScreen change (TQ-1, Fowler duplication). 4 of the 5
/// confirmed-duplicate cases were removed; one minimal smoke test is kept
/// below so this file still exercises the widget directly, since
/// `flutter test` fails a file that declares zero tests and AG-5
/// (`tool/check_test_mirroring.dart`) requires this path to keep existing
/// as the 1:1 mirror of onboarding_screen.dart.
///
/// OnboardingScreen's full behavioral coverage lives at:
///   - onboarding_bulk_l1_test.dart — profileCreation phase, mode pills,
///     Create Profile enable/disable, ACTIVE badge, childAwareText helper,
///     auth bounce, resume-from-saved-state, intentChooser, addAnotherPrompt,
///     handoff phase, RTL smoke.
///   - onboarding_screen_l1_test.dart — parentPinSetup, intentChooser
///     transitions, profileCreation/addAnotherPrompt navigation, handoff
///     "Add Another Learner", done phase, per-phase AppBar titles,
///     kOnboardingComplete bookkeeping, RTL smoke.
/// Add new tests to whichever of those two files already owns that phase —
/// not here.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockStackRouter extends Mock implements StackRouter {}

void main() {
  late MockStackRouter mockRouter;

  setUp(() {
    mockRouter = MockStackRouter();
    when(() => mockRouter.replaceAll(any())).thenAnswer((_) async {});
    when(() => mockRouter.maybePop()).thenAnswer((_) async => true);
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        // Override authStateProvider so it doesn't hit Firebase
        authStateProvider.overrideWithValue(
          const AuthState.signedIn(
            user: AuthUser(
              uid: '01ARZ3NDEKTSV4RRFFQ69G5FAV',
              email: 'test@test.com',
              displayName: 'Test',
            ),
            tier: Tier.local,
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: StackRouterScope(
          controller: mockRouter,
          stateHash: 0,
          child: const OnboardingScreen(),
        ),
      ),
    );
  }

  testWidgets(
    'OnboardingScreen mounts without throwing (AG-5 mirror smoke test — '
    'full phase coverage lives in onboarding_bulk_l1_test.dart / '
    'onboarding_screen_l1_test.dart)',
    (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(OnboardingScreen), findsOneWidget);
    },
  );
}
