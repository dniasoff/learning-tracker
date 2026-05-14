import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/features/scheduler/domain/models/delta_value.dart';

part 'pace_status.freezed.dart';

/// Status of a user's learning pace relative to their goal.
enum PaceStatusType { ahead, onPace, behind }

/// Result of a pace calculation for a curriculum goal.
@freezed
abstract class PaceStatus with _$PaceStatus {
  const factory PaceStatus({
    /// Whether the user is ahead, on-pace, or behind.
    required PaceStatusType status,

    /// For deadline goals: number of days ahead (+) or behind (−) schedule.
    /// For pace goals: weekly item surplus (+) or deficit (−), i.e.
    /// `((rollingAverage − targetPacePerDay) * 7).round()`.
    /// Zero when on-pace.
    ///
    /// Deprecated in favour of [delta]. UIs MUST switch on [delta] to render
    /// a correct label — [daysDelta] is ambiguous between calendar-days and
    /// items-per-week.
    required int daysDelta,

    /// Typed delta: [DateScheduleDelta] for deadline goals (calendar days),
    /// [PaceScheduleDelta] for pace goals (items per week).
    ///
    /// UIs MUST pattern-match on this to display the correct unit label.
    /// [daysDelta] carries the raw integer for backward compatibility only.
    required ScheduleDelta delta,

    /// Projected completion date based on rolling 7-day average.
    /// Null if no completions in the last 7 days (cannot project).
    DateTime? projectedCompletionDate,

    /// Rolling 7-day average of daily completions.
    required double rollingAverage,
  }) = _PaceStatus;
}
