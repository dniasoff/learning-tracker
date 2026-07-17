import 'dart:async';

import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/location_error_code.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/location_fetch_result.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_location.dart';

/// Wraps geolocator + geocoding so the rest of the feature can be unit-tested
/// against a fake. Pure data — no Riverpod, no SharedPreferences.
class LocationService {
  const LocationService();

  /// Request a fresh GPS fix and reverse-geocode the country code.
  /// Caller is responsible for persisting the returned [SacredLocation].
  Future<LocationFetchResult> detectCurrent() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationFetchServiceDisabled();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationFetchPermissionDenied(permanentlyDenied: true);
    }
    if (permission == LocationPermission.denied) {
      return const LocationFetchPermissionDenied(permanentlyDenied: false);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final iso = await _reverseCountryCode(
        position.latitude,
        position.longitude,
      );
      return LocationFetchSuccess(
        SacredLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          source: SacredLocationSource.detected,
          fixedAt: DateTimeFactory.nowUtc(),
          countryCode: iso,
        ),
      );
    } on Exception catch (e) {
      // AUD-sacred_time-03 (EH-5): classify into a stable code — never a
      // pre-formatted human message. The 15s timeLimit above makes
      // TimeoutException the common indoor/poor-signal case; anything else
      // falls back to unknown. debugDetail is retained for logs only — it
      // must never be rendered to the user.
      final code = switch (e) {
        TimeoutException() => LocationErrorCode.timeout,
        _ => LocationErrorCode.unknown,
      };
      return LocationFetchError(code, debugDetail: e.toString());
    }
  }

  /// Best-effort reverse geocode → ISO country code (e.g. 'IL', 'US').
  /// Returns null if reverse geocoding is unavailable on this platform.
  Future<String?> _reverseCountryCode(double lat, double long) async {
    try {
      final placemarks = await geo.placemarkFromCoordinates(lat, long);
      if (placemarks.isEmpty) return null;
      final iso = placemarks.first.isoCountryCode;
      return (iso == null || iso.isEmpty) ? null : iso.toUpperCase();
    } on Exception {
      return null;
    }
  }
}
