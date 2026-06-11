// The app UI language follows the DEVICE language. There is intentionally NO
// in-app language switcher: MaterialApp.locale is null so Flutter resolves the
// device locale against the supported set (Hebrew device → he + RTL, otherwise
// English). [resolveDeviceUiLocale] mirrors that resolution for background
// notifications, which localize without a BuildContext.
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

File _source(String relative) {
  final file = [
    File(relative),
    File('../$relative'),
  ].firstWhere((f) => f.existsSync(), orElse: () => File(relative));
  if (!file.existsSync()) {
    throw TestFailure('Could not locate $relative from the test cwd.');
  }
  return file;
}

void main() {
  group('Device-driven UI locale — resolveDeviceUiLocale', () {
    test('Hebrew device locale resolves to he', () {
      expect(resolveDeviceUiLocale(const [Locale('he')]).languageCode, 'he');
      expect(
        resolveDeviceUiLocale(const [Locale('he', 'IL')]).languageCode,
        'he',
      );
    });

    test('English device locale resolves to en', () {
      expect(resolveDeviceUiLocale(const [Locale('en')]).languageCode, 'en');
    });

    test('unsupported / empty device locale falls back to en', () {
      expect(resolveDeviceUiLocale(const [Locale('fr')]).languageCode, 'en');
      expect(resolveDeviceUiLocale(const []).languageCode, 'en');
    });

    test('first supported locale in the device preference list wins', () {
      expect(
        resolveDeviceUiLocale(const [
          Locale('fr'),
          Locale('he'),
          Locale('en'),
        ]).languageCode,
        'he',
      );
    });
  });

  group('Supported locales', () {
    test('include Hebrew and English', () {
      const supported = AppLocalizations.supportedLocales;
      expect(supported.any((l) => l.languageCode == 'he'), isTrue);
      expect(supported.any((l) => l.languageCode == 'en'), isTrue);
    });
  });

  group('Source guards — device-driven, no in-app switcher', () {
    test('MaterialApp.locale is null (device drives the UI language)', () {
      final source = _source(
        'lib/app/learning_tracker_app.dart',
      ).readAsStringSync();
      final nonCommentLines = source
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        RegExp(r'\blocale:\s*null\b').hasMatch(nonCommentLines),
        isTrue,
        reason:
            'The UI language must follow the device language: MaterialApp.locale '
            'should be null so Flutter resolves the device locale against the '
            'supported set.',
      );
    });

    test('Settings has no in-app App Language switcher tile', () {
      final source = _source(
        'lib/features/settings/presentation/screens/settings_screen.dart',
      ).readAsStringSync();
      expect(
        source.contains('_AppLanguageTile'),
        isFalse,
        reason:
            'There must be no in-app language switcher — language follows the '
            'device, not a user-configurable setting.',
      );
    });
  });
}
