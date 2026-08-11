/// Firestore account-repository adapter for the account feature.
///
/// Reaches the data ring (`firestoreAccountRepositoryProvider`,
/// `FirestoreAccountRepository`) from feature code that is NOT under
/// `data/repositories/` (presentation providers, domain services) — the
/// AD-23/AD-28 seam, same shape as `FirestoreProgressRepositoryAdapter`
/// (`features/progress/data/repositories/`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_account_repository.dart';
import 'package:learning_tracker/features/account/domain/models/account_entity.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';

/// Firestore-backed access to the `users/{uid}` account record.
///
/// Account-scoped: resolves `firestoreAccountRepositoryProvider`, which
/// returns `null` only while no device account is active yet — the same
/// "not ready yet" contract every provider in `repository_providers.dart`
/// documents. Reads are achievement/identity-shaped: a null backend here
/// means "we cannot establish the account record", which must never be
/// reported as success.
class FirestoreAccountRepositoryAdapter {
  FirestoreAccountRepositoryAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// Resolves the account repository, THROWING when no account is active —
  /// [AccountRepositoryNotReadyException] — rather than fabricating an
  /// account record. A caller that cannot prove the account is never told
  /// it exists.
  Future<FirestoreAccountRepository> _resolve() async {
    final repo = await _ref.read(firestoreAccountRepositoryProvider.future);
    if (repo == null) {
      throw const AccountRepositoryNotReadyException();
    }
    return repo;
  }

  /// Returns the account record for [firebaseUser], creating a placeholder
  /// `users/{uid}` document on first sign-in so downstream code has
  /// something to read. Idempotent — [FirestoreAccountRepository.createAccount]
  /// is a no-op when the document already exists.
  ///
  /// The email/displayName placeholders mirror the pre-rewrite sign-in path
  /// (`setCloudBornSessionFromFirebaseUser`): Firebase's values are the
  /// identity source of truth, and the account document records them once a
  /// real address/name exists.
  Future<AccountEntity> ensureAccountForFirebaseUser(
    AppUser firebaseUser,
  ) async {
    final repo = await _resolve();
    final existing = await repo.getAccount();
    if (existing != null) return existing;
    return repo.createAccount(
      displayName: firebaseUser.displayName ?? '',
      email: firebaseUser.email ?? '${firebaseUser.uid}@cloud.placeholder',
    );
  }
}

/// Thrown when `firestoreAccountRepositoryProvider` resolves to `null` (no
/// active device account yet). The caller must not treat the account as
/// existing or the session as established when it cannot resolve the record.
class AccountRepositoryNotReadyException implements Exception {
  const AccountRepositoryNotReadyException();

  @override
  String toString() => 'AccountRepositoryNotReadyException: no active device '
      'account — refusing to claim an account record exists.';
}
