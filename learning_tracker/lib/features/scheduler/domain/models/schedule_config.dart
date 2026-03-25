import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

part 'schedule_config.freezed.dart';

/// Configuration for a single scheduler run.
@freezed
abstract class ScheduleConfig with _$ScheduleConfig {
  const factory ScheduleConfig({
    required CurriculumId curriculumId,

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

    /// Number of study days per week (1-7). Used by pace calculation.
    @Default(7) int studyDaysPerWeek,
  }) = _ScheduleConfig;
}
