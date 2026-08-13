> **ARCHIVED 2026-08-13 — superseded.** Superseded by `docs/planning/phase3-wave-plan.md` and `docs/planning/phase3-handoff-5.md`. Retained for history only; do not treat as current. See `docs/planning/firestore-finish-line-plan.md` for the live plan.

# Phase 2 Execution Plan — Identity Unification (FINAL)

**Synthesized 2026-08-06 · tree `d74e3829` on `dev` · all citations below re-verified live in this session unless marked *(inherited)*.**

---

## 1. Recovery-protocol result

**Verdict: the tree is clean and safe to start Phase 2, with two recorded anomalies, neither of which blocks work.**

- `git log --oneline -1` → `d74e3829`. The log's `CURRENT STATE` **Head** field says `a2a21d0a` — **stale by one commit**. `d74e3829` is the doc-only commit that created `firestore-cutover-log.md` itself (self-reference lag, no code touched). Literally false as written; fixed in P2-0.
- `git rev-list --left-right --count origin/dev...dev` → `0 0`. In sync.
- `git status --porcelain` → exactly 8 modified `_bmad/**` config files. Confirmed regenerator noise (`# Date:` bump + key reordering), an established pre-existing pattern with its own commit history. **Do not commit, revert, or `git add -A` over these.** Every `git add` in this phase must be explicit paths.
- `git stash list` → **non-empty. RED FLAG per protocol, left untouched.** `stash@{0}`, base `8855b9b1`, dated **2026-07-19** (18 days old, predates the cutover's first commit `5b4d7924` by two weeks), label `(no branch)`, base commit **not an ancestor of `dev`** and contained by no branch. Content is two generated `*.g.dart` Riverpod files whose subject does not match the stash's own label. **Not popped, not applied, not dropped.**
- `pgrep -af "flutter[ ]test"` → none. No orphaned test processes.
- Both cheap gates green: `dart analyze --fatal-infos` → `No issues found!`; `check_profile_path_keying.dart` → `PROFILE-KEY-SPLIT check OK: 2 collection(s) currently split (bookmarks, learning_order), all within the tracked baseline (0 new violations).`
- **New finding, contradicts the draft plan's risk register:** `learning_tracker/coverage/lcov.info` **exists** (469,235 bytes, Aug 6 17:18). R6d does **not** soft-skip on this machine — it runs. Any assumption that the coverage-denominator check is dormant this phase is false.
- Unresolved inventory mismatch carried forward: the keying gate's 10-collection WATCHLIST does not map 1:1 onto `CURRENT STATE`'s "Dead adapters (7)". Phase 3's problem, recorded in P2-8, not Phase 2's.

---

## 2. Phase 2 objective

Make the learner-profile ULID the **only** identity a profile has at its source — minted eagerly and locally at creation, never null, never clearable, carried on a compile-enforced non-nullable field — and build the gate that makes every remaining int-keyed profile-identity site a tracked, ratcheted entry. Close the three identity-adjacent defects that are **not** coupled to the still-int collection trees: the dead divergent bookmark writer (T-34), the per-provider tutored guard (T-35), and the `learning_order` client reset (T-33). It deliberately does **not** re-key the tutoring wire or the owner-path delete Cloud Functions — verification below shows those address the same document trees Phase 3 moves, so they are in Phase 3's migration unit, not Phase 2's.

---

## 3. Owner rulings (RESOLVED 2026-08-06)

Both questions below were blocking as of the session that synthesized this plan. The owner has since ruled on both. This section is kept in ruling form, evidence intact, rather than rewritten as if the answer had never been in question — an interrupt diffing this file against the tree needs to see what was decided and why, not just the outcome.

### Q1 — RESOLVED: T-30 and T-31 re-phased to Phase 3

**Ruling: T-30 and T-31 move out of Phase 2 into Phase 3, landing with T-20 as one commit-unit.** This overrode a written owner assignment (`firestore-cutover-plan.md:135` assigns D1 to Phase 2; `:248-256` scopes T-30/T-31 into Phase 2), and the owner has now ruled on it directly rather than leaving it an assumption. One decoupled line item survives in Phase 2: `ProfileDao.upsertTutoredProfile` recording the remote id it was handed, which changes no wire value and no path segment — it lands in P2-2.

**The evidence that drove the ruling, verified this session:**

`TutoredProfileSelection.profileId` is not merely a Cloud-Function argument. It is a **live Firestore path segment** on both sides:

- **Reads.** `PullPipeline.pullForTutoredProfile` (`lib/core/sync/pull_pipeline.dart:295`, documented path at `:286`: `users/{parentUid}/learner_profiles/{remoteProfileId}/<coll>`) pulls **13 collections** — `pull_pipeline.dart:73-87`: completions, bookmarks, curriculum_tracks, settings, goals, learning_ledger, stage_definitions, streak_events, study_day_configs, profile_programs, learning_order, points_ledger, reward_redemptions — plus **3 preference docs** (`:91-98`). Driven from `tutored_pull_service.dart:116`, mirrored by `TutoredListenerSource`.
- **Writes.** `verifyTutorGrant` builds one `profilePath` from `profileId` (`functions/src/tutor_writes.ts:187`) and **9 collections** are written through it: completions (`:285`), goals (`:346,:399`), curriculum_tracks (`:455,:506`), stage_definitions (`:562`), study_day_configs (`:621,:672`), preferences/gamification_settings (`:744`), bookmarks (`:804`), profile_programs (`:864`), curriculum_scopes (`:927`).

For **11 of those 13**, the owner-side writer is still the int-keyed sync engine (they are the dead adapters / WATCHLIST collections). Re-keying tutoring to the ULID in Phase 2 therefore makes the tutor read a tree nothing writes and write a tree nobody reads — **the exact 2026-08-03 failure, at 9–11× the scale, deliberately.** And it is silent: `pullForTutoredProfile` counts no failures on an empty collection, so `TutoredPullService` returns success into an empty talmid.

Worse, **no gate this phase can run would see it.** Check 103's output is byte-identical across the whole change (INT-B is file-location-based: `functions/src/**` still names every collection). Check 104 as designed sees only int-shaped tokens, and after the cut there are none. `dart analyze` sees no TypeScript. The rules matrix cannot distinguish an int-string from a ULID at a `{profileId}` wildcard.

The same coupling applies to T-30: `deleteLearnerProfile` recursively deletes `learner_profiles/{profileId}` and everything under it. While both trees exist, re-keying it to the ULID means a profile delete leaves the bulk of the profile's data (the 11 int-keyed collections) behind.

**Ruling rationale (recorded, not a recommendation):** this is the log's own doctrine applied consistently: *"the migration unit is the int→ULID cut, not the feature"* — and tutoring's identity addresses precisely the collection trees T-20 moves. It costs Phase 2 nothing it can prove, and it removes the only window in the whole cutover where tutoring would be knowingly broken. The variant that would have kept T-30/T-31 in Phase 2 (deleting `TutoredPullService`, `PullPipeline.pullForTutoredProfile`, `tutoredCollections`/`tutoredPreferenceDocs`, `TutoredListenerSource`/`Supervisor`, and the tutored mirror row's writer, leaving tutoring non-functional until Phase 3's T-37) is not being taken and is not carried forward.

### Q2 — RESOLVED: audit check 104 (PROFILE-ID-INT-SITES) approved

**Ruling: check 104 is approved, and is built this phase, at P2-1.** It is new work — not a task-list item pulled from `firestore-cutover-tasks.md` — justified on its own: Phase 3 is the ~96-file move, and it needs a keying gate that can see what check 103 structurally cannot (`learner_profiles` itself, `tutor_active_access`, and int-typed profile identity in Dart). Phase 1's precedent is that a boundary gets a gate *before* it is crossed; building it now, on a quiet tree, is the cheapest it will ever be. Full design (named-entry ratchet, published scan set, baseline sentinel) is in §4 P2-1; how its first run is proven rather than merely asserted is in §6.

### Not blocking — stated assumptions instead

- **A1 — The executing agent commits.** The log's brief convention (`:149-160`) says agents must never commit *"unless the brief says otherwise."* This plan says otherwise, at the named boundaries only. The never-stash / never-branch / never-worktree rules remain absolute. P2-0 writes this override into the log so a cold agent does not read the two documents as contradictory.
- **A2 — `stash@{0}` stays untouched and is recorded as UNDISPOSITIONED-REPORTED**, with its measured facts, so future recovery runs stop re-raising it as new. It is *not* recorded as "dispositioned benign" — that would settle a question nobody has ruled on.
- **A3 — `dart run build_runner build --delete-conflicting-outputs` is an allowed command** under binding constraint 2. It is codegen, not a test run. There is no Makefile target for it (verified: `grep -n build_runner Makefile` → none), so the literal command goes in the plan.
- **A4 — `firebase deploy --only firestore:rules` against the dev project is allowed and required** before P2-7's device check. Rules changes are inert until deployed, and an undeployed rules change presents on device as `permission-denied` — indistinguishable from a keying failure.

---

## 4. Ordered execution plan, T-30 → T-35

Ordering is dependency-driven. Every step names its proving gate and its predicted output, **with the reason green is green.**

### Standing correction that governs every prediction below

`check_profile_path_keying.dart` classifies INT writers by **file location** — INT-A = any `.dart` under `lib/core/sync/**`, INT-B = any `.ts` under `functions/src/**` *(inherited: `:54-66`)* — and `currentSplits = (intA||intB) && ulidLive` *(inherited: `:1127-1132`)*. It also anchors on `match /learner_profiles/{profileId} {` (`firestore.rules:211`) and walks only that anchor's **children**, so the `learner_profiles` collection itself and the top-level `tutor_active_access` (`firestore.rules:111`) are outside it entirely; and it has no concept of a document-ID formula.

**Consequence: check 103's `OK` line and its `currentSplits` set are expected to be invariant across all of Phase 2.** Its WATCHLIST *paragraphs* may legitimately change if an INT-A touch is deleted or a repo is renamed — pin the invariant to the OK line and the split set, not to the whole stdout. (This corrects the draft's over-broad "byte-identical" claim.)

