import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/domain/profile_scoped_preference_keys.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'transliteration_variant_provider.g.dart';

String _transliterationVariantMirrorProfile0 = 'ashkenazi';

/// Call from main() after [SharedPreferences.getInstance] so the first read
/// of this provider for profile 0 matches stored prefs.
void syncTransliterationVariantPreferenceFromPrefs(SharedPreferences prefs) {
  _transliterationVariantMirrorProfile0 =
      ProfileScopedPreferenceKeys.readTransliterationVariant(prefs, 0);
}

/// Which Hebrew transliteration dialect to use for English-mode display of
/// named-level values (Bereishis vs Bereshit, Shemos vs Shemot, Kesuvim vs
/// Ketuvim). Defaults to Ashkenazi. Independent of the Hebrew-terms toggle.
@Riverpod(keepAlive: true)
class TransliterationVariantNotifier
    extends _$TransliterationVariantNotifier {
  @override
  TransliterationVariant build() {
    final profileId = ref.watch(activeProfileIdProvider);
    ref.listen(activeProfileIdProvider, (prev, next) {
      if (prev != next) {
        _loadFromPrefs(next);
      }
    });
    _loadFromPrefs(profileId);
    return profileId == 0
        ? _parse(_transliterationVariantMirrorProfile0)
        : TransliterationVariant.ashkenazi;
  }

  Future<void> _loadFromPrefs(int profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = ProfileScopedPreferenceKeys.readTransliterationVariant(
      prefs,
      profileId,
    );
    final value = _parse(raw);
    if (profileId == 0) {
      _transliterationVariantMirrorProfile0 = raw;
    }
    if (value != state) {
      state = value;
    }
  }

  Future<void> setVariant(TransliterationVariant variant) async {
    final profileId = ref.read(activeProfileIdProvider);
    state = variant;
    final raw = variant.name; // 'ashkenazi' | 'sephardi'
    if (profileId == 0) {
      _transliterationVariantMirrorProfile0 = raw;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      ProfileScopedPreferenceKeys.transliterationVariant(profileId),
      raw,
    );
  }

  TransliterationVariant _parse(String raw) {
    return raw == 'sephardi'
        ? TransliterationVariant.sephardi
        : TransliterationVariant.ashkenazi;
  }
}
