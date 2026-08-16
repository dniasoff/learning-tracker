# Product Rules — Learning Tracker

**Purpose:** This is the **canonical, maintained list of product rules** that govern what the app does and what its UI must (and must not) say. Every rule here is load-bearing — surfacing in the audit findings, breaking when ignored, and explicitly flagged by the owner across multiple sessions.

**Maintenance:** When a new rule is established (in a session, by the owner, by an architectural decision), it MUST be added here. When a rule is changed or retired, this doc MUST be updated. This is the source of truth for both human contributors and AI agents.

**Companion specs and memories:**
- `docs/hebrew-terms.md` — full Hebrew Terms specification (referenced by Rule 1).
- `docs/_archive/superseded/tutor-mode-brief.md` — full tutor mode requirements (referenced by Rule 3).
- `docs/planning/tech-debt-remediation-plan.md` — implementation backlog.
- `_bmad/` and BMAD memory files — collaboration-style rules (how to work) live elsewhere; this doc is product/design rules (what to build).

---

## How to use this document

When implementing a screen, a widget, a copy change, a data model change, or a refactor — **read this document first**. If something you're about to write contradicts a rule, stop and revisit the design (or flag the rule for revision, with the owner's agreement).

When reviewing code or copy, audit against this document. The 2026-05-20 audits (`docs/_archive/superseded/ux-audit-2026-05-20-fix-plan.md`, `docs/_archive/superseded/ux-audit-2026-05-20-hebrew-terms-findings.md`, `docs/_archive/superseded/ux-audit-2026-05-20-copy-review.md`) are concrete examples of what an audit looks like and what it should catch.

---

## Rule 1 — Hebrew Terms boundary

**Full spec:** `docs/hebrew-terms.md` (authoritative; this section is summary only).

**Summary:**
- Two independent axes: **UI locale** (auto-detected `en` / `he`, no picker) and **Hebrew Terms mode** (binary: Hebrew script vs transliteration). They do **not** interact except as documented in §5 of the spec.
- Hebrew Terms is **binary** — there is no "translated" form. "English" mode means transliteration ("Chazara", not "Review"; "Daf", not "Page"; "Masechta", not "Tractate").
- **Default ON** (Hebrew script). Setting is **hidden in Hebrew locale** (no-op there).
- Structural strings (UI chrome, screen titles, button labels, generic words like "Streak", "Today", "Recent Activity", "Overall Knowledge", "Track Progress", "Lifetime", "Milestone", "Points") follow **UI locale only** — Hebrew Terms must **never** touch them.
- Domain terms (§6 catalog: chazara, daf, amud, perek, mishnah, seder, masechta, mishnayos, bavli, yerushalmi, chumash, nach, tanach, mishna berurah, mussar, mishneh torah, seder/masechta proper names, stage names, talmid chochom) are governed by Hebrew Terms.
- Provider name: `useHebrewTermsProvider`. Reads confined to `lib/core/labels/`, `lib/core/preferences/`, settings screens. Feature widgets receive resolved strings via `domainTermLabels(ref)`.
- A **third axis** exists: **Transliteration variant** (Ashkenazi / Sephardi), only meaningful and only visible when Hebrew Terms = English.
- Stage names re-render **live** on setting change (not frozen at track creation).

**Known drift to fix:** see `docs/hebrew-terms.md` §11 and the 14 audit violations in `docs/_archive/superseded/ux-audit-2026-05-20-hebrew-terms-findings.md`.

**Memory link:** `[[reference-hebrew-terms-spec]]`, `[[project-language-support]]`.

---

## Rule 2 — Calendar terminology and date format

