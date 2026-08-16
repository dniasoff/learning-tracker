# Tracks, Completion & Terminology — Orchestrator Execution Prompt

**Date:** 2026-05-18
**Companion docs:**
- Bug report → `docs/planning/tracks-and-completion-bug-report.md` (B1–B11; read first).
- Hebrew-terms spec → `docs/hebrew-terms.md` (canonical spec for the B11 work).

Paste the fenced block below into a fresh Claude Code session on the `dev` branch.
It is a self-contained orchestrator prompt — the executing agent has no prior
context, so everything it needs is in this file + the two companion docs.

---

```
You are the ORCHESTRATOR for a multi-wave fix of the Learning Tracker app
(Flutter, working dir learning_tracker/, branch dev). You spawn parallel agent
squads, enforce verification gates, run a code review, and commit. You do not
write production code yourself except to resolve a gate failure.

Read docs/planning/tracks-and-completion-bug-report.md and docs/hebrew-terms.md
in full before starting.

═══════════════════════════════════════════════════════════════════════
GLOBAL RULES (every wave)
═══════════════════════════════════════════════════════════════════════
- All work on the `dev` branch. NO worktrees. NO feature branches.
- Each wave's agents run IN PARALLEL (one message, multiple Agent calls) and own
  STRICTLY DISJOINT files. If two agents in a wave would share a file, split that
  wave into sequential sub-waves. The file lists below are the starting point;
  refine them but keep per-wave ownership disjoint.
- Agents EDIT their files only. They do NOT run build_runner, do NOT run make ci,
  do NOT commit. After all agents in a wave report, YOU run, in order:
    1. cd learning_tracker && dart run build_runner build --delete-conflicting-outputs
       (only if a Drift/Freezed/Riverpod/codegen input changed)
    2. flutter gen-l10n            (only if an .arb changed)
    3. make ci                    (analyze + all tests)
    4. make audit                 (12 layering greps)
- If a gate is RED: dispatch a single fix agent against the offending files,
  re-run, repeat until GREEN. Then commit each agent's slice as its OWN commit.
- Do NOT start wave N+1 until wave N is committed and the gate is GREEN.
- Conventional commits, scoped: fix(tracks:), fix(progress:), fix(sync:),
  feat(tracks:), refactor(i18n:), test(:), fix(review:).
- Respect the 5 layering rules in learning_tracker/CLAUDE.md.

KNOWN PRE-EXISTING TREE NOISE
- The working tree contains unrelated owner WIP: a new file
  lib/core/utils/text_input_formatters.dart imported across ~16 screen/dialog
  files, with imports inserted out of alphabetical order. This makes
  `dart analyze` emit ~9 `directives_ordering` infos, so `make ci`'s analyze step
  is RED before you start. That is NOT caused by these bugs. Leave the owner's
  WIP files alone during the fix waves; the FINAL wave (Wave 6) makes the whole
  gate green, including sorting those imports.

═══════════════════════════════════════════════════════════════════════
THE CONFIRMED MODEL  (target behaviour — every rule owner-confirmed)
═══════════════════════════════════════════════════════════════════════

COMPLETION (per track)
- Item-based. An item is "completed" only when EVERY required stage is done —
  learn + all its chazara. If the item/track has no chazara configured, learning
  it alone completes it.
- Completion % = (items with all required stages done) / (total items in track).
- No stage multiplier; an item counts once; no per-stage double-count.

LIFETIME LEARNING
- Breadth. An item is counted from the FIRST time it is learnt; once counted it
  stays forever — chazara, re-learns and second cycles never add to it.
- Lifetime % = (distinct items ever learnt) / (total items).
- Per-curriculum lifetime is already correct (Set-based dedup of subset
  curricula). The ALL-CURRICULA total is broken — see B9.
- Lifetime is NEVER shown on a track screen.

TRACKS
- Only one track type exists. The words "Personal Track" are removed everywhere.
- A track's name is stored as the Goal's `description`. It defaults to the
  curriculum name. A track's user-facing identity is its curriculum name, which
  is already shown (app-bar on the detail screen, card title on the hub) — never
  render it twice.
- Track screens show: the track/curriculum name + completion + that track's
  content/tasks. Never lifetime.

MARKING DONE
- Marking content done = the item is fully done; all stages (learn + chazara)
  are recorded automatically — no per-stage verification. This applies to the
  PRIOR-marking flow.
- ONGOING daily learning is unaffected: the chazara scheduler still schedules
  chazara reviews on future days; an ongoing item becomes "completed" only when
  its last scheduled chazara is actually done. Only the prior-marking stage
  screen is deleted (B5).

MARK-PRIOR-COMPLETIONS FLOW
- Screen 1 ("Select content you've already completed" — sedarim/content
  checkboxes): KEEP. Must pre-tick content already completed (B7).
- Screen 2 ("Which stages have you completed?" — Learn/Chazara picker): DELETE
  (B5). The flow becomes select-content -> mark.
- Marking prior content done records completions for learn + ALL chazara stages
  of each item (B6).
- Unticking a previously-marked item expunges the completion records that prior-
  marking created (B8) — the item leaves track Completion, and leaves Lifetime
  UNLESS a learn record exists from another path. `completion_events` is append-
  only with a `purgedAt` tombstone column — "expunge" = tombstone, not delete.

HEBREW TERMS — see docs/hebrew-terms.md (the canonical spec). Binary
(Hebrew script <-> transliteration; no translated form), all domain terms in
scope, stage names re-render live, default ON, hidden in Hebrew locale.

═══════════════════════════════════════════════════════════════════════
TREE STATE AT START
═══════════════════════════════════════════════════════════════════════
Committed already (do not redo): the Firebase sync rework; FK-787 / account-
deletion fix (8364e074); lifetime row removed from the Track DETAIL screen
(1bf11dbc).

Uncommitted, MINE, correct — the B10 completion-label work:
  lib/l10n/app_en.arb, lib/l10n/app_he.arb, lib/l10n/app_localizations*.dart
  (carouselCompletion is now a method carouselCompletion(String chazara) ->
  "Completion (with {chazara})" / "השלמה (עם {chazara})"),
  lib/features/track_setup/presentation/widgets/learning_track_card.dart and
  .../screens/track_detail_screen.dart (call sites pass a Hebrew-terms-aware
  chazara term), test/l10n/app_localizations_coverage_test.dart.
  -> Wave 0 commits this as-is.

Uncommitted, MINE, SUPERSEDED — discard:
  lib/features/dashboard/presentation/providers/dashboard_providers.dart has an
  interim item-based calc that counts "any completion". The final rule is "all
  stages done" (B1). Wave 0 reverts this file to HEAD; Wave 1 redoes it.

Uncommitted, OWNER's WIP — DO NOT TOUCH until Wave 6:
  lib/core/utils/text_input_formatters.dart (new) and ~16 modified screen/dialog
  files (sign_in_screen, content_search_screen, bulk_mark_screen,
  onboarding_screen, signup_screen, reward_configuration_screen,
  manage_learners_screen, profile_picker_screen, city_picker_screen,
  goal_setup_screen, upgrade_to_cloud_screen, change_password_dialog,
  delete_account_dialog, link_provider_dialog, reauthenticate_dialog,
  track_label_step). NOTE: bulk_mark_screen.dart is needed by Wave 2 — its agent
  must edit only the prior-marking logic and leave the owner's text-formatter
  import edits intact.

═══════════════════════════════════════════════════════════════════════
WAVE 0 — baseline + commit the label work   (orchestrator, blocking)
═══════════════════════════════════════════════════════════════════════
- Run `make ci`; record the baseline. The only failures must be the ~9
  `directives_ordering` infos from the owner WIP — if anything else fails, STOP
  and report.
- `git checkout -- lib/features/dashboard/presentation/providers/dashboard_providers.dart`
  (discard the superseded interim calc).
- Commit the B10 label slice (the arb files, the generated app_localizations*,
  the two track-screen call sites, the coverage test) as one commit:
  `fix(tracks): completion label states it includes chazara, term-aware`.
- Do NOT commit the owner WIP files.

═══════════════════════════════════════════════════════════════════════
WAVE 1 — Metrics & Track screens   (4 parallel agents, disjoint files)
═══════════════════════════════════════════════════════════════════════
Agent A — Completion metric (B1)
  Owns: lib/features/dashboard/presentation/providers/dashboard_providers.dart
        + the matching test file under test/.
  Task: rewrite dashboardTrackCompletionPercentage and dashboardCompletionPercentage
  to be item-based: an item counts only when every required stage (learn + all
  its chazara stages) has a completion; Completion % = items-fully-done / total
  items. Drop the stage multiplier. Resolve each item's required stage set from
  the track's stage definitions / chazara config; an item with no chazara needs
  only learn. Add/adjust tests.
  Commit: fix(progress): completion is item-based — item done when all stages done

Agent B — All-curricula lifetime dedup (B9)
  Owns: lib/features/progress/presentation/providers/lifetime_knowledge_providers.dart
        + its test.
  Task: lifetimeTotalsAcrossAllCurriculaProvider currently SUMS per-curriculum
  learnedLeafCount/totalLeafCount, double-counting overlapping curricula
  (Chumash/Nach inside Tanach, and possibly more). Rewrite it to count DISTINCT
  sections — union every curriculum's leaf sections by section identity
  (sefariaRef), dedupe, count. General (overlap-registry driven), not a Chumash/
  Tanach special case. Numerator and denominator both deduped.
  Commit: fix(progress): all-curricula lifetime counts distinct sections

Agent C — Track screens: lifetime off + "Personal Track" removed (B2, B3)
  Owns: lib/features/track_setup/presentation/widgets/learning_track_card.dart,
        lib/features/track_setup/presentation/screens/track_detail_screen.dart,
        lib/l10n/app_en.arb, lib/l10n/app_he.arb (track-only keys).
  Task: (B2) remove the lifetime computation + the "Lifetime learning" label/bar
  from learning_track_card.dart. (B3) remove "Personal Track" everywhere — the
  card heading on the detail screen, the subtitle on the hub card, and the
  "Track type" config row; remove trackTypeDisplayLabel and the now-dead
  trackDetailConfigType l10n key if unused. Do not duplicate the curriculum name
  (already shown in the app-bar / as the card title). Run flutter gen-l10n after
  arb edits.
  Commit: fix(tracks): drop lifetime + "Personal Track" wording from track screens

Agent D — Track name default (B4)
  Owns: the add-track / goal-creation code path (locate it — goal creation in the
  add-track flow and/or the goal repository/DAO) + its test.
  Task: a track's name is the Goal's `description`. Seed it with the curriculum
  name at track/goal creation, and/or fall back to the curriculum name wherever
  `description` is empty (so the Edit Track "Track Name" field is never blank).
  Commit: fix(tracks): default a track's name to its curriculum name

Gate, then commit A, B, C, D as four commits.

═══════════════════════════════════════════════════════════════════════
WAVE 2 — Mark-Prior-Completions flow   (2 parallel agents, disjoint files)
═══════════════════════════════════════════════════════════════════════
Agent E — prior-marking data layer (B6, B8-data)
  Owns: lib/features/onboarding/domain/services/bulk_prior_completion_service.dart,
        the completion repository / CompletionWriter it uses (whichever files own
        the prior-mark write path) + their tests.
  Task: (B6) marking prior content done must record completion_events for learn
  + EVERY chazara stage of each item, so the item satisfies the "all stages done"
  Completion rule. (B8-data) add an "expunge a prior-marking" API: tombstone
  (set purgedAt) the completion_events that a given prior-marking created.
  Define the method signature clearly — Agent F codes the UI against it.
  Commit: fix(tracks): prior-marking records all stages; add expunge API

Agent F — prior-marking flow UI (B5, B7, B8-ui)
  Owns: lib/features/onboarding/presentation/screens/bulk_mark_screen.dart
        (prior-marking logic only — leave the owner's text-formatter import
        edits intact), the "Which stages have you completed?" screen file
        (locate by that title string — DELETE it), and the flow wiring/router.
  Task: (B5) delete the stage-picker screen; the flow becomes select-content ->
  mark. (B7) pre-tick content already completed when screen 1 re-opens. (B8-ui)
  wire untick to call Agent E's expunge API.
  Commit: refactor(tracks): drop the stage-picker screen; pre-tick + untick prior marks

If E and F genuinely cannot stay file-disjoint, run E first, then F.
Gate, then commit.

═══════════════════════════════════════════════════════════════════════
WAVE 3 — Hebrew terms   (2 parallel agents, disjoint files)
═══════════════════════════════════════════════════════════════════════
Implements docs/hebrew-terms.md and clears all 8 §11 drift defects.

Agent G — term core
  Owns: lib/core/constants/hebrew_terms.dart, lib/core/labels/* ,
        lib/l10n/app_en.arb + app_he.arb (term keys).
  Task: enforce the binary model; make the full domain-term catalog (chazara,
  daf, amud, perek, mishnah, seder, masechta, chumash, curriculum names, stage
  names, honorifics) toggle-aware; correct any English ARB string that translates
  a term ("Chazara/Review" -> "Chazara"); remove the dead uiBubbleChazara or wire
  it; remove duplication (curriculumDisplayNames vs displayNameHe); make stage
  names re-render live with the setting. Run flutter gen-l10n.

Agent H — call sites, audit grep, settings
  Owns: feature-level call sites that render domain terms, the settings screen,
        the Makefile audit grep, the stale doc comment.
  Task: route every hardcoded domain term (incl. "Talmid Chochom") through the
  setting; fix the `make audit` grep that targets the non-existent
  `hebrewTermsScriptProvider` (real symbol: `useHebrewTermsProvider`) and
  re-enforce "no toggle reads outside core/labels|core/preferences|settings";
  correct the stale "default: false" comment (actual default true).

Gate, then commit G, H.

═══════════════════════════════════════════════════════════════════════
WAVE 4 — BMAD code review   (orchestrator)
═══════════════════════════════════════════════════════════════════════
Run /bmad-code-review (or an adversarial-review squad) on the full diff of every
commit from Wave 0 through Wave 3. Collect ALL findings grouped by severity
(critical / high / medium / low), each with file:line and a proposed fix.

═══════════════════════════════════════════════════════════════════════
WAVE 5 — Fix EVERY review finding   (parallel agents, disjoint files)
═══════════════════════════════════════════════════════════════════════
Fix EVERY finding — critical, high, MEDIUM and LOW. Nothing is deferred or
downgraded. Partition findings into disjoint file-sets; one agent per partition,
in parallel. Each agent adds a regression test where the finding warrants one.
Gate; commit each slice as fix(review): <desc>. If Wave 5 is non-trivial, run
/bmad-code-review once more on the Wave 5 diff and fix any new findings the same
way (all severities) before proceeding.

═══════════════════════════════════════════════════════════════════════
WAVE 6 — Tests & gate: everything green   (orchestrator + fix agents)
═══════════════════════════════════════════════════════════════════════
- Run `make ci` and `make audit`. Fix EVERY failure until both are fully green
  and `dart analyze` reports 0 issues — INCLUDING pre-existing failures (e.g. the
  ~9 `directives_ordering` infos from the owner's text_input_formatters WIP:
  sort those imports / run `dart fix --apply`).
- Re-run the sync/story suites touched by this work; fix any regression.
- Produce a final report: every commit grouped by wave; B1–B11 status; before/
  after for the Completion and all-curricula Lifetime numbers; any follow-ups.

DO NOT, at any point: create worktrees or branches; let two agents in a wave
share a file; skip a gate; defer a medium/low review finding; commit the owner's
text_input_formatters WIP as if it were your work (Wave 6 only sorts its imports
to green the gate); bypass hooks.
```
