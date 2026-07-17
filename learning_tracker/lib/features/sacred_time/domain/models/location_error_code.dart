/// Stable, localizable failure category for [LocationFetchError]
/// (EH-5, AUD-sacred_time-03).
///
/// This app ships EN + Hebrew. Domain/data errors must never carry a
/// pre-formatted human-readable message: an English `Exception.toString()`
/// baked into a result type renders raw and un-RTL-shaped to Hebrew-locale
/// users, and routinely leaks plugin/platform exception class names that mean
/// nothing to an end user. Presentation resolves the user-facing string for
/// each code through `AppLocalizations`/ARB. Mirrors the `SyncErrorCode`
/// reference fix (`lib/features/sync/domain/models/sync_error_code.dart`).
enum LocationErrorCode {
  /// The GPS fix (or the 15s `Geolocator.getCurrentPosition` time budget)
  /// timed out — the common indoor / poor-signal scenario.
  timeout,

  /// Any other failure not covered by a more specific code.
  unknown,
}
