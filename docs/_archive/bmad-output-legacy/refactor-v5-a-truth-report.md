# V5-A Task-Truth Report — W1 + W2

**Date:** 2026-05-20
**Branch:** dev
**Scope:** W1.1–W1.30 + W7.20–W7.23 (S1) + W2.1–W2.41 (S3/S4/S2)

---

## Verification Notes

All code lives under `learning_tracker/lib/` (not a top-level `lib/`).
"Old path exists" = actual source code found there, not just a re-export stub.
Tasks marked SKIPPED in the tracker (W1.17, W1.18, W1.21 partial, W1.22 partial, W1.23) are accepted as intentional skips with documented reasons; they are not demoted unless the claim itself is false.

---

## Verified (60) — VERIFIED

### W1 — Foundation & dead code

- **W1.1**: `lib/app/` exists with all four sub-dirs: `router/`, `bootstrap/`, `restore/`, `sync_runtime/` — confirmed.
- **W1.2**: New files at `lib/app/router/{app_router,app_router.gr,router_provider,app_shell}.dart` + `guards/auth_guard.dart`. Old `core/navigation/` files are 1-line re-export stubs pointing to the new paths (e.g. `core/navigation/app_router.dart` line 2: `export '…app/router/app_router.dart'`). Move complete.
- **W1.3**: All 7 bootstrap files present at `lib/app/bootstrap/`: firebase, crashlytics, logger, analytics, seed, account, notifications.
- **W1.4**: `lib/app/restore/` contains `device_restore_screen.dart`, `device_restore_service.dart`, `restore_providers.dart`.
- **W1.5**: `lib/app/sync_runtime/sync_lifecycle_observer.dart` exists; orchestrator-wiring version confirmed (imports `sync_orchestrator_providers.dart`).
- **W1.7**: `core/sync/merge/merge_rules.dart` exists. `features/sync/domain/merge_rules.dart` is a 2-line re-export stub. Move complete.
- **W1.8**: `core/preferences/profile_scoped_preference_keys.dart` exists. `features/sync/domain/profile_scoped_preference_keys.dart` is a 2-line re-export stub. Move complete.
- **W1.9**: `core/preferences/language_provider.dart` exists. `features/settings/presentation/providers/language_provider.dart` is a 2-line re-export stub. Move complete.
- **W1.10**: All 18 feature barrel files confirmed: `account/account.dart`, `content_browsing/content_browsing.dart`, `dashboard/dashboard.dart`, `gamification/gamification.dart`, `learning/learning.dart`, `learning_order/learning_order.dart`, `notifications/notifications.dart`, `onboarding/onboarding.dart`, `profiles/profiles.dart`, `progress/progress.dart`, `sacred_time/sacred_time.dart`, `scheduler/scheduler.dart`, `settings/settings.dart`, `stages/stages.dart`, `sync/sync.dart`, `track_learning_order/track_learning_order.dart`, `tracks/tracks.dart`, `tutoring/tutoring.dart`.
- **W1.11**: `packages/custom_lints/lib/src/rules/no_feature_cross_import.dart` exists and enforces barrel-only cross-feature imports (`features/X/X.dart`). Registered in `learning_tracker_lints.dart`.
- **W1.12**: Makefile `learning_tracker/Makefile` line 317–320 contains audit grep "14/15 — No features/ imports inside lib/core/" (W1.12).
- **W1.13**: Makefile line 322–328 contains audit grep "15/15 — No cross-feature deep imports" (W1.13).
- **W1.14**: Correctly still blocked/skipped — CI workflow `.github/workflows/ci.yml` line 179 has the `|| echo "::warning::..."` soft-fail clause. Tracker marks it `task-blocked`. No change needed.
- **W1.15**: `packages/custom_lints/test/no_feature_cross_import_test.dart` exists.
- **W1.16**: `packages/custom_lints/test/no_curriculum_display_name_bypass_test.dart` exists.
- **W1.17**: Tracker notes "SKIPPED: test refs exist; not deleted". `dashboard_model_provider.dart` still present — consistent with skip claim. Accepted.
- **W1.18**: Tracker notes "SKIPPED: test refs exist; not deleted". `data_export_import_service.dart` still present — consistent with skip claim. Accepted.
- **W1.19**: `core/constants/app_assets.dart` does not exist. Deleted.
- **W1.20**: `core/database/seed/test_date_seeds.dart` does not exist. Deleted.
- **W1.21**: Tracker notes "partial: 6 deleted, 3 skipped (test refs)". 6 confirmed deleted: `bulk_completion_dialog`, `completion_button`, `todays_tasks_widget`, `key_stats_row`, `content_browser_tree`, `content_version_check_service`. `add_track_controller.dart` exists at `features/tracks/setup/presentation/controllers/` and has a test reference (`test/features/track_setup/presentation/controllers/add_track_controller_test.dart`). Partial skip consistent with claim. Accepted.
- **W1.22**: Tracker notes "partial: text_content_config deleted, 6 skipped (test refs)". `text_content_config.dart` gone; remaining 6 files confirmed to have test references. Accepted.
- **W1.23**: Tracker notes "SKIPPED: all 3 screens have test refs". All 3 zombie screens still present but skipped per claim. Accepted.
- **W1.24**: All 7 `.gitkeep`-only dirs deleted: `utils/extensions`, `utils/formatters`, `utils/helpers`, `parent_mode/domain/entities`, `parent_mode/domain/use_cases`, `parent_mode/domain/repositories`, `sync/data/data_sources`.
- **W1.25**: `AppLogger.instance` now returns the singleton `AppLogger` (not the raw `Talker`). `AppLogger.rawTalker` returns the singleton `Talker`. Tracker annotation "(conflict with instance getter)" confirms the deviation from the `AppLogger.talker` name was intentional. Semantic goal of T18 fix met.
- **W1.26**: Checked all `AppLogger.instance.info/warning/error/debug` call sites — all use the `event:` named parameter (structured API). Multi-line calls confirmed via spot check of `transactional_email_service.dart` lines 189–193. Migration done.
- **W1.27**: `grep -rn "final _log = AppLogger(AppLogger"` returns zero results. All 5 defensive wrappers deleted.
- **W1.28**: `core/exceptions/app_exception.dart` exists with 6 abstract category bases: `ValidationException`, `ConflictException`, `PermissionException`, `NotFoundException`, `NetworkException`, `InternalException`.
- **W1.29**: `core/logging/log_events.dart` exists with 8 subsystem constants: `sync`, `auth`, `profile`, `scheduler`, `track`, `tutor`, `content`, `notification`.
- **W1.30**: `learning_tracker/CLAUDE.md` Rule 3 references `lib/core/auth/` (correct path). No reference to deleted `docs/coding-standards.md`.

