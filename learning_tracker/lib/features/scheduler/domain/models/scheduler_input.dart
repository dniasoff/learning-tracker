import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';

part 'scheduler_input.freezed.dart';

/// All inputs required by the scheduler before any analysis is performed.
///
/// [SchedulerInput] is a pure value type (freezed). It is constructed from
/// provider-layer data and passed into [SchedulingStrategyRunner], which
/// selects the correct [SchedulingStrategy] and drives the
/// Input → Analysis → [TaskAssembly] pipeline.
///
/// Goal-type discrimination:
/// - `pacePerDay != null && trackStartedAt != null` → [SchedulingStrategy.selfPacedSnapshot]
/// - `goalDeadline != null && pacePerDay == null`   → [SchedulingStrategy.deadlineGoal]
/// - calendar program enrolled                      → [SchedulingStrategy.programCalendar]
/// - otherwise                                      → [SchedulingStrategy.legacyAdaptive]
@freezed
abstract class SchedulerInput with _$SchedulerInput {
  const factory SchedulerInput({
    /// The curriculum being scheduled.
    required CurriculumId curriculumId,

    /// The track this run is for (0 = no specific track, used in tests).
    required int trackId,

    /// Display label for the track (e.g. 'personal').
    required String trackLabel,

    /// UTC clock value for this scheduling run.
    required DateTime today,

    /// All leaf content items for the curriculum, in sort order.
    required List<SchedulerContentItem> contentItems,

    /// All completion records visible to this track.
    required List<SchedulerCompletion> completions,

    /// Stage definitions for the curriculum, ordered by stageOrder.
    required List<SchedulerStage> stages,

    /// Target pace in leaf items (or coarse units) per day.
    /// Non-null for self-paced pace-goal tracks.
    double? pacePerDay,

    /// Coarse learning unit key (e.g. 'perek', 'daf'). When set and
    /// different from the curriculum leaf, [pacePerDay] is interpreted as
    /// coarse-unit count, not leaf count.
    String? paceGranularity,

    /// When the track was activated. Required for snapshot-based pacing.
    DateTime? trackStartedAt,

    /// Goal deadline. Non-null for deadline-goal tracks.
    DateTime? goalDeadline,

    /// True when today is a configured study day for this track.
    @Default(true) bool isStudyDay,

    /// Number of study days per week (1–7). Used for deadline pacing.
    @Default(7) int studyDaysPerWeek,

    /// Exact count of study days from today through the deadline inclusive.
    /// When set, deadline pacing uses this instead of approximating.
    int? studyDaysInDeadlineWindow,

    /// Refs that appeared in any prior-day snapshot for this track.
    /// Used by the snapshot path to identify overdue and new items.
    @Default(<String>{}) Set<String> priorlyShownRefs,

    /// Default new items per day when no pacing signal is present.
    @Default(5) int defaultNewItemsPerDay,
  }) = _SchedulerInput;
}
