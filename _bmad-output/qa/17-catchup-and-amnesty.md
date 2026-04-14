# Catch-up & Amnesty System -- Manual Test Scenarios

**Document:** 17
**Feature Area:** Recovery from out-of-sync states, rescope, amnesty, pause, multi-track triage
**Created:** 2026-04-13
**Status:** FORWARD-LOOKING -- This epic has not been implemented yet. These scenarios serve as a validation checklist for when the feature ships.
**Source Document:** `_bmad-output/planning-artifacts/catchup-and-amnesty-scenarios.md` (v2, all 20 questions + NQ1-NQ4 resolved)

---

## Prerequisites

Before running these scenarios:

1. Read `01-product-overview.md` for product context and glossary
2. Complete auth (02), onboarding (03), and have working completions (04)
3. Multiple curricula active with personal tracks and goals configured
4. Familiarity with the 3 track types (Personal, School, Tutor) from document 05
5. At least one program track (e.g., Daf Yomi Bavli) activated for program-specific scenarios
6. Ability to manipulate time or simulate dormancy (e.g., changing device clock, or creating completions with gaps)

---

## What & Why

### The Problem

A learner falls behind. Maybe they were traveling, sick, busy, or just lost motivation. The app currently shows a demoralizing "X days behind" counter with no way to recover gracefully. The learner feels guilt, avoids the app, and eventually abandons it entirely.

This is the #1 user retention risk in a learning tracker.

### The Solution: Two Recovery Verbs

The catch-up system is built on a central insight: there are **two fundamentally different kinds of falling behind**, and each needs a different recovery mechanism.

| Mode | Recovery Verb | What It Does | When to Use |
|------|--------------|--------------|-------------|
| **Self-paced** (Personal track) | **Rescope** | Resets the pace baseline or deadline. All items remain in the plan, just on a new clock. Nothing is "missed." | Learner owns the schedule and can adjust it freely |
| **Program** (School/Tutor/Daf Yomi) | **Amnesty** | Formally declines specific items for this cycle. They disappear from debt counts but remain in the data as explicitly skipped. | External authority owns the schedule; learner literally cannot catch up |

### The Governing Principle

> **"Data is sacred. Salience is negotiable."**

- Completions are NEVER deleted or backdated
- Amnesty records are additive metadata, not mutations
- Rescope moves a baseline; nothing in history is rewritten
- A learner can always see what they skipped and when
- The app must NEVER force a learner to delete or lose anything to stop feeling behind

### Pause: The Silence Mechanism

**Pause** is a first-class track state (distinct from Archive):
- Learner-initiated, with duration options: 1 day / 3 days / 1 week / 2 weeks / custom / indefinite
- A paused track produces NO notifications of any kind
- Auto-resumes on expiry with a gentle welcome-back prompt
- Amnesty and rescope do NOT silence notifications -- only explicit Pause does

### Key Data Structures

- **`item_amnesty` table**: Records amnesty decisions. Per-stage granularity. Soft-delete via `revoked_at` for "unforgive." Cycle-scoped for programs.
- **`curriculum_tracks` extensions**: New columns for `catchup_mode`, `paused_at`, `paused_until`, `pace_sensitivity_days`, `show_behind_counter`, `notification_cadence`, `auto_rescope`, `primary_unit_type`
- **`TrackDebt` (computed)**: Struct with `learningDebt`, `reviewDebt`, `orderGaps`, `daysBehind`, `daysDormant`, `amnestiedThisCycle`, `primaryScenario`
- **`track_action_log`**: Audit trail of rescope/amnesty/pause/archive actions

### Track States

| State | Meaning |
|-------|---------|
| **Active** | Normal operation, notifications fire, debt is computed |
| **Paused** | Deliberately silenced for a chosen duration, no notifications, auto-resumes on expiry |
| **Archived** | Considered finished or permanently stopped, ledger preserved, requires explicit revive |

### The 15 Named Scenarios

| # | Name | Mode | Trigger | Primary Action |
|---|------|------|---------|----------------|
| S1 | Gentle Drift | Self-paced | 1-3 days behind, reviews clean | Subtle note, optional catch-up |
| S2 | Rescope Moment | Self-paced | 4-14 days behind | "Adjust your plan" invitation |
| S3 | Pace Reboot | Self-paced | 15+ days behind or dormant | Full reboot with amnesty option |
| S4 | Program Debt Pileup | Program | Accumulated missed items | "Missing dapim" card with amnesty |
| S5 | Selective Amnesty | Any | Learner-initiated | Skip specific item/stage |
| S6 | Chazara Archipelago | Any | 1-15 sporadic review gaps | Review Debt view with badge |
| S7 | Chazara Collapse | Any | 15+ reviews, <20% completion rate | Warm restart offer |
| S8 | Out-of-Order Explorer | Any | Non-contiguous learning gaps | Coverage Map / Learning Journey |
| S9 | Returning Learner | Any | 14+ days dormant | Welcome-back with lifetime stats |
| S10 | Ghosted Track | Multi-track | One track 60+ days dormant, others active | "Still active?" prompt |
| S11 | Multi-Track Overload | Multi-track | 3+ tracks in debt | Triage sheet |
| S12 | Mode Conflict | Multi-track | Two tracks, same curriculum, different modes | Cross-credit prompt |
| S13 | Siyum Cleanup | Any | Near unit completion with pending reviews | Celebratory card (only if all learning complete) |
| S14 | Program Launch Day | Program | Join mid-cycle program | Setup Seeding flow |
| S15 | Personal Track Retrofit | Self-paced | New track with pre-existing learning | Setup Seeding flow |

