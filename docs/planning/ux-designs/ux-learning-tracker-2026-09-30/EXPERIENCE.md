---
name: Learning Tracker — Sub-tracks
status: draft
updated: 2026-10-01
sources:
  - docs/planning/prds/prd-sub-tracks-2026-09-30/prd.md  # wiki "PRD: Sub-tracks" (oWEwMw7iGT) — FR / UJ IDs
  - docs/planning/prds/prd-sub-tracks-2026-09-30/addendum.md  # wiki addendum (yBGcGFULnc)
  - docs/brainstorming/brainstorm-multi-source-mishnayos-tracking-2026-08-24/brainstorm.html
  - learning_tracker/ (current app source — shell, routes, theme, lifetime tree, sacred-time lock)
  - DESIGN.md  # peer spine — visuals and tokens
---

# Learning Tracker — Sub-tracks · Experience Spine

These spines win on conflict with any mock, wireframe, or import. Visuals and tokens live in [`DESIGN.md`](DESIGN.md); this file owns how Sub-tracks behaves. Requirement and journey IDs (FR-n, UJ-n) refer to the PRD and are not restated here. Glossary terms carry their PRD §3 meanings exactly: main track, sub-track, ground, current position, learning event, source, date state, chazara, capacity, shortfall, capture lock, catch-up card, tutor.

> **Deviation from PRD FR-23 / FR-24 / UJ-4, by product-owner decision 2026-10-01. PRD amendment pending.** During a shabbos / yom tov lock the app is **not** readable or usable. The existing full-screen `SacredTimeLockOverlay` covers it. The planned list is an **erev** view with live controls. See § Shabbos & Yom Tov.

## Foundation

- **Governing principle: as simple as possible.** Every Sub-tracks surface follows it. Recording takes one gesture on the relevant row. Sub-tracks stay invisible to families who don't use them, and their settings live on the sub-track that owns them. Remove a choice when it needs no explanation.
- **Form factor.** Phone first, plus a dedicated tablet layout for every Sub-tracks surface. Dark mode follows `ThemeMode.system`. It is demonstrated on phone; tablet mocks are light only, and the dark tokens apply unchanged.
- **UI system.** The existing Learning Tracker Flutter app:
  - Material 3, with `AppTheme` + `AppPalette` (`context.colors`).
  - AutoRoute shell with Dashboard · Learn · Progress · Settings.
  - Riverpod `AsyncValue` loading and error states.
  - Shared `showAppDialog` / `showAppConfirmDialog`, floating snackbars, `AnimatedProgressBar`, `SacredTimeLockOverlay`.
- **Scope.** Sub-tracks only. Main-track task generation, onboarding, profile switcher, viewing-child banner, PIN gates, the sacred-time lock overlay, and tutor invite / grant / revoke flows behave as they do today, except where a row below names a change.
- **Visual reference.** DESIGN.md. The approved Stitch mocks under `mockups/` illustrate composition; their counts are illustrative.

### Mock reconciliation

The approved mocks contain Stitch drift that is **not** spec:

- **App name and row badges**
  - The title "Mishnayos Tracker" → the app is **Learning Tracker**.
  - "Cheder" / "Tutor" / "Primary Class" / "Special" badges on sub-track rows and the up-to picker (including "Cheder / School track") → none. Rows show the sub-track's name only.
- **Mock #09 is the erev view** (`09-erev-*`): controls live, "Planned for Shabbos" shown as a preview list. During the lock the existing full-screen overlay applies (no mock).
- **Tablet form panels.** None of the following ships:
  - ongoing form: pace-health badge, projected annual volume, daily-quota adjustment, parent tip;
  - school-year form: seder-coverage benchmarks, annual pacing, home-vs-school load, tips.
- **Invented content** → none:
  - institution, class and teacher names; session times;
  - weekly-requirement meters on child rows; "Target Siyum" projection;
  - chazara schedules and tips; tutor session notes; "Learn now" on tutor detail.
- **Sub-track-level status.** "Behind schedule" / "On target for Shavuos" on dashboard cards → none. On-track status is goal-level only (FR-18).
- **Change history.** "Reason:", "Context & Teacher Note", "Action pending review", "90-day retention", "via app ping" → none.
- **Mishna history and lifetime report.**
  - Mishna history: "Chazara Goal Met", "Last reviewed", "Logged by … Cheder portal", event IDs, per-event notes → none.
  - Lifetime report: "Projected Milestones", "rabbinic review verification signatures", "Reviews" → none.
- **Sub-labels.** "Pacing well", "Supervisor", "Active Session", "Sync active" → none.
- **Talmidim filter tabs.** All / Needs Attention / On Track → not adopted; see Open Questions.

## Information Architecture