- **Never** use the word "Gregorian" in user-facing copy. The Gregorian calendar is referred to as **"English"** (or "English calendar" where the noun form is needed).
- **Dates must be locale-aware.** US locale → `May 11, 2026`. UK / IL / AU / etc. → `11 May 2026`. **Never** ISO (`2026-05-11`) or numeric DMY (`11/05/2026`) in user-facing copy.
- Helper: `HebrewCalendarUtils.formatEnglishDate(date, locale: …)` wrapping `DateFormat.yMMMd(locale)`.
- Hebrew calendar dates (gematriya, `כ"ד אייר תשפ"ו`) follow the separate `_useHebrewCalendar` preference and are unaffected by this rule (it governs only the English-calendar display).
- Code identifiers (`gregorianToHebrew`, `dateType: 'gregorian'`, etc.) may stay as internal names — only **rendered copy** is covered by this rule.

**Memory link:** `[[feedback-calendar-terminology]]`.

---

## Rule 3 — Profile model: child and adult only

- The app has **two** profile types: **child** and **adult**. There is **no** "parent" profile — that label is a code-side artefact and must not appear in user-facing copy or new code.
- **Tutor is not a third profile type.** A tutor is an *adult account that has been granted access to one or more children in another family*. When a tutor switches *into* a tutored-child context, **they see the child's view** — the same dashboard, the same screens, the same UI the child sees. That is the entire UX premise of tutor mode.
- **Adults have no points.** Points are child-only.
- **Adults' top section** is different from the child's (different counters, no Current Balance card, no "Redeem Prizes" CTA, no points, no streak gamification). Exact shape TBD via Q-A in the fix plan.
- **Gating rule:** branch on `currentProfile.type == child` vs `adult`. When a tutor is active-as-tutored-child, `currentProfile` IS the child — the child branch lights up naturally. No separate "tutor view" code path exists or should be written.
- Tutor PIN, audit log, grant management, etc. are tutor-mode infrastructure but do not change the *view* a tutor sees while sitting in a tutored child's context.

**Memory link:** `[[project-profile-model]]`, `[[tutor-mode-planned]]`.
**Full spec:** `docs/_archive/superseded/tutor-mode-brief.md`.

---

## Rule 4 — Completion credit policy (three tiers + sentinel date)

| Source | Engagement (streak, points) | Track-learning tier (siyumim, reports, pace, recent activity, learn-data, dashboard counters) | Lifetime data | Date stamp |
|---|:---:|:---:|:---:|---|
| **Track learning – live** (real-time mark in the app) | ✅ | ✅ | ✅ | Real date (today) |
| **Track learning – bulk-mark in-track** (historical entries inside a track) | ❌ | ✅ | ✅ | **Sentinel date** (e.g. `1/1/2000`) |
| **Lifetime-mark** (lifetime-only) | ❌ | ❌ | ✅ | n/a |

> **Unifying rule (2026-05-21):** track-based learning *is* actual app learning. Every counter, chart, and report on the app's screens treats live mark + bulk-mark in-track as one combined source — **the only exceptions are points and streak**, which remain live-only because they reward real-time engagement. Bulk-mark items naturally fall outside finite "last 7 / 30 days" windows because of the sentinel date, but they are never filtered out by tier.
>
> The previous "Live learning" label is retired in user-facing copy in favour of "Track learning". The `CompletionSource.live` enum identifier is unchanged for now; only rule text and UI strings carry the rename.

- The **sentinel date is the mechanism** that lets bulk-in-track entries credit achievement/lifetime *without* leaking into recent activity, streak math, or "today's activity." Every date-keyed read must filter by date — that's where the rule enforces itself.
- Don't reinvent a parallel `is_bulk` boolean alongside the date; the date *is* the discriminator for date-keyed reads.
- `MarkCompletionUseCase` accepts a `CompletionSource ∈ {live, bulkInTrack, lifetimeOnly}` discriminator. For `bulkInTrack`, the use case writes the sentinel date (not `DateTime.now()`).
- Bulk-mark and lifetime-mark UI must always have **explicit copy** stating which counters this credits. Examples that meet the bar today (preserve these):
  - Bulk-mark wizard subtitle: *"These count toward siyumim and lifetime knowledge — but not toward your streak or points."*
  - Lifetime-marking subtitle: *"Items you've learned in your life, outside the app's tracks. Counted toward Lifetime Knowledge — not toward siyumim, streak, or points."*

