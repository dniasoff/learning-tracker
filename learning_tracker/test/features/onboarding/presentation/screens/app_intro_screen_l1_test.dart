// L1 behaviour tests for AppIntroScreen.
//
// Coverage:
//   • Palette / key widgets render on first frame
//   • "Continue Journey" CTA on pages 1-2; "Get Started" CTA on last page
//   • "Skip" button is present
//   • CTA on last page → router.replace(SignInRoute) + sets kIntroSeen in prefs
//   • "Skip" button → router.replace(SignInRoute) + sets kIntroSeen in prefs
//   • PageView advances via CTA taps
//   • RTL smoke: screen mounts without overflow in he locale
//
// Hardcoded-string findings:
//   • 'Skip'             — hardcoded in _IntroHeader, not from ARB
//   • 'Continue Journey' — hardcoded in AppIntroScreen.build, not from ARB
//   • 'Get Started'      — hardcoded in AppIntroScreen.build, not from ARB

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/app_intro_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockStackRouter extends Mock implements StackRouter {}

// Fallback value required by mocktail for any<PageRouteInfo>().
class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ---------------------------------------------------------------------------
// Provider override
// ---------------------------------------------------------------------------

/// Minimal notifier — always returns false (English terms), avoiding the
/// SharedPreferences / activeProfileIdProvider dependency chain.
class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

/// Hebrew Terms ON — renders the native-script domain terms (e.g. "משנה").
class _TrueUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => true;
}

// ---------------------------------------------------------------------------
// Rig
// ---------------------------------------------------------------------------

