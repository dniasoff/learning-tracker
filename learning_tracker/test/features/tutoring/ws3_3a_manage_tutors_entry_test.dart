// WS3.3a — "Manage tutors" entry in parent settings (DEC-8)
//
// Verifies that:
//   AC1 — ParentSettingsScreen source contains a reference to ManageTutorsRoute.
//   AC2 — ParentSettingsScreen source uses the manageTutors l10n key.
//   AC3 — The manageTutors and manageTutorsSubtitle l10n keys are defined in
//          both English and Hebrew l10n dart files.
//   AC4 — ManageTutorsRoute and InviteTutorRoute are declared in the app router.

@Tags(['ws3', 'ws3_3a', 'tutor_mode'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('WS3.3a — Manage tutors entry in parent settings', () {
    late String parentSettingsSrc;
    late String appRouterSrc;
    late String l10nEnSrc;
    late String l10nHeSrc;

    setUpAll(() {
      parentSettingsSrc = File(
        'lib/features/profiles/presentation/screens/parent_settings_screen.dart',
      ).readAsStringSync();

      appRouterSrc = File('lib/app/router/app_router.dart').readAsStringSync();

      l10nEnSrc = File('lib/l10n/app_localizations_en.dart').readAsStringSync();

      l10nHeSrc = File('lib/l10n/app_localizations_he.dart').readAsStringSync();
    });

    test('AC1: ParentSettingsScreen navigates to ManageTutorsRoute', () {
      expect(
        parentSettingsSrc,
        contains('ManageTutorsRoute'),
        reason:
            'parent_settings_screen.dart must reference ManageTutorsRoute '
            '(WS3.3a — DEC-8)',
      );
    });

    test('AC2: ParentSettingsScreen uses manageTutors l10n key', () {
      expect(
        parentSettingsSrc,
        contains('l10n.manageTutors'),
        reason:
            'parent_settings_screen.dart must use the manageTutors l10n key',
      );
    });

    test('AC3a: manageTutors key is defined in English localizations', () {
      expect(
        l10nEnSrc,
        contains("String get manageTutors => 'Manage Tutors'"),
        reason: 'manageTutors must be defined in English',
      );
      expect(
        l10nEnSrc,
        contains('manageTutorsSubtitle'),
        reason: 'manageTutorsSubtitle must be defined in English',
      );
    });

    test('AC3b: manageTutors key is defined in Hebrew localizations', () {
      expect(
        l10nHeSrc,
        contains('manageTutors'),
        reason: 'manageTutors must be defined in Hebrew',
      );
      expect(
        l10nHeSrc,
        contains('manageTutorsSubtitle'),
        reason: 'manageTutorsSubtitle must be defined in Hebrew',
      );
    });

    test('AC4: ManageTutorsRoute is declared in AppRouter routes', () {
      expect(
        appRouterSrc,
        contains('ManageTutorsRoute.page'),
        reason: 'ManageTutorsRoute must appear in the app router routes list',
      );
    });

    test('AC4: InviteTutorRoute is declared in AppRouter routes', () {
      expect(
        appRouterSrc,
        contains('InviteTutorRoute.page'),
        reason: 'InviteTutorRoute must appear in the app router routes list',
      );
    });
  });
}
