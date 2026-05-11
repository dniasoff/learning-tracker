import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

part 'schedule_config.freezed.dart';

/// Configuration for a single scheduler run.
@freezed
abstract class ScheduleConfig with _$ScheduleConfig {
  const factory ScheduleConfig({
    required CurriculumId curriculumId,

    /// The track this scheduler run is for.
    required int trackId,

    /// Display label for the track.
    required String trackLabel,

    /// Goal deadline for completing the curriculum. Null means no deadline.
    DateTime? goalDeadline,

    /// The current date (UTC) for scheduling calculations.
    required DateTime currentDate,

    /// Default number of new items per day when no deadline is set.
    @Default(5) int defaultNewItemsPerDay,

    /// Items per day for pace-based goals. Null means use deadline or default.
    double? pacePerDay,

    /// Whether today is a study day. False suppresses new learning tasks.
    @Default(true) bool isStudyDay,

    /// Number of study days per week (1-7). Used for legacy fallback pacing.
    @Default(7) int studyDaysPerWeek,

    /// Inclusive count of future study days from "today" through the goal
    /// deadline, per the track's study-day pattern. When set, deadline
    /// pacing divides remaining items by this count instead of approximating
    /// with [studyDaysPerWeek].
    int? studyDaysInDeadlineWindow,

    /// When the track was activated. Used by the self-paced new-learning
    /// path to back-fill snapshots for days the app didn't run, then to
    /// determine which prior-day items are overdue today.
    DateTime? trackStartedAt,

    /// Refs that have appeared in any prior-day snapshot for this track
    /// (including synthetic back-fill snapshots). Resolved by the
    /// repository before the engine runs. The engine uses this to:
    ///   (a) treat any uncompleted ref in this set as overdue today, and
    ///   (b) skip already-shown refs when picking today's new-learning
    ///       batch from the current ordered list.
    @Default(<String>{}) Set<String> priorlyShownRefs,
  }) = _ScheduleConfig;
}
