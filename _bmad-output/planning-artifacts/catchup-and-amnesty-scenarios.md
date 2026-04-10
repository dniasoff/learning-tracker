---
title: Catch-up & Amnesty Scenarios
author: Mary (BMAD Business Analyst)
created: 2026-04-10
updated: 2026-04-10
status: draft-v2 (all 20 open questions resolved)
purpose: Define every scenario in which a learner is out of sync with their schedule, and the UX/data response the app should offer. Serves as input to an upcoming epic and to WDS UX design work.
consumers:
  - WDS UX design (downstream)
  - Epic & story planning (PM/Architect)
  - Engineering (data model + notifications)
related:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/ux-design-specification.md
  - learning_tracker/lib/features/scheduler/domain/services/pace_calculator.dart
  - learning_tracker/lib/core/database/tables/completions.dart
  - learning_tracker/lib/core/database/tables/stage_definitions.dart
  - learning_tracker/lib/core/database/daos/track_dao.dart
---

# Catch-up & Amnesty Scenarios

## 0. Executive Summary

The Learning Tracker already has a strong data foundation for handling messy learning states: append-only completions, stage-tagged reviews, track-scoped goals, and a working `PaceCalculator`. What it lacks is a coherent model for **how learners recover from being out of sync**, and the UX surfaces that express that model.

This document defines that model. Its central claim is that there are **two fundamentally different recovery mechanisms** — *rescope* and *amnesty* — and that every catch-up scenario in the app is ultimately a combination of those two verbs, applied per track, with per-track settings.

The document delivers:

- A vocabulary and governing principle (Section 1)
- Data model additions required to express amnesty cleanly (Section 2)
- A treatment of multi-track dynamics as a first-class concern (Section 3)
- **15 named, narratively-grounded scenarios** covering the full problem space (Section 4)
- An exhaustive decision grid that maps any possible state combination to the applicable scenarios (Section 5)
- A notification philosophy that flows from the recovery model (Section 6)
- A stub surface inventory — kept deliberately light because WDS will own the UX design (Section 7)
- A resolved decisions log recording how each open question was answered (Section 8)

This document does not design the UI. It defines the *problem space* in enough detail that the UX designers (via WDS) and the engineering team can work in parallel with shared understanding.

**v2 changes**: all 20 open questions from v1 resolved; Scenario 15 (Personal Track Retrofit) added; quiet-window concept absorbed into the Pause mechanism; "time budget" concept removed in favour of per-track pace derived from goals; migration section removed (greenfield product).

---

## 1. Foundations

### 1.1 The Central Insight: Two Modes

There are two fundamentally different kinds of learning track, distinguished by **who owns the schedule**:

**Self-paced tracks** — the learner owns the schedule. Goals and pace targets are promises to oneself, adjustable at will. When a self-paced learner falls behind, the natural recovery is to **redraw the line**: the past-due items aren't gone, they're simply re-anchored to a new pace baseline. Nothing is "missed" — the plan is what the learner says it is.

**Program tracks** — an external authority owns the schedule. Daf Yomi is the canonical example: a global cycle that moves forward every day whether any individual studies or not. Yeshiva curricula, structured tutor sessions, and bounded cohort programs all share this property. When a program learner falls behind, they *literally cannot catch up* to where the program is *and* complete everything the program prescribed — the calendar has moved. Their only meaningful recovery is to decide what to do about specific missed items: do them out of band, or **formally decline them** for this cycle.

These two modes need two completely different verbs:

| Mode | Recovery verb | What it does | Data effect |
|---|---|---|---|
| Self-paced | **Rescope** | Resets the pace baseline or deadline. All not-yet-done items remain in the plan, just on a new clock. | Updates `paceResetDate` and/or `targetDate` on the track. No completion records change. |
| Program | **Amnesty** | Formally declines specific items or stages for this cycle. They disappear from catch-up counts and reminders but remain in the data as explicitly skipped. | Creates `item_amnesty` records. No completion records change. |

Both mechanisms are available on both modes — a self-paced learner *can* amnesty specific items they don't want to do, and a program learner *can* technically rescope (though it usually means disconnecting from the program). But each mode has a **primary** recovery verb that the UX should lead with.

### 1.2 The Governing Principle

> **Data is sacred. Salience is negotiable.**

The completion log is ground truth forever. What changes with rescope and amnesty is not the data but **what the app surfaces and how it counts**:

- Completions are never deleted or backdated.
- Amnesty records are additive metadata, not mutations.
- Rescope moves a baseline; nothing in history is rewritten.
- A learner can always answer the question "what did I skip and when?" — amnesty is visible and revocable.
- A learner can always answer the question "what have I actually learned?" — the ledger is lifetime.

This principle has a direct emotional consequence: **the app must never force a learner to delete or lose anything in order to stop feeling behind.** Amnesty is a visibility decision, not a destructive one.

### 1.3 Vocabulary

Terms used consistently throughout this document and in downstream epic/story work:

