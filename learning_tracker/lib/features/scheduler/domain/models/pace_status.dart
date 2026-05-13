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
    /// Kept for backward compatibility — prefer [delta] for new code.
    required int daysDelta,

    /// Typed delta — use this in UI code to avoid mixing calendar days
    /// with items/week. See [ScheduleDelta] for the two sub-types:
    /// [DateScheduleDelta] (deadline goals) and [PaceScheduleDelta]
    /// (pace-rate goals).
    required ScheduleDelta delta,

    /// Projected completion date based on rolling 7-day average.
    /// Null if no completions in the last 7 days (cannot project).
    DateTime? projectedCompletionDate,

    /// Rolling 7-day average of daily completions.
    required double rollingAverage,
  }) = _PaceStatus;
}
