# Progress-percentage divergence — code analysis (run-10)

Run-9 flagged, but could not explain, a P2: *"Track progress: 0.1%" on the Progress
tab and Track Detail, while another surface showed ~3% for the same track.* This is
the code-level explanation. It matters because these are **child learning-progress
numbers** — a user reading two different answers to the same question loses trust in
all of them.

## Root cause: four live formulas, and two different denominators

`lib/features/tracks/domain/services/track_progress_service.dart:12-31` already carries
a doc comment admitting four historically divergent aggregators were *meant* to be
unified into `TrackProgressService`. They were not — at least four remain live, and
they differ on **denominator**, **tier filter**, **`since` gate**, and **`requireAllStages`**.

The denominator is the smoking gun:

| Surface | Provider | Denominator | Scope |
|---|---|---|---|
| Dashboard per-track card | `trackDualProgressMetricsProvider` | `_safeLoadLeavesForTrack` | **track's own scope** (e.g. one masechta ≈ 230) |
| Progress tab per-track row | `trackDualProgressMetricsProvider` | `_safeLoadLeavesForTrack` | **track's own scope** |
| Track Detail (dual row) | `trackDualProgressMetricsProvider` | `_safeLoadLeavesForTrack` | **track's own scope** |
| Track Detail ("Completion" row) | `dashboardTrackCompletionPercentageProvider` | `scopedItemCountProvider` | profile+curriculum, **`requireAllStages: true`**, no `since` |
| Curriculum Progress (`trackProgressFraction`) | `curriculumProgressProvider` → legacy `CurriculumProgressService.compute()` | `scopedCurriculumContentProvider` | **no tier filter at all** (counts `lifetimeOnly` too) |
| Curriculum Progress (`lifetimeFraction`) | `lifetimeDataProvider` | `_safeLoadLeaves` | **FULL curriculum, unscoped** |
| Lifetime Knowledge (both toggles) | `items_learned_providers` | `repo.getContentForCurriculum` | **FULL curriculum, unscoped** |

So for the same numerator (7 completed sections), a track scoped to one masechta reads
**≈3% (7/230)** on Dashboard/Progress-tab/Track-Detail, and **≈0.1% (7/5,846)** on
Lifetime Knowledge / Curriculum Progress's lifetime row. That is exactly the run-9
discrepancy, and `progress_screen.dart:328-330` already references the same 7/5846
pattern in a comment.

Independent numerator differences compound it:
- tier filter: `trackAchievement` everywhere **except** `CurriculumProgressService.compute()`, which applies **none**;
- `since: track.activatedAt` — only on `currentCyclePercentage`;
- `requireAllStages: true` — only on `dashboardTrackCompletionPercentageProvider`.

## Is any of it legitimate?

Partly, and that distinction must be preserved rather than "fixed" away:

- "How much of **this track's scope** have I done?" (track-scoped) and "how much of
  **the whole curriculum** do I know?" (unscoped) are genuinely different questions,
  and Lifetime Knowledge is entitled to the unscoped denominator.
- The bulk-mark interaction is likewise deliberate: bulk rows carry the sentinel
  `completedAt` (below), so they fall before `track.activatedAt` and are excluded from
  `currentCyclePercentage` but included in `lifetimePercentage`. A freshly bulk-marked
  track legitimately reads "Track progress: 0%" beside "Lifetime: 3%".

**The defect is therefore one of labelling, not arithmetic:** two different quantities
are presented under the same or near-identical wording, on screens a user moves between
in seconds. The action is to disambiguate the labels (and ideally converge the four
aggregators onto `TrackProgressService` as its own doc comment intends) — NOT to force
the numbers equal, which would break a real distinction.

## ⚠️ AMENDMENT — this framing does NOT cover every case (run-10, 5562)

The 5562 auditor found a case the paragraph above would wrongly excuse, and was right to
push back on it. On the Progress tab the ACTIVE TRACKS row for חומש reads
**"Lifetime 0%"**; tapping that very row opens Curriculum Progress, which reads
**"Lifetime 100%"** — same label, same curriculum, one tap apart, reproduced twice, with
three other screens independently confirming 100% as ground truth.

There is **no different question being answered** there. It is not a denominator serving a
distinct purpose, and it is not a labelling ambiguity: it is simply a **wrong count**, on
the screen a parent is most likely to check first.

So the rule stands only in this narrower form:

- Where two surfaces answer genuinely different questions (track-scoped vs whole-curriculum),
  **relabel — do not equalise.**
- Where two surfaces carry the **identical** label and disagree, **that is a bug**, and the
  "labelling not arithmetic" argument must not be used to wave it through.

Recorded because the original wording was broad enough to be quoted as a reason not to fix
a real defect — precisely the kind of plausible-sounding framing this campaign exists to
catch.

Related, same screen (P2): Curriculum Progress showed "Total items: 859" listing only
ויקרא against a true 5,846 — the active track's **scope** rendered unlabelled next to an
**unscoped** "Lifetime 100%" headline on the same card, so the card contradicts itself.

⚠️ Do not "fix" this by making the denominators identical. Confirm intent against
`git log`/blame and the existing tests first; this campaign has already wasted a cycle
"fixing" a deliberate design.

## Related: siyum dates showing "Jan 1, 2000"

Bulk "Mark as previously learned" writes the sentinel
`kBulkPriorSentinelDate = DateTime.utc(2000, 1, 1)`
(`lib/core/learning/completion_constants.dart:30`), via
`BulkPriorCompletionService.execute()` and `BulkMarkCompletionUseCase`. That value flows
unchanged into the `learning_ledger` row that generates a siyum, and
`SiyumimMilestonesScreen` renders `MilestoneAchievement.achievedAt` directly.

Net effect: **a siyum earned purely by bulk-marking displays as "Jan 1, 2000"** (or
Dec 31 1999 in a negative-UTC-offset zone). The sentinel itself is intentional and
load-bearing (pace/streak logic uses it to separate historical from live rows) — but
**surfacing it raw to the user as a milestone date is not**, and that is the part worth
fixing (e.g. render bulk-derived milestones without a date, or as "previously learned").
