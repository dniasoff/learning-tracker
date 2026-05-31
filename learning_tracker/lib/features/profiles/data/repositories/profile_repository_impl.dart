import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';

final _log = AppLogger.instance;

/// Implementation of [ProfileRepository] using Drift database.
///
/// When a [SyncWriteFacade] is provided (cloud-born accounts), create / update /
/// delete operations are mirrored to Firestore so learner profiles survive
/// re-install and sync across devices. Local-born accounts pass null and
/// the repo stays local-only.
class ProfileRepositoryImpl implements ProfileRepository {
  final UserDatabase _db;
  final SyncWriteFacade? _syncEngine;

  ProfileRepositoryImpl(this._db, {SyncWriteFacade? syncEngine})
    : _syncEngine = syncEngine;

  static const int maxProfilesPerAccount = 10;

  Map<String, dynamic> _toFirestorePayload(ProfileModel profile) => {
    'profile_id': profile.id,
    'account_id': profile.accountId,
    'display_name': profile.displayName,
    'mode': profile.mode,
    'avatar_index': profile.avatarIndex,
    'created_at': profile.createdAt.toIso8601String(),
    'updated_at': profile.updatedAt.toIso8601String(),
  };

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

    _log.info(event: 'profile_repo_create_start', fields: {'mode': mode});
    final now = DateTimeFactory.nowUtc();
    final id = await _db.profileDao.insertProfile(
      LearnerProfilesCompanion.insert(
        accountId: accountId,
        displayName: trimmedName,
        mode: mode,
        avatarIndex: Value(avatarIndex),
        createdAt: now,
        updatedAt: now,
      ),
    );

    final model = ProfileModel(
      id: id,
      accountId: accountId,
      displayName: trimmedName,
      mode: mode,
      avatarIndex: avatarIndex,
      createdAt: now,
      updatedAt: now,
    );

