// Regression test for IL-6: learning_tracker_app.dart had locale:null
// (DNI-341 comment) so the UI locale was always driven by the OS device
// locale, making the per-profile app_locale_pN preference inert.
//
// The fix wires currentAppLocaleProvider → MaterialApp.locale so a profile
// that requests Hebrew ('he') gets a Hebrew UI regardless of device locale.
//
// These tests verify:
//   1. The source file no longer passes `locale: null` to MaterialApp.
//   2. AppLocalePreference correctly reports supported locales.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/app_locale_preference.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  group('IL-6 — AppLocalePreference default and supported set', () {
    test('defaultValue is English', () {
      // ignore: prefer_const_constructors
      final pref = AppLocalePreference();
      expect(pref.defaultValue.languageCode, 'en');
    });

    test('AppLocalizations.supportedLocales includes Hebrew', () {
      // ignore: prefer_const_declarations
      final supported = AppLocalizations.supportedLocales;
      expect(
        supported.any((l) => l.languageCode == 'he'),
        isTrue,
        reason: 'Hebrew must be a supported locale for the locale wire to work',
      );
    });

    test('AppLocalizations.supportedLocales includes English', () {
      const supported = AppLocalizations.supportedLocales;
      expect(supported.any((l) => l.languageCode == 'en'), isTrue);
    });
  });

  group('IL-6 — learning_tracker_app.dart locale wire (source guard)', () {
    // Read the actual source file and verify the locale is no longer null.
    // This is the canonical RED test: it fails on current code which has
    //   `locale: null,`
    // and passes after the fix wires `locale: ref.watch(currentAppLocaleProvider)`.

    test(
      'MaterialApp locale is NOT hardcoded null in learning_tracker_app.dart',
      () {
        // Find the source file relative to the project root.
        final candidates = [
          File('lib/app/learning_tracker_app.dart'),
          File('../lib/app/learning_tracker_app.dart'),
        ];
        final file = candidates.firstWhere(
          (f) => f.existsSync(),
          orElse: () => throw TestFailure(
            'Could not locate lib/app/learning_tracker_app.dart. '
            'Run tests from the learning_tracker project root.',
          ),
        );

        final source = file.readAsStringSync();

        // The bug: `locale: null,` as actual code (not a comment).
        // The fix wires a provider expression, so non-comment occurrences must
        // be absent. We check by stripping comment lines first.
        final nonCommentLines = source
            .split('\n')
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');
        final hasNullLocale = RegExp(
          r'\blocale:\s*null\b',
        ).hasMatch(nonCommentLines);
        expect(
          hasNullLocale,
          isFalse,
          reason:
              'learning_tracker_app.dart must not pass locale:null to MaterialApp '
              '(IL-6 fix: wire currentAppLocaleProvider → MaterialApp.locale)',
        );
      },
    );

    test(
      'learning_tracker_app.dart references currentAppLocaleProvider for locale',
      () {
        final candidates = [
          File('lib/app/learning_tracker_app.dart'),
          File('../lib/app/learning_tracker_app.dart'),
        ];
        final file = candidates.firstWhere(
          (f) => f.existsSync(),
          orElse: () => throw TestFailure(
            'Could not locate lib/app/learning_tracker_app.dart.',
          ),
        );

        final source = file.readAsStringSync();
        expect(
          source.contains('currentAppLocaleProvider'),
          isTrue,
          reason:
              'learning_tracker_app.dart must read currentAppLocaleProvider '
              'and pass it to MaterialApp.locale (IL-6)',
        );
      },
    );
  });
}
