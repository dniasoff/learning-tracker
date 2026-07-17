import 'package:freezed_annotation/freezed_annotation.dart';

part 'pace_calculator.freezed.dart';

/// Grace window in calendar days from track start during which pace status is
/// always [ProgressPaceStatus.graceWindow] regardless of actual progress.
///
/// Days 0 and 1 (elapsed days ≤ 1 since track start). From day 2 onward the
/// actual vs required velocity comparison kicks in. Decided by owner 2026-05-20.
const int kPaceGraceWindowDays = 1;

/// Canonical pace status for a track.
///
/// - [graceWindow] — within the first [kPaceGraceWindowDays] days of the
///   track; no pace judgement is applied.
/// - [onTrack] — |paceVariance| < requiredVelocity (within one day's work
///   of expected progress).
/// - [ahead] — liveProgress exceeds expected progress by more than one day's
///   required velocity.
/// - [behind] — liveProgress trails expected progress by more than one day's
///   required velocity.
enum ProgressPaceStatus { graceWindow, onTrack, ahead, behind }

/// Immutable value object that computes all pace-related metrics for a track.
///
/// ### Contract
/// ```
/// requiredVelocity      = (totalItems - bulkBaseline) / max(1, trackDays)
/// actualVelocity        = liveProgress / max(1, elapsedDays)
/// expectedProgressToday = requiredVelocity * elapsedDays
/// paceVariance          = liveProgress - expectedProgressToday
/// paceVarianceInDays    = paceVariance / max(0.001, requiredVelocity)
/// isInGraceWindow       = elapsedDays <= kPaceGraceWindowDays
/// ```
///
/// ### Bulk baseline
/// [bulkBaseline] counts completions that arrived via bulk-mark (those with a
/// sentinel `completedAt` date before [trackStartDate], typically 2000-01-01).
/// These are subtracted from the target count when computing [requiredVelocity]
/// so that pre-existing progress does not create a phantom "ahead" signal.
///
/// ### Edge cases
/// - `targetDate == trackStartDate` → [requiredVelocity] = 0 and
///   [paceVarianceInDays] = 0; no division by zero.
/// - `today == trackStartDate` (day 0) → [actualVelocity] = 0 and status is
///   always [ProgressPaceStatus.graceWindow].
///
/// ## Construction
/// The only production constructor is the computing factory
/// [ProgressPaceCalculator.compute] — [ProgressPaceCalculator._raw] is
/// library-private, so an instance with inconsistent derived fields can
/// never be constructed from outside this file. `==`/`hashCode` are
/// freezed-generated from all fields (inputs + derived); `toString` is
/// hand-written for a compact debug representation.
@Freezed(map: FreezedMapOptions.none, when: FreezedWhenOptions.none)
abstract class ProgressPaceCalculator with _$ProgressPaceCalculator {
  const ProgressPaceCalculator._();

  // ---------------------------------------------------------------------------
  // Private constructor — all fields pre-computed. Reached only via
  // [ProgressPaceCalculator.compute].
  // ---------------------------------------------------------------------------

  const factory ProgressPaceCalculator._raw({
    // -------------------------------------------------------------------------
    // Inputs
    // -------------------------------------------------------------------------

    /// Total number of items in the track (e.g. total mishnayos).
    required int totalItems,

    /// Items completed before [trackStartDate] via bulk-mark (sentinel date).
    required int bulkBaseline,

    /// Items completed on or after [trackStartDate] (live progress).
    required int liveProgress,

    /// The date the track was created/configured by the user (local-day
    /// midnight).
    required DateTime trackStartDate,

    /// The user-set finish date (local-day midnight).
    required DateTime targetDate,

    /// Today's date (local-day midnight).
    required DateTime today,

    // -------------------------------------------------------------------------
    // Derived fields — computed once in [ProgressPaceCalculator.compute]
    // -------------------------------------------------------------------------

    /// Items to complete per calendar day to finish on [targetDate].
    ///
    /// 0.0 when [targetDate] == [trackStartDate] (degenerate range).
    required double requiredVelocity,

    /// Items completed per calendar day since [trackStartDate].
    ///
    /// 0.0 when [today] == [trackStartDate] (day 0 — no elapsed time).
    required double actualVelocity,

    /// How many items should have been done by today at the required
    /// velocity.
    required double expectedProgressToday,

    /// Signed difference between live progress and expected progress.
    ///
    /// Positive = ahead of schedule. Negative = behind schedule.
    required double paceVariance,

    /// [paceVariance] expressed in calendar days.
    ///
    /// Positive = ahead, negative = behind. 0.0 when [requiredVelocity] is 0.
    required double paceVarianceInDays,

    /// True when the track is within the [kPaceGraceWindowDays] window.
    required bool isInGraceWindow,

    /// The overall pace status derived from the inputs and computed fields.
    required ProgressPaceStatus paceStatus,
  }) = _ProgressPaceCalculator;

