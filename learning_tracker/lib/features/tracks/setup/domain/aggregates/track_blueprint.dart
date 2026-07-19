import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/domain/value_objects/program_starting_position.dart';
import 'package:learning_tracker/core/domain/value_objects/schedule_spec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/onboarding/domain/models/wizard_result_wrapper.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';

part 'track_blueprint.freezed.dart';

// ── GoalIntent ────────────────────────────────────────────────────────────────

/// Sealed intent: what kind of goal (if any) the user attached to this track.
///
/// Replaces the loosely-typed [GoalEntity] nullable field in [AddTrackResult].
@freezed
sealed class GoalIntent with _$GoalIntent {
  /// No goal attached — self-paced / momentum-only track.
  const factory GoalIntent.none() = NoGoalIntent;

  /// Goal specified by the user (may be deadline or pace-based).
  const factory GoalIntent.specified({required GoalEntity goal}) =
      SpecifiedGoalIntent;
}

// ── StageConfiguration ────────────────────────────────────────────────────────

/// Sealed union for the stage/chazara configuration the user chose.
@freezed
sealed class StageConfiguration with _$StageConfiguration {
  /// No chazara stages — learn-only track.
  const factory StageConfiguration.single() = SingleStageConfiguration;

  /// Multi-stage chazara schedule configured via the wizard.
  ///
  /// [wizardResult] is the full [LearningProcessWizardResult] wrapper (use
  /// `.wizardResult` to reach the inner `WizardResult`).
  const factory StageConfiguration.wizard({
    required LearningProcessWizardResult wizardResult,
  }) = WizardStageConfiguration;

  /// Custom schedule-spec override (advanced / non-wizard path).
  const factory StageConfiguration.scheduleSpec({required ScheduleSpec spec}) =
      ScheduleSpecConfiguration;
}

// ── BulkMarkIntent ────────────────────────────────────────────────────────────

/// Sealed intent: whether/how the user pre-marked prior completions.
///
/// The presentation-layer [BulkMarkResult] collapses to this domain intent.
@freezed
sealed class TrackBulkMarkIntent with _$TrackBulkMarkIntent {
  /// User skipped the bulk-mark step.
  const factory TrackBulkMarkIntent.none() = NoBulkMarkIntent;

  /// User pre-marked some sections as already completed.
  ///
  /// [itemCount] is the number of distinct content items marked;
  /// [completionCount] is the total completion records written (may exceed
  /// [itemCount] for multi-stage).
  const factory TrackBulkMarkIntent.marked({
    required int itemCount,
    required int completionCount,
  }) = BulkMarkedIntent;
}

// ── ProgramSelection ──────────────────────────────────────────────────────────

/// Sealed union for the program the user chose (or didn't).
@freezed
sealed class ProgramSelection with _$ProgramSelection {
  /// No structured program — the track is self-paced.
  const factory ProgramSelection.selfPaced() = SelfPacedSelection;

  /// User enrolled in a specific calendar-driven program.
  ///
  /// [program] carries the full program data for reading stage config
  /// metadata.
  const factory ProgramSelection.calendar({
    required int programId,
    required String programName,
    required ProgramStartingPosition startingPosition,
    LearningProgramData? program,
  }) = CalendarProgramSelection;
}

// ── TrackBlueprint aggregate ──────────────────────────────────────────────────

/// Typed aggregate capturing every decision made in the Add Track wizard.
///
/// Replaces the loosely-typed [AddTrackResult] / [AddTrackState] pattern:
///  - [Object?] fields → sealed VOs ([GoalIntent], [StageConfiguration],
///    [TrackBulkMarkIntent], [ProgramSelection])
///  - String `startingRef` grammar → [ProgramStartingPosition] VO (B2/B3)
///
/// [ProvisionTrackUseCase] consumes a [TrackBlueprint] and uses its typed
/// fields to build the correct DB writes without inspecting raw strings.
@freezed
abstract class TrackBlueprint with _$TrackBlueprint {
  const TrackBlueprint._();

  const factory TrackBlueprint({
    /// The curriculum this track is for.
    required CurriculumId curriculumId,

    /// User-provided (or auto-derived) label for the track.
    required String label,

    /// Map of ISO weekday number → day type ('study'/'skip'/etc.).
    required Map<int, String> studyDays,

    /// Program or self-paced selection.
    required ProgramSelection programSelection,

    /// Stage/chazara configuration.
    required StageConfiguration stageConfiguration,

    /// Goal attached to the track (if any).
    required GoalIntent goalIntent,

    /// Bulk prior-completion intent (if any).
    required TrackBulkMarkIntent bulkMarkIntent,

    /// Scope constraints for self-paced tracks (null = entire curriculum).
    List<ScopeEntry>? scopeSelections,
  }) = _TrackBlueprint;

  /// True when a structured calendar program was selected.
  bool get isCalendarProgram => programSelection is CalendarProgramSelection;

  /// Convenience accessor: program id, or null for self-paced.
  int? get programId => switch (programSelection) {
    CalendarProgramSelection(:final programId) => programId,
    SelfPacedSelection() => null,
  };

  /// Convenience: the chosen starting position when a program is selected.
  ProgramStartingPosition? get startingPosition => switch (programSelection) {
    CalendarProgramSelection(:final startingPosition) => startingPosition,
    SelfPacedSelection() => null,
  };

  /// Bridge: convert from the legacy [AddTrackResult] for gradual migration.
  ///
  /// Uses [today] to parse the `startingRef` grammar into a
  /// [ProgramStartingPosition] VO. Once all callers are migrated to emit a
  /// [TrackBlueprint] directly this factory can be removed.
  factory TrackBlueprint.fromLegacyResult(
    AddTrackResult result, {
    required DateTime today,
  }) {
    final programId = result.programId;
    final programSelection = programId != null
        ? CalendarProgramSelection(
            programId: programId,
            programName: result.programName ?? '',
            startingPosition: ProgramStartingPosition.fromLegacyGrammar(
              rawStartingRef: result.startingRef,
              today: today,
            ),
          )
        : const SelfPacedSelection();

    final StageConfiguration stageConfiguration;
    final wizardResultWrapper = result.wizardResult;
    if (wizardResultWrapper != null) {
      stageConfiguration = WizardStageConfiguration(
        wizardResult: wizardResultWrapper,
      );
    } else {
      stageConfiguration = const SingleStageConfiguration();
    }

    final GoalIntent goalIntent;
    final goalResult = result.goalResult;
    if (goalResult != null) {
      goalIntent = SpecifiedGoalIntent(goal: goalResult);
    } else {
      goalIntent = const NoGoalIntent();
    }

    final TrackBulkMarkIntent bulkMarkIntent;
    final bulkResult = result.bulkMarkResult;
    if (bulkResult != null) {
      bulkMarkIntent = BulkMarkedIntent(
        itemCount: bulkResult.itemCount,
        completionCount: bulkResult.completionCount,
      );
    } else {
      bulkMarkIntent = const NoBulkMarkIntent();
    }

    return TrackBlueprint(
      curriculumId: result.curriculumId,
      label: result.label,
      studyDays: result.studyDays,
      scopeSelections: result.scopeSelections,
      programSelection: programSelection,
      stageConfiguration: stageConfiguration,
      goalIntent: goalIntent,
      bulkMarkIntent: bulkMarkIntent,
    );
  }
}