**Memory link:** `[[completion-credit-policy]]`.

---

## Rule 5 — Pace tracks track learning only

- A track is **self-paced** — the user sets a target completion date.
- App computes **velocity required** = `(total_items − bulk_baseline) ÷ (target_date − track_start_date)`.
- App computes **actual velocity** = `track_learning_completions_since_track_start ÷ days_elapsed_since_track_start`.
- "Ahead / behind" compares those two **from day 1 of the track forward**.
- **Bulk-marked prior learning establishes the starting baseline** (where the learner is *today*) — it must **never** count as retroactive pace credit. Filtering naturally falls out of Rule 4's sentinel date: any pace read that filters `completedAt >= trackStartDate` excludes bulk entries.
- Day 1 with no track-learning completions must display *"On track"* or *"Just started"* — not "Ahead by X" and not "Behind by X." A grace window (1–3 days, TBD) is appropriate.
- The on-screen caption *"Pace tracks track learning only"* is correct and must stay.

**Memory link:** `[[completion-credit-policy]]` (the underlying mechanism).
**Active bug:** see `docs/_archive/superseded/ux-audit-2026-05-20-fix-plan.md` Stream F.

---

## Rule 6 — Offline-first everywhere

- The **entire app** must function fully offline. Not a per-feature decision — the baseline.
- **Reads come from Drift, never directly from Firestore.** Firestore feeds the sync engine; the sync engine writes to Drift; the UI reads Drift.
- **Writes go to Drift first, then enqueue for sync.** Never block UI on Firestore acknowledgment.
- **No "you must be online" gates** on features that can function locally. Examples that must work offline: marking completions (live + bulk), viewing dashboards / progress / recent activity, browsing curricula, navigating tracks, viewing siyumim, all stats and counters, settings, profile switching.
- **Sync state is informational, not blocking.** A "syncing…" / "offline" indicator is fine. A spinner that prevents interaction is not. Stale data is OK; missing data is not.
- **Genuinely online-only flows** are the narrow exception and must degrade gracefully with a clear offline message: initial sign-in, password reset, fetching a Firebase Remote Config update, the very first sync after install. Anything else is suspect.
- The `initialSyncCompleteProvider` gate is allowed only for the **very first** launch after install. After that, the app must be fully usable from local data with no network.
- Reviews and tests must verify offline behaviour. Disconnect the device or use the emulator's offline mode when reviewing any screen.

**Memory link:** `[[offline-first-everywhere]]`.

---

## Rule 7 — No track types

- The app has **no track types** and no track categories. A track is a track.
- There is **no** "Personal" / "Standard" / "Custom" / "Default" / "Manual" type label, badge, chip, or column **anywhere** in the UI.
- Spotted-and-flagged 2026-05-20: `אישי: 57` (Hebrew for "personal") rendering as a per-masechta counter inside the Mishnayos breakdown — that's a regression to a removed concept and must come out.
- Any code path that branches on `trackType` / `track.type` / `TrackType` / `TrackCategory` is suspect: either delete the branch or refactor away the concept.
- If a `trackType` column or field still exists in the data layer, it's tech debt — but the UI must not surface it regardless.
- Tutor-mode vs self vs anything-else is not a track type; it's the same track viewed under different `currentProfile` contexts (see Rule 3).
- Don't reintroduce track types as a back-door discriminator for completion sources — that's what `CompletionSource` is for, and it lives at the completion record, not the track (see Rule 4).

**Memory link:** `[[no-track-types]]`.

---

## Rule 8 — Chazara is per-track-configurable; render only when enabled

