# Phase 3 handoff #4 — Drift → Firestore cutover

**Written:** 2026-08-11. **Supersedes** `phase3-handoff-3.md` (which is still
accurate on the contract; this one updates state and adds hard-won operational
rules).

**State at handoff:** HEAD `e1f30248` (P3-41). **34 commits on `dev`, 43 ahead of
`origin/dev`, ALL UNPUSHED.** `lib` analyzer errors **351** (720 at phase start).
Worker cost to date: **$0.00** — every worker on a free tier.

*(Amended after first writing: §1.2b on model selection and §6.2b on the
build_runner blocker were added once both were discovered.)*

---

## 0. Read this first: you are an ORCHESTRATOR

The owner's contract, still in force:

- **Delegate ALL repository changes to worker models via the OpenCode MCP.** Do
  not use Edit/Write on the repo yourself. Scratch files under the session
  scratchpad are exempt.
- **NEVER delegate verification.** You run `dart analyze`, the gates, and you
  read every diff. A worker's report is a claim, not evidence.
- **Alert before analysing** — say what you are about to do before a long dig.
- **NEVER push. NEVER deploy.** Only two deploys were ever authorised and both
  are done: `firestore.rules`, and the billing kill-switch function.
- **No branches, no worktrees, no `git stash`, no `git add -A`.** Explicit single
  file paths only.
- **NEVER run `make ci`** in one invocation (standing owner policy).
- **D-G: no full test runs mid-migration.** `dart analyze` is the progress
  signal. Targeted gates ARE run — see §5.
- Review with a different model than wrote the code (rule 16).
- GREENFIELD: no live users, no data worth preserving.

---

## 1. ⚠️ Operational rules learned the hard way — these will cost you hours

### 1.1 An MCP idle timeout is NOT a worker failure

`opencode_fire` reports the task `failed` after ~1800s of silence. **The worker
is usually still running.** `opencode_sessions_overview` repeatedly showed
sessions still `busy` long after their task was reported failed.

- **Track progress with `git status`, NEVER with task status.**
- **Do NOT re-dispatch a timed-out target.** Its worker is probably still writing
  that file; two workers on one file corrupts it.
- A timed-out worker's diff arrives with **no report**, so you must read the
  whole diff manually before accepting it. Several of this session's best commits
  came from timed-out workers ("the report died, the work survived").

### 1.2 Three distinct worker failure modes, needing different responses

| mode | signature | correct response |
|---|---|---|
| MCP idle timeout | task `failed` ~1800s, session still `busy` | do nothing; verify via `git status` |
| **reason-to-budget** | session `idle`, **0 output tokens**, no file change | re-dispatch on a DIFFERENT model |
| genuine BLOCKED | session `idle`, a real report | read it — often the most valuable output |

**`idle` + no file change is ambiguous.** Check the output-token count.
`kilo-auto/free` twice returned `182 in, 10000 reasoning, 0 out` — it reasons to
its budget and emits nothing. The `profile_repository_impl` refusal and the
`sacred_window` burnout both showed `idle`; one produced the best analysis of the
session, the other produced nothing.

### 1.2b Which model to actually use (as at 2026-08-11)

The table above says re-dispatch a reason-to-budget failure on a "different
model". Concretely, measured this session:

| model | verdict |
|---|---|
| `kilo` / `kilo-auto/free` | **DEGRADED — do not use.** Sessions entered `[retry]` (rate-limited) AND reason-to-budget became the norm on substantial tasks (`9600 in, 10000 reasoning, 0 out`). |
| `opencode` / `nemotron-3-ultra-free` | Returned an EMPTY response with no token counts at all. |
| `opencode` / `deepseek-v4-flash-free` | **7 for 7** on script-on-disk execution, 40–170 tokens per run. Current default. |

Untried, if both degrade: `north-mini-code-free`, `longcat-2.0-free`,
`laguna-s-2.1-free`, `ling-3.0-tiny-free`, `mimo-v2.5-free`.

⚠️ Cost is **$0.00 on all of them**, so model choice is purely a QUALITY and
WALL-CLOCK decision, never a budget one. Never send a hard cluster to a weak
model to economise — a wrong migration costs far more to find than to prevent.

The most reliable pattern remains: **author the change yourself as a script on
disk, then have a worker run it by path** with "do NOT open, read, retype or
reconstruct it". That has never once produced a wrong edit.

### 1.3 Never sample `dart analyze` while workers are mid-write