| Surface | Reached from | Roles | FRs | Mock |
|---|---|---|---|---|
| **Learn tab · Also learning section** | Learn tab, below today's main-track tasks | child, parent, tutor | FR-1, FR-2, FR-2a, FR-6a, FR-16, FR-17 | [`01-learn-tab-mobile`](mockups/01-learn-tab-mobile.html) |
| **Up-to picker** | *Up to…* on a sub-track row, on the main-track today list, or in catch-up *Adjust…* | child, parent, tutor | FR-2, FR-2a | [`02-up-to-sheet-mobile`](mockups/02-up-to-sheet-mobile.html) |
| **Dashboard · on-track card + shortfall warning** | Dashboard tab (parent / tutor view of a learner) | parent, tutor | FR-18, FR-19, FR-20, FR-21 | [`03-dashboard-parent-mobile`](mockups/03-dashboard-parent-mobile.html) |
| **Dashboard · sub-track summary cards** | Dashboard tab | child (position only), parent, tutor | FR-1, FR-9 | [`03-dashboard-parent-mobile`](mockups/03-dashboard-parent-mobile.html) |
| **Manage tracks hub · Sub-tracks group** | Settings → Manage tracks (existing hub, `/settings/tracks`; parent `/parent-mode/tracks`) | parent, tutor | FR-4a, FR-8, FR-12 | [`04-manage-tracks-mobile`](mockups/04-manage-tracks-mobile.html) |
| **New / edit school-year sub-track** | Hub → *Add sub-track* → School year; detail → ⋮ → Edit; detail → *Add next year* | parent, tutor | FR-5, FR-6b, FR-7, FR-8 | [`05-new-school-year-mobile`](mockups/05-new-school-year-mobile.html) |
| **New / edit ongoing sub-track** | Hub → *Add sub-track* → Ongoing; detail → ⋮ → Edit | parent, tutor | FR-6, FR-6a, FR-6b, FR-8 | [`06-new-ongoing-mobile`](mockups/06-new-ongoing-mobile.html) |
| **Sub-track detail** | Hub row; Learn sub-track row; dashboard summary card; shortfall *View School →* | child (read, incl. capacity), parent, tutor | FR-7, FR-8, FR-9, FR-11, FR-13 | [`07-subtrack-detail-mobile`](mockups/07-subtrack-detail-mobile.html) |
| **Ground picker** | Sub-track detail → *+ Add ground*; groundless row / talmid row → *Add ground* | parent, tutor | FR-10, FR-12a, FR-15 | [`08-ground-picker-mobile`](mockups/08-ground-picker-mobile.html) |
| **Erev planned view** | Learn tab from the zmanim-derived erev window until the lock starts | child, parent, tutor | FR-24 (amended) | [`09-erev-mobile`](mockups/09-erev-mobile.html) |
| **Lock overlay** (existing) | Automatic, whole app, every signed-in device | everyone | FR-23 (amended) | none (existing `SacredTimeLockOverlay`) |
| **Catch-up card** | Top of Learn tab after a lock | child, parent, tutor | FR-2a, FR-6b, FR-16, FR-25 | [`10-catch-up-mobile`](mockups/10-catch-up-mobile.html) |
| **My talmidim** | Tutor's own device, tutor mode (relation to existing `/tutor/my-grants` open) | tutor | FR-26, FR-29 | [`11-tutor-talmidim-mobile`](mockups/11-tutor-talmidim-mobile.html) |
| **Change history** | Settings (parent) → Change history. **NEW parent-scoped view** across all the learner's tutors and the parent; the existing `/tutor/audit-log` is keyed by one tutor grant and is not it. | parent | FR-4, FR-27 | [`12-change-history-mobile`](mockups/12-change-history-mobile.html) |
| **Mishna history** | Tap any leaf mishna in the corpus browser, lifetime tree, sub-track detail or ground row | child, parent, tutor | FR-4, FR-14, FR-30 | [`13-mishna-history-mobile`](mockups/13-mishna-history-mobile.html) |
| **Lifetime report (incl. per-source)** | Progress tab → Lifetime (existing `/progress/lifetime`) → Report | parent | FR-31, FR-32 | [`14-lifetime-report-mobile`](mockups/14-lifetime-report-mobile.html) |
| **Corpus browser · free tick** | Existing Browse (`/browse`, content hierarchy) | child, parent | FR-3, FR-15 | none |
| **Main corpus view · assigned ground greyed** | Existing curriculum progress / browse views | all | FR-10, FR-12, FR-12a, FR-15 | none |
| **Onboarding mention** | Existing onboarding, one line on one step | parent | FR-4a (UJ-5) | none |
| **Revoke tutor** | Existing Manage tutors (`/tutor/manage-tutors`) | parent | FR-28 | none (existing screen) |

**Navigation rules.** The shell is unchanged. On phone, Sub-tracks screens push onto the current tab's stack. Modal depth is one: the up-to picker never opens over another sheet or dialog.

## Roles & Visibility

| Element | Child (Yehuda) | Parent (his father) | Tutor (Rav Cohen) |
|---|---|---|---|
| Sub-track rows, +1, Up to… | ✓ capture | ✓ capture | ✓ capture (granted learners) |
| Groundless row | visible, actions disabled | *Add ground* prompt | *Add ground* prompt |
| Encouragement, today vs target, streak | ✓ | ✓ | ✓ |
| On-track card (*On track* / *Behind pace* / *Too early to tell*), projected finish | **never** | ✓ | ✓ |
| Daily target number | as today-vs-target only | ✓ | ✓ |
| Shortfall warning card, shortfall tag on the capacity bar | **never** | ✓ | ✓ `[ASSUMPTION]` (FR-21 names the parent; FR-26 gives the tutor parent-equivalent track access) |
| Sub-track detail incl. capacity bar (FR-9) | ✓ read only | ✓ | ✓ |
| Create / edit / delete sub-track, assign / order ground | ✗ | ✓ | ✓ |
| Correct a mistake (FR-4) | own captures: re-date within the catch-up window; older captures can only be removed | ✓ | ✓ |
| Voided events | hidden | visible in change history | visible in change history `[ASSUMPTION]` |
| Change history + Undo | ✗ | ✓ | ✗ |
| My talmidim list | ✗ | ✗ | ✓ |
| Mishna history | ✓ | ✓ | ✓ |
| Lifetime / per-source report + Export PDF | ✗ | ✓ | ✗ `[ASSUMPTION]` |
| Any access during the lock | ✗ (overlay) | ✗ (overlay) | ✗ (overlay, every device) |

## Voice and Tone

Microcopy only; brand posture is in DESIGN.md. There are three registers in one product:

- **Child.** Warm, short, forward-looking. Counts and next steps, never judgments. Never say outside-source learning "doesn't count" (FR-16). Never say behind, off track, failing or shortfall (FR-18, FR-21).
- **Parent.** Plain status and numbers, an approximate "about", and the named track and ground. Warnings explain the consequence ("will return to home learning"), not blame.
- **Tutor.** The parent register, scoped to *his* sub-track ("Rebbe: next Beitzah 3:1"), with a standing reminder of the access boundary.

Hebrew domain terms follow the Hebrew Terms setting. UI strings follow the device locale (English / Hebrew).

