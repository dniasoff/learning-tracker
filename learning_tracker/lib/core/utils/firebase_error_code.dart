/// Extracts a Firebase error code from an exception's string
/// representation, without importing `firebase_auth`/`cloud_firestore`.
///
/// Rule 3 (see docs/coding-standards.md) confines those packages to
/// `lib/core/sync/` and `lib/core/auth/`/`lib/features/auth/`. Every other
/// layer that needs to react to a specific Firebase error code (map it to a
/// localized message, branch on `email-already-in-use`, etc.) has to fall
/// back to parsing `Object.toString()` instead of reading the typed `.code`
/// field — this helper is that parser, kept in one place so the regex is
/// fixed once instead of drifting across copies.
///
/// `FirebaseException.toString()` renders as `[<plugin>/<code>] <message>`
/// (e.g. `[firebase_auth/email-already-in-use] The email address is already
/// in use...`). Earlier duplicated copies of this helper (AUD-account-04,
/// AUD-account-10) used `RegExp(r'\[([a-z-]+)\]')`, which never matches that
/// shape: the plugin segment contains an underscore and a slash, neither of
/// which the character class allowed, so every real Firebase error silently
/// fell through to the generic error message. This pattern captures only the
/// trailing code segment, with the `<plugin>/` prefix optional so the bare
/// `[<code>]` shape (used by some SDK paths) still matches too.
String? extractFirebaseCode(Object e) {
  final match = RegExp(r'\[(?:[a-z_]+/)?([a-z-]+)\]').firstMatch(e.toString());
  return match?.group(1);
}
