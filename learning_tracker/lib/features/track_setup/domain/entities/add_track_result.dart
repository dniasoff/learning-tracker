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

    /// Opaque wizard result — cast to `LearningProcessWizardResult` in presentation.
    Object? wizardResult,

    /// Opaque goal result — cast to `GoalFormResult` in presentation.
    Object? goalResult,

    /// Opaque bulk mark result — cast to `BulkMarkResult` in presentation.
    Object? bulkMarkResult,
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
    Object? wizardResult,
    Object? goalResult,
    String? trackLabel,
    Object? bulkMarkResult,
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
