# Scope: Daf as the natural display unit for Talmud (amud → daf rollup)

**Status:** Scoping / awaiting product sign-off
**Author:** loop (2026-06-14)
**Origin:** DSWEEP finding — track-detail "Items remaining 5349" shows *amudim* for a
Talmud Bavli track whose goal is "7 **daf**/week". For daf-based learning the natural
unit is the **daf**; two amudim (a/b) should roll up to one daf in user-facing counts.

---

## 1. Problem

The Talmud is *learned and counted in dapim*, but the app models, stores, and in several
places *displays* the **amud** (half-daf) as the unit. A user doing Daf Yomi sees "5349
items remaining" (amudim) instead of "~2711 dapim", and pace reads as "X items/day" rather
than "X dafim/day". This is a leaky abstraction: the amud is an internal storage unit, not
the unit a learner thinks in.

This is **specific to curricula whose leaf is an amud** — i.e. **Talmud Bavli** (L1=Masechta,
L2=Daf, **L3=Amud=leaf**). For other curricula the leaf *is* the natural unit (a mishna, a
pasuk, a halacha, a seif) and needs no rollup.

## 2. Current model (verified in code)

| Layer | Behaviour | Evidence |
|---|---|---|
| Content hierarchy (Bavli) | L1=Masechta, L2=Daf (number), L3=Amud (`a`/`b`) = **leaf** | `build/seeded_content/bavli.json`; `content_item.dart` |
| Completion | **One `completion_events` row per amud (leaf sefariaRef)** — natural key `(profileId, sefariaRef, stageId, trackType, curriculumId)`. A daf is never a stored unit. | `core/database/tables/completion_events.dart`; `features/learning/data/completion_writer.dart` |
| Scheduler pacing | **Already daf-aware**: when `goal.paceGranularity == 'daf'` the daily batch is *all amudim under the next N dapim* ("1 daf/day" emits the whole daf). | `scheduler/domain/services/scheduler_engine.dart`; `SchedulerContentItem.coarseUnitKey` |
| Daily task | unit = leaf (amud); carries seeded `unitDisplayHe/En` collapsed-to-daf label ("חולין דף כ״ה") | `scheduler/domain/models/daily_task.dart` |
| Reader nav | prev/next steps **amud-by-amud** (same leaf depth) | `content_browsing/.../content_providers.dart` `adjacentContentRefsProvider` |
| Add-track wizard | User **picks daf vs amud** (Bavli defaults to `daf`, fine choice `amud`); projected finish already counts in the chosen unit | `tracks/setup/.../steps/step_goal.dart`, `goal_cards.dart`, `paceUnitOptionsFor()` |

### Rollup infrastructure that already exists (reusable)
- `collapseAmudToDaf(breadcrumb)` — strips the "› Amud a" leaf for display — `dashboard/.../dashboard_helpers.dart`.
- `programUnitDayLabel(task)` — seeded collapsed daf label — same file.
- `scopedCoarseUnitCountProvider(curriculumId)` — **distinct daf count** (collapses leaf→parent) — `settings/.../curriculum_scope_providers.dart` (added in the deferred-fix wave).
- `SchedulerContentItem.coarseUnitKey` — groups leaves by their coarse parent.
- `PaceGranularity { perek, daf, seif }` + `paceUnitOptionsFor(curriculumId)`.

## 3. Surfaces inventory (what still shows amud)

| # | Surface | File:line | Current unit | Target |
|---|---|---|---|---|
| S1 | Track detail **Items remaining** | `track_detail_screen.dart:~436` (src `scopedItemCountProvider`) | amud (leaf) | **daf** for Bavli — and align with the already-daf "Est. finish" on the same card |
| S2 | Track detail **Required / Actual pace** ("X items/day") | `track_info_card.dart:~160,175` (src `PaceCalculator`) | amud/day, unlabeled | **daf/day** + unit-labeled ("dafim/day") |
| S3 | Lifetime Knowledge **"N items learned"** + per-curriculum **"X of Y"** | `lifetime_knowledge_screen.dart:~224`; `curriculum_breakdown_list.dart:~186` | amud (leaf) | **daf** for Bavli |
| S4 (opt) | Dashboard **self-paced "current focus"** pill | `active_track_card.dart:~171` | leaf ref | daf-collapsed (program pill already is) |

