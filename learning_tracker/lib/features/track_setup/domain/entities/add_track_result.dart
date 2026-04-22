import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

part 'add_track_result.freezed.dart';

/// Result returned by [AddTrackFlow] on successful completion.
///
/// Contains all configuration gathered across the 8-step wizard.
/// Uses [Object?] for wizard/goal/bulkMark results to avoid importing
/// presentation-layer types into the domain layer (clean architecture).
@freezed
abstract class AddTrackResult with _$AddTrackResult {
  const factory AddTrackResult({
    required CurriculumId curriculumId,
    required String label,
    int? programId,
    String? programName,
    List<ScopeEntry>? scopeSelections,
    required Map<int, String> studyDays,

    /// Opaque wizard result — cast to `LearningProcessWizardResult`.
    Object? wizardResult,

    /// Opaque goal result — cast to `GoalFormResult`.
    Object? goalResult,

    /// Opaque bulk mark result — cast to `BulkMarkResult`.
    Object? bulkMarkResult,

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

    /// Full program object for reading stagesConfig metadata.
    /// Opaque Object? to avoid importing DB types into domain.
    Object? selectedProgram,
    Map<int, String>? studyDays,
    Object? wizardResult,
    Object? goalResult,
    String? trackLabel,
    Object? bulkMarkResult,
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
