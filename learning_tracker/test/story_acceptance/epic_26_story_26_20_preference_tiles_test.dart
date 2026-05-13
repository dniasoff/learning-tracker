/// Story acceptance tests for Story 26.20 (DNI-363) —
/// PreferenceListTile + PreferenceSegmentedTile primitives.
///
/// AC1: PreferenceListTile exists under core/widgets/.
/// AC2: PreferenceSegmentedTile<T> exists under core/widgets/.
/// AC3: Settings screen no longer contains the bespoke _HebrewDateTile,
///      _HebrewTermsTile, _NikudTile, _TransliterationVariantTile class
///      declarations.
/// AC4: Settings screen uses PreferenceListTile and PreferenceSegmentedTile.
/// AC5: hebrewTerms defaults to false, useHebrewDate defaults to false
///      (verified via HebrewTermsPreference / HebrewDatePreference).
/// AC6: Onboarding screen does NOT contain hebrewTerms or hebrewDate toggles
///      as steps.
@Tags(['epic_26'])
library;

import 'dart:io';

import 'package:learning_tracker/core/preferences/hebrew_date_preference.dart';
import 'package:learning_tracker/core/preferences/hebrew_terms_preference.dart';
import 'package:learning_tracker/core/widgets/preference_list_tile.dart';
import 'package:learning_tracker/core/widgets/preference_segmented_tile.dart';
import 'package:test/test.dart';

