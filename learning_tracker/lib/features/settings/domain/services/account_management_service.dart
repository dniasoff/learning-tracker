import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/features/auth/domain/repositories/auth_repository.dart';

/// Service for account management operations:
/// sign out, delete account, change password, link providers.
class AccountManagementService {
  AccountManagementService({
    required AuthRepository authRepository,
    required AppDatabase database,
    required FirebaseFirestore firestore,
  }) : _authRepository = authRepository,
       _database = database,
       _firestore = firestore;

  final AuthRepository _authRepository;
  final AppDatabase _database;
  final FirebaseFirestore _firestore;

  /// Signs out the current user.
  ///
  /// Clears the auth session but preserves local data so the user
  /// can sign back in and see their data (FR102).
  Future<void> signOut() async {
    await _authRepository.signOut();
  }

  /// Deletes the current user's account and all associated data.
  ///
  /// Requires [reauthenticateWithEmail] or [reauthenticateWithGoogle]
  /// to be called first. Cascade:
  /// 1. Delete Firestore user document and subcollections
  /// 2. Delete Firebase Auth account
  /// 3. Clear local database (FR103)
  Future<void> deleteAccount(String uid) async {
    // 1. Delete Firestore data
    await _deleteFirestoreUserData(uid);

    // 2. Delete Firebase Auth account
    await _authRepository.deleteAccount();

    // 3. Clear local database
    await _clearLocalDatabase();
  }

  /// Changes the password for the current email/password user.
  ///
  /// Requires recent authentication (FR104).
  Future<void> changePassword(String newPassword) async {
    await _authRepository.changePassword(newPassword);
  }

  /// Re-authenticates the current user with email and password.
  Future<void> reauthenticateWithEmail(String email, String password) async {
    await _authRepository.reauthenticateWithEmail(email, password);
  }

  /// Re-authenticates the current user with Google.
  Future<void> reauthenticateWithGoogle() async {
    await _authRepository.reauthenticateWithGoogle();
  }

  /// Links a Google account to the current user (FR105).
  Future<void> linkGoogleProvider() async {
    await _authRepository.linkGoogleProvider();
  }

  /// Links an email/password credential to the current user (FR105).
  Future<void> linkEmailProvider(String email, String password) async {
    await _authRepository.linkEmailProvider(email, password);
  }

  /// Returns the list of provider IDs linked to the current user.
  List<String> getLinkedProviders() {
    return _authRepository.getLinkedProviders();
  }

  /// Deletes all Firestore data for the given user.
  Future<void> _deleteFirestoreUserData(String uid) async {
    try {
      final userDocRef = _firestore.collection('users').doc(uid);

      // Delete known subcollections
      const subcollections = ['completions', 'bookmarks', 'settings'];

      for (final sub in subcollections) {
        final snapshot = await userDocRef.collection(sub).get();
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
      }

      // Delete streak document
      await userDocRef.collection('streak').doc('current').delete();

      // Delete user document itself
      await userDocRef.delete();
    } catch (e, stack) {
      developer.log(
        'Failed to delete Firestore data for user $uid',
        error: e,
        stackTrace: stack,
        name: 'AccountManagementService',
      );
      // Still proceed with auth deletion and local cleanup
    }
  }

  /// Clears all data from the local database.
  Future<void> _clearLocalDatabase() async {
    // Delete all rows from all tables
    await _database.transaction(() async {
      await _database.delete(_database.syncQueue).go();
      await _database.delete(_database.completions).go();
      await _database.delete(_database.bookmarks).go();
      await _database.delete(_database.goals).go();
      await _database.delete(_database.learningOrder).go();
      await _database.delete(_database.rewards).go();
      await _database.delete(_database.streaks).go();
      await _database.delete(_database.pointConfigs).go();
      await _database.delete(_database.activeCurricula).go();
      await _database.delete(_database.userProfiles).go();
      await _database.delete(_database.textCache).go();
      await _database.delete(_database.textDownloadStatuses).go();
    });
  }
}
