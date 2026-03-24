import 'package:freezed_annotation/freezed_annotation.dart';

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
    required int daysDelta,

    /// Projected completion date based on rolling 7-day average.
    /// Null if no completions in the last 7 days (cannot project).
    DateTime? projectedCompletionDate,

    /// Rolling 7-day average of daily completions.
    required double rollingAverage,
  }) = _PaceStatus;
}