### Siyum Integrity Rule

**A siyum (completion celebration) is only valid when ALL learning items in the unit have been completed -- nothing skipped, nothing amnestied.** If a learner has amnestied or skipped items within a masechta/seder/sefer, the app must NOT offer a siyum celebration. Instead it should show: "Siyum not available -- [N items] in [unit name] are missing or were skipped." The learner can then choose to go back and complete or un-amnesty those items to earn the siyum.

---

## Test Scenarios

### S1: Gentle Drift (Self-Paced, Mildly Behind)

| Field | Details |
|-------|---------|
| **ID** | CATCH-01 |
| **Priority** | P0 |
| **Title** | Gentle drift shows subtle inline note |
| **Preconditions** | Personal track with pace goal active, `pace_sensitivity_days = 3`. Miss 2 days of learning. |
| **Steps** | 1. Set a pace goal (e.g., "1 daf per day") on Bavli personal track. 2. Complete items for 3 consecutive days. 3. Skip 2 days (no completions). 4. Open the app on day 6. |
| **Expected** | Today's task shown front-and-center. A subtle inline note: "You're 2 dapim behind your pace. Want to catch up?" No red banners, no alarm. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-02 |
| **Priority** | P1 |
| **Title** | Gentle drift "catch up" option suggests temporary stretch |
| **Preconditions** | CATCH-01 state (2 days behind) |
| **Steps** | 1. Tap the "catch up" option on the inline note. |
| **Expected** | App suggests a temporary stretch (e.g., "3 dapim today instead of 1"). No permanent state change until learner acts. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-03 |
| **Priority** | P1 |
| **Title** | Gentle drift dismiss hides note for 24h |
| **Preconditions** | CATCH-01 state |
| **Steps** | 1. Dismiss the inline note. 2. Close and reopen app within 24h. |
| **Expected** | Note does not reappear until 24h have passed. After 24h, if drift persists, note returns. No data changes. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

---

### S2: Rescope Moment (Self-Paced, Meaningfully Behind)

| Field | Details |
|-------|---------|
| **ID** | CATCH-04 |
| **Priority** | P0 |
| **Title** | Rescope invitation shown at 4-14 days behind |
| **Preconditions** | Personal track with deadline goal. Fall 10 days behind (simulate by not completing for 10 days). |
| **Steps** | 1. Open app after 10 days of no completions. |
| **Expected** | "Adjust your plan" invitation shown. Preview: "At your current pace, you'd finish on [new date]. Want to update your goal?" Non-judgmental tone. Four options: (a) rescope to realistic date, (b) stretch goal, (c) not now, (d) archive goal. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-05 |
| **Priority** | P0 |
| **Title** | Rescope updates pace baseline and target date |
| **Preconditions** | CATCH-04 state |
| **Steps** | 1. Tap "Rescope to realistic date." 2. Check pace status. 3. Check daily task list. |
| **Expected** | `paceResetDate` updated. Pace status shows "on pace" (reset). Daily load recalculated to realistic amount. No completion records changed. Daily notifications continue normally (no automatic silence). |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-06 |
| **Priority** | P1 |
| **Title** | Stretch goal increases daily load temporarily |
| **Preconditions** | CATCH-04 state |
| **Steps** | 1. Select "Stretch goal." 2. Review proposed catch-up plan (e.g., "double pace for 5 days"). 3. Accept. |
| **Expected** | Scheduler increases daily load for specified period. Original deadline preserved. After stretch period, load returns to normal. Unrealistic stretches are warned against or suppressed. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-07 |
| **Priority** | P1 |
| **Title** | Rescope "Not now" defers prompt for 7 days |
| **Preconditions** | CATCH-04 state |
| **Steps** | 1. Tap "Not now." 2. Reopen app next day. |
| **Expected** | Rescope invitation does not reappear for 7 days. No state changes. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-08 |
| **Priority** | P1 |
| **Title** | Multi-track rescope companion prompt |
| **Preconditions** | 2+ self-paced tracks, both drifting |
| **Steps** | 1. Rescope one track. |
| **Expected** | Optional companion: "2 other self-paced tracks are also drifting. Rescope them too?" Shown as suggestion, never automatic. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

---

### S3: Pace Reboot (Self-Paced, Severely Behind)