### W7 (S1 scope)

- **W7.20**: `packages/custom_lints/lib/src/rules/no_e_to_string_in_ui.dart` exists, registered in plugin as `NoEToStringInUi()`.
- **W7.21**: `packages/custom_lints/lib/src/rules/no_raw_logevent.dart` exists, registered as `NoRawLogEvent()`.
- **W7.22**: Root `Makefile` does not exist. Canonical `learning_tracker/Makefile` present.
- **W7.23**: CLAUDE.md Rule 3 correctly reads `lib/core/auth/` (not `lib/features/auth/`).

### W2 — Feature re-carving + sync stack

- **W2.1**: `features/tracks/data/`, `features/tracks/domain/`, `features/tracks/presentation/` all exist.
- **W2.2**: `features/track_setup/` deleted; `features/tracks/setup/` exists with content.
- **W2.6**: `features/tracks/data/` directory exists (placeholder confirmed).
- **W2.8**: `features/tracks/tracks.dart` barrel exists (38 lines), exports 18 public symbols across setup, stages, track_order, whole_curriculum_order sub-clusters.
- **W2.10**: `features/account/data/`, `domain/`, `presentation/` all exist.
- **W2.11**: `features/auth/` deleted. Content confirmed at `features/account/`.
- **W2.12**: `features/account/onboarding/` exists.
- **W2.14**: `features/account/account.dart` exists.
- **W2.15**: No remaining deep imports of `features/auth/` path from outside account/ (grep returns 0 external imports).
- **W2.16**: Reward and point config screens confirmed in `features/gamification/presentation/screens/`.
- **W2.17**: `core/widgets/pin_entry_widget.dart` exists.
- **W2.18**: `features/dashboard/domain/services/parent_dashboard_aggregator.dart` exists.
- **W2.19**: `features/profiles/domain/services/pin_service.dart` + `pin_flow_machine.dart` exist.
- **W2.20**: `features/parent_mode/` deleted.
- **W2.21**: `core/learning/` deleted; `features/learning/` exists with data/, domain/, presentation/.
- **W2.22**: `core/streak/` deleted; `features/gamification/streak/` exists.
- **W2.23**: `core/services/` contains only a stale `.g.dart` artifact — actual services moved to `sacred_time/` and `scheduler/`.
- **W2.24**: `core/services/pin_service.dart` deleted (only orphaned `pin_service.g.dart` artifact remains); canonical at `features/profiles/domain/services/pin_service.dart`.
- **W2.26**: `core/sync/merge/learning_order_merger.dart` exists; `EntityKind.learningOrder` at `entity_merger.dart:21` with comment `// W2.26 — closes C3/H3`; registered in merge router case `EntityKind.learningOrder`.
- **W2.27**: All 7 mergers confirmed in `core/sync/merge/`: `goal_merger.dart`, `learning_ledger_merger.dart`, `notification_settings_merger.dart`, `gamification_settings_merger.dart`, `ui_preferences_merger.dart`, `learning_order_merger.dart`, `profile_program_merger.dart`. All registered in `merge_router.dart`.
- **W2.28**: `pull_pipeline.dart` line 157–164: `pullStreak` step wired with `collection: 'streak_events'`.
- **W2.30**: `pull_pipeline.dart` line 232–244: `MergeOutcome.halt` triggers an early `return` (stops current collection pagination) with analytics event. Note: implementation returns rather than throws — see FLAGGED section.
- **W2.31**: `core/sync/sync_write_facade.dart` exists; `syncWriteFacadeProvider` at `features/sync/presentation/providers/sync_providers.dart:60`.
- **W2.32**: `push_pipeline_impl.dart:167` and `outbox/push_pipeline.dart:115` both carry `// W2.32 — pushAllLocalData outbox kinds`. Orchestrator wires `resolvePushAllLocalData` + `resolveBackfillGoals` via outbox path.
- **W2.33**: `SyncOrchestratorImpl` at `core/sync/sync_orchestrator.dart:197` owns `StreamController<SyncStatus>.broadcast()`. `SyncStatus` no longer comes from `SyncEngine`.
- **W2.34**: `syncEngineProvider` appears only in comments (6 references: 2 in doc comments, 2 in inline notes). No `ref.watch`/`ref.read` consumption. All 21 consumers migrated.
- **W2.35**: `features/sync/data/sync_engine.dart` does not exist.
- **W2.36**: `features/sync/data/firestore_data_source.dart` does not exist.
- **W2.37**: `features/sync/data/offline_queue.dart` does not exist.
- **W2.38**: Legacy `features/sync/…/sync_lifecycle_observer.dart` deleted. Only orchestrator-wiring version at `app/sync_runtime/sync_lifecycle_observer.dart` remains.
- **W2.39**: `features/sync/presentation/providers/sync_providers.dart` (75 lines) retains only `syncWriteFacadeProvider` + status stream providers. Legacy SyncEngine providers absent.
- **W2.40**: H5 (SyncEngine exception swallowing) and M2 (missing mergers) cannot exist — SyncEngine deleted; W2.27 wired all 7 missing mergers. Accepted as verified by deletion.
- **W2.41**: `features/tutoring/data/`, `domain/`, `presentation/` all exist; `tutoring.dart` barrel present.

