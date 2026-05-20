import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';

/// Result of a "next reward" selection — the closest reward milestone
/// the user has not yet unlocked.
class NextRewardResult {
  const NextRewardResult({
    required this.trackId,
    required this.trackPoints,
    required this.threshold,
    required this.title,
    required this.isGlobal,
  });

  final int trackId;

  /// Progress numerator: per-track points or global total when [isGlobal].
  final int trackPoints;
  final int threshold;
  final String title;
  final bool isGlobal;
}

/// Selects the single closest upcoming reward milestone for a child profile.
///
/// Operates on already-loaded milestone + points data (no DB / Riverpod
/// dependencies here) so that the logic is unit-testable without mocks.
///
/// Algorithm: iterate all per-track and global milestones; for each enabled
/// milestone whose threshold has not been reached, compute the gap
/// `threshold − progressPoints`.  Return the milestone with the smallest gap.
class NextRewardSelector {
  const NextRewardSelector();

  /// Selects the next unearned milestone across per-track and global milestones.
  ///
  /// [trackEntries] — list of `(trackId, points, milestones)` tuples.
  /// [globalPoints] — the profile's global points total for rewards.
  /// [globalMilestones] — milestones that apply to the global total.
  ///
  /// Returns `null` when all milestones are already earned or none exist.
  NextRewardResult? select({
    required List<TrackMilestoneEntry> trackEntries,
    required int globalPoints,
    required List<RewardMilestone> globalMilestones,
  }) {
    NextRewardResult? best;
    var bestGap = 1 << 30;

    void consider({
      required int trackId,
      required int progressPoints,
      required int threshold,
      required String title,
      required bool isGlobal,
    }) {
      if (progressPoints >= threshold) return;
      final gap = threshold - progressPoints;
      if (gap < bestGap) {
        bestGap = gap;
        best = NextRewardResult(
          trackId: trackId,
          trackPoints: progressPoints,
          threshold: threshold,
          title: title,
          isGlobal: isGlobal,
        );
      }
    }

    for (final entry in trackEntries) {
      for (final m in entry.milestones) {
        if (!m.isEnabled) continue;
        consider(
          trackId: entry.trackId,
          progressPoints: entry.points,
          threshold: m.thresholdPoints,
          title: m.title,
          isGlobal: false,
        );
      }
    }

    for (final m in globalMilestones) {
      if (!m.isEnabled) continue;
      consider(
        trackId: RewardMilestone.kGlobalTrackSentinel,
        progressPoints: globalPoints,
        threshold: m.thresholdPoints,
        title: m.title,
        isGlobal: true,
      );
    }

    return best;
  }
}

/// A single track's points + milestones bundle, used as input to
/// [NextRewardSelector.select].
class TrackMilestoneEntry {
  const TrackMilestoneEntry({
    required this.trackId,
    required this.points,
    required this.milestones,
  });

  final int trackId;
  final int points;
  final List<RewardMilestone> milestones;
}
