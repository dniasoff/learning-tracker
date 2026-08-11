# Phase 3 handoff #5 — Drift → Firestore cutover

**Written 2026-08-11. SUPERSEDES `phase3-handoff-4.md`**, which is still correct
on architecture (§3) and worth reading, but this file is the current state and
carries two new owner decisions.

**State:** HEAD `d8661e8d`. **39 commits on `dev`, 48 ahead of `origin/dev`, ALL
UNPUSHED.** Tree clean. `lib` analyzer errors **353** (720 at phase start).
Worker cost to date **$0.00**.

**Standing owner mandate: keep going until lib errors are 0.**
⚠️ But read §6.1 first — driving errors to zero *naively* will create a
user-facing bug. Zero errors is not the same as a working app.

---

## 0. You are an ORCHESTRATOR — the contract

- **Delegate all repository changes to worker models.** Do not Edit/Write repo
  files yourself. Scratch files are exempt.
- **NEVER delegate verification.** You run `dart analyze`, the gates, and you read
  every diff. A worker's report is a claim, not evidence.
- **NEVER push. NEVER deploy** — except §6.1, which needs a rules deploy and
  therefore needs explicit owner authorisation first.
- No branches, no worktrees, no `git stash`, no `git add -A` (explicit paths only).
- **Never run `make ci`** in one invocation (standing owner policy).
- **D-G: no full test runs mid-migration.** `dart analyze` is the progress signal.
  Targeted gates ARE run — §5.
- GREENFIELD: no live users, no data worth preserving.

---

## 1. ⚠️ HOW TO RUN WORKERS — read before dispatching anything

### 1.1 Free models have COLLAPSED for open-ended work

Measured this session, not guessed:

| model | open-ended migration | script execution |
|---|---|---|
| `kilo` / `kilo-auto/free` | **0/3** — `[retry]` (rate-limited) + reason-to-budget (`9600 in, 10000 reasoning, 0 out`) | was fine earlier, now degraded |
| `opencode` / `nemotron-3-ultra-free` | **0/1** — empty response, no tokens at all | untested |
| `opencode` / `deepseek-v4-flash-free` | **0/2** — empty response | **9/9**, 40–170 tokens/run |

**The only reliable pattern left: YOU author the change as a script on disk, a
worker executes it by path.** That has never once produced a wrong edit. Nine for
nine.

Dispatch template that works:

> Run EXACTLY this command, ONCE. The python script already exists on disk — do
> NOT open, read, retype, or reconstruct it. Just run it.
> `python3 /abs/path/to/script.py`
> Then report RAW output of: `dart analyze --fatal-infos <paths> | tail -5`
> and `dart run tool/check_dependency_direction.dart >/dev/null 2>&1; echo EXIT=$?`
> PROHIBITIONS: no commit/push/deploy/`git add -A`, no test suite, no build_runner.

Untried free models if these degrade further: `north-mini-code-free`,
`longcat-2.0-free`, `laguna-s-2.1-free`, `ling-3.0-tiny-free`, `mimo-v2.5-free`.

⚠️ Cost is **$0.00 on all of them**, so model choice is a QUALITY and WALL-CLOCK
decision, never a budget one.

### 1.2 Three distinct worker failure modes

| mode | signature | correct response |
|---|---|---|
| MCP idle timeout | task reported `failed` ~1800s, session still `busy` | **do nothing** — worker is alive and still writing. Verify via `git status`. |
| reason-to-budget | session `idle`, **0 output tokens**, no file change | re-dispatch on a different model — retrying the same one repeats it |
| genuine BLOCKED | session `idle`, a real report | read it — often the most valuable output of the run |

⚠️ **`idle` + no file change is ambiguous.** Check the output-token count. The
best analysis of the session (the `profile_repository_impl` refusal) and a total
no-op (`sacred_window`) both showed `idle`.

⚠️ **An MCP idle timeout is NOT a worker failure** — it kills your visibility, not
the worker. Several of this phase's best commits arrived with no report at all
("the report died, the work survived"), and had to be reviewed diff-by-diff.
**Never re-dispatch a timed-out target** — two workers on one file corrupts it.

### 1.3 Track progress by `git status` and the error count, NEVER by task status

A batch of seven dispatches once sat "in flight" for hours doing **nothing**.
After any batch, re-check the error count; if it has not moved, read a session's
token counts before assuming the work is merely slow.