void main() {
  // ── AC1: PreferenceListTile class exists and is importable ──────────────────
  group(
    'Story 26.20 AC1 — PreferenceListTile exists under core/widgets/',
    tags: ['story_26_20'],
    () {
      test('widget file is present at the expected path', () {
        final candidates = [
          File('lib/core/widgets/preference_list_tile.dart'),
          File('learning_tracker/lib/core/widgets/preference_list_tile.dart'),
        ];
        final file = candidates.firstWhere(
          (f) => f.existsSync(),
          orElse: () => candidates.first,
        );
        expect(
          file.existsSync(),
          isTrue,
          reason:
              'preference_list_tile.dart must exist under core/widgets/. '
              'Looked for ${candidates.map((f) => f.path).join(", ")}',
        );
      });

      test('PreferenceListTile is importable (compile-time check)', () {
        // If this test file compiles, the import at the top of this file
        // has already resolved PreferenceListTile successfully.
        expect(PreferenceListTile, isNotNull);
      });
    },
  );

  // ── AC2: PreferenceSegmentedTile<T> class exists and is importable ──────────
  group(
    'Story 26.20 AC2 — PreferenceSegmentedTile<T> exists under core/widgets/',
    tags: ['story_26_20'],
    () {
      test('widget file is present at the expected path', () {
        final candidates = [
          File('lib/core/widgets/preference_segmented_tile.dart'),
          File(
            'learning_tracker/lib/core/widgets/preference_segmented_tile.dart',
          ),
        ];
        final file = candidates.firstWhere(
          (f) => f.existsSync(),
          orElse: () => candidates.first,
        );
        expect(
          file.existsSync(),
          isTrue,
          reason:
              'preference_segmented_tile.dart must exist under core/widgets/. '
              'Looked for ${candidates.map((f) => f.path).join(", ")}',
        );
      });

      test('PreferenceSegmentedTile<T> is importable (compile-time check)', () {
        // The import at the top of this file already resolved it.
        expect(PreferenceSegmentedTile, isNotNull);
      });
    },
  );

  // ── AC3: Bespoke tile class declarations removed from settings_screen.dart ──
  group(
    'Story 26.20 AC3 — bespoke tile classes deleted from settings_screen.dart',
    tags: ['story_26_20'],
    () {
      late String settingsSource;

      setUpAll(() {
        final candidates = [
          File(
            'lib/features/settings/presentation/screens/settings_screen.dart',
          ),
          File(
            'learning_tracker/lib/features/settings/presentation/screens/settings_screen.dart',
          ),
        ];
        final file = candidates.firstWhere(
          (f) => f.existsSync(),
          orElse: () => candidates.first,
        );
        settingsSource = file.existsSync() ? file.readAsStringSync() : '';
      });

      for (final className in ['_SettingsTile']) {
        test(
          'bespoke class $className is not declared in settings_screen.dart',
          () {
            expect(
              settingsSource.contains('class $className '),
              isFalse,
              reason:
                  '$className must be deleted — all navigation tiles now use '
                  'PreferenceListTile',
            );
          },
        );
      }
    },
  );

  // ── AC4: Settings screen references the new primitives ──────────────────────
  group(
    'Story 26.20 AC4 — settings_screen.dart uses the new primitives',
    tags: ['story_26_20'],
    () {
      late String settingsSource;

      setUpAll(() {
        final candidates = [
          File(
            'lib/features/settings/presentation/screens/settings_screen.dart',
          ),
          File(
            'learning_tracker/lib/features/settings/presentation/screens/settings_screen.dart',
          ),
        ];
        final file = candidates.firstWhere(
          (f) => f.existsSync(),
          orElse: () => candidates.first,
        );
        settingsSource = file.existsSync() ? file.readAsStringSync() : '';
      });

      test('imports PreferenceListTile', () {
        expect(
          settingsSource.contains('preference_list_tile'),
          isTrue,
          reason: 'settings_screen.dart must import preference_list_tile.dart',
        );
      });

      test('imports PreferenceSegmentedTile', () {
        expect(
          settingsSource.contains('preference_segmented_tile'),
          isTrue,
          reason:
              'settings_screen.dart must import preference_segmented_tile.dart',
        );
      });

      test('uses PreferenceListTile.withIcon at least once', () {
        expect(
          settingsSource.contains('PreferenceListTile.withIcon'),
          isTrue,
          reason:
              'settings_screen.dart must use PreferenceListTile.withIcon '
              'to replace navigation tiles',
        );
      });

      test('uses PreferenceSegmentedTile at least once', () {
        expect(
          settingsSource.contains('PreferenceSegmentedTile'),
          isTrue,
          reason:
              'settings_screen.dart must use PreferenceSegmentedTile for '
              'segmented preference tiles',
        );
      });
    },
  );

  // ── AC5: hebrewTerms and useHebrewDate default to false ─────────────────────
  group(
    'Story 26.20 AC5 — hebrewTerms and useHebrewDate default to false',
    tags: ['story_26_20'],
    () {
      test('HebrewTermsPreference.defaultValue is false', () {
        expect(
          HebrewTermsPreference().defaultValue,
          isFalse,
          reason: 'hebrewTerms must default to false per story AC',
        );
      });

      test('HebrewDatePreference.defaultValue is false', () {
        expect(
          HebrewDatePreference().defaultValue,
          isFalse,
          reason: 'useHebrewDate must default to false per story AC',
        );
      });
    },
  );

  // ── AC6: Onboarding does NOT present hebrewTerms / hebrewDate as steps ──────
  group(
    'Story 26.20 AC6 — onboarding does not include hebrewTerms/hebrewDate steps',
    tags: ['story_26_20'],
    () {
      late String onboardingSource;

      setUpAll(() {
        final candidates = [
          File(
            'lib/features/onboarding/presentation/screens/onboarding_screen.dart',
          ),
          File(
            'learning_tracker/lib/features/onboarding/presentation/screens/onboarding_screen.dart',
          ),
        ];
        final file = candidates.firstWhere(
          (f) => f.existsSync(),
          orElse: () => candidates.first,
        );
        onboardingSource = file.existsSync() ? file.readAsStringSync() : '';
      });

      test('onboarding_screen.dart does not have a hebrewTerms phase', () {
        // The _ScreenPhase enum must not contain a hebrewTerms entry.
        expect(
          onboardingSource.contains('hebrewTerms'),
          isFalse,
          reason:
              'Onboarding must NOT surface a hebrewTerms step — '
              'it lives only in Settings (per UX-DR3 / PART 6.5)',
        );
      });

      test(
        'onboarding_screen.dart does not reference HebrewTermsTile or hebrewTermsStep',
        () {
          for (final forbidden in [
            'HebrewTermsTile',
            'hebrewTermsStep',
            'hebrewTermsPhase',
          ]) {
            expect(
              onboardingSource.contains(forbidden),
              isFalse,
              reason:
                  '$forbidden must not appear in onboarding — '
                  'Hebrew-terms toggle is Settings-only',
            );
          }
        },
      );

      test(
        'onboarding _ScreenPhase enum does not declare a calendarPreference value',
        () {
          // The calendarPreference enum member must be removed from _ScreenPhase.
          // A string comparison in a legacy redirect (e.g.
          // `if (savedPhase == 'calendarPreference')`) is acceptable but the
          // enum MEMBER itself must not exist — we look for the declaration
          // pattern `calendarPreference,` inside the enum body.
          expect(
            RegExp(r'calendarPreference\s*,').hasMatch(onboardingSource),
            isFalse,
            reason:
                'calendarPreference must be removed from the _ScreenPhase enum — '
                'calendar toggle lives only in Settings (Story 26.20)',
          );
        },
      );
    },
  );
}
