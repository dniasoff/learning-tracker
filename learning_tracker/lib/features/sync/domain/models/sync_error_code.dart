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

  /// Any other failure not covered by a more specific code.
  unknown,
}
