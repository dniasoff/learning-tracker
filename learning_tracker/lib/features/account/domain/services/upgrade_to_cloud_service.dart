import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/core/utils/firebase_error_code.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/domain/services/password_hasher.dart';

/// Thrown when the email is already in use by an existing Firebase
/// account. UI layer must enter the guided merge flow — see v2 §4.3.
class EmailCollisionException extends ConflictException {
  const EmailCollisionException(this.email) : super('$email is already in use');
  final String email;
}

/// Thrown when the password supplied for the upgrade does not match
/// the local-born account's stored argon2id hash.
class UpgradePasswordMismatchException extends PermissionException {
  const UpgradePasswordMismatchException()
    : super('Password does not match local account');
}

/// Thrown when an upgrade account exists but email ownership has not been
/// verified yet. Caller should keep the account local-born, prompt the user
/// to verify via inbox link, and retry completion.
class UpgradeEmailNotVerifiedException extends ValidationException {
  const UpgradeEmailNotVerifiedException()
    : super('Email address has not been verified yet');
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
    required AuthRepository authRepository,
    PasswordHasher? hasher,
    this.registry,
    this.accountId,
  }) : _dao = dao,
       _auth = authRepository,
       _hasher = hasher ?? PasswordHasher();

  final UserProfileDao _dao;
  final AuthRepository _auth;
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
  ///   - Exception for other Firebase errors
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

    AppUser? signedInUser;
    try {
      final uid = await _auth.createUserAccount(profile.email, password);
      signedInUser = await _auth.reloadCurrentUser();
      if (signedInUser == null || !signedInUser.emailVerified) {
        await _auth.sendEmailVerification();
        await _auth.signOut();
        throw const UpgradeEmailNotVerifiedException();
      }
      return await _finalizeUpgrade(profile, uid);
    } catch (e) {
      final code = extractFirebaseCode(e);
      if (code == 'email-already-in-use') {
        // Retry path: user may already have started upgrade. If the existing
        // account can be signed in with the same password and is verified,
        // proceed; otherwise require verification or collision flow.
        try {
          signedInUser = await _auth.signInAndGetUser(profile.email, password);
        } catch (signInError) {
          final signInCode = extractFirebaseCode(signInError);
          if (signInCode == 'wrong-password' ||
              signInCode == 'invalid-credential' ||
              signInCode == 'user-not-found') {
            throw EmailCollisionException(profile.email);
          }
          rethrow;
        }

        final existing = await _auth.reloadCurrentUser();
        if (existing == null || !existing.emailVerified) {
          await _auth.sendEmailVerification();
          await _auth.signOut();
          throw const UpgradeEmailNotVerifiedException();
        }
        return await _finalizeUpgrade(profile, existing.uid);
      }
      rethrow;
    }
  }

  /// Register fresh cloud credentials for a CREDENTIAL-LESS local account
  /// (e.g. an offline account with a synthetic `@offline.local` email and no
  /// user-known password) — the "full sign-in at conversion" path.
  ///
  /// Unlike [upgrade] there is no local password to verify; the user supplies
  /// a real [email] + [password] now, a Firebase account is created with them,
  /// and the synthetic email is replaced. Throws [EmailCollisionException] (on
  /// the entered email) when that email already has a Firebase account — the
  /// caller resolves it via the merge flow, passing the entered email.
  Future<UserProfile> upgradeWithNewCredentials({
    required UserProfile profile,
    required String email,
    required String password,
  }) async {
    if (profile.tier != UserTier.localBorn.dbValue) {
      throw StateError(
        'upgradeWithNewCredentials() requires a local-born profile',
      );
    }
    final normalized = email.trim().toLowerCase();
    try {
      final uid = await _auth.createUserAccount(normalized, password);
      final signedIn = await _auth.reloadCurrentUser();
      if (signedIn == null || !signedIn.emailVerified) {
        await _auth.sendEmailVerification();
        await _auth.signOut();
        throw const UpgradeEmailNotVerifiedException();
      }
      return await _finalizeUpgrade(profile, uid, email: normalized);
    } catch (e) {
      final code = extractFirebaseCode(e);
      if (code == 'email-already-in-use') {
        throw EmailCollisionException(normalized);
      }
      rethrow;
    }
  }

  Future<UserProfile> _finalizeUpgrade(
    UserProfile profile,
    String uid, {
    String? email,
  }) async {
    final refreshed = await _auth.reloadCurrentUser();
    if (refreshed == null || !refreshed.emailVerified) {
      await _auth.sendEmailVerification();
      await _auth.signOut();
      throw const UpgradeEmailNotVerifiedException();
    }

    await _dao.upgradeLocalToCloud(
      profileId: profile.id,
      firebaseUid: refreshed.uid,
      updatedAt: DateTimeFactory.nowUtc(),
      email: email,
    );

    if (registry != null && accountId != null) {
      await registry!.updateAccountTier(
        accountId!,
        'cloudBorn',
        firebaseUid: refreshed.uid,
        email: email,
      );
    }

    return (await _dao.getUserProfileById(profile.id))!;
  }

  /// Completes a pending local→cloud upgrade after the user verified email
  /// out-of-band (e.g. inbox link opened the app on Sign-In).
  ///
  /// Signs into Firebase with the same [password] used for the local account.
  /// If Firebase has no account, credentials are wrong, or email is still
  /// unverified, signs out of Firebase and returns `null`. On success the
  /// local [UserProfile] row is flipped to [cloudBorn], the registry tier is
  /// updated when [registry]/[accountId] are set, and the Firebase session
  /// remains active for sync.
  Future<UserProfile?> tryFinalizeVerifiedCloudUpgrade({
    required UserProfile localProfile,
    required String password,
  }) async {
    if (localProfile.tier != UserTier.localBorn.dbValue) return null;
    try {
      await _auth.signInAndGetUser(localProfile.email, password);
      final refreshed = await _auth.reloadCurrentUser();
      if (refreshed == null || !refreshed.emailVerified) {
        await _auth.signOut();
        return null;
      }
      await _dao.upgradeLocalToCloud(
        profileId: localProfile.id,
        firebaseUid: refreshed.uid,
        updatedAt: DateTimeFactory.nowUtc(),
      );

      if (registry != null && accountId != null) {
        await registry!.updateAccountTier(
          accountId!,
          'cloudBorn',
          firebaseUid: refreshed.uid,
        );
      }

      return (await _dao.getUserProfileById(localProfile.id))!;
    } catch (_) {
      await _auth.signOut();
      return null;
    }
  }

  Future<void> resendUpgradeVerification({
    required UserProfile profile,
    required String password,
  }) async {
    if (profile.tier != UserTier.localBorn.dbValue) {
      throw StateError(
        'resendUpgradeVerification() requires local-born profile',
      );
    }
    final hash = profile.passwordHash;
    if (hash == null || !await _hasher.verify(password, hash)) {
      throw const UpgradePasswordMismatchException();
    }

    try {
      await _auth.signInAndGetUser(profile.email, password);
    } catch (e) {
      final code = extractFirebaseCode(e);
      if (code == 'wrong-password' ||
          code == 'invalid-credential' ||
          code == 'user-not-found') {
        throw EmailCollisionException(profile.email);
      }
      rethrow;
    }

    final refreshed = await _auth.reloadCurrentUser();
    if (refreshed != null && refreshed.emailVerified) {
      await _auth.signOut();
      return;
    }
    await _auth.sendEmailVerification();
    await _auth.signOut();
  }

  /// Collision-path resolution: sign in to the existing cloud
  /// account and adopt it as the user's identity. Local data handling
  /// (upload vs discard) is delegated to the caller — this service
  /// only handles the credential side.
  Future<AppUser?> signInToExistingCloud({
    required String email,
    required String password,
  }) {
    return _auth.signInAndGetUser(email, password);
  }

  /// Wipe the local-born profile on a "discard local" merge choice.
  /// Keeps the profile row but clears the password hash — the row
  /// itself will be replaced when the cloud profile is imported.
  Future<void> discardLocalCredentials(int profileId) async {
    // Targeted partial update — updateUserProfile() does update().replace(),
    // which requires a COMPLETE row and throws InvalidDataException for this
    // id+passwordHash-only companion (crashing the "discard local" merge path).
    await _dao.clearPasswordHash(profileId);
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
    String? cloudEmail,
  }) async {
    // Credential-less accounts pass the user-entered [cloudEmail]; others
    // reuse the local profile's real email.
    final email = cloudEmail ?? localProfile.email;
    await _auth.signInAndGetUser(email, cloudPassword);
    final refreshed = await _auth.reloadCurrentUser();
    if (refreshed == null || !refreshed.emailVerified) {
      await _auth.sendEmailVerification();
      await _auth.signOut();
      throw const UpgradeEmailNotVerifiedException();
    }
    await _dao.upgradeLocalToCloud(
      profileId: localProfile.id,
      firebaseUid: refreshed.uid,
      updatedAt: DateTimeFactory.nowUtc(),
      email: cloudEmail,
    );

    if (registry != null && accountId != null) {
      await registry!.updateAccountTier(
        accountId!,
        'cloudBorn',
        firebaseUid: refreshed.uid,
        email: cloudEmail,
      );
    }

    return (await _dao.getUserProfileById(localProfile.id))!;
  }

  /// Option B — "Keep cloud, discard local": sign in to the existing
  /// Firebase account, clear the local-born password hash, flip the
  /// profile to `cloudBorn`, and let the next sync pull down the
  /// authoritative cloud data.
  Future<UserProfile> executeKeepCloudDiscardLocal({
    required UserProfile localProfile,
    required String cloudPassword,
    String? cloudEmail,
  }) async {
    final email = cloudEmail ?? localProfile.email;
    await _auth.signInAndGetUser(email, cloudPassword);
    final refreshed = await _auth.reloadCurrentUser();
    if (refreshed == null || !refreshed.emailVerified) {
      await _auth.sendEmailVerification();
      await _auth.signOut();
      throw const UpgradeEmailNotVerifiedException();
    }
    await discardLocalCredentials(localProfile.id);
    await _dao.upgradeLocalToCloud(
      profileId: localProfile.id,
      firebaseUid: refreshed.uid,
      updatedAt: DateTimeFactory.nowUtc(),
      email: cloudEmail,
    );

    if (registry != null && accountId != null) {
      await registry!.updateAccountTier(
        accountId!,
        'cloudBorn',
        firebaseUid: refreshed.uid,
        email: cloudEmail,
      );
    }

    return (await _dao.getUserProfileById(localProfile.id))!;
  }
}
