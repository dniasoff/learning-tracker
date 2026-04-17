import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart'
    show kOnboardingComplete;
import 'package:shared_preferences/shared_preferences.dart';

/// Service for account management operations:
/// sign out, delete account, change password, link providers.
class AccountManagementService {
  AccountManagementService({
    required AuthRepository authRepository,
    required UserDatabase database,
    required FirebaseFirestore firestore,
  }) : _authRepository = authRepository,
       _database = database,
       _firestore = firestore;

  final AuthRepository _authRepository;
  final UserDatabase _database;
  final FirebaseFirestore _firestore;

  /// Soft sign-out — clears the in-app session so the user sees the
  /// account picker on next launch, but leaves Firebase's cached
  /// refresh token in place. That's what lets Epic 21.9 AC2 (tap the
  /// tile → dashboard in < 200ms) actually work: without a cached
  /// session the picker would always fall through to the sign-in
  /// page instead of resuming.
  ///
  /// The hard sign-out (clearing the Firebase token) happens when the
  /// account is removed or deleted — see
  /// [AccountLifecycleService.removeCloudFromDevice] /
  /// [AccountLifecycleService.deleteCloudAccount].
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kOnboardingComplete);
    // Clear transient onboarding/add-track state
    for (final key in [
      'onboarding_phase',
      'onboarding_profile_id',
      'onboarding_profile_name',
      'onboarding_profile_mode',
      'onboarding_language',
      'add_track_step',
      'add_track_curriculum',
      'add_track_scope',
      'add_track_program',
      'add_track_program_name',
      'add_track_study_days',
      'add_track_label',
    ]) {
      await prefs.remove(key);
    }
  }

  /// Deletes the current user's account and all associated data.
  ///
  /// Requires [reauthenticateWithEmail] or [reauthenticateWithGoogle]
  /// to be called first. Cascade:
  /// 1. Delete Firestore user document and subcollections
  /// 2. Delete Firebase Auth account
  /// 3. Clear local database (FR103)
  /// 4. Clear SharedPreferences
  Future<void> deleteAccount(String uid) async {
    // 1. Delete Firestore data
    await _deleteFirestoreUserData(uid);

    // 2. Delete Firebase Auth account
    await _authRepository.deleteAccount();

    // 3. Clear local database
    await _clearLocalDatabase();

    // 4. Clear all local preferences (onboarding state, settings, etc.)
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
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
  ///
  /// Handles both profile-scoped collections (`users/{uid}/profiles/{pid}/...`)
  /// and legacy flat collections (`users/{uid}/...`).
  /// A server-side Cloud Function (`onUserDeleted`) also performs this cascade
  /// when a user is deleted from Firebase Auth outside the app.
  Future<void> _deleteFirestoreUserData(String uid) async {
    try {
      final userDocRef = _firestore.collection('users').doc(uid);

      const profileSubcollections = [
        'completions',
        'bookmarks',
        'settings',
        'goals',
        'rewards',
        'learning_ledger',
        'active_curricula',
        'curriculum_imports',
      ];

      // 1. Delete profile-scoped data
      final profilesSnapshot = await userDocRef.collection('profiles').get();
      for (final profileDoc in profilesSnapshot.docs) {
        for (final sub in profileSubcollections) {
          final subSnapshot = await profileDoc.reference.collection(sub).get();
          for (final doc in subSnapshot.docs) {
            await doc.reference.delete();
          }
        }
        // Delete streak/data and active_curricula/data within profile
        await profileDoc.reference.collection('streak').doc('data').delete();
        await profileDoc.reference
            .collection('active_curricula')
            .doc('data')
            .delete();
        // Delete the profile document itself
        await profileDoc.reference.delete();
      }

      // 2. Delete legacy flat subcollections
      const legacySubcollections = [...profileSubcollections, 'profile'];

      for (final sub in legacySubcollections) {
        final snapshot = await userDocRef.collection(sub).get();
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
      }

      // Delete legacy streak document
      await userDocRef.collection('streak').doc('current').delete();

      // 3. Delete user document itself
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
  ///
  /// Deletes all rows from every table in the user database.
  /// Order matters: child tables (with FK references) before parent tables.
  Future<void> _clearLocalDatabase() async {
    await _database.transaction(() async {
      // Child / leaf tables first
      await _database.delete(_database.syncQueue).go();
      await _database.delete(_database.completions).go();
      await _database.delete(_database.bookmarks).go();
      await _database.delete(_database.learningLedger).go();
      await _database.delete(_database.learningOrder).go();
      await _database.delete(_database.goals).go();
      await _database.delete(_database.rewards).go();
      await _database.delete(_database.rewardPoolItems).go();
      await _database.delete(_database.rewardPools).go();
      await _database.delete(_database.streaks).go();
      await _database.delete(_database.pointConfigs).go();
      await _database.delete(_database.stageDefinitions).go();
      await _database.delete(_database.studyDayConfigs).go();
      await _database.delete(_database.curriculumScopes).go();
      await _database.delete(_database.profilePrograms).go();
      await _database.delete(_database.testScores).go();
      await _database.delete(_database.textDownloadStatuses).go();
      // Parent tables
      await _database.delete(_database.curriculumTracks).go();
      await _database.delete(_database.activeCurricula).go();
      await _database.delete(_database.profiles).go();
      await _database.delete(_database.userProfiles).go();
    });
  }
}
