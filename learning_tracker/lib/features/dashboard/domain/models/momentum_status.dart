import 'package:freezed_annotation/freezed_annotation.dart';

part 'momentum_status.freezed.dart';

/// Personal momentum level for tracks with no explicit goal.
///
/// Semantics (from redesign analysis):
///   [gettingStarted] -- fewer than 3 completions ever (not enough data)
///   [active]         -- recent (7d) >= 80% of personal average (30d)
///   [slowing]        -- recent (7d) < 80% of personal average (30d)
///   [paused]         -- 0 completions in last 3+ days
///
/// Tone: never punishing. "Paused" not "stalled." "Slowing" not "failing."
enum MomentumLevel { gettingStarted, active, slowing, paused }

/// Momentum metrics for self-paced tracks without an explicit goal.
///
/// Measures the user against their own rhythm, not against an arbitrary
/// standard.
@freezed
abstract class MomentumStatus with _$MomentumStatus {
  const factory MomentumStatus({
    /// Completions in the last 7 days.
    required int recentCount,

    /// Average completions per 7-day window over the last 30 days.
    required double personalAverage,

    /// Current momentum level.
    required MomentumLevel level,

    /// Days since the most recent completion. Null if completed today.
    int? daysSinceLastCompletion,
  }) = _MomentumStatus;
}
