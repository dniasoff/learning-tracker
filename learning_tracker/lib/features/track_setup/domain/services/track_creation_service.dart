import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/onboarding/domain/models/wizard_result_wrapper.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_form_result.dart';
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
/// All DB writes (stages, study days, scopes, goals) are wrapped
/// in a single transaction for atomicity.
class TrackCreationService {
  TrackCreationService({
    required UserDatabase database,
    required CurriculumActivationService activationService,
    required LearningProcessWizardService wizardService,
    required GoalRepository goalRepository,
    SyncEngine? syncEngine,
  }) : _database = database,
       _activationService = activationService,
       _wizardService = wizardService,
       _goalRepository = goalRepository,
       _syncEngine = syncEngine;

  final UserDatabase _database;
  final CurriculumActivationService _activationService;
  final LearningProcessWizardService _wizardService;
  final GoalRepository _goalRepository;
  final SyncEngine? _syncEngine;

  /// Persist all track configuration from the AddTrackFlow result.
  ///
  /// Curriculum activation runs outside the transaction (idempotent).
  /// All subsequent writes run inside a single transaction — if any
  /// step fails, everything rolls back.
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

    // 3. All remaining writes in a single transaction
    await _database.transaction(() async {
      // Apply wizard result (stages) if provided
      if (result.wizardResult is LearningProcessWizardResult) {
        final wizard = result.wizardResult! as LearningProcessWizardResult;
        await _wizardService.applyWizardResult(
          wizard.wizardResult,
          profileId: profileId,
          trackId: trackId,
        );
      }

      // Save study day configs
      await _saveStudyDays(
        profileId: profileId,
        curriculumId: curriculum,
        trackId: trackId,
        studyDays: result.studyDays,
      );

      // Save scope selections if narrowed
      if (result.scopeSelections != null &&
          result.scopeSelections!.isNotEmpty) {
        await _saveScopes(
          profileId: profileId,
          curriculumId: curriculum,
          trackId: trackId,
          scopes: result.scopeSelections!,
        );
      }

      // Create goal if provided
      if (result.goalResult is GoalFormResult) {
        final goal = result.goalResult! as GoalFormResult;
        await _goalRepository.createGoal(
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

      // Seed default point configs for child mode tracks
      await _seedPointConfigsIfNeeded(
        profileId: profileId,
        curriculumId: curriculum,
        trackId: trackId,
      );
    });

    // Link profile to program if one was selected (outside transaction — idempotent)
    if (result.programId != null) {
      final programId = result.programId!;
      // startingRef is either:
      //   - null → start from beginning
      //   - "offset:N" → legacy day-offset format
      //   - a sefariaRef string (e.g. "Berakhot 42a") → content-based position
      DateTime? trackingStartDate;
      if (result.startingRef != null &&
          result.startingRef!.startsWith('offset:')) {
        final offset = int.tryParse(
          result.startingRef!.substring('offset:'.length),
        );
        if (offset != null) {
          final clampedOffset = offset.clamp(-30, 30);
          trackingStartDate = DateTime.now().toUtc().add(
            Duration(days: clampedOffset),
          );
        }
      }

      await _database.profileProgramDao.setProfileProgram(
        profileId: profileId,
        curriculumType: curriculum.storageKey,
        programId: programId,
        trackingStartDate: trackingStartDate,
        trackingStartRef: result.startingRef,
      );

      await _syncEngine?.pushProfileProgram({
        'profile_id': profileId,
        'curriculum_id': curriculum.storageKey,
        'program_id': programId,
        'tracking_start_date': trackingStartDate?.toIso8601String(),
        'tracking_start_ref': result.startingRef,
      });
    }

    AppLogger.instance.info(
      'TrackCreationService: track "${result.label}" created for '
      '${curriculum.storageKey} (profile=$profileId)',
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
    final now = DateTime.now().toUtc();
    for (final scope in scopes) {
      await _database
          .into(_database.curriculumScopes)
          .insert(
            CurriculumScopesCompanion.insert(
              profileId: Value(profileId),
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
    final existing = await _database.pointConfigDao.getConfigsByCurriculum(
      curriculumId.storageKey,
    );
    if (existing.isEmpty) {
      await _database.pointConfigDao.seedDefaults(
        curriculumId.storageKey,
        trackId,
      );
    }
  }
}