| Context | Approved string (from mocks or PRD) |
|---|---|
| Learn section header | "Also learning · 2 sub-tracks" |
| Sub-track row position | "Next: Berachos 1:4" |
| Row actions | "Up to…" · "+1" (main list: "Mark +1") |
| Up-to picker | "School · up to…" · "Tap the last mishna you learnt" · rows "Included" / "Skipped" / "Next up" · "Cancel" · "Record 4 mishnayos" |
| Child encouragement | "Today 3 of 4 done" · "Great pace! Only one left to finish today's goal." |
| On-track (parent) | "On track" · "Projected finish: 14 Mar 2029 · deadline Elul 5789" · "Daily target: 3 mishnayos/day" |
| Off-track (parent / tutor) | "Behind pace" |
| Too little history | "Too early to tell" |
| Zero target (FR-19) | "All covered — any extra learning is a bonus." |
| Shortfall (FR-21, UJ-3) | "School may not reach Berachos perek 3 before July. About 40 mishnayos will return to home learning." · "View School →". **Deviates from the PRD example string by decision — flag to PM.** PRD UJ-3: "School will not finish Berachos by Jul 2027 — about 40 mishnayos come back to you." |
| Hub | "Sub-tracks · 2 active" · "Learning that happens outside home — school, a rebbe, a chavrusa." · "Add sub-track" · "Ended sub-tracks (1)" |
| School-year form | "Sub-track name" · "Academic year" · "Start month" / "End month" · "Mishnayos per week" · "~2 mishnayos / school day" · "Weeks per year" · "Prefilled — edit if the school year is shorter" · "Learns on shabbos / yom tov" · "Include this source on the catch-up card after shabbos" · "You can add ground later — the school's masechtos don't need to be known yet." · "Save sub-track" |
| Ongoing form | "Not learning during bein hazmanim" · "Lowers weeks per year" · "Prefilled from bein hazmanim toggle — edit if needed" · "Start date (optional)" · "End date (optional)" · "You can have up to 5 ongoing sub-tracks. 1 in use." |
| Sub-track detail | "Up next" · "38 ticked" · "Capacity vs Path" · "Remaining path: 350 · Total capacity: 390" · "No shortfall" · "Ground (in order)" · "Drag to order" · "3 of 5 learnt" · "learnt at home" · "+ Add ground" · "Add next year (2027–28)" |
| Ground picker | "Add ground to School" · "Available only" · "Rebbe · In use" · "Chazara" · "Complete · Partial · Empty" · "Reset changes" · "Add 3 perakim to School" · "They'll leave the home schedule while School holds them." |
| Erev | "Shabbos Kodesh · שבת קודש" · "Planned for Shabbos". Lock-time line: "Shabbos begins at {time} — record what you can before then." `[ASSUMPTION copy]` |
| Lock overlay | Existing greeting and subtitle strings (`SacredTimeLockOverlay`), unchanged |
| Catch-up | "Shabbos · 14 mishnayos planned — learnt them all?" · "Available until the end of Sunday" · "Yes, all of it" · "Adjust…" · "Rebbe (learns on shabbos)" · "Record 13 mishnayos" |
| Tutor | "Tutor mode · Rav Cohen" · "My talmidim" · "Rebbe: no ground yet" · "Add ground" · "You see only learners whose parents gave you access." |
| Change history | "Rav Cohen · Rebbe · 4:10 pm — Added ביצה פרק ד׳ (Beitzah perek 4) to Rebbe track" · "Undo" · "Undone" · "Reverted change: …" |
| Mishna history | "Learnt · נלמד" · "5 times learnt" · "Every time · 5 entries · Newest first" · "(Shabbos, caught up)" · "catch-up" · "chazara" · "Before tracking" · "Repeats never add to goal progress — they're kept here as your record." |
| Lifetime report | "Distinct · 1,204 mishnayos" · "Learning events · 1,876" · "By source" · "School years" · "Per-source pace" · "Last 30 days" · "Before-tracking learning isn't counted in pace." · "Export PDF" |

| Do | Don't |
|---|---|
| "Next: Berachos 1:4" | "You're 12 mishnayos behind at school" |
| "About 40 mishnayos will return to home learning." (parent) | "School is failing" / any shortfall wording to the child |
| "Learning events" for the total of all records | "Reviews" (reads as chazara only) |
| "Ended sub-tracks" `[ASSUMPTION]` replacing the mock's "Completed … · Archived" | "Completed" for a sub-track that ended with unfinished ground |

## Component Patterns

Behavioural rules only. Visual specs live in DESIGN.md § Components under the same names.

