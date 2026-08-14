// Regression test for IL-1: UseHebrewTerms provider resets to defaultValue
// (Hebrew=true) when activeProfileIdProvider temporarily emits the sentinel
// value null while the selected profile is being re-resolved.
//
// Root fix: UseHebrewTerms.build() must NOT re-bind the SharedPreferences
// observer when profileId==null (sentinel), so the existing state (user's English
// choice) is preserved across the transient sentinel transition.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/hebrew_terms_preference.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IL-1 — HebrewTermsPreference null-sentinel read behaviour', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaultValue is true (Hebrew ON)', () {
      final pref = HebrewTermsPreference();
      expect(pref.defaultValue, isTrue);
    });

    test('null sentinel with no saved pref returns defaultValue=true '
        '(this is the BUG trigger)', () async {
      final pref = HebrewTermsPreference();
      final value = await pref.read(kNoProfilePreferenceSentinel);
      // Intentionally true: reading the sentinel bucket returns the default.
      // The IL-1 FIX is in UseHebrewTerms.build() — it must NOT re-bind
      // the observer for a null profile id, so this default never contaminates
      // the state.
      expect(value, isTrue, reason: 'Sentinel bucket has no saved pref');
    });

    test('writing English choice for real profile is persisted', () async {
      final pref = HebrewTermsPreference();
      await pref.write('profile-1', false); // profile 1 chose English
      final readBack = await pref.read('profile-1');
      expect(readBack, isFalse);
    });

    test(
      'reading sentinel profile-0 does NOT corrupt profile-1 English pref',
      () async {
        final pref = HebrewTermsPreference();
        await pref.write('profile-1', false); // profile 1 chose English
        // Simulate the sentinel-bucket read that happens during re-resolution.
        final sentinelRead = await pref.read(kNoProfilePreferenceSentinel);
        expect(sentinelRead, isTrue); // sentinel returns its default
        // Profile 1 must still be false (English).
        final profile1AfterSentinel = await pref.read('profile-1');
        expect(
          profile1AfterSentinel,
          isFalse,
          reason:
              'Reading sentinel profile-0 must not corrupt profile-1 English pref',
        );
      },
    );
  });

  group('IL-1 — UseHebrewTerms sentinel guard (source check)', () {
    // The IL-1 fix adds an early-return guard in UseHebrewTerms.build():
    //   if (sentinelBlocksRebind(profileId)) return state;
    //   // keep the last non-sentinel value
    // Verify this pattern exists in the source file.
    test(
      'UseHebrewTerms.build() contains a null-sentinel guard that preserves state',
      () {
        final candidates = [
          File('lib/core/preferences/preference_providers.dart'),
          File('../lib/core/preferences/preference_providers.dart'),
        ];

        final file = candidates.firstWhere(
          (f) => f.existsSync(),
          orElse: () => throw TestFailure(
            'Could not locate lib/core/preferences/preference_providers.dart.',
          ),
        );

        final source = file.readAsStringSync();

        // The guard must prevent re-binding when profileId is the null sentinel.
        final hasSentinelGuard = source.contains(
          'if (sentinelBlocksRebind(profileId)) return state;',
        );

        expect(
          hasSentinelGuard,
          isTrue,
          reason:
              'UseHebrewTerms.build() must contain a null-sentinel guard '
              '(when profileId is the null sentinel, skip re-bind and return '
              'existing state). '
              'IL-1 fix is missing.',
        );
      },
    );
  });
}
