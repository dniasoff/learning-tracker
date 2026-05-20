/// Filter enum for the three-tier completion credit policy.
///
/// Controls which completion rows are included when querying aggregated
/// progress metrics. Maps to the [CompletionSource] hierarchy:
///
/// ```
/// Tier               | live | bulkInTrack | lifetimeOnly
/// ───────────────────┼──────┼─────────────┼─────────────
/// liveOnly           |  ✓   |      ✗      |      ✗
/// trackAchievement   |  ✓   |      ✓      |      ✗
/// lifetime           |  ✓   |      ✓      |      ✓
/// ```
///
/// ### Semantics (owner-confirmed)
///
/// **[liveOnly]** — Engagement tier. Includes only in-session marks
/// (not present in `prior_completion_imports`). Used for streak,
/// points, daily-activity bar charts.
///
/// **[trackAchievement]** — Achievement tier. Includes live completions
/// PLUS bulk-marks made inside a track wizard (`source = 'bulkInTrack'`).
/// Used for track-completion %, siyumim, reports, "I learnt it" displays,
/// Manage Tracks card, curriculum progress screens.
///
/// **[lifetime]** — Lifetime tier. Includes ALL three sources — live,
/// bulkInTrack, and lifetimeOnly (historical imports). Used for lifetime
/// progress, ever-learned views, Lifetime Marking screen.
enum CompletionTierFilter {
  /// Engagement tier — live in-session completions only.
  liveOnly,

  /// Achievement tier — live + bulk-in-track completions.
  trackAchievement,

  /// Lifetime tier — all completion sources.
  lifetime,
}
