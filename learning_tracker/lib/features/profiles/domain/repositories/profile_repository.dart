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
  ///
  /// [ulid] (P2-2): the profile's Firestore identity, minted eagerly
  /// BEFORE the local row is ever inserted — never left null and lazily
  /// backfilled on a later edit. Optional here, not required: the only
  /// production caller that ever supplies it is
  /// `FirestoreProfileRepositoryAdapter` (`profile_repository_impl.dart`),
  /// which lives in `data/repositories/` and is therefore the one place
  /// allowed to import `DocIds` (`check_dependency_direction.dart` / audit
  /// check 102 forbids that import everywhere else under `lib/features/**`).
  /// A caller that omits it (any bare `ProfileRepositoryImpl` construction,
  /// e.g. in tests) still gets one — the implementation mints a fallback
  /// rather than ever leaving the row's identity null.
  Future<ProfileModel> createProfile({
    required int accountId,
    required String displayName,
    required String mode,
    int avatarIndex = 0,
    String? ulid,
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
  ///
  /// [ulid] (P2-2): see [createProfile]'s doc comment — same optional,
  /// eager-mint-with-fallback contract, used only when this call actually
  /// creates the healed profile (the no-op fast path ignores it).
  Future<int> ensureDefaultProfile({
    required int accountId,
    required String defaultDisplayName,
    String? ulid,
  });

  /// Heals [id]'s remote Firestore mirror if it is missing (T-40) — a no-op
  /// for a local-only account. The replacement for the lazy backfill P2-2
  /// deleted: [createProfile]/[ensureDefaultProfile] already attempt this
  /// once, at creation, but that is exactly the instant a network outage
  /// would have caused the original failure, with no retry. Callers invoke
  /// this again at every profile ACTIVATION (see
  /// `FirestoreProfileRepositoryAdapter`'s class doc comment, "A profile
  /// created while offline still gets its remote document", for the real
  /// call path — `lib/app/router/app_shell.dart` fires it on every
  /// `selectedProfileIdProvider` change) so a profile whose document is
  /// still missing after creation keeps getting a fresh, idempotent attempt
  /// every time it is selected again, until one succeeds. Never throws —
  /// [id] not existing, or not yet carrying a `ulid` to heal onto, is a
  /// silent no-op, same as any other non-fatal Firestore push in this
  /// interface's implementations.
  Future<void> ensureRemoteProfile(int id);
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
