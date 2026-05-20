import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';

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
class AddTrackDraft {
  const AddTrackDraft({
    required this.navStepIndex,
    this.curriculumKey,
    this.scopeSelectionsJson,
    this.programId,
    this.programName,
    this.studyDays,
    this.trackLabel,
  });

  /// Navigation position, corresponding to the [AddTrackStep] ordinal.
  final int navStepIndex;

  /// [CurriculumId.storageKey] of the selected curriculum, or `null`.
  final String? curriculumKey;

  /// JSON-encoded list of scope entries (serialised from [ScopeEntry]), or null.
  final String? scopeSelectionsJson;

  /// Program id if a calendar program was selected, or `null`.
  final int? programId;

  /// Human-readable program name if a program was selected.
  final String? programName;

  /// Study-day config as a `{isoWeekday: dayType}` map, or null.
  final Map<int, String>? studyDays;

  /// User-entered track label, or `null`.
  final String? trackLabel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AddTrackDraft &&
          other.navStepIndex == navStepIndex &&
          other.curriculumKey == curriculumKey &&
          other.programId == programId &&
          other.programName == programName &&
          other.trackLabel == trackLabel);

  @override
  int get hashCode => Object.hash(
    navStepIndex,
    curriculumKey,
    programId,
    programName,
    trackLabel,
  );

  @override
  String toString() =>
      'AddTrackDraft(step: $navStepIndex, curriculum: $curriculumKey, '
      'program: $programId, label: $trackLabel)';
}
