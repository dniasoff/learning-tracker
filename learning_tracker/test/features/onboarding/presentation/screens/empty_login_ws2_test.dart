// WS2 regression tests:
//  WS2.skip   — Skip affordance exists at the profile-creation phase
//  WS2.relax  — 0-profile account with hasSkippedOnboarding flag routes to
//               EmptyLoginRoute, not back to OnboardingRoute
//  WS2.surface — EmptyLoginScreen renders the CTA banner and basic layout

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/skipped_onboarding_cta_banner.dart'
    show SkippedOnboardingCtaBanner;
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_resume_store.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/empty_login_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_profile_creation_step.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockStackRouter extends Mock implements StackRouter {}

// Stub gateway so DeviceNotificationToggle doesn't crash in tests — WS5 added
// hasPermission() which hits the uninitialized platform plugin in test env.
class _StubNotificationGateway extends Mock implements NotificationGateway {
  @override
  Future<bool> hasPermission() async => false;
}

// ── Helpers ────────────────────────────────────────────────────────────────────

Widget _wrapWithProviders({
  required Widget child,
  StackRouter? router,
  Locale locale = const Locale('en'),
}) {
  final mockRouter = router ?? _MockStackRouter();
  return ProviderScope(
    overrides: [
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
      // Override notificationServiceProvider so DeviceNotificationToggle
      // (added by WS5) doesn't crash when hasPermission() hits the
      // uninitialized FlutterLocalNotifications platform plugin in tests.
      notificationServiceProvider.overrideWithValue(_StubNotificationGateway()),
    ],
    child: MaterialApp(
      locale: locale,
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
          _wrapWithProviders(
            child: Scaffold(
              body: OnboardingProfileCreationStep(
                onCreated:
                    ({
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
          _wrapWithProviders(
            child: Scaffold(
              body: OnboardingProfileCreationStep(
                onCreated:
                    ({
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
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Skip for now'), findsNothing);
      },
    );

    testWidgets('OnboardingScreen profile-creation phase has Skip wired', (
      tester,
    ) async {
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
    });
  });

  // ── WS2.relax ────────────────────────────────────────────────────────────────

  group('WS2.relax — 0-profile + hasSkippedOnboarding flag', () {
    test('kOnboardingSkipped SharedPrefs key is "onboarding_skipped"', () {
      // Verify the constant value matches what sign_in_controller reads
      expect(kOnboardingSkipped, 'onboarding_skipped');
    });

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

    testWidgets('EmptyLoginScreen renders SkippedOnboardingCtaBanner', (
      tester,
    ) async {
      final mockRouter = _MockStackRouter();
      when(() => mockRouter.replaceAll(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        _wrapWithProviders(child: const EmptyLoginScreen(), router: mockRouter),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // The CTA banner widget is mounted in the tree
      expect(find.byType(SkippedOnboardingCtaBanner), findsOneWidget);
    });

    testWidgets('EmptyLoginScreen renders tutor entry button', (tester) async {
      final mockRouter = _MockStackRouter();
      when(() => mockRouter.replaceAll(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        _wrapWithProviders(child: const EmptyLoginScreen(), router: mockRouter),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // WS3 stub tutor entry point
      expect(find.byKey(const Key('empty_login_tutor_entry')), findsOneWidget);
      expect(find.text("I'm a tutor"), findsOneWidget);
    });

    testWidgets(
      'EmptyLoginScreen does NOT render a device notification toggle',
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

        // The device-notification toggle was removed from this landing surface:
        // OS notification permission is now requested up front in the first-run
        // intro flow (AppIntroScreen) and managed afterwards under
        // Settings → Notification Settings. It must not appear here.
        expect(
          find.byKey(const Key('device_notification_toggle')),
          findsNothing,
        );
        expect(find.text('Device notifications'), findsNothing);
      },
    );

    testWidgets(
      'EmptyLoginScreen CTA banner shows "Add a learning track" call-to-action',
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

        // SkippedOnboardingCtaBanner (non-tutor) shows a single primary CTA,
        // "Add a learning track". The separate "Accept a tutor invite" button
        // was removed from the banner; tutor entry is the dedicated "I'm a
        // tutor" button on EmptyLoginScreen (tested above).
        expect(find.text('Add a learning track'), findsOneWidget);
      },
    );

    testWidgets(
      'CTA banner is localized in Hebrew — no hardcoded English leak (D-l10n)',
      (tester) async {
        final mockRouter = _MockStackRouter();
        when(() => mockRouter.replaceAll(any())).thenAnswer((_) async {});

        await tester.pumpWidget(
          _wrapWithProviders(
            child: const EmptyLoginScreen(),
            router: mockRouter,
            locale: const Locale('he'),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // The Hebrew CTA renders; the old hardcoded English must NOT leak.
        expect(find.text('הוסיפו מסלול לימוד'), findsOneWidget);
        expect(find.text('בואו נתחיל'), findsWidgets);
        expect(find.text('Add a learning track'), findsNothing);
      },
    );
  });
}
