import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences keys for magic-link sign-in state.
///
/// We must persist the email between "request link" and "click link"
/// because the link itself only contains an opaque code; Firebase needs
/// the original email to complete sign-in.
const kMagicLinkPendingEmail = 'magic_link_pending_email';
const kMagicLinkPendingDisplayName = 'magic_link_pending_display_name';

/// Listens for incoming deep links and completes Firebase magic-link sign-in.
///
/// Per Epic 19 / DNI-188 / DNI-165 — replaces password-based account creation
/// with passwordless email-link authentication.
///
/// ## How it works
///
/// 1. User enters email in [AccountCreationScreen] and taps "Send link".
///    The screen calls [AuthRepository.sendSignInLinkToEmail] and persists
///    the email under [kMagicLinkPendingEmail].
/// 2. Firebase sends an email containing a one-time `https://...` link.
/// 3. User taps the link in their email app. Android routes the deep link
///    to MainActivity via the intent-filter in AndroidManifest.xml.
/// 4. [app_links] surfaces the link to this service, which:
///    - verifies it's a sign-in link via [AuthRepository.isSignInWithEmailLink],
///    - reads the persisted email,
///    - calls [AuthRepository.signInWithEmailLink] to complete sign-in,
///    - notifies the supplied [onSignedIn] callback so the auth state
///      can be promoted to cloud.
/// 5. Pending email is cleared on success or after a hard failure.
///
/// ## External setup required (not in code)
///
/// - Firebase Console → Authentication → Sign-in method →
///   enable "Email link (passwordless sign-in)".
/// - Firebase Console → Authentication → Settings → Authorized domains →
///   add the host used in [AuthRepositoryImpl.sendSignInLinkToEmail]
///   (currently `torah-study-tracker.firebaseapp.com`).
/// - The AndroidManifest already declares the matching intent-filter.
class MagicLinkService {
  MagicLinkService({
    required AuthRepository authRepository,
    required Future<void> Function(User user) onSignedIn,
    AppLinks? appLinks,
  }) : _authRepository = authRepository,
       _onSignedIn = onSignedIn,
       _appLinks = appLinks ?? AppLinks();

  final AuthRepository _authRepository;
  final Future<void> Function(User user) _onSignedIn;
  final AppLinks _appLinks;

  StreamSubscription<Uri>? _linkSubscription;
  bool _initialized = false;

  /// Begins listening for incoming deep links.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  /// Also processes any link that launched the app cold (`getInitialLink`).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Cold-start link: app was launched by tapping the email link.
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        await _handleIncomingLink(initial);
      }
    } catch (e, stack) {
      AppLogger.instance.handle(e, stack);
    }

    // Warm links: app was already running and brought to foreground by tap.
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleIncomingLink,
      onError: (Object e, StackTrace stack) {
        AppLogger.instance.handle(e, stack);
      },
    );
  }

  /// Cleans up resources — call from app teardown.
  Future<void> dispose() async {
    await _linkSubscription?.cancel();
    _linkSubscription = null;
    _initialized = false;
  }

  Future<void> _handleIncomingLink(Uri uri) async {
    final link = uri.toString();
    final mode = uri.queryParameters['mode'];
    if (mode == 'verifyEmail') {
      await _handleVerifyEmailLink(uri);
      return;
    }
    if (!_authRepository.isSignInWithEmailLink(link)) {
      // Not an auth link we care about. Ignore.
      return;
    }

    await _handleSignInLink(link);
  }

  Future<void> _handleSignInLink(String link) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(kMagicLinkPendingEmail);
    if (email == null || email.isEmpty) {
      // We received a sign-in link but have no record of which email
      // it belongs to. This usually means the link was opened on a
      // different device than the one that requested it.
      AppLogger.instance.handle(
        StateError(
          'Received magic-link sign-in but no pending email is stored. '
          'The link must be opened on the same device that requested it.',
        ),
        StackTrace.current,
      );
      return;
    }

    try {
      final credential = await _authRepository.signInWithEmailLink(email, link);
      final user = credential.user;
      if (user != null) {
        // Apply pending display name (if any) before promoting auth state.
        final pendingName = prefs.getString(kMagicLinkPendingDisplayName);
        if (pendingName != null && pendingName.isNotEmpty) {
          await user.updateDisplayName(pendingName);
        }
        await _onSignedIn(user);
      }
    } on FirebaseAuthException catch (e, stack) {
      AppLogger.instance.handle(e, stack);
    } finally {
      // Clear pending state regardless — a stale email is worse than none.
      await prefs.remove(kMagicLinkPendingEmail);
      await prefs.remove(kMagicLinkPendingDisplayName);
    }
  }

  Future<void> _handleVerifyEmailLink(Uri uri) async {
    final oobCode = uri.queryParameters['oobCode'];
    if (oobCode == null || oobCode.isEmpty) {
      AppLogger.instance.handle(
        StateError('Received verify-email link without oobCode'),
        StackTrace.current,
      );
      return;
    }
    try {
      await FirebaseAuth.instance.applyActionCode(oobCode);
      await FirebaseAuth.instance.currentUser?.reload();
    } on FirebaseAuthException catch (e, stack) {
      AppLogger.instance.handle(e, stack);
    }
  }
}
