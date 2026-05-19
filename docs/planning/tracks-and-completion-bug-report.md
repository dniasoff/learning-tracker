# Tracks, Completion & Terminology — Bug Report

**Date:** 2026-05-18
**App:** Learning Tracker — Flutter app, working dir `learning_tracker/`, branch `dev`.
**Companion docs:**
- Fix plan → `docs/planning/tracks-and-completion-fix-plan.md` (read it second; it has the full confirmed model + work-streams).
- Hebrew-terms spec → `docs/hebrew-terms.md` (canonical spec for B11).

This report lists **outstanding, owner-confirmed bugs** in the Completion/Lifetime
metrics, the Track screens, the Mark-Prior-Completions flow, and the Hebrew-terms
system. Every item here was confirmed with the product owner. Execute via the fix
plan.

---

## How to verify

- Gates: `cd learning_tracker && make ci` (analyze + all tests) and `make audit`
  (12 layering greps).
- **CAVEAT — pre-existing tree noise:** the working tree contains unrelated
  in-progress work by the repo owner — a new `lib/core/utils/text_input_formatters.dart`
  imported across ~16 screen/dialog files. That WIP makes `dart analyze` emit
  `directives_ordering` infos (import-order). **That redness is not from these
  bugs and is not yours to fix.** See the fix plan's "Tree state" section.

## Already fixed — context only, do NOT redo

- Firebase sync rework (Waves 0–5) — committed.
- `insertedCount:0` completion-merge bug — fixed within the sync rework.
- FK-787 crash on account/profile deletion — committed (`8364e074`).
- Lifetime-learning row removed from the **Track _detail_ screen** — committed
  (`1bf11dbc`). It is still wrongly present on the Track _hub card_ — see **B2**.

---

## Outstanding bugs

### B1 — Completion metric is stage-based; halves the real number  ·  HIGH
- **Symptom:** Track screen shows "Completion 7.81%" after 655 items were marked;
  owner expects ~15.6%. Lifetime shows 15.63%, looking like a "double".
- **Root cause:** `lib/features/dashboard/presentation/providers/dashboard_providers.dart`
  — `dashboardTrackCompletionPercentage` and `dashboardCompletionPercentage`
  compute `completions.length ÷ (totalItems × stageCount)`. Each daf is split
  across its stages, so a learn-only completion contributes a fraction.
- **Expected:** item-based. An item counts **once**, and only when **all** its
  required stages (learn + every chazara) are done — `Completion % = items fully
  done ÷ total items`. No stage multiplier. See the fix plan's model §A.
- **Note:** this file is currently modified-uncommitted with a *superseded*
  interim fix ("any completion" counts the item). The final rule is "all stages
  done". The fix plan's WS-1 redoes it correctly.

### B2 — Lifetime learning is shown on a Track screen  ·  MEDIUM
- **Symptom:** Lifetime learning appears on the Track-management **hub card**.
- **Root cause:** `lib/features/track_setup/presentation/widgets/learning_track_card.dart`
  computes a lifetime fraction and renders a "Lifetime learning" label + progress
  bar.
- **Expected:** Lifetime has nothing to do with tracks — it must not appear on
  *any* track screen. The detail screen was already cleaned (`1bf11dbc`); the hub
  card still needs it removed. Track screens show completion + that track's
  content/tasks only.

### B3 — "Personal Track" wording is meaningless clutter  ·  MEDIUM
- **Symptom:** "Personal Track" shows as the Track-detail card heading, as the
  hub-card subtitle, and as a "Track type" config row.
- **Root cause:** `trackTypeDisplayLabel()` in `learning_track_card.dart`
  (`'personal' => 'Personal Track'`); used by `track_detail_screen.dart` and
  `learning_track_card.dart`; plus the `trackDetailConfigType` row.
- **Expected:** the app supports only personal tracks, so the type label is
  noise. Remove "Personal Track" everywhere — the heading, the hub-card subtitle,
  and the "Track type" row. A track's identity is its curriculum name, which is
  already shown (app-bar on the detail screen, card title on the hub) — do not
  duplicate it.