**Phase 2's stated exit criterion in the plan doc — *"Phase 1's check shows the identity split closed. `make ci` green."* (`firestore-cutover-plan.md:264-265`) — is unachievable on two independent counts** and is replaced in §8.

---

### P2-0 — Make the plan and the protocol survive an interrupt *(no code)*

**Why first.** The draft plan existed only in one agent's context. The recovery protocol's own remedy for a mid-commit interrupt is *"compare the tree against the edit list"* — an edit list that was never on disk. An interrupt during any code step would have left a cold agent re-deriving the entire cut against a half-migrated tree.

**Edits — `docs/planning/`:**
1. Commit **this plan** as `docs/planning/firestore-phase2-plan.md`. It is the artifact the interrupt rule diffs against.
2. `firestore-cutover-log.md` `CURRENT STATE`: `Head:` → `d74e3829`; add a `Deployed:` line (`rules + functions built from <SHA>`, initially `unknown — not deployed this phase yet`).
3. `firestore-cutover-log.md`: add an **IN FLIGHT protocol** — before starting any commit P2-*n*, append an entry naming the commit id and its remaining edit-list items; the same commit that lands the code clears it. The log's model (`:41-43`) requires an IN FLIGHT record to exist *before* work starts; today it is only ever written after.
4. `firestore-cutover-log.md` brief convention (`:149-160`): record the A1 override — implementing agent commits at named boundaries and rewrites `CURRENT STATE` in the same commit; never stash, never branch, never worktree.
5. Record `stash@{0}` as **UNDISPOSITIONED-REPORTED** with its measured facts.

**Gate:** none applicable (docs only). Run `git status --porcelain | grep -v '^ M _bmad'` before committing.
**Commit boundary:** P2-0.

---

### P2-1 — Audit check 104: `PROFILE-ID-INT-SITES` *(new work; not a task-list item)*

**Why it exists.** Phase 3 is the ~96-file move, and it needs a keying gate that can see what check 103 structurally cannot: `learner_profiles` itself, `tutor_active_access`, and int-typed profile identity in Dart. Phase 1's precedent is that a boundary gets a gate *before* it is crossed. Building it now, on a quiet tree, is the cheapest it will ever be. In Phase 2 it also ratchets Phase 2's own edits.

**Edits:**
- New `learning_tracker/tool/check_profile_id_int_sites.dart`. **`tool/` is safe ground** — verified: `check_test_mirroring.dart` (`_findUnmirrored`, `Directory('lib')`) and `check_lcov_denominator.dart` (`_allLibFiles`, `Directory('$root/lib')`) both scan `lib/` only, so a new tool file trips neither the AG-5 mirroring ratchet nor R6d.
- Scan set (each violation keyed by **`file:enclosing-symbol`**, never a line number — lines move):
  - `functions/src/**/*.ts` (excl. `*.test.ts`): `typeof profileId !== "number"` / `Number.isInteger(profileId)` guards. Current population **17**, verified: `tutor_writes.ts:276,334,390,443,497,550,609,663,726,792,852,912,979`; `deletes.ts:135,214,406`; `tutor_bulk_completions.ts:74`.
  - `functions/src/**/*.ts`: `.doc(String(profileId))` against `learner_profiles` — `deletes.ts:143,225,441`, `tutor_writes.ts:187-191`, `tutor_bulk_completions.ts:~197`.
  - Dart: `required int profileId` in `lib/features/tutoring/data/services/tutor_write_service.dart` (13); `int.tryParse` **anywhere under `lib/features/tutoring/**`** — this deliberately widens the draft's pattern so it catches **`invite_tutor_screen.dart:112`** (`int.tryParse(widget.childProfileId)` compared against `p.id`), a real P2/P3 edit site the narrower pattern missed; `.id.toString()` anywhere under `lib/features/tutoring/**` — which catches **all six** `manage_tutors_screen.dart` sites (`163,173,206,293,298,312`), not the three the draft listed; `int profileId` in `lib/core/sync/firestore_gateway.dart` and `outbox/push_pipeline.dart` (interface-level only, not all 179 occurrences under `lib/core/sync/**` — those die wholesale in Phase 4 and tracking them individually is noise).
- New `learning_tracker/tool/profile_id_int_sites_baseline.txt`, written by `--update-baseline`.

**Gate design — three corrections to the draft, all load-bearing:**
1. **Named-entry ratchet, not "must reach empty."** A new entry fails (exit 1). An entry present in the baseline but absent from the scan also fails (exit 1) — so a fix must remove its baseline line in the same commit, locking the win. This is fail-closed in both directions *per entry*, without the draft's impossible "0 tracked sites" end-state (there are 179 `int profileId` occurrences under `lib/core/sync/**` alone; the identity is not "unified" merely because 104 is empty).
2. **The OK line prints the scan set**, e.g. `PROFILE-ID-INT-SITES OK: 31 tracked site(s) across 5 patterns [cf-int-guard, cf-string-profileid-doc, dart-int-profileid-param, dart-tutoring-int-parse, dart-tutoring-id-tostring]; 0 new, 0 stale.` A gate whose reported number depends on its scan set must publish that set, or "0" is a claim about the scanner, not about the code.
3. **The baseline carries a required header sentinel** (`# format: profile-id-int-sites v1` + a hash of the pattern list). A missing or sentinel-less baseline **exits 1**. Every sibling ratchet in this repo returns the empty set for a missing baseline; for a gate whose success state is a small file, "absent" must not be indistinguishable from "clean."
4. **The commit that changes a scan pattern may not also change code those patterns cover.** State it in the tool's doc comment. An exact-set gate whose scanner and fix land together can be satisfied by narrowing the scanner.

