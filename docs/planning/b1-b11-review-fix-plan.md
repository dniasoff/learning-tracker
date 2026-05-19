# Execution Prompt — B1–B11 Adversarial-Review Remediation (2026-05-19)

Paste the fenced block below into a fresh Claude Code session on the `dev` branch.

- **Origin:** an adversarial review (2026-05-19) of the B1–B11 fix (commits
  `d6c8e28b`→`a20c112a`) found the "all 11 resolved" claim overstated — B8 and
  B11 are partial, the B1 fix is untested, and a set of code-quality issues
  remain. This document lists the 15 findings and the wave plan to clear them.
- **Owner decision (2026-05-19):** prior-marking and per-track Completion are
  **per-curriculum** (Option B). See "THE OPTION-B DESIGN" inside the fenced block.
- **Remediation complete (2026-05-19):** Waves 1–7 executed and committed on `dev`.
  See `docs/planning/tracks-and-completion-bug-report.md § Remediation status` for
  the per-bug resolution table. **Wave 4 false-positive note:** findings 11 and 14
  (canonical B4/B5) were found to be false positives during Wave 4 execution —
  `TrackCardViewModel` is actively used in `lib/`, and "Personal" is already
  single-sourced in `TrackType.displayNameEn`. No code changes were made for those
  two items; their canonical bug entries are marked FALSE POSITIVE in the status table.
- **Companion docs:** `docs/planning/tracks-and-completion-bug-report.md`
  (canonical B1–B11); `docs/hebrew-terms.md` (B11 spec);
  `docs/planning/tracks-and-completion-fix-plan.md` (the prior effort).
- **Execution model:** a parallel agent squad in waves. **No worktrees** — every
  agent works directly in the shared checkout on `dev`. Safety comes from strict
  disjoint-file ownership per wave and an orchestrator-run verification gate
  (`make ci` + `make audit`) between waves.
- **Pre-work HEAD:** `a20c112a`.

## The 15 findings this plan remediates

**Per-curriculum (Option B) + completion correctness**

1. **B8 — completions are not per-curriculum.** Identity must become
   `(profileId, sefariaRef, stageId, trackType, curriculumId)`; the expunge's
   currently-unused `curriculumId` parameter becomes load-bearing. *(HIGH — foundational)*
