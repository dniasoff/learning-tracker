import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'locale_provider.g.dart';

const _kLocaleKey = 'app_locale';

/// Provider for the app locale, persisted to SharedPreferences.
@riverpod
class AppLocale extends _$AppLocale {
  @override
  Locale build() {
    _load();
    return const Locale('he');
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLocaleKey);
    if (code != null && _supported.contains(code)) {
      state = Locale(code);
    }
  }

  static const _supported = {'en', 'he'};

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale.languageCode);
  }
}