| Field | Details |
|-------|---------|
| **ID** | CATCH-09 |
| **Priority** | P0 |
| **Title** | Pace reboot welcome shown at 15+ days behind |
| **Preconditions** | Personal track, 15+ days behind or 14+ days dormant. |
| **Steps** | 1. Simulate 20 days of no completions. 2. Open app. |
| **Expected** | Warm, non-judgmental welcome: "Let's restart fresh. You've learned [X] dapim -- that's real and it's saved." NO behind-counters shown. Four options: (a) full reboot, (b) rescope + keep reviews, (c) rescope only, (d) archive track. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-10 |
| **Priority** | P0 |
| **Title** | Full reboot rescopes + batch-amnesty all overdue reviews |
| **Preconditions** | CATCH-09 state with overdue chazara |
| **Steps** | 1. Select "Full reboot." 2. Check completion history. 3. Check review queue. |
| **Expected** | `paceResetDate` set. Bulk `item_amnesty` records created for all overdue reviews with `source = "bulk_rescope"`. Review queue cleared. Original completions untouched. Chazara schedule restarts fresh for future completions. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-11 |
| **Priority** | P1 |
| **Title** | Reboot offers explicit Pause option |
| **Preconditions** | CATCH-09 state |
| **Steps** | 1. Complete reboot flow. Look for Pause offer. |
| **Expected** | "Pause this track for a week while you get settled?" with Yes/No. NOT automatic -- learner chooses. If accepted, track paused for 7 days with auto-resume. If declined, normal notifications continue immediately. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-12 |
| **Priority** | P1 |
| **Title** | Rescope + keep reviews preserves review debt |
| **Preconditions** | CATCH-09 state |
| **Steps** | 1. Select "Rescope + keep reviews." 2. Check track state. |
| **Expected** | Learning pace rescoped (new baseline). Review debt remains visible in Review Debt view. Reviews NOT amnestied -- still actionable. Learner can amnesty them individually later. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

---

### S4: Program Debt Pileup

| Field | Details |
|-------|---------|
| **ID** | CATCH-13 |
| **Priority** | P0 |
| **Title** | Missing items card shown for program track |
| **Preconditions** | Program track (e.g., Daf Yomi Bavli). Miss 8 dapim over a month. |
| **Steps** | 1. Open app with 8 unlogged program dapim. |
| **Expected** | "Missing dapim" card: "8 dapim aren't logged as learned. What do you want to do?" Scrollable list grouped by date range. Five options: (a) catch up (mark as learned now), (b) amnesty all, (c) amnesty selected, (d) split decision, (e) decide later. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-14 |
| **Priority** | P0 |
| **Title** | Bulk amnesty for program debt |
| **Preconditions** | CATCH-13 state |
| **Steps** | 1. Tap "Amnesty all 8." |
| **Expected** | 8 `item_amnesty` records created with `source = "user_manual"`. Items removed from debt count. Behind-counter recomputed. Amnestied items visible in amnesty history. Daily program notification continues unchanged. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-15 |
| **Priority** | P1 |
| **Title** | Split decision: amnesty some, catch-up others |
| **Preconditions** | CATCH-13 state |
| **Steps** | 1. Multi-select 5 items for amnesty. 2. Mark 3 items as "learned now." |
| **Expected** | 5 amnesty records + 3 completion records with `completedAt = now` (not backdated). Behind-count reflects only remaining un-actioned items. Points awarded for 3 catch-up completions. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-16 |
| **Priority** | P1 |
| **Title** | "Decide later" snoozes program debt for 7 days |
| **Preconditions** | CATCH-13 state |
| **Steps** | 1. Tap "Decide later." 2. Reopen app next day. |
| **Expected** | Card does not reappear for 7 days. No nagging notifications about missed items during snooze. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

---

### S5: Selective Amnesty (Learner-Initiated)

| Field | Details |
|-------|---------|
| **ID** | CATCH-17 |
| **Priority** | P0 |
| **Title** | Amnesty single item from item detail |
| **Preconditions** | Any track with at least one item in the learning queue. |
| **Steps** | 1. Navigate to an item detail view. 2. Initiate amnesty (long-press or menu). |
| **Expected** | Confirmation: "Skip [item name]. You can change your mind later." Option to amnesty all stages or specific stage. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-18 |
| **Priority** | P0 |
| **Title** | Per-stage amnesty (keep learning, skip chazara) |
| **Preconditions** | Item with Learn stage completed, Chazara 1 overdue |
| **Steps** | 1. Amnesty only Chazara 1 stage for this item. |
| **Expected** | `item_amnesty` record created with specific `stage_id`. Learn completion preserved. Item removed from review debt but stays in learning history. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-19 |
| **Priority** | P1 |
| **Title** | Amnesty with optional reason |
| **Preconditions** | CATCH-17 flow |
| **Steps** | 1. Amnesty an item. 2. Add reason: "too advanced." |
| **Expected** | `item_amnesty.reason` stores the note. Visible in amnesty history. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

---

### S6: Chazara Archipelago (Sporadic Review Gaps)

