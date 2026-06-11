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

  // ── Day-circle AVATAR initials (finding 1: localized, no mixed script) ───────

  group('StudyDaysEditable — avatar initials are localized', () {
    /// Collects the single-grapheme text inside every day-circle CircleAvatar.
    List<String> avatarInitials(WidgetTester tester) {
      final texts = <String>[];
      for (final avatar in tester.widgetList<CircleAvatar>(
        find.byType(CircleAvatar),
      )) {
        final child = avatar.child;
        if (child is Text && child.data != null) texts.add(child.data!);
      }
      return texts;
    }

    final hebrew = RegExp('[֐-׿]');
    final latin = RegExp('[A-Za-z]');

    testWidgets('English locale: every avatar initial is Latin (no Hebrew)', (
      tester,
    ) async {
      _sizeView(tester);
      await tester.pumpWidget(_buildStudyDaysApp());
      await tester.pump();

      final initials = avatarInitials(tester);
      expect(initials.length, 7, reason: 'one avatar per day');
      // Sun..Fri + Shabbos → all Latin first letters; none Hebrew.
      for (final i in initials) {
        expect(
          hebrew.hasMatch(i),
          isFalse,
          reason: 'EN locale must not show a Hebrew avatar initial (got "$i")',
        );
      }
      // Saturday's avatar in English-Ashkenazi is "S" (Shabbos), not "ש".
      expect(initials.contains('ש'), isFalse);
    });

    testWidgets(
      'Hebrew locale + Terms ON: every avatar initial is Hebrew (no lone '
      'Latin)',
      (tester) async {
        _sizeView(tester);
        await tester.pumpWidget(
          _buildStudyDaysApp(
            locale: const Locale('he'),
            useHebrewTerms: true,
          ),
        );
        await tester.pump();

        final initials = avatarInitials(tester);
        expect(initials.length, 7);
        // Pre-fix the Sun..Fri initials were Latin 'S'/'M'/'T' (from the
        // hardcoded English kStepStudyDayLabels) next to Shabbos' Hebrew 'ש' —
        // a mixed-script row even in the Hebrew locale. Post-fix every initial
        // must be Hebrew script (Sun..Fri from the he schedulerDayAbbrev keys,
        // Sat from the שבת term).
        for (final i in initials) {
          expect(
            latin.hasMatch(i),
            isFalse,
            reason:
                'Hebrew locale must not show a Latin avatar initial (got '
                '"$i") — the row must be fully Hebrew',
          );
          expect(hebrew.hasMatch(i), isTrue);
        }
        // Saturday's avatar initial is the first glyph of "שבת" → "ש".
        expect(initials.contains('ש'), isTrue);
      },
    );
  });
}
