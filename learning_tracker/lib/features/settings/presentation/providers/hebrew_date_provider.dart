import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/domain/profile_scoped_preference_keys.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'hebrew_date_provider.g.dart';

/// In-memory mirror for profile 0 — seeded from [syncHebrewCalendarPreferenceFromPrefs].
bool _useHebrewDateMirrorProfile0 = false;

/// Call once from [main] after [SharedPreferences.getInstance], so the first
/// [UseHebrewDateNotifier.build] for profile 0 matches stored prefs.
void syncHebrewCalendarPreferenceFromPrefs(SharedPreferences prefs) {
  _useHebrewDateMirrorProfile0 =
      ProfileScopedPreferenceKeys.readUseHebrewCalendar(prefs, 0);
}

/// Global preference for Hebrew vs Gregorian calendar (per learner profile).
@Riverpod(keepAlive: true)
class UseHebrewDateNotifier extends _$UseHebrewDateNotifier {
  @override
  bool build() {
    final profileId = ref.watch(activeProfileIdProvider);
    ref.listen(activeProfileIdProvider, (prev, next) {
      if (prev != next) {
        _loadFromPrefs(next);
      }
    });
    _loadFromPrefs(profileId);
    return profileId == 0 ? _useHebrewDateMirrorProfile0 : false;
  }

  Future<void> _loadFromPrefs(int profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final value = ProfileScopedPreferenceKeys.readUseHebrewCalendar(
      prefs,
      profileId,
    );
    if (profileId == 0) {
      _useHebrewDateMirrorProfile0 = value;
    }
    if (value != state) {
      state = value;
    }
  }

  Future<void> setUseHebrewDate(bool value) async {
    final profileId = ref.read(activeProfileIdProvider);
    state = value;
    if (profileId == 0) {
      _useHebrewDateMirrorProfile0 = value;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      ProfileScopedPreferenceKeys.useHebrewCalendar(profileId),
      value,
    );
    await ref.read(syncEngineProvider)?.pushUiPreferencesSnapshot();
  }
}
