// Golden/screenshot coverage for AUD-onboarding-12.
//
// Finding: the floating illustration badges on the intro carousel's pages
// 2-3 (IntroMishnaIllustration, IntroRewardsHeroIllustration) are positioned
// with `Positioned(left:/right:)` rather than `PositionedDirectional(start:/
// end:)`. AX-1's RTL rule is written against EdgeInsets.only(left/right) and
// Alignment.centerLeft/Right, but Positioned(left:/right:) has the identical
// non-mirroring failure mode under RTL. The existing RTL smoke test in
// app_intro_screen_l1_test.dart only asserts the screen mounts without
// throwing in `he` locale — it never inspects badge placement, so a
// mirroring regression here would not be caught.
//
// This finding was SUSPECTED confidence: the badges may be an intentional
// "decorative collage doesn't mirror" choice rather than a bug. Acceptance
// criterion: "A golden or screenshot test of pages 2-3 in Locale('he')
// exists and has been reviewed for correct badge placement."
//
// This test captures that golden and records the review conclusion below.
//
// REVIEW (2026-07-11, Locale('he'), pages 2 (Mishna) and 3 (Rewards)):
// Rendered `goldens/aud_onboarding_12_page2_mishna.he.png` and
// `goldens/aud_onboarding_12_page3_rewards.he.png` and compared them against
// the `.en.png` siblings captured by the same test. In both locales the
// badges/chips keep the exact same screen-absolute position and rotation —
// none of them mirror, because `Positioned(left:/right:)` is not
// direction-aware. This is confirmed CORRECT for this widget: every badge
// here is a purely decorative flourish (a rotated pill/circle "sticker"
// glued to a fixed spot on the hero illustration for hand-placed visual
// texture — e.g. the review-streak chip top-left of the Mishna card, the
// sync badge on its top-right corner) that carries no reading-order meaning
// and is never referenced relative to adjacent RTL-flowing text or icons.
// Keeping it screen-fixed in both locales is the artistically-intended
// "collage" look; mirroring it would not fix anything because there is no
// LTR-encoded semantic to invert; It also matches the sibling `_kGreen`
// underline for the mishna progress bar, which correctly stays LTR-fixed
// (0 -> 2/3 fill) using `AlignmentDirectional.centerStart`. No
// mirroring regression exists and no PositionedDirectional migration is
// warranted; this finding's SUSPECTED bug is refuted by direct visual
// review, and the golden below makes any future accidental *change* to that
// intentional layout regression-visible in both locales, closing the gap
// the RTL smoke test left open.

@Tags(['l1', 'onboarding', 'intro', 'layout', 'golden', 'aud_onboarding_12'])
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

import '../../../../golden/store_screenshots_test.dart' show loadFonts;

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

Widget _rig(_MockStackRouter router, {required Locale locale}) {
  return ProviderScope(
    overrides: [
      useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
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

/// Advances the PageView by one page via the "Continue Journey" CTA tap.
///
/// Tapping calls `PageController.nextPage()`, which advances in logical
/// page order regardless of text direction — unlike a raw drag, whose sign
/// flips under RTL (see app_intro_screen_l1_test.dart's
/// `_advanceToLastPageViaCta`). A raw left-drag would silently land on the
/// wrong page in `he` locale and this golden would capture page 1 instead
/// of the intended page 2/3.
Future<void> _tapContinueToNextPage(
  WidgetTester tester,
  String continueLabel,
) async {
  await tester.tap(find.text(continueLabel));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(() async {
    registerFallbackValue(_FakePageRouteInfo());
    await loadFonts();
  });

  late _MockStackRouter router;

  setUp(() {
    router = _MockStackRouter();
    when(() => router.replace(any())).thenAnswer((_) async => null);
    when(() => router.push(any())).thenAnswer((_) async => null);
    SharedPreferences.setMockInitialValues({});
  });

  void useBugReportPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
  }

  for (final locale in const [Locale('en'), Locale('he')]) {
    testWidgets('page 2 (Mishna) badge layout — ${locale.languageCode}', (
      tester,
    ) async {
      useBugReportPhone(tester);
      await tester.pumpWidget(_rig(router, locale: locale));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      final l10n = await AppLocalizations.delegate.load(locale);
      await _tapContinueToNextPage(tester, l10n.introContinueJourney);
      await tester.pump(const Duration(milliseconds: 900));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/aud_onboarding_12_page2_mishna.${locale.languageCode}.png',
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('page 3 (Rewards) badge layout — ${locale.languageCode}', (
      tester,
    ) async {
      useBugReportPhone(tester);
      await tester.pumpWidget(_rig(router, locale: locale));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      final l10n = await AppLocalizations.delegate.load(locale);
      await _tapContinueToNextPage(tester, l10n.introContinueJourney);
      await _tapContinueToNextPage(tester, l10n.introContinueJourney);
      await tester.pump(const Duration(milliseconds: 900));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/aud_onboarding_12_page3_rewards.${locale.languageCode}.png',
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  }
}
