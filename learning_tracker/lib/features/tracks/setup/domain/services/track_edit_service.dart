import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';

/// Applies in-place edits to an existing track.
///
/// Only the fields passed as non-null are written; omitted fields are left
/// unchanged. Goal TYPE cannot be changed — pass only pace/deadline values.
///
/// Chazarah changes use a supersede-and-replace strategy: the current active
/// stage rows are stamped with [supersededAt] so existing completions keep
/// their stageId FK valid, then replacement rows are inserted. New items pick
/// up the new stages; items already in progress continue against the old ones.
class TrackEditService {
  TrackEditService({
    required UserDatabase database,
    required LearningProcessWizardService wizardService,
    required GoalRepository goalRepository,
  }) : _database = database,
       _wizardService = wizardService,
       _goalRepository = goalRepository;

  final UserDatabase _database;
  final LearningProcessWizardService _wizardService;
  final GoalRepository _goalRepository;

  Future<void> editTrack({
    required int trackId,

    /// The goal being edited, by value (owner decision 4,
    /// `docs/firestore-rewrite-map.md`) — not a Drift row id. The caller
    /// (the edit-track screen) already holds this entity from loading the
    /// track's current goal.
    required GoalEntity goal,
    required int profileId,
    required CurriculumId curriculum,
    String? label,
    Map<int, String>? studyDays,
    WizardResult? chazarahWizard,

    /// Sealed goal-mode discriminant. Pass [DeadlineTarget] or
    /// [PacePeriodTarget] to update; `null` keeps the existing goal mode.
    /// Pass `null` with [clearPaceTarget] = `true` to remove the goal.
    PaceTarget? paceTarget,
    bool clearPaceTarget = false,
    String? paceGranularity,
  }) async {
    await _database.transaction(() async {
      // 1. Study days — delete-and-replace (same pattern as track creation).
      if (studyDays != null) {
        await _database.studyDayConfigDao.replaceAllForTrack(
          profileId: profileId,
          curriculumId: curriculum.storageKey,
          trackId: trackId,
          studyDays: studyDays,
        );
      }

      // 2. Chazarah — delete existing stages then insert replacements.
      // W3.28/W3.29: supersededAt dropped; stages are now hard-deleted and
      // replaced (completions.stageId FKs are managed at the application layer).
      if (chazarahWizard != null) {
        await _wizardService.applyWizardResult(
          chazarahWizard,
          profileId: profileId,
          trackId: trackId,
        );
      }
    });

    // Goal updates run outside the core transaction (they sync to Firestore).
    final hasGoalChange =
        label != null ||
        paceTarget != null ||
        clearPaceTarget ||
        paceGranularity != null;

    if (hasGoalChange) {
      await _goalRepository.updateGoal(
        goal: goal,
        description: label,
        paceTarget: paceTarget,
        clearPaceTarget: clearPaceTarget,
        paceGranularity: paceGranularity != null
            ? PaceGranularity.fromStorageKey(paceGranularity)
            : null,
      );
    }

    AppLogger.instance.info(
      event:
          'TrackEditService: track $trackId edited for ${curriculum.storageKey} '
          '(profile=$profileId)',
    );
  }
}
