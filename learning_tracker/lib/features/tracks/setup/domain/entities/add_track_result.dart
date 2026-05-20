import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/onboarding/domain/models/wizard_result_wrapper.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';

part 'add_track_result.freezed.dart';

/// Typed container for bulk-mark intent collected during the AddTrackFlow.
///
/// Domain-layer counterpart to [BulkMarkResult] (presentation), carrying
/// only the counts the domain needs — avoids pulling a presentation widget
/// into the domain entity.
class BulkMarkIntent {
  const BulkMarkIntent({
    required this.itemCount,
    required this.completionCount,
  });

  /// Number of distinct content items marked.
  final int itemCount;

  /// Total completion records written (may exceed [itemCount] if multi-stage).
  final int completionCount;

  @override
  bool operator ==(Object other) =>
      other is BulkMarkIntent &&
      other.itemCount == itemCount &&
      other.completionCount == completionCount;

  @override
  int get hashCode => Object.hash(itemCount, completionCount);

  @override
  String toString() =>
      'BulkMarkIntent(itemCount: $itemCount, completionCount: $completionCount)';
}

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

    /// Stage/review schedule configuration from the chazara wizard.
    LearningProcessWizardResult? wizardResult,

    /// Goal configuration from the goal step.
    GoalEntity? goalResult,

    /// Bulk prior-completion intent from the confirmation step.
    BulkMarkIntent? bulkMarkResult,

    /// Sefaria ref for program starting position (Screen 8 program mode).
    String? startingRef,
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

    /// Full program data for reading stagesConfig metadata.
    LearningProgramData? selectedProgram,
    Map<int, String>? studyDays,
    LearningProcessWizardResult? wizardResult,
    GoalEntity? goalResult,
    String? trackLabel,
    BulkMarkIntent? bulkMarkResult,
    String? startingRef,
    @Default(false) bool contentActivated,
  }) = _AddTrackState;
}

/// Steps in the Add Track flow.
///
/// Order: Program comes BEFORE Scope — if user selects a program,
/// scope is skipped (program defines it).
enum AddTrackStep {
  curriculum, // Screen 1
  program, // Screen 2 (auto-skip if no programs)
  scope, // Screen 3 (skip if program selected)
  studyDays, // Screen 4 (program: auto-fill read-only)
  chazaraSetup, // Screen 5 (program: show or offer)
  goal, // Screen 6 (program: skip)
  trackName, // Screen 7 (program: prior learned lifetime marking)
  bulkMark, // Screen 8 (program: starting position)
}
