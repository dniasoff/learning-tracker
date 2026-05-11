import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/domain/profile_scoped_preference_keys.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'hebrew_terms_provider.g.dart';

bool _hebrewTermsScriptMirrorProfile0 = true;

/// Call once from [main] after [SharedPreferences.getInstance], so the first
/// build of [hebrewTermsScriptProvider] for profile 0 matches stored prefs.
void syncHebrewTermsScriptPreferenceFromPrefs(SharedPreferences prefs) {
  _hebrewTermsScriptMirrorProfile0 =
      ProfileScopedPreferenceKeys.readHebrewTermsScript(prefs, 0);
}

/// Whether to render Jewish learning terms (chazara, review section, etc.)
/// in Hebrew script. When false, the same terms are shown in English
/// transliteration. Independent of the app's UI locale.
@Riverpod(keepAlive: true)
class HebrewTermsScriptNotifier extends _$HebrewTermsScriptNotifier {
  @override
  bool build() {
    final profileId = ref.watch(activeProfileIdProvider);
    ref.listen(activeProfileIdProvider, (prev, next) {
      if (prev != next) {
        _loadFromPrefs(next);
      }
    });
    _loadFromPrefs(profileId);
    return profileId == 0 ? _hebrewTermsScriptMirrorProfile0 : true;
  }

  Future<void> _loadFromPrefs(int profileId) async {
    // Wrap SharedPreferences access — tests that don't initialize the
    // shared-prefs platform channel would otherwise crash with
    // MissingPluginException and bubble up through every widget that
    // depends on this provider.
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }
    final value = ProfileScopedPreferenceKeys.readHebrewTermsScript(
      prefs,
      profileId,
    );
    if (profileId == 0) {
      _hebrewTermsScriptMirrorProfile0 = value;
    }
    if (value != state) {
      state = value;
    }
  }

  Future<void> setHebrewTermsScript(bool value) async {
    final profileId = ref.read(activeProfileIdProvider);
    state = value;
    if (profileId == 0) {
      _hebrewTermsScriptMirrorProfile0 = value;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      ProfileScopedPreferenceKeys.hebrewTermsScript(profileId),
      value,
    );
    await ref.read(syncEngineProvider)?.pushUiPreferencesSnapshot();
  }
}
