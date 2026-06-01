/// Describes whether the live Firebase auth identity matches the active
/// in-app account.
///
/// The outbox addresses every Firestore path from the **active account
/// record's** uid (`authStateProvider.currentUser.firebaseUid`), but the
/// device has a single FirebaseAuth slot. After switching into a *second*
/// cloud account on the same device without re-authenticating, the live token
/// (`authRepository.currentUser.uid`) can still belong to a DIFFERENT account.
/// Every push is then denied — `cloud_firestore/permission-denied` on direct
/// writes, `firebase_functions/unauthenticated` on callable Cloud Functions —
/// because the security rules require `request.auth.uid == <path uid>`.
///
/// When [isMismatch] is true the outbox drain is skipped (so these doomed rows
/// do not burn their retry budget and dead-letter, silently wedging sync) and
/// the Backup & Sync banner prompts the user to sign in as [activeAccountEmail]
/// instead of showing the misleading "N rows stuck after 3+ attempts".
class SyncIdentityStatus {
  /// The live Firebase identity matches the active account (or there is no
  /// cloud session / no active-account uid to mismatch against) — sync may
  /// proceed normally.
  const SyncIdentityStatus.matched()
    : isMismatch = false,
      activeAccountEmail = null,
      signedInEmail = null;

  /// The live Firebase identity belongs to a different account than the one
  /// currently active in the app. Sync is paused until the user signs in as
  /// [activeAccountEmail].
  const SyncIdentityStatus.mismatched({
    required this.activeAccountEmail,
    required this.signedInEmail,
  }) : isMismatch = true;

  /// Whether the live token and the active account disagree.
  final bool isMismatch;

  /// Email of the active in-app account — the identity the user must sign in
  /// as for sync to resume. Null when [isMismatch] is false.
  final String? activeAccountEmail;

  /// Email of the currently-signed-in Firebase identity (the "wrong" one),
  /// shown so the user understands which account they are signed in as. Null
  /// when [isMismatch] is false or the live user exposes no email.
  final String? signedInEmail;
}
