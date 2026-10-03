/// Firestore implementation of the parent-push token port (sub-tracks Story
/// 4.7 / DNI-515, AD-39): `users/{uid}.fcm_tokens[installId]`.
///
/// The only Firestore access of the parent-push path lives here (AD-3 / AD-28
/// confinement); `lib/features/notifications/` reaches it through
/// [fcmTokenRepositoryProvider] and [currentFcmTokenOwnerProvider].
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/firestore/account_firebase_providers.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/write_ack.dart';
import 'package:learning_tracker/domain/repositories/fcm_token_repository.dart';

/// Field of the account document that holds the install → token map.
const String kFcmTokensField = 'fcm_tokens';

/// Resolves the Firestore handle of a device account (its named app), so a
/// token is written and removed with the owning account's own session even
/// after the device has switched to another account.
typedef AccountFirestoreResolver =
    Future<FirebaseFirestore> Function(String accountId);

/// `users/{uid}.fcm_tokens[installId] = {token, updated_at}` — field-level
/// writes of this install's entry only (owner-only by `firestore.rules`
/// `match /users/{uid}`).
///
/// Writes are bounded by [FirestoreWriteAck.orQueuedOffline]: an offline
/// lock queues the delete and returns, so it never blocks the lock path.
class FirestoreFcmTokenRepository implements FcmTokenRepository {
  /// Creates the repository over [firestoreFor].
  FirestoreFcmTokenRepository({required AccountFirestoreResolver firestoreFor})
    : _firestoreFor = firestoreFor;

  final AccountFirestoreResolver _firestoreFor;

  Future<DocumentReference<Map<String, dynamic>>> _account(
    FcmTokenOwner owner,
  ) async =>
      (await _firestoreFor(owner.accountId)).collection('users').doc(owner.uid);

  @override
  Future<void> upsertToken(
    FcmTokenOwner owner, {
    required String installId,
    required String token,
  }) async {
    final ref = await _account(owner);
    // A nested map under merge touches only this install's entry; the
    // account doc always exists for a signed-in owner, and set-merge keeps
    // this from failing if it does not yet.
    await ref.set({
      kFcmTokensField: {
        installId: {'token': token, 'updated_at': FieldValue.serverTimestamp()},
      },
    }, SetOptions(merge: true)).orQueuedOffline;
  }

  @override
  Future<void> removeToken(
    FcmTokenOwner owner, {
    required String installId,
  }) async {
    final ref = await _account(owner);
    await ref.set({
      kFcmTokensField: {installId: FieldValue.delete()},
    }, SetOptions(merge: true)).orQueuedOffline;
  }
}

/// The parent-push token repository, resolving each owner account's own
/// named Firebase app.
final fcmTokenRepositoryProvider = Provider<FcmTokenRepository>((ref) {
  final registry = ref.watch(accountFirebaseRegistryProvider);
  return FirestoreFcmTokenRepository(
    firestoreFor: (accountId) async =>
        (await registry.resolve(accountId)).firestore,
  );
});

/// The active account as a token owner — its registry id and AD-24 path uid —
/// or null when no account is active. Read once at parent unlock.
final currentFcmTokenOwnerProvider = FutureProvider<FcmTokenOwner?>((
  ref,
) async {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  final handles = await ref.watch(activeAccountFirebaseProvider.future);
  if (handles == null) return null;
  return FcmTokenOwner(accountId: accountId, uid: handles.uid);
}, retry: (retryCount, error) => null);
