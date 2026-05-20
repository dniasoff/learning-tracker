/// Discriminator for the three-tier completion credit policy (B1).
///
/// Each tier defines which side-effect handlers fire when a completion is
/// recorded. The hierarchy is:
///
/// ```
/// Tier              | Streak / Points | Siyumim / Reports | Lifetime data
/// ──────────────────┼─────────────────┼───────────────────┼──────────────
/// live              |       ✓         |        ✓          |      ✓
/// bulkInTrack       |       ✗         |        ✓          |      ✓
/// lifetimeOnly      |       ✗         |        ✗          |      ✓
/// ```
///
/// ### live
/// A real-time completion triggered by the learner pressing "Mark Complete"
/// during a live study session. All three handler tiers fire:
///   - Engagement: streak event written, gamification points awarded.
///   - Achievement: siyum detection, study-report indexing.
///   - Lifetime: the completion enters the learner's permanent history.
///
/// ### bulkInTrack
/// A prior-completion marked during the Add-Track or Edit-Track wizard
/// (the "I already learned this" bulk-mark step). The learner is
/// crediting themselves for past study they have already done; this
/// must NOT inflate the current streak or award points. However,
/// siyumim and reports should reflect these completions (achievement
/// tier fires). Stored with `priorMarkOnly = true` in `completion_events`.
///
/// ### lifetimeOnly
/// A lifetime historical import (e.g. migrating data from an external
/// source). Only the lifetime counter is credited; no streak, no points,
/// no siyum detection. The completion enters the learner's history but
/// does not influence any calculated metrics beyond total coverage.
enum CompletionSource {
  /// Live in-session marking — all three handler tiers fire.
  live,

  /// Bulk prior-learning marking from the track wizard — engagement
  /// handlers suppressed; achievement and lifetime handlers fire.
  bulkInTrack,

  /// Pure historical import — only lifetime handlers fire.
  lifetimeOnly,
}

/// Extension providing tier-membership predicates so consumers can gate
/// side effects without pattern-matching on the raw enum value.
extension CompletionSourceX on CompletionSource {
  /// True when engagement side effects (streak, gamification points) should
  /// fire for this source.
  ///
  /// Only [CompletionSource.live] triggers engagement credit.
  bool get creditsEngagement => this == CompletionSource.live;

  /// True when achievement side effects (siyum detection, study-report
  /// indexing) should fire for this source.
  ///
  /// Applies to [CompletionSource.live] and [CompletionSource.bulkInTrack].
  bool get creditsAchievement =>
      this == CompletionSource.live || this == CompletionSource.bulkInTrack;

  /// True when the completion should be included in lifetime-data totals.
  ///
  /// Always true — every source contributes to the learner's lifetime
  /// coverage record.
  bool get creditsLifetime => true;
}
