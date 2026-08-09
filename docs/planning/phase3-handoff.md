# Phase 3 handoff — Firestore cutover, "Wire and move"

**You are a fresh agent with no memory of Phase 2.** This prompt is the entire
context you need to start. It was authored by Phase 2's own closing round
(P2-35), from Phase 2's own measured state, per this project's Working
Protocol rule 15 ("each phase's CLOSING step authors the NEXT phase's handoff
... never speculatively, in advance"), and **hardened one round later (P2-36,
docs-only)** against a red-team pass and an independent cold-read (an agent
given only this document and told to follow it) — both run against the
as-shipped P2-35 version. Everywhere P2-36 changed a number or a claim, it is
because the original was found stale, unverifiable, or contradicted by
another document, not for style. Full change list: the **P2-36** entry in
`firestore-cutover-log.md`. Everything below is either a standing owner
instruction, a fact re-derivable from the repo, or a number explicitly
attributed to who measured it and at which commit. Where a number is a "last
known" figure rather than something you yourself measured, it is labeled as
such — re-measure it before you trust it (§2 tells you how and why). Where a
number is prone to changing as soon as you touch code, this document gives
you the COMMAND to recompute it instead of a number that will go stale.

Repo: `/home/daniel/repos/learning-tracker`. App: `learning_tracker/`. Branch:
`dev`. This document lives at `docs/planning/phase3-handoff.md`.

---

## 0. Owner's standing operating instructions (verbatim in effect)

These are not Phase-3-specific; they are how this owner runs every phase of
this project. Follow them without being asked again.

1. **Sonnet subagents do the actual work** (reading, editing, running
   tests); **Opus subagents do code review, planning, adversarial
   verification, and design.** If your harness exposes a named
   multi-agent/orchestration tool, use it to run this division of labor; if
   it does not, proceed directly and preserve the DIVISION OF LABOR anyway
   (implement, then have a separate pass — a separate agent turn, or at
   minimum a separate, adversarial re-read — review before you certify a
   fix, per Working Protocol rule 11/trap #11 below). The division of labor
   is the instruction; the tool name is not load-bearing.
2. **Run autonomously. Make sensible decisions without asking.** The owner
   has granted standing authority to override his own earlier rulings when
   they are demonstrably producing bad outcomes — when you do, report what
   you overrode and why, in the same commit's log entry.
3. **Never push. Never deploy. Never create a branch or a worktree. Never
   `git stash`. Never `git add -A`.** Local commits on `dev` only, explicit
   paths staged by name (`git status --porcelain | grep -v '^ M _bmad'` to
   check what's dirty before staging — `_bmad` churn is pre-existing and not
   yours to touch).
4. **GREENFIELD.** No live users, no data worth preserving. Never build
   backfills, migrations, dual-write bridges, version gates, rollout flags,
   or back-compat readers. Delete the old path in the same commit that adds
   the new one. Prefer REMOVING a divergence over ADDING a guard.
   Correctness is not relaxed by this ruling — it only removes the need for
   transitional machinery. This ruling is what let Phase 2 close `T-49` by
   deleting a write instead of relocating it a fifth time (Working Protocol
   rule / trap #1, §5 below) — expect the same shape to be the right answer
   repeatedly in Phase 3.
5. **`T-30`/`T-31` (tutoring) are IN Phase 3**, re-phased out of Phase 2 by
   an owner ruling (`firestore-phase2-plan.md` §3, Q1, 2026-08-06) because
   their coupling is blocking, not stylistic — see §4 below for the
   evidence. They land as ONE commit-unit with `T-20`, not before it.
6. **A doc comment your change makes false gets fixed in the SAME commit, in
   the CODE, not only in the `.md` files.** A docs-only round may DISCLOSE a
   false code comment it finds (name a task, quote the false text), but
   cannot CLOSE it. This recurred in Phase 2 as `T-50`, `T-49`, and `T-67`.
   **Two such live false claims are sitting in code TODAY, disclosed but not
   closed, and Phase 3 is the first code-touching phase able to close
   them — do not let this become a fourth/fifth recurrence by leaving them
   for Phase 4.** See `T-67`/`T-68` in §4.

---

## 1. Read-first order

Read in this order, before writing any code:

1. **`docs/planning/firestore-cutover-log.md` — IN FULL.** It is large and
   grows every round — run `wc -l docs/planning/firestore-cutover-log.md`
   yourself for today's exact count rather than trust a number here (one
   was cited and already wrong by the commit that added it, corrected
   2026-08-09/P2-37 by removing the number rather than re-measuring it
   again) — too big for a single read call in most harnesses; read it in
   chunks, but read the WHOLE file, not just the head. It is the recovery
   log: recovery protocol, IN FLIGHT protocol,
   the Working Protocol (binding for Phases 3/4/5 — **16** numbered rules
   as of P2-37 — if you count and get 15 or 12, you stopped at an old
   copy; re-grep `^[0-9]\+\. \*\*` under `## Working protocol` to confirm
   you have all 16), `CURRENT STATE`, Standing Facts, the PHASE 2
   RETROSPECTIVE, then the dated `### ` entries.
   **How this file's own entries, numbered sub-tables, and heading
   conventions work is now specified DURABLY in the log's own Working
   Protocol rule 16 — read it there, not here, so this handoff does not
   drift from it the way its own predecessor did (an audit found the
   convention fully written into `phase3-handoff.md`'s P2-36 version but
   never landed in the log itself, giving it a one-phase lifespan; P2-37
   moved it).** Two pieces of state specific to reading THIS handoff at
   THIS commit, not part of the durable convention itself:
   - As of this handoff the highest lettered-table variants are **§10c**
     (deferred verification) and **§11c** (Phase 3 ENTRY CRITERIA) —
     re-grep `grep -n "^#### [0-9]\+[a-z]*\."
     docs/planning/firestore-cutover-log.md` before trusting that this is
     still true; neither P2-36 nor P2-37 added a `§10d` or `§11d` (both
     changed no D-row and no checkbox — see rule 16's own last bullet).
   - `CURRENT STATE` is a single-valued snapshot, NOT part of the
     append-only history below it — always read it fresh, not
     incrementally, and note that by the end of Phase 2 it still contained
     several nested "(Superseded paragraph below, from P2-N...)" chains
     that a future round is explicitly invited to collapse (Working
     Protocol rule 8) — don't mistake a superseded paragraph for the
     current one.
2. **`docs/planning/firestore-cutover-plan.md`** — the phases and the
   anti-slop protocol. Phase 3/4/5 each carry their own "Entry criteria and
   traps" subsection (added 2026-08-09, hardened 2026-08-09 at P2-36),
   which is Phase-3-specific detail this handoff summarizes but does not
   replace — read Phase 3's subsection there directly (`### Phase 3 — Wire
   and move`). **This is also the "plan section" the IN FLIGHT protocol
   (log.md, top of file) asks you to cite** when you open your own commit
   boundary — cite it as `firestore-cutover-plan.md` § Phase 3 — Wire and
   move. There is no separate numbered `firestore-phase3-plan.md` yet; if
   you want the phase2-plan.md-style numbered per-commit edit list (worked
   example: `firestore-phase2-plan.md` §4), you may author
   `docs/planning/firestore-phase3-plan.md` yourself — genuinely useful,
   but not a blocking prerequisite the way `T-39` is.
3. **`docs/planning/firestore-cutover-tasks.md`** — the durable, single
   source of truth for task status. Every task id this handoff cites has
   its full evidence in that file's own row; this handoff does not
   duplicate it, only points at it — **with one deliberate exception:
   §3's known-issues table below carries a `Status` column, a point-in-time
   SNAPSHOT, not a second source of truth; see §3's own note for why that
   is not a contradiction of this sentence.**
4. **`docs/planning/firestore-phase2-plan.md`** — read this only as a
   WORKED EXAMPLE of what a frozen phase plan looks like (a numbered,
   per-commit edit list, `P2-1` … `P2-N`). It is self-stamped "tree
   `d74e3829`," predates all seven rounds of the `T-49` saga, and its
   line-number citations are long stale. Do not treat any fact inside it as
   current — it records Phase 0/2 decisions (notably the `T-30`/`T-31`
   re-phasing ruling in §3, Q1) that are still binding, but for anything
   about the CODE, prefer the log. **This is the ONE document of the four
   above that is intentionally frozen** — when §5 trap 14 says "grep all
   THREE planning docs," it means #1–#3 (log, plan, tasks): the three that
   get updated every round. Do not edit `firestore-phase2-plan.md`, and do
   not count it toward "all three."
5. **This document**, `phase3-handoff.md` — you're reading it.

The recovery protocol (log.md's own `## Recovery protocol` section — as of
this handoff, lines 15-71, covering both the numbered steps and the "If a
session died mid-build" subsection; re-grep `^## Recovery protocol$` and
`^## IN FLIGHT protocol$` for the current bounds rather than trusting these
line numbers, which will drift) says to run it BEFORE reading the plan or
the task list. This handoff reorders that slightly only because you need the
log's own content to know what the recovery protocol even checks against —
but §2 below is still your first ACTION, before any code edit.

---

## 2. FIRST ACTION: re-establish the suite baselines yourself

**Read this before touching any code.** The full test suites (`make test`,
`make test-rules`, `make test-functions`, and the three cheap gates) were
LAST RUN by the round-7 independent verifier at commit `6655f184`, and
LAST RE-CONFIRMED as still attributable to the current code (via an empty
`git diff --stat 17134b43..HEAD -- learning_tracker/lib learning_tracker/test`)
at several later docs-only commits (P2-32 through P2-36) — every one of
those re-confirmations was a **read-only tree-identity check**, not a fresh
test run. **No agent has actually re-run the full suites since `6655f184`.**
This matters specifically to you: inheriting an unmeasured baseline means you
cannot tell YOUR first regression from one you inherited unmeasured. Do not
start editing code on the strength of the numbers in this document — they
are LAST KNOWN, not a warranty.

**This section describes the state as of commit `e5a97f6b` (P2-35) and its
subsequent docs-only re-confirmations through P2-37. It becomes false the
moment YOUR OWN FIRST ACTION below completes** — at that point you, not
this document, hold the current baseline. Do not "fix" this section
afterward to reflect what you just measured; record your own numbers in
your own commit's log entry instead (per the placement convention, Working
Protocol rule 16), and let this document be superseded wholesale by Phase
3's own closing round writing Phase 4's handoff, per Working Protocol rule
15 — that is the mechanism that retires this section, not an edit to it.

