import 'dart:developer' as developer;

import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

/// Callback type for pushing user profile data to Firestore.
typedef PushUserProfile =
    Future<void> Function({
      required String firebaseUid,
      required String displayName,
      required String userMode,
    });

/// Gateway-based Firestore push implementation.
///
/// Replaces [createFirestorePush] — uses the [FirestoreGateway] seam so
/// `cloud_firestore` types do not leak into feature code.
PushUserProfile createFirestorePushFromGateway(FirestoreGateway? gateway) {
  return ({
    required String firebaseUid,
    required String displayName,
    required String userMode,
  }) async {
    if (gateway == null) return;
    await gateway.pushAccountUserProfile(
      uid: firebaseUid,
      data: {
        'displayName': displayName,
        'userMode': userMode,
      },
    );
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
