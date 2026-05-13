/// Lightweight representation of the currently authenticated Firebase user.
///
/// Exposed by [AuthRepository.currentUser] and streamed by
/// [AuthRepository.onAuthStateChanged] so the rest of the app can
/// consume identity information without importing firebase_auth.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.emailVerified,
    required this.providers,
  });

  /// Firebase UID.
  final String uid;

  /// Primary email address, or null if unset (e.g. anonymous / phone-only).
  final String? email;

  /// Display name, or null if not set.
  final String? displayName;

  /// Whether the email address has been verified.
  final bool emailVerified;

  /// List of provider IDs linked to this account
  /// (e.g. 'password', 'google.com').
  final List<String> providers;

  @override
  String toString() =>
      'AppUser(uid: $uid, email: $email, emailVerified: $emailVerified)';
}