Run this now, before any edit:

```bash
cd /home/daniel/repos/learning-tracker
git log --oneline -5
git rev-list --left-right --count origin/dev...dev   # want: 0 <n>. This project NEVER pushes
                                                       # (§0 rule 3), so n grows every round — that
                                                       # is expected, not a red flag. Investigate only
                                                       # if the LEFT count is nonzero (something is on
                                                       # origin/dev that isn't on dev) or n drops
                                                       # (commits vanished).
git status --porcelain | grep -v '^ M _bmad'          # _bmad churn is pre-existing, ignore it
git stash list                                        # want exactly 2 — see §8, a 3rd is a RED FLAG
pgrep -af flutter | grep -v pgrep || echo 'no flutter process'
                                                       # orphaned test process check — this machine has
                                                       # held one for 4+ days before; it burns CPU and
                                                       # skews timing you observe. (Do not use
                                                       # `pgrep -af "flutter[ ]test"` alone and trust an
                                                       # empty/nonempty result without checking whether
                                                       # pgrep's own invocation matched itself — the
                                                       # `grep -v pgrep` above removes that ambiguity.)

cd learning_tracker
dart analyze --fatal-infos
dart run tool/check_profile_path_keying.dart
dart run tool/check_profile_id_int_sites.dart
make audit                       # MUST run from learning_tracker/, never the repo root — see §7
make test                        # ~8.5 min (per the LAST KNOWN `08:54` timing in
                                  # the table below, @ 6655f184 — not a guarantee,
                                  # time your own run)
make validate-calendar           # duration not recorded anywhere in this project's
                                  # history — do not assume a number; this is YOUR
                                  # first action too, not a Phase-4 problem: see below
make test-serial-tools           # ~32 min (per the LAST KNOWN `32:16` timing in the
                                  # table below, @ ~3872fdbc, NOT re-measured since —
                                  # T-69), serial lane, run it alone
```

Then, ONE AT A TIME with ports confirmed free first (`ss -ltnp | grep -E
':8080|:9099|:4400'`):

```bash
make test-rules
make test-functions
```

**`make validate-calendar` and `make test-serial-tools` are `T-69`, and they
are YOURS to run before your first code edit, not Phase 4's.** Neither has
run against the code since round 5 (`~3872fdbc`, two code commits before
`17134b43`) — every later "measurement" of them in this document and in the
log is a LAST KNOWN figure, not something anyone re-ran. `make test` does
**not** cover `make test-serial-tools` — `Makefile`'s `test:` target passes
`--exclude-tags "serial-tools || quarantine"`, so a green `make test` is not
evidence about the serial lane. Running both now, once, and recording the
real result (pass/fail, with the actual output) discharges `T-69` and
supersedes deferred-table row `✦D24` and the `make validate-calendar` row in
the SAME commit as whatever else you land first (Working Protocol rule 7).
**Watch for a `Terminated` line and a missing `EXIT=`** — the last recorded
`make test-serial-tools` attempt in this project ended `09:14 +19 ~1 -1`
with a `Bad state: Cannot close sink while adding stream` error and no
`EXIT=` line at all; that is a killed process (a session limit or timeout),
not a red test — see the callout at the end of this section.

**LAST KNOWN numbers to compare against** (all measured by the round-7
independent verifier at commit `6655f184`, code-identical to `17134b43` —
the commit that actually landed Phase 2's `T-49` fix — and reconfirmed
identical, by tree-diff only, through later docs-only commits):

| Command | Last known result | Last actually measured at |
|---|---|---|
| `dart analyze --fatal-infos` | `No issues found!`, exit 0 | `6655f184` |
| `dart run tool/check_profile_path_keying.dart` (check 103) | `PROFILE-KEY-SPLIT check OK: 2 collection(s) currently split (bookmarks, learning_order), 0 new violations`, exit 0 | `6655f184` |
| `dart run tool/check_profile_id_int_sites.dart` (check 104) | `PROFILE-ID-INT-SITES OK: 88 tracked entries covering 91 site(s) across 5 pattern(s); 0 new, 0 stale, 0 changed`, exit 0 | `6655f184` |
| `make audit` | `104/104 checks; === audit PASSED — all 68 greps clean ===`, exit 0 | `6655f184` |
| `make test` | `08:54 +11527 ~131: All tests passed!`, exit 0 | `6655f184` |
| `flutter test test/features/profiles/` | `00:12 +441: All tests passed!` (433 baseline + 8 new) | `6655f184` |
| `make test-rules` (alone) | `pass 116 fail 0`; TQ-9: all 37 conditional allow rules evaluated at least once | `6655f184` |
| `make test-functions` (alone) | `pass 337 fail 0` | `6655f184` |
| `make validate-calendar` | `OK: 62068 expected (program, date) pairs all present, every ref resolves`, exit 0 | `~3872fdbc` (round 5 — NOT re-measured since; see above, this is `T-69`) |
| `make test-serial-tools` | `32:16 +38 ~1: All tests passed!`, exit 0 (the `~1` is `T-38`'s pre-existing disclosed skip) | `~3872fdbc` (round 5 — NOT re-measured since; see above, this is `T-69`) |

**`dart format --output=none --set-exit-if-changed`** — run this against
whatever files YOUR commit touches, every commit; the count of files it
last checked (a per-round figure, not a phase baseline) is not useful to
you and is intentionally not reproduced here. It must return `0` changed
before you commit.

**Never run, this cutover or any prior phase:** `make ci` in a single
invocation (owner policy batches it to the end of Phase 4 — see §4 and §7
for what this means for Phase 3's own per-collection verification step,
which is `make audit` + a targeted `flutter test`, NOT `make ci`).

**Coverage** (`coverage/lcov.info`): regenerated by every `make test` run —
its byte size and mtime as of any past commit are not meaningful to record
here and will be wrong the moment you run `make test` yourself. Check
`ls -la coverage/lcov.info` after your own `make test` run if you need to
confirm it was regenerated (mtime should be after your run started). R6d
(`check_lcov_denominator.dart --strict`)'s last explicit result (P2-21):
`76` zero-coverage files, `0` new violations — not re-measured since; `make
audit` re-runs R6d every time, so you get a fresh number for free the first
time you run it.

If anything above comes back different from what you just measured: name
the difference explicitly (predicted / actual / mechanism / whether any
invariant is affected — see the deviation-reporting shape used throughout
`firestore-cutover-log.md`). Do not silently update the number in your head
and move on, and do not assume a difference is a regression you caused
before checking whether it predates your first edit.

**A killed test run manufactures fake red tests.** Before reading any
suite's failure count, check for a `Terminated` line and an explicit
`EXIT=` code. A `make test-serial-tools` attempt during Phase 2 ended
`09:14 +19 ~1 -1` with a `Bad state: Cannot close sink while adding stream`
error and no `EXIT=` line at all — that is a killed process (a session
limit or timeout), not a code failure.

---

## 3. Where Phase 2 landed

**Verdict:** `T-49` (the phase's one SERIOUS code defect — a
write-after-await race on `activeProfileDocIdProvider`, the provider that
keys all 13 profile-scoped Firestore providers) is **CLOSED, by REMOVAL**,
in commit `17134b43` (`fix(profiles): delete the T-49 activation write
instead of hoisting it a fifth time`). `FirestoreProfileRepositoryAdapter`
no longer writes `activeProfileDocIdProvider` on any path; `select()` in
`profile_providers.dart` is the sole activation seam. This closure is
**confirmed by a review independent of the fixing round** (the round-7
verifier, at commit `6655f184`), which is the mandatory step this project's
own rule requires ("a round cannot certify its own fix" — §5 trap #11,
below) — the four PRIOR closure attempts (P2-18, P2-23, P2-28, and the fix
P2-29 reviewed) each lacked this and each was later falsified.

**Phase 2 AS A WHOLE is recorded NOT RESOLVED**, per this project's own
DECISION RULE (a disjunction — ANY of: verdict incomplete, `safe_for_phase_3`
false, `still_open_unrecorded` non-empty, an unguarded post-await write
found, or a new blocking defect found ⇒ NOT RESOLVED, blockers named and
owned by task id, Phase 3 explicitly blocked). The rule fires here on
exactly one item: **`T-39`** — untouched by every one of Phase 2's rounds,
and Phase 3's own declared entry blocker (§4 below). The rule is
mechanical, not a judgment call on severity: `T-49` (the phase's only
SERIOUS code defect) is genuinely closed, and `T-39` alone is still enough
to keep the verdict NOT RESOLVED.

**What's live on Firestore (4, unchanged since before Phase 2):** bookmarks
· learning-order · profile identity · scheduler learning-order read.

**What's still int-keyed / dead — TWO DIFFERENT LISTS, NOT YET RECONCILED
(that reconciliation is `T-39`, §4):**

- **CURRENT STATE's hand-maintained list, by FEATURE name** (verbatim from
  the log): `completion · curriculum-track · goal · progress ·
  stage-definition · study-day-config · track-learning-order` (7).
