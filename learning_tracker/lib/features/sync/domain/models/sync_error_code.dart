/// Stable, localizable failure category for [SyncStatus.error] and
/// [RestoreStatus.error] (EH-5).
///
/// This app ships EN + Hebrew. Domain/data errors must never carry a
/// pre-formatted human-readable message: an English sentence baked into a
/// sealed status type renders raw and un-RTL-shaped to Hebrew-locale users,
/// and routinely leaks exception class names, Firestore collection paths, or
/// SDK error codes that mean nothing to an end user. Presentation resolves
/// the user-facing string for each code through `AppLocalizations`/ARB.
enum SyncErrorCode {
  /// The operation exceeded its time budget.
  timeout,

  /// Firestore rejected the operation with a permission-denied error
  /// (expired/revoked session, rules rejection, identity mismatch).
  permissionDenied,

  /// The request was rejected because Firebase App Check could not attest the
  /// app (e.g. Play Integrity misconfigured/disabled, "Too many attempts", a
  /// permission-denied carrying an App Check context). This is a PERMANENT,
  /// non-retryable failure from the user's perspective — retrying the same
  /// pull cannot succeed until the app/install is verified again, so the
  /// presentation layer must NOT frame it as "temporarily unavailable, tap to
  /// retry". Distinct from [permissionDenied] (a bare rules/session rejection
  /// with no App Check signature).
  appCheck,

  /// Any other failure not covered by a more specific code.
  unknown,
}