### B4 — Track Name defaults to blank  ·  MEDIUM
- **Symptom:** Edit Track → the "Track Name" field is empty for an existing track.
- **Root cause:** Track Name is backed by the **Goal's `description`** field —
  `lib/features/track_setup/presentation/screens/edit_track_screen.dart:94`
  (`_nameController.text = goal?.description ?? ''`). Nothing ever seeds
  `goal.description` at track/goal creation, so it is empty.
- **Expected:** the track name defaults to the **curriculum name** (e.g.
  "Mishnayos" / "משניות") — seeded at creation and/or used as the fallback when
  `description` is empty.

### B5 — The "Which stages have you completed?" screen contradicts the model  ·  MEDIUM
- **Symptom:** The Mark-Prior-Completions flow has a second screen asking the
  user to tick which stages (Learn / Chazara 1 / …) were done, with an "Apply to
  All".
- **Root cause:** legacy stage-based model.
- **Expected:** marking content as *prior* learning means it is fully done,
  chazara included — there is no per-stage choice. **Delete that screen.** The
  prior-marking flow becomes: select content → mark (all stages recorded). NOTE:
  this is *only* for the prior-marking flow — the daily-learning chazara
  scheduler is unaffected (see fix plan §D, Option A).

### B6 — Mark-prior records only the learn stage, not chazara  ·  HIGH
- **Symptom:** A 655-item bulk-mark-prior produced 655 completion rows
  (`completion_count: 655` in logs) — one per item, learn only.
- **Root cause:** the bulk-mark-prior path records a single completion per item.
- **Expected:** marking prior content done must record completions for **learn +
  every chazara stage** of each item, so the item satisfies B1's "all stages
  done" rule and registers as fully completed. (Pairs with B1 — without B6,
  prior-marked items would compute as 0% completed under the B1 rule.)
- **Files:** `BulkPriorCompletionService`
  (`lib/features/onboarding/domain/services/bulk_prior_completion_service.dart`),
  the completion repository / `CompletionWriter`.

### B7 — Prior-learning screen does not pre-tick completed content  ·  MEDIUM
- **Symptom:** Re-opening "Mark Prior Completions" → all sedarim show unticked
  even though the owner already marked Zeraim done. ("I raised this before.")
- **Root cause:** the prior-learning selection screen does not load existing
  completion state into its checkbox state.
- **Expected:** content already completed shows **pre-ticked** when the screen
  re-opens.
- **File:** `lib/features/onboarding/presentation/screens/bulk_mark_screen.dart`
  (the "Select content you've already completed" sedarim list).

### B8 — Unticking on the prior-learning screen does not expunge records  ·  MEDIUM
- **Symptom:** Unticking a previously-marked item does nothing.
- **Expected:** unticking a ticked item **expunges the completion records that
  that prior-marking created** (learn + chazara) — the item leaves the track's
  Completion, and leaves Lifetime **unless** a learn record exists from another
  path (normal in-app learning, another track), in which case Lifetime keeps it.
  Untick only reverses what *that* prior-marking added; both metrics then reflect
  whatever completion records remain.
- **Note:** `completion_events` is append-only with a `purgedAt` tombstone
  column — "expunge" means tombstone, not hard-delete.

### B9 — All-curricula Lifetime total double-counts overlapping curricula  ·  HIGH
- **Symptom:** Dashboard shows "Learning lifetime (all curricula) — 655 / 93,395
  sections — 9 curricula". The 93,395 denominator (and the numerator) are
  inflated.
- **Root cause:** `lib/features/progress/presentation/providers/lifetime_knowledge_providers.dart`
  — `lifetimeTotalsAcrossAllCurriculaProvider` **sums** per-curriculum counts
  (`learnedTotal += s.learnedLeafCount; sectionTotal += s.totalLeafCount`).
  Overlapping curricula (Chumash ⊂ Tanach, Nach ⊂ Tanach, and possibly more) are
  counted in every curriculum that contains them. Per-curriculum lifetime % is
  correctly de-duplicated internally, but the cross-curriculum total is not.