### 1.4 Never sample `dart analyze` while workers are mid-write

One reading returned **950** when the truth was **475**; another 351 vs 349.

### 1.5 A contract split across two files needs the SECOND re-verified

Two workers each did half the curriculum-activation rewire. The service gained a
dependency after the provider was written, so the provider constructed it with one
argument and an import was missing. **Both reports were individually truthful and
jointly wrong.**

### 1.6 Check a worker's JUSTIFICATION as carefully as its code

One threw `UnsupportedError` citing "no presentation-legal provider exists yet" —
false since P3-29, and the dispatch had named the methods. Workers reaching for
`throw` sometimes justify it with a reason that has expired.

---

## 2. SEQUENCING: callee before caller

**The single most useful rule discovered.** A Drift-era class that takes its
dependencies as CONSTRUCTOR ARGUMENTS blocks EVERY caller, because each caller
would otherwise have to reach the data-access ring itself — which AD-23/AD-28
forbids from `presentation/` and `domain/`.

Converting the callee to take `Ref` does not merely unblock callers, it makes them
**smaller**. `onboarding_providers.dart` collapsed from a seven-line construction
over `db.stageDao` / `db.completionDao` / `syncFacade?.pushStageDefinitions` to:

    final stageRepo = FirestoreStageDefinitionRepositoryAdapter(ref: ref);

**Order the queue by dependency, NOT by error count.** When a presentation file's
errors are all "undefined name" on Drift-era injected dependencies, do not touch
that file — convert its callee.

Target shape (used by the progress, bookmark, stage-definition, curriculum-track
and study-day-config adapters):

    SomeAdapter({required Ref ref}) : _ref = ref;   // constructed as SomeAdapter(ref: ref)

---

## 3. Architecture facts — do not re-derive

Full detail in `phase3-handoff-4.md` §3. Summary:

- **Layering:** `check_dependency_direction.dart:57` exempts EXACTLY
  `/data/repositories/`. Not `/data/`, not `/data/services/`. Fix by `git mv`-ing
  the file into its feature's `data/repositories/` (done 3× this phase).
- **AD-25:** `CurriculumTrackEntity` has no `id`; `LearningLedgerEntry` has no
  `trackId`. A track IS its curriculum. Re-key `Map<int trackId, X>` onto
  `curriculumId.storageKey`. Sentinels `c.trackId == 0` / `e.trackId == null` →
  `source == CompletionSource.lifetimeOnly`.
  ⚠️ `entryScope` is a UNIT scope (`seder`/`masechta`/`sefer`/`levelN`), NOT a
  lifetime-vs-track discriminator.
- **AD-24:** profile ids are ULID Strings. This seam broke the
  client/Cloud-Function boundary twice (`e2ab5aeb`, P3-17) because each side was
  internally consistent, so no gate caught it.
- **Type map:** `Completion`→`CompletionEntity`,
  `LearningLedgerData`→`LearningLedgerEntry`, `ProfileProgram`→`ProfileProgramEntity`,
  `CurriculumTrack`→`CurriculumTrackEntity`. All `core/database/**` and the whole
  `core/sync` outbox engine are deleted.
  ⚠️ `core/database/registry/device_registry_database.dart` is a DIFFERENT, LIVE
  database (the device-local account registry). Do not delete it.
- **D-E, achievement vs configuration:** achievement reads (completions, points,
  ledger, streaks) THROW when not ready; configuration reads may return empty.
  **Whether `0`/`[]` is legitimate is a property of the BRANCH, not the method** —
  the same function can owe a truthful zero on one path and a loud failure on
  another.
- **D-E in a WIDGET means VISIBLY, not FATALLY.** A `throw` from `build()` is a
  worse regression than the bug it avoids. Copy `backup_sync_section.dart`'s
  `build()`.
- **Offline:** `get()` does NOT reliably fall back to cache; it can hang or throw
  `unavailable`. Settled empirically on-device after two wrong claims were written
  into comments. Pattern: `.timeout(kFirestoreWriteAckTimeout)` + catch
  `FirebaseException` code `unavailable`, degrade to "assume absent". Writes use
  `.orQueuedOffline` (`lib/data/firestore/write_ack.dart`), **never on reads**.