2. **B8 — tombstone sync unverified.** The expunge sets `purgedAt` via a raw
   write; confirm `purgedAt` tombstones propagate through the sync engine (also
   affects `track_dao`'s deletion path). *(verify)*
3. **B1 — the completion test is a mirror.** `dashboard_completion_percentage_test.dart`
   tests local copies (`_computeTrackCompletion`/`_computeCurriculumCompletion`),
   never the real providers. The Wave-5 `s.id`→`s.stageOrder` fix has zero
   coverage. *(HIGH)*
8. **B8 — lifetime-retention untested + insert-or-ignore edge.** Untick must
   leave Lifetime when a learn record exists from another path; real learning
   after a prior-mark is swallowed by the natural-key collision. *(MEDIUM)*
9. **B6 — silent degrade.** `_allStageIds` falls back to learn-only `[1]` when
   stage defs are missing, with no signal. *(LOW)*
10. **B6 — caller `stageIds` bypass the superseded guard.** The
    `{...stageIds, ...allConfiguredStageIds}` union re-admits superseded stages. *(LOW)*

**Hebrew terms (B11)**

4. **§11.6 — stage names not live.** `resolveStoredStageName` is unused;
   `daily_task_card.dart` / `dashboard_task_item.dart` render raw
   `task.stageName`. *(MEDIUM)*
5. **§11.1 — structural unit words English-only.** `daf/amud/perek/mishnah/seder/
   masechta/chumash` getters have no consumers; `levelLabels` ignores the
   toggle. *(MEDIUM)*
6. **§11.4 — hardcoded honorific.** `app_intro_screen.dart:387` `'Talmid Chochom'`
   literal default; `'Novice'` also hardcoded. *(MEDIUM)*
12. **§11.8 — `'חזרה'` scattered** across several `HebrewTerms` constants. *(LOW)*
13. **§11.5 — audit grep escape hatch.** Makefile rule 7's blanket `.notifier)`
    exclusion lets toggle reads slip past. *(LOW)*

**Track screens / cleanup**

11. **B2 — orphan `TrackCardViewModel`** + `LifetimeLearningData`, constructed
    nowhere in `lib/`. *(LOW)*
14. **B4 — divergent default-name sources.** `_recreateGoal` seeds `result.label`;
    the edit screen falls back to the localized curriculum name. *(LOW)*

**Process / report**

7. **Status table renumbered** — the "all fixed" report's B1–B11 do not match the
   canonical bug report; canonical B2/B5 are absent. *(MEDIUM)*
15. **Blanket `dart format` commit** (`b6b5fc75`) reformatted 157 files
    mid-stream. Record the practice rule. *(process)*

---

```
You are the ORCHESTRATOR for the B1–B11 adversarial-review remediation of the
Learning Tracker app (Flutter, working dir learning_tracker/, branch dev). You
spawn parallel agent squads, enforce verification gates, run a code review, and
commit. You do NOT write production code yourself except to resolve a gate failure.

Read in full before starting:
  - docs/planning/b1-b11-review-fix-plan.md      (THIS file — the 15 findings)
  - docs/planning/tracks-and-completion-bug-report.md   (canonical B1–B11)
  - docs/hebrew-terms.md                         (canonical spec for the B11 work)

═══════════════════════════════════════════════════════════════════════
GLOBAL RULES (every wave)
═══════════════════════════════════════════════════════════════════════

BRANCH & ISOLATION
- All work on the `dev` branch. NO worktrees. NO feature branches.
- Each wave's agents run IN PARALLEL (one message, multiple Agent calls) and own
  STRICTLY DISJOINT files. The per-agent file lists below are the starting point;
  refine them but keep per-wave ownership disjoint. If two agents in a wave would
  share a file, split that wave into sequential sub-waves.

NO-WORKTREE COORDINATION PROTOCOL
- Agents EDIT their files only. They do NOT run build_runner, do NOT run make ci,
  do NOT commit. (The tree holds every agent's half-done edits mid-wave.)
- Each agent, when done, reports: (a) exact files changed, (b) a one-line
  conventional commit message, (c) the tests it added and that they pass in
  isolation (`flutter test <file>`), (d) anything notable.
- After ALL agents in a wave report, YOU run, in order:
    1. cd learning_tracker && dart run build_runner build --delete-conflicting-outputs
       (only if a Drift/Freezed/Riverpod codegen input changed)
    2. flutter gen-l10n            (only if an .arb changed)
    3. make ci                    (analyze + seed validation + all tests)
    4. make audit                 (12 layering greps)
- Gate RED → dispatch ONE fix agent against the offending files, re-run, repeat
  until GREEN.
- Gate GREEN → commit each agent's slice as its OWN commit, sequentially:
  `git add <that agent's files> && git commit -m "<that agent's message>"`.
  One agent = one commit.
- Do NOT start wave N+1 until wave N is committed and the gate is GREEN.

DISCIPLINE (the core lesson of the review being remediated)
- Every fix ships with a regression test that exercises REAL production code.
  NEVER write a test that re-implements the logic under test and asserts against
  its own copy — that is Finding 3 itself. Drive providers / services / DAOs
  through real in-memory Drift + ProviderContainer (helpers in test/helpers/:
  test_database.dart, drift_memory.dart; reference pattern:
  test/features/progress/presentation/providers/lifetime_knowledge_providers_test.dart).
- If a change breaks a pre-existing test, update the test to the CORRECTED
  behaviour — never re-encode the bug. If unsure whether a test encodes intended
  behaviour, STOP and report.
- Wave 6 fixes EVERY review finding — critical, high, medium AND low. Nothing is
  deferred or downgraded.

CONVENTIONS
- Conventional commits, scoped: fix(progress:), fix(tracks:), feat(sync:),
  fix(sync:), refactor(i18n:), refactor(dashboard:), test(:), docs(:), fix(review:).
- Respect the 5 layering rules in learning_tracker/CLAUDE.md.
- Do NOT deploy Firestore rules — committing files is the deliverable.

TREE STATE AT START
- The working tree carries unrelated owner WIP: lib/core/utils/text_input_formatters.dart
  (new) imported across ~15 screen/dialog files. `make ci` is GREEN with this WIP
  present. Do NOT commit it and do NOT edit those files — no wave below needs them.

═══════════════════════════════════════════════════════════════════════
THE OPTION-B DESIGN  (owner-confirmed 2026-05-19 — target behaviour)
═══════════════════════════════════════════════════════════════════════
Prior-marking and per-track Completion are PER-CURRICULUM.

- A completion's identity becomes the 5-tuple
  (profileId, sefariaRef, stageId, trackType, curriculumId). The same section
  completed under two curricula is TWO rows.
- Track Completion % (B1) counts ONLY completions whose curriculumId == that
  track's curriculum.
- LIFETIME stays CONTENT-identity: distinct sections by sefariaRef, deduped
  across all curricula — a section done under N curricula counts ONCE. B9 already
  does this; it MUST keep working after the schema change (Wave 2 Agent E guards it).
- Expunge (untick) is scoped to one curriculumId — the previously-unused
  `curriculumId` parameter of expungePriorCompletions becomes load-bearing.
- The completion Firestore document id MUST include curriculumId, or two
  per-curriculum completions of one section collide on one document.
- KNOWN CONSEQUENCE: existing completion_events rows keep the curriculumId they
  were written under. After this ships, a track over a SUPERSET curriculum (e.g.
  Tanach) no longer inherits completions marked under a SUBSET (e.g. Chumash) —
  its Completion % may drop. This is the intended Option-B behaviour; state it
  plainly in the Wave 7 final report.

═══════════════════════════════════════════════════════════════════════
WAVE 0 — Baseline   (orchestrator, blocking)
═══════════════════════════════════════════════════════════════════════
Run `make ci` and `make audit`. Both MUST be green. If not, STOP and report —
do not proceed. Record HEAD. No commit.

═══════════════════════════════════════════════════════════════════════
WAVE 1 — Per-curriculum foundation: schema + sync   (2 parallel agents)
═══════════════════════════════════════════════════════════════════════
Shared contract: a completion's identity is now the 5-tuple
(profileId, sefariaRef, stageId, trackType, curriculumId).

── Agent A — Schema v20 → v21 ──
Owns: lib/core/database/tables/completion_events.dart,
      lib/core/database/user/user_database.dart,
      lib/core/database/views/completions_view.dart (only if it must expose
        curriculumId for Wave 2's consumers),
      test/migration/v20_to_v21_test.dart (new).
Task (Finding 1, schema half): change the `completion_events_natural_key` unique
  @TableIndex to {profileId, sefariaRef, stageId, trackType, curriculumId}. Bump
  schemaVersion to 21. Add the onUpgrade v20→v21 step: drop the old index, create
  the new one (existing rows stay unique — widening a unique index cannot create
  a collision). The write path already uses InsertMode.insertOrIgnore, which now
  collapses on the 5-tuple automatically. Write v20_to_v21_test.dart: seed v20
  rows, migrate, assert the new index exists and that two rows differing only in
  curriculumId can now coexist.
Commit: feat(sync): completion identity is per-curriculum — v21 natural key

── Agent B — Per-curriculum completion doc id + tombstone propagation ──
Owns: lib/core/sync/firestore_gateway_impl.dart, firestore_gateway.dart,
      the push-pipeline files (push_pipeline*.dart) and the completion entityKey
      derivation — wherever the completion document id is built; plus the matching
      test files under test/sync/.
Task (Findings 1 sync half, 2): (1) extend the completion entityKey / Firestore
  document id to include curriculumId, consistently on push AND on any pull/merge
  that reconstructs rows by that key — so two per-curriculum completions of one
  section are two documents. (2) Finding 2: confirm a `purgedAt` tombstone write
  propagates to Firestore; if the push path sends only inserts, add tombstone
  propagation (this also fixes track_dao's deletion path). Add tests to test/sync/.
Commit: fix(sync): per-curriculum completion doc id; propagate purgedAt tombstones

Gate, then commit A then B.

═══════════════════════════════════════════════════════════════════════
WAVE 2 — Consumers: completion %, prior-mark, lifetime guard   (3 parallel agents)
═══════════════════════════════════════════════════════════════════════

── Agent C — Curriculum-scoped Completion % + REAL B1 test ──
Owns: lib/features/dashboard/presentation/providers/dashboard_providers.dart,
      test/features/dashboard/presentation/providers/dashboard_completion_percentage_test.dart,
      lib/core/database/daos/completion_dao.dart (only if a curriculum-filtered
        query method is needed — disjoint from Wave 2 siblings).
Task (Findings 1, 3): (1) dashboardTrackCompletionPercentage and
  dashboardCompletionPercentage must count ONLY completions whose curriculumId
  matches the track's curriculum (Option-B design). (2) Finding 3: DELETE the
  local mirror helpers `_computeTrackCompletion`/`_computeCurriculumCompletion`
  from the test file and rewrite every test to drive the REAL providers through a
  ProviderContainer over in-memory Drift. Seed stage definitions whose `id`
  differs from `stageOrder` so a regression from `s.stageOrder` back to `s.id`
  fails the suite. Cover: item done only when ALL required stages present;
  an item completed under curriculum A is NOT counted by a track over curriculum
  B; a zero-item track → 0.0.
Commit: fix(progress): curriculum-scoped completion %; real provider tests (B1)

── Agent D — Prior-mark service: per-curriculum expunge + B6/B8 hardening ──
Owns: lib/features/onboarding/domain/services/bulk_prior_completion_service.dart,
      test/features/onboarding/domain/services/bulk_prior_completion_service_test.dart,
      test/integration/bulk_prior_completion_b6_b8_test.dart.
Task (Findings 1, 8, 9, 10): (1) expungePriorCompletions must filter by
  curriculumId — add `& t.curriculumId.equals(curriculumId.storageKey)` to the
  tombstone query; the parameter is now used. (9) when stage definitions are
  missing/empty, log an AppLogger warning instead of silently returning [1].
  (10) drop the caller-`stageIds` union in `effectiveStageIds` — use only the
  superseded-filtered configured set; deprecate or remove the `stageIds`
  parameter. (8) add tests: untick under curriculum A leaves curriculum B's
  completion intact; after prior-marking under both A and B the section counts
  in both; untick leaves Lifetime when a non-sentinel learn row exists; the
  insert-or-ignore edge — real learning of a stage AFTER a prior-mark.
Commit: fix(tracks): per-curriculum expunge; harden prior-mark stage resolution

── Agent E — Lifetime stays content-identity (regression guard) ──
Owns: lib/features/progress/presentation/providers/lifetime_knowledge_providers.dart,
      test/features/progress/presentation/providers/lifetime_knowledge_providers_test.dart.
Task (Option-B design): add a test that, after the v21 change, B9 still counts a
  section completed under two curricula EXACTLY ONCE in lifetime totals
  (numerator and denominator). No production change is expected — if the test
  fails, fix lifetime_knowledge_providers.dart so the union dedupes by sefariaRef.
Commit: test(progress): lifetime dedup survives per-curriculum completions

Gate, then commit C, D, E.

═══════════════════════════════════════════════════════════════════════
WAVE 3 — Hebrew terms   (3 parallel agents, disjoint files)
═══════════════════════════════════════════════════════════════════════

── Agent F — Stage names re-render live ──
Owns: lib/features/scheduler/presentation/widgets/daily_task_card.dart,
      lib/features/dashboard/presentation/widgets/dashboard_task_item.dart,
      a widget test for the live re-render.
Task (Finding 4): render domainTermLabels(ref).resolveStoredStageName(task.stageName)
  instead of raw task.stageName at daily_task_card.dart:30 and
  dashboard_task_item.dart:152/158. Add a widget test that flips
  useHebrewTermsProvider and asserts the stage label changes live.
Commit: fix(i18n): stage names re-render live with the Hebrew Terms toggle

── Agent G — Structural unit words follow the toggle ──
Owns: lib/core/labels/domain_term_labels.dart (only if needed),
      the levelLabels resolution path (content_repository_impl.dart, step_scope.dart,
      curriculum_defaults.dart), + tests.
Task (Finding 5): make the levelLabels / structural-unit resolution
  Hebrew-Terms-aware — Hebrew → labelsHe, English → transliteration. Wire the
  daf/amud/perek/mishnah/seder/masechta/chumash catalog getters into the
  breadcrumb / level-label render path, or retire them if labelsHe subsumes them.
  Add tests for the toggle.
Commit: feat(i18n): structural unit words follow the Hebrew Terms setting

── Agent H — Honorific literal, חזרה dedup, audit grep ──
Owns: lib/features/onboarding/presentation/screens/app_intro_screen.dart,
      lib/core/constants/hebrew_terms.dart, learning_tracker/Makefile.
Task (Findings 6, 12, 13): (6) app_intro_screen — use
  domainTermLabels(ref).talmidChochom / .talmidChochomCaps; remove the
  'Talmid Chochom' literal default; route 'Novice'. (12) consolidate the Hebrew
  'חזרה' literal in hebrew_terms.dart to ONE const the other ui* fields reference.
  (13) tighten Makefile rule 7: replace the blanket `.notifier)` exclusion with a
  precise allowance — whitelist the legitimate writer paths (settings + onboarding)
  BY PATH, not by token; verify the grep still FAILS on a planted violation.
Commit: refactor(i18n): route honorific via setting; consolidate חזרה; tighten audit grep

Gate, then commit F, G, H. If G must edit hebrew_terms.dart, run G then H
sequentially (H owns that file).

═══════════════════════════════════════════════════════════════════════
WAVE 4 — Track-screen cleanup   (2 parallel agents, disjoint files)
═══════════════════════════════════════════════════════════════════════

NOTE (2026-05-19 post-execution): Both Wave 4 findings were FALSE POSITIVES.
Agent I confirmed `TrackCardViewModel` IS actively used in `lib/` — the file was
not orphaned. Agent J confirmed `TrackType.displayNameEn` already single-sources
the "Personal" label — no divergent default existed. No code was changed in Wave 4.

── Agent I — Remove orphan TrackCardViewModel ──
Owns: lib/features/dashboard/domain/models/track_card_view_model.dart
      (+ generated .freezed.dart) and any file importing it.
Task (Finding 11): confirm TrackCardViewModel + LifetimeLearningData are
  constructed nowhere in lib/ (grep `TrackCardViewModel(`); delete them; rerun
  build_runner; remove now-dead imports.
STATUS: FALSE POSITIVE — TrackCardViewModel is actively used; no deletion made.

── Agent J — Single-source the default track name ──
Owns: lib/features/track_setup/domain/services/track_creation_service.dart,
      lib/features/track_setup/presentation/screens/edit_track_screen.dart,
      + a shared helper + a test.
Task (Finding 14): both the goal-creation default and the edit-screen fallback
  must use the SAME default — the localized curriculum name. Extract one shared
  helper; both call it. Add a test that a track created with no description shows
  the curriculum name in Edit Track.
STATUS: FALSE POSITIVE — "Personal" is already single-sourced in TrackType.displayNameEn;
  no divergent default found; no change made.

Gate, then commit I, J.

═══════════════════════════════════════════════════════════════════════
WAVE 5 — BMAD code review   (orchestrator)
═══════════════════════════════════════════════════════════════════════
Run /bmad-code-review on the full diff of every commit from Wave 1 through Wave 4
(`git diff <Wave-0 HEAD>...HEAD`). Collect ALL findings grouped by severity
(critical / high / medium / low), each with file:line and a proposed fix.

═══════════════════════════════════════════════════════════════════════
WAVE 6 — Fix EVERY review finding   (parallel agents, disjoint files)
═══════════════════════════════════════════════════════════════════════
Fix EVERY finding — critical, high, MEDIUM and LOW. Nothing deferred or
downgraded. Partition the findings into disjoint file-sets; one agent per
partition, in parallel. Each agent adds a regression test that exercises real
code (per the DISCIPLINE rule) where the finding warrants one. Gate; commit each
slice as fix(review): <desc>. If Wave 6 is non-trivial, run /bmad-code-review
once more on the Wave 6 diff and fix any new findings the same way.

═══════════════════════════════════════════════════════════════════════
WAVE 7 — Docs + final verification   (orchestrator + 1 agent)
═══════════════════════════════════════════════════════════════════════
- Finding 7: produce a corrected B1–B11 status table using the CANONICAL ids
  from tracks-and-completion-bug-report.md; append it to that file under a
  "## Remediation status (2026-05-19)" heading. Every canonical bug B1–B11 must
  appear (B2 and B5 included), each with its true status and commit.
- Finding 15: add a one-line practice note to docs/coding-standards.md — no
  blanket `dart format` commits mid-stream; formatting is part of each slice's
  gate, not a separate commit.
- Run `make ci` and `make audit` — both fully green; `dart analyze` 0 issues.
- Re-run the touched suites: test/migration/, test/sync/, the dashboard /
  progress / onboarding story-acceptance suites, and
  test/story_acceptance/epic_28_curriculum_overlap_test.dart.
- Produce a final report: every commit grouped by wave; each of the 15 findings
  marked resolved with its commit; the Option-B behaviour change for existing
  superset-curriculum tracks; before/after Completion numbers; any follow-ups.
Commit: docs(tracks): B1–B11 remediation — reconcile status table + practice note

DO NOT, at any point: create worktrees or branches; let two agents in a wave
share a file; skip a gate; defer a medium/low review finding; commit the owner
text_input_formatters WIP; deploy Firestore rules; bypass hooks; write a test
that re-implements the code under test instead of calling it.
```

---

## Wave summary

| Wave | Agents | Delivers | Findings |
|---|---|---|---|
| 0 | orchestrator | baseline — `make ci` + `make audit` green | — |
| 1 | A · B | v21 per-curriculum schema; per-curriculum completion doc id + tombstone sync | 1, 2 |
| 2 | C · D · E | curriculum-scoped Completion % + real B1 provider tests; per-curriculum expunge + B6/B8 hardening; lifetime-dedup guard | 1, 3, 8, 9, 10 |
| 3 | F · G · H | stage names re-render live; structural unit words toggle-aware; honorific + `חזרה` + audit grep | 4, 5, 6, 12, 13 |
| 4 | I · J | ~~remove orphan TrackCardViewModel; single-source the default track name~~ — both findings were FALSE POSITIVES; no code changed | 11, 14 |
| 5 | orchestrator | `/bmad-code-review` on the full diff | — |
| 6 | parallel | fix every review finding — all severities | — |
| 7 | orchestrator + 1 | reconcile status table to canonical IDs; practice note; full green; final report | 7, 15 |

All work lands on `dev`. No worktrees. Verification gate (`make ci` + `make audit`)
between every wave. Findings 1 and 2 were corrected down from their first-pass
"HIGH data-loss" framing after a schema review — under Option B they become the
foundational Wave 1 work rather than emergency patches.
