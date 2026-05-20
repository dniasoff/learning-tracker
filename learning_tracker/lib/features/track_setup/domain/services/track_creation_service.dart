import 'dart:async';

import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/onboarding/domain/models/wizard_result_wrapper.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/goal_repository.dart';
import 'package:learning_tracker/features/settings/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/stages/domain/repositories/stage_definition_repository.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';

/// Default study days: all 7 days active (Sun–Shabbos).
///
/// ISO weekdays: Mon=1 ... Sun=7.
const kDefaultStudyDays = <int, String>{
  7: 'study', // Sunday
  1: 'study', // Monday
  2: 'study', // Tuesday
  3: 'study', // Wednesday
  4: 'study', // Thursday
  5: 'study', // Friday
  6: 'study', // Shabbos (Saturday)
};

/// Creates a track in the database from an [AddTrackResult].
///
/// All core DB writes (stages, study days, scopes, point seeds) run in one
/// transaction. Goals are removed first (with sync), then re-created after if
/// the flow includes a goal. Program enrollment is set or cleared after.
class TrackCreationService {
  TrackCreationService({
    required UserDatabase database,
    required CurriculumActivationService activationService,
    required LearningProcessWizardService wizardService,
    required GoalRepository goalRepository,
    required StageDefinitionRepository stageRepository,
    FirestoreGateway? gateway,
    AnalyticsService? analytics,
  }) : _database = database,
       _activationService = activationService,
       _wizardService = wizardService,
       _goalRepository = goalRepository,
       _stageRepository = stageRepository,
       _gateway = gateway,
       _analytics = analytics ?? const NullAnalyticsService();

  final UserDatabase _database;
  final CurriculumActivationService _activationService;
  final LearningProcessWizardService _wizardService;
  final GoalRepository _goalRepository;
  final StageDefinitionRepository _stageRepository;
  final FirestoreGateway? _gateway;
  final AnalyticsService _analytics;

  /// Persist all track configuration from the AddTrackFlow result.
  ///
  /// Curriculum activation runs outside the transaction (idempotent).
  /// Remaining steps replace any prior track configuration for this curriculum.
  Future<void> createTrack({
    required AddTrackResult result,
    required int profileId,
  }) async {
    final curriculum = result.curriculumId;

    final trackId = await _restoreOrCreateTrack(
      profileId: profileId,
      curriculum: curriculum,
    );

    await _deleteExistingGoals(trackId);

    await _runCoreTransaction(
      result: result,
      profileId: profileId,
      curriculum: curriculum,
      trackId: trackId,
    );

    await _recreateGoal(
      result: result,
      profileId: profileId,
      curriculum: curriculum,
      trackId: trackId,
    );

    if (result.programId == null) {
      await _clearProgramEnrollment(
        profileId: profileId,
        curriculum: curriculum,
      );
    } else {
      await _enrollInProgram(
        result: result,
        profileId: profileId,
        curriculum: curriculum,
        trackId: trackId,
      );
    }

    AppLogger.instance.info(
      event:
          'TrackCreationService: track "${result.label}" created for '
          '${curriculum.storageKey} (profile=$profileId)',
    );

    // Story 27.14 (DNI-390): fire analytics event after successful track creation.
    unawaited(_analytics.logTrackAdded(curriculumId: curriculum.storageKey));
  }

  /// Restore a soft-deleted track row or create a fresh one, and ensure the
  /// curriculum is activated for this profile. Returns the track ID.
  Future<int> _restoreOrCreateTrack({
    required int profileId,
    required CurriculumId curriculum,
  }) async {
    // Restore any soft-deleted track row (avoids UNIQUE violation on re-add).
    final trackId = await _database.trackDao.restoreOrCreate(
      profileId: profileId,
      curriculumId: curriculum,
      trackType: TrackType.personal,
    );

    // Activate the curriculum in active_curricula (idempotent, outside
    // transaction). A soft-deleted track can exist without an active_curricula
    // row, so we always attempt this even when restoreOrCreate found an
    // existing row.
    try {
      await _activationService.activateForProfile(curriculum, profileId);
    } catch (_) {
      AppLogger.instance.debug(
        event:
            'TrackCreationService: curriculum ${curriculum.storageKey} '
            'activation skipped (likely already active)',
      );
    }

    return trackId;
  }

