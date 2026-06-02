import 'package:google_sign_in/google_sign_in.dart';
import 'package:learning_tracker/core/auth/google_sign_in_gateway.dart';

/// Concrete [GoogleSignInGateway].
///
/// **This is the only file in `lib/` permitted to take a hard dependency on
/// `package:google_sign_in/google_sign_in.dart` for the credential-exchange
/// flow.** Presentation code may still import the SDK's *exception types*
/// (`GoogleSignInException`, `GoogleSignInExceptionCode`) to handle cancel /
/// interrupt; that's a leaky-but-pragmatic exception accepted by the audit
/// because there is no clean way to re-throw without a mirror enum.
class GoogleSignInGatewayImpl implements GoogleSignInGateway {
  GoogleSignInGatewayImpl({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;
  bool _initialized = false;

  /// Lazily initialize the Google SDK on first use.
  ///
  /// `google_sign_in` v7 requires `initialize()` before `authenticate()`.
  /// Doing this eagerly at startup crashed offline; deferring to first
  /// sign-in attempt is safe because `authenticate()` is itself online-only.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _googleSignIn.initialize();
    _initialized = true;
  }

  @override
  Future<GoogleSignInResult> authenticate() async {
    await _ensureInitialized();
    final account = await _googleSignIn.authenticate();
    final auth = account.authentication;
    return GoogleSignInResult(idToken: auth.idToken);
  }

  @override
  Future<GoogleSignInResult?> authenticateSilently() async {
    await _ensureInitialized();
    // v7 silent path. `attemptLightweightAuthentication` resolves the
    // last-authorized Google session WITHOUT any UI, and returns null (rather
    // than throwing) for canceled / interrupted / ui-unavailable cases.
    final future = _googleSignIn.attemptLightweightAuthentication();
    if (future == null) return null;
    final account = await future;
    if (account == null) return null;
    final auth = account.authentication;
    if (auth.idToken == null) return null;
    return GoogleSignInResult(idToken: auth.idToken);
  }

  @override
  Future<void> signOut() => _googleSignIn.signOut();
}
