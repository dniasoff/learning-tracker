import 'package:learning_tracker/features/sacred_time/domain/models/location_error_code.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_location.dart';

// AUD-sacred_time-05: lives under domain/ (not data/) so presentation can
// pattern-match on the outcome of a location fetch without importing past
// domain into data — LocationService (data/services/location_service.dart)
// constructs and returns these; presentation only ever sees this domain type.

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
  const LocationFetchError(this.code, {this.debugDetail});

  /// Stable, localizable failure category (EH-5). Presentation resolves the
  /// user-facing string through `AppLocalizations`/ARB, keyed on this code —
  /// never on [debugDetail].
  final LocationErrorCode code;

  /// Raw exception text, retained for logs/diagnostics only (e.g.
  /// `AppLogger`). Must never be rendered to the user.
  final String? debugDetail;
}
