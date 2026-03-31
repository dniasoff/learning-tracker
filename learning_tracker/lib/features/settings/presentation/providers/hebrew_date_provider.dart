import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'hebrew_date_provider.g.dart';

const String _useHebrewDateKey = 'use_hebrew_calendar';

/// Global preference for Hebrew vs Gregorian calendar.
///
/// When true, all date pickers across the app use Hebrew calendar.
/// Set during onboarding or in Settings.
@riverpod
class UseHebrewDateNotifier extends _$UseHebrewDateNotifier {
  @override
  bool build() {
    _loadFromPrefs();
    return false;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_useHebrewDateKey);
    if (value != null) {
      state = value;
    }
  }

  Future<void> setUseHebrewDate(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useHebrewDateKey, value);
  }
}
