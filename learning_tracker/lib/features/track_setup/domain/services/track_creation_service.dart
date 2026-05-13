import 'dart:async';

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/onboarding/domain/models/wizard_result_wrapper.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/goal_repository.dart';
import 'package:learning_tracker/features/settings/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';
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
    SyncEngine? syncEngine,
    AnalyticsService? analytics,
  }) : _database = database,
       _activationService = activationService,
       _wizardService = wizardService,
       _goalRepository = goalRepository,
       _syncEngine = syncEngine,
       _analytics = analytics ?? const NullAnalyticsService();

  final UserDatabase _database;
  final CurriculumActivationService _activationService;
  final LearningProcessWizardService _wizardService;
  final GoalRepository _goalRepository;
  final SyncEngine? _syncEngine;
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

    // 1. Ensure curriculum is activated for this profile (idempotent, outside transaction)
    try {
      await _activationService.activateForProfile(curriculum, profileId);
    } catch (_) {
      AppLogger.instance.debug(
        'TrackCreationService: curriculum ${curriculum.storageKey} '
        'activation skipped (likely already active)',
      );
    }

    // 2. Resolve the trackId — activation created the personal track above.
    final track =
        await (_database.select(_database.curriculumTracks)
              ..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.curriculumId.equals(curriculum.storageKey) &
                    t.trackType.equals(TrackType.personal.storageKey),
              )
              ..limit(1))
            .getSingleOrNull();
    if (track == null) {
      throw StateError(
        'No curriculum track found after activation for '
        '${curriculum.storageKey} (profile=$profileId)',
      );
    }
    final trackId = track.id;

    // Replace prior goals (syncs tombstones) so re-add does not stack duplicates.
    final existingGoals = await _database.goalDao.getGoalsByTrack(trackId);
    for (final g in existingGoals) {
      await _goalRepository.deleteGoal(g.id);
    }

    await _database.transaction(() async {
      await _database.stageDao.deleteStagesForTrack(trackId);

      if (result.wizardResult is LearningProcessWizardResult) {
        final wizard = result.wizardResult! as LearningProcessWizardResult;
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

    if (result.goalResult is GoalEntity) {
      final goal = result.goalResult! as GoalEntity;
      await _goalRepository.createGoal(
        profileId: profileId,
        curriculumId: curriculum,
        trackId: trackId,
        targetPercent: goal.targetPercent,
        targetDate: goal.targetDate,
        description: goal.description,
        dateType: goal.dateType,
        goalType: goal.goalType,
        paceValue: goal.paceValue,
        paceUnit: goal.paceUnit,
        learningUnit: goal.learningUnit,
      );
    }

    // Self-paced: clear program enrollment locally + on cloud when switching from programmed.
    if (result.programId == null) {
      final removed = await _database.profileProgramDao
          .clearProgramForProfileAndCurriculum(
            profileId,
            curriculum.storageKey,
          );
      if (removed > 0) {
        await _syncEngine?.removeProfileProgramAssignment(
          curriculum.storageKey,
        );
      }
    }

    // Link profile to program if one was selected (outside transaction — idempotent)
    if (result.programId != null) {
      final programId = result.programId!;
      // startingRef is either:
      //   - null → start from beginning
      //   - "offset:N|ref:<sefariaRef>" → calendar offset + resolved unit
      //   - "offset:N" → legacy day-offset format
      //   - a sefariaRef string (e.g. "Berakhot 42a") → content-based position
      final rawStartingRef = result.startingRef;
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
        await _syncEngine?.pushBookmark({
          'curriculum_id': curriculum.storageKey,
          'track_type': TrackType.personal.storageKey,
          'content_item_id': bookmarkRef,
          'updated_at': updatedAt.toIso8601String(),
        });
      }

      await _syncEngine?.pushProfileProgram({
        'profile_id': profileId,
        'curriculum_id': curriculum.storageKey,
        'program_id': programId,
        'tracking_start_date': trackingStartDate?.toIso8601String(),
        'tracking_start_ref': bookmarkRef,
      });
    }

    AppLogger.instance.info(
      'TrackCreationService: track "${result.label}" created for '
      '${curriculum.storageKey} (profile=$profileId)',
    );

    // Story 27.14 (DNI-390): fire analytics event after successful track creation.
    unawaited(_analytics.logTrackAdded(curriculumId: curriculum.storageKey));
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