| Component | Use | Behavioural rules |
|---|---|---|
| **Sub-track row** | Learn tab, Also learning | One row per *active* sub-track, in hub order `[ASSUMPTION]`. Hidden before a future start date (FR-6a) and after the window ends. The whole section is absent when the learner has no active sub-tracks (FR-4a). The row is the source (FR-2), so there is never a source prompt. Tapping the row body opens Sub-track detail. Groundless: actions are disabled for the child; parent and tutor see *Add ground* → Ground picker (FR-1). Uses `{components.subtrack-row}`. |
| **+1 button** | Sub-track row; main-track today list | Records one learning event at the track's current position, dated today. The current position then advances to the next mishna not yet ticked *in that track* (FR-2, FR-13). Optimistic update: count, masechta fill, streak (home only, FR-16) and siyum (FR-17) update in the same frame. Shows an undo snackbar. |
| **Up to… button** | Sub-track row; main-track list; catch-up groups | Opens the Up-to picker for that track at its current position. |
| **Up-to picker** | Sheet (phone) / dialog (tablet) | Lists mishnayos in track order from the current position. Tapping a row makes it the target and ticks everything from the current position through it (tick-to-here). Any row can then be unticked individually, which flips its label between *Included* and *Skipped* (FR-2a). The confirm button counts only ticked rows. *Cancel* or swipe-down discards. Confirm writes one event per ticked row; skipped rows stay unticked, so the position becomes the first unticked row. The list runs through the end of the track's entered ground and loads lazily `[ASSUMPTION]`. |
| **Tri-state row** | Ground picker, Sub-track detail, corpus browser, lifetime tree | State is derived (FR-15): one learnt descendant makes every ancestor partial; all learnt makes it complete. Learning from *any* source counts (FR-13, FR-14). Tapping the checkbox selects (ground picker) or ticks (corpus browser). Tapping the label expands a non-leaf node or opens Mishna history for a leaf mishna. |
| **Free-tick row** | Corpus browser (FR-3) | Tap ticks one node. Long-press → "Tick up to here" marks the mishna and everything before it in corpus order within its masechta `[ASSUMPTION gesture]`. A batch asks for the source once (Home by default; *Before tracking* offered). The date defaults to today and can be edited before confirming. Before-tracking events touch neither streak nor velocity. Free ticks count toward the streak only when the source is Home. |
| **Source chip** | Mishna history, lifetime report | Display only. The label is the sub-track's name at event time; events from a deleted track keep the deleted track's name (FR-30). |
| **On-track card** | Dashboard (parent, tutor) | Hidden for the child. Shows *On track*, *Behind pace*, or *Too early to tell* (under 2 weeks of history), based on the trailing-4-week projection (FR-18). With no deadline it shows only "Projected finish", with no status and no daily target (FR-20). Frozen for the lock period and re-evaluated after it (FR-23). |
| **Shortfall warning card** | Dashboard, under the on-track card | One card per sub-track with shortfall > 0, naming the track, ground, window end and approximate count (FR-21). Disappears when shortfall returns to 0. *View School →* opens that sub-track's detail. Never shown to the child. |
| **Status chip** | My talmidim | Same three states and rules as the on-track card, per learner (FR-29). |
| **Sub-track summary card** | Dashboard | Name, "Next: …", ticked count and a progress bar (`{components.subtrack-summary-card}`); tap → Sub-track detail. The bar shows ticked in this track ÷ (ticked + remaining path) `[ASSUMPTION]`. *Manage* → hub. |
| **Capacity bar** | Sub-track detail | Capacity vs remaining path, shown to every role (FR-9, FR-19). When remaining path exceeds capacity, parent and tutor see the shortfall count in the tag. The child never sees a shortfall tag or count. |
| **Ground row** | Sub-track detail | Reorder by drag handle (FR-11). Ticks are kept, the current position resets to the first unticked item, and the forecast, **the main track's schedule and today's tasks recompute** (FR-11, FR-19). No stale tasks remain. New ground is appended at the end. Swipe or ⋮ → *Remove from School* `[ASSUMPTION]` returns unlearnt ground to the main track at its original position (FR-12). Read only for the child, with no handles. |
| **Ground picker** | Full screen (phone) / right pane (tablet) | Multi-select of masechta / perek / mishna nodes (FR-10); selecting a parent selects its descendants. Nodes already in *this* sub-track are pre-checked and disabled, so there are no duplicates. Ground held by another sub-track stays selectable, tagged "{name} · In use". Already-learnt ground stays selectable, tagged "Chazara". *Available only* filters out in-use and learnt nodes. The footer count is live. Confirm appends the selection and greys those nodes on the main track. **The main track's schedule and today's tasks recompute** (FR-10, FR-19); the target does not jump while entered ground stays within capacity. *Reset changes* clears the pending selection. |
| **Sub-track form** | New / edit | Inline validation on blur and on save. School-year: the academic-year picker spans current → deadline year, or current + 2 when there is no deadline; used years are disabled, not hidden (FR-5). Start and end months are editable, and windows may not overlap. Weeks/year prefills 39. Ongoing: the bein-hazmanim switch changes only the *prefilled* weeks, never weeks the user edited (FR-6). Save is blocked at 5 active ongoing tracks. Rate edits recompute the daily target on save (FR-8). |
| **Academic-year picker** | School-year form | Single select. Each chip shows *Used* (disabled), *Active* or *Open*. |
| **Add next year** | Sub-track detail (school-year only) | Opens the school-year form prefilled with name, rate, weeks and edited month boundaries for the following academic year, with empty ground (FR-7). Disabled if that year is already used. |
| **Delete sub-track confirm** | Detail ⋮ → Delete track | Uses `showAppConfirmDialog`. The message states that unfinished ground returns to the main track and learning events stay in the lifetime record (FR-8, FR-12). On confirm: navigate back to the hub, recompute the schedule, show a snackbar. Dismissing the dialog is the same as *Cancel*. |
| **Ended sub-tracks group** | Hub | Collapsed by default. Ended tracks are read only and open Sub-track detail in read-only mode `[ASSUMPTION]`. They don't count toward the five-ongoing limit. |
| **Info note** | Forms, talmidim footer, mishna history footer, onboarding | Static text, not focusable as an action. |
| **Onboarding mention** | One existing onboarding step (UJ-5) | One `Info note`, no action, no setup step, never repeated (FR-4a). |
| **Erev banner + planned list** | Learn tab, erev | Appears from the erev window until the lock starts `[ASSUMPTION: start of window = the day of candle-lighting]`. The banner shows the lock start time from zmanim at the learner location. The planned list shows the main-track mishnayos planned for each locked day, with **live** checkboxes, +1 and *Up to…*. Ticks made here are ordinary dated events. Sub-track rows stay live. |
| **Lock overlay** | Whole app, during the lock | Existing behaviour, unchanged: opaque full screen, back navigation blocked, no app content readable or tappable. Shown on every signed-in device, tutor devices included. Dismisses itself when the window ends. |
| **Disabled action** | Groundless-row actions (child), used academic years, *Add next year* when the year is used | Stays in place, non-interactive, exposed to semantics as disabled; tapping does nothing. |
| **Catch-up card** | Learn tab, top, after a lock | See § Shabbos & Yom Tov. |
| **Tutor-mode bar** | Shell, tutor sessions | Existing component. Persistent on every surface in tutor mode. |
| **Talmid row** | My talmidim | Tap → that learner's context (through the existing tutor PIN gate where one is configured). Revoked learners disappear on the next sync (FR-28, FR-29). *Add ground* on a groundless row deep-links to that learner's Ground picker. |
| **Revoke tutor** | Existing Manage tutors | Existing action and confirm. Access ends on the tutor's next sync. Tracks and events the tutor created remain unchanged (FR-28). |
| **Change-history entry** | Change history (new parent-scoped view) | Shows who, what and when (FR-27). *Undo* reverts the change and records a new "Reverted change" entry; the original is marked *Undone* and can't be undone twice. Tutor edits to the deadline or main track notify the parent (bell on the entry); sub-track edits appear without a notification. Concurrent edits: the later one wins, and both are listed. |
| **History event row** | Mishna history | Newest first. Voided events are excluded from the count and hidden from the child (FR-30). Parent / tutor: tap → correct or remove (FR-4) `[ASSUMPTION placement]`. |
| **Per-source pace row** | Lifetime report | One row per source: measured mishnayos/week over the window against the sub-track's estimate (FR-32). Before-tracking events are excluded from pace; catch-up events count on the day they were learnt. |
| **School-year group row** | Lifetime report | Same-named sub-tracks roll up into one expandable row with a child line per year (FR-31). |
| **Navigation rail** | Tablet shell | Same destinations, order and visibility rules as the bottom navigation, including hidden in parent-elevated child mode `[ASSUMPTION]`. |

