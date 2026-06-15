// Layout regression test for the rewards intro page ("Earn While You Learn").
//
// Bug (P1): the pinned bottom "Get Started" CTA was a Positioned overlay drawing
// ON TOP of the scrolling page content. At FIRST PAINT it covered the Badge
// Collection / Mystery Prizes reward cards (clipping their second label line),
// and at font scale 1.3 it covered the subtitle's last line and the entire
// reward-card row. The fix makes the CTA a non-overlapping Column sibling below
// the scroll view, so the scroll viewport's bottom edge IS the CTA's top edge
// and nothing can ever be painted behind the CTA — at any text scale.
//
// These tests assert, at FIRST PAINT (no scroll) at BOTH font scale 1.0 and
// 1.3, that the visible reward cards do not vertically intersect (i.e. are not
// covered by) the GlowingCtaButton, and that scrolling reveals them above the
// CTA.

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

Widget _rig(_MockStackRouter router, {double textScale = 1.0}) {
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: const AppIntroScreen(),
      ),
    ),
  );
}

/// Asserts the VISIBLE portion of [target] is not painted behind the pinned CTA.
///
/// The bug was a Positioned CTA overlay drawing on top of the scroll content, so
/// the reward cards' visible pixels were partly hidden behind the CTA. The fix
/// puts the scroll view and the CTA in a non-overlapping Column: the scroll
/// Viewport clips its content at its own bottom edge, which sits ABOVE the CTA's
/// top edge. So a card may extend below the viewport (it is then clipped and
/// reachable by scrolling — NOT drawn over the CTA), but its visible region must
/// never reach into the CTA.
///
/// Visible region = target rect intersected with the scroll Viewport rect. We
/// assert the bottom of that visible region is at or above the CTA's top edge.
void _expectVisiblePortionAboveCta(WidgetTester tester, Finder target) {
  final ctaTop = tester.getRect(find.byType(GlowingCtaButton)).top;
  final viewport = tester.getRect(
    find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Viewport),
        )
        .first,
  );
  final cardRect = tester.getRect(target);
  final visibleBottom = cardRect.bottom < viewport.bottom
      ? cardRect.bottom
      : viewport.bottom;
  expect(
    visibleBottom,
    lessThanOrEqualTo(ctaTop),
    reason:
        'Visible portion of $target (bottom $visibleBottom, clipped to viewport '
        '$viewport) reaches into the pinned CTA (top $ctaTop). The reward cards '
        'must never be drawn behind the CTA at first paint.',
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

  // Representative 1080x1920 / 420dpi phone (the device from the bug report):
  // 1080x1920 physical @ 2.625 dpr -> ~411x731 logical.
  void useBugReportPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpToRewardsPage(
    WidgetTester tester, {
    double textScale = 1.0,
  }) async {
    await tester.pumpWidget(_rig(router, textScale: textScale));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    // Advance to the rewards page (page 3) WITHOUT scrolling the page.
    await _swipeToNextPage(tester);
    await _swipeToNextPage(tester);
  }

  for (final scale in const [1.0, 1.3]) {
    testWidgets('reward cards are NOT covered by the pinned CTA at FIRST PAINT '
        '(no scroll) at font scale $scale', (tester) async {
      useBugReportPhone(tester);

      await pumpToRewardsPage(tester, textScale: scale);

      // The bug: at first paint the CTA overlay clipped the reward cards
      // (the Badge/Mystery row, and at 1.3 the whole row + subtitle line).
      // With the non-overlapping layout no VISIBLE content is ever drawn behind
      // the CTA — the scroll viewport clips above the CTA's top edge.
      _expectVisiblePortionAboveCta(tester, find.byType(IntroFeatureCardsRow));
      _expectVisiblePortionAboveCta(tester, find.byType(IntroScholarLevelCard));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  }

  testWidgets('reward cards clear the pinned CTA when scrolled to the end', (
    tester,
  ) async {
    useBugReportPhone(tester);

    await pumpToRewardsPage(tester);

    // Scroll the rewards page to its maximum extent so every reward card is
    // lifted into the viewport above the CTA.
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
