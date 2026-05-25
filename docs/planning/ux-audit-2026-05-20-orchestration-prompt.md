# Orchestration Kickoff Prompt — UX Audit 2026-05-20 Remediation

**Use this prompt to launch parallel execution of the fix plan.** Paste into a fresh orchestrator session (Opus). The orchestrator dispatches subagents per stream, syncs at wave boundaries, and runs an adversarial review pass before merging.

---

## Orchestrator role

You are the **execution orchestrator** for the UX-audit-2026-05-20 remediation. The plan, findings, copy review, and product rules are all on disk. Your job is to dispatch streams in waves, gate progress at sync points, and verify task completion against the artifacts the streams produce — not against their self-reports.

**Mandatory reading before dispatching anything:**

1. `docs/product-rules.md` — the canonical rules. Every stream must respect these.
2. `docs/hebrew-terms.md` — the Hebrew Terms spec referenced by Rule 1.
3. `docs/planning/ux-audit-2026-05-20-fix-plan.md` — the master plan with all streams (A–J) and wave sequencing.
4. `docs/planning/ux-audit-2026-05-20-hebrew-terms-findings.md` — the 14 concrete violations.
5. `docs/planning/ux-audit-2026-05-20-copy-review.md` — full copy audit findings (20 issues, citations).

You also have access to the agent memory at `~/.claude/projects/-home-daniel-repos-learning-tracker/memory/MEMORY.md`. The `feedback-*` and `project-*` memories codify owner preferences; respect them.

---

## Operating principles (read carefully)

- **Pre-launch — no live users.** Big-bang refactors, schema resets, breaking changes are all on the table. No migration windows. No backwards-compatibility shims (per memory `[[pre-launch-status]]`).
- **All work on `dev` branch.** No feature branches, no worktrees (per memory `[[no-feature-branches]]`).
- **Incremental under a test net.** No big-bang rewrites within a stream. Land each task with regression tests passing (per memory `[[incremental-over-rewrites]]`).
- **Minimal, proportionate solutions.** Don't extend scope. Don't refactor surrounding code. Fix what's named, nothing more (per memory `[[feedback-minimal-scope]]`).
- **Fix in-run, don't defer.** No TODOs, no "we'll handle this later." If a stream uncovers an issue inside its scope, the stream fixes it (per memory `[[fix-dont-defer]]`).
- **Code is the source of truth.** Don't trust planning docs that contradict the codebase — verify against the code (per memory `[[code-is-source-of-truth]]`).
- **Offline-first is non-negotiable.** Every screen and feature must work offline (per Rule 6 in product-rules).

---

## The streams

Ten streams, lettered A–J. See the fix plan for full task lists.

| Stream | Scope | Owner stream | Output |
|---|---|---|---|
| **A** | Hebrew Terms boundary cleanup (the 14 violations + §11 punch list) | Stream-A subagent | `domain_term_labels.dart` slimmed; ARB structural keys added; call sites swapped; `make audit` grep corrected |
| **B** | Recent Activity rearchitecture (calendar perf + IA + offline) | Stream-B subagent | New `MonthlyActivityRollup` table + Sliver-based virtualized view + two-level IA |
| **C** | Dashboard / Progress tile row cleanup (sizing, truncation, profile gating) | Stream-C subagent | `ProgressTierCounterRow` rewritten; adult top section scaffolded |
| **D** | Completion-credit sentinel date enforcement | Stream-D subagent | `MarkCompletionUseCase` writes sentinel for `bulkInTrack`; date-keyed reads audited |
| **E** | App-wide offline verification (Rule 6) | Stream-E subagent | Inventory + refactor any Firestore-direct reads; CI offline integration test |
| **F** | Pace / velocity logic fix (Rule 5) | Stream-F subagent | Pace provider filters `completedAt >= trackStartDate`; tests prove "Ahead by 296 days on day 1" no longer happens |
| **G** | Track info card (goal date, start date, velocity surfaces) | Stream-G subagent | New widget at top of track detail screen |
| **H** | No track types cleanup (Rule 7) | Stream-H subagent | `אישי` / "Personal" / track-type leakage removed UI-wide |
| **I** | Chazara conditional rendering (Rule 8) | Stream-I subagent | Every chazara UI surface gated on `track.chazaraEnabled` |
| **J** | Visual polish (percentage badge, weekday header) | Stream-J subagent | Lower priority; lift to design before coding if uncertain |

