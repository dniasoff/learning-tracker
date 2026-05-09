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
}

/// Thrown when attempting to create more than 10 profiles per account.
class MaxProfilesExceededException implements Exception {
  final int accountId;
  const MaxProfilesExceededException(this.accountId);

  @override
  String toString() =>
      'MaxProfilesExceededException: Account $accountId already has 10 profiles';
}

/// Thrown when a profile with the same name (case-insensitive) already exists
/// for the account.
/// Thrown when attempting to delete the last remaining profile.
class LastProfileException implements Exception {
  const LastProfileException();

  @override
  String toString() =>
      'LastProfileException: Cannot delete the last profile — at least one must exist';
}

class DuplicateProfileNameException implements Exception {
  final String displayName;
  const DuplicateProfileNameException(this.displayName);

  @override
  String toString() =>
      'DuplicateProfileNameException: A profile named "$displayName" already exists';
}
