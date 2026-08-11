import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/study_day_write_repository.dart';

/// Applies in-place edits to an existing track.
///
/// Only the fields passed as non-null are written; omitted fields are left
/// unchanged. Goal TYPE cannot be changed — pass only pace/deadline values.
///
/// AD-25: a track IS a curriculum (one track per curriculum per profile),
/// so every write here is keyed on [CurriculumId] alone — there is no
/// separate per-device track id left to thread through.
///
/// Not atomic across study-days + chazara + goal (Firestore has no
/// cross-collection transaction available through the plain repository
/// calls this migration already uses elsewhere — see
/// LearningProcessWizardService's module doc comment for the same
/// trade-off). Each piece is only written when its corresponding parameter
/// is non-null, same as before.
class TrackEditService {
  TrackEditService({
    required LearningProcessWizardService wizardService,
    required GoalRepository goalRepository,
    required StudyDayWriteRepository studyDayRepository,
  }) : _wizardService = wizardService,
       _goalRepository = goalRepository,
       _studyDayRepository = studyDayRepository;

  final LearningProcessWizardService _wizardService;
  final GoalRepository _goalRepository;
  final StudyDayWriteRepository _studyDayRepository;

  Future<void> editTrack({
    /// The goal being edited, by value (owner decision 4,
    /// `docs/firestore-rewrite-map.md`) — not a Drift row id. The caller
    /// (the edit-track screen) already holds this entity from loading the
    /// track's current goal.
    required GoalEntity goal,
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
    // 1. Study days — full replace (delete is rules-legal for this
    // collection, unlike stage_definitions).
    if (studyDays != null) {
      await _studyDayRepository.replaceAllForCurriculum(
        curriculumId: curriculum,
        studyDays: studyDays.map(
          (day, type) => MapEntry(day, type == 'study' ? DayType.study : DayType.review),
        ),
      );
    }

    // 2. Chazarah — overwrite the curriculum's stage set.
    if (chazarahWizard != null) {
      await _wizardService.applyWizardResult(chazarahWizard);
    }

    // Goal updates (sync to Firestore directly via _goalRepository).
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
      event: 'TrackEditService: track edited for ${curriculum.storageKey}',
    );
  }
}