  /// Delete all existing goals for [trackId], syncing tombstones so
  /// re-add does not stack duplicates.
  Future<void> _deleteExistingGoals(int trackId) async {
    final existingGoals = await _database.goalDao.getGoalsByTrack(trackId);
    for (final g in existingGoals) {
      await _goalRepository.deleteGoal(g.id);
    }
  }

  /// Run the core DB transaction: delete old stages, apply wizard result,
  /// save study days, save scopes, and seed point configs.
  Future<void> _runCoreTransaction({
    required AddTrackResult result,
    required int profileId,
    required CurriculumId curriculum,
    required int trackId,
  }) async {
    await _database.transaction(() async {
      await _stageRepository.deleteStagesForTrack(trackId);

      if (result.wizardResult != null) {
        final wizard = result.wizardResult!;
        await _wizardService.applyWizardResult(
          wizard.wizardResult,
          profileId: profileId,
          trackId: trackId,
        );
      }

      await _saveStudyDays(
        profileId: profileId,
        curriculumId: curriculum,
        trackId: trackId,
        studyDays: result.studyDays,
      );

      await _database.curriculumScopeDao.clearScopesForTrack(trackId);
      if (result.scopeSelections != null &&
          result.scopeSelections!.isNotEmpty) {
        await _saveScopes(
          profileId: profileId,
          curriculumId: curriculum,
          trackId: trackId,
          scopes: result.scopeSelections!,
        );
      }

      await _seedPointConfigsIfNeeded(
        profileId: profileId,
        curriculumId: curriculum,
        trackId: trackId,
      );
    });
  }

  /// Create the goal from [result] if one is present.
  ///
  /// Falls back to [result.label] as the goal description when the [GoalEntity]
  /// carries an empty description — this covers tracks created before B4 was
  /// fixed and any code path that does not seed [GoalEntity.description].
  Future<void> _recreateGoal({
    required AddTrackResult result,
    required int profileId,
    required CurriculumId curriculum,
    required int trackId,
  }) async {
    if (result.goalResult == null) return;
    final goal = result.goalResult!;
    // Use the track label as the description when the goal entity has none
    // (belt-and-suspenders: step_goal seeds it, but older flows may not).
    final description = goal.description.isNotEmpty
        ? goal.description
        : result.label;
    await _goalRepository.createGoal(
      profileId: profileId,
      curriculumId: curriculum,
      trackId: trackId,
      targetPercent: goal.targetPercent,
      paceTarget: goal.paceTarget,
      description: description,
      dateType: goal.dateType,
      paceGranularity: goal.paceGranularityKey,
    );
  }

  /// Clear program enrollment locally and on cloud when switching to self-paced.
  Future<void> _clearProgramEnrollment({
    required int profileId,
    required CurriculumId curriculum,
  }) async {
    final removed = await _database.profileProgramDao
        .clearProgramForProfileAndCurriculum(profileId, curriculum.storageKey);
    if (removed > 0) {
      await _gateway?.removeProfileProgramAssignment(
        profileId: profileId,
        curriculumStorageKey: curriculum.storageKey,
      );
    }
  }

  /// Parse the raw startingRef string into a bookmark ref and tracking-start date.
  ///
  /// The format may be:
  ///   - null → start from beginning
  ///   - "offset:N|ref:<sefariaRef>" → calendar offset + resolved unit
  ///   - "offset:N" → legacy day-offset format
  ///   - a sefariaRef string (e.g. "Berakhot 42a") → content-based position
  ({String? bookmarkRef, DateTime? trackingStartDate}) _parseProgramStartingRef(
    String? rawStartingRef,
  ) {
    var bookmarkRef = rawStartingRef;
    String? offsetToken;

    if (rawStartingRef != null && rawStartingRef.contains('|')) {
      for (final token in rawStartingRef.split('|')) {
        if (token.startsWith('offset:')) offsetToken = token;
        if (token.startsWith('ref:')) {
          final parsedRef = token.substring('ref:'.length);
          if (parsedRef.isNotEmpty) {
            bookmarkRef = parsedRef;
          }
        }
      }
    }

    DateTime? trackingStartDate;
    final offsetSource =
        offsetToken ??
        ((rawStartingRef != null && rawStartingRef.startsWith('offset:'))
            ? rawStartingRef
            : null);
    if (offsetSource != null) {
      final offset = int.tryParse(offsetSource.substring('offset:'.length));
      if (offset != null) {
        final clampedOffset = offset.clamp(-30, 30);
        trackingStartDate = DateTimeFactory.nowUtc().add(
          Duration(days: clampedOffset),
        );
      }
    }

    return (bookmarkRef: bookmarkRef, trackingStartDate: trackingStartDate);
  }

