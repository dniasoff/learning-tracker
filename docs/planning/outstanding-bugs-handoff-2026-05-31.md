# Outstanding bugs — handoff (2026-05-31)

These are the **confirmed, not-yet-fixed** defects from the on-device sweep + the adversarial bug-hunt.
Each has a pinned file:line, root cause, and fix. 12 sibling defects (D1–D5, B1, B2, D8–D12) are already
fixed + committed green to `dev` — see `test-fix-bug-log.md`. Fuller verifier reasoning for each item below is in
`bug-hunt-findings-2026-05-31.md`.

## Working rules (per the standing mandate)
- Fix the **root cause**, no TODOs/tech-debt. Add a **regression test** that fails before / passes after.
- `cd learning_tracker` → `dart format .` → **`make ci` must be green** (analyze + format-check + ~8950 tests) before committing.
- Commit each fix to **`dev`** (no feature branches). End commit messages with
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- Codegen: after editing a `@riverpod`/Drift/Freezed signature run `dart run build_runner build --delete-conflicting-outputs`.
- `--fatal-infos` is on: watch `directives_ordering` (sort imports) and `use_named_constants`.

---

## Priority 1 — DATA-LOSS (sync; do first, with fresh focus — merge engine)

### D14 · points-ledger rows can be permanently lost from cloud sync
- **File:** `learning_tracker/lib/core/database/daos/points_balance_dao.dart:497` (+ `_applyDelta`/`createRedemption`/`parentAdjust` ~:121,:204,:432)
- **Symptom:** Points awarded/redeemed/refunded on one device never reach Firestore / other devices; balances diverge permanently with no recovering retry.
- **Root cause:** The balance+ledger row commits inside `db.transaction()`, but `_pushLedgerEntry` (the outbox enqueue) runs **after** the transaction returns — non-atomic; a crash in that window leaves a durable ledger row never enqueued. Worse, `_pushLedgerEntry` returns early when `syncSink == null` (:499); on a cloud-born account the features layer wires `PointsBalanceDao.syncSink` slightly **after** the first credit, so that delta is silently dropped. Nothing ever re-scans `points_ledger` for un-enqueued rows.
- **Fix:** Enqueue the ledger outbox row **inside the same `db.transaction()`** as the ledger write (insert into `Outbox` directly — see `outbox_sync_write_facade.dart:19-23`). Add a startup/post-wire reconciliation that re-enqueues any `points_ledger` rows lacking a pushed/outbox record (recovers rows written while `syncSink` was null).
- **Test:** seed a credit while `syncSink == null`, then wire it + run reconciliation → assert the outbox now has the ledger row; and assert enqueue happens atomically (simulate a post-commit throw → row still enqueued or recoverable).

### D15 · `remoteIsNewer` clobbers a newer un-pushed local edit inside the 5 s window
- **File:** `learning_tracker/lib/core/sync/merge/drift_merge_store.dart:132` (falls through to `return true` at :145)
- **Symptom:** A local edit made within ~5 s of an incoming remote write but **not yet pushed** (no local `synced_at`) is silently overwritten by an **older** remote value, even though local `updated_at` is newer.
- **Root cause:** In the ≤5 s window the server-timestamp tie-break only runs when **both** `remoteSyncedAt` and `localSyncedAt` are non-null. A fresh local edit has `updated_at` but no `synced_at` (set only after a successful push) → the `localSyncedAt != null` guard fails → falls through to the unconditional “prefer remote”.
- **Fix:** Before defaulting to “prefer remote”, when only one side (or neither) has a `synced_at` within the window, compare client `updated_at` — prefer the strictly-newer `updated_at`; only treat true equality as the convergence tie that prefers remote. Don’t let a missing local `synced_at` downgrade a demonstrably-newer local edit.
- **Test:** local row `updated_at = T`, no `synced_at`; remote arrives `updated_at = T−3s` with `synced_at` set → `remoteIsNewer` must be **false** (keep local). Add the both-null and remote-newer cases too.

---

## Priority 2 — CORRECTNESS

### D13 · sync status shows 'Synced' while a profile-0 outbox row is stuck  *(fix already pinned)*
- **File:** `learning_tracker/lib/core/sync/sync_orchestrator.dart:940`
- **Symptom:** `SyncStatusIndicator` shows green 'Synced' even though the bootstrap `learner_profile` push (or any profile-0 row) is wedged (e.g. permission-denied) and never reaches the cloud.
- **Root cause:** `_doDrain` sweeps the active profile **and profile 0** (`outbox_processor.dart:201-207`), but `_recomputeOutboxStatus` queries only `_profileId` (depth/oldestPendingAt/stuckCount, each scoped to one profile_id). Profile-0 rows are invisible → `depth == 0` → emits `SyncStatus.synced`.
- **Fix:** When `_profileId != 0`, sum `depth`/`stuckCount` across `_profileId` **and** `0` and take the min `oldestPendingAt` (mirror `_doDrain`’s two-profile sweep).
- **Test:** orchestrator with a real `outboxDao` + a failing pipeline; enqueue a profile-0 row that won’t drain → recompute → status is `degraded`/`pending`, not `synced`. (Needs the `resolveOutboxDao` + failing-pipeline harness; not in the existing drain-triggers `_buildSetup`.)

