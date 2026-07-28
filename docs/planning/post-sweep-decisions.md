# Post-sweep product decisions (repo owner, 2026-07-28)

Four decisions made by the repo owner after the run-11 clean sweep. Items 1–3 are
new build work; item 4 is a documented decision-to-not-act.

## 1. Configurable siyum granularity (FEATURE — to build)

**Decision:** siyum (milestone) granularity is a **user-configurable setting**, because
different families want different levels:
- some want a siyum only on the **entire curriculum** (e.g. all of Chumash / Shas);
- some want it at the **top grouping** (seder for Mishnayos);
- some want it at the **sidra / parsha** level;
- **default is per SEFER** (book);
- **chapter / perek is NEVER an option** (this is the level the run-11 P0 wrongly fired at).

**Build notes:**
- Each curriculum's own hierarchy maps to these choices — "seder" is a Mishnayos term, so
  Chumash's equivalents are curriculum / parsha-sidra / sefer. Provide the setting per
  curriculum against its real levels, not a one-size enum.
- Respect the existing fix: `completion_detection_service.dart`'s `hasNamedLevel2Unit` and
  the ancestor-qualified `scopeUnitIdentifier()` pattern (R1) already prevent the
  bare-numeric-collision class — the config must build on that, never re-enable a
  positional (chapter) unit as a siyum tier.
- Needs: a persisted preference (per profile? per curriculum?), a Settings UI, siyum-
  detection logic that reads the setting, and tests (incl. a red-demo that the wrong level
  does not fire).
- Default (per sefer) matches what shipped, so existing behaviour is the default.

## 2. Dark-mode legibility — dedicated audit + burndown (to build)

**Decision:** do a **dedicated, exhaustive** dark-mode legibility pass, not just fix-as-
reported. Every screen audited in dark mode; all hardcoded-white / low-contrast surfaces
fixed to theme-aware tokens (`brandCreamCard` etc.), each with measured WCAG contrast.

**Build notes:**
- ~249 raw-color occurrences remain (the `check_raw_color_literal_ratchet.dart` baseline).
  The ratchet already blocks NEW ones; this burns down the existing tail.
- Reuse the established pattern (`brandCreamCard` for surfaces, `brandInk`/`brandInkMuted`
  for text, split tokens like `goldOnColouredSurface`/`progressTierSiyumimAccent` for
  ink-on-coloured-surface). Contrast tests + red-demos per fix, as this campaign did.
- Ratchet baseline should drop as sites are fixed (250 → down).

## 3. Curriculum Progress card — rework (to build)

**Decision:** **rework** the card, not just relabel. Currently it shows a track-scoped
count ("Total items 859 / Not started 858", one masechta) next to a whole-curriculum
"Lifetime 100%", which reads as contradictory. Redesign how per-track vs whole-curriculum
progress is presented so it's clear and not self-contradictory.

**Build notes:**
- The arithmetic is correct (see `docs/test-artifacts/run11/progress-percentage-divergence.md`):
  track-scoped (÷ track's own scope) vs whole-curriculum (÷ full curriculum) answer
  different questions. Do NOT equalise the numbers — that destroys a real distinction.
- This is a design task: propose a clearer layout (e.g. two clearly-labelled sections, or a
  single progress model) before building. Investigate `curriculum_progress_screen.dart`'s
  `OverallStatsCard` and the four live progress aggregators.

## 4. Learn tab eager-load — LEAVE AS-IS (documented, not acting)

**Decision:** leave the current behaviour; document it.

**Facts:** opening the Learn tab materialises all 9 curricula (~70k `ContentItem`s) into
`contentIndexProvider`'s keepAlive cache (`content_index.dart`). Run-8 suspected this caused
OOM on low-end devices; **run-10/run-11 DISPROVED that on device** — native heap peaked
~123 MB (24%) of the 512 MB limit even under a deep Talmud Bavli drill, guest-clean.

**The held optimization:** branch `reassurance/run9-learn-eager-load` bounds the load to
only the curricula backing a profile's coarse-paced tracks. It is **deliberately NOT
merged** because:
1. its justification (the OOM P0) was refuted, so it's a perf optimisation for a problem
   that doesn't exist on tested devices;
2. it changes Learn's core navigation via an invariant ("the bound never misses") that, if
   ever wrong, silently degrades which items appear;
3. merging it would invalidate run-11's device evidence, which was gathered on the unbounded
   path.
The fix-wave agent that built it also found that fully bounding `contentIndexProvider` broke
`daily_task_card_test.dart` and had to revert that part — i.e. it is only partial.

**If revisited later:** treat it as a standalone performance change with its own device
validation, not a crash fix. Not a ship-blocker either way.