| Field | Details |
|-------|---------|
| **ID** | CATCH-20 |
| **Priority** | P0 |
| **Title** | Review Debt view shows 1-15 scattered gaps |
| **Preconditions** | Track with 7 missed reviews scattered across different items. Learning debt is zero. |
| **Steps** | 1. Navigate to Review Debt view. |
| **Expected** | Browsable list of 7 overdue reviews, organized by age. Subtle badge on dashboard ("7 reviews waiting"), NOT a red banner. Actions: do review now, amnesty, amnesty all, schedule into rotation. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-21 |
| **Priority** | P1 |
| **Title** | Schedule reviews into rotation |
| **Preconditions** | CATCH-20 state |
| **Steps** | 1. Select "Schedule into rotation" for the 7 reviews. |
| **Expected** | Reviews spread across the next week's daily plan (1-2 extra per day). Daily task list updated. No amnesty records created -- these are being done, not skipped. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

---

### S7: Chazara Collapse (Systematic Review Neglect)

| Field | Details |
|-------|---------|
| **ID** | CATCH-22 |
| **Priority** | P0 |
| **Title** | Warm chazara restart offer at 15+ overdue reviews |
| **Preconditions** | Track with 60+ missed reviews, review completion rate < 20% over 30 days. |
| **Steps** | 1. Open app. Navigate to track. |
| **Expected** | Warm framing: "Your learning is strong. Chazara stopped around [date]. Reviews help retention -- want to restart?" NOT guilt-tripping. Four options: (a) restart reviews from today, (b) small commitment, (c) amnesty all review debt, (d) disable review stages. Notification cadence drops to weekly. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-23 |
| **Priority** | P1 |
| **Title** | Restart reviews from today (bulk amnesty old debt) |
| **Preconditions** | CATCH-22 state |
| **Steps** | 1. Select "Restart reviews from today." |
| **Expected** | Bulk `item_amnesty` records for all old review debt with `source = "restart_chazara"`. Future completions start fresh review clock. Existing completions untouched. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

---

### S8: Out-of-Order Explorer (Coverage Gaps)

| Field | Details |
|-------|---------|
| **ID** | CATCH-24 |
| **Priority** | P1 |
| **Title** | Coverage Map / Learning Journey shows gaps |
| **Preconditions** | Learn Mishnayos perek 1, skip perek 2-3, learn perek 4. |
| **Steps** | 1. Navigate to Learning Journey view. |
| **Expected** | Visual representation: perek 1 and 4 highlighted as learned, perek 2-3 shown as hollow gaps. "You have 1 gap: Perek 2-3." Accessible but NOT prominent on main dashboard. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-25 |
| **Priority** | P1 |
| **Title** | Fill gap or amnesty gap from Coverage Map |
| **Preconditions** | CATCH-24 state |
| **Steps** | 1. Tap on a gap. 2. Choose "Fill gap now" or "Amnesty gap." |
| **Expected** | Fill: routes to scheduler for gapped items. Amnesty: creates `item_amnesty` records for items in the gap. Also available: ignore, rearrange plan. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

---

### S9: Returning Learner (14+ Days Dormant)

| Field | Details |
|-------|---------|
| **ID** | CATCH-26 |
| **Priority** | P0 |
| **Title** | Welcome-back screen after 14+ days dormant |
| **Preconditions** | At least one track active. No app activity for 14+ days. |
| **Steps** | 1. Open app after 3+ weeks of no activity. |
| **Expected** | Welcome-back screen showing lifetime progress ("You've learned 38 dapim total"). NO behind-counts. Gentle onramp options. For single track: (a) quick reboot, (b) gentle resume, (c) ambitious catch-up, (d) just browse. For multi-track: routes to triage flow (S11). Tone is warm re-engagement, not judgmental. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-27 |
| **Priority** | P0 |
| **Title** | Welcome-back offers Pause as explicit choice |
| **Preconditions** | CATCH-26 state |
| **Steps** | 1. Look for Pause offer in welcome-back flow. |
| **Expected** | "Pause everything for a week while you get re-oriented?" with duration options. NOT automatic -- learner chooses. If accepted, all affected tracks paused with auto-resume. If declined, normal notifications resume immediately. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-28 |
| **Priority** | P1 |
| **Title** | Quick reboot from welcome-back (rescope + amnesty all) |
| **Preconditions** | CATCH-26 state, single track |
| **Steps** | 1. Select "Quick reboot." |
| **Expected** | Rescope + bulk amnesty all missed items. Clean slate. Pace recalculated from today. Original completions preserved. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

---

### S10: Ghosted Track (One Dormant Among Healthy)

| Field | Details |
|-------|---------|
| **ID** | CATCH-29 |
| **Priority** | P1 |
| **Title** | Dormant track demoted in track list |
| **Preconditions** | 3 tracks active. 2 healthy (recent activity). 1 track with 60+ days no activity. |
| **Steps** | 1. View track list or dashboard. |
| **Expected** | Ghosted track demoted below active tracks with reduced visual weight. Subtle note in Settings > Tracks: "[Curriculum] has been quiet. Still active?" Never notifies about ghosted tracks. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-30 |
| **Priority** | P1 |
| **Title** | Archive or revive ghosted track |
| **Preconditions** | CATCH-29 state |
| **Steps** | 1. Tap the ghosted track prompt. 2. Choose Archive or Revive. |
| **Expected** | Archive: sets `archivedAt`, removes from main UI, preserves ledger. Revive (rescope): clears archive, resets pace. Revive (fresh start): rescope + amnesty all past debt. Also available: dismiss prompt for 30 days. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