One reading returned **950** when the true count was **475**. Re-run when the
tree is quiet.

### 1.4 A contract split across two files needs the SECOND re-verified

Two workers each did half the curriculum-activation rewire. The service gained a
second dependency AFTER the provider was written, so the provider constructed it
with one argument and an import was missing. **Both reports were individually
truthful and jointly wrong.**

### 1.5 Check a worker's JUSTIFICATION as carefully as its code

A worker threw `UnsupportedError` citing "no presentation-legal provider exists
yet" — which had been false since P3-29, and the dispatch had named the methods.
A worker reaching for `throw` will sometimes justify it with a reason that has
expired.

### 1.6 Dispatch mechanics that work

- Write the change as a **script on disk**, then have a worker run it by path
  with "do NOT open, read, retype or reconstruct it". This defeated three silent
  single-character heredoc corruptions.
- Every dispatch carries the shared brief and an explicit
  **"NEVER return a plausible value"** clause. It visibly changed output quality.
- Tell workers to **be decisive** — the reason-to-budget failures correlate with
  open-ended deliberation.

---

## 2. The sequencing rule: CALLEE BEFORE CALLER

**This is the single most useful thing discovered this session.**

Three files that looked "blocked" were blocked on a **constructor shape**, not a
missing capability. A Drift-era class that takes its dependencies as constructor
arguments blocks EVERY caller, because each caller would otherwise have to reach
the data-access ring itself — which AD-23/AD-28 forbids from `presentation/` and
`domain/`.

Converting the callee to take `Ref` and resolve internally does not merely
unblock callers, it makes them **smaller**. `onboarding_providers.dart` went from
a seven-line construction over `db.stageDao` / `db.completionDao` /
`syncFacade?.pushStageDefinitions` to:

    final stageRepo = FirestoreStageDefinitionRepositoryAdapter(ref: ref);

**Order the queue by dependency, not by error count.** When a presentation file's
errors are all "undefined name" on Drift-era injected dependencies, do not touch
that file — convert its callee.

The target shape, used by `FirestoreProgressRepositoryAdapter`,
`FirestoreBookmarkRepositoryAdapter`, `FirestoreStageDefinitionRepositoryAdapter`,
`FirestoreCurriculumTrackRepositoryAdapter` and
`FirestoreStudyDayConfigRepositoryAdapter`:

    SomeAdapter({required Ref ref}) : _ref = ref;

constructed from presentation as `SomeAdapter(ref: ref)`.

---

## 3. Architecture facts you must not re-derive

### 3.1 Layering — AD-23/AD-28

`tool/check_dependency_direction.dart:57` exempts **EXACTLY** the path segment
`/data/repositories/`. NOT `/data/`, NOT `/data/services/`.

**18 of 18** files importing `data/firestore/repository_providers.dart` sit under
that segment. If a file needs the ring and is not there, the fix used three times
this phase is `git mv` it into its feature's `data/repositories/`.

### 3.2 AD-25 — the `trackId` axis no longer exists

`CurriculumTrackEntity` has NO `id`. `LearningLedgerEntry` has NO `trackId`. A
track IS its curriculum; the Firestore doc id is the curriculum storage key, so a
profile has at most one track per curriculum.

- `Map<int trackId, …>` → key on `curriculumId.storageKey`.
- A file carrying BOTH a by-track and a by-curriculum map now has the SAME map
  twice — collapse them.
- `scopeDao.getScopesByTrack(trackId)` → `scopeRepo.getScopes(curriculumId)`.
- Sentinels: `c.trackId == 0` and `e.trackId == null` both meant "lifetime
  import". They become `source == CompletionSource.lifetimeOnly`.
- ⚠️ `LearningLedgerEntry.entryScope` is a UNIT scope (`seder` / `masechta` /
  `sefer` / `levelN`). It is NOT a lifetime-vs-track discriminator.

### 3.3 AD-24 — profile ids are ULID strings

This seam has broken the client/Cloud-Function boundary **twice** (`e2ab5aeb`,
P3-17), both times because each side was internally consistent so no gate caught
the disagreement. Always read the callee's real signature.

### 3.4 Drift → Firestore type map (verified by reading the classes)

| dead | live | defined in |
|---|---|---|
| `Completion` | `CompletionEntity` | `features/learning/domain/entities/completion_entity.dart` |
| `LearningLedgerData` | `LearningLedgerEntry` | `features/learning/domain/entities/learning_ledger_entry.dart` |
| `ProfileProgram` | `ProfileProgramEntity` | `features/tracks/setup/domain/entities/profile_program.dart` |
| `CurriculumTrack` | `CurriculumTrackEntity` | `features/tracks/setup/domain/entities/curriculum_track.dart` |