## State Patterns

### Cross-cutting

| State | Surface | Treatment |
|---|---|---|
| No sub-tracks | Learn, Dashboard | No "Also learning" section and no summary cards. Nothing invites creation (FR-4a). |
| Groundless sub-track | Learn row, talmid row, detail | Row visible. Child: "No ground yet" `[ASSUMPTION copy]` with disabled actions. Parent / tutor: *Add ground*. The forecast still counts expected new ground (FR-19). |
| Future-start sub-track | Learn, hub | Absent from Learn until the start date. The hub row shows "Starts {date}" `[ASSUMPTION copy]` (FR-6a). |
| Ended sub-track | Learn, hub | Absent from Learn; listed under *Ended sub-tracks*. |
| Partial / complete / empty | All corpus trees | Tri-state per FR-15. Ground learnt in another source shows as learnt ("learnt at home" / "learnt at {source}") without changing this track's current position (FR-9). |
| Overlapping ground | Ground picker, details | "{name} · In use". Each track keeps its own position (FR-13). |
| Assigned ground on main track | Main corpus / browse | Visible but greyed and unscheduled while any active sub-track holds it (FR-10). Greyed rows carry the holding sub-track's name as a tag `[ASSUMPTION]`. Returned earlier ground queues after the current masechta (FR-12a). |
| Too early to tell / Behind pace | On-track card, talmid chip | Too early to tell: under 2 weeks of history. Behind pace: parent and tutor only; child surfaces show unchanged encouragement (FR-18). |
| No deadline | Dashboard | Projected finish only (FR-20). |
| Zero target | Dashboard (parent / tutor); Learn today section `[ASSUMPTION placement]` | "All covered — any extra learning is a bonus." (FR-19) |
| Shortfall | Dashboard, sub-track detail | Warning card and capacity tag, parent / tutor only. Clears at 0. |
| Erev | Learn | Banner and planned list, all controls live. |
| Locked | Whole app, every device | Existing full-screen overlay. On-track status frozen. |
| Lock, zmanim / location unavailable | Overlay; parent | Conservative local-time fallback lock (fails closed). After the lock the parent is prompted to set location via the existing city picker `/sacred-time/city` (FR-23). Prompt copy is open. |
| Catch-up pending / stacked / expired | Learn | See § Shabbos & Yom Tov. |
| Offline | All capture | Capture works offline and syncs later. The existing shell offline banner shows for cloud-born users. Events from devices merge without overwrite. |
| Loading / error (generic) | All | Existing `LoadingIndicator`, `AppErrorView`, `InlineAsyncError` with retry. The target recompute takes under 1 s `[ASSUMPTION — PRD §4.9]`, so no spinner shows on the target after a tick. |
| Ongoing limit reached | Ongoing form, hub | *Add sub-track* → Ongoing is disabled: "You can have up to 5 ongoing sub-tracks. 5 in use." `[ASSUMPTION copy]` |
| Siyum | Any capture | The existing celebration fires once, when distinct learnt mishnayos complete a masechta from any source. Chazara never re-fires it (FR-17). |

### Per surface

Rejected sync means the server rejects a queued write: an event stamped inside a lock window (FR-23), or an edit to a track deleted or access-revoked in the meantime. The default treatment `[ASSUMPTION]` is the same everywhere: sync rolls back the optimistic change and a floating snackbar explains it. Each row below gives the surface's copy or a deviation.

| Surface | Empty | Load / error | Rejected sync |
|---|---|---|---|
| Learn · Also learning | Section absent | Inline `InlineAsyncError` in the section; main-track tasks unaffected | "Some learning couldn't be saved — it was recorded during Shabbos." / "…this sub-track no longer exists." `[ASSUMPTION copy]` |
| Up-to picker | Groundless never opens it. End of ground: "No more mishnayos in School's ground." `[ASSUMPTION copy]` | Inline error + retry inside the sheet; confirm disabled | As Learn |
| Dashboard · on-track / shortfall | No deadline → FR-20; < 2 weeks → Too early to tell; no shortfall → no card | Card shows `InlineAsyncError` with retry | n/a (read only) |
| Dashboard · summary cards | Absent when no active sub-tracks | Inline error per section | n/a |
| Manage tracks hub | Sub-tracks group shows only the header text and *Add sub-track* | Existing `TrackManagementBody` error state | Edit rolled back with snackbar "Your change couldn't be saved." `[ASSUMPTION copy]` |
| Sub-track forms | n/a | Save failure: stays on the form with values kept, plus an error snackbar and retry | Created track removed on sync with the snackbar above |
| Sub-track detail | Groundless: empty ground list + *+ Add ground* | `AppErrorView` with retry | Reorder / remove rolled back with snackbar |
| Ground picker | *Available only* with nothing left: "Everything here is already assigned or learnt." `[ASSUMPTION copy]` | `AppErrorView` with retry | Assignment rolled back with snackbar |
| Erev planned view | Nothing planned for the locked day(s): the banner shows without the list | As Learn | As Learn |
| Catch-up card | Nothing planned and no flagged sub-tracks → no card | Inline error in the card; card stays available | "Couldn't save — try again before the card expires." `[ASSUMPTION copy]` |
| My talmidim | "No talmidim yet — a parent needs to give you access." `[ASSUMPTION copy]` | `AppErrorView` with retry | Edits on a revoked learner discarded: "Access to {name} has ended." `[ASSUMPTION copy]` |
| Change history | "No changes yet." `[ASSUMPTION copy]` | `AppErrorView` with retry | Undo rolled back with snackbar |
| Mishna history | Not learnt: header "Not learnt yet", empty list `[ASSUMPTION copy]` | `AppErrorView` with retry | Correction rolled back with snackbar |
| Lifetime report | No events: totals show 0, sections hidden except "Distinct · 0" `[ASSUMPTION]` | `AppErrorView` with retry | n/a; export failure in UJ-6 |
| Corpus browser · free tick | n/a | Existing browse error state | As Learn |

## Interaction Primitives