- `learning_tracker/Makefile`: append a `104/104 — PROFILE-ID-INT-SITES` block immediately after the `103/103` block (`Makefile:1353-1361`), copying its shape. Denominators are per-group in this file, so **no renumbering is needed**. Do **not** touch the summary string `all 68 greps clean` (`Makefile:1366`) — it is already stale and `test-serial-tools` greps audit stdout; retargeting it is T-23/Phase 5.
- `learning_tracker/Makefile`: add target `check-profile-id-int-sites` (mirroring `check-profile-path-keying`, `Makefile:91-92`) and add it to `ci:` (`Makefile:293`).
- **`docs/planning/firestore-cutover-log.md` Step 4 (`:32-37`) in this same commit:** add `dart run tool/check_profile_id_int_sites.dart`. The recovery protocol's "confirm the gates before trusting anything" currently confirms two gates that are both blind to this phase. A gate nobody runs on cold start is not a gate.

**Proving gate & predicted output:**

| Gate | Predicted | Why |
|---|---|---|
| `dart analyze --fatal-infos` | `No issues found!` | tool file is standalone Dart |
| check 103 | OK line and split set **unchanged** | no bucket input moved |
| check 104 | **GREEN**, `31 tracked site(s) … 0 new, 0 stale` | every existing violation is baselined at introduction |
| `make audit` | `=== audit PASSED ===`, now 104 checks | — |

