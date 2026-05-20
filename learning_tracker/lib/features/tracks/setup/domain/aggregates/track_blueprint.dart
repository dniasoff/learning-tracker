import 'package:learning_tracker/core/domain/value_objects/program_starting_position.dart';
import 'package:learning_tracker/core/domain/value_objects/schedule_spec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/onboarding/domain/models/wizard_result_wrapper.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';

// ── GoalIntent ────────────────────────────────────────────────────────────────

/// Sealed intent: what kind of goal (if any) the user attached to this track.
///
/// Replaces the loosely-typed [GoalEntity] nullable field in [AddTrackResult].
sealed class GoalIntent {
  const GoalIntent();
}

/// No goal attached — self-paced / momentum-only track.
final class NoGoalIntent extends GoalIntent {
  const NoGoalIntent();

  @override
  String toString() => 'NoGoalIntent';
}

/// Goal specified by the user (may be deadline or pace-based).
final class SpecifiedGoalIntent extends GoalIntent {
  const SpecifiedGoalIntent({required this.goal});

  final GoalEntity goal;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpecifiedGoalIntent && other.goal == goal);

  @override
  int get hashCode => goal.hashCode;

  @override
  String toString() => 'SpecifiedGoalIntent(goal: $goal)';
}

// ── StageConfiguration ────────────────────────────────────────────────────────

/// Sealed union for the stage/chazara configuration the user chose.
sealed class StageConfiguration {
  const StageConfiguration();
}

/// No chazara stages — learn-only track.
final class SingleStageConfiguration extends StageConfiguration {
  const SingleStageConfiguration();

  @override
  String toString() => 'SingleStageConfiguration';
}

/// Multi-stage chazara schedule configured via the wizard.
final class WizardStageConfiguration extends StageConfiguration {
  const WizardStageConfiguration({required this.wizardResult});

  /// The full [LearningProcessWizardResult] wrapper (use `.wizardResult` to
  /// reach the inner [WizardResult]).
  final LearningProcessWizardResult wizardResult;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WizardStageConfiguration && other.wizardResult == wizardResult);

  @override
  int get hashCode => wizardResult.hashCode;

  @override
  String toString() => 'WizardStageConfiguration(wizardResult: $wizardResult)';
}

/// Custom schedule-spec override (advanced / non-wizard path).
final class ScheduleSpecConfiguration extends StageConfiguration {
  const ScheduleSpecConfiguration({required this.spec});

  final ScheduleSpec spec;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduleSpecConfiguration && other.spec == spec);

  @override
  int get hashCode => spec.hashCode;

  @override
  String toString() => 'ScheduleSpecConfiguration(spec: $spec)';
}

// ── BulkMarkIntent ────────────────────────────────────────────────────────────

/// Sealed intent: whether/how the user pre-marked prior completions.
///
/// The presentation-layer [BulkMarkResult] collapses to this domain intent.
sealed class TrackBulkMarkIntent {
  const TrackBulkMarkIntent();
}

/// User skipped the bulk-mark step.
final class NoBulkMarkIntent extends TrackBulkMarkIntent {
  const NoBulkMarkIntent();

  @override
  String toString() => 'NoBulkMarkIntent';
}

/// User pre-marked some sections as already completed.
final class BulkMarkedIntent extends TrackBulkMarkIntent {
  const BulkMarkedIntent({
    required this.itemCount,
    required this.completionCount,
  });

  /// Number of distinct content items marked.
  final int itemCount;

  /// Total completion records written (may exceed [itemCount] for multi-stage).
  final int completionCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BulkMarkedIntent &&
          other.itemCount == itemCount &&
          other.completionCount == completionCount);

  @override
  int get hashCode => Object.hash(itemCount, completionCount);

  @override
  String toString() =>
      'BulkMarkedIntent(itemCount: $itemCount, completionCount: $completionCount)';
}

// ── ProgramSelection ──────────────────────────────────────────────────────────

/// Sealed union for the program the user chose (or didn't).
sealed class ProgramSelection {
  const ProgramSelection();
}

/// No structured program — the track is self-paced.
final class SelfPacedSelection extends ProgramSelection {
  const SelfPacedSelection();

  @override
  String toString() => 'SelfPacedSelection';
}

/// User enrolled in a specific calendar-driven program.
final class CalendarProgramSelection extends ProgramSelection {
  const CalendarProgramSelection({
    required this.programId,
    required this.programName,
    required this.startingPosition,
    this.program,
  });

  final int programId;
  final String programName;
  final ProgramStartingPosition startingPosition;

  /// Full program data for reading stage config metadata.
  final LearningProgramData? program;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarProgramSelection &&
          other.programId == programId &&
          other.programName == programName &&
          other.startingPosition == startingPosition);

  @override
  int get hashCode => Object.hash(programId, programName, startingPosition);

  @override
  String toString() =>
      'CalendarProgramSelection(programId: $programId, '
      'programName: $programName, startingPosition: $startingPosition)';
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
class TrackBlueprint {
  const TrackBlueprint({
    required this.curriculumId,
    required this.label,
    required this.studyDays,
    required this.programSelection,
    required this.stageConfiguration,
    required this.goalIntent,
    required this.bulkMarkIntent,
    this.scopeSelections,
  });

  /// The curriculum this track is for.
  final CurriculumId curriculumId;

  /// User-provided (or auto-derived) label for the track.
  final String label;

  /// Map of ISO weekday number → day type ('study'/'skip'/etc.).
  final Map<int, String> studyDays;

  /// Scope constraints for self-paced tracks (null = entire curriculum).
  final List<ScopeEntry>? scopeSelections;

  /// Program or self-paced selection.
  final ProgramSelection programSelection;

  /// Stage/chazara configuration.
  final StageConfiguration stageConfiguration;

  /// Goal attached to the track (if any).
  final GoalIntent goalIntent;

  /// Bulk prior-completion intent (if any).
  final TrackBulkMarkIntent bulkMarkIntent;

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackBlueprint &&
          other.curriculumId == curriculumId &&
          other.label == label &&
          other.programSelection == programSelection &&
          other.stageConfiguration == stageConfiguration &&
          other.goalIntent == goalIntent &&
          other.bulkMarkIntent == bulkMarkIntent);

  @override
  int get hashCode => Object.hash(
    curriculumId,
    label,
    programSelection,
    stageConfiguration,
    goalIntent,
    bulkMarkIntent,
  );

  @override
  String toString() =>
      'TrackBlueprint(curriculumId: $curriculumId, label: $label, '
      'program: $programSelection, stages: $stageConfiguration, '
      'goal: $goalIntent, bulk: $bulkMarkIntent)';
}
