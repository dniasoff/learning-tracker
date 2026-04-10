---
title: Catch-up & Amnesty Scenarios
author: Mary (BMAD Business Analyst)
created: 2026-04-10
status: draft-v1
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
- 14 named, narratively-grounded scenarios covering the full problem space (Section 4)
- An exhaustive decision grid that maps any possible state combination to the applicable scenarios (Section 5)
- A notification philosophy that flows from the recovery model (Section 6)
- A stub surface inventory — kept deliberately light because WDS will own the UX design (Section 7)
- Open questions that must be resolved before moving to epic (Section 8)

This document does not design the UI. It defines the *problem space* in enough detail that the UX designers (via WDS) and the engineering team can work in parallel with shared understanding.

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
| **Rescope** | Resetting the pace or deadline baseline on a self-paced track so "behind" is recomputed from a new anchor. Non-destructive. |
| **Amnesty** | Marking a specific item (or a specific stage of an item) as "declined in this cycle." The item remains in the data, but is excluded from debt calculations and reminders. Revocable. |
| **Debt** | The quantifiable gap between expected state and actual state on a track. Two independent flavors: **learning debt** (items the schedule expected but the learner hasn't completed) and **review debt** (chazara stages that are overdue and not amnestied). |
| **Cycle** | A time-bounded period within which amnesty applies. For Daf Yomi, a cycle is ~7.5 years. For self-paced tracks, a cycle is implicit or user-defined. New cycles reset the amnesty frame. |
| **Quiet window** | A period of notification silence that follows a rescope or amnesty action, to prevent the app from immediately re-nagging a learner who has just made a recovery decision. |
| **Catch-up plan** | A concrete, time-bounded recommendation (e.g., "do 2 dapim a day for the next week") that closes learning debt without rescoping or amnesty. |
| **Triage** | A multi-track workflow where the learner handles multiple out-of-sync tracks in one session, applying per-track rescope/amnesty/archive decisions efficiently. |
| **Coverage** | The pattern of what a learner has actually completed against the ordered content of a track, revealing gaps, out-of-order learning, and review state visually. |
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

Per Daniel's explicit requirement, recovery behavior must be configurable per track. Add the following columns (or a joined `track_settings` table, if preferred for schema hygiene):

```
curriculum_tracks
  ... existing columns ...

  catchup_mode              TEXT NOT NULL DEFAULT <derived from track_type>
                                -- "rescope" | "amnesty" | "hybrid"
                                -- default: rescope for personal, amnesty for school/tutor
  show_behind_counter       INTEGER NOT NULL DEFAULT 1     -- bool; learner can disable the "X days behind" surface
  pace_sensitivity_days     INTEGER NOT NULL DEFAULT 3     -- threshold before "behind" messaging kicks in
  review_strictness         TEXT NOT NULL DEFAULT 'relaxed'  -- "strict" | "relaxed"
  notification_cadence      TEXT NOT NULL DEFAULT 'daily'  -- "daily" | "weekly" | "silent"
  quiet_window_days         INTEGER NOT NULL DEFAULT 2     -- silence after rescope/amnesty action
  auto_rescope              INTEGER NOT NULL DEFAULT 0     -- bool; self-paced only — auto-reset pace on threshold
  last_action_silence_until DATETIME NULL                   -- computed; set by recovery actions
  current_cycle_tag         TEXT NULL                       -- active cycle identifier (for program tracks)
```

These settings let each track express its own personality:

- A disciplined Daf Yomi learner: `catchup_mode = amnesty`, `pace_sensitivity_days = 1`, `notification_cadence = daily`, `show_behind_counter = 1`.
- A casual self-paced learner who hates being nagged: `catchup_mode = rescope`, `pace_sensitivity_days = 7`, `notification_cadence = silent`, `auto_rescope = 1`, `show_behind_counter = 0`.
- A school track with strict teacher expectations: `catchup_mode = amnesty`, `review_strictness = strict`, `notification_cadence = daily`.

Track-type still provides the *default*, but the learner can override any setting per track. The same curriculum in different tracks can behave completely differently.

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

When two tracks point at the same content (e.g., a personal Bavli track and a Daf Yomi program track, both learning Berachos), the learner's work on one can optionally count for the other. This is a feature, not a default.

- The learner opts in per pair of tracks.
- Cross-credit duplicates the completion record into both tracks (maintaining the append-only invariant).
- Stage definitions are still per-track, so chazara schedules remain independent.
- Cross-credit applies forward only — it does not retroactively credit past completions unless the learner explicitly asks.

This creates Scenario 12 (Mode Conflict) as a distinct case worth naming.

### 3.3 Time Budget

A learner running 4 tracks has a finite daily capacity. The sum of "today's recommended work" across all tracks can exceed reality. When this happens:

- The app should detect the overload (`sum(today_items) > learner's_typical_daily_capacity`).
- The **daily plan** (a merged view across tracks, already present in the scheduler) should propose a prioritized subset, not the full list.
- Prioritization rules (to be defined; candidate heuristics): program-tracks-first (external deadlines), then streak-critical, then review debt, then new learning.
- The learner can override the priority per day.

Time budget is closely tied to Scenario 11 (Multi-Track Overload).

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

Triage completes in 90 seconds for a 4-track user. This is the primary escape hatch for Scenario 9 (Returning Learner) and Scenario 11 (Multi-Track Overload).

---

## 4. The 14 Named Scenarios

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
- **Notifications**: Quiet window of `quietWindowDays` (default 2) after rescope. No "behind" messaging during the window.
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
- **Notifications**: Long quiet window (default 7 days) post-reboot.
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
- **Notifications**: Hard silence for the first 7 days regardless of settings. Pure re-engagement mode — no nag is allowed.
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
- **Actions**: (a) **Align with program now** — start tracking from today's daf; all earlier items are auto-amnestied with `source = "cycle_boundary_join"` and a `cycle_tag`; (b) **Start from the beginning** — track independently, don't care about program's clock (this is effectively a self-paced track pretending to be program mode, and the learner should be warned); (c) **Custom start point** — pick any daf, auto-amnesty earlier ones.
- **Data impact**: Track created with appropriate settings + bulk `item_amnesty` inserts for pre-start items (if aligning).
- **Notifications**: Onboarding sequence only — no catch-up logic until day 7.
- **Multi-track**: *"You already have a personal Bavli track — cross-credit future completions?"* prompt if applicable (links to Scenario 12).
- **Open questions**: What happens when a new Daf Yomi cycle starts? Do existing trackers carry forward amnesties or get a fresh slate? (Recommendation: fresh slate by default, with an option to carry forward in settings.)

---

## 5. Exhaustive Scenario Grid

The 14 named scenarios cover the most important narratives. But any possible state combination should map to at least one scenario. This section provides that complete mapping.

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
- **Specialized cases** (S5, S9, S13, S14): triggered by action or context, not computed state alone.

**Coverage assertion**: every cell in the state space either maps to the default "normal" dashboard (when no scenario applies) or to at least one named scenario. There are no silent dead zones.

---

## 6. Notification Philosophy

The notification system (currently a TODO — `PaceBehindCallback` in `pace_calculator.dart`) should be designed in service of the recovery model above, not bolted on after. This section defines the principles; the wiring comes later.

### 6.1 Principles

1. **Never demoralize.** No notification should ever lead with a behind-count. *"You're 14 dapim behind"* is forbidden language. *"Today's daf is ready"* or *"Time for chazara"* is the correct register.
2. **Respect recovery actions.** After a rescope or amnesty, the quiet window must be honored. The learner has just made a decision; pinging them immediately contradicts it.
3. **Consolidate across tracks.** A learner with 4 tracks should not receive 4 notifications per day. A single daily digest is the default, with per-track opt-in to detailed notifications.
4. **Celebrate more than nag.** Positive events (streak maintained, siyum approaching, catch-up completed) get a higher notification budget than negative events.
5. **Every notification is dismissible into silence.** The learner can turn off any specific notification class without abandoning the app entirely.
6. **Per-track override.** Global notification preferences are overridden by per-track `notification_cadence`.

### 6.2 Quiet Windows

Quiet windows are periods of forced silence on a track following a recovery action. Defaults:

| Trigger | Quiet window |
|---|---|
| Rescope | 2 days |
| Selective amnesty (≤ 3 items) | 0 days |
| Bulk amnesty (> 3 items) | 3 days |
| Pace Reboot (S3) | 7 days |
| Returning Learner onboarding (S9) | 7 days |
| Program Launch Day (S14) | 7 days |

During a quiet window: no behind-count messaging, no "did you forget?" nudges, no guilt. Daily program notifications (e.g., "today's daf is ready") are still allowed because they are purely informational, not evaluative.

### 6.3 Notification Types

| Type | Trigger | Muted during quiet window? | Default cadence |
|---|---|---|---|
| **Daily reminder** | "Today's work is ready" | No | Daily at learner-chosen time |
| **Review due** | Chazara stage threshold hit | Yes | Daily |
| **Streak at risk** | Within 2 hours of streak-breaking | Yes | Once per day max |
| **Streak achievement** | Milestone hit | No | On event |
| **Siyum approaching** | S13 conditions | No | Weekly |
| **Siyum complete** | Unit finished | No | On event |
| **Catch-up progress** | Learner closed some debt | No | On event |
| **Review debt digest** | S6 conditions | Yes | Weekly |
| **Triage invitation** | S11 conditions | No | Once per overload event |
| **Welcome back** | S9 trigger | No | Once per gap |
| **Chazara collapse notice** | S7 conditions | Yes | Once per collapse event, then monthly |
| **Ghosted track prompt** | S10 trigger | N/A — track has no quiet window | Once, then suppressed 30 days |

### 6.4 Suppression Rules

- No two evaluative notifications on the same track within 4 hours.
- No more than 3 notifications across all tracks per day (default — learner can change).
- Overload state (S11) suppresses all per-track notifications until triage is complete or paused.
- Dormant tracks never generate notifications except the Welcome Back on next session open.
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
| **Coverage Map view** | **New** | S8 |
| **Amnesty history / Skipped view** | **New** | All amnesty scenarios (review & unforgive) |
| **Track settings panel** | Existing (extend) | All per-track mode configuration |
| **Onboarding (returning)** | **New** | S9 |
| **Onboarding (program launch)** | **New** | S14 |
| **Siyum celebration** | Existing (extend) | S13 |
| Notification center | Existing (extend) | All |

The WDS work can use this table as its scope checklist. Each new surface becomes a candidate page specification.

---

## 8. Open Questions & Decisions Needed

These are the things we need to decide before moving to epic. They are in rough priority order.

### 8.1 Naming & concepts

- **Q1**: Is *amnesty* the final word? Alternatives considered: *skip, defer, forgive, release, pass.* (Current working answer: yes — amnesty carries the right emotional weight.)
- **Q2**: Is *coverage* the right word for the gap-visualization view? Alternatives: *map, sequence, atlas.*
- **Q3**: *Rescope* vs. *reset pace* — the code already uses "reset pace" and `paceResetDate`. Do we rename the code concept to rescope or keep internal code terminology and use rescope only as the learner-facing term?

### 8.2 Data model

- **Q4**: Is `stage_id = NULL` the right sentinel for "amnesty all stages of this item," or should we use explicit rows per stage? (Trade-off: NULL is compact but requires special-case logic; explicit is verbose but uniform.)
- **Q5**: Cycle scoping — should `cycle_tag` auto-advance for program tracks on new cycles, and should carrying forward be automatic or explicit? (Recommendation: explicit fresh slate, with a migration-time option to carry forward.)
- **Q6**: Do we need a separate `track_settings` table, or extend `curriculum_tracks` in place? (Schema hygiene vs. write efficiency.)

### 8.3 Thresholds

- **Q7**: Default values for `paceSensitivityDays`, `severeThreshold`, `dormancyThreshold`, `chazaraCollapseThreshold`. Need to pick numbers that feel right for typical Torah learners — may need user research.
- **Q8**: What defines a "unit" for the concentration detection in S6 vs S13? Masechta? Perek? Configurable per curriculum?
- **Q9**: How do we compute "typical daily capacity" for time-budget checks in Section 3.3? Rolling average of recent days? Explicit learner setting?

### 8.4 Multi-track

- **Q10**: Cross-credit between same-curriculum tracks — should chazara stage progression cross-credit, or only initial learning? (Current recommendation: only learning, unless the learner explicitly opts in per pair.)
- **Q11**: Triage order — what's the priority of tracks within a triage session? Alphabetical? Most-behind first? Most-recently-used first?
- **Q12**: Is there a distinction between "pause a track" and "archive a track"? (Paused = temporarily silent, easy to resume; archived = ledger-only, intended permanent.)

### 8.5 Notifications

- **Q13**: Default notification cadence per track type (personal, school, tutor) — what should the initial defaults be?
- **Q14**: How do program notifications behave during a quiet window? (Recommendation: daily "today's daf" informational notifications continue; evaluative notifications pause.)
- **Q15**: Can learners configure the quiet window duration per recovery action, or only globally?

### 8.6 Backwards-compat & migration

- **Q16**: Existing tracks have no `catchup_mode`, `show_behind_counter`, etc. What's the migration story? (Recommendation: derive defaults from `track_type` at migration time; offer a one-time setup prompt for learners to review the defaults.)
- **Q17**: Existing data has no amnesty records. Do we need to seed anything on migration? (Recommendation: no — migration is neutral; learners create amnesty records going forward.)

### 8.7 UX direction for WDS

- **Q18**: Should the Catch-up Sheet, Triage Sheet, and Review Debt View be three distinct surfaces or tabs of a single "Recovery Center" screen? (Defer to WDS.)
- **Q19**: Should amnesty be a swipe gesture, a long-press menu, or a confirmation sheet? (Likely mixed by context — defer to WDS.)
- **Q20**: How prominent should the "what I amnestied" history be? Hidden in settings? Accessible from every amnesty button? (Defer to WDS but flag as important.)

---

## 9. Glossary

- **Amnesty** — A formal, non-destructive declaration that a specific item or stage is "not being done in this cycle." Removes the item from debt calculations and reminders while preserving it in the data. Revocable.
- **Catch-up plan** — A concrete, bounded recommendation for closing learning debt without rescoping or amnesty. Typically phrased as "do X extra per day for Y days."
- **Chazara** — Review. Post-initial-learning repetitions defined by stage definitions.
- **Contiguous learning** — Completion order matches curriculum order (no gaps).
- **Coverage** — The pattern of completed vs. uncompleted items across the curriculum's linear structure.
- **Cycle** — A bounded time period within which amnesty applies. Explicit for program tracks (e.g., Daf Yomi cycle 14), implicit for self-paced.
- **Debt** — The quantifiable gap between expected and actual learning state on a track. Has two independent flavors: learning debt and review debt.
- **Dormant track** — A track with no activity for ≥ 14 days.
- **Ghosted track** — A dormant track in a multi-track setup where other tracks are active.
- **Learning debt** — Items the schedule expected but the learner hasn't completed and hasn't amnestied.
- **Mode (catchup_mode)** — A per-track setting controlling the primary recovery verb: rescope, amnesty, or hybrid.
- **Program track** — A track bound to an external schedule (Daf Yomi, school, tutor). Characterized by the impossibility of true catch-up.
- **Quiet window** — A period of notification silence following a recovery action, to prevent immediate re-nagging.
- **Rescope** — Resetting the pace or deadline baseline on a self-paced track so "behind" is recomputed from a new anchor. Non-destructive.
- **Review debt** — Chazara stages that are overdue according to the track's stage definitions and haven't been amnestied.
- **Self-paced track** — A track where the learner owns the schedule. Characterized by the ability to rescope without ceremony.
- **Triage** — A multi-track workflow that presents each out-of-sync track in turn for a quick decision, completing in one short session.
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

**Epic goal**: Give learners graceful, non-demoralizing recovery from out-of-sync states across all track types, with first-class multi-track handling.

**High-level story groupings**:
1. **Data model foundation** — `item_amnesty`, track settings extension, `TrackDebt` computed view, `track_action_log`.
2. **Rescope v2** — promote existing `resetPace` to full rescope UX with quiet window and preview.
3. **Amnesty primitive** — single-item amnesty flow (Scenario 5), revocation, history view.
4. **Program debt handling** — Scenarios 4, 14.
5. **Pace Reboot** — Scenario 3, bulk recovery.
6. **Review Debt** — Scenarios 6, 7; Review Debt view; chazara-respecting detection.
7. **Coverage Map** — Scenario 8.
8. **Multi-track triage** — Scenarios 9, 10, 11, 12; triage sheet, consolidation surfaces, time budget.
9. **Siyum cleanup** — Scenario 13.
10. **Notification system rewrite** — Section 6; wire `PaceBehindCallback`; quiet windows; per-track cadence.
11. **Track settings UI** — expose per-track configuration from Section 2.2.

These are groupings, not stories. Each would expand into 3–8 stories during epic breakdown.

---

*End of document. Next actions: review with WDS for UX scoping; resolve open questions with product/engineering; promote to epic.*