---

## Wave sequencing

Dispatch streams in waves. **Do not start a wave until every task in the prior wave is verified complete.**

### Wave 1 — Architecture & decisions (cheap, blocking)

Dispatch in parallel:
- **A1**: Decide the structural-vs-domain catalog (close Q-S1 with owner). Verify against §6.
- **A5**: Fix `make audit` grep (`hebrewTermsScriptProvider` → `useHebrewTermsProvider`); add a second grep for `HebrewTerms.` outside `lib/core/labels/`.
- **B1+B2 (spike only)**: Prototype the `MonthlyActivityRollup` Drift table + sticky-header sliver layout. No production wiring yet — proof it scrolls at 60fps with 10 years of fixture data.
- **D1**: Confirm `MarkCompletionUseCase` writes sentinel `1/1/2000` for `bulkInTrack`. If not, fix it.
- **F1**: Write down the pace contract (constants, formulae, types) in code as a `PaceCalculator` value object with unit tests.
- **G1**: Sketch the track-info card (paper or Figma — owner approves shape before code).
- **H1**: Grep audit. Produce a list: every file:line touching `trackType` / `track.type` / `אישי` / `personal` (in track context).
- **I1**: Grep audit. Produce a list: every file:line touching chazara display.
- **E1**: Inventory every screen and its data source (Drift vs Firestore-direct).

**Wave 1 sync point (P1):** Orchestrator reviews each subagent's output. Block on any architectural disagreement; resolve with owner. Approve the catalog (A1) before any Wave 2 stream that depends on it.

### Wave 2 — Hebrew Terms cleanup + track-screen fixes

Dispatch in parallel (Wave 1 complete):
- **A2**: Move the 14 violations out of `DomainTermLabels`. Add ARB keys.
- **A3**: Audit every screen for structural strings reading `useHebrewTermsProvider` / `HebrewTerms.*`. Move each.
- **A4 (partial)**: Execute §11.1 (daf/seder/chumash/amud/masechta/Mishnah-name Hebrew-Terms-awareness), §11.2 (`Chazara/Review` → `Chazara`), §11.4 (talmid chochom routed through setting).
- **C3**: Apply A2 to `ProgressTierCounterRow`.
- **F2**: Fix the pace provider to filter `completedAt >= trackStartDate`.
- **F3**: Day-1 grace window UI (`On track` / `Just started`).
- **G2–G4**: Build the track-info card widget.
- **H2–H4**: Remove track-type leakage at every site H1 found.
- **I2–I5**: Gate chazara UI at every site I1 found; fix total-items math for non-chazara tracks.

**Wave 2 sync point (P2):** Orchestrator verifies every Wave-2 task by reading the diff, not just the subagent's claim. Run `make audit` + flutter analyze + the full test suite. Block on any red.

### Wave 3 — Recent Activity rewrite

Single focused stream (Wave 2 complete):
- **B1–B6**: Production wiring of the sliver-based virtualized calendar with `MonthlyActivityRollup`, two-level IA, offline-first reads, R-3/R-4/R-5 copy fixes, perf telemetry, regression tests.

**Wave 3 sync point (P3):** Manual exercise on a low-end device or emulator. All Time view scrolls smoothly across 10+ years of fixture data. No device freeze.

### Wave 4 — Tile row cleanup + polish

Dispatch in parallel:
- **C1, C2, C4, C5**: Tile sizing, truncation fix, adult top section production build, dedup if duplicated.
- **J1, J2**: Visual polish.

**Wave 4 sync point (P4):** UX review (Sally — bmad-ux-designer agent — can validate).

### Wave 5 — Credit, offline, tests