- **+1.** One tap records one learning event and advances the current position.
- **Up to….** Opens the picker. Tapping a row ticks through to it; individual rows can then be unticked or re-ticked. Confirm with *Record n mishnayos*.
- **Tick-to-here.** In the picker (tap) and in the corpus browser (long-press "Tick up to here"), as specified above.
- **Drag reorder.** Ground rows reorder by drag handle or by long-press on the row, reusing the existing `draggable_order_item` pattern. ⋮ → *Move up* / *Move down* is the accessible equivalent `[ASSUMPTION]`. Every reorder recomputes the main track's schedule and today's tasks.
- **Undo.** After +1, *Record n*, *Yes, all of it*, or a free-tick batch, a floating snackbar shows "Recorded n · Undo" `[ASSUMPTION copy]` for the standard snackbar duration. Undo voids those events (FR-4). The parent undoes tutor changes in Change history, and each undo is itself recorded.
- **Correct.** Parent and tutor correct place, source or date from Mishna history. The child is limited as FR-4 describes.
- **Expand / collapse.** Tree nodes, the ended-sub-tracks group, school-year group rows, and catch-up *Adjust…*.
- **Banned.** Source pickers on sub-track rows; prompts or nudges to create sub-tracks; app access during the lock; modal stacks more than one deep; hover-only affordances.

## Shabbos & Yom Tov

This section covers FR-23 to FR-25, FR-6b and FR-16.

> **Deviates from PRD FR-23 / FR-24 by product-owner decision 2026-10-01 — PRD amendment pending.** The PRD's "app remains readable" and "locked planned view" are replaced: the lock is the existing unreadable full-screen overlay, and the planned view is an erev view with live controls.

→ Mocks: [`09-erev-mobile`](mockups/09-erev-mobile.html) (erev, controls live); [`10-catch-up-mobile`](mockups/10-catch-up-mobile.html) and [`10-catch-up-dark`](mockups/10-catch-up-dark.html).

1. **Erev.** Before the lock, the Learn tab shows the erev banner, then "Planned for Shabbos" listing the main-track mishnayos planned for each locked day, then "Also learning". Every control is live.
2. **Lock window.** Runs from 10 minutes before candle-lighting to 10 minutes after tzeis at the learner's location, on every signed-in device including the tutor's.
   - The lock fails closed. If zmanim or location are unavailable, a conservative local-time fallback applies, including at high latitude.
   - One-day or two-day yom tov follows the learner-level Israel / chutz-la'aretz setting.
   - Chained yom tov + shabbos is one continuous lock.
3. **During the lock** the existing `SacredTimeLockOverlay` covers the whole app: opaque, back navigation blocked, nothing readable or tappable. The on-track status is frozen and doesn't change on account of the locked days. Offline writes stamped inside the window are rejected at sync.
4. **Catch-up card** after the lock: "Shabbos · 14 mishnayos planned — learnt them all?"
   - *Yes, all of it* records every planned main-track mishna, plus the planned next mishnayos of sub-tracks marked *Learns on shabbos / yom tov*, as *catch-up dated* events on the locked day(s). How a sub-track's amount is derived is `[ASSUMPTION]`: that track's planned amount for the lock.
   - *Adjust…* expands into per-source groups, one section per locked day (up to 3, FR-25). Each section has *Up to…* and individual untick. Confirm with *Record n mishnayos*.
   - Only the main track and flagged sub-tracks appear (FR-6b).
   - The card stays available through the first full non-locked day ("Available until the end of Sunday"). It pauses across an intervening lock. Pending cards stack, oldest first `[ASSUMPTION order]`.
   - **A reminder notification fires once, when the card becomes available** (FR-25). Reminder copy is open.
   - A caught-up lock day keeps the streak (FR-16). If the card expires, learning can still be recorded by free tick, but the lock day gets no streak credit.

## Accessibility Floor

Behavioural. Contrast lives in DESIGN.md § Colors.

- **Targets.** Every interactive element is at least 48 × 48dp, including +1, *Up to…*, picker rows, tree checkboxes, drag handles, chips and *Undo* (`{spacing.touch-target}`).
- **Text scaling.** Honoured up to the platform maximum. At large scales, sub-track rows wrap with name and position stacked above the actions, rather than truncating. Context bars keep the existing text-scale sizing. Hebrew marks are never clipped.
- **Semantics.**
  - Sub-track row: "School, next Berachos 1:4", with actions "Record one mishna for School" / "Record up to, School".
  - Tri-state checkbox: "complete" / "partially learnt, 3 of 9" / "not learnt".
  - Picker rows announce included or skipped; the confirm label carries the live count.
  - Status chips and the on-track card announce status as text, never by colour alone.
- **Disabled, not hidden.** Groundless-row actions for the child, used academic years, and an unavailable *Add next year* stay in the tree and are announced as "disabled".
- **Lock overlay.** Existing behaviour: the greeting is announced, back navigation is blocked, and nothing behind it is reachable by screen reader. The erev banner is the first focusable element after the app bar and announces the lock start time.
- **Reorder.** Every drag has a non-drag equivalent.
- **Focus order.** Follows reading order. In tablet two-pane layouts the list comes before the detail. Opening the up-to picker moves focus to its title; closing returns focus to the triggering button.
- **Motion.** The progress-bar animation and the siyum celebration respect the platform reduce-motion setting `[ASSUMPTION]`.
- **Direction.** RTL comes from the app's Hebrew locale. Drag handles, chevrons and "next" direction mirror, and insets use `EdgeInsetsDirectional`.

## Responsive & Platform

- **Breakpoints** `[ASSUMPTION]`, using Material 3 window size classes:
  - below 600dp: phone layout with bottom navigation;
  - 600–839dp: navigation rail with single-pane content;
  - 840dp and up: navigation rail with two-pane layouts.