Delete outright: every `core/database/**` import, and
`core/providers/database_provider.dart`'s `userDatabaseProvider`.

### 3.5 The achievement / configuration distinction (owner ruling D-E)

- **Achievement-shaped** reads (completions, points, ledger, streaks) → THROW
  when the backend is not ready. `0`/`[]` is indistinguishable from a truthful
  answer and silently tells the learner they achieved nothing.
- **Configuration-shaped** reads (tracks, learning order, study-day configs,
  goals) → an empty list IS a legitimate state the UI already renders.

Canonical doc comment: `ProgressRepositoryNotReadyException` in
`features/progress/data/repositories/firestore_progress_repository_adapter.dart`.

### 3.6 ⚠️ D-E sharpened: in a WIDGET, "loudly" means VISIBLY, not FATALLY

A worker expressed a correct refusal-to-fabricate as `throw UnsupportedError`
inside `build()`, which would have shown every cloud-born account an error screen
on opening Parent Settings. **A crash is not a louder error message; it is a
worse regression than the bug it avoids.** Refusing to fabricate a value and
refusing to render are different decisions. See `backup_sync_section.dart`'s
`build()` for the pattern to copy.

### 3.7 Tutoring: tutors read the child's data DIRECTLY

`hasActiveTutorAccess` in `firestore.rules` grants a tutor read across **20
collections**, enforced server-side against a `tutor_active_access` index
maintained by Cloud Functions. The Drift mirror-pull model (pull into a local
mirror + delta listeners) is therefore **obsolete, not broken**.

Verified: the int→ULID keying bug that `docs/firestore-rewrite-map.md` documents
for `acceptInvite` is **already fixed** — `manage_tutors_screen.dart:291,296`
sends `profile.ulid`, and the CF stringifies that same ULID.

### 3.8 Offline semantics — settled EMPIRICALLY on device, do not re-theorise

`get()` does **not** reliably fall back to the cache offline; it can hang or
throw `unavailable`. Two earlier wrong claims about this were written into code
comments before a real device probe refuted both.

The established pattern for any read on a write path:

    try {
      snap = await ref.get().timeout(kFirestoreWriteAckTimeout);
    } on TimeoutException { /* degrade to "assume absent" */ }
      on FirebaseException catch (e) { if (e.code != 'unavailable') rethrow; }

Writes use `.orQueuedOffline` (`lib/data/firestore/write_ack.dart`) — applied at
19 write sites. **NEVER on reads.**

### 3.9 `conflict.dart` is dead BY DESIGN

`lib/data/firestore/conflict.dart` has **zero importers** — the whole module, not
just one function. `docs/firestore-rewrite-map.md:95` lists it among the
machinery Firestore makes unnecessary, rationale **"one writer per account"**.
Its header used to claim "every reconciliation path routes through this file",
which was false of every path; corrected in P3-39. Do not "wire it up" — there is
no client-side merge pipeline.

---

## 4. What this session landed (P3-27 … P3-39)

- **P3-27** The streak tee was a **NO-OP**: the provider built a Drift recorder
  from a deleted database, so `streakPort` was `null` and *every completion since
  the cutover wrote no streak event*. Reconnected with a deterministic
  `completion_YYYYMMDD` doc id.
- **P3-28** Wiring it **armed two latent defects**: a bare `ref.get()` that would
  hang an offline completion, and — subtler — the deterministic id makes the
  day's second mark an UPDATE, which `firestore.rules` SR-1 would have **denied
  silently** (the tee swallows). Fixed by sending the normalised day so same-day
  writes are byte-identical, satisfying SR-1's identical-replay clause.
- **P3-29** Progress adapter +5 seams. A free worker split them along the
  achievement/configuration line **unprompted** and documented why.
- **P3-30** Backup card: refuses to fabricate "synced" WITHOUT crashing. New
  l10n key in `app_en.arb` AND `app_he.arb` (the app ships Hebrew).
- **P3-31** Bulk-prior expunge migrated; `purgeCompletion` / `purgeEntry` seams
  opened. The worker refused to fabricate and threw an error carrying an exact,
  directly-executable migration path.
