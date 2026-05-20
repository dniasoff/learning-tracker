---
title: Progress Information Architecture — Redesign Proposal
date: 2026-05-20
author: Sally (UX Designer, BMAD) with Daniel
status: Proposal — awaiting Daniel's sign-off before implementation
related:
  - B1 three-tier completion credit policy (`completion_source.dart`)
  - feedback: lean hard on Hebrew vocabulary in English UI; respect existing Hebrew Terms toggle for script
  - tutor-mode-brief — same data surfaces will be reused for tutor's read-only view
---

# Progress IA Redesign — Concrete Proposal

## Why this exists

The Progress tab and its descendants currently expose **four conceptually different questions** behind **one undifferentiated vocabulary**. The result: a user with 1,336 bulk-imported mishnayot sees `1336 ITEMS LEARNED · 1336 TASKS DONE · 0 DAY STREAK · 0 siyumim` on the same screen and reasonably concludes the app is broken.

The underlying data model (B1 three-tier credit policy: **engagement / achievement / lifetime**) is correct. The UI never tells the user that the data has tiers. This proposal makes the tiers visible — by structuring the IA and the vocabulary around them.

## The four questions, mapped to three lenses

| User's actual question | Tier | Lens (this proposal) |
|---|---|---|
| "What did I do today / this week?" | engagement (live only) | **Recent Activity** |
| "What have I completed (siyumim, milestones) in my tracks?" | achievement (live + bulkInTrack) | **Siyumim & Milestones** |
| "What have I ever learned (including outside-track historical knowledge)?" | lifetime (all three sources) | **Lifetime Knowledge** |
| "How am I doing right now in this track?" | per-track achievement % | **Dashboard + Track screens** |

Owner-confirmed scoping (2026-05-20):
- **Siyumim & Milestones** is strictly track-scoped. Pure lifetime-only imports do **not** generate siyumim.
- **Lifetime Knowledge** includes everything — live, bulkInTrack, *and* lifetimeOnly historical imports outside of any track.

## Canonical vocabulary (lean hard on Hebrew)

Used everywhere in the app. The existing `useHebrewTermsProvider` toggle controls **script** — English-default uses the transliterated word; toggle-on uses the Hebrew letters.

| Concept | English-default (lean hard) | Hebrew (toggle on) | Note |
|---|---|---|---|
| Mark stage 1 (initial study) of one item | **Limud** | לימוד | The first encounter |
| Mark stage 2+ (review) of one item | **Chazara** | חזרה | Each review = one chazara |
| Total stage-marks ever (lifetime sum) | **Total chazaros** | חזרות | Every event counts |
| Unique items ever touched | **Items learned** | פריטים נלמדו | Distinct sefariaRefs |
| Finish all stages of a unit (e.g. masechta) | **Siyum** | סיום | Achievement milestone |
| Multiple siyumim earned over time | **Siyumim** | סיומים | Plural |
| Generic achievement (siyum + seder-complete + curriculum-complete) | **Milestone** | הישג | Umbrella |
| Today's learning activity | **Today** | היום | — |
| Consecutive active days | **Streak** | רצף | engagement |
| Engagement lens screen | **Recent Activity** | פעילות אחרונה | live only |
| Achievement lens screen | **Siyumim & Milestones** | סיומים והישגים | track-scoped |
| Lifetime lens screen | **Lifetime Knowledge** | ידע כולל | all sources |
| Per-track progress percentage | **Track progress** | התקדמות מסלול | per track |

**Terms to retire:** `Tasks Done`, `Items Learned` (as a stat-card label — see new IA), `Completions Over Time`, `Daily Activity` (as a separate tag), `Cumulative Progress` (as a separate chart title — fold into Recent Activity), `Completion History` (chronological list — drop), `Tasks Done screen`, `Lifetime View` (as a separate label — folds into Lifetime Knowledge).

## New IA at a glance

```
HOME (bottom-nav)
└── Dashboard
    ├── Active tracks (each: cycle %, lifetime %, today/overdue)
    ├── Streak chip → Recent Activity
    └── Today's plan

LEARN (bottom-nav)                — content browser (unchanged)

PROGRESS (bottom-nav)
└── Progress hub
    ├── Top counters (one per lens — three icons, three numbers)
    │      🔥 N-day streak       (engagement)
    │      🏆 N siyumim earned   (achievement)
    │      📚 N items in lifetime (lifetime)
    │
    ├── Lens tile: 🔥 Recent Activity    →  RecentActivityScreen
    ├── Lens tile: 🏆 Siyumim & Milestones → SiyumimScreen
    ├── Lens tile: 📚 Lifetime Knowledge  →  LifetimeKnowledgeScreen
    │
    └── Per-track section (compact list — taps go to TrackDetail)

SETTINGS (bottom-nav)             — unchanged + Lifetime Marking input
```

