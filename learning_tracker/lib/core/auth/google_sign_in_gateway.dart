/// Plain Dart DTO returned by [GoogleSignInGateway.authenticate].
///
/// Carries the single field the rest of the app needs from a Google
/// authentication round-trip — the OAuth `idToken` to exchange with Firebase
/// for a credential. No `GoogleSignInAccount` / `GoogleSignInAuthentication`
/// types are exposed outside `lib/core/auth/`.
class GoogleSignInResult {
  const GoogleSignInResult({required this.idToken});

  /// OAuth ID token from the Google sign-in flow. May be `null` if the
  /// platform returned no token (this is treated as an auth failure by the
  /// caller).
  final String? idToken;
}

/// Thin facade around `package:google_sign_in/google_sign_in.dart`.
///
/// **This is the public seam between the rest of the app and the Google
/// Sign-In SDK.** Production code outside `lib/core/auth/` should consume
/// Google sign-in via this interface; the concrete implementation in
/// [GoogleSignInGatewayImpl] (`google_sign_in_gateway_impl.dart`) is the
/// only file allowed to import `package:google_sign_in/google_sign_in.dart`.
///
/// Note: The Google SDK still throws `GoogleSignInException` to callers
/// (e.g. for canceled / interrupted flows). Catching that is unavoidable
/// without re-mapping every exception code, so a small number of UI files
/// continue to import the exception class. The gateway hides the *happy
/// path* — credential exchange and sign-out — which is the part that
/// matters for the layering audit.
abstract class GoogleSignInGateway {
  /// Run the Google sign-in flow and return the resulting [GoogleSignInResult].
  ///
  /// Throws `GoogleSignInException` from the underlying SDK on cancel /
  /// interrupt / failure — callers in presentation/UI code may catch and
  /// inspect that type via its own import.
  Future<GoogleSignInResult> authenticate();

  /// Attempt a SILENT (no-UI) Google sign-in.
  ///
  /// Returns a [GoogleSignInResult] if a previously-authorized Google session
  /// can be resolved without showing any UI, or `null` if no such session is
  /// available (in which case the caller should fall back to the interactive
  /// [authenticate]).
  ///
  /// Limitation: this resolves the *last-authorized* Google account only
  /// (`google_sign_in` v7 `attemptLightweightAuthentication`). It will NOT
  /// silently switch to a different, not-currently-cached Google account — that
  /// still requires the interactive picker. Never shows UI; never throws for
  /// the cancel / interrupt / ui-unavailable cases (returns `null` instead).
  Future<GoogleSignInResult?> authenticateSilently();

  /// Sign out from Google. Safe to call when not signed in.
  Future<void> signOut();
}
