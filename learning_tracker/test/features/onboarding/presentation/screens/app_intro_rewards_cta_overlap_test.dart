// Layout regression test for the rewards intro page ("Earn While You Learn").
//
// Bug (vision sweep): the pinned bottom "Get Started" CTA overlapped the
// reward cards (Badge Collection / Mystery Prizes + the scholar-level card)
// the page is selling. The fix reserves bottom scroll inset so that, once the
// page is scrolled to the end, every reward card clears the overlaid CTA.
//
// This test scrolls the rewards page to its maximum extent and asserts that
// neither IntroFeatureCardsRow nor IntroScholarLevelCard vertically overlaps
// the GlowingCtaButton.

@Tags(['l1', 'onboarding', 'intro', 'layout'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/app_intro_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

Widget _rig(_MockStackRouter router) {
  return ProviderScope(
    overrides: [
      useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
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
        controller: router,
        stateHash: 0,
        child: const AppIntroScreen(),
      ),
    ),
  );
}

Future<void> _swipeToNextPage(WidgetTester tester) async {
  final box = tester.getRect(find.byType(PageView));
  await tester.drag(find.byType(PageView), Offset(-box.width, 0));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  late _MockStackRouter router;

  setUp(() {
    router = _MockStackRouter();
    when(() => router.replace(any())).thenAnswer((_) async => null);
    when(() => router.push(any())).thenAnswer((_) async => null);
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Badge/Mystery reward cards clear the pinned CTA at first paint '
      '(no scroll) on a phone viewport', (tester) async {
    // Small/typical phone: 360x720 logical (1080x2160 @ 3x).
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_rig(router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    // Advance to the rewards page (page 3) without scrolling the page.
    await _swipeToNextPage(tester);
    await _swipeToNextPage(tester);

    final ctaTop = tester.getRect(find.byType(GlowingCtaButton)).top;
    final cardsBottom = tester
        .getRect(find.byType(IntroFeatureCardsRow))
        .bottom;

    expect(
      cardsBottom,
      lessThanOrEqualTo(ctaTop),
      reason:
          'At rest (no scroll) the Badge Collection / Mystery Prizes cards '
          'must not be covered by the pinned "Get Started" CTA.',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('rewards cards clear the pinned CTA when scrolled to the end', (
    tester,
  ) async {
    await tester.pumpWidget(_rig(router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    // Advance to the rewards page (page 3).
    await _swipeToNextPage(tester);
    await _swipeToNextPage(tester);

    // Scroll the rewards page to its maximum extent so the reward cards
    // are lifted above the overlaid CTA.
    final scrollable = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    await tester.drag(scrollable.first, const Offset(0, -2000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final ctaTop = tester.getRect(find.byType(GlowingCtaButton)).top;

    final cardsBottom = tester
        .getRect(find.byType(IntroFeatureCardsRow))
        .bottom;
    expect(
      cardsBottom,
      lessThanOrEqualTo(ctaTop),
      reason:
          'Badge/Mystery reward cards must clear the pinned CTA when '
          'scrolled to the end (CTA must not overlap them).',
    );

    final scholarBottom = tester
        .getRect(find.byType(IntroScholarLevelCard))
        .bottom;
    expect(
      scholarBottom,
      lessThanOrEqualTo(ctaTop),
      reason:
          'Scholar-level reward card must clear the pinned CTA when '
          'scrolled to the end.',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
