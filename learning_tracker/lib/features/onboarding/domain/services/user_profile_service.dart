import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

/// Callback type for pushing account display-name updates to Firestore.
///
/// WS9.flows: formerly also pushed [userMode] (vestigial Account-level field,
/// now removed). Mode is synced via the [LearnerProfiles] subcollection.
typedef PushUserProfile =
    Future<void> Function({
      required String firebaseUid,
      required String displayName,
    });

/// Gateway-based Firestore push implementation for display-name updates.
PushUserProfile createFirestorePushFromGateway(FirestoreGateway? gateway) {
  return ({
    required String firebaseUid,
    required String displayName,
  }) async {
    if (gateway == null) return;
    await gateway.pushAccountUserProfile(
      uid: firebaseUid,
      data: {'displayName': displayName},
    );
  };
}

/// Service for managing account-level profile persistence (local + Firestore).
///
/// WS9.flows: [setUserMode] and [getUserMode] removed — mode is not an
/// account-level concept; it lives in [LearnerProfiles.mode] and is read via
/// [dashboardUserModeProvider].
class UserProfileService {
  UserProfileService({
    required UserProfileDao userProfileDao,
    required PushUserProfile pushUserProfile,
  }) : _userProfileDao = userProfileDao,
       _pushUserProfile = pushUserProfile;

  final UserProfileDao _userProfileDao;
  final PushUserProfile _pushUserProfile;

  /// Updates the display name for [firebaseUid] in both SQLite and Firestore.
  Future<void> updateDisplayName({
    required String firebaseUid,
    required String displayName,
  }) async {
    final now = DateTimeFactory.nowLocal();

    await _userProfileDao.upsertProfile(
      firebaseUid: firebaseUid,
      displayName: displayName,
      updatedAt: now,
    );

    await _pushUserProfile(
      firebaseUid: firebaseUid,
      displayName: displayName,
    );
  }
}
