// Variant-aware domain-term test for the full-screen Sacred Time lock overlay.
//
// The "Good Shabbos" greeting + "...closed for Shabbos" subtitle (and the
// combined Shabbos & Yom Tov variants) must NOT hardcode the Ashkenazi
// "Shabbos" in the ARB. They are composed from the variant-aware Shabbos term
// resolved via domainTermLabels(ref).shabbos(variant), so they follow the
// Hebrew-terms toggle + Ashkenazi/Sephardi nusach.
//
// Renders the REAL [SacredTimeLockOverlay] with the active-window provider
// overridden (overrideWithValue bypasses the notifier's 30s Timer) plus the
// toggle / variant providers overridden, then asserts on the rendered text.

@Tags(['sacred_time', 'l10n', 'regression'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_lock_overlay.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

SacredWindow _windowOf(SacredWindowKind kind) => SacredWindow(
  startUtc: DateTime.utc(2026, 5, 15, 18, 0),
  endUtc: DateTime.utc(2026, 5, 16, 20, 0),
  kind: kind,
);

Future<void> _pumpOverlay(
  WidgetTester tester, {
  required SacredWindowKind kind,
  required bool useHebrewTerms,
  required TransliterationVariant variant,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentSacredWindowProvider.overrideWithValue(_windowOf(kind)),
        useHebrewTermsProvider.overrideWithValue(useHebrewTerms),
        currentTransliterationVariantProvider.overrideWithValue(variant),
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
        home: const SacredTimeLockOverlay(child: SizedBox.expand()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('SacredTimeLockOverlay — variant-aware Shabbos greeting', () {
    testWidgets('Ashkenazi → "Good Shabbos" + "...closed for Shabbos."', (
      tester,
    ) async {
      await _pumpOverlay(
        tester,
        kind: SacredWindowKind.shabbos,
        useHebrewTerms: false,
        variant: TransliterationVariant.ashkenazi,
      );

      expect(find.text('Good Shabbos'), findsOneWidget);
      expect(find.text('The app is closed for Shabbos.'), findsOneWidget);
      expect(find.text('Good Shabbat'), findsNothing);
    });

    testWidgets('Sephardi → "Good Shabbat" + "...closed for Shabbat."', (
      tester,
    ) async {
      await _pumpOverlay(
        tester,
        kind: SacredWindowKind.shabbos,
        useHebrewTerms: false,
        variant: TransliterationVariant.sephardi,
      );

      expect(find.text('Good Shabbat'), findsOneWidget);
      expect(find.text('The app is closed for Shabbat.'), findsOneWidget);
      expect(find.text('Good Shabbos'), findsNothing);
    });

    testWidgets('Hebrew-terms ON → greeting uses שבת ("שבת שלום")', (
      tester,
    ) async {
      await _pumpOverlay(
        tester,
        kind: SacredWindowKind.shabbos,
        useHebrewTerms: true,
        variant: TransliterationVariant.ashkenazi,
        locale: const Locale('he'),
      );

      // Hebrew frame "{term} שלום" → "שבת שלום".
      expect(find.text('שבת שלום'), findsOneWidget);
      expect(find.text('Good Shabbos'), findsNothing);
      expect(find.text('Good Shabbat'), findsNothing);
    });
  });

  group('SacredTimeLockOverlay — combined Shabbos & Yom Tov', () {
    testWidgets('Ashkenazi → "Good Shabbos & Good Yom Tov"', (tester) async {
      await _pumpOverlay(
        tester,
        kind: SacredWindowKind.shabbosYomTov,
        useHebrewTerms: false,
        variant: TransliterationVariant.ashkenazi,
      );

      expect(find.text('Good Shabbos & Good Yom Tov'), findsOneWidget);
      expect(
        find.text('The app is closed for Shabbos and Yom Tov.'),
        findsOneWidget,
      );
    });

    testWidgets('Sephardi → "Good Shabbat & Good Yom Tov"', (tester) async {
      await _pumpOverlay(
        tester,
        kind: SacredWindowKind.shabbosYomTov,
        useHebrewTerms: false,
        variant: TransliterationVariant.sephardi,
      );

      expect(find.text('Good Shabbat & Good Yom Tov'), findsOneWidget);
      expect(
        find.text('The app is closed for Shabbat and Yom Tov.'),
        findsOneWidget,
      );
    });
  });
}