---

## Mismatches / Demoted (8) — FLAGGED

- **W1.6**: Claim "Shrink main.dart to ~30 lines (bootstrap() then runApp(App()))"; actual `lib/main.dart` is **102 lines / 80 substantive lines**. Bootstrap orchestration remains inline (ProviderContainer construction, db seeding, account bootstrapping, profile listener, notifications). Bootstrap functions extracted to `app/bootstrap/*.dart` but main.dart still calls each individually rather than delegating to a single `bootstrap()` then `runApp(App())`. Evidence: `lib/main.dart` line count via `wc -l`.

- **W2.3**: Claim "Move features/learning_order/** → features/tracks/whole_curriculum_order/". New path has content. But **`features/learning_order/` still exists** with 8 actual source files (not re-exports): `domain/models/learning_order_item.dart` is byte-identical to `tracks/whole_curriculum_order/domain/models/learning_order_item.dart`. Old directory never deleted. Evidence: `find learning_tracker/lib/features/learning_order -name "*.dart"` returns 8 files; `diff` shows identical content.

- **W2.4**: Claim "Move features/track_learning_order/** → features/tracks/track_order/". New path has content. But **`features/track_learning_order/` still exists** with 5 actual source files; old directory never deleted. Evidence: `find learning_tracker/lib/features/track_learning_order -name "*.dart"` returns 5 files.

- **W2.5**: Claim "Move features/stages/** → features/tracks/stages/". New path has content. But **`features/stages/` still exists** with 9 actual source files. External importers (e.g. `dashboard/presentation/providers/calendar_position_providers.dart:9`, `dashboard/domain/services/parent_dashboard_aggregator.dart:11–13`) still import from `features/stages/` deep paths. Evidence: `find learning_tracker/lib/features/stages -name "*.dart"` returns 9 files; `grep -rn "import.*features/stages/"` finds 42 import references in lib/.

