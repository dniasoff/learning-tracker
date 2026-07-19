import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';

part 'track_blueprint_draft_repository.freezed.dart';

/// Persists the in-progress [AddTrackState] wizard draft across restarts.
///
/// Replaces the 7 ad-hoc SharedPreferences keys written directly by
/// [AddTrackController] (_kStep, _kCurriculum, _kScope, _kProgram,
/// _kProgramName, _kStudyDays, _kLabel) with a single repository boundary
/// so the presentation controller is not coupled to storage mechanics.
///
/// ### Intentional scope
/// Only the fields needed to resume an interrupted wizard session are stored.
/// Complex transient objects (wizardResult, goalResult, bulkMarkResult,
/// startingRef, selectedProgram) are NOT persisted — if the user restarts
/// mid-wizard those steps re-play from scratch, which is the acceptable UX.
abstract interface class TrackBlueprintDraftRepository {
  /// Persist the wizard draft.
  ///
  /// Implementations MUST be idempotent and fire-and-forget safe — callers
  /// do not await an error and there is no rollback path.
  Future<void> saveDraft(AddTrackDraft draft);

  /// Load the most recently saved draft, or `null` if none exists.
  Future<AddTrackDraft?> loadDraft();

  /// Clear any saved draft (called on successful submission or explicit abort).
  Future<void> clearDraft();
}

/// The subset of wizard state that survives an app restart.
///
/// Fields that cannot be safely serialised (Freezed/deep objects) are omitted;
/// the wizard re-collects them from scratch when the user continues.
@freezed
abstract class AddTrackDraft with _$AddTrackDraft {
  const factory AddTrackDraft({
    /// Navigation position, corresponding to the [AddTrackStep] ordinal.
    required int navStepIndex,

    /// [CurriculumId.storageKey] of the selected curriculum, or `null`.
    String? curriculumKey,

    /// JSON-encoded list of scope entries (serialised from [ScopeEntry]), or
    /// null.
    String? scopeSelectionsJson,

    /// Program id if a calendar program was selected, or `null`.
    int? programId,

    /// Human-readable program name if a program was selected.
    String? programName,

    /// Study-day config as a `{isoWeekday: dayType}` map, or null.
    Map<int, String>? studyDays,

    /// User-entered track label, or `null`.
    String? trackLabel,
  }) = _AddTrackDraft;
}