- **P3-32** **COLD CACHE** (owner ask #2).
- **P3-33/35** Stage definitions → `Ref`-taking adapter; `onboarding_providers`
  collapsed. This is where the callee-before-caller rule came from.
- **P3-34** Billing kill-switch committed (was **deployed but untracked**).
- **P3-36** Curriculum activation rewired + the siyum-retraction ruling (§6.1).
- **P3-37** `lifetime_knowledge_providers` 48 → 0, ⚠️ but four providers throw.
- **P3-38** Cold-cache tests (owner ask #3).
- **P3-39** `conflict.dart` header corrected.

All three of the owner's explicit asks — wire the delete Cloud Function, cold
cache, test them — are **closed and verified**.

---

## 5. Gates — how to run them, and current status

    cd learning_tracker && dart analyze --fatal-infos <paths>
    cd learning_tracker && dart run tool/check_dependency_direction.dart   # EXIT 0
    cd learning_tracker && flutter test test/data/repositories/            # 309/309 ✅
    cd learning_tracker && make test-functions                             # 339/339 ✅
    cd learning_tracker && make test-rules                                 # 116/116 (last run)

⚠️ `make test-functions` must run from `learning_tracker/`, NOT the repo root.
Run `flutter test test/data/repositories/` whenever a `data/repositories/` file
changes — that is not a "full test run" and is expected.

### ⚠️ Known-failing tests (pre-existing, D-G defers them)

`test/data/firestore/conflict_single_module_test.dart` — **3 failures**. It
asserts that `lib/core/sync/firestore_gateway_impl.dart`,
`lib/core/database/daos/points_balance_dao.dart` and
`lib/core/sync/merge/drift_merge_store.dart` call the canonical module. **All
three files were deleted with Drift**, so the test asserts a now-impossible
invariant. It should be deleted or rewritten alongside `conflict.dart` itself.

### Test debt accrued (deliberate, per D-G)

- ~10 files reference `BulkPriorCompletionService`'s old constructor.
- 2 files reference the three deleted `track*ByProfileProvider`s.
- Several reference `StageDefinitionRepositoryImpl` (renamed to
  `FirestoreStageDefinitionRepositoryAdapter`).

---

## 6. ⚠️ HELD-BACK decisions — do NOT delegate these

### 6.1 Siyum retraction on expunge — RULING MADE, NOT IMPLEMENTED

`expungePriorCompletions` still throws `UnsupportedError`. The seams
(`purgeCompletion`, `purgeEntry`) are open but unused.

**Evidence found:** nothing in `lib/` **writes** an `unmark_` ledger row — only
`lifetime_tree_builder` and two providers read them. That mechanism's writer died
with Drift, so `purgeEntry`'s `purged_at` tombstone is the live path.

**The ruling:** ledger entries are per `(curriculumId, unitIdentifier)` and carry
an incrementing `completionNumber` — one per cycle/chazara. So:

> Retract the **highest-`completionNumber`** entry for the unit containing the
> expunged ref, and **only** when the remaining non-purged completions no longer
> cover that unit.

Both clauses matter. Retracting by unit alone would erase earlier legitimate
cycles (a learner who finished a masechta three times would lose all three).
Retracting unconditionally would be wrong when a `live` completion still covers
the ref.

### 6.2 ⚠️ `trackDualProgressMetricsProvider` THROWS and has 12 consumers

Including the dashboard's active-track card, `progress_screen`,
`curriculum_progress_screen`, `track_detail_screen`. Accepted ONLY as an
intermediate state because the file had 48 compile errors immediately before —
nothing regressed from working. **IT MUST NOT SHIP THROWING.**

Fix, fully specified: `TrackDualProgressMetric.trackId` is redundant with the
class's existing `final CurriculumId curriculumId`. Delete `trackId`, re-key
`trackCustomNameProvider` (`family<String?, int>` at
`track_management_providers.dart:46`) to `CurriculumId`, update
`progress_screen.dart:~345` and `curriculum_progress_screen.dart:~80`, and
reimplement the provider from the adapter's `getAllTracks()` /
`getProgramsByCurriculum()` / `getScopes()` / ledger reads.

### 6.2b ⚠️ The AD-24 profile cluster is BLOCKED ON `build_runner`

§7 recommends the profile cluster as the biggest coherent unit. It is — but as
described there it **cannot succeed**, and three separate attempts failed for
this reason before it was spotted:

`ProfileModel` is a **freezed** class (`part 'profile_model.freezed.dart'`, ~12KB
generated). Dropping `int id` / `int accountId` requires REGENERATING that file
— `dart run build_runner build`. Every worker dispatch in this session carried
"do NOT run build_runner", so the change was structurally impossible as
dispatched.

**Before retrying:** authorise build_runner for this specific change, and run it
YOURSELF after the source edit so the regeneration stays controlled.

Already measured, so it need not be re-derived — which identity field survives:

    profile `.ulid` uses : 33
    `profile.id` uses    : 18

So **KEEP `ulid`, DROP `id` and `accountId`** — lower churn AND the
Firestore-native name. (`.accountId` shows 52 hits repo-wide, but most are on
`Account`, not `ProfileModel`; re-measure before acting.)

Decompose it — the 7-file cluster defeated three different models as one unit:

    step 1  profile_model.dart + profile_repository.dart, then build_runner
    step 2  profile_repository_impl.dart
    step 3  the four consumers, in small batches

### 6.3 Offline step 2 — process-kill survival UNVERIFIED

Needs `flutter run` + `am force-stop` + `am start` (the test harness uninstalls
the app, which destroys the cache and invalidates the check). **Blocked until lib
errors reach 0** — the app cannot be built or run before then.

### 6.4 A real Firestore sync status is achievable

`SnapshotMetadata.hasPendingWrites` + `isFromCache` give syncing/synced/offline
without resurrecting the Drift engine. Recorded as `TODO(AD-30)` in
`backup_sync_section.dart`.

---

## 7. Remaining work — 376 errors, ordered callee-first

Top files (`dart analyze --fatal-infos` from `learning_tracker/`):

    25  features/tracks/setup/presentation/screens/track_detail_screen.dart
    16  features/profiles/data/repositories/profile_repository_impl.dart
    15  features/settings/presentation/screens/upgrade_to_cloud_screen.dart
    14  features/profiles/presentation/widgets/tutored_children_section.dart
    13  features/settings/presentation/screens/lifetime_marking_screen.dart
    11  features/account/presentation/notifiers/sign_in_controller.dart
    10  features/tracks/setup/presentation/screens/edit_track_screen.dart
     9  features/tracks/setup/domain/services/track_creation_service.dart      ← CALLEE
     9  features/gamification/presentation/providers/points_providers.dart     ← CALLEE
     9  features/account/presentation/providers/auth_state_provider.dart       ← CALLEE
     8  features/notifications/data/services/sacred_window_repository.dart     ← CALLEE
     7  features/account/domain/services/local_auth_service.dart               ← CALLEE
     7  features/onboarding/domain/services/learning_process_wizard_service.dart

**The AD-24 profile cluster** is the single biggest coherent unit — ~41 errors
across 7 files, all one int→ULID seam. A worker correctly REFUSED
`profile_repository_impl` alone and proved why: `ProfileRepository` is still
int-keyed (`getProfileById(int id)`, `ensureDefaultProfile → Future<int>`) and
`ProfileModel` requires `int id` + `int accountId` + `String ulid`, but those
ints came ONLY from deleted Drift rows. **`ProfileModel` already carries `ulid` —
that is the identity.** Drop `id`/`accountId` and propagate through:
`profile_model.dart`, `profile_repository.dart`, `profile_repository_impl.dart`,
`auth_state.dart`, `profile_guard.dart`, `profile_providers.dart`,
`sign_in_controller.dart`.

Callers to fix only AFTER their callee lands: `edit_track_screen` and
`track_detail_screen` (after `track_creation_service`); `point_config_screen` and
`parent_pending_redemptions_screen` (after `points_providers`);
`upgrade_to_cloud_screen` and `sign_in_controller` (after the auth cluster);
`dashboard_providers` / `dashboard_screen` / `active_track_card` and
`lifetime_marking_screen` (after §6.2).

---

## 8. Session scratch state (survives only while the session lives)

    <scratchpad>/MIGRATION_BRIEF.md   — the shared worker brief: TYPE MAP, AD-25,
                                        AD-23/AD-28, no-fabrication clause.
                                        EVERY dispatch tells the worker to read it first.
    <scratchpad>/QUEUE-S2.md          — in-flight targets, held-back decisions
    <scratchpad>/MODELS.md            — free-model behaviour, the three failure modes

If these are gone, **recreate `MIGRATION_BRIEF.md` first** from §3 of this
document — worker quality depends on it more than on anything else.

The authoritative narrative record is `docs/planning/firestore-cutover-log.md`
(entries are inserted at line 2447 via `sed -i "2447r /tmp/pNNN.md"`, newest
first).