**Already correct (no change):** add-track wizard pace step; Est. finish (uses coarse count);
program dashboard "today" pill (collapses to daf); daily-task batching; all **percentages**
(proportion, unit-independent); task-count chips ("2 today").

## 4. Design

### Principle — "natural display unit" per curriculum
Introduce a single source of truth: each curriculum has a **natural display unit** for
user-facing counts. Bavli → **daf** (roll up amudim); all others → leaf (mishna/pasuk/
halacha/seif — unchanged). This is a *display/aggregation* concept layered on the unchanged
amud-level storage — **no data-model or completion migration**.

Concretely: a `curriculumDisplayUnit(curriculumId)` + count helpers that the four surfaces
read, backed by the existing `coarseUnitKey` collapse for Bavli and identity for the rest.

### The one real semantic decision — partial dapim
A daf has two amudim. When counting **learned/remaining dapim**, how is a daf with only
**one** amud done treated?
- **(A) Strict** — a daf counts as learned only when **both** amudim are done. "X of Y dafim"
  = fully-complete dapim. Cleanest meaning; a half-done daf shows as not-yet-learned.
- **(B) Touched** — a daf counts once **any** amud is done. Counts converge faster but
  "learned" overstates.
Recommendation: **(A) Strict** for "learned/remaining" counts (matches "I finished the daf"),
while **pace** (S2) is rate-of-progress and can stay amud-derived then ÷2 to dafim/day
(a fractional rate like "3.5 daf/day" is fine, or round for display).

### Scope-breadth options
- **Tier 1 (minimal):** S1 + S2 — fixes the reported track-detail inconsistency only.
- **Tier 2 (recommended):** S1 + S2 + S3 — daf everywhere a Bavli **count** is shown
  (track + progress/lifetime). Coherent; this is what "daf not amud" really means.
- **Tier 3:** + S4 self-paced pill — full parity with program tracks.

## 5. Phased plan (Tier 2)

1. **Core helper** — `curriculumDisplayUnit(id)` + `dafFromAmud` rollup; reuse
   `coarseUnitKey`. Add `learnedDisplayUnitCount` / `totalDisplayUnitCount` (strict-daf for
   Bavli, leaf otherwise) next to the existing leaf counters. *(core, well-tested)*
2. **S1 Items remaining** — swap to display-unit count for Bavli; align with Est. finish.
3. **S2 Pace** — thread `paceGranularity`/display-unit into `PaceCalculator` output + label
   strings ("{n} daf/day" — new ICU plural keys, en+he).
4. **S3 Lifetime/progress counts** — daf-aware `learnedLeafCount`/`totalLeafCount` variants
   for Bavli in `lifetimeHeaderCountersProvider` + `curriculum_breakdown_list`.
5. **(Tier 3) S4** — apply `collapseAmudToDaf` to the self-paced focus pill.
6. **Tests** — unit tests for strict-daf rollup (full/partial/edge), widget tests per surface
   in en+he; on-device verify a Bavli track shows ~2711 dafim remaining + "daf/day" pace.

## 6. Risks / notes
- **No storage migration** — purely display/aggregation; completion stays amud-level, so
  existing data and sync are untouched. Low blast radius.
- **Percentages unaffected** (ratios are unit-independent) — avoids double-work.
- **Yerushalmi caveat:** modeled as Perek→Halacha (leaf=halacha), but `paceUnitOptionsFor`
  forces its coarse label to `daf`. That label↔model mismatch is **out of scope here**;
  flagged for a separate content/label fix.
- **Siyumim** unit references not fully inventoried — confirm during impl whether any
  siyum/milestone copy says "amud".
- Test churn: any test asserting an amud-based count on S1–S3 must update.

## 7. Effort (rough)
Tier 2 ≈ 1 focused implementation wave: ~6–8 files + l10n + tests, comparable to the
deferred-fix wave. Tier 1 ≈ half that. No migration.

## 8. Open decisions (need product sign-off)
1. **Breadth:** Tier 1 / **Tier 2 (recommended)** / Tier 3?
2. **Partial daf:** **(A) Strict** (recommended) vs (B) Touched for learned/remaining counts.
3. **Scope of "daf-based":** Bavli only (recommended — it's the only amud-leaf curriculum),
   or also force Yerushalmi's "daf" label (needs the separate content fix first)?