| Term | Definition |
|---|---|
| **Rescope** | Resetting the pace or deadline baseline on a self-paced track so "behind" is recomputed from a new anchor. Non-destructive. Surfaced in the learner-facing UI as "rescope"; implemented in code via the existing `TrackDao.resetPace` primitive, wrapped by a service layer that carries the semantic meaning. |
| **Amnesty** | Marking a specific item (or a specific stage of an item) as "declined in this cycle." The item remains in the data, but is excluded from debt calculations and reminders. Revocable. Amnesty does **not** trigger any notification silence — it is a surgical data decision. |
| **Debt** | The quantifiable gap between expected state and actual state on a track. Two independent flavors: **learning debt** (items the schedule expected but the learner hasn't completed) and **review debt** (chazara stages that are overdue and not amnestied). |
| **Cycle** | A time-bounded period within which amnesty applies. For Daf Yomi, a cycle is ~7.5 years. For self-paced tracks, a cycle is implicit or user-defined. New cycles reset the amnesty frame via an auto-fresh-slate default and a cycle-boundary welcome flow. |
| **Pause** | A first-class track state (distinct from Archive) where the learner deliberately silences a track for a chosen duration. Replaces the earlier "quiet window" concept — if a learner wants notification silence, they pause. Auto-resumes on expiry with a gentle welcome-back. |
| **Archive** | A track state indicating the learner considers the track finished or permanently stopped. Ledger and completions preserved. Reviving requires explicit action. Distinct from Pause. |
| **Catch-up plan** | A concrete, time-bounded recommendation (e.g., "do 2 dapim a day for the next week") that closes learning debt without rescoping or amnesty. |
| **Triage** | A multi-track workflow where the learner handles multiple out-of-sync tracks in one session, applying per-track rescope/amnesty/archive decisions efficiently. Triage order: program tracks first (amnesty decisions), ordered within by smallest debt first (quick wins). |
| **Coverage Map** | Internal name for the gap-visualization view (from Scenario 8). The **learner-facing label is "Learning Journey."** |
| **Setup Seeding flow** | The onboarding surface used when a learner creates a new track with pre-existing learning state. Per-item choices of learned / amnesty / defer. Used by Scenario 14 (Program Launch Day) and Scenario 15 (Personal Track Retrofit). Replaces the clunky existing "mark done" bulk flow. |
| **Chazara** | Review — the post-initial-learning repetitions defined by stage definitions. |

### 1.4 Why This Can't Just Be a UI Fix

It is tempting to frame all of this as "the dashboard needs to stop showing the demoralizing 'X days behind' counter." That would be a mistake. The current UI is honest about the underlying state — the problem is that the underlying model has no way to express the learner's *intent* about missed work. Without amnesty as a first-class concept, there's no way for the app to know which misses matter and which the learner has consciously decided to let go. A cosmetic fix would hide the symptom while the debt keeps growing invisibly.

This is why the document starts with data model changes: the UX work downstream only becomes possible once the data can express "I decided not to do this."

---

## 2. Data Model Implications

### 2.1 New Entity: `item_amnesty`

A new table records amnesty decisions. Proposed shape:

```
item_amnesty
  id                INTEGER PK AUTOINCREMENT
  profile_id        TEXT NOT NULL
  track_id          INTEGER NOT NULL FK -> curriculum_tracks.id
  curriculum_id     TEXT NOT NULL    -- denormalized for query efficiency
  sefaria_ref       TEXT NOT NULL    -- the item being amnestied
  stage_id          INTEGER NULL     -- NULL = amnesty ALL stages of this item
                                     -- non-null = amnesty only this specific stage
  cycle_tag         TEXT NULL        -- e.g., "daf-yomi-cycle-14"; null for self-paced
  amnestied_at      DATETIME NOT NULL
  reason            TEXT NULL        -- optional user note or system tag
                                     -- e.g., "too advanced", "missed-traveling", "bulk-amnesty"
  revoked_at        DATETIME NULL    -- soft delete for "unforgive"
  source            TEXT NOT NULL    -- "user_manual" | "bulk_rescope" | "cycle_boundary" | "triage"

  UNIQUE (track_id, sefaria_ref, stage_id, cycle_tag) WHERE revoked_at IS NULL
```

Key design notes:

- **Per-stage granularity.** A learner might mark a review (chazara stage 2) as "not doing," while keeping the initial learning. `stage_id = NULL` means "amnesty the whole item including all reviews"; a specific `stage_id` scopes the amnesty to that stage only.
- **Cycle scoping.** For program tracks, amnesty should be bounded to the current cycle — so when a new Daf Yomi cycle starts, the learner gets a fresh slate (or can explicitly carry forward). `cycle_tag` makes this explicit.
- **Soft delete via `revoked_at`.** "Unforgive" is a first-class action — a learner can change their mind and put an item back in their queue.
- **Audit trail in `source`.** Distinguishes learner-initiated amnesty from system-initiated amnesty (e.g., from a bulk triage flow or an automatic cycle-boundary sweep).

### 2.2 Extend: `curriculum_tracks` with per-track settings

Recovery behavior must be configurable per track. Per-track settings are added as columns on `curriculum_tracks` directly (no separate `track_settings` table — see §8 decision Q6):

```
curriculum_tracks
  ... existing columns ...

  catchup_mode              TEXT NOT NULL DEFAULT <derived from track_type>
                                -- "rescope" | "amnesty" | "hybrid"
                                -- default: rescope for personal, amnesty for school/tutor
  show_behind_counter       INTEGER NOT NULL DEFAULT 1     -- bool; learner can disable the "X days behind" surface
  pace_sensitivity_days     INTEGER NOT NULL DEFAULT 3     -- threshold before "behind" messaging kicks in
  review_strictness         TEXT NOT NULL DEFAULT 'relaxed'  -- "strict" | "relaxed"
  notification_cadence      TEXT NOT NULL DEFAULT <derived from goal state>
                                -- "daily" | "weekly" | "silent"
                                -- default: 'daily' if track has an active goal,
                                --          'silent' if momentum-only
  auto_rescope              INTEGER NOT NULL DEFAULT 0     -- bool; self-paced only — auto-reset pace on threshold
  paused_at                 DATETIME NULL                  -- when the learner paused the track
  paused_until              DATETIME NULL                  -- when the pause auto-resumes (NULL = indefinite)
  current_cycle_tag         TEXT NULL                      -- active cycle identifier (for program tracks)
  primary_unit_type         TEXT NULL                      -- optional per-track override of curriculum's
                                                           --   default primary_unit_type
                                                           --   (e.g., a children's Bavli track sets this
                                                           --    to 'perek' instead of the curriculum default 'masechta')
```

**Important**: no `quiet_window_days` column. The quiet-window concept is absorbed entirely into the **Pause** mechanism — if a learner wants notification silence, they pause the track. Amnesty and rescope do **not** trigger any notification silence; they just change what the debt computations return.

These settings let each track express its own personality:

- A disciplined Daf Yomi learner: `catchup_mode = amnesty`, `pace_sensitivity_days = 1`, `notification_cadence = daily`, `show_behind_counter = 1`.
- A casual self-paced learner who hates being nagged: `catchup_mode = rescope`, `pace_sensitivity_days = 7`, `notification_cadence = silent`, `auto_rescope = 1`, `show_behind_counter = 0`.
- A children's Mishnayos track at a yeshiva: `catchup_mode = amnesty`, `primary_unit_type = 'perek'` (override from the curriculum default of `seder`), `review_strictness = strict`.

Track-type still provides defaults for `catchup_mode` and related settings, but the learner (or the onboarding flow) can override any setting per track. The same curriculum in different tracks can behave completely differently.

### 2.3 Computed View: `TrackDebt`

A struct (not a table — computed on demand in the provider layer) that represents a track's current out-of-sync state, respecting amnesty and settings:

```
class TrackDebt {
  int learningDebt;              // count of expected-but-not-done items, minus amnestied
  List<ReviewGap> reviewDebt;    // overdue chazara, minus amnestied per-stage
  List<ContentGap> orderGaps;    // contiguous missing ranges in learning sequence
  int daysBehind;                // PaceCalculator output, respecting amnesty
  int daysDormant;               // days since last completion or recovery action
  int amnestiedThisCycle;        // total stage-scoped amnesty records active
  DateTime? lastActionAt;        // last rescope or amnesty timestamp
  ScenarioMatch primaryScenario; // which named scenario best describes current state
}
```

The primary scenario match is how the UI knows which surface to lead with — it's the output of the decision tree in Section 5.

### 2.4 Track Action Log (optional, recommended)

A lightweight audit trail of rescope/amnesty actions. Not strictly required for the recovery model, but valuable for:

- Undo workflows (the learner changes their mind within a session)
- Visibility ("what did I do to this track, and when?")
- Debugging & support (why does this track say what it says?)
- Analytics (which recovery actions are learners actually using?)

```
track_action_log
  id              INTEGER PK
  profile_id      TEXT NOT NULL
  track_id        INTEGER NOT NULL
  action_type     TEXT NOT NULL  -- "rescope" | "amnesty_item" | "amnesty_bulk"
                                 -- | "unforgive" | "archive" | "revive"
  payload         TEXT           -- JSON snapshot of before/after state
  occurred_at     DATETIME NOT NULL
  source          TEXT NOT NULL  -- "dashboard" | "catchup_sheet" | "triage" | "settings" | "notification"
```

---

## 3. Multi-Track Dynamics

Multi-track handling is not an afterthought — it is the main thing that distinguishes the Learning Tracker from a single-schedule habit app, and it is where most of the hard UX problems live. This section captures the dynamics that apply *across* tracks.

### 3.1 Consolidation Surfaces

Consolidation means "unified awareness across tracks in one glance." The app needs at least three consolidation surfaces:

**Home consolidation** — the dashboard's top-level view. Should show one summary row per track with a status glyph (on-track / gently-drifting / needs-decision / dormant / on-fire). Never shows the demoralizing total behind-count across all tracks.

**Debt consolidation** — a dedicated view ("Across your tracks") that aggregates debt into actionable groupings:

- "You have **learning debt on 2 tracks** — 14 items total. [Review]"
- "You have **review debt on 3 tracks** — 22 reviews total. [Review]"
- "You have **2 decisions waiting** — both are program tracks asking about missed dapim. [Decide]"

**Action consolidation** — bulk actions: "reset pace on all self-paced tracks," "amnesty all review debt older than 60 days," "archive dormant tracks." Important principle: bulk actions *always require per-track confirmation* — they are presented as efficient, not automatic.

### 3.2 Cross-Track Credit

When two tracks point at the same content (e.g., a personal Bavli track and a Daf Yomi program track, both learning Berachos), the learner's work on one can optionally count for the other.

- **Default: no cross-credit at all.** Tracks are independent unless the learner explicitly opts in per pair.
- **Learning cross-credit** is opt-in per track pair.
- **Review cross-credit** is also opt-in per track pair, but only *configurable* if learning cross-credit is already enabled on that pair (gated dependency — you cannot cross-credit a review of something you haven't cross-credited the learning for).
- When cross-credit is enabled, it duplicates the completion record into both tracks (maintaining the append-only invariant).
- Stage definitions are still per-track, so chazara schedules remain independent unless review cross-credit is explicitly enabled.
- Cross-credit applies forward only — it does not retroactively credit past completions unless the learner explicitly asks.

This creates Scenario 12 (Mode Conflict) as a distinct case worth naming.

### 3.3 Pace Is Per-Track, Not a Global Budget

A deliberately-omitted section. Earlier drafts of this document proposed a "daily time budget" — a learner-level quantity representing total daily learning capacity against which the sum of today's recommended work across all tracks would be checked. **This concept has been removed.**

**Why it was wrong**: The app already knows the learner's intended work per track — it's derived from each track's goal (deadline goal → `total_items ÷ days_remaining`; pace goal → the declared rate per day or week). Total daily commitment is simply the sum of those per-track paces. There is no separate "capacity" quantity the app needs to compute or the learner needs to configure. If a learner has over-committed, they will fall behind, and the existing rescope/amnesty recovery scenarios handle it.

**What this means for Multi-Track Overload (Scenario 11)**: the trigger is a simple count of tracks currently in debt (≥ 3 out-of-sync tracks), not a budget overrun. The triage flow is about *which tracks to focus on or triage*, not about *fitting into a budget*.

### 3.4 Triage Flows

When a learner hits multi-track overload or returns after dormancy, the app offers a **triage flow** — a guided, low-friction sequence that presents each track in turn and lets the learner apply a quick decision:

```
[Track: Daf Yomi Bavli — 12 dapim behind]
  [Amnesty all 12]  [Catch up]  [Skip for now]

[Track: Personal Mishna Berurah — 6 days drift]
  [Rescope]  [Push harder]  [Archive]

[Track: School Chumash — 3 months dormant]
  [Revive]  [Archive]  [Skip for now]
```

**Triage order**: program tracks first (because amnesty decisions have external-clock consequences and are the heavier calls to make), ordered within each group by smallest debt first (quick wins build momentum). Then self-paced tracks, also ordered by smallest debt first.

Triage completes in 90 seconds for a 4-track user. This is the primary escape hatch for Scenario 9 (Returning Learner) and Scenario 11 (Multi-Track Overload).

---

## 4. The 15 Named Scenarios

Each scenario below uses a consistent template. These are the canonical narratives that downstream UX design and story planning should reference by name.

**Template**:
- **Mode / State tuple** — machine-readable classification
- **Narrative** — concrete user story
- **Detection** — the conditions that trigger this scenario
- **What the learner sees** — the primary surface
- **Actions offered** — discrete choices
- **Data impact** — what changes when an action is taken
- **Notification behavior** — what fires, what's suppressed
- **Multi-track interaction** — how it plays with other tracks
- **Open questions** — what we still need to decide

---

### Scenario 1: Gentle Drift

- **Mode / State**: Self-paced (any goal) · mildly behind (1–3 days past sensitivity) · reviews clean · contiguous order
- **Narrative**: *Yaakov has a "daf a day" personal goal in Bavli Berachos. He missed learning Monday and Tuesday while traveling. On Wednesday he opens the app.*
- **Detection**: `daysBehind ∈ [1, paceSensitivityDays + 2]` AND `reviewDebt` empty AND `orderGaps` empty
- **Sees**: Today's daf front-and-center. A subtle inline note: *"You're 2 dapim behind your pace. Want to catch up?"* No red. No banners.
- **Actions**: (a) **Do today's daf only** — stays mildly behind, no state change; (b) **Catch up (3 dapim today)** — suggests a temporary stretch; (c) **Dismiss for 24h** — hides the note.
- **Data impact**: None from the prompt itself. Completions accrue when the learner works.
- **Notifications**: Default cadence; no escalation.
- **Multi-track**: None — local to this track.
- **Open questions**: How do we display the "catch up" option without making it feel like a demand?

---

### Scenario 2: Rescope Moment

- **Mode / State**: Self-paced (pace or deadline goal) · meaningfully behind (4–14 days) · any review state · single or multi-track
- **Narrative**: *Miriam set a goal to finish Mishnayos Berachos by Pesach. She's been sick and is 12 days behind. Her reviews are mostly clean.*
- **Detection**: `daysBehind > paceSensitivityDays + 2` AND `daysBehind ≤ severeThreshold` (~14) AND track mode is self-paced
- **Sees**: A dedicated **"Adjust your plan"** invitation. Preview: *"At your current pace, you'd finish on [new date]. Want to update your goal to match? Your learning won't change — just the finish line."*
- **Actions**: (a) **Rescope to realistic date** — update target, pace reset; (b) **Stretch goal** — commit to double-pace for N days to catch up; (c) **Not now** — defer decision, suppress prompt for 7 days; (d) **Archive goal** — stop tracking this goal, keep learning untracked.
- **Data impact**: Rescope updates `paceResetDate` and optionally `targetDate`. No completion records change.
- **Notifications**: No silencing required. Rescope recomputes the pace baseline so that "today's work" is realistic from the moment of the action — there is no longer any demoralizing "behind" counter to silence. Daily informational notifications continue normally. If the learner wants actual silence on top of the rescope, they can explicitly pause the track.
- **Multi-track**: Optional companion prompt: *"2 other self-paced tracks are also drifting. Rescope them too?"* — shown as a suggestion, never automatic.
- **Open questions**: What's the right threshold for "stretch goal" to be offered vs. suppressed as unrealistic?

---

### Scenario 3: The Pace Reboot

- **Mode / State**: Self-paced · severely behind (15+ days) OR dormant (14+ days of no activity) · any review state
- **Narrative**: *Avraham started learning Mesechta Shabbos in January, did great for a month, then fell off. It's now April. He's 40 dapim behind on learning and has ~15 missed chazara.*
- **Detection**: `daysBehind > severeThreshold` OR `daysDormant > 14`
- **Sees**: A warm, non-judgmental welcome. *"Let's restart fresh. You've learned 24 dapim — that's real and it's saved."* No counters showing how far behind.
- **Actions**: (a) **Full reboot** — rescope to start fresh from today, batch-amnesty all past-due reviews on this track, reset chazara schedule; (b) **Rescope + keep reviews** — rescope learning, but keep the review debt visible in the dedicated review view; (c) **Rescope only** — reset learning pace, don't touch review state; (d) **Archive track** — stop tracking entirely, preserve the ledger.
- **Data impact**: Rescope sets `paceResetDate`. If "full reboot": bulk `item_amnesty` inserts for all overdue reviews, with `source = "bulk_rescope"`.
- **Notifications**: No automatic silencing — rescope and amnesty don't suppress notifications on their own. The reboot flow **explicitly offers a Pause**: *"Pause this track for a week while you get settled?"* with a one-tap Yes/No. If the learner accepts, the track is paused (silent) for 7 days and then auto-resumes with a welcome-back. If they decline, normal daily notifications continue immediately against the new rescoped baseline.
- **Multi-track**: If other tracks are also dormant, trigger triage flow (Scenario 9) instead of showing reboot for just one track.
- **Open questions**: Should the full reboot be reversible within a grace period (e.g., 7 days)? The bulk-amnesty is revocable individually but that's tedious.

---

### Scenario 4: Program Debt Pileup

- **Mode / State**: Program · accumulated missed items · any review state
- **Narrative**: *Shmuel is doing Daf Yomi Bavli. Over the past month he's missed 8 dapim — some sporadic, some clustered around a family simcha week. Daf Yomi moves on regardless.*
- **Detection**: Track `catchup_mode = amnesty` AND gaps exist between the learner's first completion and today's program daf, with neither completion nor amnesty records.
- **Sees**: A **"Missing dapim"** card on the track view. *"8 dapim aren't logged as learned. What do you want to do with them?"* Shows a scrollable list grouped by date range.
- **Actions**: (a) **Catch up — mark as learned now** (for items the learner actually did offline); (b) **Amnesty all 8** — one-tap bulk; (c) **Amnesty selected** — multi-select; (d) **Split decision** — amnesty some, catch-up others; (e) **Decide later** — snooze for 7 days (muted, no nag).
- **Data impact**: `item_amnesty` inserts with `source = "user_manual"` or `"triage"`. For "catch up now," new completion records with `completedAt = now` (the learner explicitly confirms they're logging past learning).
- **Notifications**: Program's daily daf notification continues unchanged. Behind-count messaging is recomputed to exclude amnestied items.
- **Multi-track**: Independent of other tracks.
- **Open questions**: If the learner marks an old item as "learned now" with a backdated timestamp, do we allow backdating? (Recommendation: no — keep completion timestamps honest. The learner is logging *now* that they learned; the system doesn't need to pretend otherwise.)

---

### Scenario 5: Selective Amnesty

- **Mode / State**: Any mode · learner-initiated (not system-prompted)
- **Narrative**: *Rivka is doing Yerushalmi and has hit a few sugyas that are beyond her level. She wants to skip them and keep going without noise.*
- **Detection**: Learner initiates from an item detail view, a debt view, or a long-press on a scheduler task. Not triggered by computed state.
- **Sees**: A simple confirmation sheet: *"Skip [Yerushalmi Berachos 12b]. You can change your mind later."* Option to amnesty only specific stages.
- **Actions**: (a) **Amnesty item (all stages)**; (b) **Amnesty specific stage** (e.g., keep learning, skip chazara 2); (c) **Add reason** (optional note).
- **Data impact**: One or more `item_amnesty` records with `source = "user_manual"`.
- **Notifications**: Immediate removal from pending lists. No confirmation pings.
- **Multi-track**: None.
- **Open questions**: Should amnesty from the scheduler view be a swipe action or require a confirmation sheet? (Recommendation: swipe for single-stage amnesty, sheet for whole-item amnesty.)

---

### Scenario 6: Chazara Archipelago

- **Mode / State**: Any mode · sporadic review gaps across largely-clean learning · reviewDebt size ~1–15 items
- **Narrative**: *David has learned 80 dapim of Bavli Berachos over a year. His chazara is mostly on track, but 7 reviews — scattered across different dapim and stages — were missed along the way.*
- **Detection**: `reviewDebt.length ∈ [1, 15]` with low clustering (no single unit contains more than 40% of the debt) AND learning debt is zero or low.
- **Sees**: A dedicated **"Review Debt"** view — browsable, organized by how old each gap is. **Not** surfaced on the main dashboard except as a subtle badge. *"7 reviews waiting."*
- **Actions**: (a) **Do review now** — pick any one, mark complete; (b) **Amnesty a review** — single or multi-select; (c) **Amnesty all**; (d) **Schedule into rotation** — spread the 7 reviews across the next week's daily plan.
- **Data impact**: Completions (when the learner reviews) or `item_amnesty` inserts (stage-scoped) or scheduler adjustments.
- **Notifications**: Gentle weekly digest ("7 reviews waiting — handle them this week?"). Respects the track's notification cadence.
- **Multi-track**: Review Debt view can optionally show reviews across all tracks with a track-filter control.
- **Open questions**: Should we visualize which masechta/sefer each debt belongs to for easier browsing? (Recommendation: yes, group by unit with expandable sections.)

---

### Scenario 7: Chazara Collapse

- **Mode / State**: Any mode · systematic review neglect · reviewDebt size > 15 · review completion rate in last N days < 20%
- **Narrative**: *Sarah learned Bavli Berachos over a year, hitting her learning pace diligently, but gradually stopped doing chazara. Now she has 60+ missed reviews.*
- **Detection**: `reviewDebt.length > 15` AND last-30-days review completion rate < 0.2 · AND either `daysSinceLastReview > 21` OR the slope of reviews-per-week is negative for 4+ weeks.
- **Sees**: A warm, honest framing. *"Your learning is strong. Chazara stopped around [date]. Reviews help retention — want to restart?"*
- **Actions**: (a) **Restart reviews from today** — archive old review debt (bulk amnesty with `source = "restart_chazara"`), start the review clock fresh on future completions; (b) **Small commitment** — pick a manageable subset (e.g., 5 reviews) and schedule them; (c) **Amnesty all review debt** — clean slate; (d) **Disable review stages on this track** — the learner is okay with learn-only.
- **Data impact**: Varies by choice. (a) bulk amnesty with a `source` tag; (d) disables stages by modifying `stage_definitions` or a track flag.
- **Notifications**: Very quiet. Chazara collapse is a sensitive state — do not nag. Notification cadence drops to weekly.
- **Multi-track**: If multiple tracks show chazara collapse, offer a bundled "restart reviews on all tracks" option in triage.
- **Open questions**: How do we distinguish "learner has stopped reviewing" from "learner took a week off"? (Recommendation: use the slope + absolute threshold combo in detection.)

---

### Scenario 8: Out-of-Order Explorer

- **Mode / State**: Any mode · non-contiguous learning · gaps in the learning order with completions on both sides
- **Narrative**: *Aharon learned Mishnayos Berachos perek 1, then jumped to perek 4, then perek 2. Perek 3 is untouched. His chazara on learned perakim is clean.*
- **Detection**: `orderGaps.length > 0` AND at least one gap has completed items on both sides (not just "haven't gotten there yet").
- **Sees**: A **Coverage Map** view — a visual representation of the curriculum's linear structure with learned sections highlighted and gaps shown as hollow. *"You have 1 gap: Perek 3."* Accessible but not front-page.
- **Actions**: (a) **Fill gap now** — route to the scheduler for the gapped items; (b) **Amnesty gap** — mark the gap as deliberately skipped; (c) **Ignore** — keep the gap visible but take no action; (d) **Rearrange plan** — schedule the gap for a specific future date.
- **Data impact**: Amnesty records, or scheduler adjustments, or nothing.
- **Notifications**: Low priority — only surfaced if the learner visits the coverage view. Never nagged about.
- **Multi-track**: The coverage view can show per-track coverage side-by-side.
- **Open questions**: Is "coverage" the right word? (Alternatives: map, sequence, progress atlas.)

---

### Scenario 9: The Returning Learner

- **Mode / State**: Any mode · dormant for 14+ days · now opening the app
- **Narrative**: *Moshe hasn't opened the app in 6 weeks. Life got in the way. He opens it today intending to re-engage.*
- **Detection**: On app open: `daysDormant > 14` on at least one track AND the learner has just launched the app after a dormancy gap.
- **Sees**: A welcome-back screen. Total lifetime progress summary ("You've learned 38 dapim total"). **No behind-counts shown.** Offers a gentle onramp.
- **Actions**: Presented as a triage sequence if multi-track (see Scenario 11). For a single track: (a) **Quick reboot** (rescope + amnesty all missed); (b) **Gentle resume** (rescope only, review debt stays visible); (c) **Ambitious catch-up** (try to close learning debt over N days); (d) **Just browse** (no action, learner explores their own state first).
- **Data impact**: Varies by choice.
- **Notifications**: No automatic silence. Instead, the welcome-back flow **offers Pause as an explicit choice** — *"Pause everything for a week while you get re-oriented?"* If the learner accepts, all affected tracks are paused for 7 days with auto-resume. If they decline, normal notifications resume immediately against the newly rescoped baselines. The 7-day default is a suggestion, not a lock — the learner can choose any duration.
- **Multi-track**: This is the canonical entry point to the triage flow.
- **Open questions**: Should we show encouraging stats (total dapim, total time learned, masechtos siyum'd) or does that feel patronizing? (Recommendation: yes but understated; they are factual, not praise.)

---

### Scenario 10: The Ghosted Track

- **Mode / State**: One track in a multi-track setup is dormant; other tracks are healthy or recent
- **Narrative**: *Yitzchok is doing well on Daf Yomi Bavli and personal Mishna Berurah, but his school Chumash track hasn't been touched in 3 months. The school year may or may not even include it anymore.*
- **Detection**: Single-track `daysDormant > 60` while at least one other track has activity within the last 14 days.
- **Sees**: Non-intrusive presence. The ghosted track is demoted in the track list (moved below active tracks, shown with reduced visual weight). A subtle note in Settings → Tracks: *"[Chumash] has been quiet. Still active?"*
- **Actions**: (a) **Archive track** — remove from main UI, preserve ledger; (b) **Revive (rescope)** — reset pace; (c) **Revive (fresh start)** — rescope + amnesty all past debt; (d) **Dismiss prompt for 30 days** — the learner isn't ready to decide.
- **Data impact**: Archive sets `archivedAt`. Revive clears `archivedAt` and sets `paceResetDate`.
- **Notifications**: Never notify about ghosted tracks. They are deliberately silent.
- **Multi-track**: The main point of this scenario is multi-track awareness — it only exists as a pattern *because* other tracks are active.
- **Open questions**: Is there a distinction between "ghosted" and "paused"? Should the learner be able to explicitly pause a track (different from archive)?

---

### Scenario 11: Multi-Track Overload

- **Mode / State**: Behind or in-debt on 3+ tracks simultaneously
- **Narrative**: *Chaya runs 4 tracks: personal Bavli, program Daf Yomi Yerushalmi, school Mishnayos, tutor Chumash. She's drifted behind on 3 of them. She feels overwhelmed and the dashboard looks like a panic attack.*
- **Detection**: Count of tracks with `daysBehind > paceSensitivityDays` OR `reviewDebt.length > 10` is ≥ 3.
- **Sees**: A **Triage** sheet at the top of the dashboard. *"Quick triage: handle all 4 tracks in 2 minutes."* Individual dashboard cards are collapsed under the triage banner until it's acted on.
- **Actions**: Triage steps through each out-of-sync track in turn, offering per-track quick actions. At any point: (a) **Finish triage**; (b) **Pause triage** — save progress, resume later; (c) **Bulk action** — "reset pace on all self-paced, amnesty all review debt older than 60 days."
- **Data impact**: Multiple rescope / amnesty / archive actions, logged individually in `track_action_log`.
- **Notifications**: All per-track notifications are suppressed while triage is pending. A single "triage awaits" nudge replaces them.
- **Multi-track**: The whole point.
- **Open questions**: Should triage also suggest *reducing* the number of active tracks? (Recommendation: yes, but gently — "you have 4 tracks. Many learners do well with 2–3.")

---

### Scenario 12: Mode Conflict

- **Mode / State**: Two tracks, same `curriculum_id`, different `track_type` / mode, divergent progress states
- **Narrative**: *Binyamin is enrolled in Daf Yomi Bavli (program) AND keeps a personal Bavli track to focus on selected masechtos at his own pace. He's on track with the program daf but behind on his personal study of Masechta Yoma.*
- **Detection**: Two active tracks share `curriculum_id` and have different `track_type` OR different `catchup_mode`.
- **Sees**: Both tracks appear independently on the dashboard. When the learner completes a daf on one track, a subtle prompt offers: *"This daf is also in your [other track]. Count it there too?"*
- **Actions**: (a) **Cross-credit this completion**; (b) **Always cross-credit this pair** (set a persistent rule); (c) **Keep tracks independent**; (d) **Merge tracks** (destructive, explicit warning).
- **Data impact**: If cross-credit: a parallel completion row is created on the second track with a `cross_credited_from` reference (new field). Stage definitions per-track still apply independently.
- **Notifications**: Notification dedup logic — same-curriculum reminders are bundled so the learner isn't pinged twice for the same daf.
- **Multi-track**: Core multi-track edge case.
- **Open questions**: Should review stage progression also cross-credit? (Recommendation: no by default, yes on explicit per-pair setting — chazara schedules differ per track on purpose.)

---

### Scenario 13: Siyum Cleanup

- **Mode / State**: Any mode · near end of a learning unit (masechta, perek, sefer) with pending reviews in that unit
- **Narrative**: *Elazar is on daf 62 of Berachos (64 total). He's 2 dapim away from a siyum. But he has 4 pending chazara reviews on earlier dapim of the same masechta.*
- **Detection**: Progress in a unit is within a configurable threshold of completion (e.g., 95%) AND `reviewDebt` contains items within that same unit.
- **Sees**: A celebratory, non-pressuring card. *"Siyum incoming! 4 reviews left to close this masechta cleanly."*
- **Actions**: (a) **Do reviews now**; (b) **Siyum anyway** (amnesty the pending reviews in this unit); (c) **Finish learning first, reviews later** (no state change).
- **Data impact**: Completions or unit-scoped `item_amnesty`.
- **Notifications**: Celebratory framing. **Never** use this to guilt-trip the learner into reviews. The siyum is the star.
- **Multi-track**: `learning_ledger` records the siyum event regardless of which choice was made.
- **Open questions**: Should siyum cleanup be offered on every unit type (masechta, perek, seder) or only specific ones? (Recommendation: masechta and sefer only for Bavli-like curricula; perek for Mishnayos; configurable per curriculum.)

---

### Scenario 14: Program Launch Day

- **Mode / State**: Program track · fresh creation mid-cycle · learner joining an in-progress program
- **Narrative**: *Yosef decides to join Daf Yomi Bavli today. The program is currently on daf 87 of Berachos. He's never tracked this before.*
- **Detection**: New program track created AND program's current position is not at the beginning.
- **Sees**: A two-choice onboarding screen. *"The program is on [daf 87]. Where would you like to start?"*
- **Actions**: All choices are expressed through the unified **Setup Seeding flow** (a new surface, shared with Scenario 15) — per-item options of ✅ learned · ⏭️ amnesty · 📅 catch up later. Quick-path shortcuts: (a) **Align with program now** — mark pre-cycle items as amnesty in bulk, start tracking from today's daf; (b) **Start from the beginning** — mark nothing; track independently of the program clock (the learner is warned this is effectively self-paced); (c) **Custom start point** — pick any daf, auto-amnesty earlier ones, customize individual items if needed.
- **Data impact**: Track created with appropriate settings + bulk `item_amnesty` inserts for pre-start items (if aligning) + bulk completion inserts for any items the learner marks as already learned during seeding.
- **Notifications**: Onboarding sequence only. Normal daily notifications begin on day 1 against the newly-established baseline. Pause is available as always if the learner wants silence.
- **Multi-track**: *"You already have a personal Bavli track — cross-credit future completions?"* prompt if applicable (links to Scenario 12; cross-credit is opt-in per Q10).
- **Cycle boundaries**: When a new Daf Yomi cycle begins (every ~7.5 years), the default behavior is **auto-fresh slate** — old amnesties remain in the data tagged with the previous cycle but are no longer active in the new cycle. A one-time **Welcome to Cycle N+1** flow is shown on first engagement post-boundary, giving the learner the explicit option to carry forward previous amnesties if they want.
- **Relation to existing mark-done**: The Setup Seeding flow **replaces the current clunky "mark done" bulk UX** with first-class per-item learned/amnesty/defer choices. This is a user-visible improvement worth calling out in the epic.

---

### Scenario 15: Personal Track Retrofit

- **Mode / State**: Self-paced track · fresh creation · learner has pre-existing learning they want to import into tracking
- **Narrative**: *Leah has been learning Mishnayos Seder Zeraim on her own for a year. She's completed masechtos Berachos and Peah entirely, is halfway through Demai, and has done sporadic chazara on the completed masechtos (but not all of it). Today she decides she wants to start tracking this in the app.*
- **Detection**: New personal/self-paced track created AND the learner indicates they have existing learning state to import (via an explicit toggle in track creation, e.g., *"I've already started this — help me set up my current state"*).
- **Sees**: The **Setup Seeding flow** (same surface as Scenario 14). Unlike Program Launch Day, there is no external cycle to align with — the learner is in full control. The flow presents the curriculum's content hierarchy and lets the learner mark each unit (or batch of units) as:
  - ✅ **Learned** — creates completion records with `completedAt = now` (the learner is logging *now* that they learned, not backdating)
  - ⏭️ **Amnesty** — creates `item_amnesty` records; these items will not count as debt
  - 📅 **Defer** — no action; the item remains unstarted and will be part of future catch-up plans
  - 📚 **Reviewed once / twice / N times** — for items marked as learned, optional declaration of review state to seed the stage history
- **Actions**:
  - **Batch mode** — mark a whole masechta / sefer / perek as learned or amnestied in one tap
  - **Individual mode** — override the batch choice for specific items
  - **Start minimal** — skip seeding entirely and begin tracking from today forward (everything prior is implicitly deferred)
  - **Set starting pace / deadline** — after seeding, establish the track's goal (so the pace calculator has something to measure against)
- **Data impact**: Bulk completion records (with `completedAt = now`) + bulk `item_amnesty` records (with `source = "retrofit_seeding"`). Track settings populated from defaults. Goal set as part of the flow.
- **Notifications**: Onboarding sequence only. Normal daily notifications begin on day 1 against the newly-established baseline.
- **Multi-track**: If the learner already has another track for the same curriculum (e.g., they're joining a school track after having a personal one), the Mode Conflict scenario (S12) cross-credit prompt applies.
- **Why this matters**: Without this scenario, a learner with pre-existing learning faces an awful choice: either spend hours laboriously marking each item as complete (the current broken "mark done" experience), pretend they haven't started (ugly fiction), or skip tracking this content entirely (lost user). The Setup Seeding flow turns this into a 2-minute setup with honest data.
- **Open questions**: For reviews declared during seeding, do we create fake completion records with timestamps (unhonest) or a separate "retrofit_stage_count" field on stage definitions (more honest but complex)? Recommendation: create real completion records with `completedAt = now` and a `source = "retrofit_seeding"` tag on the completion — so the audit trail shows these were declared during setup, not backdated.

---

## 5. Exhaustive Scenario Grid

The 15 named scenarios cover the most important narratives. But any possible state combination should map to at least one scenario. This section provides that complete mapping.

### 5.1 State Dimensions

The full state space is the Cartesian product of these dimensions:

| Dimension | Values |
|---|---|
| **Mode** | SP-Pace (self-paced, pace goal) · SP-Deadline (self-paced, deadline goal) · SP-Momentum (self-paced, no explicit goal) · Program |
| **Pace state** | On-track · Mildly behind (1–3 days) · Meaningfully behind (4–14 days) · Severely behind (15+ days) · Dormant (14+ days no activity) · Ahead |
| **Review state** | Clean · Sporadic (1–15 items) · Systematic backlog (>15) · Concentrated (debt >40% in one unit) |
| **Order state** | Contiguous · Gapped · Out-of-order (≥ 2 gaps) |
| **Multi-track context** | Single track · Multi-healthy (others OK) · Multi-mixed (≥ 2 other in-debt) |

Full Cartesian product: 4 × 6 × 4 × 3 × 3 = **864 cells**. Most cells behave identically for the purposes of scenario selection. The grid below shows the **decision logic** that assigns each state combination to one or more named scenarios.

### 5.2 Primary Scenario Selection — Mode × Pace State

This is the first-pass lookup. Given a track's mode and pace state, which named scenario is the *leading* one?

|                   | **On-track** | **Mildly behind** | **Meaningfully behind** | **Severely behind** | **Dormant** | **Ahead** |
|---|---|---|---|---|---|---|
| **SP-Pace**       | — (normal) | S1 Gentle Drift | S2 Rescope Moment | S3 Pace Reboot | S3 / S9 | — (encouragement) |
| **SP-Deadline**   | — | S1 Gentle Drift | S2 Rescope Moment | S3 Pace Reboot | S3 / S9 | — |
| **SP-Momentum**   | — | — (ignore) | — (ignore) | S3 / S9 | S9 Returning Learner | — |
| **Program**       | — | S4 Program Debt Pileup | S4 Program Debt Pileup | S4 + possibly S9 | S9 Returning Learner | — |

Notes:
- SP-Momentum tracks don't have a pace goal, so "behind" is undefined. They only trigger scenarios when the learner returns after dormancy.
- "Ahead" states don't trigger catch-up scenarios but should trigger light positive reinforcement (celebration notifications, "rest day" suggestions).

### 5.3 Review-State Overlay

Review state is *independent* of pace state and triggers its own scenarios, which **chain** on top of the primary scenario from 5.2:

| Review state | Triggers | Notes |
|---|---|---|
| Clean | — | No action |
| Sporadic (1–15) | **S6 Chazara Archipelago** | Shown in dedicated Review Debt view, not dashboard |
| Systematic (>15) | **S7 Chazara Collapse** | Warm reframing; offer restart |
| Concentrated (one unit) | **S13 Siyum Cleanup** (if near unit end) or **S6/S7** fallback | Unit proximity matters |

**Chaining example**: A track that is both *severely behind on pace* AND has *systematic review debt* is **S3 Pace Reboot** primary, with **S7 Chazara Collapse** as a secondary surface accessible from the reboot flow. The reboot's option (a) "full reboot" naturally handles both.

### 5.4 Order-State Overlay

| Order state | Triggers | Notes |
|---|---|---|
| Contiguous | — | No action |
| Gapped (1 gap) | **S8 Out-of-Order Explorer** | Shown in Coverage Map, not dashboard |
| Out-of-order (≥ 2 gaps) | **S8 Out-of-Order Explorer** | Same surface, higher salience |

Order-state overlays never take precedence — they are always a secondary surface, accessible but not intrusive.

### 5.5 Multi-Track Modifiers

| Multi-track context | Modifier applied |
|---|---|
| Single track | None — scenarios apply as-is |
| Multi-healthy | Other tracks provide positive framing ("Your other tracks are strong"). Scenarios on the affected track apply as-is. |
| Multi-mixed (≥ 2 affected) | **S11 Multi-Track Overload** escalates — individual scenarios are subordinated to triage |

Additional multi-track triggers independent of the primary scenario:

- **S10 The Ghosted Track**: triggered by `dormant track + other healthy tracks`, even when the primary scenario on other tracks is "normal."
- **S12 Mode Conflict**: triggered by the mere existence of two same-curriculum tracks with different modes, independent of their individual pace states.

### 5.6 Master Decision Flow (Pseudocode)

```
for each active track t:
    state = computeState(t)  // pace, reviews, order, dormancy

    # Primary scenario from mode × pace
    primary = selectPrimaryScenario(state.mode, state.paceState, state.daysDormant)

    # Review state overlay
    if state.reviewDebt > 15 and state.reviewVelocity < threshold:
        secondary.add(S7_ChazaraCollapse)
    elif state.reviewDebt ∈ [1, 15]:
        if state.concentratedIn(unit) and state.unitProximity > 0.95:
            secondary.add(S13_SiyumCleanup)
        else:
            secondary.add(S6_ChazaraArchipelago)

    # Order state overlay
    if state.orderGaps > 0:
        secondary.add(S8_OutOfOrderExplorer)

    # Cycle boundary check
    if t.just_created and t.mode == Program and t.program.current_position > 0:
        primary = S14_ProgramLaunchDay

    # Dormant + multi-track check
    if state.daysDormant > 60 and multi_track_healthy:
        overlay(S10_GhostedTrack)

    # Mode conflict check
    if exists other_track with same curriculum_id and different mode:
        overlay(S12_ModeConflict)

# Multi-track overload check (post-loop)
if count(tracks where primary != "normal") >= 3:
    promote to S11_MultiTrackOverload at session start

# Returning learner check (post-loop, session-level)
if sessionIsFirstAfterGap(>14 days):
    wrap everything in S9_ReturningLearner framing
```

### 5.7 Cell-Level Coverage Check

The 864-cell Cartesian product maps to named scenarios as follows (grouped for readability):

- **Normal states** (on-track, clean reviews, contiguous, single-track): ~4 cells × all review-clean × all order-contiguous = **~48 cells** → no scenario triggered, default dashboard.
- **Primary catch-up scenarios** (S1, S2, S3, S4): cover all mildly-behind-through-dormant combinations across all modes = **~144 cells**.
- **Review-state overlays** (S6, S7): stack on top of pace states = **~216 cells** add review scenarios.
- **Order-state overlays** (S8): stack on top = **~192 cells** add order scenarios.
- **Multi-track modifiers** (S10, S11, S12): trigger independent of pace state = **applies to ~576 multi-track cells**.
- **Specialized cases** (S5, S9, S13, S14, S15): triggered by action or context, not computed state alone.

**Coverage assertion**: every cell in the state space either maps to the default "normal" dashboard (when no scenario applies) or to at least one named scenario. There are no silent dead zones.

---

## 6. Notification Philosophy

The notification system (currently a TODO — `PaceBehindCallback` in `pace_calculator.dart`) should be designed in service of the recovery model above, not bolted on after. This section defines the principles; the wiring comes later.

### 6.1 Principles

1. **Never demoralize.** No notification should ever lead with a behind-count. *"You're 14 dapim behind"* is forbidden language. *"Today's daf is ready"* or *"Time for chazara"* is the correct register.
2. **Silence is a deliberate act, not an automatic side effect.** Amnesty and rescope do **not** silence notifications. If a learner wants silence, they **pause** the track explicitly. This keeps the learner in control — the app never guesses that they need quiet.
3. **Informational notifications always continue on active tracks.** Daily "today's daf is ready" pings are factual, not evaluative. They fire regardless of recent recovery actions because the learner still needs to know what's happening.
4. **Consolidate across tracks.** A learner with 4 tracks should not receive 4 notifications per day. A single daily digest is the default, with per-track opt-in to detailed notifications.
5. **Celebrate more than nag.** Positive events (streak maintained, siyum approaching, catch-up completed) get a higher notification budget than negative events.
6. **Every notification is dismissible into silence.** The learner can turn off any specific notification class without abandoning the app entirely.
7. **Per-track override.** Global notification preferences are overridden by per-track `notification_cadence`. Default cadence is derived from goal state: *has active goal → `daily`*, *momentum-only → `silent`*.

### 6.2 Pause as the Silence Mechanism

Earlier drafts of this document had a "quiet window" concept — automatic periods of notification silence triggered by rescope or amnesty actions. **This concept has been removed.** Instead, all silencing flows through a single mechanism: the learner explicitly pauses a track.

**How Pause works**:

- Learner-initiated from any track surface or during a recovery flow (Pace Reboot, Returning Learner, etc. all *offer* pause as an explicit option, but never impose it).
- Duration options at pause time: **1 day · 3 days · 1 week · 2 weeks · custom · indefinite**.
- Fixed-duration pauses auto-resume on expiry with a gentle welcome-back prompt (no notification; next app open surfaces it).
- Indefinite pauses require explicit resume.
- A paused track produces **no notifications of any kind** until resumed.
- Pause is distinct from Archive (see §3 and Scenario 10). A paused track is "coming back"; an archived track is "done."

**What amnesty and rescope do NOT do to notifications**:

- Neither action triggers any silence window.
- After rescope, the pace baseline is new, so "today's work" is immediately realistic — there is no demoralizing debt counter to silence.
- After amnesty, the amnestied items are removed from debt computations — reminders about those specific items stop, but all other notifications continue.

### 6.3 Notification Types

| Type | Trigger | Silenced when paused? | Default cadence |
|---|---|---|---|
| **Daily reminder** | "Today's work is ready" | Yes | Daily at learner-chosen time |
| **Review due** | Chazara stage threshold hit | Yes | Daily |
| **Streak at risk** | Within 2 hours of streak-breaking | Yes | Once per day max |
| **Streak achievement** | Milestone hit | Yes | On event |
| **Siyum approaching** | S13 conditions | Yes | Weekly |
| **Siyum complete** | Unit finished | Yes | On event |
| **Catch-up progress** | Learner closed some debt | Yes | On event |
| **Review debt digest** | S6 conditions | Yes | Weekly |
| **Triage invitation** | S11 conditions | Yes | Once per overload event |
| **Welcome back (after pause expiry)** | Pause auto-resume | N/A — this *is* the post-pause resume | Once per pause event |
| **Welcome back (after dormancy)** | S9 trigger | N/A — on app open | Once per gap |
| **Chazara collapse notice** | S7 conditions | Yes | Once per collapse event, then monthly |
| **Ghosted track prompt** | S10 trigger | Yes (paused tracks are never "ghosted") | Once, then suppressed 30 days |

**Key simplification from v1**: all notification types respect Pause uniformly. There is no per-type "muted during quiet window" distinction — Pause silences everything.

### 6.4 Suppression Rules

- No two evaluative notifications on the same track within 4 hours.
- No more than 3 notifications across all tracks per day (default — learner can change).
- Overload state (S11) suppresses all per-track notifications until triage is complete or paused.
- Dormant tracks never generate notifications except the Welcome Back on next session open.
- **Paused tracks never generate notifications** until the pause expires or is manually resumed.
- Archived tracks never generate notifications.

---

## 7. Surface Inventory (Stub)

This is deliberately thin because **WDS will own the actual UX design**. The goal here is to enumerate the surfaces the scenarios reference so downstream designers have a checklist.

Known surfaces (existing or new):

| Surface | Existing / New | Used by scenarios |
|---|---|---|
| Dashboard (home) | Existing | S1, S2, S11 |
| Today / Scheduler | Existing | S1, S4 |
| Track detail | Existing | All |
| **Catch-up sheet** | **New** | S2, S3, S4 |
| **Triage sheet** | **New** | S9, S11 |
| **Review Debt view** | **New** | S6, S7 |
| **Learning Journey view** (internal name: Coverage Map) | **New** | S8 |
| **Amnesty history / Skipped view** | **New** | All amnesty scenarios (review & unforgive) |
| **Setup Seeding flow** (replaces current "mark done" UX) | **New — upgrade** | **S14, S15** |
| **Pause control** (duration picker, resume UI) | **New** | All scenarios — learner-initiated silence |
| **Track settings panel** | Existing (extend) | All per-track mode configuration |
| **Onboarding (returning learner)** | **New** | S9 |
| **Onboarding (program launch)** | **New** | S14 |
| **Onboarding (personal retrofit)** | **New** | S15 (shares Setup Seeding with S14) |
| **Cycle-boundary welcome flow** | **New** | Every N years for program tracks — explicit carry-forward decision |
| **Siyum celebration** | Existing (extend) | S13 |
| Notification center | Existing (extend) | All |

The WDS work can use this table as its scope checklist. Each new surface becomes a candidate page specification.

**Callout for the epic**: The **Setup Seeding flow** is not merely a new feature — it is an **upgrade to an existing clunky "mark done" bulk UX**. This should be positioned in the epic as a user-visible improvement, not just a new surface for onboarding.

---

## 8. Resolved Decisions Log

All 20 open questions from v1 have been resolved. This section records each decision in a compact form — downstream readers can use it as a traceable index.

### 8.1 Naming & concepts — resolved

- **Q1** — *Is "amnesty" the final word?* **Resolved: Yes.** The emotional payload ("officially forgiven, no shame") fits. No alternatives chosen.
- **Q2** — *Name for the gap-visualization view?* **Resolved: "Coverage Map" internally, "Learning Journey" user-facing.** Code, tickets, specs use *Coverage Map* for precision; learner-facing UI copy uses *Learning Journey* for warmth.
- **Q3** — *Rename `TrackDao.resetPace` to `rescope`?* **Resolved: No rename — service wrapper pattern.** DAO stays `resetPace` (storage primitive). A new service layer exposes `rescope()` that wraps the DAO call with semantic side effects (logging, optional pause offers, etc.). Learner-facing surfaces only see "rescope."

### 8.2 Data model — resolved

- **Q4** — *NULL sentinel vs. explicit per-stage rows for whole-item amnesty?* **Resolved: NULL sentinel.** `stage_id IS NULL` means "amnesty the whole item, all stages now and any stages added later." Survives stage additions; simpler revocation.
- **Q5** — *Cycle-boundary behavior?* **Resolved: Auto-fresh slate as default, with a cycle-boundary welcome flow.** On new Daf Yomi (or equivalent) cycle start, old amnesties remain in the data tagged with the previous cycle but are inactive in the new cycle. A one-time "Welcome to Cycle N+1" flow gives the learner the explicit option to carry forward if they want.
- **Q6** — *Separate `track_settings` table vs. extend `curriculum_tracks`?* **Resolved: Extend in place.** Matches existing style; avoids a join on every dashboard read; 1:1 normalization adds no benefit.

### 8.3 Thresholds — resolved

- **Q7** — *Default threshold values?* **Resolved**:
  - `paceSensitivityDays` = **3 days**
  - `severeThreshold` = **14 days**
  - `dormancyThreshold` = **14 days**
  - `chazaraCollapseThreshold` = **15 items AND review completion rate < 20% over 30 days**
  - `ghostedThreshold` (multi-track) = **60 days**
  - All values are per-track overridable via the settings columns.
- **Q8** — *Unit definition for concentration and siyum proximity?* **Resolved: Per-curriculum `primary_unit_type` with per-track override.** Curriculum defaults: Bavli/Yerushalmi → masechta, **Mishnayos → seder (corrected from v1 draft)**, Mishna Berurah → siman, Chumash → parsha. Track-level override to `perek` is the standard pattern for children's Bavli / Mishnayos tracks.
- **Q9** — *How to compute typical daily capacity?* **Resolved: Removed from scope.** The concept was confused. Pace is per-track, derived directly from each track's goal. Total daily commitment is the sum. Multi-Track Overload triggers on simple debt count (≥3 tracks), not on any budget calculation. Section 3.3 documents this explicitly.

### 8.4 Multi-track — resolved

- **Q10** — *Cross-credit: learning-only default or include chazara?* **Resolved: No cross-credit at all by default.** Both learning and review cross-credit are opt-in per track pair. Review cross-credit is gated: only configurable if learning cross-credit is already enabled on that pair.
- **Q11** — *Triage order?* **Resolved: Hybrid.** Program tracks first (amnesty decisions are the heavier calls). Within each group, order by smallest debt first (quick wins build momentum). Then self-paced tracks, also smallest-debt-first.
- **Q12** — *Pause vs. Archive as distinct states?* **Resolved: Yes, distinct states.** Pause = intentional temporary silence, one-tap resume, no data changes, pace clock stops. Archive = intended done, ledger preserved, reviving is explicit.

### 8.5 Notifications — resolved

- **Q13** — *Default cadence per track type?* **Resolved: Cadence defaults are derived from goal state, not track type.** Tracks with an active goal default to `daily`; momentum-only tracks default to `silent`. Track type still influences `catchup_mode` default (personal → rescope, school/tutor → amnesty).
- **Q14** — *Program notifications during quiet window?* **Resolved: Quiet window concept eliminated entirely.** Informational notifications ("today's daf is ready") continue on all active tracks regardless of recent recovery actions. Silence is achieved only via explicit Pause.
- **Q15** — *Configurable quiet window — global or per-action?* **Resolved: Reframed.** There is no quiet window to configure. Pause is the silence mechanism, with duration options at pause time: 1 day / 3 days / 1 week / 2 weeks / custom / indefinite. Auto-resume on expiry with welcome-back prompt.

### 8.6 Migration — removed

- **Q16** and **Q17** — *Migration story for existing tracks and amnesty data?* **Resolved: Not applicable.** Learning Tracker is a greenfield product with no existing users to migrate. The new columns and tables exist in the schema from day 1. What v1 described as "Q17 seed data on migration" has been reframed as the **Setup Seeding flow** (Scenario 14 + new Scenario 15) — an onboarding feature, not a migration concern.

### 8.7 UX direction for WDS — deferred

These questions are explicitly deferred to WDS. They are UX decisions that properly belong to the designer.

- **Q18** — *Recovery Center unified surface vs. distinct surfaces?* **Deferred to WDS.** (Product-level lean recorded: distinct surfaces with a shared visual family, no unified "Recovery Center" door.)
- **Q19** — *Amnesty gesture vocabulary — swipe / long-press / confirmation sheet?* **Deferred to WDS.** (Product-level lean recorded: mixed by context — lightweight swipe + snackbar for single-stage amnesty; confirmation sheet for whole-item and bulk.)
- **Q20** — *Amnesty history prominence?* **Deferred to WDS.** (Product-level lean recorded: two access points — track settings panel and inside Review Debt / Learning Journey views — plus an undo snackbar after each amnesty action.)

### 8.8 New questions surfaced during v1 → v2

These questions were generated by the resolution process itself and should be addressed before epic/story work begins:

- **NQ1** — *Children's overrides of `primary_unit_type`*: is this set during Setup Seeding or only from Track settings? Suggested: offer as a choice during initial track creation, with Settings as the long-term override home.
- **NQ2** — *Retrofit review seeding*: how are declared-at-setup reviews recorded? Suggested: real completion records with `completedAt = now` and a `source = "retrofit_seeding"` tag. Avoids backdated data; honest audit trail. (Noted in Scenario 15.)
- **NQ3** — *Welcome-back after pause vs. after dormancy*: are these the same UI treatment or distinct? Suggested: similar tone, but pause-expiry welcomes celebrate the intentional break ("hope the break was good"), whereas dormancy welcome is more re-engagement-focused ("glad you're back").
- **NQ4** — *Pause during triage*: if the learner pauses a track during triage, does triage skip that track? Suggested: yes — paused tracks are never in triage.

---

## 9. Glossary

- **Amnesty** — A formal, non-destructive declaration that a specific item or stage is "not being done in this cycle." Removes the item from debt calculations and reminders while preserving it in the data. Revocable. Does not trigger notification silence.
- **Archive** — A track state signalling the learner considers the track finished or permanently stopped. Ledger preserved; reviving is an explicit action. Distinct from Pause.
- **Catch-up plan** — A concrete, bounded recommendation for closing learning debt without rescoping or amnesty. Typically phrased as "do X extra per day for Y days."
- **Chazara** — Review. Post-initial-learning repetitions defined by stage definitions.
- **Contiguous learning** — Completion order matches curriculum order (no gaps).
- **Coverage Map (internal) / Learning Journey (user-facing)** — The visual representation of completed vs. uncompleted items across the curriculum's linear structure, revealing gaps and out-of-order learning. See Scenario 8.
- **Cross-credit** — An opt-in-per-track-pair mechanism where a completion on one track counts toward another track that shares the same content. Learning cross-credit is the primary form; review cross-credit is an additional opt-in gated on learning cross-credit being enabled.
- **Cycle** — A bounded time period within which amnesty applies. Explicit for program tracks (e.g., Daf Yomi cycle 14), implicit for self-paced. New cycles default to fresh-slate behavior with a welcome-flow carry-forward option.
- **Debt** — The quantifiable gap between expected and actual learning state on a track. Has two independent flavors: learning debt and review debt.
- **Dormant track** — A track with no activity for ≥ 14 days.
- **Ghosted track** — A dormant, non-paused track in a multi-track setup where other tracks are active.
- **Learning debt** — Items the schedule expected but the learner hasn't completed and hasn't amnestied.
- **Mode (catchup_mode)** — A per-track setting controlling the primary recovery verb: rescope, amnesty, or hybrid.
- **Pause** — A first-class track state where the learner deliberately silences a track for a chosen duration (1d/3d/1w/2w/custom/indefinite). Auto-resumes with welcome-back on expiry. Pause is the **only** mechanism for notification silence — amnesty and rescope never silence on their own. Distinct from Archive.
- **Program track** — A track bound to an external schedule (Daf Yomi, school, tutor). Characterized by the impossibility of true catch-up; recovery is via amnesty.
- **Rescope** — Resetting the pace or deadline baseline on a self-paced track so "behind" is recomputed from a new anchor. Non-destructive. Does not trigger notification silence.
- **Review debt** — Chazara stages that are overdue according to the track's stage definitions and haven't been amnestied.
- **Self-paced track** — A track where the learner owns the schedule. Characterized by the ability to rescope without ceremony.
- **Setup Seeding flow** — The onboarding surface (new, replaces the existing "mark done" bulk UX) used by Scenarios 14 and 15 to let a learner declare pre-existing learning state — per-item choices of ✅ learned, ⏭️ amnesty, or 📅 defer.
- **Triage** — A multi-track workflow that presents each out-of-sync track in turn for a quick decision, completing in one short session. Order: program tracks first, smallest-debt-first within each group.
- **Unforgive** — Revoking an amnesty decision. The item returns to the queue.

---

## Appendix A: Mapping to Existing Code

Pointers to the code that this scenarios document would affect:

| Concept | Existing code | Change needed |
|---|---|---|
| `PaceCalculator` | `learning_tracker/lib/features/scheduler/domain/services/pace_calculator.dart:26` | Extend to respect amnesty when computing `daysBehind` |
| `TrackDao.resetPace` | `learning_tracker/lib/core/database/daos/track_dao.dart:215` | Rename/wrap as `rescope` in the service layer |
| Stage definitions | `learning_tracker/lib/core/database/tables/stage_definitions.dart` | No change; review-debt computation queries this |
| Completions | `learning_tracker/lib/core/database/tables/completions.dart` | No change; append-only invariant preserved |
| `ChazaraStatus` | `learning_tracker/lib/features/dashboard/domain/models/chazara_status.dart:1` | Extend to exclude amnestied reviews |
| `RecoveryActionButton` | `learning_tracker/lib/features/dashboard/presentation/widgets/track_card/recovery_action_button.dart` | Rework into scenario-aware actions |
| `TrackProgress` | `learning_tracker/lib/features/dashboard/domain/models/track_progress.dart:36` | Extend with `TrackDebt` struct |
| `PaceBehindCallback` | `learning_tracker/lib/features/scheduler/domain/services/pace_calculator.dart:7` | Wire into notification system per Section 6 |
| `curriculum_tracks` | `learning_tracker/lib/core/database/tables/` | Add per-track settings columns |
| (new) `item_amnesty` | — | New table per Section 2.1 |
| (new) `track_action_log` | — | New table per Section 2.4 |

---

## Appendix B: Ready-to-file Epic Shape

Rough epic shape (not a real epic yet — raw material for PM):

**Epic**: Catch-up & Amnesty System

**Epic goal**: Give learners graceful, non-demoralizing recovery from out-of-sync states across all track types, with first-class multi-track handling and a unified Pause-based silence mechanism.

**High-level story groupings**:
1. **Data model foundation** — `item_amnesty`, extended `curriculum_tracks` (including `paused_at`, `paused_until`, `primary_unit_type` per-track override), `TrackDebt` computed view, `track_action_log`. Curriculum metadata extension for `primary_unit_type`.
2. **Rescope v2 (service wrapper)** — wrap existing `TrackDao.resetPace` in a service-level `rescope()` method that handles side effects (audit log, optional pause offer, notification refresh). No DAO rename.
3. **Amnesty primitive** — single-item and per-stage amnesty (Scenario 5), revocation ("unforgive"), amnesty history view, snackbar undo.
4. **Pause mechanism** — new first-class track state distinct from Archive. Duration picker (1d/3d/1w/2w/custom/indefinite). Auto-resume with welcome-back. Applies everywhere the old "quiet window" was.
5. **Program debt handling** — Scenario 4 (Program Debt Pileup); bulk amnesty flows; behind-count recomputation respecting amnesty.
6. **Pace Reboot** — Scenario 3, bulk recovery with explicit Pause offer (not automatic).
7. **Review Debt** — Scenarios 6, 7; Review Debt view; chazara-respecting detection.
8. **Learning Journey view (Coverage Map)** — Scenario 8; gap visualization; per-track and cross-track.
9. **Multi-track triage** — Scenarios 9, 10, 11, 12; triage sheet (program-tracks-first, smallest-debt-first within), consolidation surfaces. Cross-credit opt-in UI (learning primary, review gated).
10. **Siyum cleanup** — Scenario 13; celebratory surface; unit-scoped amnesty.
11. **Setup Seeding flow** — Scenarios 14 and 15. **Replaces existing "mark done" bulk UX** with per-item learned/amnesty/defer choices. Used for both Program Launch Day and Personal Track Retrofit onboarding. Positioned in the epic as a user-visible improvement, not merely a new feature.
12. **Cycle-boundary welcome flow** — program track cycle transitions; auto-fresh-slate default with explicit carry-forward option.
13. **Notification system rewrite** — Section 6; wire `PaceBehindCallback`; unified Pause-based silence (no quiet windows); cadence derived from goal state; notification consolidation across tracks.
14. **Track settings UI** — expose per-track configuration from Section 2.2 (catchup_mode, show_behind_counter, pace_sensitivity_days, notification_cadence, review_strictness, auto_rescope, primary_unit_type override).

These are groupings, not stories. Each would expand into 3–8 stories during epic breakdown.

**Rough sequencing dependencies**:
- Group 1 (data model) blocks everything else.
- Groups 2, 3, 4 (rescope, amnesty, pause) are primitives consumed by Groups 5–12.
- Group 13 (notifications) depends on Groups 2, 3, 4 being in place.
- Groups 11 (Setup Seeding) and 12 (cycle boundary) can ship independently once primitives exist.
- Group 14 (settings UI) can ship in slices aligned with each primitive it configures.

**New questions surfaced in v2** (see §8.8) should be resolved before starting story breakdown on the affected groups.

---

*End of document. v2 delivered 2026-04-10. Next actions: hand §3, §4, §7, §8.7 to WDS for UX scoping; promote Appendix B to a real epic in the BMAD planning workflow; start data model story (Group 1).*