- **The same 7 collections' feature-level Adapter CLASSES**, built, tested,
  never constructed by the app: `FirestoreCompletionRepositoryAdapter`,
  `FirestoreCurriculumTrackRepositoryAdapter`, `FirestoreGoalRepositoryAdapter`,
  `FirestoreProgressRepositoryAdapter`, `FirestoreStageDefinitionRepositoryAdapter`,
  `FirestoreStudyDayConfigRepositoryAdapter`, `FirestoreTrackLearningOrderRepositoryAdapter`
  — under `lib/features/**/data/repositories/`.
- **Check 103's WATCHLIST names a DIFFERENT class layer**, under
  `lib/data/repositories/` (no `Adapter` suffix — e.g.
  `FirestoreCompletionRepository`, not `FirestoreCompletionRepositoryAdapter`):
  these are the low-level Firestore-document classes the Adapters above
  wrap. Confirmed by reading `tool/check_profile_path_keying.dart`'s
  `_repositoryDirSegment = '/data/repositories/'` constant and its
  reachability scan this round (P2-36) — this is a structural fact about
  the tool, not something that changes when you re-run it, but the
  WATCHLIST's own MEMBERSHIP (which collections appear) is dynamic and
  DOES change as code moves — **do not hardcode a count for it; run
  `dart run tool/check_profile_path_keying.dart --report` and read the
  `--- WATCHLIST (N) ---` line yourself.** (`_kCollections`, the FULL
  profile-scoped collection registry the tool cross-checks against
  `firestore.rules`, is a fixed 17 — confirmed by reading the constant at
  `tool/check_profile_path_keying.dart:233-250` this round — but 17 is the
  registry size, not the WATCHLIST size; do not conflate the two.)

**The scale of the move — re-measured this round (P2-36), the prior `135
files / ~96 feature files` figures were wrong, use these:**

```
$ grep -rl 'import .*core/database' lib --include=*.dart | wc -l
166
$ grep -rl 'import .*core/database' lib/core/database --include=*.dart | wc -l
49
$ grep -rl 'import .*core/database' lib/core/sync --include=*.dart | wc -l
14
$ grep -rl 'import .*core/database' lib/features --include=*.dart | wc -l
90
```

166 total, not 135; 49 inside `lib/core/database` (the Drift layer itself,
stays until Phase 4), not 25; 14 inside `lib/core/sync` (dies in Phase 4);
**90** inside `lib/features` (not "~96") — the closest thing to "files
Phase 3 needs to move." **The arithmetic does not close: 166 − 49 − 14 =
103, not 90 — there are 13 further files that import Drift from OUTSIDE
`lib/core/database`, `lib/core/sync`, AND `lib/features`** (`lib/app/**`,
`lib/core/providers/database_provider.dart`,
`lib/core/analytics/parent_analytics_repository.dart`,
`lib/core/navigation/guards/*_guard.dart`, `lib/data/firestore/*`). Re-run
the four commands above yourself before trusting any of these numbers —
they will change as you move files — and don't assume "zero files under
`lib/features/**` import Drift" (§4's exit criterion) accounts for those 13;
it doesn't, by construction, since they're outside `lib/features/**`. Check
whether each of the 13 needs to move too, or is legitimately allowed to keep
a Drift import (e.g. a guard reading local-only state that has no Firestore
equivalent) — this handoff does not know which, because it changes as
Phase 3 removes call sites.

**Full known-issues table, task id per item, one line each** (reproduced
from `firestore-cutover-log.md`'s §2 in the P2-33 entry — read each row's
own task-file entry in `firestore-cutover-tasks.md` for full mechanism and
evidence, not duplicated here). **This table, INCLUDING its `Status`
column, is a SNAPSHOT as of `e5a97f6b`/P2-36, unchanged at P2-37 — do NOT
maintain it as you close tasks, and do not treat it as authoritative the
moment any status here diverges from `firestore-cutover-tasks.md`'s own
row (which it will, as soon as you close anything). `firestore-cutover-
tasks.md` remains the sole durable source of truth for CURRENT status;
this column exists only to save you a lookup on your first read, not to
be kept in sync — corrected 2026-08-09, P2-37, per §1 point 3's own
"does not duplicate it" claim, which this table was the one place that
claim did not hold.**