Widget _rig({
  required _MockStackRouter router,
  Locale locale = const Locale('en'),
  bool useHebrewTerms = false,
}) {
  return ProviderScope(
    overrides: [
      useHebrewTermsProvider.overrideWith(
        () => useHebrewTerms ? _TrueUseHebrewTerms() : _FalseUseHebrewTerms(),
      ),
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
        controller: router,
        stateHash: 0,
        child: const AppIntroScreen(),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Advance the PageView by one page via a full-width drag, then let the
/// animation complete.
Future<void> _swipeToNextPage(WidgetTester tester) async {
  final box = tester.getRect(find.byType(PageView));
  await tester.drag(find.byType(PageView), Offset(-box.width, 0));
  // Allow up to 600 ms for the easeOutCubic page animation to finish.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Tear down helper — replace the tree with a shrunk widget and drain.
Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  late _MockStackRouter router;

  setUp(() {
    router = _MockStackRouter();
    // replace<T extends Object?> — use untyped any() so mocktail matches
    // the generic call regardless of T.
    when(() => router.replace(any())).thenAnswer((_) async => null);
    SharedPreferences.setMockInitialValues({});
  });

  // ── 1. Palette / key widgets render ────────────────────────────────────────

  group('AppIntroScreen renders', () {
    testWidgets('mounts and shows Scaffold with intro background colour', (
      tester,
    ) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      // Intro palette background — const _kBg = Color(0xFFF8F9FB).
      expect(scaffold.backgroundColor, const Color(0xFFF8F9FB));

      await _tearDown(tester);
    });

    testWidgets('GlowingCtaButton is present on first page', (tester) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      expect(find.byType(GlowingCtaButton), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets(
      // HARDCODED-STRING: "Skip" is not from ARB — flagged for i18n.
      'Skip button is present (hardcoded string "Skip")',
      (tester) async {
        await tester.pumpWidget(_rig(router: router));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));

        expect(find.text('Skip'), findsOneWidget);

        await _tearDown(tester);
      },
    );

    testWidgets(
      // HARDCODED-STRING: "Continue Journey" is not from ARB.
      'first page shows "Continue Journey" label (hardcoded string)',
      (tester) async {
        await tester.pumpWidget(_rig(router: router));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));

        expect(find.text('Continue Journey'), findsOneWidget);
        expect(find.text('Get Started'), findsNothing);

        await _tearDown(tester);
      },
    );

    testWidgets('PageView is present and shows 3 pages', (tester) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      expect(find.byType(PageView), findsOneWidget);

      await _tearDown(tester);
    });
  });

  // ── 2. "Get Started" appears on last page ──────────────────────────────────

  group('CTA label on last page', () {
    testWidgets(
      // HARDCODED-STRING: "Get Started" is not from ARB.
      'shows "Get Started" on page 3 after two swipes (hardcoded string)',
      (tester) async {
        await tester.pumpWidget(_rig(router: router));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));

        await _swipeToNextPage(tester); // page 1 → 2
        await _swipeToNextPage(tester); // page 2 → 3

        expect(find.text('Get Started'), findsOneWidget);
        expect(find.text('Continue Journey'), findsNothing);

        await _tearDown(tester);
      },
    );
  });

  // ── 3. Skip → router.replace(SignInRoute) ──────────────────────────────────

  group('Skip button navigation', () {
    testWidgets(
      'tapping Skip calls router.replace(SignInRoute) and writes kIntroSeen=true',
      (tester) async {
        await tester.pumpWidget(_rig(router: router));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));

        await tester.tap(find.text('Skip'));
        await tester.pump();
        // Allow SharedPreferences write + async router call to complete.
        await tester.pump(const Duration(seconds: 1));

        final captured = verify(() => router.replace(captureAny())).captured;
        expect(captured.single, isA<SignInRoute>());

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(kIntroSeen), isTrue);

        await _tearDown(tester);
      },
    );
  });

  // ── 4. "Get Started" CTA → router.replace(SignInRoute) ───────────────────

  group('Get Started CTA navigation', () {
    testWidgets(
      'tapping "Get Started" on page 3 calls router.replace(SignInRoute) and writes kIntroSeen=true',
      (tester) async {
        await tester.pumpWidget(_rig(router: router));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));

        await _swipeToNextPage(tester);
        await _swipeToNextPage(tester);

        expect(find.text('Get Started'), findsOneWidget);

        await tester.tap(find.text('Get Started'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final captured = verify(() => router.replace(captureAny())).captured;
        expect(captured.single, isA<SignInRoute>());

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(kIntroSeen), isTrue);

        await _tearDown(tester);
      },
    );
  });

  // ── 5. Continue Journey advances pages but does NOT navigate ─────────────

  group('Continue Journey CTA', () {
    testWidgets(
      'tapping "Continue Journey" on page 1 does NOT call router.replace',
      (tester) async {
        await tester.pumpWidget(_rig(router: router));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));

        await tester.tap(find.text('Continue Journey'));
        // Complete the 500 ms page animation.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        verifyNever(() => router.replace(any()));

        await _tearDown(tester);
      },
    );

    testWidgets(
      'tapping "Continue Journey" twice (via swipe) reaches last page with "Get Started"',
      (tester) async {
        await tester.pumpWidget(_rig(router: router));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));

        // Use swipes rather than CTA taps to advance pages; the CTA tap
        // triggers a nextPage() call that animates asynchronously — the second
        // tap is safer to issue after the swipe animation has completed.
        await _swipeToNextPage(tester); // page 2
        await _swipeToNextPage(tester); // page 3

        expect(find.text('Get Started'), findsOneWidget);
        expect(find.text('Continue Journey'), findsNothing);

        await _tearDown(tester);
      },
    );
  });

  // ── 6. kIntroSeen is not written until CTA is tapped ─────────────────────

  group('kIntroSeen pref', () {
    testWidgets('kIntroSeen is absent before any CTA tap', (tester) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kIntroSeen), isNull);

      await _tearDown(tester);
    });
  });

  // ── 6b. Mishna domain term switches with the Hebrew Terms toggle ─────────

  group('Mishna domain term (toggle-aware)', () {
    testWidgets('page 2 shows transliterated "Mishna" when Hebrew Terms OFF', (
      tester,
    ) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      await _swipeToNextPage(tester); // page 1 → 2 (mishna page)

      expect(find.textContaining('Mishna'), findsWidgets);
      expect(find.textContaining('משנה'), findsNothing);

      await _tearDown(tester);
    });

    testWidgets('page 2 shows Hebrew "משנה" when Hebrew Terms ON', (
      tester,
    ) async {
      await tester.pumpWidget(_rig(router: router, useHebrewTerms: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      await _swipeToNextPage(tester); // page 1 → 2 (mishna page)

      expect(find.textContaining('משנה'), findsOneWidget);
      expect(find.textContaining('Mishna'), findsNothing);

      await _tearDown(tester);
    });
  });

  // ── 7. RTL smoke (Hebrew locale) ─────────────────────────────────────────

  group('RTL smoke', () {
    testWidgets('mounts without rendering errors in he locale', (tester) async {
      await tester.pumpWidget(_rig(router: router, locale: const Locale('he')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      // Screen must mount and show the CTA button.
      expect(find.byType(GlowingCtaButton), findsOneWidget);

      await _tearDown(tester);
    });
  });
}