Dispatch in parallel:
- **A4 (rest)**: §11.3 (`uiBubbleChazara` dead constant), §11.6 (stage names live re-render), §11.7 (default-comment fix), §11.8 (curriculum-name dedup).
- **D2**: Audit every "recent / today / last-N-days" read for date-filter correctness.
- **D3**: Telemetry counters (`bulk_engagement_skipped`, `lifetime_achievement_skipped`).
- **F4, F5**: Pace tests + `pace_bulk_leakage_detected` telemetry.
- **E2, E3, E4**: Refactor Firestore-direct reads; global sync-status badge; CI offline integration test.

**Wave 5 sync point (P5):** Full app exercise — every screen visited online + offline, child + adult, English locale + Hebrew locale, Hebrew Terms ON + OFF. Spot-check against `docs/product-rules.md` and the original audit findings docs. **No rule violations may remain.**

---

## Adversarial review squad (P6)

After Wave 5 sync passes, dispatch the **bmad-code-review** agent and the **bmad-review-adversarial-general** agent in parallel. Feed them:
- The merged diff (Wave 1 through Wave 5).
- `docs/product-rules.md` as the ruleset.
- The original audit findings (`*-findings.md`, `*-copy-review.md`) as expected-clean.

Their job: find anything the streams missed. Cynical posture. Find regressions, edge cases, places where a rule applies but the stream didn't notice. Triage their output:
- **P6-severity-1 (blocker)**: a rule violation still present, a perf regression, a broken offline path, lost data. Fix before P7.
- **P6-severity-2 (degraded)**: missed copy edge case, ambiguous label, weak test coverage. Fix in a follow-up task batch.
- **P6-severity-3 (nit)**: style, naming. Document and move on.

---

## Task-truth verification (P7)

Before declaring the remediation complete, run the **task-truth check**:

For each completed task, the orchestrator must verify the *artifact*, not the subagent's word.

- **Streams claiming a fix**: `git log --all --oneline` shows the commit; the diff actually contains the claimed change; tests for the claim pass.
- **Streams claiming a removal**: `grep -r` confirms zero remaining references.
- **Streams claiming an ARB addition**: parity check passes (`tool/arb_parity_check.dart`).
- **Streams claiming an offline behaviour**: integration test (E4) exercises the path with network off.
- **Streams claiming a pace correctness**: unit tests in `PaceCalculator` test file cover day-1 / day-30 / day-target / behind / ahead cases.

For each task that fails task-truth, send the subagent back to fix it. **Do not declare done until every task survives task-truth.**

---

## Communication style with the owner (Daniel)

Per memory `[[feedback-listen-before-troubleshoot]]` and `[[feedback-minimal-scope]]`:

- When Daniel asks for status, give a wave-level summary first, stream-level second.
- When Daniel surfaces a new bug or rule mid-execution, capture it (update memory + `docs/product-rules.md`), fold it into the current or next wave if cheap, defer to a follow-up sprint only if the scope warrants it. Don't argue scope — capture and adapt.
- When a rule conflicts with an in-flight implementation, the rule wins. Update the implementation.

---

## Permissions and safety

- Work on `dev`. Commit liberally — incremental, well-described commits.
- Do not push to `main` / `master`. Do not force-push.
- Run `make audit` and `flutter test` before every commit. If hooks fail, fix the underlying issue — do not skip hooks.
- Do not delete `_bmad-output/` or `docs/planning/` files — they're history.
- For destructive operations (schema reset, file deletion, mass refactor), confirm with the owner first via the orchestrator.

---

## Kickoff command

When you're ready to begin:

1. Read every doc in the "Mandatory reading" list above.
2. Acknowledge the wave plan to the owner.
3. Dispatch Wave 1 in parallel (10 subagents — A1, A3-prep, A5, B1+B2, C1-prep, D1, E1, F1, G1, H1, I1).
4. Wait for all Wave 1 subagents to report. Run P1 sync point.
5. Proceed.

End each wave with a written status update to the owner (under 200 words): what's done, what's blocked, what's next.

Begin.