---

### S11: Multi-Track Overload (3+ Tracks Behind)

| Field | Details |
|-------|---------|
| **ID** | CATCH-31 |
| **Priority** | P0 |
| **Title** | Triage sheet appears with 3+ tracks in debt |
| **Preconditions** | 4 tracks active. 3+ tracks behind or in review debt. |
| **Steps** | 1. Open app with 3+ tracks in debt. |
| **Expected** | Triage sheet at top of dashboard: "Quick triage: handle all [N] tracks in 2 minutes." Individual cards collapsed under triage banner. Per-track notifications suppressed while triage pending, replaced by single "triage awaits" nudge. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-32 |
| **Priority** | P0 |
| **Title** | Triage order: program tracks first, smallest debt first |
| **Preconditions** | CATCH-31 state with mix of program and self-paced tracks |
| **Steps** | 1. Begin triage. Note the order tracks are presented. |
| **Expected** | Program tracks shown first (amnesty decisions are heavier). Within each group, smallest debt first (quick wins build momentum). Then self-paced tracks, also smallest-debt-first. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-33 |
| **Priority** | P1 |
| **Title** | Per-track quick actions in triage |
| **Preconditions** | CATCH-31 state |
| **Steps** | 1. Step through triage. For each track, choose an action (amnesty/rescope/archive/skip). |
| **Expected** | Each action applied individually. Logged in `track_action_log`. Next track presented immediately. Triage completes in ~90 seconds. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-34 |
| **Priority** | P1 |
| **Title** | Pause triage mid-flow and resume later |
| **Preconditions** | Triage flow active with 4 tracks. Learner completes 2 of 4. |
| **Steps** | 1. Handle first two tracks. 2. Select "Pause triage" or navigate away. 3. Return later. 4. Resume triage. |
| **Expected** | First two decisions saved and applied. Remaining tracks still pending. Triage banner reappears: "2 tracks remaining." Resuming picks up where left off. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-35 |
| **Priority** | P2 |
| **Title** | Pause a track during triage drops it from sequence |
| **Preconditions** | CATCH-31 state, mid-triage |
| **Steps** | 1. Pause a track during triage (NQ4). |
| **Expected** | Track immediately drops from triage sequence. If last track, triage ends gracefully. Paused track's debt becomes invisible. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

---

### S12: Mode Conflict (Same Curriculum, Different Tracks)

| Field | Details |
|-------|---------|
| **ID** | CATCH-36 |
| **Priority** | P1 |
| **Title** | Cross-credit prompt on completion |
| **Preconditions** | Two active tracks on same curriculum (e.g., personal Bavli + Daf Yomi program Bavli). |
| **Steps** | 1. Complete a daf on one track. |
| **Expected** | Subtle prompt: "This daf is also in your [other track]. Count it there too?" Options: cross-credit / always cross-credit / keep independent. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-37 |
| **Priority** | P1 |
| **Title** | Cross-credit creates parallel completion |
| **Preconditions** | CATCH-36 state, select cross-credit |
| **Steps** | 1. Accept cross-credit. 2. Check completion history on both tracks. |
| **Expected** | Parallel completion row on second track. Stage definitions per-track still apply independently (chazara schedules differ). Points awarded on both tracks if applicable. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-38 |
| **Priority** | P2 |
| **Title** | Cross-credit is opt-in, default off |
| **Preconditions** | Two tracks, same curriculum, no cross-credit configured |
| **Steps** | 1. Complete on one track. 2. Check other track. |
| **Expected** | No automatic cross-credit. Other track unchanged. Prompt appears only on the completing track. Default behavior is independent tracks. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

---

### S13: Siyum Cleanup (Near Completion with Pending Reviews)

| Field | Details |
|-------|---------|
| **ID** | CATCH-39 |
| **Priority** | P0 |
| **Title** | Siyum card shown ONLY when ALL learning items are complete |
| **Preconditions** | ALL items in a masechta have been completed (Learn stage). Some chazara reviews are pending in that masechta. No items amnestied or skipped. |
| **Steps** | 1. Complete the final Learn stage item in the masechta. |
| **Expected** | Celebratory card: "Siyum incoming! [N] reviews left to close this masechta cleanly." Options: (a) do reviews now, (b) siyum anyway (amnesty pending reviews), (c) finish learning first, reviews later. The siyum is the star -- NOT guilt-tripping about reviews. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-40 |
| **Priority** | P0 |
| **Title** | Siyum BLOCKED when items are skipped or amnestied |
| **Preconditions** | Near end of a masechta (95%+ progress) but 3 items within the masechta have been amnestied. |
| **Steps** | 1. Complete learning up to the last non-amnestied item. 2. Check for siyum card. |
| **Expected** | NO siyum celebration card. Instead: "Siyum not available -- 3 items in [masechta name] are missing or were skipped." Options: (a) go back and complete them, (b) un-amnesty and learn them, (c) acknowledge (no siyum). A siyum requires 100% completion of ALL learning items in the unit -- no exceptions. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-41 |
| **Priority** | P1 |
| **Title** | Un-amnesty items to earn siyum |
| **Preconditions** | CATCH-40 state (siyum blocked due to amnestied items) |
| **Steps** | 1. Un-amnesty the 3 skipped items. 2. Complete their Learn stages. 3. Check for siyum card. |
| **Expected** | After completing all items (including previously amnestied ones), siyum card now appears. The siyum is legitimate -- all learning was done. Learning ledger records the siyum event. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-42 |
| **Priority** | P1 |
| **Title** | "Siyum anyway" amnesty pending reviews |
| **Preconditions** | CATCH-39 state (all learning done, reviews pending) |
| **Steps** | 1. Choose "Siyum anyway." |
| **Expected** | Unit-scoped `item_amnesty` for pending reviews. Siyum recorded in `learning_ledger`. Celebration shown. This is valid because all LEARNING was completed -- only reviews were amnestied. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

