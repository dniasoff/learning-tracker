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
/// ### Semantics (owner-confirmed, 2026-05-21)
///
/// **Rule:** track-based learning *is* actual app learning. Everywhere
/// except points and streak, use [trackAchievement] — bulk-mark in-track
/// counts the same as a live mark. [liveOnly] is reserved exclusively for
/// the engagement tier (points + streak).
///
/// **[liveOnly]** — Engagement tier. Includes only in-session marks
/// (not present in `prior_completion_imports`). Used **only** by
/// streak-eligibility and points-earned-per-day, where credit is awarded
/// solely for marks made live in-session. Everything else — charts,
/// counters, pace, recent activity, siyumim — uses [trackAchievement].
///
/// **[trackAchievement]** — Track-learning tier. Includes live completions
/// PLUS bulk-marks made inside a track wizard (`source = 'bulkInTrack'`).
/// The default tier for every screen, report, dashboard counter, and chart
/// except the streak calendar dots and the points-per-day chart.
///
/// **[lifetime]** — Lifetime tier. Includes ALL three sources — live,
/// bulkInTrack, and lifetimeOnly (historical imports). Used for lifetime
/// progress, ever-learned views, Lifetime Marking screen.
enum CompletionTierFilter {
  /// Engagement tier — live in-session completions only.
  ///
  /// Used for streak-eligibility and points-earned-per-day (which only
  /// credit live marks). Charts use [trackAchievement] instead.
  liveOnly,

  /// Achievement tier — live + bulk-in-track completions.
  trackAchievement,

  /// Lifetime tier — all completion sources.
  lifetime,
}