  // ---------------------------------------------------------------------------
  // Factory constructor — performs all computation
  // ---------------------------------------------------------------------------

  /// Compute pace metrics for a track.
  ///
  /// [totalItems]      — total items in the track scope.
  /// [bulkBaseline]    — items already done before [trackStartDate] (bulk-mark
  ///                     sentinel completions; these do not count towards live
  ///                     velocity).
  /// [liveProgress]    — items completed on or after [trackStartDate].
  /// [trackStartDate]  — date the track was configured (local-day midnight).
  /// [targetDate]      — user-set finish date (local-day midnight).
  /// [today]           — today's local-day midnight.
  factory ProgressPaceCalculator.compute({
    required int totalItems,
    required int bulkBaseline,
    required int liveProgress,
    required DateTime trackStartDate,
    required DateTime targetDate,
    required DateTime today,
  }) {
    // Number of calendar days in the full track window.
    final trackDays = targetDate.difference(trackStartDate).inDays;

    // Required velocity: items left after bulk baseline divided by track days.
    // Guard: when targetDate == trackStartDate, set to 0 (degenerate range).
    // Clamped to 0 when bulkBaseline > totalItems (over-marked prior learning).
    final requiredVelocity = trackDays > 0
        ? ((totalItems - bulkBaseline) / trackDays).clamp(0.0, double.infinity)
        : 0.0;

    // Elapsed days since track start (0 on day 1).
    final elapsedDays = today.difference(trackStartDate).inDays;

    // Actual velocity: live completions per elapsed day.
    // Guard: day 0 → 0.0.
    final actualVelocity = elapsedDays > 0 ? liveProgress / elapsedDays : 0.0;

    // Expected progress: how far along we should be today at required velocity.
    final expectedProgressToday = requiredVelocity * elapsedDays;

    // Signed variance: positive = ahead, negative = behind.
    final paceVariance = liveProgress - expectedProgressToday;

    // Variance in calendar days.
    // Guard: requiredVelocity == 0 → no meaningful days-variance.
    final paceVarianceInDays = requiredVelocity > 0
        ? paceVariance / requiredVelocity
        : 0.0;

    // Grace window: first kPaceGraceWindowDays days (elapsedDays <= threshold).
    final isInGraceWindow = elapsedDays <= kPaceGraceWindowDays;

    // Derive pace status.
    final ProgressPaceStatus paceStatus;
    if (isInGraceWindow) {
      paceStatus = ProgressPaceStatus.graceWindow;
    } else if (paceVariance > requiredVelocity) {
      paceStatus = ProgressPaceStatus.ahead;
    } else if (paceVariance < -requiredVelocity) {
      paceStatus = ProgressPaceStatus.behind;
    } else {
      paceStatus = ProgressPaceStatus.onTrack;
    }

    return ProgressPaceCalculator._raw(
      totalItems: totalItems,
      bulkBaseline: bulkBaseline,
      liveProgress: liveProgress,
      trackStartDate: trackStartDate,
      targetDate: targetDate,
      today: today,
      requiredVelocity: requiredVelocity,
      actualVelocity: actualVelocity,
      expectedProgressToday: expectedProgressToday,
      paceVariance: paceVariance,
      paceVarianceInDays: paceVarianceInDays,
      isInGraceWindow: isInGraceWindow,
      paceStatus: paceStatus,
    );
  }

  // ---------------------------------------------------------------------------
  // toString — freezed generates == and hashCode from all fields above;
  // this custom override is kept for a compact, fixed-precision debug
  // representation.
  // ---------------------------------------------------------------------------

  @override
  String toString() =>
      'ProgressPaceCalculator('
      'totalItems: $totalItems, '
      'bulkBaseline: $bulkBaseline, '
      'liveProgress: $liveProgress, '
      'requiredVelocity: ${requiredVelocity.toStringAsFixed(4)}, '
      'actualVelocity: ${actualVelocity.toStringAsFixed(4)}, '
      'paceVariance: ${paceVariance.toStringAsFixed(4)}, '
      'paceVarianceInDays: ${paceVarianceInDays.toStringAsFixed(2)}, '
      'paceStatus: $paceStatus'
      ')';
}
