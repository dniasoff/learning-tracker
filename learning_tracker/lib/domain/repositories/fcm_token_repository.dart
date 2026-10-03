/// The account-token port behind parent push (sub-tracks Story 4.7 /
/// DNI-515, AD-39).
///
/// Each install of the app that holds an unlocked parent PIN session keeps
/// one entry in its owning account's `users/{uid}.fcm_tokens` map:
/// `fcm_tokens[installId] = {token, updated_at}`. The `onChangeLogCreated`
/// trigger reads that map (only for the account that owns the learner) and
/// prunes entries FCM reports dead.
///
/// Implementations touch only `fcm_tokens[installId]` of the given owner's
/// account document — never another install's entry, never another field.
library;

/// The account an install's token belongs to.
///
/// [accountId] is the device-registry account id (which named Firebase app
/// writes); [uid] is that account's Firestore path uid (`users/{uid}`, AD-24),
/// the same uid the trigger finds in the change_log path. Captured when the
/// parent unlocks, so the token is removed from the right account even after
/// the device has switched to another one.
final class FcmTokenOwner {
  /// Creates an owner.
  const FcmTokenOwner({required this.accountId, required this.uid});

  /// Device-registry account id.
  final String accountId;

  /// Firestore path uid of the owning account.
  final String uid;

  @override
  bool operator ==(Object other) =>
      other is FcmTokenOwner &&
      other.accountId == accountId &&
      other.uid == uid;

  @override
  int get hashCode => Object.hash(accountId, uid);

  @override
  String toString() => 'FcmTokenOwner($accountId)';
}

/// Writes and removes one install's FCM token on its owner account.
abstract interface class FcmTokenRepository {
  /// Sets `fcm_tokens[installId] = {token, updated_at: server time}` on
  /// [owner]'s account document, leaving every other entry untouched.
  Future<void> upsertToken(
    FcmTokenOwner owner, {
    required String installId,
    required String token,
  });

  /// Deletes `fcm_tokens[installId]` from [owner]'s account document. A
  /// missing entry is not an error.
  Future<void> removeToken(FcmTokenOwner owner, {required String installId});
}
