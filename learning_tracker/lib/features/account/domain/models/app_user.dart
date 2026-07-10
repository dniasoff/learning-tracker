import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';

/// Lightweight representation of the currently authenticated Firebase user.
///
/// Exposed by [AuthRepository.currentUser] and streamed by
/// [AuthRepository.onAuthStateChanged] so the rest of the app can
/// consume identity information without importing firebase_auth.
///
/// AUD-account-22: @freezed for generated value equality — this is the type
/// streamed by `firebaseAuthStateProvider` (`AsyncValue<AppUser?>`), so
/// `ref.watch`/`ref.listen` equality checks previously compared by reference
/// identity only.
@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    /// Firebase UID.
    required String uid,

    /// Primary email address, or null if unset (e.g. anonymous / phone-only).
    required String? email,

    /// Display name, or null if not set.
    required String? displayName,

    /// Whether the email address has been verified.
    required bool emailVerified,

    /// List of provider IDs linked to this account
    /// (e.g. 'password', 'google.com').
    required List<String> providers,
  }) = _AppUser;

  const AppUser._();

  @override
  String toString() =>
      'AppUser(uid: $uid, email: $email, emailVerified: $emailVerified)';
}