- **Two-pane behaviour.** The list pane keeps its selection, and the detail pane updates in place. The up-to picker is a centred dialog.
- **Forms.** Capped at `{spacing.form-max-width}`, beside a summary panel listing the learner's existing sub-tracks. For school-year tracks the panel also shows "Capacity {n} mishnayos ({rate}/wk × {weeks} weeks)". No projections, health badges or tips.
- **Per-surface layouts.** See DESIGN.md § Layout & Spacing and the tablet mocks: [`01`](mockups/01-learn-tab-tablet.html) · [`02`](mockups/02-up-to-dialog-tablet.html) · [`03`](mockups/03-dashboard-parent-tablet.html) · [`04`](mockups/04-manage-tracks-tablet.html) · [`05`](mockups/05-new-school-year-tablet.html) · [`06`](mockups/06-new-ongoing-tablet.html) · [`07`](mockups/07-subtrack-detail-tablet.html) · [`08`](mockups/08-ground-picker-tablet.html) · [`10`](mockups/10-catch-up-tablet.html) · [`11`](mockups/11-tutor-talmidim-tablet.html) · [`12`](mockups/12-change-history-tablet.html) · [`13`](mockups/13-mishna-history-tablet.html) · [`14`](mockups/14-lifetime-report-tablet.html).
- **Dark mode.** Follows the system setting. Dark phone mocks: [`01`](mockups/01-learn-tab-dark.html) · [`02`](mockups/02-up-to-sheet-dark.html) · [`03`](mockups/03-dashboard-parent-dark.html) · [`04`](mockups/04-manage-tracks-dark.html) · [`05`](mockups/05-new-school-year-dark.html) · [`06`](mockups/06-new-ongoing-dark.html) · [`07`](mockups/07-subtrack-detail-dark.html) · [`08`](mockups/08-ground-picker-dark.html) · [`10`](mockups/10-catch-up-dark.html) · [`11`](mockups/11-tutor-talmidim-dark.html) · [`12`](mockups/12-change-history-dark.html) · [`13`](mockups/13-mishna-history-dark.html) · [`14`](mockups/14-lifetime-report-dark.html).
- **Locale.** Mocks are English LTR. Hebrew domain terms follow the Hebrew Terms setting, and RTL is inherited from the app's Hebrew locale.
- **Platforms.** iOS and Android parity via Flutter. The platform back gesture pops one level and dismisses the up-to sheet without recording. During the lock, back is blocked.

## Inspiration & Anti-patterns