Three lenses. Three screens. No more duplicated, conflicting nouns.

---

## Screen-by-screen specification

For each screen: **purpose**, **data tier**, **wireframe**, **what changes**.

### 1. Dashboard (refined — surface a single number per lens)

**Purpose:** Glance — "where am I right now". Today's plan + per-track status.

**Wireframe (adult mode — 3 top counters):**
```
┌─────────────────────────────────────────────┐
│  Hi Daniel                                  │
│                                             │
│  🔥 6-day streak    🏆 4 siyumim   📚 1336  │
│  ─────────────────────────────────────────  │
│                                             │
│  TODAY                                      │
│  3 of 5 tasks done • across 2 tracks        │
│                                             │
│  Mishnayos             ━━━━━━━━━━ 31%       │
│  Lifetime: 33%  •  Today: 1/3 done           │
│                                             │
│  Bavli                 ━━━━ 12%             │
│  Lifetime: 12%  •  Today: 2/2 done ✓        │
└─────────────────────────────────────────────┘
```

**Wireframe (child mode — 4 top counters):**
```
┌─────────────────────────────────────────────┐
│  Hi Daniel                                  │
│                                             │
│  🔥 6   🏆 4    📚 1336    ⭐ 1,250 pts     │
│  ─────────────────────────────────────────  │
│                                             │
│  TODAY                                      │
│  3 of 5 tasks done • next reward at 1,500   │
│                                             │
│  Mishnayos             ━━━━━━━━━━ 31%       │
│  ...                                        │
└─────────────────────────────────────────────┘
```

**Changes:**
- **Top counter row** is the consistent tier header used everywhere — Dashboard, Progress hub, and (read-only) tutor mode all use the same row.
- **Adult mode:** three counters (streak / siyumim / items). **Child mode:** adds a fourth — ⭐ points.
- Drop "TASKS DONE" stat card entirely (it duplicated "ITEMS LEARNED" data; total-chazaros is now part of Lifetime Knowledge).
- Per-track section uses two labels: **Track progress** (current cycle, engagement+achievement) and **Lifetime** (lifetime-tier %).

---

### 2. Progress hub (the bottom-nav landing page — restructured)

**Purpose:** Entry point to the three lenses + a quick per-track digest.

**Wireframe (adult mode):**
```
┌──────────────────────────────────────────────┐
│  Progress                                    │
│                                              │
│  🔥        🏆         📚                     │
│  6-day     4 siyumim  1336 items            │
│  streak    earned     in lifetime            │
│                                              │
│ ┌──────────────────────────────────────────┐ │
│ │ 🔥  Recent Activity                    > │ │
│ │     Streak, today, last 7/30 days        │ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ 🏆  Siyumim & Milestones               > │ │
│ │     4 siyumim across your tracks         │ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ 📚  Lifetime Knowledge                 > │ │
│ │     1,336 items ever learned             │ │
│ └──────────────────────────────────────────┘ │
│                                              │
│  YOUR TRACKS                                 │
│  ─────────────                               │
│  Mishnayos    31%  ━━━━━━━━━━━━━━━           │
│  Bavli        12%  ━━━━━                     │
└──────────────────────────────────────────────┘
```

Child mode: same layout, with a fourth ⭐ counter in the top row (matching Dashboard). The three lens tiles are identical.

**Changes:**
- The 4-stat grid (ITEMS LEARNED · TASKS DONE · DAY STREAK · ACTIVE TRACKS) is **replaced** by the three lens counters + three lens tiles + per-track list.
- ACTIVE TRACKS as a stat goes away (tracks are listed below — counting them is redundant).
- The current "Learning Lifetime" tree on this hub becomes the body of the Lifetime Knowledge screen — not crammed onto the hub.

---

### 3. Recent Activity screen (was: Progress Charts)

**Purpose:** Engagement-tier lens. *"What did I do recently?"* Strictly live completions.

