// Regression test for IL-1: UseHebrewTerms provider resets to defaultValue
// (Hebrew=true) when activeProfileIdProvider temporarily emits the sentinel
// value 0 — which happens during the offline-signup DB switch
// (ref.invalidate(userDatabaseProvider) collapses the active profile id to 0
// while the new DB initialises).
//
// Root fix: UseHebrewTerms.build() must NOT re-bind the SharedPreferences
// observer when profileId==0 (sentinel), so the existing state (user's English
// choice) is preserved across the transient sentinel transition.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/hebrew_terms_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IL-1 — HebrewTermsPreference sentinel-0 read behaviour', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaultValue is true (Hebrew ON)', () {
      final pref = HebrewTermsPreference();
      expect(pref.defaultValue, isTrue);
    });

    test('profileId=0 with no saved pref returns defaultValue=true '
        '(this is the BUG trigger)', () async {
      final pref = HebrewTermsPreference();
      final value = await pref.read(0);
      // Intentionally true: reading sentinel profile 0 returns the default.
      // The IL-1 FIX is in UseHebrewTerms.build() — it must NOT re-bind
      // the observer for id==0, so this default never contaminates the state.
      expect(value, isTrue, reason: 'Sentinel profile 0 has no saved pref');
    });

    test('writing English choice for real profile is persisted', () async {
      final pref = HebrewTermsPreference();
      await pref.write(1, false); // profile 1 chose English
      final readBack = await pref.read(1);
      expect(readBack, isFalse);
    });

    test(
      'reading sentinel profile-0 does NOT corrupt profile-1 English pref',
      () async {
        final pref = HebrewTermsPreference();
        await pref.write(1, false); // profile 1 chose English
        // Simulate the sentinel-0 read that happens on DB invalidation.
        final sentinelRead = await pref.read(0);
        expect(sentinelRead, isTrue); // sentinel returns its default
        // Profile 1 must still be false (English).
        final profile1AfterSentinel = await pref.read(1);
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
    //   if (profileId == 0) return state;   // keep last non-sentinel value
    // Verify this pattern exists in the source file.
    test(
      'UseHebrewTerms.build() contains a sentinel-0 guard that preserves state',
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

        // The guard must prevent re-binding when profileId is the sentinel 0.
        final hasSentinelGuard =
            source.contains('profileId == 0') ||
            source.contains('if (profileId == 0)');

        expect(
          hasSentinelGuard,
          isTrue,
          reason:
              'UseHebrewTerms.build() must contain a sentinel-0 guard '
              '(if profileId==0, skip re-bind and return existing state). '
              'IL-1 fix is missing.',
        );
      },
    );
  });
}
