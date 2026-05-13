import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';

/// Navigation-level sealed state for the AddTrackFlow wizard.
///
/// Each variant represents a distinct screen the user can be on.
/// All accumulated form data (curriculum, scope, program, study days, etc.)
/// is carried forward on each transition so the controller has full context.
///
/// Note: this is distinct from [AddTrackState] (the freezed form-data
/// class in `add_track_result.dart`) — that holds raw field values;
/// this holds the *navigation position* + accumulated data.
sealed class AddTrackFlowState {
  const AddTrackFlowState();

  /// The form data accumulated so far (curriculum, scope, program, etc.).
  AddTrackState get formData;
}

/// Initial state — curriculum picker is shown.
/// Maps to the "welcome/curriculumChoice" screens in the spec.
final class CurriculumChoiceState extends AddTrackFlowState {
  const CurriculumChoiceState({required this.formData});

  @override
  final AddTrackState formData;
}

/// Program-selection step (auto-skipped when curriculum has no programs).
final class ProgramChoiceState extends AddTrackFlowState {
  const ProgramChoiceState({required this.formData});

  @override
  final AddTrackState formData;
}

/// Scope selection (skipped when a program is selected).
final class ScopeChoiceState extends AddTrackFlowState {
  const ScopeChoiceState({required this.formData});

  @override
  final AddTrackState formData;
}

/// Study-days configuration (skipped for program tracks — auto-filled).
final class StudyDaysState extends AddTrackFlowState {
  const StudyDaysState({required this.formData});

  @override
  final AddTrackState formData;
}

/// Chazara / review-stages configuration.
final class StagesChoiceState extends AddTrackFlowState {
  const StagesChoiceState({required this.formData});

  @override
  final AddTrackState formData;
}

/// Goal / pace setup (skipped for program tracks).
final class GoalChoiceState extends AddTrackFlowState {
  const GoalChoiceState({required this.formData});

  @override
  final AddTrackState formData;
}

/// Confirmation / bulk-mark / starting-position step.
final class ConfirmationState extends AddTrackFlowState {
  const ConfirmationState({required this.formData});

  @override
  final AddTrackState formData;
}

/// Terminal state — flow has completed successfully.
final class CompleteState extends AddTrackFlowState {
  const CompleteState({required this.formData, required this.result});

  @override
  final AddTrackState formData;

  /// The committed track configuration returned on completion.
  final AddTrackResult result;
}

/// Extension helpers for pattern-matching convenience.
extension AddTrackFlowStateX on AddTrackFlowState {
  bool get isCurriculumChoice => this is CurriculumChoiceState;
  bool get isProgramChoice => this is ProgramChoiceState;
  bool get isScopeChoice => this is ScopeChoiceState;
  bool get isStudyDays => this is StudyDaysState;
  bool get isStagesChoice => this is StagesChoiceState;
  bool get isGoalChoice => this is GoalChoiceState;
  bool get isConfirmation => this is ConfirmationState;
  bool get isComplete => this is CompleteState;

  /// True when the user has chosen a calendar program (scope/study-days are
  /// auto-filled and goal step is skipped).
  bool get isProgramTrack => formData.programId != null;

  /// Display progress fraction (0.0 – 1.0) for the progress bar.
  /// Based on the active steps list similar to the monolith.
  double get progressFraction {
    final steps = _activeStepCount;
    final index = _currentIndex;
    if (steps == 0) return 1.0;
    return (index + 1) / steps;
  }

  /// 1-based step index for "STEP X OF Y" label.
  int get stepNumber => _currentIndex + 1;

  /// Total active step count.
  int get totalSteps => _activeStepCount;

  int get _currentIndex {
    return switch (this) {
      CurriculumChoiceState() => 0,
      ProgramChoiceState() => isProgramTrack ? 1 : 1,
      ScopeChoiceState() => isProgramTrack ? 1 : 2,
      StudyDaysState() => isProgramTrack ? 2 : 3,
      StagesChoiceState() => isProgramTrack ? 3 : 4,
      GoalChoiceState() => 5,
      ConfirmationState() => isProgramTrack ? 4 : 6,
      CompleteState() => _activeStepCount - 1,
    };
  }

  int get _activeStepCount {
    // Mirrors the monolith's _activeSteps logic.
    final hasProgramStep =
        formData.curriculumId != null &&
        hasProgramsForCurriculum(formData.curriculumId!);
    final isProg = formData.programId != null;

    // curriculum + optional program + optional scope + optional studyDays
    // + chazara + optional goal + bulkMark/startingPos
    return 1 + // curriculum
        (hasProgramStep ? 1 : 0) + // program
        (isProg ? 0 : 1) + // scope (skip for program)
        (isProg ? 0 : 1) + // studyDays (skip for program)
        1 + // chazara / stages
        (isProg ? 0 : 1) + // goal (skip for program)
        1; // confirmation / bulkMark / startingPos
  }

  /// Mirrors the monolith's `_hasProgramStepForCurriculum` logic.
  /// Curricula that ship at least one seeded learning program.
  static bool hasProgramsForCurriculum(CurriculumId id) {
    return switch (id) {
      CurriculumId.bavli => true,
      CurriculumId.mishnaBerurah => true,
      CurriculumId.yerushalmi => true,
      CurriculumId.mussar => true,
      CurriculumId.mishnayos => true,
      CurriculumId.nach => true,
      CurriculumId.mishnehTorah => true,
      CurriculumId.tanach => true,
      _ => false,
    };
  }
}
