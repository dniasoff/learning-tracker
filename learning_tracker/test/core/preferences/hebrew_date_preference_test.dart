// Tests for HebrewDatePreference — AG-5 mirror of
// lib/core/preferences/hebrew_date_preference.dart.
//
// Regression test for AUD-core-preferences-02: ProfileScopedPreferenceKeys
// .readUseHebrewCalendar(prefs, profileId) used to default to `false` for a
// never-written profile, while HebrewDatePreference().defaultValue is `true`
// (Hebrew calendar is the factory default — see hebrew_date_preference.dart
// doc comment). Both codepaths must return the SAME value for a fresh
// profile, or a sync push driven by ProfileScopedPreferenceKeys silently
// disagrees with what the UI (driven by HebrewDatePreference) displays.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/hebrew_date_preference.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('HebrewDatePreference', () {
    test('defaultValue is true (Hebrew calendar on first launch)', () {
      expect(HebrewDatePreference().defaultValue, isTrue);
    });

    test(
      'read() for a never-written profile returns defaultValue=true',
      () async {
        final value = await HebrewDatePreference().read('profile-7');
        expect(value, isTrue);
      },
    );

    test('writing false persists and reads back false', () async {
      final pref = HebrewDatePreference();
      await pref.write('profile-3', false);
      expect(await pref.read('profile-3'), isFalse);
    });
  });

  group('AUD-core-preferences-02 — HebrewDatePreference and '
      'ProfileScopedPreferenceKeys.readUseHebrewCalendar agree', () {
    test(
      'both codepaths return true for a never-written (fresh) profile',
      () async {
        const profileId = '01J8M6H7QK2P4N9R5T6V8W0XYZ';
        final prefs = await SharedPreferences.getInstance();

        final viaPreference = await HebrewDatePreference().read(profileId);
        final viaKeys = ProfileScopedPreferenceKeys.readUseHebrewCalendar(
          prefs,
          profileId,
        );

        expect(
          viaKeys,
          HebrewDatePreference().defaultValue,
          reason:
              'ProfileScopedPreferenceKeys.readUseHebrewCalendar must match '
              'HebrewDatePreference().defaultValue for an unset profile — '
              'the stale `?? false` fallback disagreed with the true '
              'default (AUD-core-preferences-02).',
        );
        expect(
          viaPreference,
          viaKeys,
          reason:
              'HebrewDatePreference.read() and '
              'ProfileScopedPreferenceKeys.readUseHebrewCalendar() must '
              'agree for the same never-written profile.',
        );
      },
    );

    test(
      'both codepaths agree for the null sentinel (legacy-key fallback path) '
      'with no legacy key set',
      () async {
        final prefs = await SharedPreferences.getInstance();

        final viaPreference = await HebrewDatePreference().read(
          kNoProfilePreferenceSentinel,
        );
        final viaKeys = ProfileScopedPreferenceKeys.readUseHebrewCalendar(
          prefs,
          kNoProfilePreferenceSentinel,
        );

        expect(viaPreference, isTrue);
        expect(viaKeys, isTrue);
        expect(viaPreference, viaKeys);
      },
    );
  });
}
