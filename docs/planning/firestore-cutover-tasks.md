# Firestore cutover — task list

Durable companion to [`firestore-cutover-plan.md`](firestore-cutover-plan.md).
Session task lists do not survive; this file does. **Update it in the same
commit as the work it describes.**

**Last updated:** 2026-08-06 · head `a2a21d0a`

Status values: `todo` · `doing` · `done` · `blocked` · `decided` (owner has
ruled; implementation still outstanding).

---

## Open

| ID | Phase | Status | Task |
|----|-------|--------|------|
| T-30 | 2 | todo | **Owner-path Cloud Functions still key `learner_profiles` by the Drift int.** `functions/src/deletes.ts`: `deleteLearnerProfile` (:135), `deleteCurriculumTrack` (:214), `deleteBulkMarkedCompletions` (:406) each validate `profileId` as a positive integer (:136, :215, :407) and address `.collection("learner_profiles").doc(String(profileId))` (:225, :441). Post-cutover they address a path holding no data — **delete nothing, report success**. `deleteBulkMarkedCompletions` implements the owner's un-tick-a-bulk-mark rule, so that feature silently stops working. |
| T-31 | 2 | decided | **Tutoring identity is Drift-int end-to-end.** Owner decision D1 (2026-08-04): re-file under the ULID; tutor reads the parent's tree directly; the local mirror dies. Scope: grant creation (`profile.id.toString()` — `manage_tutors_screen.dart:293,298,312`, `invite_tutor_screen.dart:112`), the `tutor_active_access` doc-id (`tutor_invites.ts:203-205,402-403,458-459`), 17 CF int-validations (13 `tutor_writes.ts`, 3 `deletes.ts`, 1 `tutor_bulk_completions.ts`), `TutoredWriteRouter`'s `int.tryParse` (:410), and `ProfileDao.upsertTutoredProfile` minting no ULID. **The rules formula does not change** — `hasActiveTutorAccess` (`firestore.rules:87-91`) and `acceptInvite` already build the identical `{tutorUid}_{ownerUid}_{profileId}` string; only what `profileId` *is* changes. |
| T-34 | 2 | todo | **Bookmark doc-id divergence.** `DocIds.bookmarkDocId` is bare `{curriculum_id}`; `TutoredWriteRouter.pushBookmark` computes `{curriculum_id}_{track_type}` (`tutored_write_router.dart:236`). Two writers, different documents, on a two-writer collection. Must be reconciled with T-31, not after it. |
| T-35 | 2 | todo | **Hoist the tutored guard into `_watchActiveAccountAndProfile`** (`repository_providers.dart:126-134`) so all 13 profile-scoped providers refuse uniformly in one place, rather than replicating `TutoredBookmarkWriteUnsupportedException` 13 times. `grep` finds zero references to `activeTutoredProfileSelectionProvider` under `lib/data/`. |
| T-33 | 2 | decided | **`learning_order` reset is unimplementable client-side.** Owner decision D3 (2026-08-04): narrow allowance, `allow delete: if isOwner(uid)`, matching the `goals` precedent. Today `FirestoreLearningOrderRepository.resetToDefault` throws `UnimplementedError`; `LearningOrderScreen._resetToDefault`'s catch was widened from `on Exception` to a bare `catch` so it degrades to a snackbar instead of crashing. Rules and the code writing through them must land in the **same commit**. |
| T-20 | 3 | todo | **Wire the 7 dead adapters and move ~96 feature files.** Built-but-never-constructed: `FirestoreCompletionRepositoryAdapter`, `FirestoreCurriculumTrackRepositoryAdapter`, `FirestoreGoalRepositoryAdapter`, `FirestoreProgressRepositoryAdapter`, `FirestoreStageDefinitionRepositoryAdapter`, `FirestoreStudyDayConfigRepositoryAdapter`, `FirestoreTrackLearningOrderRepositoryAdapter`. Order by data dependency — **writers before readers** — and add a writer/reader agreement test per collection. |
| T-32 | 3 | decided | **Reorder amnesty is no longer stamped on any path.** Owner decision D2 (2026-08-04): restore both forgiveness paths. **The two are not equal cost.** Reorder stamp is cheap (`last_reorder_at` already permitted, `firestore.rules:412`); write it and move `daily_task_projection_service`'s read (`:443-446`) off Drift. **Content-reseed forgiveness needs a NEW mechanism** — the old detection used the Drift `learning_order.learningOrderVersion` column and the `learning_order` rules whitelist has no version field. Design explicitly; do not assume it comes free. |
| T-21 | 4 | todo | **Demolish the sync engine and Drift user database.** `lib/core/sync` (62 files, 12,819 lines), `lib/core/database/user` (2, 25,774), `daos` (49, 5,991), `tables` (26, 1,111), `views` (1, 34), plus 85 sync test files. ≈45,700 lines. |
| T-29 | 4 | todo | **ISO→Timestamp conversion dies with `core/sync`.** `firestore.rules` enforces `is timestamp` on `streak_events.created_at`, `completions`/`learning_ledger.completed_at`, `points_ledger.created_at`. `FirestoreGatewayImpl._timestampifyField` did that conversion and is deleted here. Verified 2026-08-03: the new repositories handle all three correctly (completions and points_ledger round-trip real `Timestamp`s; streak_events omits the key so the optional-field guard short-circuits). **Re-verify before deleting.** `fake_cloud_firestore` cannot catch a regression — it surfaces only as permission-denied on a real device. |
| T-36 | 4 | todo | **Remove Rule 5 allow-list entries as PAIRS.** `epic_25_story_25_9_lints_test.dart` exempts `firestore_learning_order_repository.dart` and `firestore_track_learning_order_repository.dart` alongside the Drift repositories they replace. Delete both halves together so the list shrinks rather than accumulating exemptions for files that no longer exist. |
| T-23 | 5 | todo | **Retarget enforcement gates.** Many encode the old sync engine's invariants and will be policing deleted code. |
| T-24 | 5 | todo | **Verify `resolve()` cold-start re-attach on a real device.** Mock-only today; runs every launch. Specifically: `ProfileGuard`'s single-profile auto-select calls `.select(id)` without `ulid:` (`router_provider.dart:55-56`), which deliberately clears `activeProfileDocIdProvider`. It self-heals via `ensureSelected()` on the next frame — **whether anything can fire inside that window is not statically determinable.** |
| T-25 | 5 | todo | **Add a gate rejecting non-text source files.** One NUL byte makes grep treat a file as binary, silently disabling all 103 audit checks on it. Has happened once. |

## Done

| ID | Phase | Commit | Task |
|----|-------|--------|------|
| T-01 | — | — | Baseline gate: `make audit` + `make ci` green on untouched `dev` |
| T-16 | — | — | A1 — named-app auth: each account owns its own authenticated `FirebaseApp` |
| T-19 | — | — | B2 — build repositories for the whole data model |
| T-26 | — | — | `track_learning_order` repository |
| T-27 | — | `58b2e396` | Onboarding switches to the child profile before add-track |
| T-28 | — | `5b4d7924` | Bookmarks vertical slice — end-to-end onto Firestore |
| T-P0 | 0 | `9a5cb97c` | Phase 0 — three blocking decisions resolved (D1/D2/D3) |
| T-P1 | 1 | `a2a21d0a` | Phase 1 — audit check 103, keying gate + agreement helper |

---

## Conventions

- **One row per unit of work**, with enough file:line evidence to act without
  re-deriving anything. A task nobody can execute cold is not recorded.
- **Update in the same commit as the work.** A stale task list is worse than
  none — this project has already lost a live feature to a stale doc comment.
- **`decided` ≠ `done`.** The owner has ruled; the code has not moved.
- Verify a file:line before trusting it. Citations here age like any other.
