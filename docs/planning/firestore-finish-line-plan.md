# Firestore Migration — Finish-Line Plan

**Status:** ACTIVE. This is the single authoritative plan for completing the Drift→Firestore migration.
**Created:** 2026-08-13. **Branch:** `crew/daniel`. **Baseline commit:** see §7.
**Supersedes:** all `phase3-handoff-*.md`, `firestore-phase2-plan.md`, `epics-firestore-migration-phase*.md`, `tech-debt-remediation-plan.md`, `sync-architecture-plan.md`, `two-database-architecture.md`, `architecture-offline-v2.md`, and `docs/specs/spec-drift-firestore-migration/SPEC.md` — all now in `docs/_archive/superseded/`.

Live companion docs (do **not** archive): `docs/firestore-rewrite-map.md`, `docs/firestore-collection-layout.md`, `docs/planning/firestore-cutover-plan.md`, `docs/planning/firestore-cutover-tasks.md`, `docs/planning/phase3-wave-plan.md`, `docs/planning/phase3-handoff-5.md`, `docs/planning/t37-tutored-view-decision-brief.md`.

---

## 1. Definition of done

Three documents defined "done" differently. This plan resolves that conflict once.

**Ruling: GREENFIELD. No existing-user backfill.**

The archived SPEC required existing-user backfill with byte-verification, a per-account point-of-no-return, and staged rollout. That requirement is void — not deferred. The Drift user-database stack was wholesale-archived to `docs/_archive/drift-user-db/`, so **no code path exists that can read a legacy SQLite user database**. Backfill is impossible by construction. The SPEC was also `draft` and pointed at a migration plan that `docs/firestore-rewrite-map.md` supersedes.

**The finish line is therefore:**

1. No production code path throws `UnimplementedError` for a user-reachable action.
2. No achievement-shaped read fabricates a zero/empty when the backend is not ready (the **D-E rule**).
3. Profile identity is a valid 26-character Crockford ULID everywhere (**AD-24**); `CurriculumId` is the sole track identity (**AD-25**).
4. No orphaned Drift user-domain artefacts remain in `lib/`.
5. The `make audit` profile-path-keying gate runs clean and unskipped.
6. `flutter test` shows no regression against the recorded baseline.

Explicitly **out of scope**: store release, iOS support, existing-user migration, and the AD-23/AD-28 layering refactor (see §6).

---

## 2. Rules for every Codex MCP dispatch

These are not style preferences. Each one maps to a failure already hit on this migration.

**R1 — No `sandbox`, no `approval-policy`, no override parameters on any Codex MCP call.** Pass `prompt` and `cwd` only.

**R2 — No agent runs `build_runner`.** Codegen is global; two concurrent runs corrupt each other's output. An agent that needs regeneration reports "codegen needed" and stops. The orchestrator runs it once, serially, between waves.

**R3 — No agent runs any git state-changing command.** No `commit`, `checkout`, `stash`, `branch`, `reset`, `rebase`. `git mv` for file moves is permitted. The orchestrator owns every commit.

**R4 — No agent measures the test surface.** Agents never run the full suite and never report pass/fail counts. *Reason: two waves once ran over overlapping directories and each measured the whole surface; one reported a 446→428 "regression" that was pure crosstalk from the other's in-flight edits.* The orchestrator measures, once, per wave.

**R5 — Every lane owns an explicitly enumerated, disjoint file list.** Not a directory description — a list. Before dispatch, the orchestrator confirms no path appears in two concurrently-running lanes.

**R6 — Agents report a per-item disposition table.** *Reason: coverage silently collapsed three times (40→6 tests, 37→4, 104→7) when agents were trusted to "migrate" without itemising.*

**R7 — Baselines are commit-to-commit, never `git stash`.** Stashing is unsafe while parallel agents write to the tree — it would capture their in-flight edits.

---

## 3. Live work inventory

Derived by auditing every migration doc **against the code at HEAD**. An item appears here only if code evidence proves it is still outstanding.

