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
| 7 | `getStagesByTrack` throws — dashboard/scheduler callers live | `features/tracks/stages/data/repositories/stage_definition_repository_impl.dart:169-180` | L3 |
| 8 | `deleteStagesForTrack` throws — track-creation reseed broken | `stage_definition_repository_impl.dart:185-191` | L3 |
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
- **L3 — Stages** (items 6,7,8): `data/repositories/firestore_stage_definition_repository.dart`, `features/tracks/stages/data/repositories/stage_definition_repository_impl.dart`.
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

- **Baseline commit:** recorded at the moment the first write-lane starts.
- **Baseline counts:** full-suite pass / skip / fail, with the failing-test list retained for set-diff.
- **Wave acceptance:** re-run the full suite at the wave tip; set-diff the failure lists. A wave is accepted only if the new-failure set is empty. Raw counts alone are insufficient — a file that fails to compile runs zero tests and looks identical to a passing file.
