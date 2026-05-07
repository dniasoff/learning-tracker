import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_location.dart';

/// Outcome of a permission/location request.
sealed class LocationFetchResult {
  const LocationFetchResult();
}

class LocationFetchSuccess extends LocationFetchResult {
  const LocationFetchSuccess(this.location);
  final SacredLocation location;
}

class LocationFetchPermissionDenied extends LocationFetchResult {
  const LocationFetchPermissionDenied({required this.permanentlyDenied});
  final bool permanentlyDenied;
}

class LocationFetchServiceDisabled extends LocationFetchResult {
  const LocationFetchServiceDisabled();
}

class LocationFetchError extends LocationFetchResult {
  const LocationFetchError(this.message);
  final String message;
}

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
          fixedAt: DateTime.now().toUtc(),
          countryCode: iso,
        ),
      );
    } on Object catch (e) {
      return LocationFetchError(e.toString());
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
    } on Object {
      return null;
    }
  }
}