| # | Item | Evidence | Lane |
|---|---|---|---|
| 1 | Tutored-session reads refuse all profile-scoped repositories | `data/firestore/repository_providers.dart:170-178` returns `null` when a tutored profile is selected | L1 |
| 2 | Tutored-session writes not routed to owner-scoped tutor CFs | `features/tracks/setup/presentation/screens/edit_track_screen.dart:385-392` | L1 |
| 3 | Tutor point-override write path inconsistent | `features/gamification/presentation/screens/point_config_screen.dart:212-214` vs null provider | L1 |
| 4 | `track_learning_order.resetToDefault` throws | `data/repositories/firestore_track_learning_order_repository.dart:421-438` | L2 |
| 5 | Reorder-amnesty stamp (`last_reorder_at`) not co-written with order changes | `data/repositories/firestore_curriculum_track_repository.dart:99-110`; `firestore_track_learning_order_repository.dart:59-73` | L2 |
| 6 | `hasCompletionsForStage` throws (stage deletion safety) | `data/repositories/firestore_stage_definition_repository.dart:308-318` | L3 |
| 7 | `getStagesByTrack` throws — needs re-expression on CurriculumId per AD-25 even with no current caller, since the interface is otherwise dead weight blocking cleanup | `features/tracks/stages/data/repositories/stage_definition_repository_impl.dart:169-180`. **Corrected 2026-08-13:** verified zero production callers exist; original "live dashboard/scheduler callers" claim was wrong. | L3 |
| 8 | `deleteStagesForTrack` throws — track-creation reseed broken | `stage_definition_repository_impl.dart:185-191`. **Corrected 2026-08-13:** `firestore.rules:414` denies delete on `stage_definitions` outright — must tombstone, not delete, and cannot reuse `replaceStagesForCurriculum` as originally assumed. | L3 |
| 9 | Reward catalogue persists to SharedPreferences only | `features/gamification/presentation/providers/reward_config_controller.dart:122-127` | L4 |
| 10 | Sync-status UI unavailable for cloud-born accounts | `features/settings/presentation/widgets/backup_sync_section.dart:74-83` | L5 |
| 11 | Profile-path-keying audit gate unreconciled: `point_configs` missing from registry, 8 new baseline violations, assertion skipped | `tool/check_profile_path_keying.dart:233-251`; `test/tool/audit_and_arb_parity_test.dart:146-157`; `Makefile:1356` stale "103/103" | L6 |
| 12 | Orphaned Drift user-domain artefacts in `lib/` | see §5 (L7) | L7 |
| 13 | D-E rule round two — 11 further fabricated-zero sites | see §5 (L8) | L8 |
| 14 | Domain service holds `FirebaseFirestore` | `features/settings/domain/services/data_export_import_service.dart:4,51` | L8 |
| 15 | Integer identity violations (AD-24/AD-25) across ~90 files | see §4 | **P2** |

---

## 4. Phasing

**Phase 1 — L1…L8 in parallel.** Disjoint file sets, all landing on `crew/daniel`.

**Phase 2 — Integer-identity refactor, alone.** This is *not* a lane. It rewrites shared Freezed models (`track_scope`, `goal_entity`, `scheduler_input`, `stage_definition`, `scheduler_stage_repository`, `streak_log_event`) and regenerates `.freezed.dart`/`.g.dart` across ~90 files touching nearly every other lane. Running it concurrently guarantees codegen conflicts. It runs alone, after Phase 1 lands and codegen is regenerated once.

Sentinels to eliminate in Phase 2: `RewardMilestone.kGlobalTrackSentinel = 0`, `kFirestoreUnmappedStageId = -1`, and every `profileId: 0` / `trackId: 0` call site.

**Phase 3 — Test repair.** Against the §7 baseline, grouped by root cause. Sequenced last because Phases 1–2 will both fix and unmask failures; slicing test work against a pre-Phase-1 failure list would draw lane boundaries against a fictional inventory.

---

## 5. Lane map

Concurrent lanes must not share a file. Verified disjoint at dispatch.