- **Cold cache:** an unsynced cache returns empty, indistinguishable from a real
  zero. `isFromCache` CANNOT decide it (a new profile looks identical). The
  discriminator is the **profile document's presence**
  (`FirestoreLearnerProfileRepository.hasHydratedCache`), probed ONLY when a read
  returns empty. Propagated to progress reads and the notification path.
- **Tutoring:** tutors read the child's data DIRECTLY — `hasActiveTutorAccess`
  grants read across 20 collections, server-enforced. The Drift mirror-pull model
  is obsolete, not broken.
- **`conflict.dart` is dead BY DESIGN** — zero importers, rationale "one writer per
  account" in the rewrite map. Do not wire it up.

---

## 4. Gates

    cd learning_tracker && dart analyze --fatal-infos <paths>
    cd learning_tracker && dart run tool/check_dependency_direction.dart   # EXIT 0
    cd learning_tracker && flutter test test/data/repositories/            # 309/309 ✅
    cd learning_tracker && make test-functions                             # 339/339 ✅
    cd learning_tracker && make test-rules                                 # 116/116

⚠️ `make test-functions` must run from `learning_tracker/`, NOT the repo root.
Run the repository suite whenever a `data/repositories/` file changes — that is
not a "full test run".

### Known-failing, pre-existing (D-G defers)

`test/data/firestore/conflict_single_module_test.dart` — **3 failures**. It asserts
that `firestore_gateway_impl.dart`, `points_balance_dao.dart` and
`drift_merge_store.dart` call the canonical module; **all three were deleted with
Drift**, so it asserts a now-impossible invariant. Delete or rewrite it alongside
`conflict.dart`.

### Test debt accrued deliberately

~10 files reference `BulkPriorCompletionService`'s old constructor; 2 reference the
three deleted `track*ByProfileProvider`s; several reference
`StageDefinitionRepositoryImpl` (renamed `FirestoreStageDefinitionRepositoryAdapter`).

---

## 5. ⚠️ OWNER-APPROVED WORK: restore per-curriculum point overrides