| ID | Phase | Status (snapshot @ `e5a97f6b`/P2-36 — NOT maintained; see `firestore-cutover-tasks.md` for current) | One-line note |
|---|---|---|---|
| `T-39` | 3 | **`todo` — SOLE DECLARED PHASE 3 ENTRY BLOCKER** | Reconcile check 103's WATCHLIST against the dead-adapters list before wiring anything — see §4, do not trust a specific count from any document, re-derive it. Prerequisite for `T-20`. |
| `T-69` | 2 | `todo` (new, P2-33) | Re-run `make validate-calendar` and `make test-serial-tools` against the current code — this is your FIRST ACTION, §2, not a Phase 4 problem. |
| `T-65` | 3 | `todo`, MINOR (P2-32) | Design residual R1 — six post-await `select()` call sites guarded only by widget/screen liveness, not a selection re-check. Strictly better than pre-Phase-2 (both providers now agree, even if on the wrong profile) — not closed. |
| `T-66` | 2 | `todo`, MINOR (P2-32) | The 14-case permanent T-49 matrix has no case for `ensureDefaultProfile`'s FAST path; GROUP-3's gate is unreachable on it by construction. Verifier's `E2-fast` probe went RED on the reverted tree, confirming a real, previously-unprobed site. |
| `T-67` | 2 | **`todo`, but CLOSE IT IN PHASE 3** — MINOR as code / SERIOUS as an unqualified claim (P2-32, enriched P2-33) | CONTROL-4's regex has a demonstrated 40-character blind spot, PLUS an unnamed aliased-notifier evasion and a trailing-comment false-positive. The overbroad "structurally impossible" claim still stands in the test's own printed NAME (emits on every run). See §4. |
| `T-68` | 2 | **`todo`, but CLOSE IT IN PHASE 3** — MINOR, pre-existing, dates to `a3c92d6c` (P2-32) | `profile_repository_impl.dart`'s doc comment (around line 618 as of this handoff — re-grep, it moves) claims a single-line grep "returns every one of them and nothing else" for the activation call sites; re-run it this round (P2-36): it returns **3 of 14** real call sites (11 use the multi-line `.read(...)\n.select(...)` form the pattern can't match). See §4. |
| `T-44` | 2 | `todo`, MINOR (P2-13) | `T-41`'s refusal relocates the second-identity outcome (a fresh ULID mint) instead of preventing it. Needs a product decision. |
| `T-46` | 2 | `todo`, MINOR, informational (P2-13) | `T-41`'s export/import fix has no production caller. Correct hygiene, closes zero runtime risk today. |
| `T-55` | 2 | `todo`, MINOR, informational (P2-21) | ~60 further ulid-less test seeders beyond the 9 known/fixed instances, none currently failing. Needs a decision. |
| `T-60` | 5 | `todo`, MINOR (P2-26) | `T-58`'s fix excludes lines by bare substring match, not anchored like its sibling exclusion. Narrow today. |
| `T-37` | 3 | `todo` | Tutored read seam — owner-uid-scoped handles. Blocks D1's completion. Untouched by Phase 2. Detail in §4. |
| `T-38` | 5 | `todo` | Gate retarget + housekeeping folded together (check 104 into `T-23`, stale `all 68 greps clean` summary string, un-skip a now-false `skip:`). |
| `T-30` | 3 | `re-phased` | Owner-path CF deletes still key `learner_profiles` by the Drift int — moves with `T-20`. Detail in §4. |
| `T-31` | 3 | `re-phased` | Tutoring identity is Drift-int end-to-end — 13-read/9-write coupling. Detail in §4. |
| `T-32` | 3 | `decided` | Reorder amnesty — both forgiveness paths restored by owner ruling; content-reseed half needs a NEW mechanism (no Firestore version field). Detail in §4 — do not skip this one, it is easy to miss because it's not in the T-20/T-30/T-31/T-37/T-39 list. |
| `T-20` | 3 | `todo` | Wire the 7 dead adapters, move the feature files (§3's 90-plus-13, re-derive). Prerequisite: `T-39`. |

**Device checks, still open, not task ids** (full deferred-verification
table: `firestore-cutover-log.md`'s highest-lettered `§1{0,1}[a-z]*`
variant — §10c/§11c as of this handoff, re-grep): `D10` (create a profile
offline, restore network, activate — highest-value remaining device check
in the whole cutover), `D11` (deploy `T-33`/P2-6's `firestore.rules` change
+ reset + negative control — TEST-VERIFIED 116/116 but still UNDEPLOYED,
the owner's call — §9 below), `D20` (code-level subject CLOSED by removal
in Phase 2; the device observation itself stays open —
`fake_cloud_firestore` cannot model an offline queue plus a reconnect
ack, so no in-repo test substitutes for either D10 or D20).

---

## 4. Phase 3's scope

**The move, in order, per collection:** (1) move every writer, (2) move
every reader, (3) add the Phase-1 writer/reader agreement test — **use
`expectWriterReaderAgree` from `learning_tracker/test/helpers/
writer_reader_agreement.dart`, do NOT hand-roll a `fake_cloud_firestore`
test that seeds its own fixture.** That helper's own class doc states the
hard requirement: the `write` and `read` closures you pass it must never
contain a literal `.collection(...)`/`.doc(...)` — both must resolve
through production wiring (`lib/data/firestore/repository_providers.dart`
or the feature's own Ref-taking adapter), so the document path comes from
production code on both sides, not from the test. A test that seeds its
own fixture agrees with itself and proves nothing — that is exactly the
shape that let 144 tests stay green over the 2026-08-03 bookmarks/
learning-order writer/reader path split that started this whole cutover.
The helper's own non-vacuity is pinned by
`test/writer_reader_agreement_helper_test.dart` (a deliberately mis-wired
case that must fail inside the helper's own assertion, not merely fail the
outer test) — run that file once before trusting any new test you write
against the helper. (4) Run `make audit` (from `learning_tracker/`) plus a
targeted `flutter test` against the collection's own test directory —
**NOT `make ci` per collection.** `make ci` in a single invocation is
owner policy, batched to the end of Phase 4 (log Working Protocol rule 9
/ deferred-table row `D25`); running it once per collection would mean
running it roughly ten times this phase, at minutes each, against a
policy that explicitly says once, later. Use `make test` (the full,
unscoped suite you already ran in §2) as your per-commit net instead.

Order by DATA DEPENDENCY, writers before readers, not by feature
convenience. **Known reader/writer pairs that must move together**
(learned the hard way in earlier phases): track-creation → bookmarks;
learning-order → bookmarks *and* the scheduler's daily-task projection;
completion → bookmarks.

**Exit criteria:**

- Zero files under `lib/features/**` import Drift (re-derive with the
  `grep -rl 'import .*core/database' lib/features --include=*.dart | wc -l`
  command from §3 — it was **90** at this handoff, `e5a97f6b`/`P2-36`, and
  will fall as you move files; also account for the 13 files OUTSIDE
  `lib/features/**` that import Drift, §3 — the exit criterion as literally
  worded does not cover them, decide explicitly whether each one needs to
  move too).
- `make audit` 104/104 green, `make test` green, `dart analyze --fatal-infos`
  clean, `make test-rules` and `make test-functions` green — all run fresh
  by you (not inherited), with `T-69`'s two targets (`make
  validate-calendar`, `make test-serial-tools`) discharged as your FIRST
  ACTION (§2). These are the same six standalone targets named in the
  bullet immediately below, restated here so the exit state matches the
  entry state §2 required.
- **`make ci` is NOT this phase's exit criterion — it is Phase 4's.** Do
  not chase a green `make ci` this phase; it has never been run in one
  invocation, by standing owner policy, and running it here would
  contradict that policy for no benefit. **Precisely what covers `make
  ci`'s nine targets (`analyze validate-calendar lint-rules-test test
  test-serial-tools test-rules test-functions check-profile-path-keying
  check-profile-id-int-sites`) without running it as one invocation —
  corrected 2026-08-09 (P2-37): the prior version of this bullet claimed
  `make audit` + `make test` + `T-69`'s two targets alone "already cover
  everything," which is FALSE — `make audit`'s own recipe
  (`learning_tracker/Makefile:359`, `audit: lint-rules-test`) covers only
  `lint-rules-test` plus, inside its own body, `check-profile-path-keying`
  and `check-profile-id-int-sites` (`Makefile:1357`/`:1366`) — three of
  the nine. `make test` covers `test`. `T-69`'s two targets cover
  `validate-calendar`/`test-serial-tools`. That is six of nine. The
  remaining three — `analyze`, `test-rules`, `test-functions` — are NOT
  covered by `make audit` or `make test` at all; they are separately,
  individually required by §2's FIRST ACTION block (`dart analyze
  --fatal-infos`, `make test-rules`, `make test-functions`) and restated
  as exit criteria in the bullet immediately above. Nothing is actually
  left ungated — but no single command or pair of commands subsumes all
  nine; you need all six standalone targets, not three.**
- **Check 103's baseline (`tool/profile_path_keying_baseline.txt`) will
  still contain exactly `bookmarks` and `learning_order` at Phase 3's exit,
  and that is CORRECT, not a leftover.** Check 103 classifies an INT
  writer by FILE LOCATION (`lib/core/sync/**`, `functions/src/**`), not by
  whether anything still reads that path — so the baseline cannot empty
  until `lib/core/sync/**` itself is deleted, which is Phase 4's job (§7).
  **Never edit that file to make check 103 "greener" this phase** — if a
  collection you wire shows up in `currentSplits`/`newViolations`, that is
  a REAL new writer/reader disagreement (you wired a ULID reader while an
  INT writer for that collection is still live in `lib/core/sync/**` or
  `functions/src/**`), and the fix is to finish moving the writer, not to
  baseline the symptom away.
- **Wiring an adapter changes check 103's output too, and in two different
  ways that mean opposite things.** (a) The collection's WATCHLIST line
  disappears — that's progress, expected. (b) The collection can appear in
  `newViolations` — that's a hard failure meaning (a) happened for the
  READER side while the WRITER side is still int-keyed. Never treat (b) as
  something to baseline around.

### `T-39` — do this FIRST, before wiring anything

Check 103's WATCHLIST and the dead-adapters list (§3) are **not
necessarily the same set, and they name two different class layers** (§3).
Neither this handoff nor `firestore-cutover-tasks.md`'s own `T-39` row
carries a trustworthy live count for either side as of this handoff — both
documents' "5 unmatched / 2 unmatched" and "10-collection WATCHLIST"
figures were found unattributed to any actual `--report` run when this
handoff was hardened (P2-36) and have been removed rather than repeated.
**Reconcile them by running the tool yourself:**

```bash
cd learning_tracker
dart run tool/check_profile_path_keying.dart --report
```

Read the `--- WATCHLIST (N) ---` block; for each collection it names, check
whether it has a counterpart in §3's dead-adapters list (by COLLECTION, not
by class name — the two lists use different class layers, §3). Write the
mapping down (in your first commit's log entry, or in a
`firestore-phase3-plan.md` you author, §1) before wiring anything — this is
the prerequisite for `T-20`.

### `T-30` — 3 owner-path Cloud Functions still int-keyed

**Line numbers verified this round (P2-36) at `e5a97f6b`; re-grep before
editing — `grep -n 'String(profileId)' functions/src/deletes.ts` and
`grep -n '^export const delete' functions/src/deletes.ts` — the prior
version of this handoff had these stale.** `functions/src/deletes.ts`:
`deleteLearnerProfile` (:128), `deleteCurriculumTrack` (:209),
`deleteBulkMarkedCompletions` (:401) — each validates `profileId` as a
positive integer and addresses `learner_profiles/{String(profileId)}`.
**There are THREE `.doc(String(profileId))` sites, not two** — :143
(inside `deleteLearnerProfile` — the previous version of this handoff
omitted this one), :225, :441. Re-key all three. Post-cutover, unfixed,
they address a path holding no data: delete nothing, report success.
`deleteBulkMarkedCompletions` implements the owner's un-tick-a-bulk-mark
rule, so that feature would silently stop working with no error.
**Ordering trap, also corrected this round — the prior line numbers were
stale by 70+ lines:**
`lib/features/profiles/data/repositories/profile_repository_impl.dart:354`
deletes the Drift row, `:361` calls `_syncEngine?.deleteLearnerProfile(id)`,
and the adapter at `:674-675` delegates straight through — so a naive
re-keyed implementation has nothing left to build the remote path from by
the time it tries. Capture the profile's ULID before the local delete
removes the row.

### `T-31` — tutoring identity is Drift-int end-to-end

Owner decision D1 (2026-08-04): re-file under the ULID; the tutor reads
the parent's tree directly; the local mirror dies. **Coupling evidence,
why this could not land in Phase 2:** `TutoredProfileSelection.profileId`
is a live Firestore path segment on both sides — **13 read collections**
(`pull_pipeline.dart:73-98`: completions, bookmarks, curriculum_tracks,
settings, goals, learning_ledger, stage_definitions, streak_events,
study_day_configs, profile_programs, learning_order, points_ledger,
reward_redemptions) and **9 write collections** (`tutor_writes.ts:187`
builds one `profilePath`, written through at 12 call sites — completions
`:285`, goals `:346,:399`, curriculum_tracks `:455,:506`,
stage_definitions `:562`, study_day_configs `:621,:672`,
preferences/gamification_settings `:744`, bookmarks `:804`,
profile_programs `:864`, curriculum_scopes `:927` — re-verified this
round, P2-37; full breakdown also in `firestore-cutover-tasks.md`'s
`T-31` row). **11 of the 13 read collections still have an int-keyed
owner-side writer** — derived, not independently re-checked
collection-by-collection this round: 13 total minus the 2 already live
as ULID per `CURRENT STATE`'s "What's live on Firestore" list (§3,
above — `bookmarks`, `learning_order`) = 11; re-verify this arithmetic
against the CURRENT dead-adapters/live list before trusting it, since
which collections are "live" changes as Phase 3 wires adapters.
Re-keying tutoring's identity ALONE makes the tutor read a tree nothing
writes and write a tree nobody reads — **silently**: `pullForTutoredProfile`
counts no failures on an empty collection, so the pull "succeeds" into an
empty talmid, and no gate through Phase 3 can see a doc-id-formula
mismatch (neither check 103 nor check 104 covers doc-id formulas — §7).
**`manage_tutors_screen.dart`'s `.id.toString()` sites, re-verified this
round (P2-36):** exactly six — `163, 173, 206, 293, 298, 312` — the last
three (`293, 298, 312`) are `childProfileId:` constructor args, the first
three (`163, 173, 206`) are `outgoingTutorGrantsProvider(...)` reads/
invalidations; converting only the constructor-arg three would list a
child's grants under the old id while creating them under the new one. Do
not re-key one direction (reads or writes) without the other, and do not
re-key one of the 13 read collections without checking whether its
owner-side writer is still int-keyed.

**Check 104's baseline breakdown, re-derived this round (P2-36) — do not
trust a stale copy of these numbers, re-run the command:**

```bash
grep -v '^#' tool/profile_id_int_sites_baseline.txt | grep -v '^$' | awk '{print $1}' | sort | uniq -c
```

88 tracked entries / 91 sites (sum of each line's `xN`) as of this
handoff, split: **17** `cf-int-guard` + **5** `cf-string-profileid-doc`
(all in `functions/src/deletes.ts`/`tutor_writes.ts`/
`tutor_bulk_completions.ts` — `T-30`/`T-31`); **61** `dart-int-profileid-param`,
which itself splits by FILE, not by pattern, and NOT all of it is Phase 4's:
**28** against `lib/core/sync/firestore_gateway.dart` and **20** against
`lib/core/sync/outbox/push_pipeline.dart` are interface-level and belong to
**Phase 4** — do not touch those 48 lines here — but the remaining **13**
are against `lib/features/tutoring/data/services/tutor_write_service.dart`
and ARE `T-31`'s, in Phase 3, and MUST be updated in the same commit as the
re-key; **3** `dart-tutoring-id-tostring` (6 sites, in
`manage_tutors_screen.dart`, above) + **2** `dart-tutoring-int-parse`
(`tutored_write_router.dart`, `invite_tutor_screen.dart`) round out the 88.
**Editing a T-30/T-31 file WILL change check 104's output** (expected, not
a regression) — the code fix and the matching
`tool/profile_id_int_sites_baseline.txt` edit MUST land in the SAME
commit.

### `T-32` — reorder amnesty, both halves (owner decision D2, 2026-08-04) — IN SCOPE, unequal cost

Easy to miss: it does not appear in the T-20/T-30/T-31/T-37/T-39 list above
because it is not a collection-move, it is a feature fix riding along with
the `learning_order`/`curriculum_tracks` move. **The reorder-stamp half is
cheap and mostly done:** `last_reorder_at` is already permitted on
`curriculum_tracks` (`firestore.rules:412`, verified this round). The
Drift READ that feeds it is
`lib/features/scheduler/domain/services/daily_task_projection_service.dart:75`
(`db.trackDao.getActiveTracksForProfile(profileId)`, consumed at `:96`/
`:444` — verified this round; the previous version of this handoff cited
`:443-446` as "the read," which is actually the CONSUMPTION site, not the
Drift call) — move that call onto the ULID-keyed track repository.
**The content-reseed half needs a NEW mechanism, and does not come free
with the move:** the old detection used the Drift `learning_order.
learningOrderVersion` column (`lib/core/database/tables/learning_order.dart`),
and the `learning_order` collection's rules whitelist has no version field
today — design this explicitly; it is not covered by the "zero Drift
imports" exit criterion, since a missing feature leaves no Drift import
behind to detect it. Full text: `firestore-cutover-tasks.md`'s `T-32` row.

### `T-37` — the tutored read seam (repairs a Phase-2-created regression)

P2-5 (Phase 2) hoisted a uniform refusal into
`_watchActiveAccountAndProfile` for all 13 profile-scoped providers during
a tutored session — correct, it closed a live latent corruption where the
other 12 providers (besides `bookmark_repository_impl.dart`, the only one
that had carried the check) silently served the TUTOR's own account+profile
tree. But the refusal sources `uid` from the signed-in account (the
tutor's own). **Substituting the profile ULID alone, without also
substituting the owner's `uid`, addresses `users/{TUTOR}/learner_profiles/
{talmid ULID}` — a brand-new WRONG tree, not the parent's.** The rules
already permit the correct read — `firestore.rules` has **13** lines of
the exact shape `allow read: if isOwner(uid) || hasActiveTutorAccess(uid,
profileId);` (re-counted this round: `grep -c 'allow read: if isOwner(uid)
|| hasActiveTutorAccess(uid, profileId)' firestore.rules`; the prior
version of this handoff said "16 siblings," i.e. 17 total — re-run the
grep, do not copy either number forward). `T-37` needs an owner-uid-scoped
HANDLE SEAM — feature wiring, not a config flip or a value substitution.
Blocks D1's completion.

### New Riverpod-chain trap for every adapter you wire

Every new provider chain — the 7 currently-dead adapters, `T-37`'s
owner-scoped handles — is a fresh Riverpod chain that may await
`activeAccountFirebaseProvider.future` or similar. **Declare `retry: (_,
__) => null` on it, or verify its test container came through
`bootstrap()`.** Riverpod 3's default per-provider retry
(`ProviderContainer.defaultRetry`) treats a structural exception (e.g. an
unauthenticated-account error) as retryable for up to ~6.4s per attempt,
~38s total backoff, before `.future` ever settles (attributed 2026-08-09,
P2-37: the formula itself, `maxRetries: 10, maxDelay: 6400ms, minDelay:
200ms`, doubling each retry and capping at `maxDelay`, is in the pinned
`riverpod` package source, `defaultRetry` in `provider_container.dart:
831-845` of `riverpod-3.2.1` per this repo's own `pubspec.lock` —
summing the 10 capped delays, `200+400+800+1600+3200+6400×5`ms, gives
`38.2s`, i.e. "~38s"; re-derive against whatever `riverpod` version
`pubspec.lock` pins if it has changed since) — and while retrying,
`AsyncLoading(retrying: true)` routes to `onLoading`, which does NOT
complete the `.future` Completer, so a bare test container hangs for the
full backoff. The app's ONE production `ProviderContainer`
(`lib/app/bootstrap/bootstrap.dart:68-81`, verified this round) already
disables retry container-wide, so this is a test-harness-only risk, not
production — but it cost real debugging time twice in Phase 2 before the
container-wide fix was found, and every one of the 7 new chains
reintroduces the exposure in whatever bare test container first exercises
it.

### Every "adapter" hides 4-6 awaits — enumerate before wiring

`FirestoreProfileRepositoryAdapter.createProfile`'s own chain — not fully
discovered until Phase 2's SIXTH round — hid four of
`ProfileRepositoryImpl`'s own awaits plus a durable-outbox enqueue that is
a **one-shot Cloud Function RPC** in a tutored session
(`TutoredWriteRouter.pushLearnerProfile` →
`tutored_write_router.dart:301-321`). None of it was visible from the
adapter's own signature or doc comments. Enumerate every await
TRANSITIVELY reachable from each of the 7 adapters' public methods before
wiring them — from the public entry point, not from the adapter's own
body (Working Protocol rule 2, trap #2 in §5).

### `T-67`/`T-68` — close these in Phase 3, they are live false claims in code today

Working Protocol rule 5 / §0 rule 6 above: a docs-only round can disclose a
false code comment but cannot close it; Phase 3 is the first code-touching
round since they were found, so close them here rather than letting them
become a fourth/fifth recurrence of the `T-50`/`T-49` pattern.

- **`T-67`:** the CONTROL-4 test's own printed NAME still asserts a fifth
  reopening is "structurally impossible," a claim the round-7 verifier
  disproved by injecting an evading variant (a longer variable name defeats
  its bounded regex window; a separate aliased-notifier form evades it
  independently of length). Rename the test to its true, narrower scope
  and widen or supplement the pattern; prove the fix by injecting BOTH
  evading variants and confirming they go RED before trusting the new
  gate (§5 trap 6).
- **`T-68`:** `lib/features/profiles/data/repositories/
  profile_repository_impl.dart`'s doc comment (near line 618 as of this
  handoff — it will move) claims a single-line grep pattern
  (`selectedProfileIdProvider.notifier).select(`) "returns every one of
  them and nothing else" for the profile-activation call sites. **Finding
  the comment by grepping its own claimed phrase does not work — corrected
  2026-08-09 (P2-37): the phrase itself is line-wrapped by the doc comment's
  own formatting (`/// ... returns every one of` ends one source line,
  `/// them and nothing else)...` starts the next), so
  `grep -rn 'every one of them and nothing else' lib/` returns ZERO hits —
  this is Working Protocol rule 14's own lesson recurring inside the fix
  for the defect that lesson describes. Find it instead with
  `grep -n 'returns every one of'
  lib/features/profiles/data/repositories/profile_repository_impl.dart`
  (the fragment before the wrap, confirmed on one line).** Re-run the
  pattern itself yourself — as of this handoff (P2-36) it returns 4 raw
  matches, one of which is the doc comment quoting its own pattern (so 3
  real call sites), against **14** real call sites total; the other 11
  use the multi-line `.read(selectedProfileIdProvider.notifier)\n
  .select(...)` form the single-line pattern can't match. **Command that
  actually finds all 14 (added P2-37, tolerates the line break via Perl's
  `/s` flag, one file at a time):**
  `for f in $(grep -rl 'selectedProfileIdProvider.notifier)' lib/
  --include='*.dart'); do perl -0777 -ne '$n = () =
  /selectedProfileIdProvider\.notifier\)\s*\.select\(/gs; print "$f: $n\n"
  if $n' "$f"; done` — sums to 15 matches across the codebase; subtract 1
  for the doc comment's own self-quoting match (in
  `profile_repository_impl.dart`) to get the 14 real call sites. Fix the
  comment IN CODE — state the true scope, or replace the pattern the
  comment itself describes with one shaped like the command above.

---

## 5. Traps this phase proved are real — instructions, not anecdotes

Each rule below cost at least one full round of Phase 2 (some cost four).
Full incident evidence for every one lives in `firestore-cutover-log.md`'s
Working Protocol section (**16** numbered rules as of P2-37, at the top
of the file — not 12, not 15; if a document anywhere in this project says
12 or 15, it is stale — re-grep `^[0-9]\+\. \*\*` under
`^## Working protocol$` to confirm) and
PHASE 2 RETROSPECTIVE (prepended atop `## Entries`) — this list restates
them as direct instructions with the incident cited by name and where each
one bites in Phase 3.

1. **Prefer DELETING a write to relocating it.** Four rounds (P2-18,
   P2-23, P2-28, and the fix P2-29 reviewed) each asked "is this write
   above the awaits I can see from inside this method?" and each was
   falsified by an await one level up. That question has no terminating
   answer — there is always one more caller. "Does this path perform this
   write at all?" does terminate: a write that doesn't exist has no
   boundary to enumerate and no doc comment that can go stale. Phase 3
   will hit the same shape wiring `T-20`, `T-30`, `T-31`, `T-37` — every
   one adds a write behind a new caller chain. Default to deleting the old
   write, not guarding it.
2. **Enumerate awaits from the PUBLIC ENTRY POINT of the class, not from
   inside the method holding the write.** Enumerate EVERY public method of
   the class under review, not only the ones your change touches — the
   round-7 verifier found `T-66` (a real, previously-unprobed activation
   site) only by enumerating all 8 of `FirestoreProfileRepositoryAdapter`'s
   public methods, where the design that shipped the original fix had
   named only 3. Recompute this count yourself rather than trusting "8":
   `sed -n '/class FirestoreProfileRepositoryAdapter/,$p'
   lib/features/profiles/data/repositories/profile_repository_impl.dart |
   grep -c '@override'` (valid as long as that class stays the last one in
   the file, true as of 2026-08-09/P2-37 — if it stops being last, bound
   the `sed` range at the class's own closing `}` instead).
3. **A negative claim is verified by (a) re-run enumeration against the
   CURRENT tree, or (b) an executable probe gating the specific
   await/branch — never by re-reading the code more carefully.** A defect
   filed `done` with a plausible written justification is NOT closed by
   that justification. Two different agents wrote two well-argued,
   individually-plausible justifications for the same underlying `T-49`
   error (P2-18's, P2-23's); both were disproven in minutes by a 30-line
   probe.
4. **An unqualified safety claim is a defect even when the code is
   correct.** Every failed `T-49` round stated its result at a scope wider
   than it had verified ("nothing asynchronous precedes it," "no
   post-await re-check is needed"). The round that finally got the code
   RIGHT still produced one — "CONTROL-4 makes a fifth reopening
   structurally impossible" — disproved by execution in minutes (`T-67`,
   §4 above — close it in Phase 3, don't just cite it here).
   State the scope you actually checked: "this path performs no such write
   on any path," not "nothing can race this."
5. **A guard that watches for a COMPETING selection cannot detect the
   ABSENCE of one.** The design that finally held enumerated all four race
   states and showed a re-check guard leaves the abandoned-create cell
   open: nothing raced, the caller died, the guard writes C, nobody
   selects C. This is why relocation (option "re-check after the await")
   was rejected on CORRECTNESS, not style. Enumerate all four cells before
   reaching for a post-await re-check anywhere in Phase 3's new wiring.
6. **A source-scanning structural gate is only as good as its pattern, and
   its pattern will be optimistic — attack it before trusting it.**
   CONTROL-4's bounded 40-character regex window was evaded by a longer
   variable name in minutes; a separate aliased-notifier gap is
   width-independent. If Phase 3 (e.g. `T-67`'s fix, above) or Phase 5
   write a new structural gate to police the moved code, inject an
   evading variant and confirm it goes RED before trusting the gate's
   claim.
7. **A test that passes on the broken tree is not a regression guard.**
   The six inherited GROUP-1/GROUP-2 race cases stayed GREEN on the
   reverted, pre-fix tree in exactly the sub-cases where the verifier's own
   sentinel probes went RED — because they asserted only the FINAL value
   after an interleave that happened to complete first. Assert the
   intermediate state, not only the outcome, for every new race-condition
   test Phase 3 writes.
8. **Use a SENTINEL value, never `expect(..., isNull)`, to prove "never
   written."** `isNull` cannot distinguish "untouched" from "written to
   null" — a re-added `set(null)` passes an `isNull` assertion. Pre-set the
   provider under test to a string no production code could produce
   (`'SENTINEL-...'`) and assert byte-identity afterward.
9. **A permanent race-condition test needs, AT MINIMUM, TWO sanity
   assertions, or the case is vacuous — and more is better.** The log's own
   documented minimum (P2-28's entry, verbatim): "the remote doc really
   landed; the selection really was the other profile." The likeliest way
   such a test silently rots is passing because the whole operation
   completed before the interleave point ever mattered — so treat those
   two as a floor, not a ceiling, and add whatever else your specific race
   needs to rule out a false pass: that the gate was genuinely shut at the
   interleave, that the gated collaborator was genuinely reached
   (`verify(...).called(1)`), that the operation was genuinely incomplete
   at the check point (a done-flag + `pumpEventQueue`). (This bullet is
   this handoff's own synthesis of the general principle, not a numbered
   list copied from the log — the log itself states only the two-item
   floor above; do not go looking in the log for a longer authoritative
   list, you won't find one.)
10. **Publish the predicted revert signature BEFORE running the revert.**
    The design that finally held predicted exactly 6 RED / 8 GREEN, named
    each case, and matched on the first real run — every earlier round
    skipped this and each shipped a defect. Before trusting any new
    permanent test: disable the fix (or revert via `cp`, never `git
    stash`), state which cases you predict go RED, run it, and treat any
    mismatch as a defect in the TEST, not noise.
11. **A round cannot certify its own fix — the review must be
    adversarial, not confirmatory.** Round 7's verifier returned
    `t49_closed: true` AND `verdict: defective` in the same report,
    because it separated "is the code right?" from "is the record true?"
    That split is what made round 7 the round that finally held. Any
    Phase 3 round that closes a defect needs a SEPARATE round — not itself
    — to review it before the entry criteria checkbox is marked satisfied.
12. **Read-only passes still find real defects — budget one at the end of
    every phase.** P2-33 ran no test and no gate and still found a
    two-round-stale deferred-verification table asserting the OPPOSITE of
    the truth, missed by the fix round, the independent code verifier, AND
    the recording round. Static enumeration plus cross-document checking
    is cheap and catches a class execution cannot.
13. **A record correction applied only to a `.md` file leaves the false
    claim live in the code.** `T-50` and `T-49`'s own doc comments each
    recurred this way. A docs-only round can and must DISCLOSE a false
    code comment it finds (name a task), but cannot CLOSE it — closing
    needs a round explicitly scoped to touch `lib/`/`functions/src/`. Never
    let disclosure substitute for the fix. (`T-67`/`T-68`, §4, are this
    project's own live examples right now — close them in Phase 3.)
14. **Multi-field self-reference staleness (`T-62`) is the most persistent
    defect class in this project.** Correcting one field that cites
    "current HEAD" does not correct its siblings elsewhere in the same
    file, in a companion file, or inside a table. After ANY closing
    commit, **grep all THREE live planning docs** — `firestore-cutover-
    log.md`, `firestore-cutover-plan.md`, `firestore-cutover-tasks.md`
    (NOT `firestore-phase2-plan.md`, which is intentionally frozen, §1) —
    for every SHA, line number, count, and "only writer"/"structurally
    impossible"/"no path" claim, and re-derive each one — do not trust
    that fixing the narrative paragraph in one file fixed the same fact
    stated elsewhere. This handoff itself had several such staleness bugs
    when it was hardened at P2-36 (stale line numbers in `T-30`'s section,
    a stale "5/2 unmatched" `T-39` figure nobody had actually run, a stale
    "16 sibling" rules-line count) — the mechanism reaches even a document
    written to WARN about the mechanism.
15. **Never delete a probe that found something real — make it
    permanent.** A throwaway probe that finds a defect and is then deleted
    lets the SAME defect survive to be rediscovered from scratch by the
    next round. This happened at least four times in Phase 2, including
    inside the round that finally closed `T-49`. If a probe must be
    disposable by charter (a docs-only round with no fix yet to guard),
    say so explicitly and open a task for a future round to make it
    permanent.
16. **`git stash` is never the tool.** Every revert and restore across
    Phase 2 used `cp` with md5 verification. Two unattributed stash
    entries have sat untouched since before the cutover began (§8, below);
    their reflog SHAs are byte-identical across every round's record.
    Never pop, apply, drop, or index them positionally.
17. **Any step that runs a deferred check supersedes the
    deferred-verification table IN THE SAME COMMIT (Working Protocol rule
    7) — this is the one rule the P2-35 version of this document dropped
    from this list, and dropping it is exactly the mechanism that cost a
    full extra round earlier in Phase 2** (the table sat two rounds stale
    with its two most load-bearing rows asserting the opposite of the
    truth, missed by the fix round, the independent verifier, AND the
    recording round — trap 12, above, names the same incident from a
    different angle). Concretely: your first commit that touches `D10`,
    `D11`, `D20`, or discharges `T-69`'s two targets (§2) must add a new
    superseding table — physically as `#### 10d.`/`#### 11d.` (or whatever
    the next free letter is; re-grep, §1) — in the SAME commit, not a
    later one. **A commit that touches no D-row and no entry-criteria
    checkbox must say so explicitly** ("this round changes no D-row, no
    checkbox") rather than staying silent, which reads as an oversight to
    the next round.

---

## 6. Test policy

- **Targeted `flutter test <paths>` is REQUIRED per commit.** A fix is not
  done until its test has been RUN and PASSES, with the ACTUAL command and
  ACTUAL output pasted into the commit's log entry — never imply a test is
  green without running it. (A fabricated `01:31 +1` test timing in one
  Phase 2 round's own entry had to be corrected by a follow-up commit that
  actually ran the suite.)
- **Prefer a directory-level run over a hand-picked file list as the
  disclosure baseline.** A hand-picked list missed a 6th red test twice in
  Phase 2 — once inside `test/features/profiles/`, once for all 14
  failures under `test/e2e/journeys/**`, invisible for FIVE rounds because
  no round ever ran `flutter test test/e2e/` as its own net.
- **Emulator suites ONE AT A TIME**, on port 8080 — confirm free first:
  `ss -ltnp | grep -E ':8080|:9099|:4400'`. Running `make test-rules` and
  `make test-functions` concurrently already produced one self-inflicted
  port collision in this cutover.
- **Check for a `Terminated` line and an explicit `EXIT=` code before
  reading a suite's failure count** — a killed run manufactures fake red
  tests (sink-close errors, teardown `PathNotFoundException`s) that are
  process artifacts, not code failures (§2, above, has the concrete
  example).
- **Never run two agent sessions against the same planning documents
  concurrently.** Three separate Phase-2 incidents: files excluded
  mid-edit because a concurrent session was writing them; a commit landing
  with NO log entry at all because `docs/planning/**` was dirty from a
  sibling session; gates going red transiently from a concurrent session's
  mid-write state. A gate or test result collected while another session
  is writing describes nothing.

---

## 7. Gate map

- **`make audit` (the 104-check gate every log entry means) MUST run from
  `learning_tracker/`, never the repo root.** The repo-root Makefile
  (`/home/daniel/repos/learning-tracker/Makefile:112`) defines a
  DIFFERENT, 12-grep `audit` target — a pre-existing check, unrelated to
  this cutover — and it FAILS today on unrelated pre-existing violations.
  Running it from the repo root and reading a red result as a Phase 3
  regression is a documented trap (`T-52`).
- **`make audit` is a SUBSET of `make ci`** — checks exist in only one
  lane. `make ci`'s recipe is exactly nine targets (`learning_tracker/
  Makefile`'s `ci:` line): `analyze validate-calendar lint-rules-test test
  test-serial-tools test-rules test-functions check-profile-path-keying
  check-profile-id-int-sites`. TQ-9 (rule coverage) is `make ci`/`make
  test-rules`-only, chained with `&&` behind a `node --test` step that can
  itself silently block it from ever running — confirm the chain actually
  REACHED the second command, not merely that it exited 0. (A stale
  assertion once prevented TQ-9 from running even once for an entire
  phase — `T-54`.) **Do not run `make ci` per collection this phase (§4)
  — it is Phase 4's exit criterion, not Phase 3's.**
- **Check 103 (`PROFILE-KEY-SPLIT`, `check_profile_path_keying.dart`) is
  FILE-LOCATION-based, not keying-based.** INT-A = every `.dart` under
  `lib/core/sync/**` (no liveness filter); INT-B = every `.ts` under
  `functions/src/**`; ULID-C = `lib/data/repositories/**` +
  `lib/features/**/data/repositories/**` (liveness-filtered — see §3 for
  the two distinct class layers this covers). It CANNOT register Phase 3
  progress on the check-103-baseline-emptying axis until `lib/core/sync/**`
  itself is deleted or edited (that's Phase 4, §4's exit criteria above) —
  but it DOES register progress via the WATCHLIST shrinking and via
  `newViolations`/`currentSplits` moving as you wire adapters (§4). It
  cannot see `learner_profiles` itself (parent collection, outside its
  scan), `tutor_active_access`, or ANY doc-id formula — that gap is
  exactly what let `T-31`'s tutoring coupling go undetected before this
  phase, and why a doc-id-formula mismatch will still be invisible to
  every gate you have if you re-key `T-31` incompletely.
- **Check 104 (`PROFILE-ID-INT-SITES`) counts, it does not reach.** Scope
  is five patterns only (see `tool/profile_id_int_sites_baseline.txt`'s
  header). It has ZERO concept of whether a symbol is ever called — "a
  location can be counted with perfect accuracy while being provably
  unreachable from any UI trigger" is its own documented blind spot. This
  is the check `T-38` plans to fold into `T-23`'s gate retarget in Phase
  5 — until then, treat its green as counting evidence only, never
  reachability evidence.
- **R6d (`coverage/lcov.info` denominator) soft-skips and still exits 0
  when the file is absent.** Read the stdout line above the exit code,
  never the exit code alone. Never delete `coverage/lcov.info` to make a
  gate green.
- **`dart analyze` + `make audit` green means it COMPILES and no ratchet
  MOVED — nothing more.** Two Phase 2 rounds shipped confidently-documented
  fixes on exactly that basis while a real defect sat underneath both
  gates, green before and after.

---

## 8. Environment hazards

- **Two `git stash` entries exist, identified by BASE COMMIT, never by
  positional index** (`stash@{N}` reorders on every push/pop):
  - `stash@{0}` (as of Phase 2's close): `WIP on dev: d74e3829` — appeared
    MID-SESSION during Phase 2's own P2-0, with **no `git stash` command
    ever run by the agent that found it**. The mechanism is still
    unidentified.
  - `stash@{1}` (as of Phase 2's close): `WIP on (no branch): 8855b9b1` —
    pre-existing, predates this cutover entirely.
  - Neither is popped, applied, or dropped; neither is ruled on. Full
    measured facts: `firestore-cutover-log.md`'s "Known stashes —
    UNDISPOSITIONED-REPORTED" section, near the end of the file.
- **A clean `git status --porcelain` is NOT proof nothing is wrong.**
  Re-verify immediately before every `git add`, and if a just-written edit
  is missing on re-read, check `git stash list` before assuming the edit
  tool failed.
- **Verify the tree first, because the log may predate a crash.** Sessions
  die mid-work — session limits, interrupts, crashes. Run `git log
  --oneline -1` and compare to `CURRENT STATE`'s `Head:` field before
  trusting anything else in the log. `CURRENT STATE`'s `Head:` field lags
  its own commit by construction (a commit cannot cite its own SHA before
  it exists — see the log's `T-62` discussion) — a ONE-commit mismatch
  where the log's cited head is the PARENT of actual `HEAD` is normal, not
  a crash signature; verify by reading that commit's own message, not by
  the SHA mismatch alone.
- **Uncommitted work in the tree is suspect until verified, not lost.**
  Check whether the last agent finished by reading its section under IN
  FLIGHT in the log. Never `git stash` to clean up — a partial pop has
  already silently dropped work on this project once. Edit by hand.

---

## 9. What is deliberately NOT done — the owner's call

- **The `firestore.rules` change (T-33, P2-6, owner-delete for
  `learning_order`) is TEST-VERIFIED but still UNDEPLOYED.**
  `Deployed:` in `CURRENT STATE` still reads `unknown — not deployed`.
  `make test-rules` → `pass 116 fail 0`, TQ-9 → all 37 conditional allow
  rules evaluated at least once — proves the rule text is internally
  consistent against `fake_cloud_firestore`'s emulation; proves NOTHING
  about what is live on the dev Firebase project, which only a real
  deploy changes. **You are instructed never to deploy** (§0, standing
  instruction #3) — this stays the owner's call. **Requalified 2026-08-09
  (P2-37): `Deployed:` is the last thing an AGENT wrote to a text file —
  it is not an observation of the live Firebase project, and it can go
  stale silently the moment the owner deploys or resets something outside
  this repo, with no commit to record it. The only ways to actually know
  what is live: ask the owner, or read the Firebase console yourself
  (read-only — you are still forbidden from changing anything there).**
  Before attributing any device `permission-denied` to a keying defect,
  rule out BOTH of the following independently, not just the first one
  this field happens to suggest: (1) an undeployed rules change (this
  field, itself unverified — see above) and (2) an unregistered App Check
  debug token (a wipe or fresh install regenerates the debug token; a
  stale registered token or a missing registration produces the identical
  403/`permission-denied` symptom, unrelated to keying or deployment) —
  the two present IDENTICALLY on-device and neither is ruled out by the
  other.
- **`D10`/`D11`/`D20` (device checks) require an actual device**, not a
  docs pass or a code change — `fake_cloud_firestore` cannot model an
  offline queue plus a reconnect ack. They are standing work, not phase
  gates: read them before touching profile-activation code a second time,
  but they do not block Phase 3's start.
- **`T-44` and `T-46` need a PRODUCT decision, not a mechanical fix** — do
  not resolve them unilaterally as part of Phase 3 wiring work.
- **`T-55`** (the ~60 further ulid-less test seeders) needs a decision:
  fix preventively, or wait for each to fail on its own the way its
  predecessors did. Not yours to decide silently either way — flag it if
  Phase 3's work starts exercising any of them.

---

## 10. Phase 3 entry criteria — verify each, in order, before your first edit

**The AUTHORITATIVE Phase 3 entry-criteria checklist is
`firestore-cutover-log.md`'s highest-lettered `#### 11[a-z]*.` block —
`§11c` as of this handoff, re-grep `^#### 1[01][a-z]*\.` to confirm you
have the current one, §1. The list below is an OPERATIONAL restatement for
your first five minutes, not a replacement — §11c also carries one
criterion this list doesn't repeat: the deferred-verification table must
be current as of the last entry (Working Protocol rule 7).** The commit
that closes `T-39` must supersede `§11c` as the next free letter (`§11d`
as of this handoff — re-grep) with `T-39`'s box CHECKED and the overall
verdict restated per the DECISION RULE (Phase 2 → RESOLVED, or the
remaining blocker named) — and must update the Status paragraph in
`firestore-cutover-plan.md` and the header + `T-39` row in
`firestore-cutover-tasks.md` in the SAME commit (Working Protocol rule 6).

- [ ] **Recovery protocol run** (§2, above) — tree verified against
      `CURRENT STATE`'s `Head:`, no orphaned `flutter` test process, gates
      and `make test` re-run FRESH by you, not inherited. Any drift from
      the "last known" table in §2 named explicitly.
- [ ] **`make validate-calendar` and `make test-serial-tools` (`T-69`) run
      fresh by you** — neither has run against the code since round 5;
      discharge them as part of §2, not deferred further.
- [ ] **`git stash list` confirms exactly 2 entries**, same bases
      (`d74e3829`, `8855b9b1`) as §8. A third entry, or a changed base, is
      a red flag — stop and investigate before editing anything.
- [ ] **`git status --porcelain | grep -v '^ M _bmad'` is empty**, or any
      dirty file is explained (a prior session's genuinely-finished,
      uncommitted work — verify against that session's own IN FLIGHT
      entry, don't assume).
- [ ] **`T-39` reconciled** — check 103's `--report` WATCHLIST run fresh
      against the current tree and compared, BY COLLECTION, to the
      dead-adapters list (§3/§4); the mapping written down before any
      adapter is wired.
- [ ] **You understand the IN FLIGHT protocol** (top of the log) and will
      append an entry — citing `firestore-cutover-plan.md`'s "### Phase 3
      — Wire and move" section, §1 — naming your commit id and remaining
      edit-list items BEFORE your first edit; the commit that lands your
      code clears it and rewrites `CURRENT STATE` truthfully, in the same
      commit.
- [ ] **You have read §5's 17 traps** and intend to apply them, not just
      acknowledge them — in particular: enumerate from the public entry
      point (#2), delete rather than relocate (#1), supersede the
      deferred-verification table in the same commit that touches it
      (#17), and never delete a probe that finds something real (#15).

Once every box above is checked, you are clear to start Phase 3's own
work. **This handoff document does not write Phase 4's handoff — that is
explicitly Phase 3's own closing round's job, from Phase 3's own measured
state (Working Protocol rule 15). Do not treat any "bites Phase 4" note
anywhere in this project's docs as a substitute for writing that handoff
when the time comes.**