---

### S14: Program Launch Day (Join Mid-Cycle)

| Field | Details |
|-------|---------|
| **ID** | CATCH-43 |
| **Priority** | P0 |
| **Title** | Setup Seeding flow for mid-cycle program join |
| **Preconditions** | No existing Daf Yomi track. Program is on daf 87. |
| **Steps** | 1. Create new Daf Yomi program track. |
| **Expected** | Two-choice screen: "The program is on daf 87. Where would you like to start?" Setup Seeding flow with per-item options: learned / amnesty / catch up later. Quick-path shortcuts: (a) align with program now, (b) start from beginning, (c) custom start point. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-44 |
| **Priority** | P0 |
| **Title** | "Align with program now" bulk amnesty pre-cycle items |
| **Preconditions** | CATCH-43 flow |
| **Steps** | 1. Choose "Align with program now." |
| **Expected** | Bulk `item_amnesty` for all pre-today items. Track starts from today's daf. Normal notifications begin. If personal Bavli track exists, cross-credit prompt (S12). |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-45 |
| **Priority** | P1 |
| **Title** | Custom start point with selective amnesty |
| **Preconditions** | CATCH-43 flow |
| **Steps** | 1. Choose custom start (e.g., daf 50). 2. Amnesty dapim 1-49. 3. Mark dapim 50-60 as "already learned." |
| **Expected** | Amnesty records for 1-49. Completion records for 50-60 with `completedAt = now`. Tracking starts from daf 61. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

---

### S15: Personal Track Retrofit (Import Existing Learning)

| Field | Details |
|-------|---------|
| **ID** | CATCH-46 |
| **Priority** | P0 |
| **Title** | Setup Seeding flow for existing learning import |
| **Preconditions** | No existing Mishnayos track. Learner has studied Berachos and Peah already. |
| **Steps** | 1. Create new personal Mishnayos track. 2. Toggle "I've already started this." |
| **Expected** | Setup Seeding flow showing curriculum hierarchy with per-item choices: learned / amnesty / defer. Batch mode available (mark whole masechta). Individual override for specific items. "Start minimal" option to skip seeding entirely. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-47 |
| **Priority** | P0 |
| **Title** | Batch mark masechta as learned during seeding |
| **Preconditions** | CATCH-46 flow |
| **Steps** | 1. Batch-mark Masechta Berachos as "learned." 2. Batch-mark Masechta Peah as "learned." 3. Leave others as "defer." 4. Complete seeding. |
| **Expected** | Completion records for all items in Berachos and Peah with `completedAt = now` and `source = "retrofit_seeding"`. Bookmark set after Peah. Goal setup offered. Honest audit trail -- timestamps reflect when declared, not backdated. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-48 |
| **Priority** | P1 |
| **Title** | Declare review state during seeding |
| **Preconditions** | CATCH-46 flow, items marked as learned |
| **Steps** | 1. For items marked "learned," declare "reviewed once." |
| **Expected** | Completion records created for Chazara 1 stage with `completedAt = now` and `source = "retrofit_seeding"`. Honest audit trail -- no fake timestamps. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

---

### Pause Mechanism

| Field | Details |
|-------|---------|
| **ID** | CATCH-49 |
| **Priority** | P0 |
| **Title** | Pause track with duration selection |
| **Preconditions** | Any active track |
| **Steps** | 1. Navigate to track settings. 2. Select "Pause." 3. Choose duration (e.g., 1 week). |
| **Expected** | `paused_at` set. `paused_until` set to 7 days from now. Track silenced -- no notifications. Track visually distinct (muted/greyed). Pace clock stops -- learner does not fall further behind while paused. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-50 |
| **Priority** | P0 |
| **Title** | Paused track auto-resumes on expiry |
| **Preconditions** | Track paused for 1 day (or simulate clock forward) |
| **Steps** | 1. Wait for pause expiry. 2. Open app. |
| **Expected** | Track auto-resumed. Gentle welcome-back prompt on next app open (not a notification). Normal notifications resume. Pace baseline accounts for pause period. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-51 |
| **Priority** | P1 |
| **Title** | Pause is distinct from Archive |
| **Preconditions** | One paused track, one archived track |
| **Steps** | 1. Compare UI treatment of paused vs archived. |
| **Expected** | Paused: "coming back" framing, one-tap resume, still visible in main UI (muted). Archived: "done" framing, explicit revive action, hidden from main UI. Different visual treatment. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-52 |
| **Priority** | P1 |
| **Title** | Indefinite pause requires manual resume |
| **Preconditions** | Any active track |
| **Steps** | 1. Pause with "indefinite" duration. 2. Wait any amount of time. 3. Open app. |
| **Expected** | Track stays paused. No auto-resume. Must manually resume from track settings. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

