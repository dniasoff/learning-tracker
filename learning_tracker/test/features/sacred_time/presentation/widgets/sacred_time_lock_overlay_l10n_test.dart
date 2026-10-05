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

SacredWindow _windowOf(
  SacredWindowKind kind, {
  DateTime? startUtc,
  DateTime? endUtc,
  String timeZone = 'America/New_York',
}) => SacredWindow(
  startUtc: startUtc ?? DateTime.utc(2026, 5, 15, 18, 0),
  endUtc: endUtc ?? DateTime.utc(2026, 5, 16, 20, 0),
  kind: kind,
  timeZone: timeZone,
);

class _MutableSacredWindow extends CurrentSacredWindow {
  _MutableSacredWindow(this.current);

  SacredWindow? current;

  @override
  SacredWindow? build() => current;

  void replace(SacredWindow window) {
    current = window;
    state = window;
  }
}

Future<void> _pumpOverlay(
  WidgetTester tester, {
  required SacredWindowKind kind,
  required bool useHebrewTerms,
  required TransliterationVariant variant,
  Locale locale = const Locale('en'),
  SacredWindow? window,
  bool alwaysUse24HourFormat = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentSacredWindowProvider.overrideWithValue(
          window ?? _windowOf(kind),
        ),
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
        home: MediaQuery(
          data: MediaQueryData(alwaysUse24HourFormat: alwaysUse24HourFormat),
          child: const SacredTimeLockOverlay(child: SizedBox.expand()),
        ),
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

  group('SacredTimeLockOverlay — lock window times', () {
    testWidgets('shows configured-zone start and local 24-hour unlock time', (
      tester,
    ) async {
      await _pumpOverlay(
        tester,
        kind: SacredWindowKind.shabbos,
        useHebrewTerms: false,
        variant: TransliterationVariant.ashkenazi,
        alwaysUse24HourFormat: true,
      );

      // UTC bounds are rendered in the configured America/New_York zone.
      expect(find.text('Started Fri at 14:00'), findsOneWidget);
      expect(find.text('Unlocks Sat at 16:00'), findsOneWidget);
    });

    testWidgets('a chained window displays its final end, in Hebrew RTL', (
      tester,
    ) async {
      await _pumpOverlay(
        tester,
        kind: SacredWindowKind.shabbosYomTov,
        useHebrewTerms: true,
        variant: TransliterationVariant.ashkenazi,
        locale: const Locale('he'),
        window: _windowOf(
          SacredWindowKind.shabbosYomTov,
          endUtc: DateTime.utc(2026, 5, 18, 20),
        ),
      );

      expect(find.textContaining('התחיל ביום'), findsOneWidget);
      expect(find.textContaining('הנעילה תסתיים ביום'), findsOneWidget);
      expect(find.textContaining('Mon'), findsNothing);
      final unlock = tester.widget<Text>(
        find.byKey(const Key('sacredTimeLockUnlockTime')),
      );
      expect(unlock.data, contains('יום ב׳'));
      expect(unlock.data, contains('16:00'));
      expect(
        Directionality.of(tester.element(find.byType(SacredTimeLockOverlay))),
        TextDirection.rtl,
      );
    });

    testWidgets(
      'refreshes displayed times when a location edit recomputes the window',
      (tester) async {
        final source = _MutableSacredWindow(
          _windowOf(SacredWindowKind.shabbos),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentSacredWindowProvider.overrideWith(() => source),
              useHebrewTermsProvider.overrideWithValue(false),
              currentTransliterationVariantProvider.overrideWithValue(
                TransliterationVariant.ashkenazi,
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: SacredTimeLockOverlay(child: SizedBox.expand()),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Unlocks Sat at 4:00 PM'), findsOneWidget);

        // The governed location save refreshes the shared lock window. The
        // overlay rebuilds from the replacement bounds and zone immediately.
        source.replace(
          _windowOf(
            SacredWindowKind.shabbos,
            endUtc: DateTime.utc(2026, 5, 18, 21),
            timeZone: 'Europe/London',
          ),
        );
        await tester.pump();
        expect(find.text('Unlocks Mon at 10:00 PM'), findsOneWidget);
        expect(find.text('Unlocks Sat at 4:00 PM'), findsNothing);
      },
    );
  });

  // DNI-481 AC-1 edge row: accessibility and display resilience — the
  // greeting is the only semantics, in light and dark, LTR and RTL.
  group('SacredTimeLockOverlay — semantics expose the greeting only', () {
    for (final (name, theme, locale, greeting) in [
      ('light en', ThemeData.light(), const Locale('en'), 'Good Shabbos'),
      ('dark he', ThemeData.dark(), const Locale('he'), 'שבת שלום'),
    ]) {
      testWidgets(name, (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentSacredWindowProvider.overrideWithValue(
                _windowOf(SacredWindowKind.shabbos),
              ),
              useHebrewTermsProvider.overrideWithValue(
                locale.languageCode == 'he',
              ),
              currentTransliterationVariantProvider.overrideWithValue(
                TransliterationVariant.ashkenazi,
              ),
            ],
            child: MaterialApp(
              theme: theme,
              locale: locale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const SacredTimeLockOverlay(
                child: Scaffold(body: Text('BEHIND THE LOCK')),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.bySemanticsLabel(RegExp(greeting)), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('BEHIND THE LOCK')), findsNothing);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  });
}