**Wireframe:**
```
┌────────────────────────────────────────────────┐
│  ←  Recent Activity                            │
│                                                │
│  [Last 7 days]  [Last 30 days]  [All time]    │
│  [All] [חומש] [נ"ך] [תנ"ך] [משניות] ...        │
│                                                │
│  🔥 STREAK                                     │
│  6 days · Best: 14 days                        │
│  ┌──────────────────────────────────────────┐  │
│  │  M  T  W  T  F  S  S                     │  │
│  │  ●  ●  ●  ●  ●  ─  ●  (this week)        │  │
│  └──────────────────────────────────────────┘  │
│                                                │
│  LIMUDIM & CHAZAROS                            │
│  Last 30 days · live learning only             │
│  ┌──────────────────────────────────────────┐  │
│  │     ▌  ▌                                 │  │
│  │  ▌  ▌  ▌  ▌    ▌▌                        │  │
│  │  ─────────────────────────────           │  │
│  └──────────────────────────────────────────┘  │
│                                                │
│  CUMULATIVE  (live learning only)              │
│  ┌──────────────────────────────────────────┐  │
│  │                          ╱─              │  │
│  │                    ╱────                 │  │
│  │             ╱─────                       │  │
│  │       ╱────                              │  │
│  └──────────────────────────────────────────┘  │
│                                                │
│  ⭐ POINTS  (child mode only)                  │
│  120 this week                                 │
└────────────────────────────────────────────────┘
```

**Changes:**
- Single screen replaces "Progress Charts" + "Streak History".
- Every chart on this screen is **live-only** (engagement tier). The tag "DAILY ACTIVITY" goes away — the *screen itself* names the tier.
- Charts add a one-line subtitle: *"Live learning only — bulk-marked items appear under Lifetime Knowledge."* Eliminates the "0 streak with 1336 completions" confusion.
- "All time" range is bounded to the user's first live completion (not Jan 1, 2000) — eliminates the 9,600-day Dart loop performance bug.
- Labels: chart now reads "Limudim & Chazaros" (or Hebrew script with toggle on); the cumulative chart is its own card titled "Cumulative" (no "Progress" suffix — context is clear).

---

### 4. Siyumim & Milestones screen (was: Learning Journey)

**Purpose:** Achievement-tier lens. Track-scoped milestones. *"What have I completed?"*

#### Three celebration levels per curriculum

A siyum on a single unit deserves recognition. A siyum on an aggregate (a whole seder, or a whole book of Tanach) deserves a *bigger* recognition. Completing an entire curriculum is the biggest of all. The redesign exposes **all three** as separate, counted, celebrated events. They are additive — completing Seder Zeraim awards 11 masechta siyumim *and* 1 seder siyum.

The exact level names come from each curriculum's hierarchy. The rule: every curriculum exposes its two most coarse hierarchy levels as siyum levels, plus a top-level "curriculum complete" celebration.

| Curriculum | Level-2 siyum (unit) | Level-1 siyum (aggregate) | Curriculum siyum (top) |
|---|---|---|---|
| Mishnayos | Siyum Masechta | Siyum Seder | Siyum HaMishnayos |
| Bavli | Siyum Masechta | Siyum Seder | Siyum HaShas |
| Yerushalmi | Siyum Masechta | Siyum Seder | Siyum HaYerushalmi |
| Mishna Berurah | Siyum Siman | Siyum Chelek (if exposed) | Siyum Mishna Berurah |
| Mishneh Torah | Siyum Hilchos | Siyum Sefer | Siyum Mishneh Torah / HaRambam |
| Chumash | Siyum Sefer (Bereishis…) | — | Siyum Chumash / HaTorah |
| Nach | Siyum Sefer | — | Siyum Nach |
| Tanach | Siyum Sefer | — | Siyum Tanach |
| Mussar | Siyum Sefer | — | Siyum Mussar / per-author |

Some curricula only have two levels exposed in content data (Chumash → sefer; Nach → sefer; Mussar → sefer). For those, the screen shows two tiers: per-sefer siyumim + curriculum siyum. For Mishnayos/Bavli/Yerushalmi which expose the seder→masechta hierarchy, the screen shows three tiers. Detection follows existing `_detectMilestones` logic in `journey_providers.dart`; new vocabulary is presentation-only.

#### Wireframe

