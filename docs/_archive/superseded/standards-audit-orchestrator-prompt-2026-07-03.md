# Full-Codebase Standards Audit — Orchestrator Prompt

**Mission:** audit every hand-written file in this repository against `docs/coding-standards.md` (revision 2026-07-02) and the architecture documents, using parallel Sonnet subagents, and produce **one recommendations document** whose findings are ready to be converted 1:1 into Linear tickets (team `DNI`, project `learning-tracker`). No effort spared: full manifest coverage, every severity down to P3/minimal, every finding adversarially verified before it is published.

**Voice:** Martin Fowler chairs; Michael Feathers (testability/legacy), Eric Evans (domain integrity), and Michael Nygard (production resilience) are the named supporting lenses. Findings are written blunt and plain — name the defect, no diplomatic padding — but the adversarial posture lives in the *method* (presumption of guilt + refutation-based verification), not in theatrical language. Never present output as authored by the real people; the voice is an editorial lens.

---

## Part A — Posture

1. **Presumption of guilt.** Every file is assumed to contain at least one violation until it has been read in full and cleared. A batch agent that returns zero findings for a batch must say what it checked and why it cleared — "looks fine" is not a verdict.
2. **Evidence or it doesn't exist.** Every finding cites `file:line` with a minimal quote and states a concrete consequence (failure scenario, invariant at risk, or maintenance cost). Adversarial ≠ inventive: a finding without traceable evidence is fabrication and gets killed in verification.
3. **Include the small stuff.** P3/minimal findings (naming drift, missing `const`, a log-less catch, a 401-line file) are in scope and wanted — the downstream ticket pass will batch them. Severity honesty still applies: do not inflate a P3 to a P1 to make it survive review.
4. **One finding per root cause.** If the same defect appears at 23 sites, that is one finding with 23 listed sites, not 23 findings. Verifiers kill duplicates.
5. **Novelty filter.** Do not re-report: (a) anything `make audit` (22 checks), `dart run custom_lint` (9 rules), `flutter analyze`, or `make arb-parity` already flags — run them first and treat output as baseline; (b) the ten known items in the standards doc's **Current Compliance Gaps** table; (c) documented judgment calls (nested subcollections, hand-rolled lint list, bundled-avatars default) unless you bring *new* evidence. Violations of **[Pending]** rules ARE novel findings — discovering that backlog is half the point.
6. **Report coverage honestly.** Files not audited are listed `UNAUDITED` in the ledger. Silent sampling, silent truncation, or "spot-checked the rest" is a failed audit.

## Part B — Inputs (orchestrator loads these; batch agents get the digest)

1. `docs/coding-standards.md` — **the yardstick.** All rule IDs: Rule 0–5, SM-1..8, EH-1..6, DB-1..6, FB-1..9, SR-1..5, PV-1..6, AU-1..5, ST-1..2, PF-1..4, AX-1..4, TQ-1..9, AG-1..11, plus profileId-in-PK, naming conventions, placement guide.
2. `docs/architecture.md` (feature dependency graph, sync architecture, scheduler/streak algorithms), `docs/product-rules.md`, `docs/sync-conflict-resolution.md`, `docs/delete-policy.md`, `docs/data-models.md`, `docs/firestore-collection-layout.md`, `docs/hebrew-terms.md`.
3. Mechanical baseline (run before any agent spawns; store output as the novelty filter):
   ```bash
   cd learning_tracker && make audit; dart run custom_lint; flutter analyze; cd .. && make arb-parity
   ```
4. Hotspot list (deepest scrutiny where waves churned most):
   ```bash
   git log --format= --name-only -- learning_tracker/lib | sort | uniq -c | sort -rn | head -40
   ```

## Part C — Manifest and batching

Source of truth: `git ls-files`. Partition into tiers; every file lands in exactly one ledger row.

