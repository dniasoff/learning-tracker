import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'hebrew_date_provider.g.dart';

const String _useHebrewDateKey = 'use_hebrew_calendar';

/// In-memory mirror kept in sync with [SharedPreferences] and [setUseHebrewDate].
/// [UseHebrewDateNotifier.build] must return a correct value on the first
/// frame—async [_loadFromPrefs] alone was too late, so date pickers read `false`
/// and stayed on the Gregorian path until a rebuild happened.
bool _useHebrewDateMirror = false;

/// Call once from [main] right after the first [SharedPreferences.getInstance],
/// so the first provider [build] matches stored prefs before async load finishes.
void syncHebrewCalendarPreferenceFromPrefs(SharedPreferences prefs) {
  _useHebrewDateMirror = prefs.getBool(_useHebrewDateKey) ?? false;
}

/// Global preference for Hebrew vs Gregorian calendar.
///
/// When true, all date pickers across the app use Hebrew calendar.
/// Set during onboarding or in Settings.
@riverpod
class UseHebrewDateNotifier extends _$UseHebrewDateNotifier {
  @override
  bool build() {
    _loadFromPrefs();
    return _useHebrewDateMirror;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_useHebrewDateKey) ?? false;
    _useHebrewDateMirror = value;
    if (value != state) {
      state = value;
    }
  }

  Future<void> setUseHebrewDate(bool value) async {
    _useHebrewDateMirror = value;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useHebrewDateKey, value);
  }
}