    _log.info(
      event: 'profile_repo_create_done',
      fields: {'profileId': model.id},
    );
    // Profile creation must succeed offline-first even if cloud push fails.
    try {
      await _syncEngine?.pushLearnerProfile(_toFirestorePayload(model));
    } catch (_) {
      // no-op: cloud push failure is non-fatal; local write already succeeded (offline-first)
    }
    return model;
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
    final now = DateTimeFactory.nowUtc();
    await (_db.update(
      _db.learnerProfiles,
    )..where((t) => t.id.equals(id))).write(
      LearnerProfilesCompanion(
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
    final model = ProfileModel.fromDriftRow(updated!);
    try {
      await _syncEngine?.pushLearnerProfile(_toFirestorePayload(model));
    } catch (_) {
      // no-op: cloud push failure is non-fatal; local write already succeeded (offline-first)
    }
    return model;
  }

  @override
  Future<void> deleteProfile(int id, {bool allowLast = false}) async {
    _log.info(
      event: 'profile_repo_delete_start',
      fields: {'profileId': id, 'allowLast': allowLast},
    );
    // Guard: by default we refuse to leave the account with zero profiles —
    // the picker would have nothing to show. Callers can opt in via
    // `allowLast: true` after a strong confirmation; the empty-state UI in
    // ProfilePicker will route the user to add a fresh profile.
    if (!allowLast) {
      // Read the account from the profile we're about to delete so the
      // last-profile guard scopes to the right account (DNI-342).
      final existing = await _db.profileDao.getProfileById(id);
      if (existing != null) {
        final count = await countProfilesForAccount(existing.accountId);
        if (count <= 1) {
          throw const LastProfileException();
        }
      }
    }

    await _db.transaction(() async {
      // Cascade delete all associated data.
      // W3.20: `completions` and `streaks` tables dropped — their data is now
      // in `completion_events` and `streak_events` which cascade-delete via FK.
      await (_db.delete(
        _db.bookmarks,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(_db.goals)..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.stageDefinitions,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.learningOrder,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.pointConfigs,
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
      // Canonical event logs + pending-command queue + derived plans.
      // completion_events / streak_events also cascade off the
      // learner_profiles delete, but clear them explicitly so the wipe does
      // not depend on FK-cascade ordering. `outbox` has no FK — without this
      // its pending pushes for the deleted profile would survive.
      await (_db.delete(
        _db.completionEvents,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.streakEvents,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(
        _db.dailyPlans,
      )..where((t) => t.profileId.equals(id))).go();
      await (_db.delete(_db.outbox)..where((t) => t.profileId.equals(id))).go();
      // Finally delete the profile itself
      await _db.profileDao.deleteProfile(id);
    });
    _log.info(
      event: 'profile_repo_delete_db_complete',
      fields: {'profileId': id},
    );

    await _syncEngine?.deleteLearnerProfile(id);
    _log.info(
      event: 'profile_repo_delete_sync_notified',
      fields: {'profileId': id},
    );
  }

  @override
  Future<int> countProfilesForAccount(int accountId) =>
      _db.profileDao.countProfilesForAccount(accountId);

  @override
  Future<int> ensureDefaultProfile({
    required int accountId,
    required String defaultDisplayName,
  }) async {
    // Fast path: account already owns a profile — nothing to heal.
    final existing = await _db.profileDao.getProfilesByAccount(accountId);
    if (existing.isNotEmpty) return existing.first.id;

    _log.warning(
      event: 'profile_self_heal_start',
      fields: {'accountId': accountId},
    );

    final now = DateTimeFactory.nowUtc();
    final trimmedName = defaultDisplayName.trim();
    final displayName = trimmedName.isEmpty ? 'Me' : trimmedName;

    // Single transaction: create the profile, then re-parent any orphaned
    // `profile_id = 0` rows that were written before a profile existed (e.g. a
    // track created on a profile-less account). These tables have no FK on
    // `learner_profiles`, so `profile_id = 0` rows are physically present and
    // must be adopted by the new profile rather than left stranded. The
    // FK-enforced tables (stage_definitions, goals, completion_events, …) can
    // never hold a `profile_id = 0` row, so they need no re-parenting.
    final newProfileId = await _db.transaction<int>(() async {
      final id = await _db.profileDao.insertProfile(
        LearnerProfilesCompanion.insert(
          accountId: accountId,
          displayName: displayName,
          mode: ProfileMode.adult.storageKey,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await (_db.update(_db.curriculumTracks)
            ..where((t) => t.profileId.equals(0)))
          .write(CurriculumTracksCompanion(profileId: Value(id)));
      await (_db.update(_db.pointConfigs)..where((t) => t.profileId.equals(0)))
          .write(PointConfigsCompanion(profileId: Value(id)));
      await (_db.update(_db.studyDayConfigs)
            ..where((t) => t.profileId.equals(0)))
          .write(StudyDayConfigsCompanion(profileId: Value(id)));
      await (_db.update(_db.profilePrograms)
            ..where((t) => t.profileId.equals(0)))
          .write(ProfileProgramsCompanion(profileId: Value(id)));
      await (_db.update(_db.dailyPlans)..where((t) => t.profileId.equals(0)))
          .write(DailyPlansCompanion(profileId: Value(id)));

      return id;
    });

    _log.info(
      event: 'profile_self_heal_done',
      fields: {'accountId': accountId, 'profileId': newProfileId},
    );

    // Mirror to the cloud so the healed profile survives re-install / sync.
    // Offline-first: a push failure is non-fatal — the local write stands.
    try {
      await _syncEngine?.pushLearnerProfile(
        _toFirestorePayload(
          ProfileModel(
            id: newProfileId,
            accountId: accountId,
            displayName: displayName,
            mode: ProfileMode.adult.storageKey,
            avatarIndex: 0,
            createdAt: now,
            updatedAt: now,
          ),
        ),
      );
    } catch (_) {
      // no-op: cloud push failure is non-fatal; local write already succeeded.
    }

    return newProfileId;
  }
}