| Tier | Contents | Treatment |
|------|----------|-----------|
| 1 | `learning_tracker/lib/**`, `learning_tracker/test/**` excluding generated (`*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `lib/l10n/app_localizations*.dart`); `lib/l10n/*.arb` | Full read, per-file protocol (Part D) |
| 2 | `pubspec.yaml`, `analysis_options.yaml`, both `Makefile`s, `packages/custom_lints/**`, `tool/**`, `hooks/**`, `.github/workflows/**`, `firebase.json`(×2), `firestore.rules`, `firestore.indexes.json`, `functions/**`, android/ios manifests & build config | Full read, judged for correctness/security/drift |
| 3 | Generated files | Not line-audited; regenerate (`build_runner`, `gen-l10n`) → `git diff` must be clean; drift is a finding |
| 4 | `docs/**` (excluding `_archive/`, `test-artifacts/`) | Factual-drift check against code only |
| X | `_archive/`, `test-artifacts/`, lockfiles, binary assets | `EXCLUDED(reason)` |

**Batches** (each is one Sonnet subagent; keep batches ≤ ~30 files or ~6k lines, split large ones):
- One batch per feature (15): `features/<name>/**` lib + its mirrored `test/` files together — the agent judges code and its tests as a unit.
- `core/` split by subdirectory (~23 batches; group tiny dirs, split `database/` and `sync/` further).
- `app/` + `main.dart` + l10n ARBs = one batch. `test/story_acceptance/` split by epic (~8 batches). `test/helpers|fixtures|mocks` = one. Tier 2 = 3–4 batches (build/CI; lints/hooks/tool; firebase/rules/functions).
- Expect ~55–65 batch agents in the find stage. All fan-out agents run **Sonnet** (`model: 'sonnet'`); verification agents also Sonnet; synthesis runs on the orchestrator's own model.

## Part D — Batch-agent protocol (give verbatim to every Tier-1/2 agent)

For each file in your list:
1. **Read the whole file.** The violation is in the half you skipped.
2. **Applicability sweep** — check the rule families that apply to this file type:
   - Screens/widgets: Rules 2/5, SM-2..4, EH-5, PF-1..4, AX-1..4, naming/placement, presentation→data import ban.
   - Providers/notifiers: SM-1..8, EH-2/EH-6, Rule 6-adjacent greps (`DateTime.now`, Talker).
   - Repositories/DAOs/tables: DB-1..6, profileId-in-PK, SM-7/8, EH-2..4.
   - `core/sync/**`: FB-1..9, EH-2..4, Nygard lens mandatory (process death, offline, clock skew, permission-denied at every I/O point).
   - `core/analytics|logging|auth`, bootstrap: PV-1..6, AU-1..5, EH-1.
   - Tests: TQ-1..8 — tautological/over-mocked tests, weakened assertions (compare against what the source can actually do wrong), shared containers, wall-clock, golden nondeterminism.
   - `firestore.rules`/`functions`: SR-1..5, TQ-9.
   - Config/CI/Makefiles/hooks/custom_lints: Rule 0, AG-1..11 (bypassable gates, soft-skips, divergent targets, dead targets).
   - Everything: AG-3 (>400 lines), AG-4 (duplicate top-level names — report candidates; orchestrator dedups globally), AG-6 (untracked TODOs), dead code, EH-3.
3. **Lens pass beyond the rules** — Fowler (duplication, shotgun surgery, speculative generality, misplaced responsibility — name the refactoring), Feathers (can this be tested without booting Firebase/Drift? where's the seam?), Evans (is the ubiquitous language consistent? is this invariant enforced in one place or re-derived?), Nygard (what happens when this I/O fails halfway?).
4. **Verdict per file:** `SOUND` / `ISSUES(n)` / `DEFECTIVE` — plus findings in the schema below. Confidence: `CONFIRMED` (traced statically) or `SUSPECTED` (needs runtime/emulator confirmation — say what would confirm it).

**Finding schema (JSON, one object per finding)** — this is the ticket contract; every field is mandatory:
```json
{
  "id": "assigned-by-orchestrator",
  "title": "Imperative one-liner usable verbatim as a Linear ticket title",
  "severity": "P0|P1|P2|P3",
  "confidence": "CONFIRMED|SUSPECTED",
  "rule": "SM-4 | lens:nygard | ...",
  "area": "feature or core subdir",
  "evidence": [{"file": "path", "line": 123, "quote": "≤2 lines"}],
  "sites": 1,
  "why": "Concrete failure scenario or cost, 1–3 sentences",
  "recommendation": "The remedy + first mechanical step; named refactoring where apt",
  "effort": "S|M|L",
  "acceptance_criteria": ["testable done-condition", "checker/test that locks it in (Rule 0)"],
  "labels": ["suggested Linear labels"]
}
```
Severity: **P0** data loss / security / child-privacy / silent corruption · **P1** user-visible defect or violated named invariant · **P2** design debt with stated concrete cost · **P3** hygiene/minimal (still filed). Acceptance criteria must include the Rule-0 checker or regression test wherever the fix is checkable.

## Part E — Orchestration (Workflow script shape)

1. **Phase 0 — Baseline & manifest** (orchestrator, inline): run Part B tooling, build manifest + batches, compute hotspots.
2. **Phase 1 — Find** (parallel Sonnet fan-out): one agent per batch, Part D verbatim + file list + the rules digest + novelty filter (baseline output digest + known-gaps list). Returns findings JSON + ledger rows. Use `pipeline()` so verification starts per-batch without a global barrier.
3. **Phase 2 — Merge & dedup** (orchestrator or one agent): cluster by root cause across batches (same rule + same symbol/pattern → one finding, sites summed); assign IDs `AUD-<area>-<n>`.
4. **Phase 3 — Adversarial verify** (parallel Sonnet): every finding gets fresh-context skeptics who see only the finding + the cited files and are prompted to **refute** (wrong line? behavior actually correct? rule misread? already covered by a checker? duplicate?). P0/P1: 3 verifiers, majority must uphold, and each upholds only after re-reading the evidence file. P2/P3: 1 verifier. Verifier edits severity/confidence downward freely; upward only with new evidence. Killed findings are logged with the refutation (appendix, not silently dropped).
5. **Phase 4 — Meta-findings** (orchestrator): for each [Pending] rule with ≥1 confirmed violation, emit one meta-recommendation: "build checker X; violation backlog: n sites" — these become the enforcement tickets.
6. **Phase 5 — Completeness critic** (one agent): reads the ledger + register and answers "what's missing?" — unaudited files, rule families no batch applied, suspicious zero-finding batches, cross-cutting checks (AG-4 global dedup, dependency-graph reality vs `architecture.md`) not yet run. Its output either triggers a supplemental Phase-1 round or is recorded as an explicit gap.
7. **Phase 6 — Synthesize** (orchestrator's model): write the deliverable.

Budget/scale notes: ~55–65 finders + ~1 verifier per P2/P3 and 3 per P0/P1 — several hundred agents; cap concurrency at the pool default and let the queue drain. If token budget forces triage, cut *verifier count on P3s* first and *never* coverage — and say so in the report.

## Part F — Deliverable

One master document: `docs/audits/standards-audit-2026-07-03/_RECOMMENDATIONS.md`, plus machine-readable `findings.json` (the full schema objects — input for the Linear ticket-generation pass) and `_LEDGER.md` (every manifest file with verdict). Structure of the master doc:

1. **State of the Codebase** (2–3 pages, the chair's voice): what the codebase is trying to become, where conceptual integrity holds and frays, the systemic risks, what to stop doing. Opinionated and blunt, grounded in register IDs.
2. **Findings register** — every verified finding, grouped by area, ordered P0→P3 within each, each entry rendering all schema fields in readable form. Include the P3s; do not summarize them away.
3. **Meta-recommendations** — the Pending-checker tickets with violation counts.
4. **Roadmap** — sequenced tidy-first vs behavioral waves, each item pointing at finding IDs, with a do-first / do-next / defer rationale (risk retired per unit effort).
5. **Appendices** — killed-findings log (with refutations), coverage stats, unaudited/excluded list, baseline-tool output digest.

Every register entry must be self-sufficient for ticket creation: title, severity→priority mapping (P0→Urgent, P1→High, P2→Medium, P3→Low), description (= why + evidence + recommendation), acceptance criteria, labels, effort. The ticket pass should need zero re-reading of source.

## Part G — Calibration reminders for the orchestrator

- Adversarial means *hard to convince*, not *eager to accuse*. The kill-log is a quality signal: a healthy run kills 20–40% of raw findings.
- A finding that merely restates a rule ("file violates SM-3") without the failure scenario is incomplete — bounce it back or complete it from the evidence.
- Consistency beats heroics: identical defects must get identical severity across areas; sweep the register for severity drift before publishing.
- The register will seed *many* Linear tickets — titles must be unique, imperative, and self-locating (include the area/symbol, not "fix issue in file").
