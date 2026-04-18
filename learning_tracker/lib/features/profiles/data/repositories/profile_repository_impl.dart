import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';

/// Implementation of [ProfileRepository] using Drift database.
class ProfileRepositoryImpl implements ProfileRepository {
  final UserDatabase _db;

  ProfileRepositoryImpl(this._db);

  static const int maxProfilesPerAccount = 10;

  @override
  Future<List<ProfileModel>> getProfilesByAccount(int accountId) async {
    final rows = await _db.profileDao.getProfilesByAccount(accountId);
    return rows.map(ProfileModel.fromDriftRow).toList();
  }

  @override
  Future<ProfileModel?> getProfileById(int id) async {
    final row = await _db.profileDao.getProfileById(id);
    return row != null ? ProfileModel.fromDriftRow(row) : null;
  }

  @override
  Future<ProfileModel> createProfile({
    required int accountId,
    required String displayName,
    required String mode,
    int avatarIndex = 0,
  }) async {
    final trimmedName = displayName.trim();

    final count = await _db.profileDao.countProfilesForAccount(accountId);
    if (count >= maxProfilesPerAccount) {
      throw MaxProfilesExceededException(accountId);
    }

    // Case-insensitive duplicate name check
    final nameExists = await _db.profileDao.profileExistsByName(
      accountId,
      trimmedName,
    );
    if (nameExists) {
      throw DuplicateProfileNameException(trimmedName);
    }

    final now = DateTime.now().toUtc();
    final id = await _db.profileDao.insertProfile(
      ProfilesCompanion.insert(
        accountId: accountId,
        displayName: trimmedName,
        mode: mode,
        avatarIndex: Value(avatarIndex),
        createdAt: now,
        updatedAt: now,
      ),
    );

    return ProfileModel(
      id: id,
      accountId: accountId,
      displayName: trimmedName,
      mode: mode,
      avatarIndex: avatarIndex,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<ProfileModel> updateProfile({
    required int id,
    String? displayName,
    String? mode,
    int? avatarIndex,
  }) async {
    final existing = await _db.profileDao.getProfileById(id);
    if (existing == null) {
      throw StateError('Profile $id not found');
    }

    // Case-insensitive duplicate name check (excluding self)
    if (displayName != null) {
      final trimmedName = displayName.trim();
      final nameExists = await _db.profileDao.profileExistsByName(
        existing.accountId,
        trimmedName,
        excludeId: id,
      );
      if (nameExists) {
        throw DuplicateProfileNameException(trimmedName);
      }
    }

    final trimmedDisplayName = displayName?.trim();
    final now = DateTime.now().toUtc();
    await (_db.update(_db.profiles)..where((t) => t.id.equals(id))).write(
      ProfilesCompanion(
        displayName: trimmedDisplayName != null
            ? Value(trimmedDisplayName)
            : const Value.absent(),
        mode: mode != null ? Value(mode) : const Value.absent(),
        avatarIndex: avatarIndex != null
            ? Value(avatarIndex)
            : const Value.absent(),
        updatedAt: Value(now),
      ),
    );

    final updated = await _db.profileDao.getProfileById(id);
    return ProfileModel.fromDriftRow(updated!);
  }

  @override
  Future<void> deleteProfile(int id) async {
    // Guard: cannot delete the last profile
    final count = await countProfilesForAccount(1);
    if (count <= 1) {
      throw const LastProfileException();
    }

    await _db.transaction(() async {
      // Cascade delete all associated data
      await (_db.delete(
        _db.completions,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.bookmarks,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(_db.goals)..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.stageDefinitions,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.streaks,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.learningOrder,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.pointConfigs,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.activeCurricula,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.curriculumTracks,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.curriculumScopes,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.learningLedger,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.studyDayConfigs,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.profilePrograms,
      )..where((t) => t.profileId.equals(id))).go();
      // Finally delete the profile itself
      await _db.profileDao.deleteProfile(id);
    });
  }

  @override
  Future<int> countProfilesForAccount(int accountId) =>
      _db.profileDao.countProfilesForAccount(accountId);
}
