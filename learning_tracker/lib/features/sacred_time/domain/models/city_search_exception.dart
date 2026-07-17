/// Stable, localizable failure category for [CitySearchException]
/// (EH-5, AUD-sacred_time-03).
///
/// Presentation resolves the user-facing string for each code through
/// `AppLocalizations`/ARB — never the underlying exception text.
enum CitySearchErrorCode {
  /// The bundled cities SQLite asset could not be extracted, opened, or
  /// queried (disk I/O failure, corrupted/missing asset, malformed DB).
  database,

  /// Any other failure not covered by a more specific code.
  unknown,
}

/// Thrown by [CitiesRepository] instead of letting a raw
/// `SqliteException`/`FileSystemException`/other I/O exception propagate to
/// `citySearchProvider` (and from there into `AsyncValue.error`) untyped
/// (EH-2, EH-5). [debugDetail] retains the original exception text for
/// logs/diagnostics only — it must never be rendered to the user.
class CitySearchException implements Exception {
  const CitySearchException(this.code, {this.debugDetail});

  final CitySearchErrorCode code;
  final String? debugDetail;

  @override
  String toString() => 'CitySearchException(code: $code)';
}
