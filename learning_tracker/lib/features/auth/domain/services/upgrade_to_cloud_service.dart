import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/auth/domain/services/password_hasher.dart';

/// Thrown when the email is already in use by an existing Firebase
/// account. UI layer must enter the guided merge flow — see v2 §4.3.
class EmailCollisionException implements Exception {
  const EmailCollisionException(this.email);
  final String email;
  @override
  String toString() => 'EmailCollisionException: $email';
}

/// Thrown when the password supplied for the upgrade does not match
/// the local-born account's stored argon2id hash.
class UpgradePasswordMismatchException implements Exception {
  const UpgradePasswordMismatchException();
  @override
  String toString() => 'UpgradePasswordMismatchException';
}

/// Domain service for the local → cloud upgrade flow (v2 §4.3).
///
/// One-way only. Verifies the user's local-born credentials first,
/// creates a Firebase user, and atomically flips the `tier` +
/// `firebaseUid` + `passwordHash` columns in a single transaction
/// via [UserProfileDao.upgradeLocalToCloud].
///
/// Data migration (pushing local rows into Firestore) is handled
/// separately by SyncEngine once the tier flip completes — this
/// service keeps the responsibility boundary narrow.
class UpgradeToCloudService {
  UpgradeToCloudService({
    required UserProfileDao dao,
    required FirebaseAuth firebaseAuth,
    PasswordHasher? hasher,
    this.registry,
    this.accountId,
  })  : _dao = dao,
        _auth = firebaseAuth,
        _hasher = hasher ?? PasswordHasher();

  final UserProfileDao _dao;
  final FirebaseAuth _auth;
  final PasswordHasher _hasher;

  /// Epic 21.12: optional registry + accountId for multi-account
  /// context. When provided, the upgrade also updates the device
  /// registry tier + firebaseUid so the account picker reflects
  /// the change.
  final DeviceRegistryDatabase? registry;
  final String? accountId;

  /// Attempts to upgrade [profile] to a cloud-born account.
  ///
  /// Throws:
  ///   - [UpgradePasswordMismatchException] if [password] doesn't
  ///     match the existing argon2id hash on [profile]
  ///   - [EmailCollisionException] if Firebase reports the email is
  ///     already in use — caller must enter the merge flow
  ///   - [FirebaseAuthException] for other Firebase errors
  Future<UserProfile> upgrade({
    required UserProfile profile,
    required String password,
  }) async {
    if (profile.tier != UserTier.localBorn.dbValue) {
      throw StateError('upgrade() requires a local-born profile');
    }
    final hash = profile.passwordHash;
    if (hash == null || !await _hasher.verify(password, hash)) {
      throw const UpgradePasswordMismatchException();
    }

    UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: profile.email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw EmailCollisionException(profile.email);
      }
      rethrow;
    }

    final firebaseUid = credential.user!.uid;
    await _dao.upgradeLocalToCloud(
      profileId: profile.id,
      firebaseUid: firebaseUid,
      updatedAt: DateTime.now().toUtc(),
    );

    // Epic 21.12: also update the device registry so the account
    // picker shows the cloud badge after upgrade.
    if (registry != null && accountId != null) {
      await registry!.updateAccountTier(
        accountId!,
        'cloudBorn',
        firebaseUid: firebaseUid,
      );
    }

    return (await _dao.getUserProfileById(profile.id))!;
  }

  /// Collision-path resolution: sign in to the existing cloud
  /// account and adopt it as the user's identity. Local data handling
  /// (upload vs discard) is delegated to the caller — this service
  /// only handles the credential side.
  Future<UserCredential> signInToExistingCloud({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Wipe the local-born profile on a "discard local" merge choice.
  /// Keeps the profile row but clears the password hash — the row
  /// itself will be replaced when the cloud profile is imported.
  Future<void> discardLocalCredentials(int profileId) async {
    await _dao.updateUserProfile(
      UserProfilesCompanion(
        id: Value(profileId),
        passwordHash: const Value(null),
      ),
    );
  }

  // ───── Collision path execution (v2 §4.3 merge options) ─────

  /// Option A — "Upload local into cloud": sign in to the existing
  /// Firebase account, flip the local profile to `cloudBorn` keyed
  /// on the existing `firebaseUid`, and rely on SyncEngine's push
  /// pipeline to merge local data up via the merge rules.
  ///
  /// No data is deleted. Conflicts on specific rows resolve via
  /// LWW / merge-forward naturally once the sync engine runs its
  /// first push.
  Future<UserProfile> executeUploadLocalIntoCloud({
    required UserProfile localProfile,
    required String cloudPassword,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: localProfile.email,
      password: cloudPassword,
    );
    await _dao.upgradeLocalToCloud(
      profileId: localProfile.id,
      firebaseUid: credential.user!.uid,
      updatedAt: DateTime.now().toUtc(),
    );
    return (await _dao.getUserProfileById(localProfile.id))!;
  }

  /// Option B — "Keep cloud, discard local": sign in to the existing
  /// Firebase account, clear the local-born password hash, flip the
  /// profile to `cloudBorn`, and let the next sync pull down the
  /// authoritative cloud data.
  Future<UserProfile> executeKeepCloudDiscardLocal({
    required UserProfile localProfile,
    required String cloudPassword,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: localProfile.email,
      password: cloudPassword,
    );
    await discardLocalCredentials(localProfile.id);
    await _dao.upgradeLocalToCloud(
      profileId: localProfile.id,
      firebaseUid: credential.user!.uid,
      updatedAt: DateTime.now().toUtc(),
    );
    return (await _dao.getUserProfileById(localProfile.id))!;
  }
}