**Colour prediction, stated with its assumption (this is where Phase 1's prediction failed):** the gate ships **GREEN, at a non-empty baseline of ≈31 entries** — green because everything is baselined, *not* because no int sites exist. Identical in shape to check 103 shipping green in Phase 1. **≈31 is a prediction; the first run's printed number is the fact, and that number goes verbatim into the log.**

**Commit boundary:** P2-1. Zero behaviour change.

---

### P2-2 — Eager, unconditional ULID mint + close the two seam-clearing call sites

**Why.** The identity cannot be "unified" while it is optional. Verified today:
- Minting is **lazy, on-edit only** — `profile_repository_impl.dart:530-533` is the only backfill (`if (updated.ulid == null) return await _mintAndActivateFirestoreProfile(updated)`), and the mint swallows all failures (`:612-623`), so even a fresh profile can end with `ulid == null`.
- **Two live call sites clear the ULID seam to null**: `select(int id, {String? ulid})` (`profile_providers.dart:80-83`) sets `activeProfileDocIdProvider` to whatever `ulid` is, and `notifications_bootstrap.dart:30` and `router_provider.dart:56` both call it bare. Every other of the nine `select(` call sites already passes `ulid:` (verified: `device_restore_screen.dart:125`, `onboarding_screen.dart:183,286,331`, `onboarding_profile_creation_step.dart:141`, `sign_in_controller.dart:693,710`, `profile_picker_screen.dart:208`, `add_profile_dialog.dart:270`, `profile_providers.dart:197`). So a notification tap or a router-guard redirect blanks every profile-scoped Firestore provider — including the two features that are actually live.

Under greenfield this is a replacement, not a backfill: mint locally at creation, delete the lazy path.

**Edits:**
- `lib/features/profiles/data/repositories/profile_repository_impl.dart` — mint via `DocIds.mintProfileUlid()` **before** the Drift insert. This requires the interface change the draft omitted: `ProfileRepository.createProfile` (`lib/features/profiles/domain/repositories/profile_repository.dart:14`) and `ensureDefaultProfile` (`:54`) must accept the pre-minted ULID, because the inserts live in the inner `ProfileRepositoryImpl` (`:61`, `:317`) while the mint lives in the adapter (`:547`, `:563`, `_mintAndActivateFirestoreProfile` at `:596-624`). **List this interface change explicitly; do not discover it mid-commit.** Minting is a pure local generator (`lib/core/time/ulid.dart:8-28`) — no network, offline-safe, and `createTutorInvite` deliberately does not require the Firestore doc to exist (`functions/src/tutor_invites.ts:59-60`).
- `lib/data/repositories/firestore_learner_profile_repository.dart:186-204` — `createProfile` takes a **required** `profileId`; delete its internal mint at `:193` so exactly one site mints.
- Delete the lazy backfill branch (`profile_repository_impl.dart:530-533`) and `ProfileDao.setUlid` (`profile_dao.dart:99-102`) with its caller.
- **Replace what the backfill was silently doing.** It was also the only path that ever created a *missing* remote `learner_profiles/{ULID}` document. Deleting it without replacement creates a new failure mode for new profiles (a ULID addressing a document that never exists), which greenfield does not excuse. Add an **idempotent create-if-missing on profile activation** in `FirestoreProfileRepositoryAdapter` — a single unconditional `set(..., SetOptions(merge: true))` on the ULID doc, not a version gate, not a conditional bridge. Do **not** make the remote create fatal: profiles are offline-first by explicit contract (`tutor_invites.ts:59-60`), and a fatal remote write would break offline profile creation.
- `ProfileDao.upsertTutoredProfile` (`profile_dao.dart:226-266`) — set `ulid: Value(remoteChildProfileId)` on the insert. The mirror **records** the remote id it was handed; it never mints a fresh one (a fresh mint would create a second identity for the same child). This is a T-31 line item that is genuinely decoupled: it changes no wire value and no path segment. It is also a hard prerequisite for P2-3.
- `notifications_bootstrap.dart:30` and `router_provider.dart:56` — resolve the profile and pass `ulid:`.
- Doc comments that become load-bearing lies: `lib/core/database/tables/learner_profiles.dart:48-73` ("NULL means not yet migrated"), `profile_repository_impl.dart:457-475` ("selection only ever READS ulid back — it never triggers a mint"), `profile_providers.dart:70-83` (the whole "a caller with only a bare int omits ulid" paragraph).
- **Keep the Drift column nullable.** A v38→v39 schema bump buys nothing for a column deleted wholesale in Phase 4 (`learner_profiles.dart:67-72`). Enforce at the mapping boundary in P2-3.

**Proving gate & predicted output:** `dart analyze` **green** — and here it genuinely proves a lot: the `createProfile`/`ensureDefaultProfile` signature changes are analyzer-visible at every caller, including under `test/` (`analysis_options.yaml` excludes only generated files). Check 103 unchanged (`learner_profiles` is not in its registry at all). Check 104 green, count unchanged. `make audit` green.

**Commit boundary:** P2-2.

---

### P2-3 — `ProfileModel.ulid` becomes `required String` *(mechanical, compile-enforced)*

**Why separate, and why at all.** This is the single strongest forcing function available in a phase where no test runs: the compiler, not a gate, guarantees that every construction of a profile carries an identity. `ProfileModel` is freezed with `String? ulid` (`lib/features/profiles/domain/models/profile_model.dart:14-27`), and its sole Drift mapping boundary is `ProfileModel.fromDriftRow` (`:51`).

**Measured blast radius (verified):** 4 construction sites in `lib/` (`profile_repository_impl.dart:96`, `:381`, the factory `:14`, `fromDriftRow` `:51`) and **43 test files / 67 occurrences** under `test/`. Edits are purely additive (`ulid: 'ulid-<n>',`). `dart analyze` covers `test/`, so **every** miss fails the cheap gate — this is one of the few steps where the cheap gate proves completeness.

**Edits:**
- `profile_model.dart:26-27` — `String? ulid` → `required String ulid`; delete the "NULL means not yet migrated" comment.
- `profile_model.dart:51` (`fromDriftRow`) — the Drift column stays nullable, so this is the enforcement point: on `row.ulid == null`, throw a named `StateError` naming the profile id and the remedy (*"pre-P2-2 profile row with no ULID — wipe and reseed the device"*). Per the greenfield ruling, breaking seeded on-device data is acceptable and reseeding is the remedy; a crash with an instruction is honest, a silent fallback is not.
- `profile_providers.dart:80` — `void select(int id, {required String ulid})`. Makes a third bare call site impossible to write.
- All 43 test files: add `ulid:`.
- **Codegen:** `dart run build_runner build --delete-conflicting-outputs` (freezed). `profile_model.freezed.dart` and `profile_providers.g.dart` regenerate. Generated files are exempt from AG-5, R6d and check 102 by their own scanners' filters, so the regenerated output introduces no gate work — but it **must** be in this commit or `dart analyze` fails in a way that reads like a bad import.

**Proving gate & predicted output:** `dart analyze --fatal-infos` → `No issues found!` — **green only if all 47 sites and the codegen are done**, which is exactly the property wanted. Check 103 unchanged. Check 104 green. `make audit` green.

**Natural drop point:** if this is judged too expensive to do blind, P2-2 alone still fixes the live defect; P2-3 only makes it un-reintroducible. Dropping it must then be recorded as a deviation, not omitted silently.

**Commit boundary:** P2-3.

---

### P2-4 — T-34: delete the divergent bookmark writer *(not "reconcile the formula")*

**What the draft got wrong, and the reviewers got right.** `TutoredWriteRouter.pushBookmark` (`tutored_write_router.dart:227-236`) is reachable **only** from `bookmark_repository_impl.dart:324` (`_syncEngine?.pushBookmark`), inside `BookmarkRepositoryImpl` — and `BookmarkRepositoryImpl` is **constructed nowhere in `lib/`**. Verified: `grep -rn "BookmarkRepositoryImpl(" lib/` returns only its own constructor declaration (`:45`) and a *comment* in `bulk_prior_completion_service.dart:121`; the only real constructions are three test files. The live provider builds `FirestoreBookmarkRepositoryAdapter` (`bookmark_providers.dart:22-29`), which refuses every tutored bookmark write outright.

Two consequences:
1. The draft's plan to have the router call `DocIds.bookmarkDocId` was a **hard-gate violation**, not a conditional risk. `check_dependency_direction.dart` (audit check 102, `Makefile:1345`, *"hard gate, any match fails the check, always"*) scans `lib/features/**` and `lib/domain/**` and exempts only paths containing `/data/repositories/`. `lib/features/tutoring/data/**routers**/` is not exempt, and `DocIds` lives at `lib/data/firestore/doc_ids.dart` — the banned prefix exactly.
2. The draft's only stated proof for it (R8: "the device round-trip in P2-4 step 3, tutor sets a bookmark") was **unexecutable** — no code path lets a tutor set a bookmark.

Under binding constraint 1 ("delete rather than adapt", "prefer the smallest total surface"), the correct fix is deletion, and it dissolves the check-102 problem entirely.

**Edits:**
- Delete `TutoredWriteRouter.pushBookmark` (`tutored_write_router.dart:227-245`) and its routing-table comment line (`:23`).
- Delete `bookmark_repository_impl.dart:324`'s `_syncEngine?.pushBookmark(...)` call and, if that leaves the `syncEngine` constructor parameter unused, the parameter with it.
- Delete the stale justifying comment (`tutored_write_router.dart:233-235`, *"Mirror firestore_gateway_impl doc-id: {curriculum_id}_{track_type}"*) rather than acting on it — `firestore_gateway_impl.dart:399-404` writes a **bare** `curriculum_id` for bookmarks and `BookmarkEntity` has no `track_type` field, so the router in fact emitted `'{curriculumId}_'` with a trailing underscore. *This is the doc-comment-staleness hazard (`firestore-cutover-log.md:82-83`) firing on the exact task that cites it.*
- Same-commit test edits: the three files constructing `BookmarkRepositoryImpl` (`bookmark_repository_impl_test.dart:77`, `completion_repository_impl_test.dart:124`, `bulk_mark_screen_staleness_test.dart:198`) and `s1_tutored_write_router_test.dart`'s `pushBookmark` routing tests (`:676-723`), which die with the method.
- **Not deleted in Phase 2:** the `tutorUpsertBookmark` Cloud Function. It is deployed and externally callable; its fate rides with T-31 in Phase 3.

**Proving gate & predicted output:** `dart analyze` **green** — and it genuinely proves this one, because deleting a method breaks every caller at compile time. Check 103 unchanged (no doc-id concept; `data/routers/` is outside its ULID-C scan). Check 104 green. **`make audit` green — and specifically check 102 stays green, which it would not have under the draft's approach.**

**Commit boundary:** P2-4.

---

### P2-5 — T-35: hoist the tutored guard *(direct import; no provider relocation)*

**The draft's P2-5 provider move is deleted from this plan.** Its stated justification — that the data ring cannot import a feature presentation provider and that check 102 would fail closed — is **false, verified**: `check_dependency_direction.dart`'s `_scanFiles()` iterates only `['lib/features', 'lib/domain']`; it never inspects `lib/data/**`. And `lib/data/**` already imports `lib/features/**` in **23** places today, all green (e.g. `repository_providers.dart:96`). The two files the draft cited as "the sibling seams already there" (`lib/core/providers/active_profile_doc_id_provider.dart`, `active_account_id_provider.dart`) are themselves **re-export shims** — their own doc comments say so — i.e. the very pattern the draft forbade, and near-certainly the shims the log blames for turning `make ci` red in the B2 wave. The move would also have been a `@Riverpod` codegen relocation (`active_tutored_profile_provider.dart:20` `part`, `:26-28` `@Riverpod(keepAlive: true)`) whose `exit()` reads two providers out of `lib/core/sync/providers/` — dragging a dependency on the engine Phase 4 deletes. It is unnecessary surface between the phase's riskiest commits.

**Edits:**
- `lib/data/firestore/repository_providers.dart:126-134` — `_watchActiveAccountAndProfile` imports `active_tutored_profile_provider.dart` directly and returns `null` when a tutored selection is active, before resolving handles. All **13** profile-scoped providers (call sites `:196,217,230,243,256,269,282,295,308,321,342,355,368`) then refuse uniformly.
- Delete the per-provider duplication in `bookmark_repository_impl.dart` — the read-side guard (`:571-581`) and `_assertNotTutoredSession` (`:550-557`). Keep `TutoredBookmarkWriteUnsupportedException` (`:447-458`) only if a write path still needs to distinguish "refused" from "not ready"; its message text (`:440-442`) cites the CF's int contract and should be rewritten to cite the hoist instead.

**What this actually fixes.** Today, in a tutored session, the 12 unguarded providers resolve `uid` from `activeAccountFirebaseProvider` (the **tutor's**) paired with `activeProfileDocIdProvider` (the **tutor's own** profile ULID). Only bookmarks guards. `learning_order` is live and unguarded — a tutored session reads and writes the tutor's own learning order. This is a live latent corruption, not a style problem.

**What it deliberately does not do, and the regression it creates.** D1 says "tutor reads the parent's tree directly." That needs `uid = ownerUid`, but the helper sources `uid` from the signed-in account (`:129-130`); setting the profile ULID without substituting the owner's uid would address `users/{TUTOR}/learner_profiles/{talmid ULID}` — a brand-new wrong tree. The rules already permit the correct read (`firestore.rules:450` and 16 sibling `allow read: if isOwner(uid) || hasActiveTutorAccess(uid, profileId)` lines), so it is buildable — but it is a new owner-scoped handles seam, i.e. feature wiring. **State the consequence plainly in the commit message and the log: after this commit the talmid's scheduler renders nothing rather than the tutor's own order.** That is a deliberate regression, repaired by Phase 3's T-37. It is not "the hoist working" merely because the screen is empty.

**Proving gate & predicted output:** `dart analyze` green. Check 103 unchanged. Check 104 green. `make audit` **green — including check 102, which does not scan `lib/data/**` and therefore cannot object to this import.** (The draft predicted this as "the most likely place for audit to go red"; that prediction was wrong for a verifiable reason and is corrected here.)

**Commit boundary:** P2-5.

---

### P2-6 — T-33: `learning_order` owner delete *(rules + code, same commit)*

**Verified current state:** `firestore.rules:456` — `allow delete: if false;` inside the `learning_order` block (`:449-457`). Precedent at `firestore.rules:525` — `allow delete: if isOwner(uid);` for `goals`, with a rationale block immediately above (`:520-524`) noting that create/update are already owner-writable so forbidding removal protected nothing. That rationale applies verbatim: `learning_order` has `allow create, update: if isOwner(uid)` at `:451`.

**Edits:**
- `firestore.rules:456` → `allow delete: if isOwner(uid);`, with a comment pointing at the `goals` precedent.
- `lib/data/repositories/firestore_learning_order_repository.dart:442-444` — replace `UnimplementedError` with the real delete.
- `lib/features/tracks/whole_curriculum_order/presentation/screens/learning_order_screen.dart:193-207` — narrow the bare `catch (e, st)` back to `on Exception`. The widening exists only to survive an `UnimplementedError` (an `Error`, not an `Exception`); with the method implemented it is old-path dead weight and goes in the same commit.

**Ordering:** last, and fully independent of everything above, so an interrupt leaves the hard-to-re-derive work already landed.

**Proving gate & predicted output:** `dart analyze` green. Check 103 unchanged (`learning_order` is already a baselined split; adding a delete to an already-live ULID repo moves no bucket). Check 104 green. `make audit` green. **The rules change has no gate at all in Phase 2** — `make test-rules` is `ci:`-only (`Makefile:293`), and `fake_cloud_firestore`'s strict mode cannot evaluate custom `function` declarations, so `isOwner(uid)` would deny everyone including the owner *(inherited)*. Deploy + device is the only proof.

**Commit boundary:** P2-6.

---

### T-30, T-31 — deferred to Phase 3 per Q1's ruling

Not executed in Phase 2. Recorded in `firestore-cutover-tasks.md` as re-phased with the coupling evidence (§3 Q1). One decoupled line item from T-31 — `upsertTutoredProfile` recording the remote id it was handed — is executed in P2-2.

### T-32 — Phase 3, not Phase 2

Confirmed by the tasks doc's own Phase column. Its subject (reorder amnesty / D2) is unrelated to identity. Out of scope; not folded in.

---

## 5. Commit sequence

Every boundary leaves: `dart analyze --fatal-infos` green, check 103's OK line and split set unchanged, check 104 green, `make audit` exit 0, and `CURRENT STATE` truthfully rewritten **in the same commit** — that is what converts "we happened to commit in time" into structure.

Before each commit: `dart format` (verified: `make ci` has **no** format dependency at `Makefile:293`, despite `learning_tracker/CLAUDE.md:28` claiming it does; format is a GitHub-Actions-only job) and `git status --porcelain | grep -v '^ M _bmad'` to build the add list by hand. **Never `git add -A`.**

| # | Message | Touches |
|---|---|---|
| **P2-0** | `docs(planning): commit the Phase 2 plan, fix log Head to d74e3829, add IN FLIGHT + commit-override conventions` | `firestore-phase2-plan.md` (new), `firestore-cutover-log.md` |
| **P2-1** | `feat(gates): audit check 104 — tracked int-keyed profile-identity sites`<br><br>Named-entry ratchet: a new site fails, a stale baseline line fails. Prints its scan set, so "N sites" is a claim about the code, not the scanner. Ships green with ~31 sites baselined — same shape as 103's Phase-1 green. Adds itself to the recovery protocol's Step 4. | new tool + baseline, `Makefile`, `firestore-cutover-log.md` |
| **P2-2** | `feat(profiles): mint the profile ULID eagerly at creation; delete the lazy backfill`<br><br>Local mint, offline-safe. `createProfile`/`ensureDefaultProfile` take the pre-minted id. Lazy backfill and `setUlid` deleted; replaced by an idempotent create-if-missing on activation so a missing remote doc still heals. The two bare `select(id)` sites now pass `ulid:`. The tutored mirror records the remote id it was handed. | profiles repo + interface + dao, firestore profile repo, `notifications_bootstrap.dart`, `router_provider.dart`, doc comments |
| **P2-3** | `refactor(profiles): ProfileModel.ulid is required — the compiler now enforces the identity`<br><br>`fromDriftRow` throws a named StateError with a reseed instruction on a legacy null row. `select` takes `required String ulid`, so a third bare call site cannot be written. 4 lib + 43 test files; freezed regenerated. | `profile_model.dart`, `profile_providers.dart`, 43 test files, regenerated `*.freezed.dart`/`*.g.dart` |
| **P2-4** | `fix(tutoring): delete the dead divergent bookmark writer (T-34)`<br><br>`TutoredWriteRouter.pushBookmark` was reachable only from `BookmarkRepositoryImpl`, which nothing in `lib/` constructs. Its "mirror firestore_gateway_impl" comment described a formula that file no longer implements for bookmarks, so it emitted a trailing-underscore id matching nobody. Deleted, not reconciled — reconciling would have required a check-102-forbidden import. | `tutored_write_router.dart`, `bookmark_repository_impl.dart`, 4 test files |
| **P2-5** | `fix(providers): hoist the tutored guard into _watchActiveAccountAndProfile (T-35)`<br><br>All 13 profile-scoped providers refuse uniformly. Closes a live latent corruption: 12 of them previously served the tutor's own tree during a tutored session. **Known regression:** the talmid's scheduler now renders nothing instead of the tutor's learning order, until Phase 3's T-37. | `repository_providers.dart`, `bookmark_repository_impl.dart` |
| **P2-6** | `feat(learning-order): allow owner delete and implement resetToDefault (T-33)`<br><br>Rules and the code writing through them in one commit, per the plan's standing rule. Matches the `goals` precedent at firestore.rules:525. **Rules must be deployed before device verification.** | `firestore.rules`, learning-order repo + screen |
| **P2-7** | `docs(planning): resolve Phase 2 — identity singular at the source; T-30/T-31 re-phased to 3` | 3 planning docs |

**Interrupt rule.** No commit here is large enough to require a mid-commit checkpoint, but the policy is stated so it does not have to be invented under pressure: **never `git stash`** (`firestore-cutover-log.md:44-45` — *"A partial pop has already silently dropped work on this project"*). If interrupted: run `git status --porcelain`, diff against the IN FLIGHT entry in the log and the edit list in `firestore-phase2-plan.md`, then either finish the list or `git checkout --` the named files by hand. If a checkpoint commit is genuinely needed, prefix it `wip(identity):`, expect check 104 red at that boundary, and say so in the IN FLIGHT entry — a red gate with a written explanation is recoverable; a red gate without one is indistinguishable from a broken tree. Treat uncommitted work as **suspect, not lost** (`:42-43`); collect no gate result while an agent is writing (`:46-47`).

---

## 6. Verification that isn't a lie

| Step | What actually proves it | What does *not* prove it |
|---|---|---|
| **P2-1** | The gate's own first run, whose printed site count and scan-set list go verbatim into the log. Then a deliberate red-demo: add a throwaway `typeof profileId !== "number"` guard in a scratch `functions/src` file, confirm exit 1, revert. A ratchet nobody has seen fail is a ratchet nobody has tested. | `make audit` exit 0. It was 0 before the gate existed. |
| **P2-2** | `dart analyze` green **does** prove every `createProfile`/`ensureDefaultProfile` caller was updated (analyzer covers `test/`). It proves nothing about the remote write. Device: on a wiped emulator-5556 profile, create a profile and read `users/{uid}/learner_profiles/` directly — the doc id must be a 26-char Crockford ULID (`ulid.dart:3,30`). Then kill the network, create a second profile, confirm it gets a local ULID and no crash. | Any test file. None seeds a profile whose remote doc is missing. |
| **P2-3** | `dart analyze` green is a **complete** proof here — a `required` field on a freezed class fails at every construction site, and analysis covers `test/`. This is the one step in the phase where the cheap gate is sufficient. | — |
| **P2-4** | `dart analyze` green is a **complete** proof of removal — deleting a method breaks every caller at compile time. There is nothing behavioural to verify: the deleted path was unreachable from production, which is *why* it is deleted. | The draft's "tutor sets a bookmark, owner reads the same document" device step. It is **unexecutable** — the live adapter refuses tutored bookmark writes before anything reaches the router. Do not attempt it; do not record it as passed. |
| **P2-5** | Device only: enter a tutored session and confirm every profile-scoped screen shows empty/loading, and specifically that the talmid's scheduler no longer shows the *tutor's* learning order. **Distinguish the two causes of "empty"** — after this commit, "empty" means either "refused (correct)" or "the tutored mirror has no data (also true, pre-existing)". Only the disappearance of the tutor's own order proves the hoist. | "The screen is empty." That was already true for bookmarks and is now true for a second reason. |
| **P2-6** | Deploy rules to the dev project, then on device: reset a learning order to default and confirm the documents are gone from `users/{uid}/learner_profiles/{ULID}/learning_order/`. Negative control: confirm a signed-out/other-account client is denied. | `dart analyze`, check 103, check 104, `make audit` — all four are green whether or not the rules line was changed at all. |
| **Every step** | Read the **stdout line** of R6d (check 98/98) inside `make audit`, not the exit code. `coverage/lcov.info` exists on this machine (verified, 469KB), so R6d **runs** — but if it is ever deleted or staled it soft-skips and still exits 0 *(inherited: `check_lcov_denominator.dart:29-37,156-166`; `Makefile:1312-1320` passes no `--strict`)*. **Never delete `coverage/lcov.info` to make a gate green.** | `=== audit PASSED ===`. It does not distinguish a check that passed from a check that skipped. |
| **Phase exit** | Re-run the two **count-only** ratchets (check 100 MCF-11 autoincrement-id-in-payload, baseline `39`; check 101 bare-firebase-instance, baseline `2`). Both compare `actual > baseline`, so a *drop* passes silently and leaves headroom for regressions. If P2-2/P2-3 lowered either count, lower the baseline in the same commit per the checkers' own instruction and record before/after. | Leaving them alone because audit is green. Green here is true and empty. |

### Deferred verification — attribution map for the single end-of-cutover CI phase

| ID | Skipped ci-only check | What it would have covered | Commit |
|---|---|---|---|
| **D1** | `make test` (Dart suite) | Behaviour of every touched Dart file. Files edited to **compile** but never **run**: the 43 `ProfileModel` fixture files (P2-3); `bookmark_repository_impl_test.dart`, `completion_repository_impl_test.dart`, `bulk_mark_screen_staleness_test.dart`, `s1_tutored_write_router_test.dart` (P2-4); the profile-repository and `repository_providers` tests (P2-2, P2-5). **A green run here proves compilation was restored, not that the retired assertions were replaced.** | P2-2, P2-3, P2-4, P2-5, P2-6 |
| **D2** | `make test-rules` (emulator, 104-test matrix) | That `learning_order`'s new `allow delete: if isOwner(uid)` permits the owner and denies a stranger. **Warning for the CI reviewer:** this matrix is green before, during and after *any* keying change — `{profileId}` is an unconstrained wildcard (`firestore.rules:211-214`), so it can never detect an identity defect. Do not read its green as identity reassurance. | P2-6 |
| **D3** | `make test-functions` (emulator) | Regression only — Phase 2 changes no Cloud Function. Becomes load-bearing when T-30/T-31 land in Phase 3. **Standing warning to carry forward:** `functions/test/_cf_helpers.mjs:31` shares one int constant `PROFILE = 5` across 9 test files; "fixing" it by swapping in a ULID literal reproduces the same self-consistent-fixture blindness one identity later. | — (Phase 3) |
| **D4** | `make test-serial-tools` → `test/tool/audit_and_arb_parity_test.dart` | That the `make audit` target still runs end-to-end and prints the strings the test greps for, after check 104 was appended. | P2-1 |
| **D5** | `check_lcov_denominator.dart --strict` + the 60% coverage floor (GitHub Actions `test` job only) | That the 60% floor still holds after ~50 files change. **No new `lib/**` file is created in this phase** (the draft's provider move is deleted), so the per-file denominator risk is nil; only the floor is at issue. | P2-2, P2-3, P2-5 |
| **D6** | `dart format --set-exit-if-changed` (GitHub Actions `format-check` job only) | Formatting of every touched file, including the 43 mechanical test edits and the regenerated freezed output. `make ci` never runs it. | all commits |
| **D7** | `make audit` **exit-code assertion** | The one test that would assert `make audit` exits 0 is `skip:`-disabled with a reason that is now false (audit currently exits 0) *(inherited: `audit_and_arb_parity_test.dart:112-125`)*. Un-skipping it belongs to T-23/Phase 5, not here. | whole phase |
| **D8** | Writer/reader agreement for CF-mediated paths | No harness exists — `test/helpers/writer_reader_agreement.dart` drives only the owner seam; `TutorCallableInvoker` is injectable but no fake CF-double writes into the shared fake Firestore *(inherited)*. Highest-value test work the CI phase could add, and a **prerequisite for Phase 3's T-31**, not for Phase 2. | — (Phase 3) |

**Tests that will pass misleadingly, for the CI phase's reviewer:** all 14 `test/data/repositories/firestore_*_test.dart` take `profileId` as a constructor argument (`'profile-ulid-1'`) and never touch identity resolution; `doc_ids_test.dart:244-249` cross-checks `DocIds.bookmarkDocId` against `FirestoreGatewayImpl.pushBookmark` — a **different method with the same name** as T-34's subject — and stays green either way; the 104-test rules matrix is green regardless of keying *(all inherited)*.

---

## 7. Risk register

| # | What silently breaks | Specific detection |
|---|---|---|
| **R1** | Check 103 stays green through the entire phase while proving nothing about it; a reader takes "green" as "identity split closed." | Structural — no detection inside 103. Documentary mitigation only: the log records that 103's OK line and split set are **expected invariant** across Phase 2, and that check 104 is the phase's proof. |
| **R2** | Check 104 reports "0 new, 0 stale" and someone reads it as "the identity is unified." It is not: `lib/core/sync/**` still holds 179 `int profileId` occurrences, and `pushLearnerProfile` (`profile_repository_impl.dart:119,187,379` → `outbox_sync_write_facade.dart:146` → `outbox_processor.dart:671` → `firestore_gateway_impl.dart:466`) still writes an **int-keyed `learner_profiles` twin on every profile create/update** — invisible to 103 (parent collection not in `_kCollections`) and out of 104's scope by design. | The gate prints its scan set in its own OK line. The log carries this as a standing fact with the Phase 4 owner named. *Not fixed in Phase 2 — see §9, rejected defect 3.* |
| **R3** | A legacy Drift row with `ulid == null` crashes `ProfileModel.fromDriftRow` after P2-3. | By design, with a named `StateError` naming the profile id and instructing a wipe-and-reseed. Greenfield: reseeding is the remedy. A silent fallback here would be the defect. |
| **R4** | `_mintAndActivateFirestoreProfile` swallows all failures (`profile_repository_impl.dart:612-623`), so a Firestore outage leaves a profile with a valid local ULID and no remote document — and P2-2 deletes the lazy path that used to heal it. | P2-2's idempotent create-if-missing on activation is the replacement. Device check: create a profile with the network off, restore the network, activate it, confirm the doc appears. **Do not** make the remote write fatal — profiles are offline-first by explicit contract (`tutor_invites.ts:59-60`). |
| **R5** | R6d (check 98/98) soft-skips and still exits 0 if `coverage/lcov.info` is deleted or staled. It exists today and **is running**. | Read R6d's own stdout line, never the exit code. Explicit prohibition: never delete `coverage/lcov.info` to restore a green gate. |
| **R6** | A tutored session shows empty screens after P2-5 for two independent reasons (correct refusal; empty mirror), and "empty" is recorded as proof the hoist worked. | The only discriminating observation is that the talmid's scheduler **stops showing the tutor's own learning order**. Record that specific observation, not "screens are empty." |
| **R7** | `firestore_learner_profile_repository.dart:71-80` claims `tutorEditProfile` merges onto "the SAME document." **Verified false today** — `tutor_writes.ts:968-978,1005` validates an int and writes through the int-keyed `profilePath` (`:186-191`). It stays false through all of Phase 2. | Do not let this comment stand as evidence in either direction. Correct it or annotate it in P2-2's doc-comment sweep. |
| **R8** | Renaming any `Firestore*` repository class flips it from live to permanently unreachable in check 103's liveness logic, hiding a real split forever *(inherited: `check_profile_path_keying.dart:279-282,743-751`)*. | Rule: **Phase 2 renames no `Firestore*` class.** Detect by diffing `check_profile_path_keying.dart --report`'s WATCHLIST before/after: any collection moving live→DORMANT without a code deletion is this bug. |
| **R9** | Format drift ships — `make ci` has no format target (`Makefile:293`) while `CLAUDE.md:28` says it does. | `dart format` before every commit; D6 in the deferred table. |
| **R10** | The `_bmad/` churn gets swept into a commit, making the diff unreviewable and the log's "clean tree" claim false. | `git status --porcelain \| grep -v '^ M _bmad'` before every `git add`; explicit paths only; never `git add -A`. |
| **R11** | A rules change is authored but never deployed; the device check fails and is misattributed to a keying defect. | The `Deployed:` field in `CURRENT STATE` (added in P2-0) records the SHA the deployed rules/functions were built from. Before attributing any device failure, check that field **and** the App Check debug token — a device wipe regenerates it, and an unregistered token yields blanket `permission-denied` that reads exactly like a rules or keying failure. |
| **R12** | Check 104's baseline file is lost (bad checkout, an agent tidying a small file) and the gate silently tracks nothing. | Required header sentinel; a missing or sentinel-less baseline exits 1. |

---

## 8. Doc updates on completion (P2-7)

### `docs/planning/firestore-cutover-log.md`

**`CURRENT STATE` block (`:51-65`):**
- `Head:` → the **P2-6** SHA, with `(P2-7, this commit, not yet reflected)`. The self-reference lag is unavoidable for the final commit; state the previous SHA rather than writing a hash that cannot exist yet — that lag is exactly what made the Head field false at the start of this phase.
- `Phase:` → `0 ✅ · 1 ✅ · 2 ✅ · 3 next`.
- `Gates:` → `make audit` green (**104** checks); check 104 baseline = *N* entries (the measured number, verbatim from the first run); check 103 unchanged at 2 baselined splits; full `make ci` last green at `5b4d7924`, still batched.
- `Deployed:` → the SHA the dev-project rules were deployed from (P2-6).
- **`Live on Firestore` / `Dead adapters` — unchanged.** Phase 2 moved no feature. Resist promoting anything here; that is Phase 3's line to move.

**Append-only entry, `2026-08-06 — Phase 2 (identity at the source)`:**
1. What landed, per commit SHA.
2. **New standing fact:** *"Audit check 103 classifies INT writers by file location (`lib/core/sync/**`, `functions/src/**`), not by keying (`check_profile_path_keying.dart:54-66`). It cannot register Phase 2 or Phase 3 progress until those directories are deleted, and it cannot see `learner_profiles` itself, `tutor_active_access`, or any doc-id formula. Check 104 exists to cover the identity sites; neither covers doc-id formulas."*
3. **New standing fact:** *"`pushLearnerProfile` still writes an int-keyed `learner_profiles` twin on every profile create/update (`profile_repository_impl.dart:119,187,379`). It is ungated by 103 (parent collection) and out of 104's scope. It dies with the sync engine in Phase 4."*
4. **New standing fact:** *"Tutoring's `profileId` is a live Firestore path segment for 13 read collections (`pull_pipeline.dart:73-98`) and 9 write collections (`tutor_writes.ts:187` + 12 call sites). It is in Phase 3's migration unit, not Phase 2's — re-keying it alone strands both directions, silently, with every available gate green."*
5. **Deviation record** (see below).
6. `stash@{0}` recorded as UNDISPOSITIONED-REPORTED with its measured facts.
7. Step 4 gate list now includes check 104 (landed in P2-1).

### `docs/planning/firestore-cutover-tasks.md`

- **T-33, T-34, T-35 → `done`.** T-34's entry records that its stated premise was incomplete: the divergence was a trailing-underscore id (`'{curriculumId}_'`), its justifying comment described a formula `firestore_gateway_impl.dart` no longer implements for bookmarks, and the second writer was unreachable from production — so it was resolved by **deletion**, not reconciliation.
- **T-30 `todo` → `re-phased to 3`**, with the coupling evidence and the design note that `deleteLearnerProfile` must capture the ULID **before** `_drift.deleteProfile` removes the row (`profile_repository_impl.dart:284` deletes the row, `:291` calls the sync engine; the adapter at `:538-539` delegates straight through, so a naive implementation would have nothing left to send).
- **T-31 `decided` → `re-phased to 3`**, recording: the 13-read / 9-write coupling; that the correct count of `profile.id.toString()` sites in `manage_tutors_screen.dart` is **six** (`163,173,206,293,298,312`), not three — the three the original task omitted key `outgoingTutorGrantsProvider`, which filters `where("child_profile_id","==",…)` (`tutor_invites.ts:522-528`), so converting only the first three would list a child's grants under the old id while creating them under the new one; and the two citation drifts the extraction pass found (`invite_tutor_screen.dart:112` is the converse operation; `tutored_write_router.dart:410` is the signature, the `int.tryParse` is at `:412`). Note that the decoupled mirror line item shipped in P2-2.
- **New T-37 (Phase 3):** the tutored read seam — owner-uid-scoped handles so tutored sessions read the parent's tree instead of refusing. Blocks D1's completion.
- **New T-38 (Phase 5):** fold check 104 into T-23's gate retarget; fix `Makefile:1366`'s stale `all 68 greps clean`; un-skip `audit_and_arb_parity_test.dart:112-125` (its skip reason is now false).
- **New T-39 (Phase 3, prerequisite):** reconcile the gate's 10-collection WATCHLIST against `CURRENT STATE`'s 7 "dead adapters" before wiring anything — five gate names have no counterpart in the log's list and two log names have no watchlist entry.

### `docs/planning/firestore-cutover-plan.md`

- Phase 2 header (`:236`) → append `**RESOLVED <date> (<SHA>)**`, matching Phase 0/1 style (`:117`, `:187`).
- **Replace the exit line (`:264-266`)** with §6's criteria, stating plainly why the original was unachievable: check 103 is file-location-based and cannot shrink in Phase 2, and `make ci` is batched to end of Phase 4 by owner decision (`firestore-cutover-log.md:55-56`).
- Move the T-30/T-31 bullets (`:248-256`) from the Phase 2 section into Phase 3, with a one-line pointer to the coupling evidence.
- Top status line (`:3`) → `Phase 0 ✅ · Phase 1 ✅ · Phase 2 ✅ · Phase 3 next · Phases 4–5 pending`.

### How a prediction miss gets recorded

Use Phase 1's four-part structure verbatim (`firestore-cutover-plan.md:215-219`): **(a)** what was predicted, quoted; **(b)** what happened; **(c)** why the prediction was wrong, naming the mechanism, never a person; **(d)** which invariant is unaffected.

Triggers with the obligation pre-attached:
- **Check 104's first run reports a number other than ~31.** Record the measured *N* and the estimate's provenance. A predicted count is not a measured count; the measured one wins and goes into the log.
- **Check 103's OK line or split set changes at any boundary.** This plan predicts they are invariant. If either moves, the plan's model of the gate is wrong: stop, re-read `check_profile_path_keying.dart`'s bucket logic against the actual diff, record the corrected model, and continue. **Do not adjust the baseline to make it quiet.** (WATCHLIST *paragraphs* changing is not this trigger — explain it, don't stop.)
- **`make audit` goes red anywhere.** Record which check fired as a **gate success**, not a plan failure — and specifically note that this plan predicts check 102 green at P2-5 (it does not scan `lib/data/**`) and green at P2-4 (the forbidden import was avoided by deletion). If 102 fires, the plan's reading of the checker was wrong and that reading is what gets corrected.
- **P2-3 is dropped as too expensive.** Record it as a scoped-out deviation with the consequence: the ULID is guaranteed by construction but not by the type system, and a future null can be reintroduced without a compile error.
- **A device check fails.** Distinguish, in writing, an App Check failure, an undeployed-rules failure, and a keying failure **before** attributing it. All three present as `permission-denied`.

**The one sentence that must never be written:** *"the gate is green, therefore the split is closed."* Phase 1 already paid for that lesson — the gate's own reachability logic counted doc comments as evidence and both baseline entries were classified live off a doc comment, right by luck (`firestore-cutover-plan.md:221-227`).

---

## 9. Reviewer defects rejected

Everything not listed here was accepted and is folded into §4–§8. These did not survive.

**1. Reviewer 3's verdict "fatally-flawed" (the plan as a whole).** *Findings accepted; verdict rejected.* The tutored read/write coupling is real, verified, and blocking for T-30/T-31 — those are now re-phased. But it does not touch the other two-thirds of the phase: the eager mint, the `select()` seam, the `ProfileModel` type change, T-33, T-34 and T-35 have no dependency on tutoring's identity value. Condemning the whole plan for a defect confined to two of its steps would have thrown away the work that makes Phase 3 possible.

**2. Reviewer 2: "delete `TutoredWriteRouter.pushBookmark` *and* the `tutorUpsertBookmark` Cloud Function and its tests."** *Dart half accepted, CF half rejected.* The CF is deployed and externally callable; deleting it is a product decision about whether tutor bookmark-setting is still wanted, and it is entangled with T-31's re-keying of the same `profilePath`. Deleting the unreachable Dart path is sufficient to close T-34 and is verifiable by the compiler; deleting the CF is Phase 3 work riding with T-31.

**3. Reviewer 2: "no step ever stops the int-keyed `learner_profiles` write — this is a missing Phase 2 item."** *Fact accepted, work item rejected.* `pushLearnerProfile` really does write an int-keyed twin on every create/update, and it really is ungated. But stopping it in Phase 2 would strand the old sync engine's own `learner_profiles` pull/merge (`pull_pipeline.dart:144-147`, `LearnerProfileMerger`) while 11 collections still live on that tree — a change whose blast radius includes local profile rows, in a phase that cannot run a single test. It belongs to Phase 4's engine demolition (or Phase 3 at the earliest). Recorded as a standing fact with the owner named; not executed here.

**4. Reviewer 3: "make the remote profile-create failure fatal, since P2-2 deletes the only self-heal."** *Gap accepted, fix rejected.* Making it fatal would break offline profile creation, which is an explicit product contract (`functions/src/tutor_invites.ts:59-60` documents that profiles are offline-first and deliberately not verified server-side). The gap is closed instead with an idempotent create-if-missing at activation — one unconditional merge write, not a version gate, not a conditional bridge.

**5. Reviewer 1: "check 104 must be an exact-set gate that fails closed until it reaches empty."** *Rejected as specified.* Reviewer 2 correctly showed the end-state is unreachable (179 `int profileId` occurrences under `lib/core/sync/**` alone, plus the still-live int profile twin), and Reviewer 2 further showed it would make a mid-work checkpoint commit impossible — removing the log's only cited recovery mechanism at the exact moment it is needed. Replaced with a **named-entry** ratchet: new entries fail, stale entries fail, per entry, with no requirement that the set reach empty in any particular phase.

**6. Reviewer 1: "P2-5's new `lib/` file trips AG-5 test-mirroring and R6d."** *Correct about `lib/`, and its correction of the draft's R5 (that `coverage/lcov.info` is absent) is accepted and folded in — the file exists and R6d runs.* The defect itself is moot: the provider relocation is deleted from this plan, and the only new file Phase 2 creates is `tool/check_profile_id_int_sites.dart`. Verified this session that both checkers scan `lib/` only (`check_test_mirroring.dart`'s `_findUnmirrored` uses `Directory('lib')`; `check_lcov_denominator.dart`'s `_allLibFiles` uses `Directory('$root/lib')`), so a `tool/` file trips neither. The executing agent should not over-correct by adding a mirror test for a tool file it does not need.

**7. Reviewer 1: "check 103's output is not invariant — the WATCHLIST paragraphs move."** *Accepted in substance, rejected as a stop-work tripwire.* Folded in by narrowing the invariant to the OK line and the `currentSplits` set. A WATCHLIST paragraph changing because an INT-A touch was deleted must be explained in the log, not treated as a defect signal — the draft's wording would have trained the executing agent to either halt on noise or learn to ignore the criterion.

**8. Reviewer 2: "the plan mandates 9 commits while the log's convention says agents must never commit — a MUST is being violated."** *Rejected as stated.* The convention is already conditional: *"never commit or push **unless the brief says otherwise**"* (`firestore-cutover-log.md:149-160`). The plan says otherwise. The underlying point — that the override must be **written down**, not implied — is accepted and is P2-0's item 4.