- **Reference: the inherited app.** The shipping Learning Tracker UI (royal blue #1442B8, cream canvas, Plus Jakarta Sans, flat outlined cards) is the only visual reference. Sub-tracks introduces no new brand direction.
- **Lifted from the app: the lifetime tree.** Its tri-state colours and tint, combined with the marking row's tristate checkbox, give every corpus node the same look.
- **Rejected: the old dark/green Stitch direction** (`docs/scenarios/stitch-prompts/`, #13ec13 on dark). It does not match the current app and is not a visual source.
- **Rejected: the brainstorm's grey-box tri-state.** The existing lifetime-tree treatment applies.
- **Rejected: readable lock.** The existing full-screen overlay applies instead of the PRD's readable, read-only lock view (product-owner decision 2026-10-01).
- **Rejected: nudges and gap prompts.** Sub-track creation prompts and the school-year gap question (FR-22, withdrawn) are not built. Sub-tracks are found, never pushed.

## Key Flows

The PRD owns each journey's persona, context and path (PRD §2.3). The steps below are their UI realisation.

### UJ-1. Yehuda ticks his whole day in one sitting.
Protagonist: **Yehuda** (child, own profile). → [`01`](mockups/01-learn-tab-mobile.html), [`02`](mockups/02-up-to-sheet-mobile.html)
1. In the morning, Yehuda opens the Learn tab and ticks today's main-track mishnayos, or taps *Mark +1*.
2. At bedtime he reopens the Learn tab. "Also learning" shows "School — Next: Berachos 1:4" and "Rebbe — Next: Beitzah 3:1".
3. He taps *Up to…* on School. The picker opens at Berachos 1:4.
4. He taps Berachos 2:3, which ticks 1:4 – 2:3. He unticks 2:1, which the class skipped, and the button reads "Record 4 mishnayos".
5. He confirms. The sheet closes and the School row reads "Next: Berachos 2:1".
6. He does the same on Rebbe, or taps +1.
7. **Climax:** the mishnayos count rises, the masechta fills in, and the home streak holds from the morning's learning. If a masechta just completed, the siyum fires.
8. His father, on the Dashboard, sees "On track".
- **Failure path:** Yehuda records the wrong range. He taps *Undo* on the snackbar, or Yehuda, his father or Rav Cohen corrects it later (FR-4). Count and target recompute.

### UJ-2. Rav Cohen keeps his sub-track true for several talmidim.
Protagonist: **Rav Cohen** (tutor, own phone). → [`11`](mockups/11-tutor-talmidim-mobile.html), [`06`](mockups/06-new-ongoing-mobile.html), [`08`](mockups/08-ground-picker-mobile.html)
1. He opens tutor mode; the bar reads "Tutor mode · Rav Cohen". *My talmidim* lists each learner with a status chip.
2. He taps Yehuda, then Settings → Manage tracks → *Add sub-track* → Ongoing.
3. He enters "Rebbe", 5 per week and weeks per year, then taps *Save sub-track*.
4. On the groundless Rebbe sub-track he taps *+ Add ground*, selects Beitzah, and taps *Add … to Rebbe*. The main track's schedule recomputes.
5. Weeks later he adds the next masechta the same way. When Yehuda ticked the wrong place, he corrects it from Mishna history.
6. **Climax:** Yehuda's Rebbe row shows the right position, and Yehuda's daily target reflects the rebbe's contribution.
7. Back on *My talmidim*, he sees each talmid's standing in one list.
- **Failure path:** if the parent revokes access, the learner disappears on the next sync; Rav Cohen's tracks and events remain (FR-28). If the parent edits at the same time, the later change wins and both appear in history.

### UJ-3. Yehuda's father sets up this school year — informally, in pieces.
Protagonist: **Yehuda's father** (parent). → [`04`](mockups/04-manage-tracks-mobile.html), [`05`](mockups/05-new-school-year-mobile.html), [`07`](mockups/07-subtrack-detail-mobile.html), [`08`](mockups/08-ground-picker-mobile.html), [`03`](mockups/03-dashboard-parent-mobile.html)
1. In September: Settings → Manage tracks → *Add sub-track* → School year.
2. He enters "School", 2026–27, Sep → Jul, 10 per week and 39 weeks, then taps *Save sub-track* with no ground. The daily target drops.
3. In October he opens School 2026–27 → *+ Add ground*, ticks Berachos perakim 1–3, and taps *Add 3 perakim to School*.
4. Those perakim grey out on the main track, and the main track's schedule and today's tasks recompute. The daily target doesn't move, because the ground is within capacity.
5. **Climax:** if the rate can't finish the ground by July, the Dashboard shows "School may not reach Berachos perek 3 before July. About 40 mishnayos will return to home learning." (This deviates from the PRD example string by decision; flag to PM.)
6. In July the sub-track ends and moves under *Ended sub-tracks*. Unfinished ground returns to its original main-track place.
7. He taps *Add next year (2027–28)*. The form is prefilled, and he saves.
- **Edge case:** Rav Cohen's Rebbe track also holds Berachos. Each track keeps its own position (FR-13), and the ground picker tags the ground "Rebbe · In use".

### UJ-4. Friday afternoon to Sunday: shabbos without logging.
Protagonist: **Yehuda**. → [`09`](mockups/09-erev-mobile.html) (erev), [`10`](mockups/10-catch-up-mobile.html). This journey deviates from the PRD UJ-4 path by product-owner decision 2026-10-01; the PRD amendment is pending.
1. On erev shabbos the Learn tab shows the erev banner and "Planned for Shabbos". He can still tick anything live.
2. Ten minutes before candle-lighting, the existing full-screen lock overlay covers the app on every device. Nothing is readable or tappable, and the on-track status is frozen.
3. Ten minutes after tzeis the overlay dismisses itself. The catch-up card appears at the top of the Learn tab, and one reminder notification fires.
4. The card asks: "Shabbos · 14 mishnayos planned — learnt them all?"
5. **Climax:** he taps *Yes, all of it*. The ticks are dated to shabbos (*catch-up dated*), not to when he tapped, and his streak is intact.
6. Alternatively he taps *Adjust…*, unticks Beitzah 3:3 in the Rebbe group, and taps *Record 13 mishnayos*.
7. Yom tov works the same way, including a three-day yom tov + shabbos, with one Adjust section per locked day.
- **Failure path:** if the card expires unused, the lock day gets no streak credit, though learning can still be recorded by free tick. If zmanim are unavailable, a conservative fallback lock applies and the parent is prompted for location afterwards.

### UJ-5. First run: sub-tracks are mentioned, not set up.
Protagonist: **Yehuda's father** (a new family). No mock.
1. Onboarding runs as it does today: main track and goal.
2. One onboarding step carries an `Info note` saying school and rebbe sub-tracks can be added later from Settings → Manage tracks. The exact copy is an open question.
3. There is no sub-track step and no prompt.
4. **Climax:** a family that never needs sub-tracks never sees them again: no Learn section, no Dashboard cards, no nudges. A family that does knows where they live.

### UJ-6. One mishna, a whole life.
Protagonists: **Yehuda**, then **his father**. → [`13`](mockups/13-mishna-history-mobile.html), [`14`](mockups/14-lifetime-report-mobile.html)
1. Yehuda taps Berachos 1:1 in any tree.
2. Mishna history shows "Learnt · נלמד" and "5 times learnt", then events newest first:
   - School · chazara
   - Rebbe · chazara
   - Home · chazara
   - "7 Sep 2026 (Shabbos, caught up)" · catch-up
   - *Before tracking* · Home
3. **Climax:** "Repeats never add to goal progress — they're kept here as your record." Goal progress is unchanged, and the record is complete.
4. His father opens Progress → Lifetime → Report and sees Distinct, Learning events, By source, School years and Per-source pace. He taps *Export PDF*.
5. The system share / save sheet opens with the PDF.
- **Failure path:** if the PDF can't be generated or saved (offline data still syncing, storage full, or a generation error), a floating snackbar says "Couldn't export the report — try again." `[ASSUMPTION copy]` with *Retry*. The report stays on screen. Nothing partial is shared.
- **Edge case:** events from a deleted track keep its name, and voided events are excluded from the count.

## Open Questions

None of these is silently resolved above. All are non-blocking for UX handoff (decision 2026-10-01).

1. **Lock fallback prompt.** What should the parent location prompt say after a fallback lock (zmanim or location unavailable, or high latitude) (FR-23)?
2. **Rejected-sync copy.** Should the snackbars in § State Patterns › Per surface be confirmed, or should rejected events land in the catch-up card instead?
3. **Catch-up for sub-tracks.** How is a flagged sub-track's "planned" amount for the lock derived, and how does *Adjust…* allocate across up to 3 days?
4. **Catch-up reminder copy.** The timing is decided (once, when the card becomes available); the wording is not (FR-25).
5. **Erev window start.** When does the planned list first appear, and what is the banner copy?
6. **Correction entry point.** Where do child, parent and tutor correct an older event (FR-4)? Mishna history is assumed. Does the child get re-dating there within the catch-up window?
7. **Free-tick date and source control (FR-3).** Which control edits the initial event date, and how is *Before tracking* chosen in the source-once dialog?
8. **Onboarding mention.** What is the copy, and which step carries it (FR-4a, UJ-5)?
9. **Hebrew reference line.** The mocks show English and Hebrew-script references together. Is the secondary Hebrew line always shown, or only when Hebrew Terms is on?
10. **Tutor surfaces.** Does *My talmidim* replace or extend the existing `ManageGrantsScreen` (`/tutor/my-grants`)? Are the filter tabs (needs-attention / on-track) wanted?
11. **Tutor access.** Does the tutor see shortfall warnings (FR-21 names the parent) and the lifetime report?
12. **Per-source report.** What on/off-target metric and window should FR-32 use? Are the mock's "On pace" / "Steady" labels wanted?
13. **Siyum** on backfill, correction or un-completion (PRD §8.1, FR-17).
14. **Existing-user migration.** Should existing users be prompted for study days or goals when they first add a sub-track (PRD §8.1)?
15. **Row order.** What order do sub-track rows take on Learn (hub order assumed)? Is the hub's *Reorder* action (tablet mock) in scope?
16. **Ended-track label.** "Ended", or the mock's "Completed / Archived"?
17. **Tablet.** Breakpoints, and rail visibility in parent-elevated mode (assumed to mirror the bottom navigation).
18. **PRD amendment.** FR-23 / FR-24 / UJ-4 must be amended to match the lock decision, and the UJ-3 / FR-21 example string flagged (owner: PM).