### D16 · streak counts by UTC day while the rest of the app uses LOCAL days
- **File:** `learning_tracker/lib/features/gamification/streak/streak_reducer.dart:75` (`_utcDay`) + `streak_state_provider.dart:62` (`nowUtc()` anchor)
- **Symptom:** In negative-UTC offsets (Americas), the headline streak disagrees with the Recent-Activity calendar dots and breaks/extends on the wrong boundary. E.g. US-Pacific: Mon 11pm + Tue 1am local = two LOCAL days (two dots) but one UTC day → streak shows 1 instead of 2.
- **Root cause:** Reducer buckets each `eventTimestamp` into a **UTC** calendar day and the provider passes `today = nowUtc()`, while everything else (LocalDayClock, scheduler, the streak-calendar feed via `_extractLocalDate`) uses **local** days.
- **Fix:** Bucket by LOCAL day: `final l = t.toLocal(); return DateTime(l.year, l.month, l.day);` and pass `clock.today()` (local) as the anchor.
- **Test:** with a fixed non-UTC offset, two completions on consecutive local days that share a UTC day → `currentStreak == 2`; and a same-local-day pair → `1`.

### D17 · live streak stream captures 'today' once → stale across midnight  *(LOW)*
- **File:** `learning_tracker/lib/features/gamification/streak/streak_state_provider.dart:69`
- **Symptom:** A dashboard left open across midnight with no new completion keeps showing the streak as alive the next day; only corrects on rebuild/relaunch.
- **Root cause:** `watch()` reads `today = _clock.nowUtc()` **once** before yielding, then reuses it in every `reduce()`; the stream only re-emits on `streak_events` changes, never on a day rollover.
- **Fix:** Recompute `today` inside the `.map` closure (use `_clock.today()`), and/or combine the events stream with a local-midnight rollover tick. (Naturally pairs with D16.)
- **Test:** advance a fake clock past local midnight with no new events → emitted streak lapses to 0.

### D18 · parent-revoked talmid resurrects as ACTIVE on the tutor's device
- **File:** `learning_tracker/lib/features/tutoring/presentation/providers/manage_tutors_providers.dart:104` (`_reconstructActiveGrantFromMirror` ~:121)
- **Symptom:** After a parent revokes a tutor grant, the talmid keeps showing as an ACTIVE tutored child on the tutor’s device (profile picker, manage-grants, Settings) and stays tappable, until an entry pull happens to fail permission-denied.
- **Root cause:** `incomingTutorGrantsProvider` unions the CF result with locally-mirrored active talmidim, suppressing a mirror only when `cfGrantIds.contains(...)`. `listTutorGrants` returns only active/pending grants, so a revoked grant is absent from CF and gets reconstructed from the still-present local mirror. The mirror is only wiped on the tutor’s own resign or a permission-denied pull; the parent’s revoke runs `wipeMirrorForGrant` on the **parent’s** device (0 rows; can’t touch the tutor’s DB). The “does not resurrect here” comment (:100-102) is false for parent-initiated revoke.
- **Fix:** When the CF call genuinely **succeeded** (distinguish online-success vs offline-failure — have `listIncomingGrants` signal this instead of swallowing to `[]`), reconcile: for each local mirror whose `tutorGrantId` is NOT in the returned active/pending set, `wipeMirrorForGrant(grantId)` (and exit the session if it’s the active selection) before building the union. Only fall back to mirror reconstruction when the CF failed offline.
- **Test:** mirror present + CF returns a set WITHOUT that grantId (online) → mirror wiped, talmid absent; CF offline-fail → mirror retained.

### D19 · cloud-account delete leaves a ghost registry row (account reappears in picker)
- **File:** `learning_tracker/lib/features/account/domain/services/account_management_service.dart:61` (`deleteAccount`)
- **Symptom:** After fully deleting a cloud account via Settings, it still appears in the Account Picker on next launch; tapping it activates an empty shell.
- **Root cause:** `deleteAccount(uid)` only clears the user-DB **table rows**, deletes Firestore + Firebase Auth, and `prefs.clear()`. It never touches the **device registry** (separate Drift DB) or deletes the per-account DB **file**. The registry row + `lastActiveAccountId` survive → `AuthGuard` finds the stale row and routes to the picker.
- **Fix:** After the delete cascade, remove the registry entry + DB file. Simplest: route the Settings cloud-delete through `AccountLifecycleService.deleteCloudAccount` (already does Firestore+Auth+`_deleteDbFile`+`registry.removeAccount`) and reset `accountDbFileNameProvider` to `'learning_tracker'`. (Note: `removeAccount` now also clears `lastActiveAccountId` — D10, already fixed.) `AccountManagementService` currently has no registry dep — wiring that, or re-routing the flow, is the work.
- **Test:** after delete, `registry.getAllAccounts()` no longer contains the account; `lastActiveAccountId` cleared.

