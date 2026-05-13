import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

/// Callback type for pushing user profile data to Firestore.
typedef PushUserProfile =
    Future<void> Function({
      required String firebaseUid,
      required String displayName,
      required String userMode,
    });

/// Default Firestore push implementation.
PushUserProfile createFirestorePush(FirebaseFirestore firestore) {
  return ({
    required String firebaseUid,
    required String displayName,
    required String userMode,
  }) async {
    await firestore.collection('users').doc(firebaseUid).set({
      'displayName': displayName,
      'userMode': userMode,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  };
}

/// Service for managing user profile persistence (local + Firestore).
class UserProfileService {
  UserProfileService({
    required UserProfileDao userProfileDao,
    required PushUserProfile pushUserProfile,
  }) : _userProfileDao = userProfileDao,
       _pushUserProfile = pushUserProfile;

  final UserProfileDao _userProfileDao;
  final PushUserProfile _pushUserProfile;

  /// Persists the selected [UserMode] for the given user.
  ///
  /// Writes to both local SQLite (via Drift) and Firestore.
  Future<void> setUserMode({
    required String firebaseUid,
    required String displayName,
    required UserMode mode,
  }) async {
    final now = DateTimeFactory.nowLocal();
    final modeString = mode.name;

    // Write to local database
    await _userProfileDao.upsertProfile(
      firebaseUid: firebaseUid,
      displayName: displayName,
      userMode: modeString,
      updatedAt: now,
    );

    // Write to Firestore (best-effort; local DB is source of truth)
    try {
      await _pushUserProfile(
        firebaseUid: firebaseUid,
        displayName: displayName,
        userMode: modeString,
      );
    } catch (e, stack) {
      developer.log(
        'Firestore push failed for user $firebaseUid',
        error: e,
        stackTrace: stack,
        name: 'UserProfileService',
      );
    }
  }

  /// Gets the current [UserMode] for the given user, or null if not set.
  Future<UserMode?> getUserMode(String firebaseUid) async {
    final profile = await _userProfileDao.getUserProfileByFirebaseUid(
      firebaseUid,
    );
    if (profile == null) return null;
    return UserMode.values.where((m) => m.name == profile.userMode).firstOrNull;
  }
}
