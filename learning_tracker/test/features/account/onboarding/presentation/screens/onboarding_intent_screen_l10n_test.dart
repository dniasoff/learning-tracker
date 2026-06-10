// Regression test for DG-OINT-01: OnboardingIntentStep had hardcoded English
// literal strings that were never passed through AppLocalizations.  When the
// device locale was Hebrew the screen rendered English UI text — violating the
// bilingual (EN / HE) product requirement.
//
// These tests:
//   1. Verify the English render — l10n keys resolve to the correct EN strings.
//   2. Verify the Hebrew render — l10n keys resolve to Hebrew strings, NOT
//      English literals (the pre-fix bug that this guards against).
//   3. Smoke — both callbacks fire when the matching card is tapped.
@Tags(['l1', 'account', 'l10n', 'onboarding'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/onboarding/presentation/screens/onboarding_intent_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('OnboardingIntentStep — l10n (DG-OINT-01)', () {
    testWidgets('English locale: heading, subtitle and card titles use l10n', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(OnboardingIntentStep(onChosen: (_) {})));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // Heading and subtitle from l10n.
      expect(find.text(l10n.onboardingIntentHeading), findsOneWidget);
      expect(find.text(l10n.onboardingIntentSubtitle), findsOneWidget);

      // Card titles from l10n.
      expect(find.text(l10n.onboardingIntentTrackTitle), findsOneWidget);
      expect(find.text(l10n.onboardingIntentSkipTitle), findsOneWidget);
    });

    // DG-OINT-01 regression: before the fix, the Hebrew locale rendered the
    // hardcoded English literals "What brings you here?" / "Track my own
    // learning" / "Skip for now" instead of their Hebrew translations.
    testWidgets(
      'Hebrew locale: heading is Hebrew, NOT English — DG-OINT-01 regression',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            OnboardingIntentStep(onChosen: (_) {}),
            locale: const Locale('he'),
          ),
        );
        await tester.pumpAndSettle();

        final heL10n = await AppLocalizations.delegate.load(const Locale('he'));
        final enL10n = await AppLocalizations.delegate.load(const Locale('en'));

        // Hebrew text must appear.
        expect(
          find.text(heL10n.onboardingIntentHeading),
          findsOneWidget,
          reason: 'Hebrew heading must be rendered in the HE locale',
        );
        // The hardcoded English literal must NOT appear.
        expect(
          find.text(enL10n.onboardingIntentHeading),
          findsNothing,
          reason:
              'English heading must NOT appear in HE locale — '
              'DG-OINT-01 regression guard',
        );

        // Same for the track card title.
        expect(find.text(heL10n.onboardingIntentTrackTitle), findsOneWidget);
        expect(
          find.text(enL10n.onboardingIntentTrackTitle),
          findsNothing,
          reason: 'English track title must NOT appear in HE locale',
        );
      },
    );

    testWidgets('tapping track card invokes callback with trackMyLearning', (
      tester,
    ) async {
      OnboardingIntent? chosen;
      await tester.pumpWidget(
        _wrap(OnboardingIntentStep(onChosen: (intent) => chosen = intent)),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.onboardingIntentTrackTitle));
      await tester.pump();

      expect(chosen, OnboardingIntent.trackMyLearning);
    });

    testWidgets('tapping skip card invokes callback with skipForNow', (
      tester,
    ) async {
      OnboardingIntent? chosen;
      await tester.pumpWidget(
        _wrap(OnboardingIntentStep(onChosen: (intent) => chosen = intent)),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.onboardingIntentSkipTitle));
      await tester.pump();

      expect(chosen, OnboardingIntent.skipForNow);
    });
  });
}
