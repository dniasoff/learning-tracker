import 'package:learning_tracker/features/sacred_time/domain/models/sacred_location.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences keys for Sacred Time. App-global (not profile-scoped):
/// the device's physical location is shared across profiles.
class SacredTimePreferences {
  SacredTimePreferences._();

  static const _latKey = 'sacred_time_latitude';
  static const _longKey = 'sacred_time_longitude';
  static const _countryKey = 'sacred_time_country_code';
  static const _cityKey = 'sacred_time_city_label';
  static const _sourceKey = 'sacred_time_source';
  static const _fixedAtKey = 'sacred_time_fixed_at_ms';
  static const _inIsraelKey = 'sacred_time_in_israel';

  static SacredLocation? readLocation(SharedPreferences prefs) {
    final lat = prefs.getDouble(_latKey);
    final long = prefs.getDouble(_longKey);
    final fixedAtMs = prefs.getInt(_fixedAtKey);
    final sourceName = prefs.getString(_sourceKey);
    if (lat == null || long == null || fixedAtMs == null) return null;
    final source = SacredLocationSource.values.firstWhere(
      (s) => s.name == sourceName,
      orElse: () => SacredLocationSource.detected,
    );
    return SacredLocation(
      latitude: lat,
      longitude: long,
      source: source,
      fixedAt: DateTime.fromMillisecondsSinceEpoch(fixedAtMs, isUtc: true),
      countryCode: prefs.getString(_countryKey),
      cityLabel: prefs.getString(_cityKey),
    );
  }

  static Future<void> writeLocation(
    SharedPreferences prefs,
    SacredLocation loc,
  ) async {
    await prefs.setDouble(_latKey, loc.latitude);
    await prefs.setDouble(_longKey, loc.longitude);
    await prefs.setString(_sourceKey, loc.source.name);
    await prefs.setInt(_fixedAtKey, loc.fixedAt.toUtc().millisecondsSinceEpoch);
    if (loc.countryCode != null) {
      await prefs.setString(_countryKey, loc.countryCode!);
    } else {
      await prefs.remove(_countryKey);
    }
    if (loc.cityLabel != null) {
      await prefs.setString(_cityKey, loc.cityLabel!);
    } else {
      await prefs.remove(_cityKey);
    }
  }

  /// User-toggleable. Auto-flipped from country code on detect / city pick,
  /// but the user can override afterwards.
  static bool readInIsrael(SharedPreferences prefs) {
    return prefs.getBool(_inIsraelKey) ?? false;
  }

  static Future<void> writeInIsrael(
    SharedPreferences prefs,
    bool value,
  ) async {
    await prefs.setBool(_inIsraelKey, value);
  }
}