  /// Link the profile to the selected program and push to Firestore.
  /// Also upserts the bookmark if a starting ref was specified.
  Future<void> _enrollInProgram({
    required AddTrackResult result,
    required int profileId,
    required CurriculumId curriculum,
    required int trackId,
  }) async {
    final programId = result.programId!;
    final (:bookmarkRef, :trackingStartDate) = _parseProgramStartingRef(
      result.startingRef,
    );

    await _database.profileProgramDao.setProfileProgram(
      profileId: profileId,
      curriculumType: curriculum.storageKey,
      programId: programId,
      trackingStartDate: trackingStartDate,
      trackingStartRef: bookmarkRef,
    );

    if (bookmarkRef != null && bookmarkRef.isNotEmpty) {
      final updatedAt = DateTimeFactory.nowUtc();
      await _database.bookmarkDao.upsertBookmarkByProfile(
        profileId: profileId,
        curriculumId: curriculum.storageKey,
        trackId: trackId,
        sefariaRef: bookmarkRef,
        updatedAt: updatedAt,
      );
      await _gateway?.pushBookmark(
        profileId: profileId,
        data: {
          'curriculum_id': curriculum.storageKey,
          'track_type': TrackType.personal.storageKey,
          'content_item_id': bookmarkRef,
          'updated_at': updatedAt.toIso8601String(),
        },
      );
    }

    await _gateway?.pushProfileProgram(
      profileId: profileId,
      data: {
        'profile_id': profileId,
        'curriculum_id': curriculum.storageKey,
        'program_id': programId,
        'tracking_start_date': trackingStartDate?.toIso8601String(),
        'tracking_start_ref': bookmarkRef,
      },
    );
  }

  Future<void> _saveStudyDays({
    required int profileId,
    required CurriculumId curriculumId,
    required int trackId,
    required Map<int, String> studyDays,
  }) async {
    final dao = _database.studyDayConfigDao;
    await dao.deleteConfigsByCurriculumAndProfile(
      curriculumId.storageKey,
      profileId,
    );
    for (final entry in studyDays.entries) {
      await dao.upsertDayConfig(
        profileId: profileId,
        curriculumId: curriculumId.storageKey,
        trackId: trackId,
        dayOfWeek: entry.key,
        dayType: entry.value,
      );
    }
  }

  Future<void> _saveScopes({
    required int profileId,
    required CurriculumId curriculumId,
    required int trackId,
    required List<ScopeEntry> scopes,
  }) async {
    final now = DateTimeFactory.nowUtc();
    for (final scope in scopes) {
      await _database
          .into(_database.curriculumScopes)
          .insert(
            CurriculumScopesCompanion.insert(
              profileId: profileId,
              curriculumId: curriculumId.storageKey,
              trackId: trackId,
              scopeLevel: scope.level,
              scopeValue: scope.value,
              createdAt: now,
            ),
          );
    }
  }

  Future<void> _seedPointConfigsIfNeeded({
    required int profileId,
    required CurriculumId curriculumId,
    required int trackId,
  }) async {
    final profile = await _database.profileDao.getProfileById(profileId);
    if (profile?.mode != 'child') return;

    final existing = await _database.pointConfigDao.getConfigsByCurriculum(
      curriculumId.storageKey,
      profileId: profileId,
      trackId: trackId,
    );
    if (existing.isEmpty) {
      await _database.pointConfigDao.seedDefaults(
        curriculumId.storageKey,
        trackId,
        profileId: profileId,
      );
    }
  }
}
