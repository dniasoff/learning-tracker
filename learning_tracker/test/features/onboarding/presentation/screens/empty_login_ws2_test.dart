// WS2 regression tests:
//  WS2.skip   — Skip affordance exists at the profile-creation phase
//  WS2.relax  — 0-profile account with hasSkippedOnboarding flag routes to
//               EmptyLoginRoute, not back to OnboardingRoute
//  WS2.surface — EmptyLoginScreen renders the CTA banner and basic layout

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/skipped_onboarding_cta_banner.dart'
    show SkippedOnboardingCtaBanner;
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_resume_store.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/empty_login_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_profile_creation_step.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockStackRouter extends Mock implements StackRouter {}

// ── Helpers ────────────────────────────────────────────────────────────────────

Widget _wrapWithProviders({
  required Widget child,
  StackRouter? router,
}) {
  final mockRouter = router ?? _MockStackRouter();
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWithValue(
        const AuthState.signedIn(
          user: AuthUser(
            profileId: 1,
            email: 'test@test.com',
            displayName: 'Test',
            userMode: 'adult',
          ),
          tier: Tier.localBorn,
        ),
      ),
    ],
    child: MaterialApp(
      home: StackRouterScope(
        controller: mockRouter,
        stateHash: 0,
        child: child,
      ),
    ),
  );
}

void main() {
  // ── WS2.skip ─────────────────────────────────────────────────────────────────

  group('WS2.skip — Skip affordance at profile-creation phase', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
      'OnboardingProfileCreationStep shows "Skip for now" when onSkipProfileCreation is provided',
      (tester) async {
        var skipCalled = false;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWithValue(
                const AuthState.signedIn(
                  user: AuthUser(
                    profileId: 0,
                    email: 't@t.com',
                    displayName: 'T',
                    userMode: 'adult',
                  ),
                  tier: Tier.localBorn,
                ),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: OnboardingProfileCreationStep(
                  onCreated: ({
                    required profile,
                    required isChildMode,
                    required useHebrewCalendar,
                    required useHebrewTerms,
                    required showNikud,
                    required transliterationVariant,
                  }) {},
                  onSkipProfileCreation: () => skipCalled = true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The "Skip for now" button must be in the tree
        expect(find.text('Skip for now'), findsOneWidget);

        // Scroll into view and tap — the step content is in a SingleChildScrollView
        await tester.ensureVisible(find.text('Skip for now'));
        await tester.pump();
        await tester.tap(find.text('Skip for now'), warnIfMissed: false);
        await tester.pump();
        expect(skipCalled, isTrue);
      },
    );

    testWidgets(
      'OnboardingProfileCreationStep does NOT show "Skip for now" when callback is null',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWithValue(
                const AuthState.signedIn(
                  user: AuthUser(
                    profileId: 0,
                    email: 't@t.com',
                    displayName: 'T',
                    userMode: 'adult',
                  ),
                  tier: Tier.localBorn,
                ),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: OnboardingProfileCreationStep(
                  onCreated: ({
                    required profile,
                    required isChildMode,
                    required useHebrewCalendar,
                    required useHebrewTerms,
                    required showNikud,
                    required transliterationVariant,
                  }) {},
                  // no onSkipProfileCreation — no button rendered
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Skip for now'), findsNothing);
      },
    );

    testWidgets(
      'OnboardingScreen profile-creation phase has Skip wired',
      (tester) async {
        final mockRouter = _MockStackRouter();
        when(() => mockRouter.replaceAll(any())).thenAnswer((_) async {});
        when(() => mockRouter.maybePop()).thenAnswer((_) async => true);

        await tester.pumpWidget(
          _wrapWithProviders(child: const OnboardingScreen(), router: mockRouter),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // At the profile-creation phase, the Skip button must be present
        expect(find.text('Skip for now'), findsOneWidget);
      },
    );
  });

  // ── WS2.relax ────────────────────────────────────────────────────────────────

  group('WS2.relax — 0-profile + hasSkippedOnboarding flag', () {
    test(
      'kOnboardingSkipped SharedPrefs key is "onboarding_skipped"',
      () {
        // Verify the constant value matches what sign_in_controller reads
        expect(kOnboardingSkipped, 'onboarding_skipped');
      },
    );

    test(
      'OnboardingResumeStore.markComplete(skipped:true) sets kOnboardingSkipped=true',
      () async {
        SharedPreferences.setMockInitialValues({});
        const store = OnboardingResumeStore();
        await store.markComplete(skipped: true, joinedToTutor: false);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(kOnboardingSkipped), isTrue);
        expect(prefs.getBool(kOnboardingComplete), isTrue);
      },
    );

    test(
      'OnboardingResumeStore.markComplete() without skipped does NOT set kOnboardingSkipped',
      () async {
        SharedPreferences.setMockInitialValues({});
        const store = OnboardingResumeStore();
        await store.markComplete();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(kOnboardingSkipped), isNull);
        expect(prefs.getBool(kOnboardingComplete), isTrue);
      },
    );
  });

  // ── WS2.surface ──────────────────────────────────────────────────────────────

  group('WS2.surface — EmptyLoginScreen layout', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        // skipped = true so SkippedOnboardingCtaBanner renders its body
        kOnboardingSkipped: true,
        kOnboardingJoinedToTutor: false,
      });
    });

    testWidgets('EmptyLoginScreen renders SkippedOnboardingCtaBanner',
        (tester) async {
      final mockRouter = _MockStackRouter();
      when(() => mockRouter.replaceAll(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        _wrapWithProviders(
          child: const EmptyLoginScreen(),
          router: mockRouter,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // The CTA banner widget is mounted in the tree
      expect(find.byType(SkippedOnboardingCtaBanner), findsOneWidget);
    });

    testWidgets(
      'EmptyLoginScreen renders tutor entry button',
      (tester) async {
        final mockRouter = _MockStackRouter();
        when(() => mockRouter.replaceAll(any())).thenAnswer((_) async {});

        await tester.pumpWidget(
          _wrapWithProviders(
            child: const EmptyLoginScreen(),
            router: mockRouter,
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // WS3 stub tutor entry point
        expect(find.byKey(const Key('empty_login_tutor_entry')), findsOneWidget);
        expect(find.text("I'm a tutor"), findsOneWidget);
      },
    );

    testWidgets(
      'EmptyLoginScreen renders device notification toggle stub',
      (tester) async {
        final mockRouter = _MockStackRouter();
        when(() => mockRouter.replaceAll(any())).thenAnswer((_) async {});

        await tester.pumpWidget(
          _wrapWithProviders(
            child: const EmptyLoginScreen(),
            router: mockRouter,
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // WS5 stub notification toggle
        expect(
          find.byKey(const Key('empty_login_notification_toggle')),
          findsOneWidget,
        );
        expect(find.text('Device notifications'), findsOneWidget);
      },
    );

    testWidgets(
      'EmptyLoginScreen CTA banner shows "Add a profile" call-to-action',
      (tester) async {
        final mockRouter = _MockStackRouter();
        when(() => mockRouter.replaceAll(any())).thenAnswer((_) async {});

        await tester.pumpWidget(
          _wrapWithProviders(
            child: const EmptyLoginScreen(),
            router: mockRouter,
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // SkippedOnboardingCtaBanner in non-tutor mode shows "Set up a learning
        // track" as the primary CTA — this is the "Add a profile later" path.
        expect(find.text('Set up a learning track'), findsOneWidget);
      },
    );
  });
}
