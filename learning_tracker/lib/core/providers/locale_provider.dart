import 'dart:ui';

import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/domain/profile_scoped_preference_keys.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'locale_provider.g.dart';

/// Provider for the app locale, persisted per learner profile and synced to
/// Firestore for cloud accounts (`ui_preferences/data`).
@riverpod
class AppLocale extends _$AppLocale {
  @override
  Locale build() {
    final profileId = ref.watch(activeProfileIdProvider);
    ref.listen(activeProfileIdProvider, (prev, next) {
      if (prev != next) {
        _load(next);
      }
    });
    _load(profileId);
    return const Locale('en');
  }

  Future<void> _load(int profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final code = ProfileScopedPreferenceKeys.readAppLocale(prefs, profileId);
    if (_supported.contains(code)) {
      state = Locale(code);
    }
  }

  static const _supported = {'en', 'he'};

  Future<void> setLocale(Locale locale) async {
    final profileId = ref.read(activeProfileIdProvider);
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      ProfileScopedPreferenceKeys.appLocale(profileId),
      locale.languageCode,
    );
    await ref.read(syncEngineProvider)?.pushUiPreferencesSnapshot();
  }
}
