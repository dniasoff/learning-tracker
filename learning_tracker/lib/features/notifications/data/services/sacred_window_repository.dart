import 'package:learning_tracker/features/sacred_time/domain/models/sacred_location.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/domain/services/zmanim_window_service.dart';

/// Repository that provides Sacred Time block windows for notification
/// scheduling (DNI-367, Story 26.24).
///
/// Wraps [ZmanimWindowService] with an in-memory cache keyed on
/// (latitude, longitude, inIsrael). Call [invalidate] whenever the user's
/// location or timezone changes — the next query will recompute.
///
/// Windows are computed over a span wide enough to cover the next 14 days
/// plus a 2-day look-back so an in-progress window is always detected.
class SacredWindowRepository {
  SacredWindowRepository({ZmanimWindowService? service})
    : _service = service ?? const ZmanimWindowService();

  final ZmanimWindowService _service;

  /// Span used for window computation: 14 days forward + 2 days look-back
  /// inside the service itself (service always looks back 2 days from `from`).
  static const Duration _span = Duration(days: 18);

  List<SacredWindow>? _cachedWindows;
  double? _cachedLat;
  double? _cachedLong;
  bool? _cachedInIsrael;

  /// Invalidates the in-memory cache.
  ///
  /// Called by [TimezoneLifecycleObserver] on resume, and whenever the user's
  /// location changes.
  void invalidate() {
    _cachedWindows = null;
    _cachedLat = null;
    _cachedLong = null;
    _cachedInIsrael = null;
  }

  /// Returns true if [fireTimeUtc] (UTC) falls inside any Sacred Time block
  /// window.
  ///
  /// Pass [fireTimeUtc] in UTC. Use `tz_datetime.toUtc()` from a tz-aware
  /// [tz.TZDateTime] for correct local-to-UTC conversion.
  ///
  /// If [location] is null (user never set a location), returns false — no
  /// suppression without a location.
  bool isWindowActive(
    DateTime fireTimeUtc, {
    required SacredLocation? location,
    required bool inIsrael,
  }) {
    if (location == null) return false;

    final windows = _getOrComputeWindows(
      location: location,
      inIsrael: inIsrael,
      // Start 2 days before the fire time so in-progress windows are caught.
      from: fireTimeUtc.subtract(const Duration(days: 2)),
    );

    for (final w in windows) {
      if (!fireTimeUtc.isBefore(w.startUtc) && !fireTimeUtc.isAfter(w.endUtc)) {
        return true;
      }
    }
    return false;
  }

  /// Returns all Sacred Time windows for the 14-day scheduling window.
  ///
  /// Results are cached until [invalidate] is called (or location/inIsrael
  /// changes).
  List<SacredWindow> getWindows({
    required SacredLocation? location,
    required bool inIsrael,
    required DateTime from,
    Duration span = const Duration(days: 14),
  }) {
    if (location == null) return const [];
    return _getOrComputeWindows(
      location: location,
      inIsrael: inIsrael,
      from: from,
    );
  }

  List<SacredWindow> _getOrComputeWindows({
    required SacredLocation location,
    required bool inIsrael,
    required DateTime from,
  }) {
    // Cache hit: same location + inIsrael.
    if (_cachedWindows != null &&
        _cachedLat == location.latitude &&
        _cachedLong == location.longitude &&
        _cachedInIsrael == inIsrael) {
      return _cachedWindows!;
    }

    // Cache miss: recompute over a wide span (18 days) so all possible
    // fire-times in the batch are covered regardless of [from].
    _cachedWindows = _service.computeWindows(
      latitude: location.latitude,
      longitude: location.longitude,
      inIsrael: inIsrael,
      from: from,
      span: _span,
    );
    _cachedLat = location.latitude;
    _cachedLong = location.longitude;
    _cachedInIsrael = inIsrael;
    return _cachedWindows!;
  }
}
