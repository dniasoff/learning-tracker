import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
import 'package:learning_tracker/core/preferences/translation_visibility_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('TranslationVisibilityPreference', () {
    test('defaults translation visibility to on for each profile', () async {
      final preference = TranslationVisibilityPreference();

      expect(preference.defaultValue, isTrue);
      expect(await preference.read('profile-1'), isTrue);
      expect(await preference.read('profile-2'), isTrue);
    });

    test('persists independently for each profile', () async {
      final preference = TranslationVisibilityPreference();

      await preference.write('profile-1', false);

      expect(await preference.read('profile-1'), isFalse);
      expect(await preference.read('profile-2'), isTrue);
    });

    test('uses the legacy key only for the no-profile sentinel', () async {
      SharedPreferences.setMockInitialValues({
        ProfileScopedPreferenceKeys.legacyShowTranslationKey: false,
      });
      final preference = TranslationVisibilityPreference();

      expect(await preference.read(kNoProfilePreferenceSentinel), isFalse);
      expect(await preference.read('profile-1'), isTrue);
    });

    test('writes the sentinel value to its scoped key', () async {
      final preference = TranslationVisibilityPreference();

      await preference.write(kNoProfilePreferenceSentinel, false);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(
          ProfileScopedPreferenceKeys.textShowTranslation(
            kNoProfilePreferenceSentinel,
          ),
        ),
        isFalse,
      );
    });
  });
}
