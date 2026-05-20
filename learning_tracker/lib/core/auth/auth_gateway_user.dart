/// Plain Dart DTO returned by the auth gateway (`FirebaseAuthGateway`).
///
/// Carries only the identity fields the rest of the app needs and contains
/// **no** Firebase symbols, so callers can sit on it without dragging in
/// `package:firebase_auth/firebase_auth.dart`.
///
/// Features layer wraps this in its own `AppUser` model — that mapping is
/// the only place `AuthGatewayUser` is converted. Keep this class small and
/// stable; if a new identity field is needed, prefer adding it here over
/// exposing the underlying `User` object.
class AuthGatewayUser {
  const AuthGatewayUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.emailVerified,
    required this.providers,
  });

  /// Firebase UID — the stable identifier across sessions.
  final String uid;

  /// Primary email address, or null if unset (e.g. anonymous / phone-only).
  final String? email;

  /// Display name set on the Firebase account, or null if not set.
  final String? displayName;

  /// Whether the email address has been verified by the user.
  final bool emailVerified;

  /// Provider IDs linked to this account (e.g. `'password'`, `'google.com'`).
  final List<String> providers;

  @override
  String toString() =>
      'AuthGatewayUser(uid: $uid, email: $email, emailVerified: $emailVerified)';
}