---

### Archive and Revive

| Field | Details |
|-------|---------|
| **ID** | CATCH-53 |
| **Priority** | P1 |
| **Title** | Archive track preserves ledger |
| **Preconditions** | Track with completions, goals, and bookmarks |
| **Steps** | 1. Archive the track. 2. Verify removed from main list. 3. Check archived tracks view. |
| **Expected** | `archivedAt` set. Track removed from dashboard and daily tasks. All completions, ledger entries, and history preserved. No notifications. Appears in "Archived" section. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-54 |
| **Priority** | P1 |
| **Title** | Revive archived track |
| **Preconditions** | Archived track with previous completions |
| **Steps** | 1. Navigate to archived tracks. 2. Revive with rescope or fresh start. |
| **Expected** | `archivedAt` cleared. `paceResetDate` set. If fresh start: past-due items amnestied. Track reappears on dashboard. Notifications resume. Previous completions intact. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

---

### Amnesty Revocation ("Unforgive")

| Field | Details |
|-------|---------|
| **ID** | CATCH-55 |
| **Priority** | P0 |
| **Title** | Revoke amnesty returns item to queue |
| **Preconditions** | Item with active amnesty record |
| **Steps** | 1. Navigate to amnesty history. 2. Find amnestied item. 3. Tap "Unforgive" / revoke. |
| **Expected** | `revoked_at` set on `item_amnesty` record. Item reappears in debt calculations and review queue. Original amnesty record preserved for audit (not hard-deleted). Revocation logged in `track_action_log`. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-56 |
| **Priority** | P1 |
| **Title** | Amnesty history shows all decisions with status |
| **Preconditions** | Multiple amnesty decisions -- some active, some revoked |
| **Steps** | 1. Navigate to amnesty history. |
| **Expected** | All amnesty records visible: item, stage (or "all stages"), date, reason, source, revoked status. Active vs revoked clearly distinguished. Filterable by track. Revoked entries show both dates. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

---

### Track Settings

| Field | Details |
|-------|---------|
| **ID** | CATCH-57 |
| **Priority** | P1 |
| **Title** | Per-track catchup_mode configuration |
| **Preconditions** | Track settings accessible |
| **Steps** | 1. Open track settings. 2. Change `catchup_mode` from "rescope" to "amnesty." |
| **Expected** | Setting saved. Future recovery flows lead with amnesty instead of rescope. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-58 |
| **Priority** | P1 |
| **Title** | Toggle show_behind_counter off |
| **Preconditions** | Track behind on pace |
| **Steps** | 1. Disable `show_behind_counter` in track settings. 2. Return to dashboard. |
| **Expected** | "X days behind" counter no longer visible for this track. Other tracks unaffected. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-59 |
| **Priority** | P2 |
| **Title** | Configure pace_sensitivity_days |
| **Preconditions** | Track settings accessible |
| **Steps** | 1. Change `pace_sensitivity_days` from 3 to 7. 2. Fall 5 days behind. |
| **Expected** | No "behind" messaging (within new sensitivity threshold). At 8 days behind, messaging appears. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-60 |
| **Priority** | P2 |
| **Title** | Primary unit type override per track (NQ1) |
| **Preconditions** | Bavli track |
| **Steps** | 1. In track settings, change `primary_unit_type` from "masechta" to "perek." |
| **Expected** | Progress calculations and siyum eligibility use perek as the unit instead of masechta. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

---

### Cycle Boundary

| Field | Details |
|-------|---------|
| **ID** | CATCH-61 |
| **Priority** | P2 |
| **Title** | New cycle auto-fresh-slate behavior |
| **Preconditions** | Program track with cycle-scoped amnesties. Simulate cycle boundary. |
| **Steps** | 1. Trigger new cycle start. |
| **Expected** | Old amnesties tagged with previous cycle, inactive in new cycle. "Welcome to Cycle N+1" flow shown with option to carry forward. `current_cycle_tag` updated. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

---

### Data Integrity & Governing Principle

| Field | Details |
|-------|---------|
| **ID** | CATCH-62 |
| **Priority** | P0 |
| **Title** | Completions never deleted by any recovery action |
| **Preconditions** | Track with completions. Perform rescope, amnesty, pause, archive. |
| **Steps** | 1. Record completions count. 2. Perform full reboot (rescope + bulk amnesty). 3. Check completions count. |
| **Expected** | Completion count unchanged. No rows deleted from completions table. Amnesty records are additive. Points, streaks, XP all preserved. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-63 |
| **Priority** | P0 |
| **Title** | Rescope never modifies completion records |
| **Preconditions** | Track with completions and pace goal |
| **Steps** | 1. Note specific completion records. 2. Perform rescope. 3. Check records. |
| **Expected** | All completion records identical. Only `paceResetDate` and/or `targetDate` changed on the track. Ledger untouched. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