### D20 · swiping away the ACTIVE account in the picker deletes its open DB file
- **File:** `learning_tracker/lib/features/account/presentation/screens/account_picker_screen.dart:539` (`_onDismissed`)
- **Symptom:** The picker is reachable mid-session (Profile Switcher → Switch Account). Swiping the row of the **currently-active** account `deleteSync`s its SQLite file out from under the open Drift connection → later writes go to an orphaned inode (lost), reads can throw, while `authState`/`selectedProfileId` still point at it.
- **Root cause:** `_onDismissed` calls `removeCloudFromDevice`/`deleteLocalAccount` (which `_deleteDbFile`) with **no check** that the dismissed account is the active one, and never resets `accountDbFileNameProvider` / invalidates `userDatabaseProvider` / clears auth+selected-profile / calls `clearActiveAccount()` — unlike `showDeleteLocalAccountFlow` (`account_actions.dart:504-525`), which does all of these.
- **Fix:** In `_onDismissed`, detect if the dismissed account is active (compare `dbFileName` to `accountDbFileNameProvider`, or `accountId` to the resolved active id). If active: reset `accountDbFileNameProvider`→`'learning_tracker'` + `ref.invalidate(userDatabaseProvider)` (close the handle), clear `authStateProvider`/`selectedProfileIdProvider`, `SessionPersistenceService.clearActiveAccount()`, then delete file+registry row, then `replaceAll` to SignIn/AccountPicker. Mirror `showDeleteLocalAccountFlow`.
- **Test:** widget/integration test — dismiss the active account row → `userDatabaseProvider` invalidated, session cleared, routed away (no write to the deleted handle).

---

## Priority 3 — on-device findings (need a product call or a contained refactor)

### D6 · profile-less account is offered "Add a learning track" but the save always fails
- **Where:** Dashboard empty-state CTA → `AddTrackFlow` → "Failed to save track" toast, on an account with **zero `learner_profiles`** (the active profileId resolves to sentinel `0`, which has no profile row → FK fails on the track/stage insert). Reachable for tutor-only adults and churn-anomaly accounts (e.g. the current dniasoff account). Same class as D4.
- **Fix (needs product decision):** On a profile-less account, route the empty-state CTA to **profile creation** first (or block/guide `AddTrackFlow` until a profile exists) instead of letting track creation fail.

### D7 · track creation is non-atomic — orphaned rows on a mid-creation failure
- **Where:** `learning_tracker/lib/features/tracks/setup/domain/services/track_creation_service.dart` (`_runCoreTransaction`).
- **Symptom:** When stage-seeding throws mid-creation (observed on the profile-less account: the stage insert FK-failed on `profile_id = 0`), the `curriculum_tracks` + `profile_programs` rows **persist** (orphaned, 0 stages) even though the op reports "Failed to save track". Separately, **deleting a track does not remove its `profile_programs` row** (dangling enrollment).
- **Fix:** Wrap the whole creation (track insert + program enrolment + stage seeding) in a single `db.transaction()` so a stage-seed failure rolls back the track + program rows; and have track deletion also delete the matching `profile_programs` row.
- **Test:** force the stage-seed step to throw → assert no `curriculum_tracks`/`profile_programs` rows persist (rollback); delete a program track → assert its `profile_programs` row is gone.

---

## Quick index
| # | Sev | File | One-liner |
|---|---|---|---|
| D14 | data-loss | points_balance_dao.dart:497 | ledger enqueue outside txn / skipped when syncSink null |
| D15 | data-loss | drift_merge_store.dart:132 | remoteIsNewer clobbers newer un-pushed local in 5 s window |
| D13 | correctness | sync_orchestrator.dart:940 | false 'Synced' while profile-0 outbox stuck (fix pinned) |
| D16 | correctness | streak_reducer.dart:75 | streak buckets by UTC, not local day |
| D17 | low | streak_state_provider.dart:69 | live streak stale across midnight |
| D18 | correctness | manage_tutors_providers.dart:104 | revoked talmid resurrects active |
| D19 | correctness | account_management_service.dart:61 | cloud-delete leaves ghost registry row |
| D20 | data-loss | account_picker_screen.dart:539 | swipe-away active account deletes open DB |
| D6 | ux/edge | (dashboard CTA / AddTrackFlow) | profile-less account: Add-Track always fails (product call) |
| D7 | data-integrity | track_creation_service.dart | non-atomic creation orphans track+program rows |