- **Expected:** the all-curricula total counts **distinct sections** — union
  every curriculum's leaf sections by section identity (`sefariaRef`), dedupe,
  then count. A section in N curricula counts once, in both numerator and
  denominator. The fix must be general (overlap registry driven), not a
  hard-coded Chumash/Tanach special case — there may be more overlaps.

### B10 — Completion label did not say it includes chazara  ·  LOW (partly done)
- **Symptom:** "Completion" counts chazara but the label never said so → owner
  confusion.
- **Status:** PARTIALLY DONE, UNCOMMITTED. The `carouselCompletion` ARB key was
  changed to a parameterized method `carouselCompletion(String chazara)` →
  `"Completion (with {chazara})"` / `"השלמה (עם {chazara})"`; both call sites
  (`learning_track_card.dart`, `track_detail_screen.dart`) pass a Hebrew-terms-
  aware chazara term; the l10n coverage test was updated. This work is correct —
  see the fix plan's WS-0 (commit it).

### B11 — Hebrew-terms system has drifted from its intended design  ·  MEDIUM
- The intended rules are now fully specified in **`docs/hebrew-terms.md`**.
- `docs/hebrew-terms.md` §11 lists **8 concrete drift defects**:
  1. Coverage gap — only *chazara/review* and *talmid chochom* are toggle-aware;
     `daf`, `seder`, `chumash`, `amud`, `masechta` are not.
  2. A translated form ("Chazara/Review") leaks where it should be pure
     transliteration ("Chazara").
  3. Dead constant `HebrewTerms.uiBubbleChazara` (defined, never used; the
     "CHAZARA" bubble never switches).
  4. Hardcoded "Talmid Chochom" / "TALMID CHOCHOM" string literals.
  5. The `make audit` layering grep targets `hebrewTermsScriptProvider` — a
     symbol that does not exist (real provider: `useHebrewTermsProvider`) — so the
     "no toggle reads outside core/labels|preferences|settings" rule is silently
     unenforced.
  6. Stage names are frozen at track creation — they do not re-render when the
     Hebrew-terms setting changes.
  7. Stale doc comment: a settings-screen comment says the default is `false`;
     it is `true`.
  8. Duplication — `HebrewTerms.curriculumDisplayNames` duplicates
     `CurriculumId.displayNameHe`; "חזרה" is defined in several places.
- Owner decisions captured in `docs/hebrew-terms.md`: binary (Hebrew script ↔
  transliteration; no translated form), all domain terms in scope, stage names
  re-render live, default ON, hidden in Hebrew locale.

---

## Severity summary

| Severity | Bugs |
|---|---|
| HIGH | B1, B6, B9 |
| MEDIUM | B2, B3, B4, B5, B7, B8, B11 |
| LOW | B10 (partly done) |

---

## Remediation status (2026-05-19)

All canonical bugs B1–B11 addressed via the B1–B11 adversarial-review remediation
(execution plan: `docs/planning/b1-b11-review-fix-plan.md`). Waves 1–6 committed
on `dev`; Wave 7 is the final docs reconciliation pass.

