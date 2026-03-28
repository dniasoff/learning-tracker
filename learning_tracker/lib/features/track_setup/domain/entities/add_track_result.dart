import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/bulk_mark_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/learning_process_wizard_screen.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/goal_setup_screen.dart';

part 'add_track_result.freezed.dart';

/// Result returned by [AddTrackFlow] on successful completion.
///
/// Contains all configuration gathered across the 8-step wizard.
@freezed
abstract class AddTrackResult with _$AddTrackResult {
  const factory AddTrackResult({
    required CurriculumId curriculumId,
    required String label,
    int? programId,
    String? programName,
    List<ScopeEntry>? scopeSelections,
    required Map<int, String> studyDays,
    LearningProcessWizardResult? wizardResult,
    GoalFormResult? goalResult,
    BulkMarkResult? bulkMarkResult,
  }) = _AddTrackResult;
}

/// A single scope selection entry (level + value).
@freezed
abstract class ScopeEntry with _$ScopeEntry {
  const factory ScopeEntry({required int level, required String value}) =
      _ScopeEntry;
}

/// Internal state of the AddTrackFlow wizard.
///
/// Tracks user selections as they progress through the 8 steps.
@freezed
abstract class AddTrackState with _$AddTrackState {
  const factory AddTrackState({
    @Default(AddTrackStep.curriculum) AddTrackStep currentStep,
    CurriculumId? curriculumId,
    List<ScopeEntry>? scopeSelections,
    int? programId,
    String? programName,
    Map<int, String>? studyDays,
    LearningProcessWizardResult? wizardResult,
    GoalFormResult? goalResult,
    String? trackLabel,
    BulkMarkResult? bulkMarkResult,
    @Default(false) bool contentActivated,
  }) = _AddTrackState;
}

/// Steps in the Add Track flow.
enum AddTrackStep {
  curriculum,
  scope,
  program,
  studyDays,
  chazaraSetup,
  goal,
  trackName,
  bulkMark,
}