- **L1 — Tutored session** (items 1,2,3): `data/firestore/repository_providers.dart`, `features/tracks/setup/presentation/screens/edit_track_screen.dart`, `features/gamification/presentation/screens/point_config_screen.dart`. All three hinge on the same null-in-tutored-session provider, so they are one lane, not three.
- **L2 — Track order** (items 4,5): `data/repositories/firestore_track_learning_order_repository.dart`, `features/tracks/track_order/data/repositories/track_learning_order_repository_impl.dart`, `data/repositories/firestore_curriculum_track_repository.dart`, `features/scheduler/domain/services/daily_task_projection_service.dart`.
- **L3 — Stages** (items 6,7,8): `data/repositories/firestore_stage_definition_repository.dart`, `features/tracks/stages/data/repositories/stage_definition_repository_impl.dart`, `features/tracks/stages/domain/repositories/stage_definition_repository.dart` (added 2026-08-13 — required to change `getStagesByTrack`'s signature; unowned by any other Phase-1 lane).
- **L4 — Reward persistence** (item 9): `features/gamification/presentation/providers/reward_config_controller.dart`, `features/dashboard/presentation/providers/dashboard_providers.dart`, `features/gamification/presentation/providers/achievements_overview_provider.dart`.
- **L5 — Sync-status UI** (item 10): `features/settings/presentation/widgets/backup_sync_section.dart`.
- **L6 — Audit gate** (item 11): `tool/check_profile_path_keying.dart`, `Makefile`, `test/tool/audit_and_arb_parity_test.dart`.
- **L7 — Dead-code deletion** (item 12): orphaned user-domain Drift artefacts, deletion list grep-verified before removal. **Retained by design and NOT deletable:** the content database (`lib/core/database/content/**`) and device registry (`lib/core/database/registry/**`).
- **L8 — D-E round two + boundary** (items 13,14): `dashboard_body.dart`, `active_track_card.dart`, `learning_track_card.dart`, `track_detail_screen.dart`, `curriculum_list_screen.dart`, `progress_tier_counter_row.dart`, `items_learned_providers.dart`, `lifetime_knowledge_providers.dart`, `data_export_import_service.dart`.

**Known collisions — L8 must be serialised after L1 and L4.** `dashboard_providers.dart` appears in L4 and L8; `track_detail_screen.dart` appears in L1 and L8. These are the only overlaps and they are resolved by ordering, not by care.

---

## 6. Findings deliberately NOT in this plan

Recorded so they are not re-raised as new discoveries.

**C3 "hard-delete violations" — 11 reported, 0 real.** The rule was mis-stated as "rules deny delete outright". The actual rules are per-collection and contain deliberate `allow delete: if isOwner(uid)` grants (`firestore.rules:456, 524, 593, 628, 636, 650`). Every reported call site verified LEGAL or SERVER-SIDE (admin-privileged Cloud Function, where rules do not apply). No runtime bug exists.

**Rule 3 "Firebase SDK boundary" — mostly phantom.** The boundary is `lib/data/firestore/**` + `lib/data/repositories/**` + `lib/core/auth/**` + `lib/core/sync/**`, not `core/sync` + `core/auth` alone. The ~20 `firestore_*_repository.dart` hits are compliant by design. Only item 14 survives.

**Drift retention — by design.** The content and device-registry Drift databases are intentional architecture, not residue.

**AD-23/AD-28 layering (~25 feature areas) — parked, not now.** Presentation providers importing repositories is the app's existing shape throughout. Folding it in would convert a bounded finish-line into an unbounded refactor. Track separately if it is ever wanted.

---

## 7. Baseline

Measured by the orchestrator on the full suite, commit-to-commit (never `git stash`).

- **Baseline commit:** `48beaf92` (`crew/daniel`), measured 2026-08-13.
- **Baseline counts:** **5603 passed, 49 skipped, 300 failed**, across **234 unique failing test files**.
- Failing-test file list retained at `scratchpad/BASELINE_failfiles.txt` for set-diff.
- Largest failing clusters: `e2e/journeys` (34 files), `features/tutoring` (11), `tool` (10), `features/onboarding/presentation/screens` (10), `story_acceptance` (9), `features/settings/presentation/screens` (9), `features/profiles/presentation/widgets` (9).
- **Note on scope:** earlier work quoted ~108 failures. That figure came from a nine-directory subset, not the full suite. 300 is the real number.
- **Per-wave verification is targeted** to each lane's blast radius (a full-suite run costs ~30 min and buys little when lanes are file-disjoint). One full-suite run gates the end of Phase 1.
- **Wave acceptance:** re-run the full suite at the wave tip; set-diff the failure lists. A wave is accepted only if the new-failure set is empty. Raw counts alone are insufficient — a file that fails to compile runs zero tests and looks identical to a passing file.

---

## 8. Execution status

Live tracker, updated by the orchestrator as lanes land. Not a lane itself.

| Lane | Status | Notes |
|---|---|---|
| L1 — Tutored session | **Landed, verified** | Tutored reads resolve `(ownerUid, profileId)` from the grant per t37 Option A; tutor writes route through `tutorSetProfileProgram`; point-config is read-only in tutor mode with a visible reason (writes intentionally disabled — the tutor gamification CF writes `preferences/gamification_settings`, not `point_configs`). Verified by orchestrator: `repository_providers_test.dart` 20/20 (incl. 3 new tutor cases), `edit_track_screen_l1_test.dart` 31/31, no regressions. **Gap:** no widget test exists for `point_config_screen.dart` (pre-existing gap, not introduced here) — noted for Phase 3. Codex's sandbox lacks `dart`/`flutter`; all verification done by the orchestrator. |
| L2 — Track order | **Landed, verified** | `resetToDefault` uses rules-legal tombstones (`firestore.rules:536-548` denies delete on `track_learning_order`); reorder saves/resets atomically co-write `last_reorder_at`. The redispatch correctly inspected and repaired the pre-existing partial diff (fixed a missing import and a broken assertion) rather than assuming it was good. Verified by orchestrator: new test file 3/3 pass. |
| L3 — Stages | **Landed, verified** | `hasCompletionsForStage` queries `completions.stage_id` (the ordinal), ignores purged completions, throws on malformed data. `getStagesByTrack`/`deleteStagesForTrack` re-typed to `CurriculumId`; delete tombstones via `synced_at` (rules deny delete outright on `stage_definitions`, confirmed). First dispatch correctly caught two errors in my brief before writing anything (see item 7/8 corrections above) rather than guessing. Verified independently by orchestrator: 35/35 pass, exact match with Codex's self-report. |
| L4 — Reward persistence | **Landed, verified** | Owner-side writes now reach `users/{uid}/learner_profiles/{profileId}/preferences/gamification_settings` — the same document the tutor CF writes (`tutor_writes.ts:744`), confirmed via `docs/firestore-collection-layout.md:162`. New `FirestoreRewardSettingsRepository`. Verified by orchestrator: 8/8 across two test files. The `dashboard_providers_test.dart` compile failure surfaced in a combined run is confirmed pre-existing (file byte-identical to baseline commit) — not an L4 regression. |
| L5 — Sync-status UI | **Landed, verified** | Status now derived from live `users/{uid}` Firestore snapshot metadata (`hasPendingWrites`/`isFromCache`) — Synced / Syncing / Offline+Retry / honest-unknown, replacing the permanent "unavailable" message. New `firestore_sync_status_providers.dart`. Verified by orchestrator: 9/9. |
| L6 — Audit gate | **Landed, verified (self)** | Registry now 18/18 matching rules (added `point_configs`). All 8 baseline violations traced to rules-line + Cloud-Function-line + Flutter-repository-line evidence and confirmed legitimate (not defects) — false positives caused by the checker's conservative Cloud-Functions bucket not recognizing string/ULID `profileId` construction. Clean-audit assertion un-skipped and passing. Verified by orchestrator: 0 dangling references to anything L6 touched; the checker's own before/after output matches Codex's self-report exactly. |
| L7 — Dead-code deletion | **Landed, verified** | Deleted 25 files: `base_dao.dart`, 18 orphaned user-domain tables, the 4-file `accounts`/`curriculum_tracks`/`learner_profiles`/`track_learning_order` cluster (unreferenced once Step 1 landed), and `track_scope.dart`+`.freezed.dart`. `CompletionCommand` correctly retained (dead in prod, used by tests). Updated 4 tests that referenced deleted files to assert something meaningful about current architecture rather than being gutted. Verified by orchestrator: zero references to any deleted file anywhere in a full `dart analyze lib/ test/` run; 86/87 of the four target tests pass (1 failure confirmed pre-existing, unrelated file). |
| L8 — D-E round two | **Not started** | Per §5, must serialise after L1 and L4 (both landed). Not yet dispatched — deferred behind Phase 1 gate closure. |
| Phase 2 — Int-identity | **Re-audited, ready to dispatch** | Fresh post-Phase-1 audit complete (scope shrank: `track_scope.dart` already deleted by L7; two `StageDefinitionRepository` methods already migrated by L3). Split into 3 disjoint sub-phases: A (goal/track identity, 18 files), B (stage identity, 15 files), C (profile/streak identity + residual sentinels, 12 files). |
| Phase 3 — Test repair | **Blocked on Phase 1–2** | Per §4. |

**PHASE 1: COMPLETE.** All 7 lanes landed, independently verified, one regression found by the full-suite gate and fixed (see below), confirmed clean by exact file-level diff across two full-suite runs.

**Resolved:** batch size was the cause — two 6-7-way concurrent Codex dispatches were rejected in full before any lane ran; single dispatches went through cleanly every time after. All Phase 1 lanes (L1-L7) subsequently dispatched one at a time, landed, and were independently verified by the orchestrator (never trusted from a lane's self-report alone).

**Two more pre-existing issues surfaced during verification, unrelated to any Phase-1 lane, confirmed via `git diff` against baseline commit `48beaf92` (file byte-identical in both cases):**
- `data_export_import_service.dart:146` calls `DateTime.now()` outside `core/time/`, violating the LocalDayClock invariant (Story 25.10). Predates this session.
- `test/tool/audit_and_arb_parity_test.dart`'s AC1 "red-demo" sub-test for the PROFILE-KEY-SPLIT check tries to write a throwaway fixture into `lib/core/sync/`, which does not exist (and did not exist at baseline either — likely removed in the earlier Drift/sync-engine archival). The check's actual assertion (item 11 — clean against tracked baseline) passes; only this auxiliary self-test of the test harness is broken.

Both are candidates for Phase 3 (test repair), not new Phase-1 scope.

**Environment note:** `dart`/`flutter` are on this host at `/home/daniel/flutter/bin/` but not reliably on PATH — neither in the orchestrator's shell nor inside every Codex sandbox, and critically not inherited by `Process.run()` subprocess calls even after `export PATH=...` fixes the parent shell (several `audit_and_arb_parity_test.dart` sub-tests shell out to `dart run ...` directly). Always `export PATH="$HOME/flutter/bin:$PATH"` before invoking `flutter`/`dart`, in the same command, when subprocess spawns are involved.

**Phase 1 exit gate — first run, 2026-08-14:** 5548 passed / 48 skipped / 338 failed (vs. baseline 5603/49/300). Raw counts alone were insufficient to interpret — the original 234-file baseline list was lost when `/tmp` was wiped mid-session, so a like-for-like set-diff wasn't possible. Investigated by mechanism instead of by count:

- Cluster-level shape matched the baseline almost exactly (`e2e/journeys` 34=34, `features/tutoring` 11=11, `story_acceptance` 9=9, `features/settings/presentation/screens` 9=9, `features/profiles/presentation/widgets` 9=9, `tool` 9 vs 10 — *improved* by 1, consistent with L6's fix).
- Every "new-looking" cluster spot-checked (`core/preferences`, `features/dashboard/presentation/widgets`, `features/scheduler/domain/services`, the `ProfileModel`-missing cluster) turned out to be a compile failure on a file `git diff 48beaf92` shows byte-identical to baseline — i.e. pre-existing debt my original record simply never itemized by filename (I'd only recorded the top 7 clusters, not the full 234-file list).
- One **genuine regression** found and isolated: L3's `StageDefinitionRepository` interface change (`getStagesByTrack`/`deleteStagesForTrack`: `int trackId` → `CurriculumId`) broke 5 test files elsewhere in the tree with stale fake/stub implementations of that interface, still typed `int`. Exhaustively grepped for every file referencing either method across the full failure log — exactly 5, no more. None of the other 6 lanes broke any downstream consumer (checked: zero compile errors reference any other Phase-1-touched production file).
- Fix dispatched as a scoped 5-file lane, independently re-verified (36/36 tests pass across the 5 files), then a **second full-suite gate run**: 5584 passed / 48 skipped / 333 failed. Exact file-level diff between the two runs: 248 → 243 failing files, and the 5 files that dropped off are precisely the 5 fixed files — zero new failures appeared. Phase 1 is confirmed clean.

**Lesson:** this is exactly why the plan mandates a full-suite gate rather than trusting per-lane test runs — L3's own tests (scoped to its 3 owned files) could never have caught a break in a file outside its ownership. R4 (agents never run the full suite) is doing its job by forcing this catch to happen at the gate, not being skipped because a lane self-reported clean.

**Environment note:** `dart`/`flutter` are on this host at `/home/daniel/flutter/bin/` but not reliably on PATH — neither in the orchestrator's shell nor inside every Codex sandbox, and critically not inherited by `Process.run()` subprocess calls even after `export PATH=...` fixes the parent shell (several `audit_and_arb_parity_test.dart` sub-tests shell out to `dart run ...` directly). Always `export PATH="$HOME/flutter/bin:$PATH"` before invoking `flutter`/`dart`, in the same command, when subprocess spawns are involved.