```
┌────────────────────────────────────────────────┐
│  ←  Siyumim & Milestones                       │
│                                                │
│  YOUR SIYUMIM                                  │
│  ──────────────                                │
│   2  curriculum-level siyumim                  │
│   2  seder-level siyumim                       │
│  23  masechta/sefer-level siyumim              │
│                                                │
│  [ By curriculum ]   [ Timeline ]              │
│                                                │
│  📘 MISHNAYOS                                  │
│  ─────────────                                 │
│  🏆 Siyum Seder Zeraim                      ▾ │
│      All 11 masechtos complete                 │
│        Berachos · Peah · Demai · Kilayim       │
│        Shevi'is · Terumos · Ma'asros …         │
│  🏆 Siyum Seder Moed                        ▾ │
│      All 12 masechtos complete                 │
│                                                │
│  📕 BAVLI                                      │
│  ─────────────                                 │
│  🏆 Siyum Masechta Berachos                    │
│      4 May 2026                                │
│                                                │
│  📕 CHUMASH                                    │
│  ─────────────                                 │
│  🏆 Siyum HaTorah                           ▾ │
│      All 5 sefarim complete                    │
│        Bereishis · Shemos · Vayikra · Bamidbar │
│        Devarim                                 │
└────────────────────────────────────────────────┘
```

#### Display rules

- **Hierarchy-aware grouping** — within each curriculum, list the **highest-level** achievement first. Lower-level achievements that *roll up into* a higher one are collapsed inside it (expand chevron shows the contained units). A masechta siyum that's *not* yet part of a complete seder shows as a standalone row.
- **Curriculum-complete** is the top-most card for any curriculum that has one — visually distinguished (e.g. gold border / larger badge).
- **No provenance label** — a siyum is a siyum. The screen does not distinguish "live" from "via bulk-mark". The user knows what they did.
- **Counters at the top** are by level (curriculum / seder / masechta or sefer) — three numbers, not one. Aggregates educate the user that there are multiple levels of achievement.
- **Existing toggle** between "By curriculum" (grouped) and "Timeline" (chronological) is preserved. Timeline mode sorts by `achievedAt` descending and flattens the hierarchy.

#### Source of data