**The owner approved this on 2026-08-11 ("yes restore per-curriculum point
overrides"). It is now required work, not a decision.**

### Why

`point_configs` was a **Drift-only** table, retired with the user DB.
`FirestoreCompletionPointsAwarder` currently applies a hardcoded ladder
(`Learn=10, Chazara1=5, Chazara2=3, else 1`) — which is what the Drift original
fell back to when no config row existed — and its class doc records that
per-curriculum overrides no longer apply.

But **`PointConfigScreen` is still live**, routed from
`parent_settings_screen.dart:211`. It has 9 analyzer errors, so it does not
compile — **and that broken build is the only thing currently hiding the problem.**
Clear those errors mechanically and a parent can change points per stage, watch
the UI accept it, and have it silently do nothing.

**Note the shape: the defect ARRIVES as a result of fixing the errors.** This is
why "drive errors to 0" must not be followed naively.

### Design (verified against the live rules file)

**Collection** — profile-scoped, mirroring `study_day_configs`:

    users/{uid}/learner_profiles/{profileId}/point_configs/{configId}

**Doc id** — deterministic from the natural key so a retry/offline replay is
idempotent (same reasoning as the streak recorder's `completion_YYYYMMDD`):

    {curriculumStorageKey}_{stageOrder}      e.g.  genesis_1

**Document shape:**

    curriculum_id : String   (CurriculumId.storageKey)
    stage_order   : int      (1 = Learn, 2 = Chazara1, …)
    points        : int      (the override)
    updated_at    : Timestamp

**`firestore.rules`** — insert as a sibling of `study_day_configs`, whose block
starts at **line 601** and is the LAST match block before the closing braces
(file is 613 lines). Match that block's conventions exactly — note config
collections allow `delete`, unlike the achievement collections which use
`allow delete: if false`:

    match /point_configs/{configId} {
      allow read: if isOwner(uid) || hasActiveTutorAccess(uid, profileId);
      allow create, update: if isOwner(uid)
        && request.resource.data.keys().hasOnly([
          'curriculum_id', 'stage_order', 'points', 'updated_at'
        ]);
      allow delete: if isOwner(uid);
    }

⚠️ **A rules DEPLOY is required** for this to work — the global default-deny means
the client cannot write `point_configs` until the ruleset ships. **Deploying needs
explicit owner authorisation.** The owner authorised exactly one rules deploy
earlier in this phase; do not assume it extends. ASK.

**Repository:** `lib/data/repositories/firestore_point_config_repository.dart`,
modelled on `firestore_study_day_config_repository.dart`, plus a
`FutureProvider<FirestorePointConfigRepository?>` in
`lib/data/firestore/repository_providers.dart` following the existing
`_watchActiveAccountAndProfile` shape.

    Future<Map<int, int>> getConfigsForCurriculum(CurriculumId curriculumId);  // stageOrder -> points
    Future<void> setConfig({required CurriculumId curriculumId, required int stageOrder, required int points});
    Future<void> clearConfig({required CurriculumId curriculumId, required int stageOrder});

**Awarder wiring** — `completion_points_awarder.dart`. This is the part that must
be exactly right:

- **Override exists** → use it.
- **No override document** → fall back to the hardcoded ladder. This is a
  LEGITIMATE answer, not a failure — it is exactly what the Drift original did.
- **Repository not ready (resolves to `null`)** → **THROW**, do NOT fall back.
  A not-ready backend is a contradictory state here (a completion is being
  recorded, so a profile provably exists), and silently applying the ladder would
  under-credit a child whose parent had configured a higher value. That distinction
  — *absent override* vs *cannot tell* — is the whole point; see the same
  branch-level split already applied in `calculatePoints`.

**Screen:** `point_config_screen.dart` (presentation) may NOT import the ring. Add
an adapter under `features/gamification/data/repositories/` taking `Ref`, and have
the screen read/write through it.

**Tests:** `test/data/repositories/firestore_point_config_repository_test.dart`,
mirroring the study-day-config tests. Cover: round-trip, deterministic doc id
(same `(curriculum, stageOrder)` → same doc), override-wins-over-ladder, and
no-override-falls-back-to-ladder. ⚠️ `fake_cloud_firestore` has **no offline/cache
semantics**, so the not-ready/throw path cannot be exercised there — state that
limitation in the test file rather than implying coverage.

---

## 6. Other open items

### 6.1 ⚠️ `trackDualProgressMetricsProvider` THROWS and has 12 consumers

Including the dashboard's active-track card, `progress_screen`,
`curriculum_progress_screen`, `track_detail_screen`. Accepted only as an
intermediate state because the file had 48 compile errors before it — nothing
regressed from working. **MUST NOT SHIP THROWING.**

**RECOVER the original algorithm from git; do NOT reconstruct it from the doc
comments** — that would be fabricating an achievement computation from a
description of one.

    git show 94d9013d~1:learning_tracker/lib/features/progress/presentation/providers/lifetime_knowledge_providers.dart

`currentCyclePercentage` is around line 695 there. Also read `7c490bad`
(lifetimePercentage excludes lifetime-only imports), `5db8634c` (memory-bounded
denominator), `bf692d71` (deleted track shown as active) — each fixed a real
defect.

**Method:** recover verbatim, then re-point ONLY the data sources —
`db.trackDao.getActiveTracksForProfile` → `adapter.getAllTracks()`,
`db.profileProgramDao` → `adapter.getProgramsByCurriculum()`, `curriculumScopeDao`
→ `adapter.getScopes(id)`, by-trackId maps → by-`curriculumId.storageKey`. Every
arithmetic line should survive unmodified. Also delete `trackId` from
`TrackDualProgressMetric` (redundant with its existing `curriculumId`) and re-key
`trackCustomNameProvider` (`family<String?, int>` at
`track_management_providers.dart:46`) onto `CurriculumId`.

Five of the six throws in that file are zero-consumer or private-unused and can be
deleted outright. Four models have failed this as an open-ended task — it is not
subtle, it is LONG. Author it as a script from the recovered source.

### 6.2 ⚠️ AD-24 profile cluster is BLOCKED ON `build_runner`

`ProfileModel` is **freezed**. Dropping `int id`/`int accountId` requires
regenerating `profile_model.freezed.dart`. Every dispatch this session carried
"do NOT run build_runner", so the cluster was structurally impossible as
dispatched — three attempts failed for this reason.

**Authorise build_runner for this change and run it YOURSELF** after the source
edit.

Measured: `.ulid` has **33** uses vs `profile.id`'s **18** → **keep `ulid`, drop
`id` and `accountId`**. Decompose: (1) `profile_model.dart` +
`profile_repository.dart` then build_runner; (2) `profile_repository_impl.dart`;
(3) the four consumers in small batches.

### 6.3 Siyum retraction — RULING MADE, NOT IMPLEMENTED

`expungePriorCompletions` still throws. Seams (`purgeCompletion`, `purgeEntry`)
are open but unused.

Evidence: **nothing in `lib/` writes an `unmark_` ledger row** — only readers
reference them, so that mechanism's writer died with Drift. `purgeEntry`'s
`purged_at` tombstone is the live path.

**Ruling:** ledger entries carry an incrementing `completionNumber` per
`(curriculum, unit)` — one per cycle/chazara. So retract the
**highest-`completionNumber`** entry for the affected unit, and **only** when
remaining non-purged completions no longer cover it. Retracting by unit alone
would erase earlier legitimate cycles.

### 6.4 Offline step 2 — process-kill survival UNVERIFIED

Needs `flutter run` + `am force-stop` + `am start` (the test harness uninstalls the
app, destroying the cache and invalidating the check). **Blocked until errors
reach 0** — the app cannot be built before then.

### 6.5 A real Firestore sync status is achievable

`SnapshotMetadata.hasPendingWrites` + `isFromCache` give syncing/synced/offline
without resurrecting the Drift engine. `TODO(AD-30)` in `backup_sync_section.dart`.

---

## 7. Remaining work — 353 errors, ordered callee-first

**Callees to convert FIRST** (each unblocks its callers):

    9   features/tracks/setup/domain/services/track_creation_service.dart      → unblocks edit_track_screen (10), track_detail_screen (25)
    9   features/gamification/presentation/providers/points_providers.dart     → unblocks point_config_screen (9), parent_pending_redemptions_screen (8)
    9   features/account/presentation/providers/auth_state_provider.dart       → unblocks upgrade_to_cloud_screen (15), sign_in_controller (17), backup_sync_section
    7   features/onboarding/domain/services/learning_process_wizard_service.dart
    5   features/account/domain/services/account_lifecycle_service.dart
    5   features/account/domain/models/auth_state.dart
    5   features/scheduler/data/repositories/scheduler_learning_order_repository_impl.dart
    4   features/scheduler/data/repositories/scheduler_stage_repository_impl.dart
    4   core/providers/database_provider.dart
    3   features/tracks/setup/domain/services/track_edit_service.dart
    3   features/tracks/domain/services/track_progress_service.dart
    3   features/scheduler/domain/services/study_day_toggle_service.dart

**Then the callers:**

    25  features/tracks/setup/presentation/screens/track_detail_screen.dart
    17  features/account/presentation/notifiers/sign_in_controller.dart          (AD-24, §6.2)
    16  features/profiles/data/repositories/profile_repository_impl.dart         (AD-24, §6.2)
    15  features/settings/presentation/screens/upgrade_to_cloud_screen.dart
    14  features/profiles/presentation/widgets/tutored_children_section.dart      (tutored cluster, 6 files)
    13  features/settings/presentation/screens/lifetime_marking_screen.dart       (after §6.1)
    10  features/tracks/setup/presentation/screens/edit_track_screen.dart
    9   features/dashboard/presentation/screens/dashboard_screen.dart             (after §6.1)
    9   features/gamification/presentation/screens/point_config_screen.dart       (⚠️ see §5)
    7   features/dashboard/presentation/providers/dashboard_providers.dart        (after §6.1)
    …tail of ~40 files at 1–5 errors each

`LocalAuthService` was just migrated (device registry, credential-less) — its
callers `signup_screen.dart` (5) and `sign_in_controller.dart` (17) still use the
old `dao:`/`password:` API and are part of the AD-24 cluster.

---

## 8. Session scratch state (dies with the session)

    <scratchpad>/MIGRATION_BRIEF.md   — the shared worker brief. EVERY dispatch tells
                                        the worker to read it first. Worker quality
                                        depends on this more than anything else.
    <scratchpad>/QUEUE-S2.md          — in-flight targets, held decisions
    <scratchpad>/MODELS.md            — free-model behaviour, the three failure modes

**If these are gone, recreate `MIGRATION_BRIEF.md` first** from §3 above.

Authoritative narrative record: `docs/planning/firestore-cutover-log.md` (entries
inserted at line 2447 via `sed -i "2447r /tmp/pNNN.md"`, newest first).
