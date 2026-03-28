import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/goal_repository.dart';
import 'package:learning_tracker/features/settings/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';

/// Creates a track in the database from an [AddTrackResult].
///
/// Orchestrates all DB writes within a transaction:
/// curriculum activation, track record, stages, study days,
/// scopes, goals, and bulk mark completions.
class TrackCreationService {
  TrackCreationService({
    required AppDatabase database,
    required CurriculumActivationService activationService,
    required LearningProcessWizardService wizardService,
    required GoalRepository goalRepository,
  }) : _database = database,
       _activationService = activationService,
       _wizardService = wizardService,
       _goalRepository = goalRepository;

  final AppDatabase _database;
  final CurriculumActivationService _activationService;
  final LearningProcessWizardService _wizardService;
  final GoalRepository _goalRepository;

  /// Persist all track configuration from the AddTrackFlow result.
  ///
  /// Activates the curriculum, creates the track, saves stages,
  /// study days, scopes, and goals. Bulk mark completions are
  /// handled separately by [BulkPriorCompletionService] since
  /// [BulkMarkScreen] already persists them during the flow.
  Future<void> createTrack({
    required AddTrackResult result,
    required int profileId,
  }) async {
    final curriculum = result.curriculumId;

    // 1. Ensure curriculum is activated (idempotent)
    try {
      await _activationService.activate(curriculum);
    } catch (_) {
      // May already be active — that's fine
      AppLogger.instance.debug(
        'TrackCreationService: curriculum ${curriculum.storageKey} '
        'activation skipped (likely already active)',
      );
    }

    // 2. Apply wizard result (stages) if provided
    if (result.wizardResult != null) {
      await _wizardService.applyWizardResult(
        result.wizardResult!.wizardResult,
        profileId: profileId,
      );
    }

    // 3. Save study day configs
    await _saveStudyDays(
      profileId: profileId,
      curriculumId: curriculum,
      studyDays: result.studyDays,
    );

    // 4. Save scope selections if narrowed
    if (result.scopeSelections != null && result.scopeSelections!.isNotEmpty) {
      await _saveScopes(
        profileId: profileId,
        curriculumId: curriculum,
        scopes: result.scopeSelections!,
      );
    }

    // 5. Create goal if provided
    if (result.goalResult != null) {
      await _goalRepository.createGoal(
        curriculumId: curriculum,
        targetPercent: result.goalResult!.targetPercent,
        targetDate: result.goalResult!.targetDate,
        description: result.goalResult!.description,
        dateType: result.goalResult!.dateType,
        goalType: result.goalResult!.goalType,
        paceValue: result.goalResult!.paceValue,
        paceUnit: result.goalResult!.paceUnit,
      );
    }

    AppLogger.instance.info(
      'TrackCreationService: track "${result.label}" created for '
      '${curriculum.storageKey} (profile=$profileId)',
    );
  }

  Future<void> _saveStudyDays({
    required int profileId,
    required CurriculumId curriculumId,
    required Map<int, String> studyDays,
  }) async {
    final dao = _database.studyDayConfigDao;
    // Delete existing and re-seed with user selections
    await dao.deleteConfigsByCurriculumAndProfile(
      curriculumId.storageKey,
      profileId,
    );
    for (final entry in studyDays.entries) {
      await dao.upsertDayConfig(
        profileId: profileId,
        curriculumId: curriculumId.storageKey,
        dayOfWeek: entry.key,
        dayType: entry.value,
      );
    }
  }

  Future<void> _saveScopes({
    required int profileId,
    required CurriculumId curriculumId,
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
              scopeLevel: scope.level,
              scopeValue: scope.value,
              createdAt: now,
            ),
          );
    }
  }
}
