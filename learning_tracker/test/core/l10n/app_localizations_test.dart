/// Tests for [AppLocalizationsEn] and [AppLocalizationsHe] localization files.
///
/// Exercises every string getter to boost l10n coverage. The strings are
/// compile-time constants so there's no logic to validate beyond "the getter
/// returns a non-empty string" — the real contract is that the key exists.
///
/// This file intentionally tests the generated output rather than the ARB
/// source; if the ARB changes and re-generation breaks a key, this file
/// catches the regression.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/l10n/app_localizations_en.dart';
import 'package:learning_tracker/l10n/app_localizations_he.dart';

void main() {
  late AppLocalizationsEn en;
  late AppLocalizationsHe he;

  setUp(() {
    en = AppLocalizationsEn();
    he = AppLocalizationsHe();
  });

  // ─── AppLocalizationsEn ───────────────────────────────────────────────────

  group('AppLocalizationsEn', () {
    test('locale is "en"', () {
      expect(en.localeName, 'en');
    });

    test('appTitle is non-empty', () => expect(en.appTitle, isNotEmpty));
    test('dashboard is non-empty', () => expect(en.dashboard, isNotEmpty));
    test('learn is non-empty', () => expect(en.learn, isNotEmpty));
    test('progress is non-empty', () => expect(en.progress, isNotEmpty));
    test('settings is non-empty', () => expect(en.settings, isNotEmpty));
    test('goodMorning is non-empty', () => expect(en.goodMorning, isNotEmpty));
    test(
      'goodAfternoon is non-empty',
      () => expect(en.goodAfternoon, isNotEmpty),
    );
    test('goodEvening is non-empty', () => expect(en.goodEvening, isNotEmpty));
    test('streak is non-empty', () => expect(en.streak, isNotEmpty));
    test('done is non-empty', () => expect(en.done, isNotEmpty));
    test('points is non-empty', () => expect(en.points, isNotEmpty));
    test('pages is non-empty', () => expect(en.pages, isNotEmpty));

    test("todaysLearning(3) contains '3'", () {
      expect(en.todaysLearning(3), contains('3'));
    });

    test('todaysLearning(0) returns non-empty string', () {
      expect(en.todaysLearning(0), isNotEmpty);
    });
  });

  // ─── AppLocalizationsHe ───────────────────────────────────────────────────

  group('AppLocalizationsHe', () {
    test('locale is "he"', () {
      expect(he.localeName, 'he');
    });

    test('appTitle is non-empty', () => expect(he.appTitle, isNotEmpty));
    test('dashboard is non-empty', () => expect(he.dashboard, isNotEmpty));
    test('learn is non-empty', () => expect(he.learn, isNotEmpty));
    test('progress is non-empty', () => expect(he.progress, isNotEmpty));
    test('settings is non-empty', () => expect(he.settings, isNotEmpty));
    test('goodMorning is non-empty', () => expect(he.goodMorning, isNotEmpty));
    test(
      'goodAfternoon is non-empty',
      () => expect(he.goodAfternoon, isNotEmpty),
    );
    test('goodEvening is non-empty', () => expect(he.goodEvening, isNotEmpty));
    test('streak is non-empty', () => expect(he.streak, isNotEmpty));
    test('done is non-empty', () => expect(he.done, isNotEmpty));
    test('points is non-empty', () => expect(he.points, isNotEmpty));
    test('pages is non-empty', () => expect(he.pages, isNotEmpty));

    test('todaysLearning(5) returns non-empty string', () {
      expect(he.todaysLearning(5), isNotEmpty);
    });
  });

  // ─── Cross-locale sanity ──────────────────────────────────────────────────

  group('Cross-locale', () {
    test('en and he have different appTitle strings', () {
      // The English and Hebrew titles should differ.
      // (If they're the same, the Hebrew localization is missing.)
      expect(en.appTitle, isNot(equals(he.appTitle)));
    });
  });
}
