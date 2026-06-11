/// Widget tests for [StreakCalendar] honoring the Calendar Preference.
///
/// P1 regression: the streak calendar ignored the Hebrew-date setting and
/// always rendered hardcoded English/Gregorian weekday + day labels. After the
/// fix, with [useHebrewDateProvider] ON it renders Hebrew weekday initials and
/// gematriya day-of-month numbers; with the pref OFF it keeps the
/// Gregorian/English labels.
@Tags(['progress', 'recent_activity', 'hebrew_date'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/streak_calendar.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

class _UseHebrewDateOverride extends UseHebrewDate {
  _UseHebrewDateOverride({required this.value});
  final bool value;
  @override
  bool build() => value;
}

Widget _wrap({required bool useHebrewDate, required Widget child}) {
  return ProviderScope(
    overrides: [
      useHebrewDateProvider.overrideWith(
        () => _UseHebrewDateOverride(value: useHebrewDate),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightTheme(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  // Fixed 7-day window: 2026-01-05 (Mon) .. 2026-01-11 (Sun).
  // Gregorian day numbers: 5..11.
  // Hebrew day-of-month for 2026-01-05 = 16 Teves → gematriya "ט״ז".
  // Hebrew day-of-month for 2026-01-11 = 22 Teves → gematriya "כ״ב".
  final start = DateTime(2026, 1, 5);
  final end = DateTime(2026, 1, 11);

  testWidgets('Gregorian pref OFF: renders English weekday + numeric days', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        useHebrewDate: false,
        child: StreakCalendar(
          activeDates: const {},
          startDate: start,
          endDate: end,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // English weekday header initials present.
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);
    // Gregorian numeric day labels present.
    expect(find.text('5'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
    // No Hebrew gematriya leaks.
    expect(find.text('ט״ז'), findsNothing);
  });

  testWidgets('Hebrew pref ON: renders Hebrew weekday + gematriya day labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        useHebrewDate: true,
        child: StreakCalendar(
          activeDates: const {},
          startDate: start,
          endDate: end,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Hebrew weekday header initials (Sun=א .. Sat=ש). The 7-day window starts
    // on Monday (ב) and the header is derived from the first row's weekdays.
    expect(find.text('ב'), findsWidgets); // Monday initial
    expect(find.text('א'), findsWidgets); // Sunday initial

    // Gematriya day-of-month labels — these prove the day numbers follow the
    // Hebrew calendar, not Gregorian.
    expect(find.text('ט״ז'), findsOneWidget); // 16 Teves (2026-01-05)
    expect(find.text('כ״ב'), findsOneWidget); // 22 Teves (2026-01-11)

    // The Gregorian numeric labels must NOT appear when the Hebrew pref is on.
    expect(find.text('5'), findsNothing);
    expect(find.text('11'), findsNothing);
    expect(find.text('Mon'), findsNothing);
    expect(find.text('Sun'), findsNothing);
  });
}