- Siyumim are derived from `learning_ledger` entries — the existing append-only achievement log. The B1 gate fix (Task #1) ensures `bulkInTrack` completions also populate this ledger, so bulk-marked sederim correctly produce siyumim post-fix.
- Per the policy: siyumim are **track-scoped** (live + bulkInTrack). Pure lifetime-only marks do NOT produce siyumim — they live only in Lifetime Knowledge (see #5).
- Detection logic per curriculum is already in `CompletionDetectionService` (level-2 unit) and `_detectMilestones` in `journey_providers.dart` (level-1 aggregate and curriculum). The redesign uses what's already there; the change is purely presentation (vocabulary + grouping + counter).

---

### 5. Lifetime Knowledge screen (merges: Items Learned + Lifetime View)

**Purpose:** Lifetime-tier lens. *"What have I ever learned, in all my life, across any source?"*

**Wireframe:**
```
┌────────────────────────────────────────────────┐
│  ←  Lifetime Knowledge                         │
│                                                │
│  📚 1,336 ITEMS LEARNED                        │
│  Across 2 curricula · 2,142 total chazaros     │
│                                                │
│  [ All sources ◉ ]  [ Track learning only ○ ]  │
│                                                │
│  📘 MISHNAYOS              31.87% (1336/4192)  │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│   ● זרעים                  Bulk-marked         │
│   ● מועד                   Bulk-marked         │
│   ○ נשים                                       │
│   ○ נזיקין                                     │
│   ○ קדשים                                       │
│   ○ טהרות                                       │
│                                                │
│  📕 BAVLI                  12% (X of Y dapim)  │
│  ━━━━━━━━━━━━━━━━                              │
│   ● ברכות                  Live · 5 chazaros   │
│   ○ ...                                        │
│                                                │
│  ┌────────────────────────────────────────┐   │
│  │  + Add items I learned previously       │   │
│  │    (Lifetime Marking)                   │   │
│  └────────────────────────────────────────┘   │
└────────────────────────────────────────────────┘
```

**Changes:**
- One screen replaces *both* Items Learned (track-only) and Lifetime View (all sources) — they're the same tree, the **toggle** picks the data source.
- Default "All sources" answers Daniel's lifetime-includes-non-track-bulk requirement.
- Each leaf node shows **how** it entered: "Bulk-marked" (bulkInTrack), "Live · N chazaros" (live completions), or "Lifetime · imported" (lifetimeOnly).
- Total chazaros surfaced at the top — replaces the "TASKS DONE: 1336" card on the old Progress hub. Counts every event, not unique refs.
- Inline CTA to Lifetime Marking (the existing settings screen). Today that screen is hidden in Settings; surfacing it here makes the "I learned this years ago" workflow discoverable.

---

### 6. Curriculum Progress screen (relabel + small additions)

**Purpose:** Per-curriculum view (taps from track list or curriculum chip). Mostly unchanged.

**What changes:**
- Pace indicator (existing) gets a clarifying caption: *"Pace tracks live learning only."*
- "Overall Stats" card splits into two compact rows: **Track progress** (achievement) and **Lifetime** (lifetime). Mirrors the dashboard's labels.
- Breakdown-by-level uses the new vocabulary in subtitles ("N chazaros" instead of "N completions").

---

### 7. Track Detail screen (relabel only)

**Purpose:** Per-track view. Mostly unchanged.

**What changes:**
- Header shows two progress numbers explicitly labelled: **Track progress: 31%** (achievement, since track activation) and **Lifetime: 33%** (lifetime tier).
- "Mark complete" buttons remain; they always fire **live** completions (the only path that credits engagement).
- For bulkInTrack inputs (track wizard): button text becomes "**Mark as previously learned**" — visually distinct so the user cannot conflate it with a live mark.

---

### 8. Bulk Mark screen (track wizard — relabel only)

**Purpose:** Onboarding/wizard input for "I already learned these" (bulkInTrack source).

**What changes:**
- Header: *"Mark items you've already learned"*. Subtitle: *"These count toward siyumim and lifetime knowledge — but not toward your streak or points."* Plainly states the B1 policy.
- Confirmation toast on save: *"X items marked as previously learned. They'll appear in Lifetime Knowledge and may unlock siyumim."*

---

### 9. Lifetime Marking screen (settings — relabel only)

**Purpose:** Settings-level input for "I learned this years ago, outside any track" (lifetimeOnly source).

**What changes:**
- Title: *"Mark lifetime knowledge"*.
- Subtitle: *"Items you've learned in your life, outside the app's tracks. Counted toward Lifetime Knowledge — not toward siyumim, streak, or points."*
- Discoverable from the Lifetime Knowledge screen CTA (see #5) as well as Settings.

---

### 10. Manage Tracks Hub (relabel only)

**Purpose:** Track list with per-track progress at a glance.

**What changes:**
- Each track row shows **Track progress** (achievement %) + tiny **Lifetime** badge (lifetime %).
- "Active Tracks" count card on the old Progress hub is removed; the count is now inferred from this list.

---

## Screens deleted entirely

| Screen | Why | Where its content lives now |
|---|---|---|
| **Tasks Done** | Same data as Items Learned, different (and inconsistent) header | "Total chazaros" counter on Lifetime Knowledge |
| **Completion History** (chronological event list) | The "raw event log" view is engineer-flavoured; users want activity (Recent Activity) or achievements (Siyumim). The chronological-timeline mode already exists inside the Journey screen. | Siyumim & Milestones (Timeline tab) for milestones; Recent Activity for raw daily activity bars |
| **Items Learned** + **Lifetime View** | Same data with one filter difference | Lifetime Knowledge (single screen with All-sources / Track-only toggle) |
| **Streak History** | Separate screen for the streak calendar — now inside Recent Activity | Recent Activity (top section) |

Net: **4 screens deleted, 2 screens renamed/restructured, 6 screens relabelled.** From ~12 progress surfaces to **~8**, with no overlap.

---

## Migration checklist (engineering work, in order)

The existing 7 fix-tasks remain valid — this redesign **builds on** them, doesn't replace them. The migration adds the IA work on top.

### Phase A — fix correctness + perf first (existing 7 tasks)
1. Task #1 — siyumim gate (creditsAchievement, not creditsEngagement)
2. Task #2 — chart tier → trackAchievement
3. Task #3 — "All Time" range capped to first live completion (not Jan 2000)
4. Task #4 — memoize FutureBuilders
5. Task #5 — `getStreakCalendar` SQL date filter
6. Task #6 — push `since`/`until` to SQL
7. Task #7 — siyum detection N+1 query

### Phase B — IA structure (5 tasks)
8. Replace Progress hub stat grid with top counters + three lens tiles + per-track list
9. New screen: **Recent Activity** (absorbs Progress Charts + Streak History; live-only data)
10. Restructure **Learning Journey** → **Siyumim & Milestones**: multi-level celebration detection (unit / aggregate / curriculum), level-split counters, hierarchy-aware grouping — no provenance label
11. New screen: **Lifetime Knowledge** (merges Items Learned + Lifetime View; toggle for all-sources vs track-only; surfaces total chazaros + Lifetime Marking CTA)
12. Delete obsolete screens + routes + l10n keys (Tasks Done, Completion History, old Items Learned, old Lifetime View)

### Phase C — vocabulary sweep (1 task)
13. Add new l10n keys (`limud`, `chazara`, `chazaros`, `siyum`, `siyumim`, `milestone`, `trackProgress`, `lifetimeKnowledge`, `recentActivity`, `totalChazaros`, `itemsLearned` new sense, plus per-curriculum siyum labels) in both `_en.arb` and `_he.arb`; wire `useHebrewTermsProvider` so the toggle swaps script not concept; sweep all call-sites for retired keys (`statCompletions`, `statUnitsDone`, `chartDailyActivity`, `lifetimeViewTitle`, `completionsOverTime`, etc.) and remove or repoint.

### Phase D — Dashboard refinement (1 task)
14. Dashboard: add top counter row (3 counters adult mode; 4 counters child mode with ⭐ points); restyle per-track rows with `Track progress` / `Lifetime` dual labels; remove "ACTIVE TRACKS" stat card.

### Phase E — per-screen relabel (4 tasks)
15. Curriculum Progress: split "Overall Stats" into Track Progress + Lifetime; update pace caption.
16. Track Detail: dual progress labels (Track progress / Lifetime); bulk-mark button text differentiation.
17. Bulk Mark wizard: copy update + post-save toast explaining tier credit.
18. Lifetime Marking screen: title + subtitle update; surface CTA on Lifetime Knowledge screen.

---

## Decisions (locked in 2026-05-20)

| # | Question | Decision |
|---|---|---|
| Q1 | Per-track section on Dashboard, Progress hub, or both? | **Both** — Dashboard for "right now", Progress hub for "all of them at once". |
| Q2 | Limud vs Chazara on bar charts — separate colours, or aggregated? | **Two-colour stacked bars.** Limud (initial learning) and Chazara (review) are distinct concepts; visualising them separately makes the chart more informative. Legend: Limud · Chazara. |
| Q3 | Show how each siyum was earned (live vs bulk-mark) on the Siyumim screen? | **No provenance label.** A siyum is a siyum, regardless of how it was earned. Don't dilute the celebration. |
| Q3b | (Replaces Q3) — multiple celebration levels per curriculum? | **Yes.** Each curriculum exposes 2–3 siyum levels: unit-level (e.g. Siyum Masechta), aggregate-level (e.g. Siyum Seder) where applicable, and curriculum-complete (e.g. Siyum HaShas). All three count, are listed, and are celebrated as distinct events. See screen spec #4. |
| Q4 | Tutor mode — which lenses visible? | **All three lenses, read-only.** The tutor's own audit log (per tutor-mode-brief) is a separate Tutor screen, not part of the Progress lenses. |
| Q5 | Child mode — Points as a 4th top counter, or only in Recent Activity? | **4th top counter in child mode.** Top counters become: 🔥 streak · 🏆 siyumim · 📚 items · ⭐ points (child only). Adult mode keeps the three-counter row. Points still has detail inside Recent Activity. |

---

## Success criteria (how we know this worked)

1. **No user can be confused by "1336 vs 1336"** — every metric the user sees is uniquely labelled with its tier.
2. **The B1 policy is discoverable** — at minimum on the Bulk Mark and Lifetime Marking screens; ideally hinted on the Lifetime Knowledge tier toggle as well.
3. **A user with only bulk-marked data sees siyumim** (after Task #1 fix), and understands they were earned via bulk-mark (provenance labels).
4. **Performance**: "All Time" Progress Charts page renders in under 500ms (after Task #3 + #6).
5. **Vocabulary consistency**: zero use of the retired terms in any screen, l10n file, or in-code label.

---

## Out of scope for this round

- Visual restyle (colour, spacing, typography) — proposal sticks to text and structure
- Stitch / Figma mockups — text wireframes only; defer to a `bmad-wds-page-designs` pass when needed
- New analytics events for the redesigned screens — covered when the screens are coded
- Charts library swap (still `fl_chart` or equivalent) — out of scope
- Tutor-mode tutor-side experience — covered separately in `tutor-mode-brief.md`; this proposal only ensures the same data tiers will reuse cleanly

---

## Hand-off

Once Daniel signs off (or amends), this doc becomes the source for:
- **Engineering tasks** — Phase B–E above become per-screen story tickets; Phase A is the existing 7-task list
- **l10n updates** — new keys and removed keys are explicit in Phase C
- A `bmad-wds-page-designs` pass (optional) — turn the ASCII wireframes into Stitch / Figma mocks for design review

Ready for review.
