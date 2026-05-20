import 'package:drift/drift.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';

final _log = AppLogger(AppLogger.instance);

/// Maximum number of profiles allowed per account (matches the repository guard).
const _maxProfilesPerAccount = 10;

/// Command object carrying all inputs needed to create a new profile
/// in one atomic transaction.
///
/// [curriculumIds] lists the curricula to activate for this profile.
/// If empty, no curriculum tracks, stages, or point configs are seeded.
class ProfileCreationCommand {
  const ProfileCreationCommand({
    required this.accountId,
    required this.displayName,
    required this.mode,
    this.avatarIndex = 0,
    this.curriculumIds = const [],
  });

  final int accountId;
  final String displayName;
  final String mode;
  final int avatarIndex;

  /// Curricula to activate (empty = profile-only, no tracks seeded).
  final List<CurriculumId> curriculumIds;
}

/// Result returned by [ProfileCreationUseCase.execute].
class ProfileCreationResult {
  const ProfileCreationResult({required this.profile});

  /// The newly created profile.
  final ProfileModel profile;
}

/// Creates a new learner profile with all related data in one DB transaction.
///
/// Writes inside [execute] are:
///   1. Profile row
///   2. One personal [CurriculumTrack] per requested curriculum
///   3. Default [StageDefinition] rows (per [CurriculumDefaults.defaultStages])
///   4. Default [PointConfig] rows (per [CurriculumDefaults.defaultPointsPerStage])
///
/// If any insert fails the whole transaction rolls back, leaving zero new rows
/// in any table (Story 26.12, AC: atomicity / rollback guarantee).
class ProfileCreationUseCase {
  ProfileCreationUseCase(this._db);

  final UserDatabase _db;

  /// Execute profile creation atomically.
  ///
  /// Throws [MaxProfilesExceededException] when the account already has 10
  /// profiles, [DuplicateProfileNameException] when the trimmed display name
  /// already exists (case-insensitive) for the account. Both guards run
  /// *before* the transaction so they never leave partial state.
  Future<ProfileCreationResult> execute(ProfileCreationCommand command) async {
    final trimmedName = command.displayName.trim();

    // Pre-flight guards (outside the transaction — no writes yet).
    final count = await _db.profileDao.countProfilesForAccount(
      command.accountId,
    );
    if (count >= _maxProfilesPerAccount) {
      throw MaxProfilesExceededException(command.accountId);
    }

    final nameExists = await _db.profileDao.profileExistsByName(
      command.accountId,
      trimmedName,
    );
    if (nameExists) {
      throw DuplicateProfileNameException(trimmedName);
    }

    _log.info(
      event: 'profile_creation_use_case_start',
      fields: {
        'accountId': command.accountId,
        'mode': command.mode,
        'curriculaCount': command.curriculumIds.length,
      },
    );

    final now = DateTimeFactory.nowUtc();

    // Single Drift transaction — any failure rolls back everything.
    final profileId = await _db.transaction<int>(() async {
      // Step 1: Insert the profile row.
      final newProfileId = await _db.profileDao.insertProfile(
        LearnerProfilesCompanion.insert(
          accountId: command.accountId,
          displayName: trimmedName,
          mode: command.mode,
          avatarIndex: Value(command.avatarIndex),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Steps 2–4: Seed per-curriculum data.
      for (final curriculumId in command.curriculumIds) {
        // Step 2: Insert curriculum activation (personal track).
        final trackId = await _db
            .into(_db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: newProfileId,
                curriculumId: curriculumId.storageKey,
                trackType: TrackType.personal.storageKey,
                isActive: const Value(true),
                activatedAt: now,
              ),
            );

        // Step 3: Insert default stage definitions.
        for (final stage in CurriculumDefaults.defaultStages) {
          await _db
              .into(_db.stageDefinitions)
              .insert(
                StageDefinitionsCompanion.insert(
                  profileId: newProfileId,
                  curriculumId: curriculumId.storageKey,
                  trackId: trackId,
                  stageOrder: stage.stageOrder,
                  stageName: stage.stageName,
                  delayDays: stage.delayDays,
                  scheduleType: Value(stage.scheduleTypeKey),
                ),
              );
        }

        // Step 4: Insert default point configs.
        for (final entry in CurriculumDefaults.defaultPointsPerStage.entries) {
          await _db
              .into(_db.pointConfigs)
              .insert(
                PointConfigsCompanion.insert(
                  profileId: newProfileId,
                  curriculumId: curriculumId.storageKey,
                  trackId: trackId,
                  stageOrder: entry.key,
                  points: entry.value,
                ),
              );
        }
      }

      return newProfileId;
    });

    final profile = ProfileModel(
      id: profileId,
      accountId: command.accountId,
      displayName: trimmedName,
      mode: command.mode,
      avatarIndex: command.avatarIndex,
      createdAt: now,
      updatedAt: now,
    );

    _log.info(
      event: 'profile_creation_use_case_done',
      fields: {'profileId': profileId},
    );

    return ProfileCreationResult(profile: profile);
  }
}
