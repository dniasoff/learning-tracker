import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/goal_repository.dart';

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
    required int goalId,
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
        await _saveStudyDays(
          profileId: profileId,
          curriculum: curriculum,
          trackId: trackId,
          studyDays: studyDays,
        );
      }

      // 2. Chazarah — supersede existing active stages then insert replacements.
      if (chazarahWizard != null) {
        final now = DateTimeFactory.nowUtc();
        await _database.stageDao.supersedeStagesToTrack(trackId, now);
        await _wizardService.applyWizardResult(
          chazarahWizard,
          profileId: profileId,
          trackId: trackId,
          clearFirst: false,
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
        goalId: goalId,
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

  Future<void> _saveStudyDays({
    required int profileId,
    required CurriculumId curriculum,
    required int trackId,
    required Map<int, String> studyDays,
  }) async {
    final dao = _database.studyDayConfigDao;
    await dao.deleteConfigsByCurriculumAndProfile(
      curriculum.storageKey,
      profileId,
    );
    for (final entry in studyDays.entries) {
      await dao.upsertDayConfig(
        profileId: profileId,
        curriculumId: curriculum.storageKey,
        trackId: trackId,
        dayOfWeek: entry.key,
        dayType: entry.value,
      );
    }
  }
}
