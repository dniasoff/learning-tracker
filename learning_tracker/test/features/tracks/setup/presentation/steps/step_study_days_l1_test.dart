// L1 widget tests — StudyDaysEditable (step_study_days.dart)
//
// Coverage focus:
//   1. English locale: renders without crash, weekday names in English.
//   2. R5-5 regression: Hebrew locale renders Hebrew weekday names; no English
//      day names (Sunday/Monday/…) appear under he locale.

@Tags(['tracks', 'study_days_step', 'l1'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_study_days.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ── Widget builder ────────────────────────────────────────────────────────────

Widget _buildStudyDaysApp({Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: StudyDaysEditable(onComplete: (_) {})),
  );
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
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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
}
