// L1 widget tests — StudyDaysEditable (step_study_days.dart)
//
// Coverage focus:
//   1. English locale: renders without crash, weekday names in English.
//   2. R5-5 regression: Hebrew locale renders Hebrew weekday names; no English
//      day names (Sunday/Monday/…) appear under he locale.
//   3. Saturday label is the Shabbos domain term — toggle + nusach aware:
//      Ashkenazi "Shabbos", Sephardi "Shabbat", Hebrew Terms ON "שבת".

@Tags(['tracks', 'study_days_step', 'l1'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_study_days.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ── Hebrew Terms / nusach overrides ─────────────────────────────────────────────

class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _TrueUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => true;
}

/// Fixed-nusach notifier so the Shabbos transliteration is deterministic.
class _FixedVariant extends CurrentTransliterationVariant {
  _FixedVariant(this._variant);

  final TransliterationVariant _variant;

  @override
  TransliterationVariant build() => _variant;
}

// ── Widget builder ────────────────────────────────────────────────────────────

Widget _buildStudyDaysApp({
  Locale locale = const Locale('en'),
  bool useHebrewTerms = false,
  TransliterationVariant variant = TransliterationVariant.ashkenazi,
}) {
  return ProviderScope(
    overrides: [
      useHebrewTermsProvider.overrideWith(
        () => useHebrewTerms ? _TrueUseHebrewTerms() : _FalseUseHebrewTerms(),
      ),
      currentTransliterationVariantProvider.overrideWith(
        () => _FixedVariant(variant),
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
      home: Scaffold(body: StudyDaysEditable(onComplete: (_) {})),
    ),
  );
}

void _sizeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('StudyDaysEditable — English locale', () {
    testWidgets('renders without crash and shows weekday names', (
      tester,
    ) async {
      _sizeView(tester);

      await tester.pumpWidget(_buildStudyDaysApp());
      await tester.pump();

      expect(find.byType(StudyDayCard), findsWidgets);
      expect(tester.takeException(), isNull);
      // At least one English weekday name must be rendered.
      expect(
        find.textContaining('day'),
        findsWidgets,
        reason: 'English weekday names (e.g. Monday, Sunday) must appear',
      );
    });
  });

  // ── R5-5 regression: Hebrew locale day names ─────────────────────────────

  group('StudyDaysEditable — R5-5 Hebrew locale day names', () {
    testWidgets(
      'Hebrew locale: day names are Hebrew; English day names absent',
      (tester) async {
        _sizeView(tester);

        await tester.pumpWidget(_buildStudyDaysApp(locale: const Locale('he')));
        await tester.pump();

        expect(tester.takeException(), isNull);

        // English day names must not appear under Hebrew locale.
        expect(
          find.text('Sunday'),
          findsNothing,
          reason: 'R5-5: "Sunday" must not appear when locale is Hebrew',
        );
        expect(
          find.text('Monday'),
          findsNothing,
          reason: 'R5-5: "Monday" must not appear when locale is Hebrew',
        );
        expect(
          find.text('Tuesday'),
          findsNothing,
          reason: 'R5-5: "Tuesday" must not appear when locale is Hebrew',
        );

        // Hebrew weekday names rendered by intl contain "יום" (day) for
        // weekdays Mon–Fri and Sun; at least one must be visible.
        expect(
          find.textContaining('יום'),
          findsWidgets,
          reason:
              'R5-5: Hebrew weekday labels (containing "יום") must be present',
        );
      },
    );
  });

  // ── Saturday label = Shabbos domain term (toggle + nusach aware) ─────────────

  group('StudyDaysEditable — Saturday label (Shabbos domain term)', () {
    testWidgets('Ashkenazi nusach renders "Shabbos"', (tester) async {
      _sizeView(tester);

      await tester.pumpWidget(_buildStudyDaysApp());
      await tester.pump();

      expect(find.text('Shabbos'), findsOneWidget);
      expect(find.text('Shabbat'), findsNothing);
      expect(find.text('שבת'), findsNothing);
    });

    testWidgets('Sephardi nusach renders "Shabbat"', (tester) async {
      _sizeView(tester);

      await tester.pumpWidget(
        _buildStudyDaysApp(variant: TransliterationVariant.sephardi),
      );
      await tester.pump();

      expect(find.text('Shabbat'), findsOneWidget);
      expect(find.text('Shabbos'), findsNothing);
    });

    testWidgets('Hebrew Terms ON renders "שבת" (nusach-independent)', (
      tester,
    ) async {
      _sizeView(tester);

      await tester.pumpWidget(_buildStudyDaysApp(useHebrewTerms: true));
      await tester.pump();

      expect(find.text('שבת'), findsOneWidget);
      expect(find.text('Shabbos'), findsNothing);
      expect(find.text('Shabbat'), findsNothing);
    });
  });
}