| Field | Details |
|-------|---------|
| **ID** | CATCH-64 |
| **Priority** | P0 |
| **Title** | Track action log records all recovery actions |
| **Preconditions** | Perform several recovery actions: rescope, amnesty, revocation, archive. |
| **Steps** | 1. Perform each action. 2. Check `track_action_log`. |
| **Expected** | Each action has an entry: `action_type`, `track_id`, `occurred_at`, `source`. Rescope entries include before/after in `payload`. Log is append-only. |
| **Pass/Fail** | `[ ] Pass  [ ] Fail  Date: ___  Notes: ___` |

---

## Scenario Count Summary

| Category | Scenarios | IDs |
|----------|-----------|-----|
| S1: Gentle Drift | 3 | CATCH-01 to CATCH-03 |
| S2: Rescope Moment | 5 | CATCH-04 to CATCH-08 |
| S3: Pace Reboot | 4 | CATCH-09 to CATCH-12 |
| S4: Program Debt Pileup | 4 | CATCH-13 to CATCH-16 |
| S5: Selective Amnesty | 3 | CATCH-17 to CATCH-19 |
| S6: Chazara Archipelago | 2 | CATCH-20 to CATCH-21 |
| S7: Chazara Collapse | 2 | CATCH-22 to CATCH-23 |
| S8: Out-of-Order Explorer | 2 | CATCH-24 to CATCH-25 |
| S9: Returning Learner | 3 | CATCH-26 to CATCH-28 |
| S10: Ghosted Track | 2 | CATCH-29 to CATCH-30 |
| S11: Multi-Track Overload | 5 | CATCH-31 to CATCH-35 |
| S12: Mode Conflict | 3 | CATCH-36 to CATCH-38 |
| S13: Siyum Cleanup | 4 | CATCH-39 to CATCH-42 |
| S14: Program Launch Day | 3 | CATCH-43 to CATCH-45 |
| S15: Personal Track Retrofit | 3 | CATCH-46 to CATCH-48 |
| Pause Mechanism | 4 | CATCH-49 to CATCH-52 |
| Archive & Revive | 2 | CATCH-53 to CATCH-54 |
| Amnesty Revocation | 2 | CATCH-55 to CATCH-56 |
| Track Settings | 4 | CATCH-57 to CATCH-60 |
| Cycle Boundary | 1 | CATCH-61 |
| Data Integrity | 3 | CATCH-62 to CATCH-64 |
| **Total** | **64** | |

---

## Cross-Feature References

| Feature Area | Document | Relationship to Catch-up & Amnesty |
|---|---|---|
| **Learning & Completions** | 04 | Completions are never modified by catch-up or amnesty. The append-only invariant is the foundation. Amnesty is additive metadata alongside the immutable completion log. |
| **Multi-Track** | 05 | Catch-up mode is per-track. Cross-credit (S12) links same-curriculum tracks. Triage is a multi-track workflow. Pause is a new track state alongside active/archived. |
| **Scheduler & Goals** | 06 | Scheduler consumes `TrackDebt` to compute daily loads. Rescope resets pace baseline. Amnestied items excluded from debt calculations. |
| **Dashboard & Progress** | 08 | Dashboard surfaces scenario-specific cards (drift notes, reboot invitations, triage banners). Progress calculations respect amnesty. Siyum requires 100% learning completion. |
| **Gamification** | 09 | Points and streaks earned from completions persist through rescope and amnesty. Amnestied items do not retroactively remove earned points. |
| **Parent Mode** | 10 | Parent can manage track settings including catchup_mode for child accounts. |
| **Notifications** | 12 | Pause is the ONLY silence mechanism. Amnesty and rescope do NOT suppress notifications. Per-track notification cadence derived from goal state. |
| **Settings** | 13 | Per-track catchup settings accessible from track settings panel. |
| **Profiles** | 15 | All amnesty and rescope data is profile-scoped. Cascade delete removes amnesty records. |
| **Onboarding** | 03 | Setup Seeding flow (S14, S15) replaces current "mark done" bulk UX. Program Launch Day is an onboarding variant. |

---

## Notes for Testers

1. **This is a forward-looking document.** These scenarios have NOT been implemented yet. Use this document to validate the implementation when the epic ships.
2. **Simulating dormancy:** Change the device clock forward, or create test data with gaps in completion dates.
3. **Simulating program debt:** Join a Daf Yomi program track and don't complete items for several days.
4. **The emotional register matters.** Pay attention to the TONE of all messages. The app should never demoralize. "You're 14 dapim behind" is a bug. "Today's daf is ready" is correct.
5. **Data integrity is paramount.** After EVERY recovery action (rescope, amnesty, pause, reboot, triage), verify that no completion records were deleted or modified.
6. **Siyum integrity:** A siyum celebration must NEVER appear if any learning items in the unit were skipped or amnestied. Only pending REVIEWS can be amnestied and still allow a siyum. This is a critical product rule.