- Chazara (review) is a per-track configuration. Not every track has chazara enabled.
- **Any UI surface** — count, label, column, badge, stage row, progress bar, scheduler entry — that references chazara **must be gated on `track.chazaraEnabled`** (or the equivalent configuration).
- If the track doesn't have chazara, the chazara reference is **removed entirely** — not zeroed-out, not greyed-out, not "0 / 0". Gone.
- Stage rows: a non-chazara track shows the Learn stage only. No `Chazara 1 / 2 / 3` rows, no placeholders.
- Total items math: `total = unique_items_count` for a non-chazara track. Do not multiply by `(1 + chazara_passes)` when chazara is off.
- Cross-track aggregates can still total chazara done across tracks-that-have-chazara, but should not present chazara as a universal metric.
- **Generalisable principle:** per-track configurable features (chazara today; scheduling, daily goals, rewards, study-days, etc.) should only surface their UI when their configuration is enabled. Don't render placeholder UI for features the track doesn't have.

**Memory link:** `[[chazara-conditional-rendering]]`.

---

## Rule 9 — Program enrolment window and back-date overdue rule

- Program (curriculum / track) **start date** is constrained to `[today − 30, today]` uniformly. The user cannot start a program more than 30 days in the past, and cannot pre-schedule a program for a future start.
- **Back-dating** (start date in the past) MUST generate scheduled catch-up tasks dated **in the past**, which surface as **overdue** to the user. The system never silently absorbs back-dated time as "free progress."

**Memory link:** `[[program-enrolment-window]]`.

---

## Open product decisions (not yet rules — pending owner)

These appear in the fix plan's "Open questions" section. When decided, fold them in here.

- ~~**Q-S1.**~~ **Decided 2026-05-20.** `siyum` / `siyumim` is a **domain term** governed by Hebrew Terms (same category as chazara — no English translation exists). Added to `docs/hebrew-terms.md` §6. Proper-name siyumim (Siyum HaShas, etc.) are also domain terms.
- ~~**Q-A.**~~ **Decided 2026-05-21.** Adult dashboard top section = **3 counters, no points** (streak · siyumim · lifetime items). Same `ProgressTierCounterRow` with `showPoints: false`. No separate adult metrics or adult-specific counter set.
- ~~**Q-W.**~~ **Decided 2026-05-21.** Weekday header format = **3-letter** (`Sun Mon Tue Wed Thu Fri Sat`). Matches calendar convention used elsewhere in the app.
- ~~**Q-IA.**~~ **Decided 2026-05-21.** Recent Activity "All Time" = **Totals summary card only**. Shows total limudim, total chazaros, total active days — a simple stats card. No per-day calendar grid for the All Time range. Last 7 / Last 30 keep the existing day-cell calendar.
- **Q-O.** Definitive list of online-only flows beyond sign-in / password reset / first sync / remote config refresh.
- ~~**Q-G.**~~ **Decided 2026-05-20.** Pace grace window = **1 day** (days 0 and 1 of a track). From day 2 onward the ahead/behind comparison is live. `kPaceGraceWindowDays = 1` in `pace_calculator.dart`.
- ~~**Q-Term.**~~ **Resolved (AUD-docs-16, confirmed shipped 2026-07-13).** Code-side rename is complete: `UserMode` no longer exists in `lib/`, replaced by `ProfileMode` (`lib/core/domain/value_objects/profile_mode.dart`) with `child`/`adult` values, DB-enforced via a `CHECK (mode IN ('adult','child'))` constraint on `learner_profiles` (schema v26).

---

## Adversarial rules (collaboration & workflow)

The following are workflow/collaboration rules — captured in agent memory and elsewhere, not in this document — but linked here for awareness:

- Listen before troubleshooting (`[[listen-before-troubleshoot]]`).
- Incremental over rewrites — refactor under a test net (`[[incremental-over-rewrites]]`).
- Minimal proportionate solutions (`[[feedback-minimal-scope]]`).
- Fix in-run, don't defer (`[[fix-dont-defer]]`).
- Code is the source of truth (`[[code-is-source-of-truth]]`).
- All work on `dev`; no feature branches or worktrees (`[[no-feature-branches]]`).
- Pre-launch — no live users, big-bang refactors are safe (`[[pre-launch-status]]`).