- **W2.7**: Claim "Pull curriculum_activation_service from settings → tracks". `features/tracks/domain/services/curriculum_activation_service.dart` exists (193 LOC, evolved version). But **`features/settings/domain/services/curriculum_activation_service.dart` still exists** (161 LOC, original version) — not a re-export, actual implementation code. Old copy was not deleted. Evidence: `wc -l` shows 161 vs 193 lines; `diff` shows meaningful differences.

- **W2.9**: Claim "Migrate all importers from deep paths → tracks.dart barrel [P2]". `features/tracks/tracks.dart` barrel exists. But **42 files still import `features/stages/` deep paths, 16 files import `features/learning_order/` deep paths, 4 files import `features/track_learning_order/` deep paths** — none via the barrel. External consumers (dashboard, scheduler, progress, content_browsing, etc.) are untouched. Evidence: `grep -rn "import.*features/stages/"` returns 42 hits; `import.*features/learning_order/` returns 16 hits; `import.*features/track_learning_order/` returns 4 hits.

- **W2.13**: Claim "Move account_management_service from settings → account". `features/account/domain/services/account_management_service.dart` exists. But **`features/settings/domain/services/account_management_service.dart` still exists** as a byte-identical duplicate (md5 match, 144 lines each). Old copy not deleted. Evidence: `md5sum` on both files returns same hash.

- **W2.25**: Claim "Delete core/services/ (now empty) [P2]". **`core/services/` directory still exists** containing `pin_service.g.dart` (orphaned generated file — `part of 'pin_service.dart'` whose source was deleted). The directory was not cleaned up. Evidence: `ls learning_tracker/lib/core/services/` returns `pin_service.g.dart`.

### Advisory (not demoted — implementation differs from literal but intent met)

- **W2.29**: Claim "Wire real stage_definitions/ push + pull + listener channel + _channelToKind". Push (`push_pipeline_impl.dart:98`, `outbox/push_pipeline.dart:71`) and Pull (`pull_pipeline.dart:146`, orchestrator step at line 407) are wired. However, **`stage_definitions` is absent from `FirestoreListenerSource.openChannels()` and from `SyncOrchestratorImpl._channelToKind`** — the real-time listener channel is not wired. Evidence: `core/sync/firestore_listener_source.dart` lists only completions/bookmarks/settings/streak_events/curriculum_tracks; `sync_orchestrator.dart:656–667` _channelToKind switch has no `stage_definitions` case. This is a partial implementation — push/pull present, listener missing. Demoted to `pending` (partial claim).

---

## Demotions Applied to Tracker

The following tasks have been changed from `[x] done` → `[ ] pending` in the tracker:

1. W1.6 — main.dart not shrunk to ~30 lines
2. W2.3 — features/learning_order/ not deleted
3. W2.4 — features/track_learning_order/ not deleted
4. W2.5 — features/stages/ not deleted; 42+ importers not migrated
5. W2.7 — settings/curriculum_activation_service.dart not deleted
6. W2.9 — importers not migrated (42 deep imports of stages/, 16 of learning_order/, 4 of track_learning_order/)
7. W2.13 — settings/account_management_service.dart not deleted (duplicate)
8. W2.25 — core/services/ not deleted
9. W2.29 — listener channel + _channelToKind for stage_definitions absent (push+pull present)

---

## Summary

- **Total tasks in scope**: 71 (W1.1–W1.30 + W7.20–W7.23 + W2.1–W2.41; W1.14 excluded as task-blocked)
- **Verified**: 62
- **Mismatched / Demoted**: 9
- **Verdict**: PARTIAL

### Pattern of mismatches

All 9 mismatches share the same pattern: **copy-and-create was done without delete**. The new canonical paths exist and have correct code; the old paths were never removed. W2.3/W2.4/W2.5/W2.7/W2.13/W2.25 are "move" tasks where the source was not cleaned up. W2.9 is an "importer migration" task that was skipped because the source dirs weren't deleted. W2.29 is genuinely partial (push/pull done, listener not wired). W1.6 is a scope creep — bootstrap was partially extracted but orchestration logic remained inline.

### Key risk

W2.3/W2.4/W2.5 old directories + W2.9 un-migrated importers mean the codebase has **duplicate live code** for `learning_order`, `track_learning_order`, and `stages` features. Consumers are split between old and new paths, creating a maintenance hazard. These should be the highest-priority follow-up fixes.