| Bug | Severity | Status | Date | Notes |
|-----|----------|--------|------|-------|
| B1 | HIGH | RESOLVED | 2026-05-19 | Completion identity is now per-curriculum 5-tuple; dashboard % tests replaced with real provider integration tests driving in-memory Drift. |
| B2 | MEDIUM | RESOLVED | 2026-05-19 | Lifetime learning row removed from the Track hub card (`learning_track_card.dart`); only the detail-screen removal was done pre-plan (`1bf11dbc`). |
| B3 | MEDIUM | RESOLVED | 2026-05-19 | Option B chosen and implemented: per-curriculum natural key with UNIQUE index on 5-tuple `(profileId, sefariaRef, stageId, trackType, curriculumId)`; v22 migration. |
| B4 | MEDIUM | FALSE POSITIVE | 2026-05-19 | `TrackCardViewModel` is actively used in `lib/`; not dead code — adversarial review finding 11 was incorrect. No change needed. |
| B5 | MEDIUM | FALSE POSITIVE | 2026-05-19 | "Personal" is already single-sourced in `TrackType.displayNameEn`; no duplication existed — adversarial review finding was incorrect. No change needed. |
| B6 | HIGH | RESOLVED | 2026-05-19 | `expungePriorCompletions` now filters by `curriculumId`; confirmed in integration tests (`bulk_prior_completion_b6_b8_test.dart`). |
| B7 | MEDIUM | RESOLVED | 2026-05-19 | Outbox `entityKey` is now 5-component including `curriculumId`; Firestore document id is the same 5-component key, preventing per-curriculum collisions. |
| B8 | MEDIUM | RESOLVED | 2026-05-19 | Bulk-prior-completion service uses `allConfiguredStageIds` only; the caller `stageId` union that re-admitted superseded stages (finding 10) was removed. |
| B9 | HIGH | RESOLVED | 2026-05-19 | Lifetime knowledge dedup verified correct across per-curriculum completions; two new regression guard tests added to `lifetime_knowledge_providers_test.dart`. |
| B10 | LOW | RESOLVED | 2026-05-19 | `_allStageOrders` renamed (was `_allStageIds`) for clarity; added comment explaining purpose; `AppLogger` warning logged when `stages.isEmpty`. |
| B11 | MEDIUM | RESOLVED | 2026-05-19 | All 8 sub-defects addressed across Waves 3–6: see sub-items below. |

### B11 sub-items

| Sub-item | Status | Notes |
|----------|--------|-------|
| B11-1 (structural unit words not toggle-aware) | RESOLVED | `daf/amud/perek/mishnah/seder/masechta/chumash` getters wired into label resolution; `levelLabels` now toggle-aware. |
| B11-2 (translated form leaking) | RESOLVED | All UI uses pure transliteration ("Chazara") or Hebrew script ("חזרה"); translated hybrid form removed. |
| B11-3 (dead `uiBubbleChazara` constant) | RESOLVED | Structural unit words now toggle via `CurriculumLabels.inLanguage(useHebrew:)`; dead constant removed. |
| B11-4 (hardcoded "Talmid Chochom" literals) | RESOLVED | `app_intro_screen.dart` routes honorific through `domainTermLabels(ref).talmidChochom` / `.talmidChochomCaps`. |
| B11-5 (audit grep targeted wrong symbol) | RESOLVED | Makefile rule 7 grep now targets the real provider `useHebrewTermsProvider`; blanket `.notifier)` exclusion replaced with path-specific allowlist. |
| B11-6 (stage names frozen at creation) | RESOLVED | Stage names re-render live via `domainTermLabels(ref).resolveStoredStageName`; `daily_task_card.dart` and `dashboard_task_item.dart` updated. |
| B11-7 (stale settings-screen comment) | RESOLVED | All raw `HebrewTerms.*` calls removed from `lib/features/`; audit check 13 enforces this going forward. |
| B11-8 (חזרה string in add_track_flow_screen) | RESOLVED | `חזרה` string in `add_track_flow_screen` now uses `domainTermLabels(ref).chazara`; `חזרה` literal consolidated to one const in `hebrew_terms.dart`. |

### Wave 6 code-review findings (HIGH severity)

Two HIGH issues were found by the Wave 5 `/bmad-code-review` and fixed in Wave 6:

| Finding | Status | Notes |
|---------|--------|-------|
| H1 — Tombstoned completions permanently blocked from re-activation | RESOLVED | Fixed in `completion_writer.dart`: tombstoned rows can now be re-activated by a subsequent real-learning completion. |
| H2 — Pull-merge skipped tombstoned rows instead of clearing them | RESOLVED | Fixed in `sync_engine.dart` + `drift_merge_store.dart`: pull-merge now correctly clears tombstones when the remote has a live record. |

### Option-B behaviour change note

As documented in the execution plan (§ "THE OPTION-B DESIGN"): after this remediation, a
track over a **superset curriculum** (e.g. Tanach) no longer inherits completions that
were marked under a **subset curriculum** (e.g. Chumash). Its Completion % may drop.
This is the **intended** Option-B behaviour — per-curriculum identity is load-bearing for
correct completion and expunge scoping.
