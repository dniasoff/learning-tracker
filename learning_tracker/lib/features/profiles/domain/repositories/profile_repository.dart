import 'package:learning_tracker/core/exceptions/app_exception.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';

/// Repository contract for profile operations.
abstract class ProfileRepository {
  /// Get all profiles for an account.
  Future<List<ProfileModel>> getProfilesByAccount(int accountId);

  /// Get a single profile by ID.
  Future<ProfileModel?> getProfileById(int id);

  /// Create a new profile. Enforces max 10 profiles per account.
  /// Throws [MaxProfilesExceededException] if limit reached.
  Future<ProfileModel> createProfile({
    required int accountId,
    required String displayName,
    required String mode,
    int avatarIndex = 0,
  });

  /// Update an existing profile.
  Future<ProfileModel> updateProfile({
    required int id,
    String? displayName,
    String? mode,
    int? avatarIndex,
  });

  /// Delete a profile and all associated data (cascade).
  ///
  /// By default this throws [LastProfileException] when the deletion would
  /// leave the account with zero profiles, so accidental account-wipes via
  /// the picker / manage screen still surface a clear error. Set
  /// [allowLast] to `true` after presenting an explicit "this will leave
  /// you with no profiles" confirmation to actually remove the last row.
  Future<void> deleteProfile(int id, {bool allowLast = false});

  /// Count profiles for an account.
  Future<int> countProfilesForAccount(int accountId);

  /// Self-healing guarantee (BUG D1): ensure [accountId] owns at least one
  /// learner profile, returning the id that should be selected.
  ///
  /// When the account already has ≥1 (non-tutored) profile this is a no-op and
  /// the first profile's id is returned. When the account has ZERO profiles —
  /// the broken state that makes `activeProfileId` resolve to `0` and any
  /// `profile_id`-FK insert fail with `SqliteException(787)` — a default adult
  /// profile is created (named [defaultDisplayName]) and its id returned.
  ///
  /// As part of the heal, any orphaned `profile_id = 0` rows already present in
  /// this per-account database (e.g. a track created before a profile existed)
  /// are re-parented onto the new profile so existing data is preserved rather
  /// than stranded. Runs in a single transaction.
  Future<int> ensureDefaultProfile({
    required int accountId,
    required String defaultDisplayName,
  });
}

/// Thrown when attempting to create more than 10 profiles per account.
class MaxProfilesExceededException extends ValidationException {
  const MaxProfilesExceededException(this.accountId)
    : super('Account $accountId already has 10 profiles');
  final int accountId;
}

/// Thrown when attempting to delete the last remaining profile.
class LastProfileException extends ValidationException {
  const LastProfileException()
    : super('Cannot delete the last profile — at least one must exist');
}

/// Thrown when a profile with the same name (case-insensitive) already exists.
class DuplicateProfileNameException extends ConflictException {
  const DuplicateProfileNameException(this.displayName)
    : super('A profile named "$displayName" already exists');
  final String displayName;
}
