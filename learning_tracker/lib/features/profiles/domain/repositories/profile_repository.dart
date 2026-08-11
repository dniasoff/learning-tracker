import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';

/// Repository contract for profile operations.
///
/// AD-24: every profile is identified by its Firestore ULID
/// ([LearnerProfileEntity.profileId]) — there is no Drift-local
/// autoincrement int identity any more, and no separate account-scoping
/// parameter: every implementation is already scoped to the active account
/// (the `users/{uid}` path segment), matching
/// `FirestoreLearnerProfileRepository`.
abstract class ProfileRepository {
  /// All profiles for the active account.
  Future<List<LearnerProfileEntity>> getProfiles();

  /// Live updates for the active account's whole profile list.
  Stream<List<LearnerProfileEntity>> watchProfiles();

  /// Get a single profile by id, or `null` if it does not exist.
  Future<LearnerProfileEntity?> getProfileById(String profileId);

  /// Number of profiles under the active account.
  Future<int> countProfiles();

  /// Create a new profile. Enforces max 10 profiles per account and a
  /// case-insensitive unique display name.
  Future<LearnerProfileEntity> createProfile({
    required String displayName,
    required ProfileMode mode,
    String avatar = '',
  });

  /// Update an existing profile. Omitted fields keep their current value.
  Future<LearnerProfileEntity> updateProfile({
    required String profileId,
    String? displayName,
    ProfileMode? mode,
    String? avatar,
  });

  /// Delete a profile and all its Firestore subcollections (server-side
  /// recursive delete via the `deleteLearnerProfile` Cloud Function).
  ///
  /// By default throws [LastProfileException] when the deletion would leave
  /// the account with zero profiles. Set [allowLast] to `true` after an
  /// explicit "this will leave you with no profiles" confirmation.
  Future<void> deleteProfile(String profileId, {bool allowLast = false});
}

/// Thrown when a [ProfileRepository] call cannot resolve a backing Firestore
/// repository — no active account yet.
class ProfileRepositoryNotReadyException implements Exception {
  const ProfileRepositoryNotReadyException();

  @override
  String toString() =>
      'ProfileRepositoryNotReadyException: no active account — refusing to '
      'claim a profile list exists.';
}

/// Thrown when attempting to create more than 10 profiles per account.
class MaxProfilesExceededException extends ValidationException {
  const MaxProfilesExceededException()
    : super('This account already has 10 profiles');
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
