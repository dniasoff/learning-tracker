# Standards Audit 2026-07-03 — Coverage Ledger

Every git-tracked file (4,431) landed in exactly one row. Tiers per the orchestrator prompt Part C:
Tier 1 = app/test Dart (full per-file audit) · Tier 2 = config/CI/tooling (full read, correctness/security/drift) ·
Tier 3 = generated (regenerate-and-diff check, not line-audited) · Tier 4 = docs (factual drift / point-in-time triage) ·
X = excluded with reason.

**Verdict totals:** EXCLUDED: 2288, ISSUES: 957, SOUND: 783, POINT-IN-TIME: 166, DEFECTIVE: 157, REGEN-CHECKED: 80

Verdicts: SOUND = read fully, cleared (note says what was checked) · ISSUES = findings filed (see register) ·
DEFECTIVE = serious defects filed · POINT-IN-TIME = historical doc, exempt from drift audit ·
REGEN-CHECKED = covered by the Tier-3 regeneration diff (3 stale files found, finding AG-7) · EXCLUDED = reason in table.

## Tier 1 — Application & test code (1640 files)

| File | Verdict | Batch | Note |
|---|---|---|---|
| `learning_tracker/lib/app/bootstrap/.gitkeep` | SOUND | t1-app-l10n | Empty placeholder; keeps empty bootstrap/ directory tracked in git. |
| `learning_tracker/lib/app/bootstrap/account_bootstrap.dart` | ISSUES | t1-app-l10n | registry.close() skipped on exception path (leak); zero test coverage. |
| `learning_tracker/lib/app/bootstrap/analytics_bootstrap.dart` | ISSUES | t1-app-l10n | Correct kDebugMode branch verified; zero test coverage anywhere in test/. |
| `learning_tracker/lib/app/bootstrap/bootstrap.dart` | ISSUES | t1-app-l10n | Orchestration verified correct (retry, observers, PV-2 int? id); zero tests. |
| `learning_tracker/lib/app/bootstrap/crashlytics_bootstrap.dart` | ISSUES | t1-app-l10n | Correctly wires EH-1's both handlers; zero test coverage for this path. |
| `learning_tracker/lib/app/bootstrap/firebase_bootstrap.dart` | ISSUES | t1-app-l10n | 2 log-less catches (EH-3); PV-3/PV-6 verified baselined/compliant; no tests. |
| `learning_tracker/lib/app/bootstrap/logger_bootstrap.dart` | SOUND | t1-app-l10n | 1-line AppLogger.init() delegation; too trivial to need a dedicated test. |
| `learning_tracker/lib/app/bootstrap/notifications_bootstrap.dart` | ISSUES | t1-app-l10n | Error handling correct (EH-3); imports stale core/navigation shim; no tests. |
| `learning_tracker/lib/app/bootstrap/seed_bootstrap.dart` | ISSUES | t1-app-l10n | Logs+rethrows correctly (EH-3 compliant); zero test coverage for this wrapper. |
| `learning_tracker/lib/app/learning_tracker_app.dart` | ISSUES | t1-app-l10n | Imports stale core/navigation/router_provider.dart shim instead of canonical app/ path. |
| `learning_tracker/lib/app/restore/.gitkeep` | SOUND | t1-app-l10n | Empty placeholder; keeps empty restore/ directory tracked in git. |
| `learning_tracker/lib/app/restore/device_restore_screen.dart` | ISSUES | t1-app-l10n | Renders raw e.toString() untranslated (EH-5/AX-2); imports stale shim paths. |
| `learning_tracker/lib/app/restore/device_restore_service.dart` | ISSUES | t1-app-l10n | RestoreStatus.error carries free-text message shown to user unlocalized. |
| `learning_tracker/lib/app/restore/restore_providers.dart` | SOUND | t1-app-l10n | Checked SM-3/6/7 wiring, disposal, provider style vs. codebase norm; clean. |
| `learning_tracker/lib/app/router/.gitkeep` | SOUND | t1-app-l10n | Empty placeholder; keeps empty router/ directory tracked in git. |
| `learning_tracker/lib/app/router/app_router.dart` | SOUND | t1-app-l10n | Route/guard table correct; is the stale shim's real, un-imported target. |
| `learning_tracker/lib/app/router/app_shell.dart` | ISSUES | t1-app-l10n | 834 lines (AG-3 x2); 8 scattered color literals; 3 fixed-height AX-4 defects. |
| `learning_tracker/lib/app/router/guards/auth_guard.dart` | SOUND | t1-app-l10n | Fail-safe catch logs correctly (EH-3); is a stale shim's real target. |
| `learning_tracker/lib/app/router/persistent_switcher_scaffold.dart` | ISSUES | t1-app-l10n | Duplicates app_shell.dart's 0xFFF1F3FA literal instead of a shared constant. |
| `learning_tracker/lib/app/router/router_provider.dart` | SOUND | t1-app-l10n | Guard wiring correct; canonical file 60+ callers should import directly. |
| `learning_tracker/lib/app/sync_runtime/.gitkeep` | SOUND | t1-app-l10n | Empty placeholder; keeps empty sync_runtime/ directory tracked in git. |
| `learning_tracker/lib/app/sync_runtime/sync_lifecycle_observer.dart` | SOUND | t1-app-l10n | Minimal keep-alive watch wrapper; matches established effect-provider idiom, correct. |
| `learning_tracker/lib/core/analytics/analytics_provider.dart` | SOUND | t1-core-analytics-logging | Correct kDebugMode DI wiring; no defect; feeds the logEvent sink used elsewhere. |
| `learning_tracker/lib/core/analytics/analytics_service.dart` | DEFECTIVE | t1-core-analytics-logging | Baselined PV-1 (56/82/87) plus root cause: unconstrained logEvent(String) enables catalog bypass. |
| `learning_tracker/lib/core/analytics/firebase_analytics_service.dart` | SOUND | t1-core-analytics-logging | Pure pass-through to Firebase SDK; no param filtering, but not this layer's job. |
| `learning_tracker/lib/core/analytics/parent_analytics_repository.dart` | SOUND | t1-core-analytics-logging | Checked SM-7/8, EH; pure DAO delegation, no cross-repo import, unrelated to Firebase Analytics. |
| `learning_tracker/lib/core/analytics/streak_milestone_analytics_observer.dart` | ISSUES | t1-core-analytics-logging | Bare Object catches (EH-4) x2; hardcoded clock; doc says 'Keeps alive' but is autoDispose. |
| `learning_tracker/lib/core/auth/auth_gateway_user.dart` | SOUND | t1-core-auth | Immutable DTO, no Firebase leakage, no hand-rolled equality; naming and boundary clean. |
| `learning_tracker/lib/core/auth/auth_providers.dart` | ISSUES | t1-core-auth | SM-7 construction correct; both keepAlive providers lack tagged justification comment (SM-6). |
| `learning_tracker/lib/core/auth/firebase_auth_gateway.dart` | SOUND | t1-core-auth | Pure interface, plain-Dart types only; Rule-3 boundary doc-claim verified accurate via grep. |
| `learning_tracker/lib/core/auth/firebase_auth_gateway_impl.dart` | DEFECTIVE | t1-core-auth | Silent no-op on null currentUser (P1, AU-1); hardcoded English errors; duplication; force-unwrap. |
| `learning_tracker/lib/core/auth/google_sign_in_gateway.dart` | SOUND | t1-core-auth | Pure interface; exception-leak doc-claim verified against 4 real importers, accurate. |
| `learning_tracker/lib/core/auth/google_sign_in_gateway_impl.dart` | ISSUES | t1-core-auth | Logic reads correct; zero test coverage anywhere in repo (P2 finding filed). |
| `learning_tracker/lib/core/constants/.gitkeep` | ISSUES | t1-core-small-a | Stray gitkeep in non-empty dir; core/constants/ has 3 real files |
| `learning_tracker/lib/core/constants/app_constants.dart` | SOUND | t1-core-small-a | Trivial 2-constant class, private ctor; no violations |
| `learning_tracker/lib/core/constants/curriculum_defaults.dart` | ISSUES | t1-core-small-a | 1270 lines (AG-3); rendering engine misplaced outside core/labels/ |
| `learning_tracker/lib/core/constants/hebrew_terms.dart` | ISSUES | t1-core-small-a | getCurriculumDisplayName dead + Rule-5 displayNameHe access outside core/labels/ |
| `learning_tracker/lib/core/content/content_grouping.dart` | ISSUES | t1-core-content | Dead/buggy maxBrowseDepth clamp regresses fixed bug R5-6; duplicate accessors; most exports untested. |
| `learning_tracker/lib/core/content/content_index.dart` | ISSUES | t1-core-content | AdjacentItems isn't @freezed/has no equality; baselined core→features import not reported. |
| `learning_tracker/lib/core/content/content_tree.dart` | DEFECTIVE | t1-core-content | parent() off-by-one confirmed via repro test; redundant O(9x) child-list sort in fromCurricula. |
| `learning_tracker/lib/core/content/hierarchy_browser.dart` | ISSUES | t1-core-content | Hardcoded English empty-state string; dead currentPath/canGoBack getters; zero direct tests. |
| `learning_tracker/lib/core/content/hierarchy_selection.dart` | ISSUES | t1-core-content | Hand-rolled ==/hashCode instead of @freezed; its test sits at the pre-move path. |
| `learning_tracker/lib/core/content/program_ref_resolver.dart` | ISSUES | t1-core-content | Doc claims production wiring/DNI-330 integration that doesn't exist; zero real callers. |
| `learning_tracker/lib/core/database/base_dao.dart` | SOUND | t1-core-database-root | Generic getById/getByProfile/count/exists mixin; read-only, correct Drift usage. |
| `learning_tracker/lib/core/database/content/content_database.dart` | ISSUES | t1-core-database-root | 4 migration catches are untyped and log-less (EH-3/EH-4 pending). |
| `learning_tracker/lib/core/database/content/daos/calendar_cycle_dao.dart` | ISSUES | t1-core-database-root | 3 'legacy' delegate methods have zero production callers (dead code). |
| `learning_tracker/lib/core/database/content/daos/daily_content_dao.dart` | SOUND | t1-core-database-root | Trivial 2-query read-only DAO, checked against schema, no issues. |
| `learning_tracker/lib/core/database/content/daos/seed_metadata_dao.dart` | SOUND | t1-core-database-root | Single-method read-only DAO, no issues. |
| `learning_tracker/lib/core/database/content/daos/text_cache_dao.dart` | SOUND | t1-core-database-root | 4 read-only queries checked, correct Drift where/like usage. |
| `learning_tracker/lib/core/database/content_db_health_checker.dart` | SOUND | t1-core-database-root | Typed SqliteException catches + AppLogger throughout; model for finding 5. |
| `learning_tracker/lib/core/database/content_result.dart` | ISSUES | t1-core-database-root | Sealed Result type has zero production call sites (dead/speculative). |
| `learning_tracker/lib/core/database/daos/.gitkeep` | SOUND | t1-core-database-daos | Empty placeholder; dir has 24 real files now, harmless dead file. |
| `learning_tracker/lib/core/database/daos/active_curriculum_dao.dart` | ISSUES | t1-core-database-daos | Profile-scoped queries correct; EH-5 human-readable StateError (finding 7). |
| `learning_tracker/lib/core/database/daos/bookmark_dao.dart` | ISSUES | t1-core-database-daos | getBookmarkById/updateBookmark/deleteBookmark bypass profileId (finding 1). |
| `learning_tracker/lib/core/database/daos/completion_dao.dart` | ISSUES | t1-core-database-daos | 881 lines (AG-3, finding 5); cross-profile guard pattern otherwise exemplary. |
| `learning_tracker/lib/core/database/daos/completion_event_dao.dart` | SOUND | t1-core-database-daos | Append-only, INSERT OR IGNORE dedup, every query profileId-scoped. |
| `learning_tracker/lib/core/database/daos/curriculum_scope_dao.dart` | ISSUES | t1-core-database-daos | setScopes per-row awaited insert loop instead of batch() (finding 3). |
| `learning_tracker/lib/core/database/daos/daily_plan_dao.dart` | SOUND | t1-core-database-daos | insertEntries uses batch() correctly; all queries profileId/trackId-scoped. |
| `learning_tracker/lib/core/database/daos/goal_dao.dart` | ISSUES | t1-core-database-daos | getGoalById/updateGoal/deleteGoal bypass profileId — primary evidence, finding 1. |
| `learning_tracker/lib/core/database/daos/learning_ledger_dao.dart` | ISSUES | t1-core-database-daos | EH-5 human-readable StateError message (finding 7); dedup logic sound. |
| `learning_tracker/lib/core/database/daos/learning_order_dao.dart` | ISSUES | t1-core-database-daos | getLearningOrderById/updateLearningOrder/deleteLearningOrder bypass profileId (finding 1). |
| `learning_tracker/lib/core/database/daos/outbox_dao.dart` | SOUND | t1-core-database-daos | All queries profileId-scoped; documented transaction contract honored by checked callers. |
| `learning_tracker/lib/core/database/daos/point_config_dao.dart` | ISSUES | t1-core-database-daos | seedDefaults: no transaction + per-row loop, two ways (findings 2, 3). |
| `learning_tracker/lib/core/database/daos/points_balance_dao.dart` | ISSUES | t1-core-database-daos | 617 lines (AG-3, finding 5); transaction/outbox atomicity otherwise exemplary. |
| `learning_tracker/lib/core/database/daos/prior_completion_import_dao.dart` | SOUND | t1-core-database-daos | batchInsertImports uses batch(); deletes/queries all profileId-scoped. |
| `learning_tracker/lib/core/database/daos/profile_dao.dart` | SOUND | t1-core-database-daos | Bare-id lookups correct: this table IS profile identity, not data scoped by profileId. |
| `learning_tracker/lib/core/database/daos/profile_program_dao.dart` | SOUND | t1-core-database-daos | All mutations keyed by profileId+curriculumType; no bare-id CRUD exposed. |
| `learning_tracker/lib/core/database/daos/sacred_window_dao.dart` | ISSUES | t1-core-database-daos | clearAll()+insertAll() not atomic, only caller chains fire-and-forget (finding 4). |
| `learning_tracker/lib/core/database/daos/stage_dao.dart` | ISSUES | t1-core-database-daos | id-only get/update/delete bypass profileId (finding 1); replaceStagesFor* not batched (finding 3). |
| `learning_tracker/lib/core/database/daos/streak_event_dao.dart` | SOUND | t1-core-database-daos | 40-line append-only DAO, idempotent, profileId-scoped throughout. |
| `learning_tracker/lib/core/database/daos/study_day_config_dao.dart` | ISSUES | t1-core-database-daos | seedDefaults: no transaction + per-row loop (findings 2,3); throw message (finding 7). |
| `learning_tracker/lib/core/database/daos/sync_kv_dao.dart` | SOUND | t1-core-database-daos | kind+entityKey is the correct natural composite PK for this sync-bookkeeping table. |
| `learning_tracker/lib/core/database/daos/text_download_status_dao.dart` | SOUND | t1-core-database-daos | Content-cache table keyed by curriculumId only — correctly exempt from profileId-in-PK. |
| `learning_tracker/lib/core/database/daos/track_dao.dart` | ISSUES | t1-core-database-daos | 546 lines (AG-3); purgeHistory loop not batched (finding 3); stringly-typed TrackState (finding 8). |
| `learning_tracker/lib/core/database/daos/track_learning_order_dao.dart` | ISSUES | t1-core-database-daos | upsertOrder: no transaction + per-row loop, real multi-item caller (findings 2,3). |
| `learning_tracker/lib/core/database/daos/user_profile_dao.dart` | ISSUES | t1-core-database-daos | accountTier catches an Error subtype (finding 6); fromDb throws human message (finding 7). |
| `learning_tracker/lib/core/database/registry/device_registry_database.dart` | DEFECTIVE | t1-core-database-root | removeAccount/dedupeByEmail multi-write with no transaction() (DB-2). |
| `learning_tracker/lib/core/database/registry/tables/device_accounts.dart` | SOUND | t1-core-database-root | Device-scoped table, accountId PK; profileId-in-PK N/A (not profile data). |
| `learning_tracker/lib/core/database/registry/tables/device_state.dart` | SOUND | t1-core-database-root | Trivial key-value table, key PK, no issues. |
| `learning_tracker/lib/core/database/seed/learning_program_seeds.dart` | SOUND | t1-core-database-root | Pure static seed data, checked field shape/consistency, no logic. |
| `learning_tracker/lib/core/database/seed_manager.dart` | ISSUES | t1-core-database-root | _rollback's catch is log-less, unlike every other catch in this file. |
| `learning_tracker/lib/core/database/seed_version.dart` | SOUND | t1-core-database-root | Single documented constant with clear history comment, no issues. |
| `learning_tracker/lib/core/database/tables/.gitkeep` | ISSUES | t1-core-database-tables | vestigial placeholder; directory holds 27 real table files (P3) |
| `learning_tracker/lib/core/database/tables/accounts.dart` | SOUND | t1-core-database-tables | root account entity; profileId-in-PK N/A (no profileId column, by design) |
| `learning_tracker/lib/core/database/tables/bookmarks.dart` | SOUND | t1-core-database-tables | profileId FK+cascade present; uniqueKeys satisfies schema_check (tool-verified) |
| `learning_tracker/lib/core/database/tables/calendar_cycles.dart` | SOUND | t1-core-database-tables | shared content table (programKey+dateKey PK); no profile scoping needed |
| `learning_tracker/lib/core/database/tables/completion_events.dart` | ISSUES | t1-core-database-tables | docstring natural key omits curriculumId that the real unique index enforces |
| `learning_tracker/lib/core/database/tables/curriculum_scopes.dart` | SOUND | t1-core-database-tables | profileId FK+cascade present; uniqueKeys satisfies schema_check |
| `learning_tracker/lib/core/database/tables/curriculum_tracks.dart` | DEFECTIVE | t1-core-database-tables | profileId has no FK/cascade to learner_profiles; orphans tutored-mirror data |
| `learning_tracker/lib/core/database/tables/daily_content.dart` | SOUND | t1-core-database-tables | shared seed-build content keyed by sefariaRef; not profile data |
| `learning_tracker/lib/core/database/tables/daily_plans.dart` | DEFECTIVE | t1-core-database-tables | profileId has no FK/cascade; same orphan-on-mirror-wipe defect as curriculum_tracks |
| `learning_tracker/lib/core/database/tables/goals.dart` | ISSUES | t1-core-database-tables | no composite key/index at all; unprotected by schema_check (tool-verified) |
| `learning_tracker/lib/core/database/tables/learner_profiles.dart` | SOUND | t1-core-database-tables | is the profile entity itself; accountId FK+cascade correct; exempt from rule |
| `learning_tracker/lib/core/database/tables/learning_ledger.dart` | SOUND | t1-core-database-tables | FK+cascade present; unique(profileId,ulid) index is the correct dedup pattern |
| `learning_tracker/lib/core/database/tables/learning_order.dart` | SOUND | t1-core-database-tables | FK+cascade present; uniqueKeys satisfies schema_check |
| `learning_tracker/lib/core/database/tables/monthly_activity_rollups.dart` | SOUND | t1-core-database-tables | primaryKey={profileId,yearMonth}; fully compliant, tool-verified even unwhitelisted |
| `learning_tracker/lib/core/database/tables/outbox_table.dart` | DEFECTIVE | t1-core-database-tables | profileId has no FK/cascade (orphan risk); filename/class mismatch (Outbox) |
| `learning_tracker/lib/core/database/tables/point_configs.dart` | DEFECTIVE | t1-core-database-tables | profileId has no FK/cascade to learner_profiles; orphan-on-mirror-wipe defect |
| `learning_tracker/lib/core/database/tables/points_balance.dart` | DEFECTIVE | t1-core-database-tables | PointsLedger/RewardRedemptions lack unique(profileId,ulid); dedup race risk |
| `learning_tracker/lib/core/database/tables/prior_completion_imports.dart` | ISSUES | t1-core-database-tables | no composite key/index at all; documented natural key unenforced |
| `learning_tracker/lib/core/database/tables/profile_programs.dart` | DEFECTIVE | t1-core-database-tables | profileId has no FK/cascade to learner_profiles; orphan-on-mirror-wipe defect |
| `learning_tracker/lib/core/database/tables/sacred_window_entries.dart` | SOUND | t1-core-database-tables | device/location-derived data, not profile-scoped; exempt by design |
| `learning_tracker/lib/core/database/tables/seed_metadata.dart` | SOUND | t1-core-database-tables | single-row build-metadata table; not user data |
| `learning_tracker/lib/core/database/tables/stage_definitions.dart` | SOUND | t1-core-database-tables | FK+cascade present; uniqueKeys satisfies schema_check |
| `learning_tracker/lib/core/database/tables/streak_events.dart` | SOUND | t1-core-database-tables | FK+cascade; unique TableIndex; docstring matches index columns exactly |
| `learning_tracker/lib/core/database/tables/study_day_configs.dart` | DEFECTIVE | t1-core-database-tables | primaryKey includes profileId, but profileId itself still lacks FK/cascade |
| `learning_tracker/lib/core/database/tables/sync_kv.dart` | SOUND | t1-core-database-tables | profileId deliberately prefixed into entityKey string; verified in DriftMergeStore |
| `learning_tracker/lib/core/database/tables/text_cache.dart` | SOUND | t1-core-database-tables | shared cached Sefaria text; not profile data |
| `learning_tracker/lib/core/database/tables/text_download_status.dart` | ISSUES | t1-core-database-tables | class TextDownloadStatuses vs filename singular 'status' — naming mismatch |
| `learning_tracker/lib/core/database/tables/track_learning_order.dart` | SOUND | t1-core-database-tables | no profileId by design (schema_check exempts it); track-deletion cleanup verified |
| `learning_tracker/lib/core/database/track_scope.dart` | SOUND | t1-core-database-root | Trivial immutable freezed value object, no issues. |
| `learning_tracker/lib/core/database/user/user_database.dart` | DEFECTIVE | t1-core-database-root | HOTSPOT: onUpgrade has no path for schemaVersion <25, no floor guard. |
| `learning_tracker/lib/core/database/views/completions_view.dart` | SOUND | t1-core-database-root | Documented drift_dev workaround; view SQL matches migration's copy. |
| `learning_tracker/lib/core/domain/value_objects/account_tier.dart` | ISSUES | t1-core-domain-learning | storageKey/fromStorageKey correct; 4 call sites bypass it with raw 'cloudBorn' literal. |
| `learning_tracker/lib/core/domain/value_objects/calendar_system.dart` | ISSUES | t1-core-domain-learning | Correct, fully tested, but zero production callers anywhere in lib/. |
| `learning_tracker/lib/core/domain/value_objects/pin.dart` | ISSUES | t1-core-domain-learning | Correct, well-tested; zero callers — PIN regex hand-duplicated elsewhere instead. |
| `learning_tracker/lib/core/domain/value_objects/profile_mode.dart` | ISSUES | t1-core-domain-learning | Heavily/correctly adopted; one caller reimplements fromStorageKey's mapping. |
| `learning_tracker/lib/core/domain/value_objects/program_starting_position.dart` | ISSUES | t1-core-domain-learning | B2/B3 window logic correct; hand-written equality, raw-message exception, untested method. |
| `learning_tracker/lib/core/domain/value_objects/schedule_spec.dart` | DEFECTIVE | t1-core-domain-learning | Weekly/Rolling invariants use assert() (no-op in release); sealed getters use `_` arms; no test file exists. |
| `learning_tracker/lib/core/domain/value_objects/scope.dart` | ISSUES | t1-core-domain-learning | Correct, tested; ScopeLevel/ScopeValue/CurriculumScope have zero production callers. |
| `learning_tracker/lib/core/domain/value_objects/sefaria_ref.dart` | ISSUES | t1-core-domain-learning | value/parse live (2 callers); titlePart/addressPart contradict own docstring, unused. |
| `learning_tracker/lib/core/domain/value_objects/stage_order.dart` | ISSUES | t1-core-domain-learning | Correct, well-tested; zero production callers found anywhere in lib/. |
| `learning_tracker/lib/core/domain/value_objects/study_day_pattern.dart` | ISSUES | t1-core-domain-learning | Live, correctly used by scheduler projection; only hand-written equality/hash. |
| `learning_tracker/lib/core/email/transactional_email_service.dart` | ISSUES | t1-core-services | Unredacted body-field PII log (P0); EN-only email strings (P3). |
| `learning_tracker/lib/core/enums/cross_profile_scope.dart` | SOUND | t1-core-small-a | Documented Phase-0 band-aid enum, correctly scoped, DNI-321 tracked |
| `learning_tracker/lib/core/enums/curriculum_id.dart` | SOUND | t1-core-small-a | displayName getters correctly declared; exhaustive switches, values verified |
| `learning_tracker/lib/core/enums/curriculum_overlap_registry.dart` | SOUND | t1-core-small-a | Verified subsetsOf() logic against doc-commented examples; correct |
| `learning_tracker/lib/core/exceptions/app_exception.dart` | SOUND | t1-core-small-a | Clean 6-category hierarchy; no Error-catching, no cycles |
| `learning_tracker/lib/core/exceptions/duplicate_completion_exception.dart` | ISSUES | t1-core-small-a | Dead: zero production callers repo-wide; raw English userMessage |
| `learning_tracker/lib/core/exceptions/invalid_track_operation_exception.dart` | ISSUES | t1-core-small-a | Dead: never thrown; track_repository.dart only re-exports type |
| `learning_tracker/lib/core/exceptions/permission_exception.dart` | SOUND | t1-core-small-a | TutorWriteForbiddenException alive, single catch doesn't leak message |
| `learning_tracker/lib/core/exceptions/validation_exception.dart` | SOUND | t1-core-small-a | Backward-compat re-export shim; verified still has real importers |
| `learning_tracker/lib/core/ids/ids.dart` | SOUND | t1-core-small-a | 6 typed-ID extension types; verified 15 real call sites |
| `learning_tracker/lib/core/ids/natural_key.dart` | ISSUES | t1-core-small-a | 6/7 factories unused, duplicated inline in mergers; 1 buggy branch |
| `learning_tracker/lib/core/labels/curriculum_label.dart` | DEFECTIVE | t1-core-labels | 451 lines (AG-3); breadcrumb/parent modes leak raw English ancestor names in Hebrew mode. |
| `learning_tracker/lib/core/labels/curriculum_label_providers.dart` | ISSUES | t1-core-labels | Correct ancestor Hebrew-name resolution; duplicate CurriculumId lookup; no dedicated test file (AG-5). |
| `learning_tracker/lib/core/labels/curriculum_label_renderer.dart` | DEFECTIVE | t1-core-labels | renderForItem/renderParentForItem only resolve leaf Hebrew name, not ancestors; duplicate CurriculumId lookup. |
| `learning_tracker/lib/core/labels/curriculum_level_name.dart` | ISSUES | t1-core-labels | Verified toggle/variant wiring correct; no dedicated test file (AG-5 gap). |
| `learning_tracker/lib/core/labels/curriculum_visuals.dart` | ISSUES | t1-core-labels | Exhaustive 9-curriculum icon switch verified; no dedicated test file (AG-5 gap). |
| `learning_tracker/lib/core/labels/domain_term_labels.dart` | ISSUES | t1-core-labels | 435 lines (AG-3); logic verified via IL-2/IL-5/PP-5 tests; one unhoisted RegExp. |
| `learning_tracker/lib/core/learning/completion_constants.dart` | DEFECTIVE | t1-core-domain-learning | kBulkPriorSentinelMs never imported anywhere; 3 features hand-duplicate the literal. |
| `learning_tracker/lib/core/logging/.gitkeep` | SOUND | t1-core-analytics-logging | Empty placeholder file; nothing to audit. |
| `learning_tracker/lib/core/logging/crashlytics_service.dart` | ISSUES | t1-core-analytics-logging | Fire-and-forget analytics call unguarded; can re-enter the runZonedGuarded handler on rejection. |
| `learning_tracker/lib/core/logging/log_events.dart` | ISSUES | t1-core-analytics-logging | Constants documented as log-only are reused elsewhere as an ungated analytics catalog. |
| `learning_tracker/lib/core/logging/logger.dart` | ISSUES | t1-core-analytics-logging | setupFlutterErrorHandlers is dead code duplicating real bootstrap wiring; false test confidence. |
| `learning_tracker/lib/core/navigation/app_router.dart` | ISSUES | t1-core-nav-utils | Re-export shim (W1.2): creates core→app import cycle with 3 guards (see finding). |
| `learning_tracker/lib/core/navigation/app_shell.dart` | ISSUES | t1-core-nav-utils | Re-export shim (W1.2): zero importers anywhere in repo — fully dead. |
| `learning_tracker/lib/core/navigation/guards/.gitkeep` | ISSUES | t1-core-nav-utils | 0-byte placeholder; dir holds 5 real files now — vestigial (see finding). |
| `learning_tracker/lib/core/navigation/guards/auth_guard.dart` | ISSUES | t1-core-nav-utils | Re-export shim (W1.2): 0 lib/ importers, only 3 stale test refs remain. |
| `learning_tracker/lib/core/navigation/guards/child_mode_guard.dart` | SOUND | t1-core-nav-utils | Read in full; fail-closed try/catch, tutor-mirror branch, DB CHECK-constraint claim verified true. |
| `learning_tracker/lib/core/navigation/guards/pin_guard.dart` | ISSUES | t1-core-nav-utils | Correct PIN-scope logic; imports app_router.dart shim — core→app cycle (see finding). |
| `learning_tracker/lib/core/navigation/guards/profile_guard.dart` | ISSUES | t1-core-nav-utils | Correct multi-profile logic; imports app_router.dart shim — core→app cycle (see finding). |
| `learning_tracker/lib/core/navigation/guards/restore_guard.dart` | ISSUES | t1-core-nav-utils | Imports app_router.dart shim; builds repository inline outside a provider (SM-7). |
| `learning_tracker/lib/core/navigation/pin_scope.dart` | SOUND | t1-core-nav-utils | Freezed sealed union, 2 variants, no logic — nothing to break. |
| `learning_tracker/lib/core/navigation/root_scaffold_messenger.dart` | SOUND | t1-core-nav-utils | Single documented GlobalKey declaration, no logic, no findings. |
| `learning_tracker/lib/core/navigation/router_provider.dart` | ISSUES | t1-core-nav-utils | Re-export shim (W1.2), still used by 8 files — not yet migrated. |
| `learning_tracker/lib/core/network/connectivity_gateway.dart` | ISSUES | t1-core-network | Timeout leaks DNS-lookup Future; no seam, forcing its test non-hermetic. |
| `learning_tracker/lib/core/network/sefaria/curriculum_content_fetcher.dart` | ISSUES | t1-core-network | Interface dead in shipped app (tool/-only caller); FetchResult/exception not @freezed. |
| `learning_tracker/lib/core/network/sefaria/models/content_item.dart` | ISSUES | t1-core-network | Hand-rolled equality covers 2/9 fields; stale content_items-table doc comment. |
| `learning_tracker/lib/core/network/sefaria/models/curriculum_hierarchy_config.dart` | ISSUES | t1-core-network | No @freezed/equality at all; mutable List field on a cached shared instance. |
| `learning_tracker/lib/core/preferences/hebrew_date_preference.dart` | ISSUES | t1-core-providers-prefs | defaultValue=true drifts from readUseHebrewCalendar's stale false default. |
| `learning_tracker/lib/core/preferences/hebrew_terms_preference.dart` | SOUND | t1-core-providers-prefs | Default matches readHebrewTermsScript (both true); EH/SM-7 clean. |
| `learning_tracker/lib/core/preferences/nikud_preference.dart` | SOUND | t1-core-providers-prefs | Default matches readShowNikud (both true); no drift, no side effects. |
| `learning_tracker/lib/core/preferences/preference_providers.dart` | DEFECTIVE | t1-core-providers-prefs | Sentinel-guard gap on 4 notifiers, bare keepAlive:true x8, unguarded post-await state. |
| `learning_tracker/lib/core/preferences/profile_scoped_preference.dart` | SOUND | t1-core-providers-prefs | Clean abstract base; observe/write/dispose contract checked, SM-7 compliant. |
| `learning_tracker/lib/core/preferences/profile_scoped_preference_keys.dart` | ISSUES | t1-core-providers-prefs | readUseHebrewCalendar's stale '?? false' default diverges from live pref. |
| `learning_tracker/lib/core/preferences/text_display_preference.dart` | SOUND | t1-core-providers-prefs | Delegates to readFontSizeIndex correctly; default matches FontSize.medium. |
| `learning_tracker/lib/core/preferences/text_display_preferences.dart` | ISSUES | t1-core-providers-prefs | Dead global singleton, zero lib/ references, bypasses per-profile scoping. |
| `learning_tracker/lib/core/preferences/transliteration_variant_preference.dart` | SOUND | t1-core-providers-prefs | Default matches readTransliterationVariant; correctly skips sync push. |
| `learning_tracker/lib/core/providers/calendar_providers.dart` | SOUND | t1-core-providers-prefs | Thin wiring; plain-FutureProvider style is baselined SM-1 backlog, not new. |
| `learning_tracker/lib/core/providers/crashlytics_provider.dart` | SOUND | t1-core-providers-prefs | Trivial DI provider; documented override pattern, no side effects. |
| `learning_tracker/lib/core/providers/database_provider.dart` | SOUND | t1-core-providers-prefs | SM-7/Rule-3 compliant; disposal wired; keepAlive sites carry prose reasons. |
| `learning_tracker/lib/core/providers/firebase_providers.dart` | SOUND | t1-core-providers-prefs | FirebaseStorage import matches Rule 3's explicit core/providers/ allowlist. |
| `learning_tracker/lib/core/providers/network_providers.dart` | SOUND | t1-core-providers-prefs | Trivial DI provider; SM-7 compliant, dispose wired defensively. |
| `learning_tracker/lib/core/providers/registry_provider.dart` | SOUND | t1-core-providers-prefs | SM-7 compliant; keepAlive justified in doc comment; disposal wired. |
| `learning_tracker/lib/core/providers/talker_provider.dart` | SOUND | t1-core-providers-prefs | Documented narrow raw-Talker escape hatch; both consumers re-wrap AppLogger. |
| `learning_tracker/lib/core/services/.gitkeep` | ISSUES | t1-core-services | Empty dir; docs still call it canonical post-relocation (see AG-5 finding). |
| `learning_tracker/lib/core/sync/codec/bookmark_codec.dart` | ISSUES | t1-core-sync-codec | Dual-key read fallback correct; comment describing live content_item_id writer is stale. |
| `learning_tracker/lib/core/sync/codec/completion_event_codec.dart` | SOUND | t1-core-sync-codec | Checked completed_at push against firestore.rules request.time rule; gateway patches type; encode correct. |
| `learning_tracker/lib/core/sync/codec/entity_codec.dart` | SOUND | t1-core-sync-codec | Pure abstract interface, zero logic; contract doc matches all 14 implementers. |
| `learning_tracker/lib/core/sync/codec/firestore_codec.dart` | ISSUES | t1-core-sync-codec | Parser logic itself correct but untested; encodeDateTime doc wrongly claims SDK auto-Timestamp. |
| `learning_tracker/lib/core/sync/codec/goal_codec.dart` | DEFECTIVE | t1-core-sync-codec | target_percent `as num?` cast throws on String input instead of returning null. |
| `learning_tracker/lib/core/sync/codec/learner_profile_codec.dart` | SOUND | t1-core-sync-codec | All fields via FirestoreCodec.parse*; encode/decode symmetric; learner_profiles rule has no hasOnly. |
| `learning_tracker/lib/core/sync/codec/learning_ledger_codec.dart` | DEFECTIVE | t1-core-sync-codec | encode() skips FirestoreCodec.encodeDateTime for completedAt; corrupts cross-timezone pulled timestamps. |
| `learning_tracker/lib/core/sync/codec/learning_order_codec.dart` | SOUND | t1-core-sync-codec | Checked against learning_order hasOnly() rule; encode() output is a compliant subset. |
| `learning_tracker/lib/core/sync/codec/profile_program_codec.dart` | SOUND | t1-core-sync-codec | Checked against profile_programs hasOnly() rule; all fields via FirestoreCodec.parse* helpers. |
| `learning_tracker/lib/core/sync/codec/settings_codec.dart` | ISSUES | t1-core-sync-codec | encode() has zero callers anywhere; zero test coverage; nested-stage decode unverified. |
| `learning_tracker/lib/core/sync/codec/stage_definition_codec.dart` | ISSUES | t1-core-sync-codec | Legacy days_of_week catch silently defaults to [] with no AppLogger call. |
| `learning_tracker/lib/core/sync/codec/streak_event_codec.dart` | SOUND | t1-core-sync-codec | Append-only, no LWW; matches streak_events rule (no request.time check); clean. |
| `learning_tracker/lib/core/sync/codec/study_day_config_codec.dart` | SOUND | t1-core-sync-codec | All fields via FirestoreCodec.parse*; matches study_day_configs hasOnly() rule exactly. |
| `learning_tracker/lib/core/sync/codec/track_codec.dart` | DEFECTIVE | t1-core-sync-codec | profile_id/track_id `as int?` casts throw instead of null, crashing pull mid-page. |
| `learning_tracker/lib/core/sync/codec/tutor_grant_codec.dart` | ISSUES | t1-core-sync-codec | Encode/decode correct, matches tutor_grants server-only-write model; zero test coverage. |
| `learning_tracker/lib/core/sync/exceptions/firestore_permission_denied_exception.dart` | ISSUES | t1-core-sync-exceptions | Well-formed; the _guardPermission conversion it depends on covers only 2 of ~30 gateway I/O methods. |
| `learning_tracker/lib/core/sync/exceptions/merge_exception.dart` | ISSUES | t1-core-sync-exceptions | Never thrown anywhere in lib/; only constructed in one widget test. |
| `learning_tracker/lib/core/sync/exceptions/outbox_dead_letter_exception.dart` | ISSUES | t1-core-sync-exceptions | Never thrown anywhere in lib/; real dead-letter path bypasses it entirely. |
| `learning_tracker/lib/core/sync/exceptions/sync_push_exception.dart` | ISSUES | t1-core-sync-exceptions | Actively thrown and tested; committed field not defensively copied, cause-suffix duplicated. |
| `learning_tracker/lib/core/sync/firestore_gateway.dart` | ISSUES | t1-core-sync-root | Clean interface; 408 lines trips AG-3's 400-line cap. |
| `learning_tracker/lib/core/sync/firestore_gateway_impl.dart` | DEFECTIVE | t1-core-sync-root | pushGoal add() dup risk; deleteUserData wrong paths; LWW client-clock; 1216 lines. |
| `learning_tracker/lib/core/sync/firestore_listener_source.dart` | SOUND | t1-core-sync-root | Checked channel wiring, order fields, sentinel-profile guard, local-echo filtering; correct. |
| `learning_tracker/lib/core/sync/initial_sync_state.dart` | SOUND | t1-core-sync-root | Checked write-once idempotency, SharedPreferences flag semantics; correct, no side effects. |
| `learning_tracker/lib/core/sync/lifecycle_observer.dart` | SOUND | t1-core-sync-root | Checked park/unpark and resume state-machine ordering; correct, deliberate no-catch design. |
| `learning_tracker/lib/core/sync/listener_supervisor.dart` | SOUND | t1-core-sync-root | Checked restart-coalescing sealed state machine, park/unpark idempotency; correct. |
| `learning_tracker/lib/core/sync/merge/bookmark_merger.dart` | ISSUES | t1-core-sync-merge | Correct LWW gate + track-FK guard; shares non-atomic upsert/persist (K), no row isolation (G). |
| `learning_tracker/lib/core/sync/merge/completion_event_merger.dart` | ISSUES | t1-core-sync-merge | Correct append-only natural-key insertIfAbsent; no per-row exception isolation (G). |
| `learning_tracker/lib/core/sync/merge/drift_merge_store.dart` | DEFECTIVE | t1-core-sync-merge | 788-line file; raw writes bypass DAOs (A), missing track-FK guards (F), untyped catch (E). |
| `learning_tracker/lib/core/sync/merge/entity_merger.dart` | SOUND | t1-core-sync-merge | Abstract contracts match docs/sync-conflict-resolution.md and actual DriftMergeStore rule order. |
| `learning_tracker/lib/core/sync/merge/gamification_settings_merger.dart` | ISSUES | t1-core-sync-merge | Correct LWW + DI avoids core→features; track-FK guard present; no exception isolation (G). |
| `learning_tracker/lib/core/sync/merge/goal_merger.dart` | ISSUES | t1-core-sync-merge | Missing track-FK guard before upsertGoalByTrack (F); non-atomic persist (K); no isolation (G). |
| `learning_tracker/lib/core/sync/merge/learner_profile_merger.dart` | ISSUES | t1-core-sync-merge | Good per-row isolation exemplar; bare catch swallows Errors (E); non-atomic persist (K). |
| `learning_tracker/lib/core/sync/merge/learning_ledger_merger.dart` | ISSUES | t1-core-sync-merge | Duplicated FK-scan (I); non-random fallback ULID risks silent collision loss (J). |
| `learning_tracker/lib/core/sync/merge/learning_order_merger.dart` | ISSUES | t1-core-sync-merge | Correct LWW gate; non-atomic upsert/persist (K); no row isolation (G). |
| `learning_tracker/lib/core/sync/merge/merge_router.dart` | SOUND | t1-core-sync-merge | Exhaustive dispatch matches EntityKind.all (18/18); unknown kind halts loudly, verified. |
| `learning_tracker/lib/core/sync/merge/merge_rules.dart` | ISSUES | t1-core-sync-merge | Hosts stale remoteIsNewer (C); lwwMerge/mergeForward* dead in production, test-only (D). |
| `learning_tracker/lib/core/sync/merge/notification_settings_merger.dart` | ISSUES | t1-core-sync-merge | core→features import already baselined; correct per-profile LWW; no exception isolation (G). |
| `learning_tracker/lib/core/sync/merge/points_ledger_merger.dart` | ISSUES | t1-core-sync-merge | Correct ULID dedup + balance re-derivation; duplicated FK-scan (I); no isolation (G). |
| `learning_tracker/lib/core/sync/merge/profile_program_merger.dart` | ISSUES | t1-core-sync-merge | Correct R3-6 key-scoping fix; non-atomic upsert/persist (K); no isolation (G). |
| `learning_tracker/lib/core/sync/merge/reward_redemption_merger.dart` | ISSUES | t1-core-sync-merge | Correct LWW status transitions; duplicated FK-scan (I); no isolation (G). |
| `learning_tracker/lib/core/sync/merge/settings_merger.dart` | ISSUES | t1-core-sync-merge | Correct LWW gate; store-side FK guard missing (F); no isolation (G). |
| `learning_tracker/lib/core/sync/merge/stage_definition_merger.dart` | ISSUES | t1-core-sync-merge | Correct LWW gate; store-side FK guard missing (F); non-atomic persist (K). |
| `learning_tracker/lib/core/sync/merge/streak_event_merger.dart` | ISSUES | t1-core-sync-merge | core→features import already baselined; dual-shape decode correct; no isolation (G). |
| `learning_tracker/lib/core/sync/merge/study_day_config_merger.dart` | ISSUES | t1-core-sync-merge | Good track-FK guard exemplar; uses stale non-clock-skew remoteIsNewer (C), not MergeStore's. |
| `learning_tracker/lib/core/sync/merge/track_config_merger.dart` | ISSUES | t1-core-sync-merge | Correct natural-key simplification (W3.22); non-atomic upsert/persist (K); no isolation (G). |
| `learning_tracker/lib/core/sync/merge/tutor_grant_merger.dart` | SOUND | t1-core-sync-merge | Deliberate documented no-op; correctly returns continueNext so pagination isn't broken. |
| `learning_tracker/lib/core/sync/merge/ui_preferences_merger.dart` | ISSUES | t1-core-sync-merge | Correct cross-profile isolation + DEC-26 sacred_time exclusion; no exception isolation (G). |
| `learning_tracker/lib/core/sync/outbox/outbox_processor.dart` | DEFECTIVE | t1-core-sync-outbox | P0 entityKey→analytics privacy leak; P1 concurrency race in single-flight guard; P1 decode-exception escapes containment; P2 unbatched cleanup; 599 lines (AG-3). |
| `learning_tracker/lib/core/sync/outbox/push_pipeline.dart` | ISSUES | t1-core-sync-outbox | Clean 166-line abstract contract, Rules 1/3/4/5 clean; pushCompletion has zero production callers (dead code, P3). |
| `learning_tracker/lib/core/sync/providers/firestore_instance_provider.dart` | ISSUES | t1-core-sync-providers | Only allowed cloud_firestore import site (Rule 3 OK); resetFirestoreNetwork lacks error handling. |
| `learning_tracker/lib/core/sync/providers/merge_router_provider.dart` | SOUND | t1-core-sync-providers | All 18 EntityKind values wired and match entity_merger.dart; features import baselined; no gaps. |
| `learning_tracker/lib/core/sync/providers/outbox_providers.dart` | SOUND | t1-core-sync-providers | Identity-mismatch guard, lazy resolvers, Rule 3/4 compliant; well-reasoned C#1 safety-floor design. |
| `learning_tracker/lib/core/sync/providers/resolve_profile_id_provider.dart` | SOUND | t1-core-sync-providers | 13-line resolver; correctly avoids watch-driven rebuild churn per its documented rationale. |
| `learning_tracker/lib/core/sync/providers/sync_orchestrator_providers.dart` | DEFECTIVE | t1-core-sync-providers | profileId snapshot-capture orphans outbox rows across profile switch (P1); outboxProcessor also snapshot-captured. |
| `learning_tracker/lib/core/sync/providers/sync_status_providers.dart` | ISSUES | t1-core-sync-providers | Byte-identical dead duplicate lives in features/sync/.../sync_providers.dart; 'delegates here' comment is false. |
| `learning_tracker/lib/core/sync/providers/tutored_pull_providers.dart` | ISSUES | t1-core-sync-providers | D18 wipe fix has zero production callers; SM-4 gap in resolveOwnerAccountIdForWipe; minor Ref/WidgetRef duplication. |
| `learning_tracker/lib/core/sync/pull_pipeline.dart` | ISSUES | t1-core-sync-root | 447 lines (AG-3); 2 untyped catch sites swallow Error subtypes (EH-4). |
| `learning_tracker/lib/core/sync/push_pipeline_impl.dart` | ISSUES | t1-core-sync-root | Single-flight serialization correct; one dead no-op catchError at line 272. |
| `learning_tracker/lib/core/sync/sync_identity_status.dart` | SOUND | t1-core-sync-root | Pure data class, three named constructors; no logic to break. |
| `learning_tracker/lib/core/sync/sync_orchestrator.dart` | ISSUES | t1-core-sync-root | HOTSPOT: 1557 lines; 13 untyped catches; channelToKind duplicated with tutored path. |
| `learning_tracker/lib/core/sync/sync_write_facade.dart` | SOUND | t1-core-sync-root | Abstract interface only; docs match implementers' method names and behavior. |
| `learning_tracker/lib/core/sync/tutored_listener_source.dart` | DEFECTIVE | t1-core-sync-root | Missing learning_order channel contradicts its own 'mirrors pull set' doc claim. |
| `learning_tracker/lib/core/sync/tutored_listener_supervisor.dart` | DEFECTIVE | t1-core-sync-root | No onError wired (silently drops stream errors); no recovery triggers; dup switch. |
| `learning_tracker/lib/core/sync/tutored_mirror_wipe_service.dart` | SOUND | t1-core-sync-root | Checked FK-cascade delete reliance, idempotent wipe methods across 3 triggers; correct. |
| `learning_tracker/lib/core/sync/tutored_pull_service.dart` | ISSUES | t1-core-sync-root | Misleading comment: on-Exception catch doesn't actually cover the profile-upsert call. |
| `learning_tracker/lib/core/theme/.gitkeep` | SOUND | t1-core-theme-widgets | Empty placeholder; directory already has real files, nothing to review. |
| `learning_tracker/lib/core/theme/app_colors.dart` | SOUND | t1-core-theme-widgets | Checked 45 constants for theme-bypass/Rule violations; none found. |
| `learning_tracker/lib/core/theme/app_theme.dart` | ISSUES | t1-core-theme-widgets | 687 lines (AG-3 ceiling 400); light/dark theme duplication; duplicate colour literals. |
| `learning_tracker/lib/core/theme/text_styles.dart` | ISSUES | t1-core-theme-widgets | Drifted 2nd typography system (hardcoded Roboto); 2 dead methods; stale comment. |
| `learning_tracker/lib/core/time/local_day_clock.dart` | ISSUES | t1-core-small-a | Mutable global clock singleton; reset discipline unenforced by compiler |
| `learning_tracker/lib/core/time/ulid.dart` | SOUND | t1-core-small-a | DateTime.now() fallback ok inside core/time/; all prod callers pass now |
| `learning_tracker/lib/core/utils/date_utils.dart` | ISSUES | t1-core-nav-utils | DateUtils class shadows Flutter SDK's own class; also uses banned `_utils.dart` suffix. |
| `learning_tracker/lib/core/utils/gematriya.dart` | SOUND | t1-core-nav-utils | Traced forNumber/forYear math against docstring examples incl. TS-6 fix; correct. |
| `learning_tracker/lib/core/utils/hebrew_calendar_utils.dart` | ISSUES | t1-core-nav-utils | isShabbos/isYomTov/formatHebrewDate dead, duplicate zmanim_window_service; `_utils.dart` naming. |
| `learning_tracker/lib/core/utils/hebrew_utils.dart` | ISSUES | t1-core-nav-utils | Footnote/nikud logic correct; file uses banned `_utils.dart` suffix naming. |
| `learning_tracker/lib/core/utils/natural_sort.dart` | SOUND | t1-core-nav-utils | Traced digit-run comparison logic against all test cases; correct. |
| `learning_tracker/lib/core/utils/pace_derivation.dart` | SOUND | t1-core-nav-utils | Verified ceil/clamp math against 7 cases incl. boundary clamps; correct. |
| `learning_tracker/lib/core/utils/percentage_formatter.dart` | SOUND | t1-core-nav-utils | Verified adaptive-precision rounding incl. int/double `==` edge case; correct. |
| `learning_tracker/lib/core/utils/text_input_formatters.dart` | SOUND | t1-core-nav-utils | Two small formatters, straightforward selection-offset logic; correct. |
| `learning_tracker/lib/core/widgets/animated_progress_bar.dart` | SOUND | t1-core-theme-widgets | Checked lifecycle, PF-1 const usage, no hardcoded strings; clean. |
| `learning_tracker/lib/core/widgets/app_bar_title.dart` | SOUND | t1-core-theme-widgets | 21-line FittedBox wrapper; no violations. |
| `learning_tracker/lib/core/widgets/app_dialog.dart` | ISSUES | t1-core-theme-widgets | Overflow-safety design is sound; one raw Color literal outside theme. |
| `learning_tracker/lib/core/widgets/app_error_view.dart` | DEFECTIVE | t1-core-theme-widgets | 13 hardcoded English strings incl. raw error.message passthrough; AX-2/EH-5. |
| `learning_tracker/lib/core/widgets/curriculum_indicator.dart` | ISSUES | t1-core-theme-widgets | Zero production callers repo-wide; dead widget with a dedicated dead test. |
| `learning_tracker/lib/core/widgets/empty_state.dart` | SOUND | t1-core-theme-widgets | Caller supplies all text; theme-sourced colours only; no violations. |
| `learning_tracker/lib/core/widgets/error_display.dart` | DEFECTIVE | t1-core-theme-widgets | Hardcodes 'Retry'; same AX-2 defect as app_error_view.dart, live in 4 screens. |
| `learning_tracker/lib/core/widgets/hebrew_text.dart` | SOUND | t1-core-theme-widgets | RTL Directionality wrapper correct; only consumer noted under text_styles.dart. |
| `learning_tracker/lib/core/widgets/learning_date_picker_theme.dart` | SOUND | t1-core-theme-widgets | All colours sourced from AppTheme constants; no literals, no violations. |
| `learning_tracker/lib/core/widgets/loading_indicator.dart` | SOUND | t1-core-theme-widgets | Caller supplies message; theme-sourced colours; no violations. |
| `learning_tracker/lib/core/widgets/pin_entry_widget.dart` | DEFECTIVE | t1-core-theme-widgets | 4 hardcoded strings though matching ICU-ready ARB keys already exist unused. |
| `learning_tracker/lib/core/widgets/preference_list_tile.dart` | ISSUES | t1-core-theme-widgets | One raw Color literal (0xFF929BAA) duplicated verbatim elsewhere. |
| `learning_tracker/lib/core/widgets/preference_segmented_tile.dart` | ISSUES | t1-core-theme-widgets | 3 raw Color literals outside theme, one duplicating preference_list_tile.dart's. |
| `learning_tracker/lib/core/widgets/reorder_confirm_dialog.dart` | SOUND | t1-core-theme-widgets | Exemplary AppLocalizations usage throughout; positive control for AX-2 finding. |
| `learning_tracker/lib/core/widgets/scrollable_fill_body.dart` | SOUND | t1-core-theme-widgets | Bounded/unbounded height handling correct and well-documented; no violations. |
| `learning_tracker/lib/core/widgets/scrollable_step_body.dart` | SOUND | t1-core-theme-widgets | Thin SafeArea+ScrollView wrapper; no violations. |
| `learning_tracker/lib/core/widgets/stat_card.dart` | ISSUES | t1-core-theme-widgets | 5 raw Color literals; 2 exactly duplicate existing AppColors.blueNavy unreferenced. |
| `learning_tracker/lib/core/widgets/track_progress_bar.dart` | ISSUES | t1-core-theme-widgets | Zero production callers (dead widget); also hardcodes 'No completions yet'. |
| `learning_tracker/lib/features/account/account.dart` | ISSUES | t1-feat-account | barrel exports dead duplicate validators file + authStateProvider name-clash hide workaround |
| `learning_tracker/lib/features/account/data/repositories/.gitkeep` | SOUND | t1-feat-account | empty placeholder, nothing to review |
| `learning_tracker/lib/features/account/data/repositories/auth_repository_impl.dart` | SOUND | t1-feat-account | checked for Firebase SDK leakage (none), all AuthRepository methods delegate cleanly to gateways |
| `learning_tracker/lib/features/account/data/services/magic_link_service.dart` | ISSUES | t1-feat-account | duplicated/stale _extractFirebaseCode regex; disposal, deep-link unwrap, catches otherwise sound |
| `learning_tracker/lib/features/account/domain/entities/.gitkeep` | SOUND | t1-feat-account | empty placeholder, nothing to review |
| `learning_tracker/lib/features/account/domain/models/app_user.dart` | ISSUES | t1-feat-account | hand-rolled data model, not @freezed, no value equality |
| `learning_tracker/lib/features/account/domain/models/auth_state.dart` | ISSUES | t1-feat-account | AuthState/AuthUser hand-rolled, not @freezed, no value equality |
| `learning_tracker/lib/features/account/domain/repositories/.gitkeep` | SOUND | t1-feat-account | empty placeholder, nothing to review |
| `learning_tracker/lib/features/account/domain/repositories/auth_repository.dart` | SOUND | t1-feat-account | interface-only, checked for Firebase leakage and layering: clean |
| `learning_tracker/lib/features/account/domain/services/account_lifecycle_service.dart` | ISSUES | t1-feat-account | comment-only log-less catch at signOut cleanup; deletion ordering otherwise careful |
| `learning_tracker/lib/features/account/domain/services/account_management_service.dart` | ISSUES | t1-feat-account | comment-only log-less catch on Firestore-delete Cloud Function call |
| `learning_tracker/lib/features/account/domain/services/local_auth_service.dart` | ISSUES | t1-feat-account | solid timing-safe auth logic; 8-char password constant diverges from UI's 6-char validator |
| `learning_tracker/lib/features/account/domain/services/password_hasher.dart` | SOUND | t1-feat-account | checked argon2id params, constant-time compare, dummy-verify timing safety: solid |
| `learning_tracker/lib/features/account/domain/services/pending_local_signup.dart` | ISSUES | t1-feat-account | deep-imports features/profiles presentation providers, bypassing empty profiles barrel |
| `learning_tracker/lib/features/account/domain/services/session_persistence_service.dart` | SOUND | t1-feat-account | checked dual-write prefs+registry fallback chain: consistent, no I/O gaps |
| `learning_tracker/lib/features/account/domain/services/upgrade_to_cloud_service.dart` | ISSUES | t1-feat-account | duplicated _extractFirebaseCode using the stale/buggy regex pattern |
| `learning_tracker/lib/features/account/domain/use_cases/.gitkeep` | SOUND | t1-feat-account | empty placeholder, nothing to review |
| `learning_tracker/lib/features/account/onboarding/domain/validators/auth_validators.dart` | DEFECTIVE | t1-feat-account | dead byte-identical duplicate of features/onboarding twin; hardcodes untranslated English via that twin |
| `learning_tracker/lib/features/account/onboarding/presentation/screens/onboarding_intent_screen.dart` | ISSUES | t1-feat-account | not barrel-exported; consumed via cross-feature deep import from features/onboarding |
| `learning_tracker/lib/features/account/onboarding/presentation/screens/signup_screen.dart` | DEFECTIVE | t1-feat-account | 985 lines, untestable inline business logic, e.toString() in l10n, hardcoded-string validators wired in |
| `learning_tracker/lib/features/account/presentation/notifiers/sign_in_controller.dart` | DEFECTIVE | t1-feat-account | 1016 lines; zero ref.mounted guards across 84 awaits in an autoDispose notifier; other minor issues |
| `learning_tracker/lib/features/account/presentation/providers/.gitkeep` | SOUND | t1-feat-account | empty placeholder, nothing to review |
| `learning_tracker/lib/features/account/presentation/providers/account_management_providers.dart` | SOUND | t1-feat-account | trivial DI provider, service constructed inside provider body per SM-7 |
| `learning_tracker/lib/features/account/presentation/providers/auth_providers.dart` | ISSUES | t1-feat-account | authState provider name clashes with auth_state_provider.dart's generated symbol |
| `learning_tracker/lib/features/account/presentation/providers/auth_state_provider.dart` | ISSUES | t1-feat-account | same authStateProvider name-clash; build()/_init() fire-and-forget pattern is deliberate and low-risk (keepAlive) |
| `learning_tracker/lib/features/account/presentation/providers/connectivity_providers.dart` | SOUND | t1-feat-account | checked disposal, debounce, self-heal probe loop, test seams: well-engineered, no violations |
| `learning_tracker/lib/features/account/presentation/providers/magic_link_providers.dart` | SOUND | t1-feat-account | keepAlive justified inline, disposal wired via ref.onDispose |
| `learning_tracker/lib/features/account/presentation/screens/.gitkeep` | SOUND | t1-feat-account | empty placeholder, nothing to review |
| `learning_tracker/lib/features/account/presentation/screens/account_picker_screen.dart` | DEFECTIVE | t1-feat-account | 842 lines; FutureBuilder-fresh-Future-in-build; ref.read in build; 2 log-less catches |
| `learning_tracker/lib/features/account/presentation/screens/sign_in_screen.dart` | ISSUES | t1-feat-account | 446 lines (just over AG-3 cap); wires in hardcoded-string validateEmail |
| `learning_tracker/lib/features/account/presentation/widgets/.gitkeep` | SOUND | t1-feat-account | empty placeholder, nothing to review |
| `learning_tracker/lib/features/account/presentation/widgets/email_verification_confirm_panel.dart` | DEFECTIVE | t1-feat-account | 5 hardcoded English strings incl. unconditional button labels shown to all locales |
| `learning_tracker/lib/features/account/presentation/widgets/email_verification_dialog.dart` | ISSUES | t1-feat-account | never overrides the panel's hardcoded English title default |
| `learning_tracker/lib/features/account/presentation/widgets/no_backup_badge.dart` | ISSUES | t1-feat-account | hardcoded English Tooltip message and Semantics label |
| `learning_tracker/lib/features/account/presentation/widgets/offline_top_banner.dart` | ISSUES | t1-feat-account | Fixed height:32 wraps Text; clips under large text-scale accessibility settings (AX-4). |
| `learning_tracker/lib/features/account/presentation/widgets/sign_in_actions.dart` | ISSUES | t1-feat-account | TapGestureRecognizer rebuilt every build() with no disposal owner (hygiene). |
| `learning_tracker/lib/features/account/presentation/widgets/sign_in_form.dart` | SOUND | t1-feat-account | Checked l10n, directional insets, validators, disposal; pure presentational widget, no violations. |
| `learning_tracker/lib/features/account/presentation/widgets/sign_in_mode_card.dart` | SOUND | t1-feat-account | Checked exhaustive switch, l10n, colors, layering; clean pure-presentational widget. |
| `learning_tracker/lib/features/content_browsing/content_browsing.dart` | ISSUES | t1-feat-content_browsing | Barrel exports nothing; no compliant cross-feature import path exists. |
| `learning_tracker/lib/features/content_browsing/data/data_sources/.gitkeep` | SOUND | t1-feat-content_browsing | Empty placeholder file, 0 lines. |
| `learning_tracker/lib/features/content_browsing/data/models/.gitkeep` | SOUND | t1-feat-content_browsing | Empty placeholder file, 0 lines. |
| `learning_tracker/lib/features/content_browsing/data/repositories/.gitkeep` | SOUND | t1-feat-content_browsing | Empty placeholder file, 0 lines. |
| `learning_tracker/lib/features/content_browsing/data/repositories/content_repository_impl.dart` | ISSUES | t1-feat-content_browsing | Untyped catch(e); caching/search/composite-curriculum logic checked, correct. |
| `learning_tracker/lib/features/content_browsing/data/repositories/text_cache_repository.dart` | SOUND | t1-feat-content_browsing | Checked lookup chain, sort order, HTML-decode; no issues found. |
| `learning_tracker/lib/features/content_browsing/data/services/cloud_content_service.dart` | ISSUES | t1-feat-content_browsing | Dead code, zero production callers; gzip catch(_) swallows real errors. |
| `learning_tracker/lib/features/content_browsing/data/services/text_download_service.dart` | ISSUES | t1-feat-content_browsing | Dead code; fake '@deprecated' doc-comment isn't a real annotation. |
| `learning_tracker/lib/features/content_browsing/domain/entities/.gitkeep` | SOUND | t1-feat-content_browsing | Empty placeholder file, 0 lines. |
| `learning_tracker/lib/features/content_browsing/domain/repositories/.gitkeep` | SOUND | t1-feat-content_browsing | Empty placeholder file, 0 lines. |
| `learning_tracker/lib/features/content_browsing/domain/repositories/content_repository.dart` | SOUND | t1-feat-content_browsing | Interface matches impl; typed exception at data boundary; clean. |
| `learning_tracker/lib/features/content_browsing/domain/strategies/composite_curriculum_strategy.dart` | SOUND | t1-feat-content_browsing | Checked registry/remap logic and Tanach offset math; no risk found. |
| `learning_tracker/lib/features/content_browsing/domain/use_cases/.gitkeep` | SOUND | t1-feat-content_browsing | Empty placeholder file, 0 lines. |
| `learning_tracker/lib/features/content_browsing/presentation/providers/.gitkeep` | SOUND | t1-feat-content_browsing | Empty placeholder file, 0 lines. |
| `learning_tracker/lib/features/content_browsing/presentation/providers/cloud_content_providers.dart` | ISSUES | t1-feat-content_browsing | Both providers unused in production; weak keepAlive justification. |
| `learning_tracker/lib/features/content_browsing/presentation/providers/content_providers.dart` | ISSUES | t1-feat-content_browsing | curriculumHeNames keepAlive lacks justification; providers otherwise correct. |
| `learning_tracker/lib/features/content_browsing/presentation/providers/text_display_providers.dart` | ISSUES | t1-feat-content_browsing | FontSizeNotifier/ShowNikud keepAlive unjustified; textDownloadService chain unused. |
| `learning_tracker/lib/features/content_browsing/presentation/screens/.gitkeep` | SOUND | t1-feat-content_browsing | Empty placeholder file, 0 lines. |
| `learning_tracker/lib/features/content_browsing/presentation/screens/content_hierarchy_screen.dart` | ISSUES | t1-feat-content_browsing | 603 lines; silent unlogged tree-error fallback; RTL handling checked clean. |
| `learning_tracker/lib/features/content_browsing/presentation/screens/content_search_screen.dart` | ISSUES | t1-feat-content_browsing | 'Clear' tooltip hardcoded; untyped catch(_); rest of l10n is clean. |
| `learning_tracker/lib/features/content_browsing/presentation/screens/curriculum_list_screen.dart` | ISSUES | t1-feat-content_browsing | Whole screen unlocalized (9 strings); decorative search is baselined R-LC1. |
| `learning_tracker/lib/features/content_browsing/presentation/screens/text_display_screen.dart` | DEFECTIVE | t1-feat-content_browsing | 1028 lines; missing analytics injection breaks tutor-block telemetry. |
| `learning_tracker/lib/features/content_browsing/presentation/widgets/.gitkeep` | SOUND | t1-feat-content_browsing | Empty placeholder file, 0 lines. |
| `learning_tracker/lib/features/content_browsing/presentation/widgets/breadcrumb_navigation.dart` | SOUND | t1-feat-content_browsing | Checked RTL-aware separator helper and ellipsis/width handling; correct. |
| `learning_tracker/lib/features/content_browsing/presentation/widgets/content_item_tile.dart` | ISSUES | t1-feat-content_browsing | Two hardcoded strings in stage-breakdown sheet; imports otherwise clean. |
| `learning_tracker/lib/features/content_browsing/presentation/widgets/hierarchy_selection_panel.dart` | DEFECTIVE | t1-feat-content_browsing | Hardcoded chevron_right breaks RTL breadcrumb; raw Colors.grey literal. |
| `learning_tracker/lib/features/content_browsing/presentation/widgets/item_review_breakdown.dart` | ISSUES | t1-feat-content_browsing | 'Stage $key' fallback string is hardcoded, not localized. |
| `learning_tracker/lib/features/content_browsing/presentation/widgets/review_count_badge.dart` | SOUND | t1-feat-content_browsing | Checked zero-hide logic and badge rendering; no violations. |
| `learning_tracker/lib/features/dashboard/dashboard.dart` | ISSUES | t1-feat-dashboard | Barrel says 'Populated in Wave 5' but exports nothing; unused repo-wide. |
| `learning_tracker/lib/features/dashboard/data/data_sources/.gitkeep` | SOUND | t1-feat-dashboard | Directory genuinely empty; placeholder still needed. |
| `learning_tracker/lib/features/dashboard/data/models/.gitkeep` | SOUND | t1-feat-dashboard | Directory genuinely empty; placeholder still needed. |
| `learning_tracker/lib/features/dashboard/data/repositories/.gitkeep` | SOUND | t1-feat-dashboard | Directory genuinely empty; placeholder still needed. |
| `learning_tracker/lib/features/dashboard/domain/entities/.gitkeep` | SOUND | t1-feat-dashboard | Directory genuinely empty; placeholder still needed. |
| `learning_tracker/lib/features/dashboard/domain/models/calendar_position.dart` | SOUND | t1-feat-dashboard | Clean freezed value object; delta/status derivation checked, actively used. |
| `learning_tracker/lib/features/dashboard/domain/models/chazara_status.dart` | ISSUES | t1-feat-dashboard | Fully unused domain model repo-wide (dead-code finding). |
| `learning_tracker/lib/features/dashboard/domain/models/models.dart` | ISSUES | t1-feat-dashboard | Barrel re-exports models that nothing imports; dead. |
| `learning_tracker/lib/features/dashboard/domain/models/momentum_status.dart` | ISSUES | t1-feat-dashboard | Fully unused domain model repo-wide (dead-code finding). |
| `learning_tracker/lib/features/dashboard/domain/repositories/.gitkeep` | SOUND | t1-feat-dashboard | Directory genuinely empty; placeholder still needed. |
| `learning_tracker/lib/features/dashboard/domain/services/next_reward_selector.dart` | SOUND | t1-feat-dashboard | Pure, correct selection algorithm; sole caller's result is discarded elsewhere. |
| `learning_tracker/lib/features/dashboard/domain/services/parent_dashboard_aggregator.dart` | ISSUES | t1-feat-dashboard | Hardcoded SystemLocalDayClock ignores injectable now; dup CurriculumSummary class name. |
| `learning_tracker/lib/features/dashboard/domain/services/track_completion_service.dart` | SOUND | t1-feat-dashboard | Pure item/stage completion math; formulas match doc comments, no IO. |
| `learning_tracker/lib/features/dashboard/domain/use_cases/.gitkeep` | ISSUES | t1-feat-dashboard | Directory non-empty since the use-case landed; stale placeholder. |
| `learning_tracker/lib/features/dashboard/domain/use_cases/compute_pace_status_use_case.dart` | SOUND | t1-feat-dashboard | Pure sealed-switch pace projection, exhaustive, no default arm, no IO. |
| `learning_tracker/lib/features/dashboard/presentation/providers/.gitkeep` | ISSUES | t1-feat-dashboard | Directory holds 5 real provider files; stale placeholder. |
| `learning_tracker/lib/features/dashboard/presentation/providers/calendar_position_providers.dart` | SOUND | t1-feat-dashboard | Ref reads correctly ordered before first await; no SM-4 gap found. |
| `learning_tracker/lib/features/dashboard/presentation/providers/dashboard_model_provider.dart` | ISSUES | t1-feat-dashboard | Whole composition layer orphaned; screen still watches leaf providers directly. |
| `learning_tracker/lib/features/dashboard/presentation/providers/dashboard_providers.dart` | DEFECTIVE | t1-feat-dashboard | SM-4 gaps x4, 541 lines (AG-3), feeds a fully-discarded reward computation. |
| `learning_tracker/lib/features/dashboard/presentation/screens/.gitkeep` | ISSUES | t1-feat-dashboard | Directory holds dashboard_screen.dart; stale placeholder. |
| `learning_tracker/lib/features/dashboard/presentation/screens/dashboard_screen.dart` | SOUND | t1-feat-dashboard | Invalidation set, sync-transition ref.listen, ref.read/watch usage all correct. |
| `learning_tracker/lib/features/dashboard/presentation/widgets/.gitkeep` | ISSUES | t1-feat-dashboard | Directory holds 20 real widget files; stale placeholder. |
| `learning_tracker/lib/features/dashboard/presentation/widgets/active_track_card.dart` | ISSUES | t1-feat-dashboard | 414 lines exceeds AG-3 cap; otherwise correct focus-pill/label logic. |
| `learning_tracker/lib/features/dashboard/presentation/widgets/active_track_focus_pill.dart` | SOUND | t1-feat-dashboard | Uses AlignmentDirectional correctly; fully localized via caller-supplied strings. |
| `learning_tracker/lib/features/dashboard/presentation/widgets/active_tracks_carousel_section.dart` | ISSUES | t1-feat-dashboard | Correct RTL chevron-direction swap; feeds unlabeled ArrowButton (AX-3). |
| `learning_tracker/lib/features/dashboard/presentation/widgets/arrow_button.dart` | DEFECTIVE | t1-feat-dashboard | Icon-only nav control has no Semantics/label anywhere (AX-3). |
| `learning_tracker/lib/features/dashboard/presentation/widgets/child_points_rewards_tab_card.dart` | ISSUES | t1-feat-dashboard | Required nextRewardAsync param is never read in build() (dead). |
| `learning_tracker/lib/features/dashboard/presentation/widgets/compact_mission_card.dart` | SOUND | t1-feat-dashboard | Fully localized via caller params; dashed-border + solid variants both checked. |
| `learning_tracker/lib/features/dashboard/presentation/widgets/curriculum_summary_card.dart` | DEFECTIVE | t1-feat-dashboard | Zero production callers; 6 hardcoded English strings; dup CurriculumSummary type. |
| `learning_tracker/lib/features/dashboard/presentation/widgets/dashboard_all_caught_up_card.dart` | SOUND | t1-feat-dashboard | Fully localized, l10n-driven; gradient/decoration checked, no defects found. |
| `learning_tracker/lib/features/dashboard/presentation/widgets/dashboard_body.dart` | DEFECTIVE | t1-feat-dashboard | 547 lines (AG-3); discarded initialSyncComplete var; feeds dead reward param. |
| `learning_tracker/lib/features/dashboard/presentation/widgets/dashboard_helpers.dart` | SOUND | t1-feat-dashboard | Task-grouping/ref-sort helpers checked against callers; under 400 lines, cohesive. |
| `learning_tracker/lib/features/dashboard/presentation/widgets/dashboard_level_points_card.dart` | SOUND | t1-feat-dashboard | Fully localized; tasksReady/lifetimeReady loading-state discipline correct. |
| `learning_tracker/lib/features/dashboard/presentation/widgets/dashboard_stat_bubble.dart` | SOUND | t1-feat-dashboard | Small single-purpose bubble; receives pre-resolved strings, no l10n gap. |
| `learning_tracker/lib/features/dashboard/presentation/widgets/dashboard_task_item.dart` | ISSUES | t1-feat-dashboard | Dead/unused widget anywhere in lib or test; no-op onTap stub. |
| `learning_tracker/lib/features/dashboard/presentation/widgets/dashed_rounded_border_painter.dart` | SOUND | t1-feat-dashboard | Checked paint/shouldRepaint correctness; confirmed live use in compact_mission_card. |
| `learning_tracker/lib/features/dashboard/presentation/widgets/empty_dashboard.dart` | SOUND | t1-feat-dashboard | Checked l10n coverage, AX, imports, layering; no violations found. |
| `learning_tracker/lib/features/dashboard/presentation/widgets/main_focus_mission_card.dart` | SOUND | t1-feat-dashboard | Checked l10n, theming, live wiring into dashboard_body.dart; clean. |
| `learning_tracker/lib/features/dashboard/presentation/widgets/points_summary_widget.dart` | ISSUES | t1-feat-dashboard | Dead widget (superseded); hardcoded English strings bypass AppLocalizations. |
| `learning_tracker/lib/features/dashboard/presentation/widgets/skipped_onboarding_cta_banner.dart` | ISSUES | t1-feat-dashboard | Dismiss handler calls ref.invalidate after await with no mounted guard. |
| `learning_tracker/lib/features/dashboard/presentation/widgets/streak_recovery_banner.dart` | SOUND | t1-feat-dashboard | Checked AsyncValue handling, SM-3 watch usage, l10n; clean. |
| `learning_tracker/lib/features/dashboard/presentation/widgets/task_category_stat_box.dart` | SOUND | t1-feat-dashboard | Thin StatCard delegate; checked props/theming; no issues. |
| `learning_tracker/lib/features/dashboard/presentation/widgets/track_stat_grid.dart` | SOUND | t1-feat-dashboard | l10n-clean; cross-feature DailyTask import is a repo-wide pattern (see Makefile finding). |
| `learning_tracker/lib/features/gamification/data/data_sources/.gitkeep` | SOUND | t1-feat-gamification | Empty 0-byte scaffold placeholder, confirmed via ls. |
| `learning_tracker/lib/features/gamification/data/models/.gitkeep` | SOUND | t1-feat-gamification | Empty 0-byte scaffold placeholder, confirmed via ls. |
| `learning_tracker/lib/features/gamification/data/repositories/.gitkeep` | SOUND | t1-feat-gamification | Empty 0-byte scaffold placeholder, confirmed via ls. |
| `learning_tracker/lib/features/gamification/domain/entities/.gitkeep` | SOUND | t1-feat-gamification | Empty 0-byte scaffold placeholder, confirmed via ls. |
| `learning_tracker/lib/features/gamification/domain/models/reward_milestone.dart` | ISSUES | t1-feat-gamification | Clean JSON mapping; hand-written not @freezed, no value equality (F14). |
| `learning_tracker/lib/features/gamification/domain/models/streak_recovery_info.dart` | SOUND | t1-feat-gamification | Correctly @freezed, minimal, immutable; no issues. |
| `learning_tracker/lib/features/gamification/domain/repositories/.gitkeep` | SOUND | t1-feat-gamification | Empty 0-byte scaffold placeholder, confirmed via ls. |
| `learning_tracker/lib/features/gamification/domain/reward_milestone_icons.dart` | SOUND | t1-feat-gamification | Pure utility; clampIndex bounds-safety incl. empty-list checked. |
| `learning_tracker/lib/features/gamification/domain/services/points_service.dart` | ISSUES | t1-feat-gamification | Correct DAO reads; constructs RewardMilestoneService ad-hoc (SM-7). |
| `learning_tracker/lib/features/gamification/domain/services/reward_milestone_service.dart` | DEFECTIVE | t1-feat-gamification | 403 lines (AG-3); silent JSON-swallow (F4); LWW null-timestamp bug (F5). |
| `learning_tracker/lib/features/gamification/domain/services/streak_service.dart` | ISSUES | t1-feat-gamification | Clean read facade; constructs StreakStateProvider ad-hoc (SM-7). |
| `learning_tracker/lib/features/gamification/domain/use_cases/.gitkeep` | SOUND | t1-feat-gamification | Empty 0-byte scaffold placeholder, confirmed via ls. |
| `learning_tracker/lib/features/gamification/gamification.dart` | ISSUES | t1-feat-gamification | 7-line barrel: zero exports, zero importers repo-wide, dead. |
| `learning_tracker/lib/features/gamification/presentation/providers/.gitkeep` | SOUND | t1-feat-gamification | Empty 0-byte scaffold placeholder, confirmed via ls. |
| `learning_tracker/lib/features/gamification/presentation/providers/achievements_overview_provider.dart` | DEFECTIVE | t1-feat-gamification | FutureProvider writes+pushes-to-cloud from build (SM-2); ad-hoc construction. |
| `learning_tracker/lib/features/gamification/presentation/providers/points_providers.dart` | ISSUES | t1-feat-gamification | Correct pointsServiceProvider pattern; 2 family providers miss autoDispose. |
| `learning_tracker/lib/features/gamification/presentation/providers/reward_config_controller.dart` | DEFECTIVE | t1-feat-gamification | Zero ref.mounted checks in file (SM-4); 4x ad-hoc service construction. |
| `learning_tracker/lib/features/gamification/presentation/screens/.gitkeep` | SOUND | t1-feat-gamification | Empty 0-byte scaffold placeholder, confirmed via ls. |
| `learning_tracker/lib/features/gamification/presentation/screens/child_redemption_screen.dart` | DEFECTIVE | t1-feat-gamification | Raw e.toString() in UI; 414 lines; ad-hoc construction; colors. |
| `learning_tracker/lib/features/gamification/presentation/screens/gamification_screen.dart` | ISSUES | t1-feat-gamification | Good ref.listen/l10n discipline; StreakService constructed ad-hoc. |
| `learning_tracker/lib/features/gamification/presentation/screens/parent_pending_redemptions_screen.dart` | DEFECTIVE | t1-feat-gamification | ref.invalidate before mounted check; raw e.toString() in UI. |
| `learning_tracker/lib/features/gamification/presentation/screens/point_config_screen.dart` | DEFECTIVE | t1-feat-gamification | 790-line God-file; provider writes+syncs from build (SM-2). |
| `learning_tracker/lib/features/gamification/presentation/screens/reward_configuration_screen.dart` | ISSUES | t1-feat-gamification | Excellent mounted-check discipline; 718 lines; one dead error branch. |
| `learning_tracker/lib/features/gamification/presentation/widgets/.gitkeep` | SOUND | t1-feat-gamification | Empty 0-byte scaffold placeholder, confirmed via ls. |
| `learning_tracker/lib/features/gamification/presentation/widgets/achievement_tier_card.dart` | DEFECTIVE | t1-feat-gamification | Positioned(right:) overlaps title text in Hebrew RTL; colors. |
| `learning_tracker/lib/features/gamification/presentation/widgets/achievement_unlock_celebration.dart` | ISSUES | t1-feat-gamification | Excellent context.mounted discipline throughout; 413 lines; colors. |
| `learning_tracker/lib/features/gamification/presentation/widgets/achievements_header.dart` | SOUND | t1-feat-gamification | Trivial, clean, correctly localized; no issues found. |
| `learning_tracker/lib/features/gamification/presentation/widgets/avatar_picker_row.dart` | ISSUES | t1-feat-gamification | Defensive hasClients guard; 2 hardcoded color literals. |
| `learning_tracker/lib/features/gamification/presentation/widgets/gamification_route_push_guard.dart` | SOUND | t1-feat-gamification | Pure static logic, testable without a widget tree; no issues. |
| `learning_tracker/lib/features/gamification/presentation/widgets/locked_achievement_shell.dart` | ISSUES | t1-feat-gamification | Clean blur overlay; 3 hardcoded color literals. |
| `learning_tracker/lib/features/gamification/presentation/widgets/manage_rewards_list.dart` | ISSUES | t1-feat-gamification | Clean async refresh flow; raw label:value string, not ICU. |
| `learning_tracker/lib/features/gamification/presentation/widgets/points_display_widget.dart` | ISSUES | t1-feat-gamification | PointsPopupWidget unused in prod (dead); raw label:value string. |
| `learning_tracker/lib/features/gamification/presentation/widgets/pro_tip_card.dart` | ISSUES | t1-feat-gamification | Clean layout; 6 hardcoded color literals. |
| `learning_tracker/lib/features/gamification/presentation/widgets/progress_summary_card.dart` | ISSUES | t1-feat-gamification | Model PositionedDirectional RTL usage (contrast w/ F1); 2 colors. |
| `learning_tracker/lib/features/gamification/presentation/widgets/reward_config_header.dart` | ISSUES | t1-feat-gamification | Non-directional EdgeInsets.only(left/right); back IconButton has no a11y tooltip. |
| `learning_tracker/lib/features/gamification/presentation/widgets/reward_form.dart` | ISSUES | t1-feat-gamification | Hand-written state class, no @freezed/==, defeats Riverpod rebuild-skip. |
| `learning_tracker/lib/features/gamification/presentation/widgets/reward_type_segmented.dart` | SOUND | t1-feat-gamification | Directional-safe padding, theme-sourced colors, text-labeled segments checked. |
| `learning_tracker/lib/features/gamification/presentation/widgets/streak_widget.dart` | SOUND | t1-feat-gamification | l10n via ARB, AnimationController disposed, ProfileMode branching checked clean. |
| `learning_tracker/lib/features/gamification/presentation/widgets/tier_icon_box.dart` | ISSUES | t1-feat-gamification | Positioned(right:) lock badge does not mirror in RTL (Hebrew). |
| `learning_tracker/lib/features/gamification/presentation/widgets/tier_style.dart` | ISSUES | t1-feat-gamification | Fragile English-string switch, silent default fallback, un-themed literals, zero tests. |
| `learning_tracker/lib/features/gamification/presentation/widgets/track_filter_row.dart` | SOUND | t1-feat-gamification | l10n labels, directional spacing, theme colors; full widget tree checked. |
| `learning_tracker/lib/features/gamification/presentation/widgets/track_tag_chip.dart` | SOUND | t1-feat-gamification | Small presentational widget, overflow-safe text, scheme-sourced colors checked. |
| `learning_tracker/lib/features/gamification/streak/streak_event.dart` | ISSUES | t1-feat-gamification | Class name collides with Drift-generated StreakEvent (AG-4), mitigated via hide. |
| `learning_tracker/lib/features/gamification/streak/streak_event_log.dart` | ISSUES | t1-feat-gamification | Doc comment states wrong unique-index columns (eventTimestamp vs real dayUtc). |
| `learning_tracker/lib/features/gamification/streak/streak_reducer.dart` | SOUND | t1-feat-gamification | Pure function, injectable clock/dayOf; run/gap/lapse boundary logic checked. |
| `learning_tracker/lib/features/gamification/streak/streak_restorer.dart` | ISSUES | t1-feat-gamification | Redefines kBulkPriorSentinelMs locally instead of importing the core constant. |
| `learning_tracker/lib/features/gamification/streak/streak_state_provider.dart` | ISSUES | t1-feat-gamification | Named/suffixed like a @riverpod provider but is a plain hand-written service class. |
| `learning_tracker/lib/features/learning/data/completion_writer.dart` | ISSUES | t1-feat-learning | 770 lines (AG-3); commit/commitBatch transactional logic itself is sound. |
| `learning_tracker/lib/features/learning/data/data_sources/.gitkeep` | SOUND | t1-feat-learning | Empty placeholder file, no content. |
| `learning_tracker/lib/features/learning/data/models/.gitkeep` | SOUND | t1-feat-learning | Empty placeholder file, no content. |
| `learning_tracker/lib/features/learning/data/repositories/.gitkeep` | SOUND | t1-feat-learning | Empty placeholder file, no content. |
| `learning_tracker/lib/features/learning/data/repositories/bookmark_repository_impl.dart` | SOUND | t1-feat-learning | Checked LWW merge, ContentIndex fast/slow path, DI wiring; no violations. |
| `learning_tracker/lib/features/learning/data/repositories/completion_repository_impl.dart` | DEFECTIVE | t1-feat-learning | 891 lines (AG-3); ad-hoc collaborator construction (SM-7/SM-8); log-less broad catch. |
| `learning_tracker/lib/features/learning/data/repositories/learning_ledger_repository_impl.dart` | ISSUES | t1-feat-learning | Ledger insert and outbox enqueue are separate, non-atomic writes. |
| `learning_tracker/lib/features/learning/data/repositories/track_repository_impl.dart` | SOUND | t1-feat-learning | 74 lines, clean DI, checked sync-push path; no issues. |
| `learning_tracker/lib/features/learning/domain/entities/.gitkeep` | SOUND | t1-feat-learning | Empty placeholder file, no content. |
| `learning_tracker/lib/features/learning/domain/entities/batch_plan.dart` | ISSUES | t1-feat-learning | Fully-tested sealed hierarchy never consumed by production code. |
| `learning_tracker/lib/features/learning/domain/entities/bookmark.dart` | SOUND | t1-feat-learning | Checked Firestore codec round-trip and immutability; no violations. |
| `learning_tracker/lib/features/learning/domain/entities/completion_command.dart` | SOUND | t1-feat-learning | @freezed, well-documented natural-key invariant; no violations. |
| `learning_tracker/lib/features/learning/domain/entities/completion_request.dart` | ISSUES | t1-feat-learning | Hand-written, not @freezed, unlike sibling CompletionCommand in same dir. |
| `learning_tracker/lib/features/learning/domain/entities/completion_source.dart` | SOUND | t1-feat-learning | Checked tier-credit getters; consumed via exhaustive switches elsewhere. |
| `learning_tracker/lib/features/learning/domain/entities/completion_tier_filter.dart` | SOUND | t1-feat-learning | Plain documented enum, no logic to break. |
| `learning_tracker/lib/features/learning/domain/entities/mark_completion_result.dart` | SOUND | t1-feat-learning | Small DTO; checked for dangling refs, none in this file itself. |
| `learning_tracker/lib/features/learning/domain/repositories/.gitkeep` | SOUND | t1-feat-learning | Empty placeholder file, no content. |
| `learning_tracker/lib/features/learning/domain/repositories/bookmark_repository.dart` | SOUND | t1-feat-learning | Clean interface, doc-only; no violations. |
| `learning_tracker/lib/features/learning/domain/repositories/completion_repository.dart` | SOUND | t1-feat-learning | Interface clean; StageProgressionException message-shape inherited from repo-wide base. |
| `learning_tracker/lib/features/learning/domain/repositories/learning_ledger_repository.dart` | SOUND | t1-feat-learning | Interface clean; ChildSelfMarkException shape inherited, not batch-local. |
| `learning_tracker/lib/features/learning/domain/repositories/track_repository.dart` | SOUND | t1-feat-learning | Tiny interface + documented back-compat re-export; no violations. |
| `learning_tracker/lib/features/learning/domain/services/completion_detection_service.dart` | SOUND | t1-feat-learning | Checked N+1 fix, curriculum-aware scope strings, documented fire-and-forget tradeoff. |
| `learning_tracker/lib/features/learning/domain/use_cases/.gitkeep` | SOUND | t1-feat-learning | Empty placeholder file, no content. |
| `learning_tracker/lib/features/learning/domain/use_cases/bulk_mark_completion_use_case.dart` | SOUND | t1-feat-learning | Checked sentinel-date enforcement and B1 telemetry; no violations. |
| `learning_tracker/lib/features/learning/domain/use_cases/manual_completion_use_case.dart` | SOUND | t1-feat-learning | Checked child self-mark permission gate; no violations. |
| `learning_tracker/lib/features/learning/domain/use_cases/mark_completion_use_case.dart` | ISSUES | t1-feat-learning | export re-exports completion_source.dart, an unsanctioned barrel. |
| `learning_tracker/lib/features/learning/learning.dart` | SOUND | t1-feat-learning | Stub barrel, unpopulated; consistent with baselined Rule 2 backlog. |
| `learning_tracker/lib/features/learning/presentation/providers/.gitkeep` | SOUND | t1-feat-learning | Empty placeholder file, no content. |
| `learning_tracker/lib/features/learning/presentation/providers/bookmark_providers.dart` | SOUND | t1-feat-learning | Checked SM-2/3 compliance, ref.read confined to callbacks; no violations. |
| `learning_tracker/lib/features/learning/presentation/providers/completion_providers.dart` | SOUND | t1-feat-learning | Correct @riverpod DI incl. CompletionDetectionService; no violations. |
| `learning_tracker/lib/features/learning/presentation/providers/completion_writer_providers.dart` | ISSUES | t1-feat-learning | CompletionCommitted keepAlive:true lacks inline justification comment. |
| `learning_tracker/lib/features/learning/presentation/providers/learning_ledger_providers.dart` | SOUND | t1-feat-learning | Checked PIN-session gating threaded into both providers; no violations. |
| `learning_tracker/lib/features/learning/presentation/providers/optimistic_completion_provider.dart` | ISSUES | t1-feat-learning | OptimisticCompletionState keepAlive:true lacks inline justification comment. |
| `learning_tracker/lib/features/learning/presentation/providers/track_providers.dart` | SOUND | t1-feat-learning | Small, clean @riverpod DI; no violations. |
| `learning_tracker/lib/features/learning/presentation/screens/.gitkeep` | SOUND | t1-feat-learning | Empty placeholder file; nothing to audit. |
| `learning_tracker/lib/features/learning/presentation/screens/learning_screen.dart` | ISSUES | t1-feat-learning | Cross-feature deep imports bypass barrels, unmirrored RTL chevron, 670 lines over AG-3 cap. |
| `learning_tracker/lib/features/learning/presentation/widgets/.gitkeep` | SOUND | t1-feat-learning | Empty placeholder file; nothing to audit. |
| `learning_tracker/lib/features/learning/presentation/widgets/completion_animation.dart` | ISSUES | t1-feat-learning | Dead code: zero references anywhere outside its own file. |
| `learning_tracker/lib/features/learning/presentation/widgets/completion_feedback_controller.dart` | ISSUES | t1-feat-learning | Dead code: only constructed from an isolated story-acceptance test. |
| `learning_tracker/lib/features/notifications/data/data_sources/.gitkeep` | SOUND | t1-feat-notifications | Empty placeholder directory marker, no content to violate. |
| `learning_tracker/lib/features/notifications/data/models/.gitkeep` | SOUND | t1-feat-notifications | Empty placeholder directory marker, no content to violate. |
| `learning_tracker/lib/features/notifications/data/repositories/.gitkeep` | SOUND | t1-feat-notifications | Empty placeholder directory marker, no content to violate. |
| `learning_tracker/lib/features/notifications/data/repositories/shared_prefs_notification_preferences_repository.dart` | ISSUES | t1-feat-notifications | Correct implementation, but never constructed anywhere in lib/ — entirely dead. |
| `learning_tracker/lib/features/notifications/data/services/sacred_window_repository.dart` | ISSUES | t1-feat-notifications | Cross-feature deep import; unawaited non-transactional clear+insert race. |
| `learning_tracker/lib/features/notifications/domain/entities/.gitkeep` | SOUND | t1-feat-notifications | Empty placeholder directory marker, no content to violate. |
| `learning_tracker/lib/features/notifications/domain/models/reminder_preferences.dart` | ISSUES | t1-feat-notifications | Hand-rolled ==/hashCode/copyWith instead of @freezed; fields otherwise consistent. |
| `learning_tracker/lib/features/notifications/domain/repositories/.gitkeep` | SOUND | t1-feat-notifications | Empty placeholder directory marker, no content to violate. |
| `learning_tracker/lib/features/notifications/domain/repositories/notification_preferences_repository.dart` | SOUND | t1-feat-notifications | Static key-namespacing helpers checked, correctly used everywhere; load/save unused (see impl finding). |
| `learning_tracker/lib/features/notifications/domain/services/notification_gateway.dart` | ISSUES | t1-feat-notifications | Live per-profile scheduling sound; ~150 lines of dead legacy singleton API. |
| `learning_tracker/lib/features/notifications/domain/services/notification_initializer.dart` | ISSUES | t1-feat-notifications | Log-less catch silently swallows timezone-detection failure; tap routing otherwise correct. |
| `learning_tracker/lib/features/notifications/domain/services/notification_scheduler.dart` | ISSUES | t1-feat-notifications | Live per-profile path sound; schedule()/cancel() wrappers call dead gateway methods. |
| `learning_tracker/lib/features/notifications/domain/services/streak_alert_service.dart` | ISSUES | t1-feat-notifications | Injectable clock, per-profile IDs correct; unreachable hardcoded English fallback title. |
| `learning_tracker/lib/features/notifications/domain/use_cases/.gitkeep` | SOUND | t1-feat-notifications | Empty placeholder directory marker, no content to violate. |
| `learning_tracker/lib/features/notifications/notifications.dart` | SOUND | t1-feat-notifications | Empty stub barrel (Wave 5 placeholder), consistent with sibling features. |
| `learning_tracker/lib/features/notifications/presentation/providers/.gitkeep` | SOUND | t1-feat-notifications | Empty placeholder directory marker, no content to violate. |
| `learning_tracker/lib/features/notifications/presentation/providers/notification_providers.dart` | DEFECTIVE | t1-feat-notifications | HOTSPOT: SM-4 unguarded ref-after-await, SM-2 build race (confirmed StateError), dead repo, client-clock LWW, SM-7 dup construction. |
| `learning_tracker/lib/features/notifications/presentation/screens/.gitkeep` | SOUND | t1-feat-notifications | Empty placeholder directory marker, no content to violate. |
| `learning_tracker/lib/features/notifications/presentation/screens/notifications_screen.dart` | ISSUES | t1-feat-notifications | Good a11y/l10n structure; 12 hardcoded hex Color literals bypass theme tokens. |
| `learning_tracker/lib/features/notifications/presentation/widgets/.gitkeep` | SOUND | t1-feat-notifications | Empty placeholder directory marker, no content to violate. |
| `learning_tracker/lib/features/notifications/presentation/widgets/device_notification_toggle.dart` | ISSUES | t1-feat-notifications | Good async/mounted widget hygiene; 3 hardcoded hex Color literals bypass theme. |
| `learning_tracker/lib/features/notifications/presentation/widgets/timezone_lifecycle_observer.dart` | ISSUES | t1-feat-notifications | Log-less catch on timezone re-detect; zero test coverage of this class anywhere. |
| `learning_tracker/lib/features/onboarding/data/data_sources/.gitkeep` | SOUND | t1-feat-onboarding | 0-byte empty-dir placeholder, no content to audit |
| `learning_tracker/lib/features/onboarding/data/models/.gitkeep` | SOUND | t1-feat-onboarding | 0-byte empty-dir placeholder, no content to audit |
| `learning_tracker/lib/features/onboarding/data/repositories/.gitkeep` | SOUND | t1-feat-onboarding | 0-byte empty-dir placeholder, no content to audit |
| `learning_tracker/lib/features/onboarding/domain/entities/.gitkeep` | SOUND | t1-feat-onboarding | 0-byte empty-dir placeholder, no content to audit |
| `learning_tracker/lib/features/onboarding/domain/models/wizard_result_wrapper.dart` | SOUND | t1-feat-onboarding | 10-line domain wrapper, correct layering comment, no logic |
| `learning_tracker/lib/features/onboarding/domain/repositories/.gitkeep` | SOUND | t1-feat-onboarding | 0-byte empty-dir placeholder, no content to audit |
| `learning_tracker/lib/features/onboarding/domain/services/bulk_prior_completion_service.dart` | ISSUES | t1-feat-onboarding | AG-3 443 lines; untransacted expunge writes; ad-hoc repo ctor |
| `learning_tracker/lib/features/onboarding/domain/services/curriculum_import_service.dart` | SOUND | t1-feat-onboarding | checked EH-2/EH-3 boundary, no hardcoded UI text, clean |
| `learning_tracker/lib/features/onboarding/domain/services/learning_process_wizard_service.dart` | ISSUES | t1-feat-onboarding | DB-2: bypasses StageDao's own transactional replace helper |
| `learning_tracker/lib/features/onboarding/domain/services/user_profile_service.dart` | SOUND | t1-feat-onboarding | DI clean, no direct Firebase import, no violations found |
| `learning_tracker/lib/features/onboarding/domain/use_cases/.gitkeep` | SOUND | t1-feat-onboarding | 0-byte empty-dir placeholder, no content to audit |
| `learning_tracker/lib/features/onboarding/domain/validators/auth_validators.dart` | ISSUES | t1-feat-onboarding | 3 hardcoded English validator messages, live in signup form |
| `learning_tracker/lib/features/onboarding/onboarding.dart` | ISSUES | t1-feat-onboarding | empty non-functional barrel; repo-wide W1.10 gap, baselined |
| `learning_tracker/lib/features/onboarding/presentation/providers/.gitkeep` | SOUND | t1-feat-onboarding | 0-byte empty-dir placeholder, no content to audit |
| `learning_tracker/lib/features/onboarding/presentation/providers/onboarding_controller.dart` | ISSUES | t1-feat-onboarding | advance() touches state post-await with no ref.mounted check |
| `learning_tracker/lib/features/onboarding/presentation/providers/onboarding_providers.dart` | SOUND | t1-feat-onboarding | legacy Provider() style but cannot prove new vs SM-1 backlog |
| `learning_tracker/lib/features/onboarding/presentation/providers/onboarding_resume_store.dart` | SOUND | t1-feat-onboarding | save/load/clear key symmetry checked, no violations |
| `learning_tracker/lib/features/onboarding/presentation/screens/.gitkeep` | SOUND | t1-feat-onboarding | 0-byte empty-dir placeholder, no content to audit |
| `learning_tracker/lib/features/onboarding/presentation/screens/app_intro_screen.dart` | ISSUES | t1-feat-onboarding | AG-3 535 lines; 2 vestigial dead-code English defaults |
| `learning_tracker/lib/features/onboarding/presentation/screens/bulk_mark_screen.dart` | DEFECTIVE | t1-feat-onboarding | AG-3 744 lines; 5 raw strings; log-less catch; missing mounted checks; race |
| `learning_tracker/lib/features/onboarding/presentation/screens/empty_login_screen.dart` | ISSUES | t1-feat-onboarding | PF-3: getAllAccounts() future rebuilt inline every build() |
| `learning_tracker/lib/features/onboarding/presentation/screens/learning_process_wizard_screen.dart` | SOUND | t1-feat-onboarding | mounted/l10n checked; confirms controller advance() call site |
| `learning_tracker/lib/features/onboarding/presentation/screens/onboarding_screen.dart` | ISSUES | t1-feat-onboarding | AG-3 495 lines; 6 hardcoded AppBar titles; lifecycle otherwise exemplary |
| `learning_tracker/lib/features/onboarding/presentation/screens/permission_prompt_screen.dart` | SOUND | t1-feat-onboarding | fully localized; correct mounted-check after every await |
| `learning_tracker/lib/features/onboarding/presentation/steps/onboarding_add_another_prompt_step.dart` | ISSUES | t1-feat-onboarding | 2 hardcoded strings (headline + manual pluralization) |
| `learning_tracker/lib/features/onboarding/presentation/steps/onboarding_done_step.dart` | SOUND | t1-feat-onboarding | trivial, fully localized, no logic to break |
| `learning_tracker/lib/features/onboarding/presentation/steps/onboarding_handoff_step.dart` | ISSUES | t1-feat-onboarding | 4 of 5 text strings hardcoded English on child hand-off screen |
| `learning_tracker/lib/features/onboarding/presentation/steps/onboarding_parent_pin_step.dart` | DEFECTIVE | t1-feat-onboarding | zero l10n import; raw exception message shown as UI error |
| `learning_tracker/lib/features/onboarding/presentation/steps/onboarding_profile_creation_step.dart` | ISSUES | t1-feat-onboarding | AG-3 550 lines; 1 string hardcoded x2; 1 missing mounted-check |
| `learning_tracker/lib/features/onboarding/presentation/steps/onboarding_step.dart` | SOUND | t1-feat-onboarding | clean abstract interface, Ref-based, Feathers-testable |
| `learning_tracker/lib/features/onboarding/presentation/steps/wizard_steps.dart` | DEFECTIVE | t1-feat-onboarding | AG-3 807 lines; ~19 hardcoded strings incl. mixed-language day bug |
| `learning_tracker/lib/features/onboarding/presentation/widgets/.gitkeep` | SOUND | t1-feat-onboarding | 0-byte empty-dir placeholder, no content to audit |
| `learning_tracker/lib/features/onboarding/presentation/widgets/glowing_cta_button.dart` | SOUND | t1-feat-onboarding | pure presentational widget, no hardcoded text, const-friendly |
| `learning_tracker/lib/features/onboarding/presentation/widgets/intro_daily_plan_page.dart` | SOUND | t1-feat-onboarding | correct AlignmentDirectional/EdgeInsetsDirectional; text localized |
| `learning_tracker/lib/features/onboarding/presentation/widgets/intro_mishna_page.dart` | ISSUES | t1-feat-onboarding | Hardcoded non-ARB '…yos' text; raw Color literals; Positioned(left/right) in illustration |
| `learning_tracker/lib/features/onboarding/presentation/widgets/intro_page_indicator.dart` | ISSUES | t1-feat-onboarding | Clean 40-line widget; only raw Color literals (2) outside theme |
| `learning_tracker/lib/features/onboarding/presentation/widgets/intro_rewards_page.dart` | ISSUES | t1-feat-onboarding | 418 lines (AG-3); 11 raw Color literals; Positioned(left/right) badges |
| `learning_tracker/lib/features/profiles/data/repositories/profile_repository_impl.dart` | ISSUES | t1-feat-profiles | 3 log-less catch(_) around sync push; deleteProfile's sync push unguarded unlike siblings |
| `learning_tracker/lib/features/profiles/domain/models/profile_model.dart` | SOUND | t1-feat-profiles | checked @freezed model, defensive profileMode fallback, clean Drift row mapper |
| `learning_tracker/lib/features/profiles/domain/models/profile_session.dart` | ISSUES | t1-feat-profiles | hand-written ==/hashCode instead of @freezed (naming/placement invariant) |
| `learning_tracker/lib/features/profiles/domain/repositories/profile_repository.dart` | SOUND | t1-feat-profiles | checked interface contract; exceptions typed (Validation/Conflict), invariants documented |
| `learning_tracker/lib/features/profiles/domain/services/pin_flow_machine.dart` | DEFECTIVE | t1-feat-profiles | 340-line PinFlowMachine: zero imports anywhere in lib/ or test/, fully dead |
| `learning_tracker/lib/features/profiles/domain/services/pin_service.dart` | SOUND | t1-feat-profiles | checked bcrypt hashing, TOCTOU-safe lockout write order, parent/tutor key isolation |
| `learning_tracker/lib/features/profiles/domain/use_cases/profile_creation_use_case.dart` | DEFECTIVE | t1-feat-profiles | zero callers outside its own test file; dead code, atomic-seed logic never runs |
| `learning_tracker/lib/features/profiles/domain/use_cases/set_parent_pin_use_case.dart` | DEFECTIVE | t1-feat-profiles | zero callers and zero tests anywhere in repo; fully dead |
| `learning_tracker/lib/features/profiles/domain/use_cases/verify_parent_pin_use_case.dart` | DEFECTIVE | t1-feat-profiles | zero callers and zero tests anywhere in repo; fully dead |
| `learning_tracker/lib/features/profiles/presentation/providers/active_profile_provider.dart` | SOUND | t1-feat-profiles | checked chokepoint logic, correct ref.watch-in-build, tutored-mirror fallback |
| `learning_tracker/lib/features/profiles/presentation/providers/parent_dashboard_providers.dart` | SOUND | t1-feat-profiles | checked; trivial composition, correct watch usage, no side effects |
| `learning_tracker/lib/features/profiles/presentation/providers/parent_pin_session_provider.dart` | SOUND | t1-feat-profiles | checked; simple keepAlive notifier, confirmed live call sites across app |
| `learning_tracker/lib/features/profiles/presentation/providers/pin_flow_controller.dart` | ISSUES | t1-feat-profiles | missing ref.mounted after 4 awaits; change/verify modes unreachable in prod; dup enum names; 416 lines |
| `learning_tracker/lib/features/profiles/presentation/providers/profile_providers.dart` | ISSUES | t1-feat-profiles | autoSelectedProfileId's build() writes DB rows + mutates sibling providers (SM-2) |
| `learning_tracker/lib/features/profiles/presentation/screens/manage_learners_screen.dart` | SOUND | t1-feat-profiles | checked; correctly delegates to canonical edit/delete flow, no duplicate logic |
| `learning_tracker/lib/features/profiles/presentation/screens/parent_settings_screen.dart` | ISSUES | t1-feat-profiles | 612 lines exceeds AG-3 cap; permission-gating logic and l10n coverage otherwise clean |
| `learning_tracker/lib/features/profiles/presentation/screens/parent_track_management_screen.dart` | ISSUES | t1-feat-profiles | EdgeInsets.only(left:/right:) instead of Directional (AX-1), one site |
| `learning_tracker/lib/features/profiles/presentation/screens/pin_flow_screen.dart` | ISSUES | t1-feat-profiles | depends on PinFlowController's unreachable change/verify modes; fragile string-matched error fallbacks |
| `learning_tracker/lib/features/profiles/presentation/screens/profile_picker_screen.dart` | DEFECTIVE | t1-feat-profiles | HOTSPOT; reimplements rename/delete with hardcoded EN strings + missing mounted guard; 539 lines |
| `learning_tracker/lib/features/profiles/presentation/widgets/add_profile_card.dart` | SOUND | t1-feat-profiles | checked custom dashed painters, l10n coverage, disabled-state handling |
| `learning_tracker/lib/features/profiles/presentation/widgets/add_profile_dialog.dart` | ISSUES | t1-feat-profiles | log-less catch on live duplicate-name check; unexpected-error path elsewhere logs correctly |
| `learning_tracker/lib/features/profiles/presentation/widgets/add_profile_mode_pick_card.dart` | SOUND | t1-feat-profiles | checked; static selectable card, no logic issues found |
| `learning_tracker/lib/features/profiles/presentation/widgets/my_children_section.dart` | SOUND | t1-feat-profiles | checked; thin composition wrapper, l10n-covered header, AlignmentDirectional used |
| `learning_tracker/lib/features/profiles/presentation/widgets/parent_mode_dialog_frame.dart` | SOUND | t1-feat-profiles | checked; scroll-safe dialog chrome, correct AlignmentDirectional usage |
| `learning_tracker/lib/features/profiles/presentation/widgets/parent_pin_keypad_dialog.dart` | DEFECTIVE | t1-feat-profiles | 635 lines (AG-3); independently duplicates PinFlowController's verify/change state machine |
| `learning_tracker/lib/features/profiles/presentation/widgets/parent_pin_setup_dialog.dart` | ISSUES | t1-feat-profiles | duplicates PinFlowController's setup state machine; unchecked e.message cast |
| `learning_tracker/lib/features/profiles/presentation/widgets/profile_avatar.dart` | SOUND | t1-feat-profiles | checked; trivial deterministic index-to-color/icon mapping, no issues |
| `learning_tracker/lib/features/profiles/presentation/widgets/profile_card.dart` | SOUND | t1-feat-profiles | checked; decorative badge correctly wrapped in ExcludeSemantics |
| `learning_tracker/lib/features/profiles/presentation/widgets/profile_edit_delete_actions.dart` | ISSUES | t1-feat-profiles | canonical flow correct/i18n-clean, but ProfileEditFormDialog doc comment is stale post-PP-2 |
| `learning_tracker/lib/features/profiles/presentation/widgets/profile_grid.dart` | SOUND | t1-feat-profiles | checked; simple grid composition over ProfileCard/AddProfileCard, no issues |
| `learning_tracker/lib/features/profiles/presentation/widgets/profile_switcher_sheet.dart` | ISSUES | t1-feat-profiles | 457 lines (AG-3); new PIN-guard provider uses legacy FutureProvider, misplaced in widget file |
| `learning_tracker/lib/features/profiles/presentation/widgets/tutored_children_section.dart` | DEFECTIVE | t1-feat-profiles | 5 cross-feature deep imports bypass working tutoring.dart barrel; checker never catches this |
| `learning_tracker/lib/features/profiles/profiles.dart` | DEFECTIVE | t1-feat-profiles | Barrel exports nothing; 65 files repo-wide deep-import profiles/ instead of this barrel |
| `learning_tracker/lib/features/progress/data/data_sources/.gitkeep` | SOUND | t1-feat-progress | Empty placeholder, keeps directory tracked; nothing to audit. |
| `learning_tracker/lib/features/progress/data/models/.gitkeep` | SOUND | t1-feat-progress | Empty placeholder, keeps directory tracked; nothing to audit. |
| `learning_tracker/lib/features/progress/data/repositories/.gitkeep` | SOUND | t1-feat-progress | Empty placeholder, keeps directory tracked; nothing to audit. |
| `learning_tracker/lib/features/progress/data/repositories/progress_repository_impl.dart` | SOUND | t1-feat-progress | Read-only DAO delegate, profile-scoped, no writes/catches; SM-7/8 clean. |
| `learning_tracker/lib/features/progress/domain/entities/.gitkeep` | SOUND | t1-feat-progress | Empty placeholder, keeps directory tracked; nothing to audit. |
| `learning_tracker/lib/features/progress/domain/models/chart_data.dart` | SOUND | t1-feat-progress | Plain immutable chart value types and enums; no logic to break. |
| `learning_tracker/lib/features/progress/domain/models/curriculum_progress_data.dart` | ISSUES | t1-feat-progress | levelLabel field computed but never consumed by any widget (dead). |
| `learning_tracker/lib/features/progress/domain/models/journey_view_model.dart` | SOUND | t1-feat-progress | Correct @freezed models; doc comments match fields; no issues. |
| `learning_tracker/lib/features/progress/domain/models/lifetime_knowledge.dart` | ISSUES | t1-feat-progress | LifetimeLeafProvenance hand-rolls ==/hashCode instead of @freezed. |
| `learning_tracker/lib/features/progress/domain/repositories/.gitkeep` | SOUND | t1-feat-progress | Empty placeholder, keeps directory tracked; nothing to audit. |
| `learning_tracker/lib/features/progress/domain/repositories/progress_repository.dart` | SOUND | t1-feat-progress | Minimal abstract interface, matches impl 1:1; checked in full. |
| `learning_tracker/lib/features/progress/domain/services/chart_data_service.dart` | ISSUES | t1-feat-progress | 697 lines (AG-3); getDailyCompletionsLive/getCumulativeProgressLive are byte-identical duplicates. |
| `learning_tracker/lib/features/progress/domain/services/curriculum_progress_service.dart` | SOUND | t1-feat-progress | Pure static computation, no I/O; D12 stageOrder fix documented. |
| `learning_tracker/lib/features/progress/domain/services/lifetime_tree_builder.dart` | ISSUES | t1-feat-progress | 466 lines (AG-3); its engine is duplicated (unguarded) in items_learned_providers.dart. |
| `learning_tracker/lib/features/progress/domain/services/overlapping_curricula_deduplicator.dart` | SOUND | t1-feat-progress | 33-line pure set-union service; checked in full, no issues. |
| `learning_tracker/lib/features/progress/domain/services/pace_calculator.dart` | ISSUES | t1-feat-progress | Hand-rolled ==/hashCode/toString instead of @freezed. |
| `learning_tracker/lib/features/progress/domain/use_cases/.gitkeep` | SOUND | t1-feat-progress | Empty placeholder, keeps directory tracked; nothing to audit. |
| `learning_tracker/lib/features/progress/presentation/providers/.gitkeep` | SOUND | t1-feat-progress | Empty placeholder, keeps directory tracked; nothing to audit. |
| `learning_tracker/lib/features/progress/presentation/providers/chart_providers.dart` | SOUND | t1-feat-progress | 11-line provider; correct SM-7 construction-inside-provider pattern. |
| `learning_tracker/lib/features/progress/presentation/providers/items_learned_providers.dart` | DEFECTIVE | t1-feat-progress | Duplicates lifetime_tree_builder minus P0 guard; 3 log-less catches; AG-3. |
| `learning_tracker/lib/features/progress/presentation/providers/journey_providers.dart` | SOUND | t1-feat-progress | Pure @riverpod providers; F22/F24 fixes documented; checked in full. |
| `learning_tracker/lib/features/progress/presentation/providers/lifetime_knowledge_providers.dart` | DEFECTIVE | t1-feat-progress | AG-3 HOTSPOT; holds the P0 guard but has 2 sibling log-less catches. |
| `learning_tracker/lib/features/progress/presentation/providers/progress_lens_refresh_tick_provider.dart` | SOUND | t1-feat-progress | 80-line tick notifier; cross-tree refresh pattern well documented. |
| `learning_tracker/lib/features/progress/presentation/providers/progress_providers.dart` | SOUND | t1-feat-progress | 263 lines, @riverpod; F2/F5/Rule-7 fixes documented; no violations found. |
| `learning_tracker/lib/features/progress/presentation/providers/recent_activity_providers.dart` | ISSUES | t1-feat-progress | RecentActivityWindow hand-rolls ==/hashCode instead of a record. |
| `learning_tracker/lib/features/progress/presentation/screens/.gitkeep` | SOUND | t1-feat-progress | Empty placeholder, keeps directory tracked; nothing to audit. |
| `learning_tracker/lib/features/progress/presentation/screens/curriculum_progress_screen.dart` | ISSUES | t1-feat-progress | Hardcoded 'Curriculum settings' tooltip; error.toString() leaks to UI. |
| `learning_tracker/lib/features/progress/presentation/screens/lifetime_knowledge_screen.dart` | ISSUES | t1-feat-progress | Default tab reaches the items_learned P0 gap; error.toString() leaks x2. |
| `learning_tracker/lib/features/progress/presentation/screens/progress_screen.dart` | ISSUES | t1-feat-progress | 416 lines AG-3 HOTSPOT; error.toString() leaks x2; otherwise clean. |
| `learning_tracker/lib/features/progress/presentation/screens/recent_activity_screen.dart` | ISSUES | t1-feat-progress | 792 lines AG-3; back IconButton has no semantic label (AX-3). |
| `learning_tracker/lib/features/progress/presentation/screens/siyumim_milestones_screen.dart` | ISSUES | t1-feat-progress | error.toString() leak; otherwise clean, well-localized screen. |
| `learning_tracker/lib/features/progress/presentation/widgets/.gitkeep` | SOUND | t1-feat-progress | Empty placeholder, keeps directory tracked; nothing to audit. |
| `learning_tracker/lib/features/progress/presentation/widgets/cumulative_line_chart.dart` | ISSUES | t1-feat-progress | 2 raw Color(0x..) literals bypass theme tokens in gradient stops. |
| `learning_tracker/lib/features/progress/presentation/widgets/curriculum_breakdown_list.dart` | ISSUES | t1-feat-progress | 413 lines exceeds AG-3 400-line cap; l10n/layering/SM otherwise clean. |
| `learning_tracker/lib/features/progress/presentation/widgets/hierarchy_progress_card.dart` | SOUND | t1-feat-progress | Checked theme tokens, l10n, ref.watch usage, switch exhaustiveness — clean. |
| `learning_tracker/lib/features/progress/presentation/widgets/lifetime_folder_styled_widgets.dart` | ISSUES | t1-feat-progress | 650-line god-file (10 top-level symbols), 15 Color literals, unlabeled IconButton. |
| `learning_tracker/lib/features/progress/presentation/widgets/limudim_chazaros_bar_chart.dart` | ISSUES | t1-feat-progress | 3 raw Color(0x..) literals bypass theme; l10n/layering otherwise clean. |
| `learning_tracker/lib/features/progress/presentation/widgets/monthly_activity_sliver_calendar.dart` | ISSUES | t1-feat-progress | Dead spike widget: unlocalized strings, duplicate class name, 404 lines. |
| `learning_tracker/lib/features/progress/presentation/widgets/overall_stats_card.dart` | SOUND | t1-feat-progress | Checked theme tokens, l10n; no color literals or layering issues found. |
| `learning_tracker/lib/features/progress/presentation/widgets/pace_indicator.dart` | ISSUES | t1-feat-progress | Duplicate class name vs scheduler/presentation/widgets/pace_indicator.dart. |
| `learning_tracker/lib/features/progress/presentation/widgets/points_over_time_chart.dart` | ISSUES | t1-feat-progress | 1 raw Color(0x..) literal bypasses theme; otherwise clean. |
| `learning_tracker/lib/features/progress/presentation/widgets/progress_tier_counter_row.dart` | ISSUES | t1-feat-progress | 2 raw Color(0x..) literals; good Semantics usage elsewhere in file. |
| `learning_tracker/lib/features/progress/presentation/widgets/siyum_milestone_label.dart` | SOUND | t1-feat-progress | Pure label functions, proper domainTermLabels delegation, exhaustive switches. |
| `learning_tracker/lib/features/progress/presentation/widgets/siyumim_grouped_view.dart` | ISSUES | t1-feat-progress | 437 lines (AG-3); deep cross-feature import bypasses content_browsing barrel. |
| `learning_tracker/lib/features/progress/presentation/widgets/siyumim_timeline_view.dart` | SOUND | t1-feat-progress | Intra-feature import of sibling widget is Rule-2-exempt; l10n/theme clean. |
| `learning_tracker/lib/features/progress/presentation/widgets/stage_breakdown_row.dart` | SOUND | t1-feat-progress | Small, well-commented dedupe logic; domainTermLabels routing correct. |
| `learning_tracker/lib/features/progress/presentation/widgets/streak_calendar.dart` | ISSUES | t1-feat-progress | 2 raw Color(0x..) literals, one an exact duplicate of another file's. |
| `learning_tracker/lib/features/progress/progress.dart` | SOUND | t1-feat-progress | Barrel exports only ProgressTierCounterRow with documented external consumer. |
| `learning_tracker/lib/features/sacred_time/data/services/cities_repository.dart` | ISSUES | t1-feat-sacred_time | parameterized SQL is safe; no error typing — raw DB/IO exceptions reach the UI unconverted. |
| `learning_tracker/lib/features/sacred_time/data/services/location_service.dart` | ISSUES | t1-feat-sacred_time | catches `on Object` (traps Errors) and wraps failures as raw e.toString() text. |
| `learning_tracker/lib/features/sacred_time/data/services/sacred_time_preferences.dart` | SOUND | t1-feat-sacred_time | checked null/partial-data guards, stale-key removal on null fields, UTC round-trip. |
| `learning_tracker/lib/features/sacred_time/domain/models/city.dart` | SOUND | t1-feat-sacred_time | freezed immutable model, no hand-rolled ==/hashCode, nothing to break. |
| `learning_tracker/lib/features/sacred_time/domain/models/sacred_location.dart` | SOUND | t1-feat-sacred_time | freezed immutable model, shape matches sacred_time_preferences' persisted fields. |
| `learning_tracker/lib/features/sacred_time/domain/models/sacred_window.dart` | SOUND | t1-feat-sacred_time | freezed immutable model, UTC-documented bounds, closed enum kind. |
| `learning_tracker/lib/features/sacred_time/domain/services/zmanim_window_service.dart` | ISSUES | t1-feat-sacred_time | polar-fallback candle-lighting/tzais use device tz not target location's; untested branch. |
| `learning_tracker/lib/features/sacred_time/presentation/providers/cities_provider.dart` | ISSUES | t1-feat-sacred_time | keepAlive provider missing the required `// keepAlive:` justification comment. |
| `learning_tracker/lib/features/sacred_time/presentation/providers/sacred_location_provider.dart` | DEFECTIVE | t1-feat-sacred_time | ref.mounted unguarded post-await in 4 methods; deep cross-feature import; keepAlive comments missing. |
| `learning_tracker/lib/features/sacred_time/presentation/providers/sacred_windows_provider.dart` | ISSUES | t1-feat-sacred_time | Timer cancel-on-dispose pattern is correct; keepAlive comments missing x2. |
| `learning_tracker/lib/features/sacred_time/presentation/screens/city_picker_screen.dart` | DEFECTIVE | t1-feat-sacred_time | hardcoded English idle-hint never localized; raw e.toString() shown as search error. |
| `learning_tracker/lib/features/sacred_time/presentation/widgets/sacred_time_lock_overlay.dart` | ISSUES | t1-feat-sacred_time | exhaustive sealed switches correct; raw Color() literals bypass theme tokens. |
| `learning_tracker/lib/features/sacred_time/presentation/widgets/sacred_time_settings_card.dart` | ISSUES | t1-feat-sacred_time | imports data/location_service.dart for types (layering); raw Color() literals. |
| `learning_tracker/lib/features/sacred_time/sacred_time.dart` | ISSUES | t1-feat-sacred_time | barrel exports nothing; 7 external files deep-import around it, undetected by tooling. |
| `learning_tracker/lib/features/scheduler/data/data_sources/.gitkeep` | SOUND | t1-feat-scheduler | Empty placeholder (0 lines); nothing to audit. |
| `learning_tracker/lib/features/scheduler/data/models/.gitkeep` | SOUND | t1-feat-scheduler | Empty placeholder (0 lines); nothing to audit. |
| `learning_tracker/lib/features/scheduler/data/repositories/.gitkeep` | SOUND | t1-feat-scheduler | Empty placeholder (0 lines); nothing to audit. |
| `learning_tracker/lib/features/scheduler/data/repositories/daily_plan_repository.dart` | ISSUES | t1-feat-scheduler | Sound snapshot/transaction logic and batch insertOrIgnore; unguarded CurriculumId.firstWhere can crash a read (F8). |
| `learning_tracker/lib/features/scheduler/data/repositories/goal_repository_impl.dart` | DEFECTIVE | t1-feat-scheduler | Consumes firestoreId reuse bug on update (F2); no profileId ownership check (F3); unguarded firstWhere (F8). |
| `learning_tracker/lib/features/scheduler/data/repositories/scheduler_completion_repository_impl.dart` | ISSUES | t1-feat-scheduler | profileId-scoped correctly (good contrast to F1); resolveStageOrder id/stageOrder collision risk (F5). |
| `learning_tracker/lib/features/scheduler/data/repositories/scheduler_content_repository_impl.dart` | SOUND | t1-feat-scheduler | Thin pure adapter (filter/sort/map); checked against its 12 dedicated unit tests. |
| `learning_tracker/lib/features/scheduler/data/repositories/scheduler_learning_order_repository_impl.dart` | DEFECTIVE | t1-feat-scheduler | Never scopes getOrder by profileId — cross-profile custom-order leak into daily plan (F1). |
| `learning_tracker/lib/features/scheduler/data/repositories/scheduler_stage_repository_impl.dart` | DEFECTIVE | t1-feat-scheduler | Log-less catch swallows bad schedule JSON (F6); deep-imports tracks/ bypassing the barrel (F4). |
| `learning_tracker/lib/features/scheduler/data/repositories/study_day_config_repository_impl.dart` | SOUND | t1-feat-scheduler | Every method correctly threads the required profileId through the DAO. |
| `learning_tracker/lib/features/scheduler/domain/entities/.gitkeep` | SOUND | t1-feat-scheduler | Empty placeholder (0 lines); nothing to audit. |
| `learning_tracker/lib/features/scheduler/domain/labels/program_label_resolver.dart` | ISSUES | t1-feat-scheduler | Correct label logic, but Flutter/Riverpod/l10n-coupled; forces every test through pumpWidget (F7). |
| `learning_tracker/lib/features/scheduler/domain/models/daily_task.dart` | SOUND | t1-feat-scheduler | Clean @freezed model; priority enum and every field documented. |
| `learning_tracker/lib/features/scheduler/domain/models/day_type.dart` | ISSUES | t1-feat-scheduler | fromStorageKey has no orElse fallback — throws on an unknown key (F8). |
| `learning_tracker/lib/features/scheduler/domain/models/delta_value.dart` | ISSUES | t1-feat-scheduler | 4 hand-rolled ==/hashCode value classes instead of @freezed (F9). |
| `learning_tracker/lib/features/scheduler/domain/models/goal_entity.dart` | DEFECTIVE | t1-feat-scheduler | firestoreId keys on mutable targetPercent (F2 root cause); 2 hand-rolled value classes (F9). |
| `learning_tracker/lib/features/scheduler/domain/models/pace_status.dart` | SOUND | t1-feat-scheduler | Clean @freezed model; typed delta / deprecated daysDelta documented consistently. |
| `learning_tracker/lib/features/scheduler/domain/models/schedule_config.dart` | SOUND | t1-feat-scheduler | Clean @freezed config model; every field's intent documented, matches consumers. |
| `learning_tracker/lib/features/scheduler/domain/models/scheduler_analysis.dart` | SOUND | t1-feat-scheduler | Clean @freezed intermediate-result model; no logic to break. |
| `learning_tracker/lib/features/scheduler/domain/models/scheduler_input.dart` | SOUND | t1-feat-scheduler | Clean @freezed input model; strategy-selection doc comment matches its fields. |
| `learning_tracker/lib/features/scheduler/domain/models/study_day_config.dart` | SOUND | t1-feat-scheduler | Trivial 2-field @freezed entry type; no issues. |
| `learning_tracker/lib/features/scheduler/domain/models/task_assembly.dart` | SOUND | t1-feat-scheduler | Clean @freezed wrapper with length/isEmpty convenience getters; no issues. |
| `learning_tracker/lib/features/scheduler/domain/projection/overdue_projection.dart` | SOUND | t1-feat-scheduler | Pure, well-documented; disjoint-bucket logic matches its own stated contract. |
| `learning_tracker/lib/features/scheduler/domain/projection/overdue_schedule.dart` | SOUND | t1-feat-scheduler | Pure; pace-window integer-accumulator logic traced and matches documented formula/history. |
| `learning_tracker/lib/features/scheduler/domain/projection/overdue_types.dart` | ISSUES | t1-feat-scheduler | 3 hand-rolled ==/hashCode value classes instead of @freezed (F9). |
| `learning_tracker/lib/features/scheduler/domain/projection/projection.dart` | SOUND | t1-feat-scheduler | Barrel/export-only file; exports match its 3 sibling files exactly. |
| `learning_tracker/lib/features/scheduler/domain/repositories/.gitkeep` | SOUND | t1-feat-scheduler | Empty placeholder (0 lines); nothing to audit. |
| `learning_tracker/lib/features/scheduler/domain/repositories/goal_repository.dart` | ISSUES | t1-feat-scheduler | createGoal takes an explicit profileId param unlike its 3 siblings (F3). |
| `learning_tracker/lib/features/scheduler/domain/repositories/scheduler_completion_repository.dart` | ISSUES | t1-feat-scheduler | SchedulerCompletion has no equality at all — identity semantics (F9). |
| `learning_tracker/lib/features/scheduler/domain/repositories/scheduler_content_repository.dart` | ISSUES | t1-feat-scheduler | SchedulerContentItem has no equality at all — identity semantics (F9). |
| `learning_tracker/lib/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart` | DEFECTIVE | t1-feat-scheduler | getOrder(curriculumId) has no profileId parameter at all — interface root of F1. |
| `learning_tracker/lib/features/scheduler/domain/repositories/scheduler_stage_repository.dart` | ISSUES | t1-feat-scheduler | Deep-imports tracks/stages bypassing tracks.dart barrel (F4); SchedulerStage lacks equality (F9). |
| `learning_tracker/lib/features/scheduler/domain/repositories/study_day_config_repository.dart` | SOUND | t1-feat-scheduler | Clean interface; matches its impl 1:1, no extraneous surface. |
| `learning_tracker/lib/features/scheduler/domain/services/calendar_program_registry.dart` | SOUND | t1-feat-scheduler | Static const registry, 19 entries; byId/byApiKey/byHebcalCategory lookups checked correct. |
| `learning_tracker/lib/features/scheduler/domain/services/calendar_program_service.dart` | SOUND | t1-feat-scheduler | Thin delegate over LocalCalendarEngine; label routing via ProgramLabelResolver; no rule violations. |
| `learning_tracker/lib/features/scheduler/domain/services/cross_curriculum_aggregator.dart` | SOUND | t1-feat-scheduler | Pure aggregation, immutable models, no I/O; checked layering and null-handling. |
| `learning_tracker/lib/features/scheduler/domain/services/daily_schedule_composer.dart` | SOUND | t1-feat-scheduler | 22-line pure grouping helper with lazy computed field; no issues found. |
| `learning_tracker/lib/features/scheduler/domain/services/daily_task_generator.dart` | SOUND | t1-feat-scheduler | Pure orchestration wrapper over SchedulerEngine; no side effects or rule violations. |
| `learning_tracker/lib/features/scheduler/domain/services/learning_program_service.dart` | ISSUES | t1-feat-scheduler | Deprecated .instance singleton still load-bearing for 30+ tests (SM-7); see finding. |
| `learning_tracker/lib/features/scheduler/domain/services/local_calendar_engine.dart` | SOUND | t1-feat-scheduler | Careful UTC-midnight handling with documented R4-1 rationale; clean layering. |
| `learning_tracker/lib/features/scheduler/domain/services/pace_calculator.dart` | ISSUES | t1-feat-scheduler | Well-reasoned pace math; 2 TODOs lack DNI-#### id (AG-6). |
| `learning_tracker/lib/features/scheduler/domain/services/scheduler_engine.dart` | DEFECTIVE | t1-feat-scheduler | 747 lines (AG-3); delay-stage due-date math truncates on time-of-day (real bug). |
| `learning_tracker/lib/features/scheduler/domain/services/sefaria_ref_matcher.dart` | ISSUES | t1-feat-scheduler | 420 lines (AG-3); pure regex/fuzzy-match functions read correctly otherwise. |
| `learning_tracker/lib/features/scheduler/domain/use_cases/.gitkeep` | SOUND | t1-feat-scheduler | Empty placeholder file, nothing to audit. |
| `learning_tracker/lib/features/scheduler/presentation/providers/.gitkeep` | SOUND | t1-feat-scheduler | Empty placeholder file, nothing to audit. |
| `learning_tracker/lib/features/scheduler/presentation/providers/scheduler_providers.dart` | DEFECTIVE | t1-feat-scheduler | HOTSPOT, 1381 lines; misplaced domain logic, SM-2/SM-4 gap, dead code, dup helper. |
| `learning_tracker/lib/features/scheduler/presentation/providers/study_day_config_providers.dart` | ISSUES | t1-feat-scheduler | toggleStudyDay provider dead and self-documented buggy, not marked @Deprecated. |
| `learning_tracker/lib/features/scheduler/presentation/screens/.gitkeep` | SOUND | t1-feat-scheduler | Empty placeholder file, nothing to audit. |
| `learning_tracker/lib/features/scheduler/presentation/screens/goal_setup_screen.dart` | ISSUES | t1-feat-scheduler | 728 lines (AG-3, HOTSPOT); l10n and date-guard logic otherwise sound. |
| `learning_tracker/lib/features/scheduler/presentation/screens/scheduler_screen.dart` | ISSUES | t1-feat-scheduler | Wires the dead onCompleted callback and an unrendered summary; otherwise clean. |
| `learning_tracker/lib/features/scheduler/presentation/screens/study_day_config_screen.dart` | ISSUES | t1-feat-scheduler | 495 lines (AG-3); _toggleDay has no catch/log on write, inconsistent mounted-guard. |
| `learning_tracker/lib/features/scheduler/presentation/widgets/.gitkeep` | SOUND | t1-feat-scheduler | Empty placeholder file, nothing to audit. |
| `learning_tracker/lib/features/scheduler/presentation/widgets/daily_task_card.dart` | ISSUES | t1-feat-scheduler | Declares required onCompleted callback that is never invoked; AX-1/AX-2 otherwise clean. |
| `learning_tracker/lib/features/scheduler/presentation/widgets/grouped_daily_view.dart` | ISSUES | t1-feat-scheduler | Passes through the dead onTaskCompleted/onCompleted chain; otherwise sound. |
| `learning_tracker/lib/features/scheduler/presentation/widgets/hebrew_date_picker.dart` | DEFECTIVE | t1-feat-scheduler | 5 hardcoded English strings render regardless of locale (P1 AX-2). |
| `learning_tracker/lib/features/scheduler/presentation/widgets/pace_indicator.dart` | DEFECTIVE | t1-feat-scheduler | Entire widget file dead in production; duplicate PaceIndicator class name (AG-4). |
| `learning_tracker/lib/features/scheduler/scheduler.dart` | DEFECTIVE | t1-feat-scheduler | Barrel exports nothing; every cross-feature import of scheduler is structurally forced deep. |
| `learning_tracker/lib/features/settings/data/data_sources/.gitkeep` | SOUND | t1-feat-settings | Empty placeholder file (0 lines), keeps empty directory tracked in git. |
| `learning_tracker/lib/features/settings/data/models/.gitkeep` | SOUND | t1-feat-settings | Empty placeholder file (0 lines), keeps empty directory tracked in git. |
| `learning_tracker/lib/features/settings/data/repositories/.gitkeep` | SOUND | t1-feat-settings | Empty placeholder file (0 lines), keeps empty directory tracked in git. |
| `learning_tracker/lib/features/settings/domain/entities/.gitkeep` | SOUND | t1-feat-settings | Empty placeholder file (0 lines), keeps empty directory tracked in git. |
| `learning_tracker/lib/features/settings/domain/exceptions/last_active_curriculum_exception.dart` | SOUND | t1-feat-settings | Typed ValidationException; message used only for logging, matches project's exception hierarchy. |
| `learning_tracker/lib/features/settings/domain/repositories/.gitkeep` | SOUND | t1-feat-settings | Empty placeholder file (0 lines), keeps empty directory tracked in git. |
| `learning_tracker/lib/features/settings/domain/services/data_export_import_service.dart` | DEFECTIVE | t1-feat-settings | importData() wipes ALL profiles (no WHERE), contradicts its own per-profile-safety doc comment. |
| `learning_tracker/lib/features/settings/domain/use_cases/.gitkeep` | SOUND | t1-feat-settings | Empty placeholder file (0 lines), keeps empty directory tracked in git. |
| `learning_tracker/lib/features/settings/presentation/providers/.gitkeep` | SOUND | t1-feat-settings | Empty placeholder file (0 lines), keeps empty directory tracked in git. |
| `learning_tracker/lib/features/settings/presentation/providers/account_management_providers.dart` | SOUND | t1-feat-settings | DI provider; legacy Provider() ctor but part of pre-existing 121-usage SM-1 backlog (2023-era file). |
| `learning_tracker/lib/features/settings/presentation/providers/curriculum_activation_providers.dart` | SOUND | t1-feat-settings | Correct layering/DI; legacy-ctor style is pre-existing SM-1 backlog, not new code. |
| `learning_tracker/lib/features/settings/presentation/providers/curriculum_scope_providers.dart` | SOUND | t1-feat-settings | Family providers value-equal (records), no keepAlive; SM-1 ctor style is backlog only. |
| `learning_tracker/lib/features/settings/presentation/screens/.gitkeep` | SOUND | t1-feat-settings | Empty placeholder file (0 lines), keeps empty directory tracked in git. |
| `learning_tracker/lib/features/settings/presentation/screens/curriculum_settings_screen.dart` | ISSUES | t1-feat-settings | Hardcoded 'Settings -'/'Copy' strings, raw e.toString() in error msg, duplicate track query. |
| `learning_tracker/lib/features/settings/presentation/screens/lifetime_marking_screen.dart` | ISSUES | t1-feat-settings | 986 lines (AG-3); raw e.toString() embedded in localized save-error SnackBar. |
| `learning_tracker/lib/features/settings/presentation/screens/scope_selection_screen.dart` | ISSUES | t1-feat-settings | ~10 hardcoded English strings (no l10n), duplicate track query, 432 lines (AG-3). |
| `learning_tracker/lib/features/settings/presentation/screens/settings_screen.dart` | ISSUES | t1-feat-settings | 816 lines (AG-3) only; l10n, layering, SM discipline otherwise clean on full read. |
| `learning_tracker/lib/features/settings/presentation/screens/upgrade_to_cloud_screen.dart` | ISSUES | t1-feat-settings | 937 lines (AG-3) only; exemplary sealed state machine, ST-4 error pattern, clean l10n. |
| `learning_tracker/lib/features/settings/presentation/utils/account_actions.dart` | ISSUES | t1-feat-settings | 586 lines (AG-3); raw e.toString() shown unlocalized in delete-account error/overlay (2 sites). |
| `learning_tracker/lib/features/settings/presentation/utils/send_logs_service.dart` | ISSUES | t1-feat-settings | Raw e.toString() interpolated into localized send-logs-failed error message. |
| `learning_tracker/lib/features/settings/presentation/widgets/.gitkeep` | SOUND | t1-feat-settings | Empty placeholder file (0 lines), keeps empty directory tracked in git. |
| `learning_tracker/lib/features/settings/presentation/widgets/account_actions_sheet.dart` | SOUND | t1-feat-settings | Correct tier-gating (showDelete/showSignOut/showAddAccount), full l10n, no raw DB/exception leakage. |
| `learning_tracker/lib/features/settings/presentation/widgets/backup_sync_section.dart` | ISSUES | t1-feat-settings | 484 lines (AG-3) only; ST-4 error-friendliness and l10n otherwise exemplary on read. |
| `learning_tracker/lib/features/settings/presentation/widgets/change_password_dialog.dart` | SOUND | t1-feat-settings | Clean: fixed friendly error message on catch, no raw exception text, full l10n. |
| `learning_tracker/lib/features/settings/presentation/widgets/delete_account_dialog.dart` | SOUND | t1-feat-settings | Clean confirmation dialog; provider name interpolated via proper ICU l10n key. |
| `learning_tracker/lib/features/settings/presentation/widgets/reauthenticate_dialog.dart` | SOUND | t1-feat-settings | Clean: fixed friendly error message on catch, no raw exception exposure. |
| `learning_tracker/lib/features/settings/presentation/widgets/user_profile_header_card.dart` | ISSUES | t1-feat-settings | Rule 2 deep cross-feature imports x6; 457 lines (AG-3); redundant _user state; raw Color literals. |
| `learning_tracker/lib/features/settings/settings.dart` | ISSUES | t1-feat-settings | Barrel is dead: 0 exports, imported nowhere in repo; contradicts its own doc comment. |
| `learning_tracker/lib/features/sync/data/local_data_upload_service.dart` | ISSUES | t1-feat-sync | DB-3 unbatched per-row outbox loops x7; SM-7 inline repo construction |
| `learning_tracker/lib/features/sync/data/models/.gitkeep` | SOUND | t1-feat-sync | empty scaffold placeholder, no content to audit |
| `learning_tracker/lib/features/sync/data/outbox_sync_write_facade.dart` | ISSUES | t1-feat-sync | 446 lines (AG-3); log-less swallowed catch (EH-3); inline service construction |
| `learning_tracker/lib/features/sync/data/repositories/.gitkeep` | SOUND | t1-feat-sync | empty scaffold placeholder, no content to audit |
| `learning_tracker/lib/features/sync/data/reward_settings_merge_delegate.dart` | ISSUES | t1-feat-sync | SM-7 inline RewardMilestoneService construction; otherwise clean |
| `learning_tracker/lib/features/sync/domain/entities/.gitkeep` | SOUND | t1-feat-sync | empty scaffold placeholder, no content to audit |
| `learning_tracker/lib/features/sync/domain/merge_rules.dart` | ISSUES | t1-feat-sync | dead re-export shim, only a test file still imports it |
| `learning_tracker/lib/features/sync/domain/models/restore_status.dart` | ISSUES | t1-feat-sync | EH-5: error variant carries free-text message, not a code |
| `learning_tracker/lib/features/sync/domain/models/sync_status.dart` | ISSUES | t1-feat-sync | EH-5 free-text message field; duplicated by core/sync canonical file |
| `learning_tracker/lib/features/sync/domain/profile_scoped_preference_keys.dart` | ISSUES | t1-feat-sync | dead re-export shim, only test files still import it |
| `learning_tracker/lib/features/sync/domain/repositories/.gitkeep` | SOUND | t1-feat-sync | empty scaffold placeholder, no content to audit |
| `learning_tracker/lib/features/sync/domain/services/device_restore_service.dart` | ISSUES | t1-feat-sync | dead re-export shim, only test files still import it |
| `learning_tracker/lib/features/sync/domain/use_cases/.gitkeep` | SOUND | t1-feat-sync | empty scaffold placeholder, no content to audit |
| `learning_tracker/lib/features/sync/presentation/providers/.gitkeep` | SOUND | t1-feat-sync | empty scaffold placeholder, no content to audit |
| `learning_tracker/lib/features/sync/presentation/providers/restore_providers.dart` | ISSUES | t1-feat-sync | dead re-export shim; zero importers anywhere, even tests |
| `learning_tracker/lib/features/sync/presentation/providers/sync_providers.dart` | DEFECTIVE | t1-feat-sync | SM-2 build side effects; SM-4 missing mounted check x2; dead duplicate providers |
| `learning_tracker/lib/features/sync/presentation/screens/.gitkeep` | SOUND | t1-feat-sync | empty scaffold placeholder, no content to audit |
| `learning_tracker/lib/features/sync/presentation/screens/device_restore_screen.dart` | ISSUES | t1-feat-sync | dead re-export shim; zero importers anywhere, even tests |
| `learning_tracker/lib/features/sync/presentation/widgets/.gitkeep` | SOUND | t1-feat-sync | empty scaffold placeholder, no content to audit |
| `learning_tracker/lib/features/sync/presentation/widgets/sync_status_indicator.dart` | ISSUES | t1-feat-sync | AX-2 hardcoded English strings; widget unreferenced by any screen |
| `learning_tracker/lib/features/sync/sync.dart` | ISSUES | t1-feat-sync | dead barrel, zero exports, stale 'being deleted' comment |
| `learning_tracker/lib/features/tracks/data/.gitkeep` | SOUND | t1-feat-tracks | Empty placeholder file, nothing to audit. |
| `learning_tracker/lib/features/tracks/domain/.gitkeep` | SOUND | t1-feat-tracks | Empty placeholder file, nothing to audit. |
| `learning_tracker/lib/features/tracks/domain/services/curriculum_activation_service.dart` | ISSUES | t1-feat-tracks | Log-less catch swallows Firestore sync errors (EH-3); test at stale settings/ path (AG-5). |
| `learning_tracker/lib/features/tracks/domain/services/track_progress_service.dart` | SOUND | t1-feat-tracks | @riverpod codegen, pure math, no I/O in build, documented tier semantics — clean canonical aggregator. |
| `learning_tracker/lib/features/tracks/presentation/.gitkeep` | SOUND | t1-feat-tracks | Empty placeholder file, nothing to audit. |
| `learning_tracker/lib/features/tracks/setup/data/repositories/track_blueprint_draft_repository_impl.dart` | ISSUES | t1-feat-tracks | Entirely dead code, zero production callers; part of abandoned migration. |
| `learning_tracker/lib/features/tracks/setup/domain/aggregates/track_blueprint.dart` | ISSUES | t1-feat-tracks | Dead code; 6 classes hand-roll ==/hashCode instead of @freezed. |
| `learning_tracker/lib/features/tracks/setup/domain/entities/add_track_result.dart` | ISSUES | t1-feat-tracks | Live, mostly @freezed and clean; BulkMarkIntent hand-rolls ==/hashCode. |
| `learning_tracker/lib/features/tracks/setup/domain/repositories/track_blueprint_draft_repository.dart` | ISSUES | t1-feat-tracks | Dead code; AddTrackDraft's hand-rolled == silently omits 2 fields. |
| `learning_tracker/lib/features/tracks/setup/domain/services/track_creation_service.dart` | ISSUES | t1-feat-tracks | 438 lines (AG-3, HOTSPOT); study-day loop duplicated verbatim with TrackEditService. |
| `learning_tracker/lib/features/tracks/setup/domain/services/track_edit_service.dart` | ISSUES | t1-feat-tracks | Study-day save loop duplicates TrackCreationService verbatim; otherwise sound. |
| `learning_tracker/lib/features/tracks/setup/domain/use_cases/provision_track_use_case.dart` | ISSUES | t1-feat-tracks | Entirely dead code; zero references outside its own file and tests. |
| `learning_tracker/lib/features/tracks/setup/presentation/controllers/add_track_controller.dart` | ISSUES | t1-feat-tracks | Entirely dead code; duplicates live AddTrackFlow's SharedPreferences keys verbatim. |
| `learning_tracker/lib/features/tracks/setup/presentation/controllers/add_track_flow_state.dart` | ISSUES | t1-feat-tracks | Dead code, consumed only by the unreferenced AddTrackController. |
| `learning_tracker/lib/features/tracks/setup/presentation/providers/add_track_providers.dart` | ISSUES | t1-feat-tracks | Hand-written Provider() instead of @riverpod codegen (SM-1). |
| `learning_tracker/lib/features/tracks/setup/presentation/providers/after_track_change_invalidation.dart` | SOUND | t1-feat-tracks | Checked invalidation fan-out and deprecated alias; consistent, well-documented single source of truth. |
| `learning_tracker/lib/features/tracks/setup/presentation/providers/track_edit_providers.dart` | ISSUES | t1-feat-tracks | Hand-written Provider() instead of @riverpod codegen (SM-1). |
| `learning_tracker/lib/features/tracks/setup/presentation/providers/track_management_providers.dart` | ISSUES | t1-feat-tracks | Two hand-written Provider/FutureProvider declarations instead of codegen (SM-1). |
| `learning_tracker/lib/features/tracks/setup/presentation/screens/add_track_flow_screen.dart` | ISSUES | t1-feat-tracks | 989 lines (AG-3); log-less catches; duplicates dead controller's persistence keys. |
| `learning_tracker/lib/features/tracks/setup/presentation/screens/edit_track_screen.dart` | ISSUES | t1-feat-tracks | 1011 lines (AG-3); log-less catch; icon-only steppers lack semantics (AX-3). |
| `learning_tracker/lib/features/tracks/setup/presentation/screens/track_detail_screen.dart` | ISSUES | t1-feat-tracks | 994 lines (AG-3, HOTSPOT); duplicate 'Track progress' label shows two differing values. |
| `learning_tracker/lib/features/tracks/setup/presentation/screens/track_management_hub_screen.dart` | ISSUES | t1-feat-tracks | Hardcoded 'Error: $e' text (AX-2); EdgeInsets.only(left/right) RTL violation (AX-1). |
| `learning_tracker/lib/features/tracks/setup/presentation/steps/chazara_widgets.dart` | ISSUES | t1-feat-tracks | Clean/localized overall; TinyCircleButton icon-only control lacks semantics (AX-3). |
| `learning_tracker/lib/features/tracks/setup/presentation/steps/goal_cards.dart` | SOUND | t1-feat-tracks | Checked localization, const usage, no state/IO — clean presentational widgets. |
| `learning_tracker/lib/features/tracks/setup/presentation/steps/goal_helpers.dart` | SOUND | t1-feat-tracks | Verified pace/date math formulas; no I/O; confirmed unit-tested at non-mirrored path. |
| `learning_tracker/lib/features/tracks/setup/presentation/steps/scope_tiles.dart` | SOUND | t1-feat-tracks | Two tiles checked: l10n tooltips present, no hardcoded strings or directional-insets violations. |
| `learning_tracker/lib/features/tracks/setup/presentation/steps/scope_views.dart` | ISSUES | t1-feat-tracks | 487 lines exceeds AG-3's 400-line cap; otherwise clean, fully localized widget. |
| `learning_tracker/lib/features/tracks/setup/presentation/steps/step_bulk_mark.dart` | SOUND | t1-feat-tracks | 65-line delegating wrapper; fully localized, no logic to break. |
| `learning_tracker/lib/features/tracks/setup/presentation/steps/step_chazara.dart` | ISSUES | t1-feat-tracks | Preset titles/descriptions hardcoded English, shown to every user regardless of locale. |
| `learning_tracker/lib/features/tracks/setup/presentation/steps/step_chazara_readonly.dart` | SOUND | t1-feat-tracks | Read-only stage display; delay-label switch and text fully localized. |
| `learning_tracker/lib/features/tracks/setup/presentation/steps/step_goal.dart` | ISSUES | t1-feat-tracks | 487 lines (AG-3); setState after await with no mounted guard in _pickDeadline. |
| `learning_tracker/lib/features/tracks/setup/presentation/steps/step_scope.dart` | ISSUES | t1-feat-tracks | 448 lines (AG-3); hardcoded 'Level $level' fallback string; deep cross-feature import. |
| `learning_tracker/lib/features/tracks/setup/presentation/steps/step_starting_position.dart` | DEFECTIVE | t1-feat-tracks | Silent catch leaves blank dead-end screen; hardcoded strings; icon button missing tooltip. |
| `learning_tracker/lib/features/tracks/setup/presentation/steps/step_starting_position_calendar.dart` | ISSUES | t1-feat-tracks | No catch around awaited service call; hardcoded fallback string; 468 lines. |
| `learning_tracker/lib/features/tracks/setup/presentation/steps/step_study_days.dart` | SOUND | t1-feat-tracks | Careful nusach/Hebrew-Terms-aware localization; fixed anchor date; no violations found. |
| `learning_tracker/lib/features/tracks/setup/presentation/widgets/curriculum_picker_step.dart` | SOUND | t1-feat-tracks | Fully localized; displayNameHe/En access correctly confined to core/labels helper. |
| `learning_tracker/lib/features/tracks/setup/presentation/widgets/learning_track_card.dart` | SOUND | t1-feat-tracks | Chazara-gated label logic correct; Semantics present; providers watched properly. |
| `learning_tracker/lib/features/tracks/setup/presentation/widgets/program_selection_step.dart` | SOUND | t1-feat-tracks | Has mirrored test; l10n-clean; one-time repo read in initState is acceptable. |
| `learning_tracker/lib/features/tracks/setup/presentation/widgets/track_info_card.dart` | SOUND | t1-feat-tracks | 370 lines; has mirrored test; formatting helpers delegate correctly, no violations. |
| `learning_tracker/lib/features/tracks/setup/presentation/widgets/track_label_step.dart` | ISSUES | t1-feat-tracks | Hardcoded TextDirection.rtl on free-text field regardless of app locale. |
| `learning_tracker/lib/features/tracks/setup/presentation/widgets/track_management_body.dart` | DEFECTIVE | t1-feat-tracks | Widget calls trackDao directly (DB-1); multi-line EdgeInsets.only(left/right); missing tooltip. |
| `learning_tracker/lib/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart` | ISSUES | t1-feat-tracks | 474 lines (AG-3); addStage/updateStage/deleteStage/reorderStages are dead code; throws ArgumentError. |
| `learning_tracker/lib/features/tracks/stages/domain/exceptions/protected_stage_exception.dart` | ISSUES | t1-feat-tracks | Only thrown from dead deleteStage/reorderStages paths; raw English message. |
| `learning_tracker/lib/features/tracks/stages/domain/exceptions/stage_limit_exceeded_exception.dart` | ISSUES | t1-feat-tracks | Only thrown from dead addStage path; raw English message (EH-5). |
| `learning_tracker/lib/features/tracks/stages/domain/models/schedule_type.dart` | SOUND | t1-feat-tracks | Small enum, safe fromStorageKey fallback; no violations found. |
| `learning_tracker/lib/features/tracks/stages/domain/models/stage_definition.dart` | SOUND | t1-feat-tracks | @freezed domain model per convention; bridge extension clearly documented. |
| `learning_tracker/lib/features/tracks/stages/domain/repositories/stage_definition_repository.dart` | ISSUES | t1-feat-tracks | Interface documents Error-throwing contract for the dead mutation methods. |
| `learning_tracker/lib/features/tracks/stages/domain/services/stage_validator.dart` | ISSUES | t1-feat-tracks | Only reachable from dead addStage/updateStage; returns raw English strings. |
| `learning_tracker/lib/features/tracks/stages/presentation/providers/stage_providers.dart` | ISSUES | t1-feat-tracks | StageEditorNotifier's 5 mutation methods unused; mutation call not guarded (SM-5). |
| `learning_tracker/lib/features/tracks/track_order/data/repositories/track_learning_order_repository_impl.dart` | DEFECTIVE | t1-feat-tracks | Imports ContentRepository (SM-8); 3 sites non-transactional multi-write (DB-2); cross-feature import. |
| `learning_tracker/lib/features/tracks/track_order/domain/aggregates/track_order.dart` | ISSUES | t1-feat-tracks | TrackOrder/OrderingLevel unused; doc claims false contract; hand-written ==/hashCode. |
| `learning_tracker/lib/features/tracks/track_order/domain/repositories/track_learning_order_repository.dart` | SOUND | t1-feat-tracks | Clean interface; matches impl's real contract, not track_order.dart's stale doc. |
| `learning_tracker/lib/features/tracks/track_order/domain/services/masechta_ordering_policy.dart` | SOUND | t1-feat-tracks | Pure, well-documented domain service; verified sort logic; exercised by repo test. |
| `learning_tracker/lib/features/tracks/track_order/presentation/providers/track_learning_order_providers.dart` | SOUND | t1-feat-tracks | Thin providers; family args value-equal records; repo built only in provider. |
| `learning_tracker/lib/features/tracks/track_order/presentation/screens/track_learning_order_screen.dart` | ISSUES | t1-feat-tracks | Silent-fail save/reset (no error UI); dup confirm-dialog preamble; dup Hebrew regex. |
| `learning_tracker/lib/features/tracks/tracks.dart` | SOUND | t1-feat-tracks | Re-export barrel only; verified all exports stay within tracks/* (Rule 2). |
| `learning_tracker/lib/features/tracks/whole_curriculum_order/data/preferences/learning_order_preferences.dart` | ISSUES | t1-feat-tracks | Whole file is dead code: unused singleton superseded by ProfileScopedPreferenceKeys. |
| `learning_tracker/lib/features/tracks/whole_curriculum_order/data/repositories/learning_order_repository_impl.dart` | DEFECTIVE | t1-feat-tracks | profileId not filtered on 2 DAO reads (P0 leak); untransacted stamp; write-in-read. |
| `learning_tracker/lib/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart` | SOUND | t1-feat-tracks | Correct @freezed abstract-class pattern; immutable; no hand-written equality. |
| `learning_tracker/lib/features/tracks/whole_curriculum_order/domain/repositories/learning_order_repository.dart` | SOUND | t1-feat-tracks | Interface + typed ParentControlException; doc matches impl; no issues. |
| `learning_tracker/lib/features/tracks/whole_curriculum_order/domain/use_cases/save_learning_order_use_case.dart` | SOUND | t1-feat-tracks | Thin correct use-case wrapper; nothing to fault. |
| `learning_tracker/lib/features/tracks/whole_curriculum_order/presentation/providers/learning_order_providers.dart` | ISSUES | t1-feat-tracks | learningOrderProvider build invokes a repository read with a hidden DB write. |
| `learning_tracker/lib/features/tracks/whole_curriculum_order/presentation/screens/learning_order_screen.dart` | ISSUES | t1-feat-tracks | Hardcoded English 'Order' in AppBar title (AX-2); silent-fail save/reset; dup preamble. |
| `learning_tracker/lib/features/tracks/whole_curriculum_order/presentation/widgets/draggable_order_item.dart` | SOUND | t1-feat-tracks | Small presentational widget; uses CurriculumLabel widget, not raw displayName (Rule 5). |
| `learning_tracker/lib/features/tracks/whole_curriculum_order/presentation/widgets/reset_order_dialog.dart` | SOUND | t1-feat-tracks | Clean l10n-only confirmation dialog; no issues found. |
| `learning_tracker/lib/features/tutoring/data/repositories/firestore_audit_log_read_repository.dart` | ISSUES | t1-feat-tutoring | Read-repo interface lives in presentation/, forcing a backward data→presentation import. |
| `learning_tracker/lib/features/tutoring/data/repositories/firestore_tutor_grant_repository.dart` | ISSUES | t1-feat-tutoring | e.toString() into Failure.message x6; TutorGrantRepository interface imported from domain/use_cases not domain/repositories. |
| `learning_tracker/lib/features/tutoring/data/routers/tutored_write_router.dart` | ISSUES | t1-feat-tutoring | 10x unguarded int.parse(profileId); per-stage loop throws on first failure with no retry. |
| `learning_tracker/lib/features/tutoring/data/services/tutor_write_service.dart` | ISSUES | t1-feat-tutoring | e.toString() captured into TutorWriteFailure.message instead of a stable code. |
| `learning_tracker/lib/features/tutoring/domain/models/session_role.dart` | SOUND | t1-feat-tutoring | Checked sealed ProfileSelection/SessionRole/ResolvedSession immutability + permission resolution; matches its test suite. |
| `learning_tracker/lib/features/tutoring/domain/models/tutor_audit_log_entry.dart` | SOUND | t1-feat-tutoring | Checked toFirestore/fromFirestore symmetry and exhaustive TutorAuditAction switch expressions; no issues. |
| `learning_tracker/lib/features/tutoring/domain/models/tutor_grant.dart` | SOUND | t1-feat-tutoring | Checked 3-format timestamp parser and deterministic doc-id builder; callers key by grantId string, not object equality. |
| `learning_tracker/lib/features/tutoring/domain/models/tutor_grant_aggregate.dart` | SOUND | t1-feat-tutoring | Checked GrantState transitions/business guards against use-case preconditions; internally consistent. |
| `learning_tracker/lib/features/tutoring/domain/models/tutor_permissions.dart` | ISSUES | t1-feat-tutoring | Hand-rolled ==/hashCode on a self-described VO instead of @freezed. |
| `learning_tracker/lib/features/tutoring/domain/services/tutor_audit_log_writer.dart` | DEFECTIVE | t1-feat-tutoring | Never constructed anywhere in lib/; wired to a no-op stub; entryId generator contradicts its own ULID doc claim. |
| `learning_tracker/lib/features/tutoring/domain/services/tutor_notification_service.dart` | SOUND | t1-feat-tutoring | Checked UID-fallback recipient routing and fire-and-forget email contract; no issues. |
| `learning_tracker/lib/features/tutoring/domain/services/tutor_pin_service.dart` | ISSUES | t1-feat-tutoring | TutorPinValidationError carries raw English message instead of a code, x2 sites. |
| `learning_tracker/lib/features/tutoring/domain/use_cases/mark_live_completion_use_case.dart` | SOUND | t1-feat-tutoring | Tutor live-completion block verified against its strong red/green regression suite. |
| `learning_tracker/lib/features/tutoring/domain/use_cases/tutor_grant_use_cases.dart` | ISSUES | t1-feat-tutoring | TutorGrantPreconditionError raw English message x2 (revoke, resign). |
| `learning_tracker/lib/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart` | ISSUES | t1-feat-tutoring | TutorGrantPreconditionError raw English message x4; repository interface not in domain/repositories/. |
| `learning_tracker/lib/features/tutoring/presentation/providers/active_tutored_profile_provider.dart` | SOUND | t1-feat-tutoring | keepAlive justified inline; no ref-after-await gap; enter/exit lifecycle checked against docs. |
| `learning_tracker/lib/features/tutoring/presentation/providers/audit_log_providers.dart` | DEFECTIVE | t1-feat-tutoring | No-op write-repo stub + untracked TODO; misplaced interface causes data→presentation import. |
| `learning_tracker/lib/features/tutoring/presentation/providers/manage_tutors_providers.dart` | ISSUES | t1-feat-tutoring | 3x unguarded ref.read after await (SM-4); defines the duplicate incomingTutorGrantsProvider. |
| `learning_tracker/lib/features/tutoring/presentation/providers/tutor_grant_providers.dart` | ISSUES | t1-feat-tutoring | Defines a second, stale incomingTutorGrantsProvider; barrel exports this one, not the real one. |
| `learning_tracker/lib/features/tutoring/presentation/providers/tutor_pin_providers.dart` | SOUND | t1-feat-tutoring | Minimal @riverpod codegen providers; nothing to flag. |
| `learning_tracker/lib/features/tutoring/presentation/screens/accept_invite_screen.dart` | ISSUES | t1-feat-tutoring | 565 lines (AG-3); raw PreconditionError message; 8 color literals; TutorGrantFailure path correctly localized. |
| `learning_tracker/lib/features/tutoring/presentation/screens/decline_invite_screen.dart` | ISSUES | t1-feat-tutoring | 411 lines (AG-3); raw PreconditionError message; 6 color literals. |
| `learning_tracker/lib/features/tutoring/presentation/screens/invite_tutor_screen.dart` | ISSUES | t1-feat-tutoring | Raw PreconditionError message; 4 color literals; correctly localizes the Failure variant. |
| `learning_tracker/lib/features/tutoring/presentation/screens/manage_grants_screen.dart` | DEFECTIVE | t1-feat-tutoring | _resign() discards TutorGrantResult, always shows success; e.toString() in snackbar. |
| `learning_tracker/lib/features/tutoring/presentation/screens/manage_tutors_screen.dart` | DEFECTIVE | t1-feat-tutoring | _revoke()/_rescind() discard TutorGrantResult; e.toString() x3; 559 lines (AG-3). |
| `learning_tracker/lib/features/tutoring/presentation/screens/tutor_audit_log_screen.dart` | ISSUES | t1-feat-tutoring | 11 color literals (worst in batch); 563 lines (AG-3); good EdgeInsetsDirectional RTL practice otherwise. |
| `learning_tracker/lib/features/tutoring/presentation/screens/tutor_pin_entry_dialog.dart` | ISSUES | t1-feat-tutoring | Renders TutorPinValidationError.message raw and unlocalized. |
| `learning_tracker/lib/features/tutoring/presentation/screens/tutor_pin_entry_gate.dart` | ISSUES | t1-feat-tutoring | no catch around async PIN verify; duplicated numpad widget; icon buttons lack semantics; switch-statement not expression |
| `learning_tracker/lib/features/tutoring/presentation/screens/tutor_pin_reset_screen.dart` | ISSUES | t1-feat-tutoring | Rule-2 deep import bypasses account barrel; untyped log-less catch; non-atomic email-send+PIN-clear |
| `learning_tracker/lib/features/tutoring/presentation/screens/tutor_pin_setup_screen.dart` | ISSUES | t1-feat-tutoring | duplicated numpad widget; no catch around async setTutorPin; raw validation message; switch-statement |
| `learning_tracker/lib/features/tutoring/tutoring.dart` | SOUND | t1-feat-tutoring | checked every export is own-feature only; matches repo-wide barrel convention; no re-export chains |
| `learning_tracker/lib/l10n/app_en.arb` | ISSUES | t1-app-l10n | 5 duplicate top-level keys (parsed + validated programmatically); silently shadowed. |
| `learning_tracker/lib/l10n/app_he.arb` | ISSUES | t1-app-l10n | 5 duplicate top-level keys shadow content, incl. dead zero-task branch. |
| `learning_tracker/lib/main.dart` | SOUND | t1-app-l10n | Zone-guarded bootstrap correct; FlutterError/PlatformDispatcher handlers confirmed wired elsewhere. |
| `learning_tracker/test/app/locale_wiring_test.dart` | SOUND | t1-app-l10n | Device-locale guards verified true against live app/settings source files. |
| `learning_tracker/test/app/restore/device_restore_phase_l10n_test.dart` | ISSUES | t1-app-l10n | Tests real phase→l10n mapping correctly; duplicates restore-harness boilerplate (Finding 6). |
| `learning_tracker/test/app/restore/device_restore_screen_l1_test.dart` | ISSUES | t1-app-l10n | 810 lines (AG-3 cap); also duplicates restore-harness boilerplate (Finding 6). |
| `learning_tracker/test/app/restore/device_restore_screen_overflow_test.dart` | ISSUES | t1-app-l10n | Real-screen overflow matrix test is sound; duplicates restore-harness boilerplate (Finding 6). |
| `learning_tracker/test/app/restore/restore_no_double_read_test.dart` | SOUND | t1-app-l10n | Tests real DeviceRestoreService with hand-written fakes; no issues found. |
| `learning_tracker/test/app/restore/sy2_device_restore_idle_blank_test.dart` | ISSUES | t1-app-l10n | Dead nullService ternary (Finding 5); duplicates restore-harness boilerplate (Finding 6). |
| `learning_tracker/test/app/router/app_shell_an6_test.dart` | ISSUES | t1-app-l10n | Regression test never imports app_shell.dart — tests an unwired replica. |
| `learning_tracker/test/app/router/persistent_switcher_scaffold_an8_test.dart` | ISSUES | t1-app-l10n | Tautological: asserts a local literal set against itself, not real code. |
| `learning_tracker/test/core/analytics/analytics_service_test.dart` | SOUND | t1-core-analytics-logging | Hermetic LoggingAnalyticsService/FakeAnalyticsService tests; fresh AppLogger.init() per test. |
| `learning_tracker/test/core/analytics/parent_analytics_repository_test.dart` | SOUND | t1-core-analytics-logging | Fixed UTC dates, fresh in-memory DB per test, proper teardown; hermetic. |
| `learning_tracker/test/core/analytics/streak_milestone_analytics_observer_test.dart` | ISSUES | t1-core-analytics-logging | Error-swallowing tests solid; happy-path test wall-clock-dependent, polls 5s. |
| `learning_tracker/test/core/auth/.gitkeep` | SOUND | t1-core-auth | 0-line placeholder; harmless now that the directory also holds a real test. |
| `learning_tracker/test/core/auth/firebase_auth_gateway_impl_test.dart` | ISSUES | t1-core-auth | 496 lines breaches 400-line AG-3 ratchet; hermetic mocktail suite otherwise, good branch coverage. |
| `learning_tracker/test/core/constants/curriculum_defaults_extended_test.dart` | ISSUES | t1-core-small-a | Duplicates container/fullPath/valueWithLabel coverage from sibling files |
| `learning_tracker/test/core/constants/curriculum_defaults_test.dart` | ISSUES | t1-core-small-a | CurriculumDefaults assertions re-duplicated in _extended_test.dart |
| `learning_tracker/test/core/constants/curriculum_label_variant_test.dart` | SOUND | t1-core-small-a | Thorough nusach/transliteration coverage; no overlap with siblings found |
| `learning_tracker/test/core/constants/curriculum_labels_extended_test.dart` | ISSUES | t1-core-small-a | Near-duplicate of curriculum_defaults_extended_test.dart (5+ groups) |
| `learning_tracker/test/core/constants/hebrew_terms_test.dart` | ISSUES | t1-core-small-a | Two identically-named duplicate groups; tests dead delegate method |
| `learning_tracker/test/core/content/coarse_unit_leaf_refs_test.dart` | ISSUES | t1-core-content | Well-written, hermetic tests, but covers only 2/8 content_grouping.dart exports. |
| `learning_tracker/test/core/database/.gitkeep` | SOUND | t1-core-database-root | Empty directory placeholder, 0 lines, nothing to audit. |
| `learning_tracker/test/core/database/app_database_test.dart.skip` | DEFECTIVE | t1-core-database-root | Dead code: imports deleted app_database.dart, never runs (finding 3). |
| `learning_tracker/test/core/database/content_database_companion_coverage_test.dart` | ISSUES | t1-core-database-root | 855 lines (AG-3); duplicates comprehensive_test's toString/toJson coverage. |
| `learning_tracker/test/core/database/content_database_comprehensive_test.dart` | ISSUES | t1-core-database-root | 664 lines (AG-3); overlaps companion_coverage_test; not at AG-5 path. |
| `learning_tracker/test/core/database/content_database_managers_create_update_test.dart` | ISSUES | t1-core-database-root | Clean tests, but 3rd non-mirrored file testing content_database.dart (AG-5). |
| `learning_tracker/test/core/database/dao_merge_methods_test.dart.skip` | DEFECTIVE | t1-core-database-root | Dead code: imports deleted app_database.dart, never runs (finding 3). |
| `learning_tracker/test/core/database/daos/active_curriculum_dao_test.dart` | SOUND | t1-core-database-daos | Hermetic in-memory DB, fresh per test; covers activate/deactivate/idempotency/streams. |
| `learning_tracker/test/core/database/daos/bookmark_dao_extra_test.dart` | SOUND | t1-core-database-daos | Hermetic, fixed UTC dates, explicit cross-profile isolation assertions. |
| `learning_tracker/test/core/database/daos/bookmark_dao_test.dart` | ISSUES | t1-core-database-daos | DateTime.now() x5 for non-asserted timestamps (finding 11, low practical risk). |
| `learning_tracker/test/core/database/daos/completion_dao_extended_test.dart` | ISSUES | t1-core-database-daos | 533 lines (AG-3); stale insertCompletionsBatch group name (finding 9); overlaps extra_test (finding 10). |
| `learning_tracker/test/core/database/daos/completion_dao_extra_test.dart` | ISSUES | t1-core-database-daos | Stale insertCompletionsBatch group name (finding 9); duplicates extended_test coverage (finding 10). |
| `learning_tracker/test/core/database/daos/completion_dao_review_counts_test.dart` | SOUND | t1-core-database-daos | Hermetic, well-scoped track/profile/ref isolation tests, no stale references. |
| `learning_tracker/test/core/database/daos/completion_dao_test.dart` | ISSUES | t1-core-database-daos | Inline curriculumTracks seeding + wall-clock now(); null-check test never reaches DAO code. |
| `learning_tracker/test/core/database/daos/completion_dao_tier_filter_test.dart` | SOUND | t1-core-database-daos | Uses seedTrack() correctly; thorough, well-documented duplicate-import defensive regression tests. |
| `learning_tracker/test/core/database/daos/completion_event_dao_test.dart` | ISSUES | t1-core-database-daos | Only issue: wall-clock DateTime.now() filler in setUp (unasserted, low risk today). |
| `learning_tracker/test/core/database/daos/curriculum_scope_dao_extra_test.dart` | ISSUES | t1-core-database-daos | Inline curriculumTracks seeding (2 sites) instead of shared seedTrack() helper. |
| `learning_tracker/test/core/database/daos/curriculum_scope_dao_test.dart` | ISSUES | t1-core-database-daos | Inline track seeding (2) + wall-clock now() (4 sites); coverage otherwise thorough. |
| `learning_tracker/test/core/database/daos/daily_plan_dao_test.dart` | ISSUES | t1-core-database-daos | Inline curriculumTracks seeding (3 sites); batch-insert/insertOrIgnore coverage is good. |
| `learning_tracker/test/core/database/daos/goal_dao_extended_test.dart` | ISSUES | t1-core-database-daos | Inline curriculumTracks seeding instead of seedTrack() helper (1 site). |
| `learning_tracker/test/core/database/daos/goal_dao_extra_test.dart` | ISSUES | t1-core-database-daos | Inline curriculumTracks seeding instead of seedTrack() helper (4 sites). |
| `learning_tracker/test/core/database/daos/goal_dao_test.dart` | ISSUES | t1-core-database-daos | Inline track seeding + wall-clock now() (2 sites each); upsert-LWW coverage solid. |
| `learning_tracker/test/core/database/daos/learning_ledger_dao_extended_test.dart` | ISSUES | t1-core-database-daos | Inline curriculumTracks seeding instead of seedTrack() helper (2 sites). |
| `learning_tracker/test/core/database/daos/learning_ledger_dao_extra_test.dart` | ISSUES | t1-core-database-daos | Inline curriculumTracks seeding instead of seedTrack() helper (3 sites). |
| `learning_tracker/test/core/database/daos/learning_ledger_dao_test.dart` | ISSUES | t1-core-database-daos | 446 lines exceeds AG-3; inline track seeding + wall-clock now(); coverage itself thorough. |
| `learning_tracker/test/core/database/daos/learning_order_dao_extended_test.dart` | SOUND | t1-core-database-daos | No FK track-seed duplication needed; deterministic dates; hermetic; no issues found. |
| `learning_tracker/test/core/database/daos/learning_order_dao_extra_test.dart` | SOUND | t1-core-database-daos | Deterministic upsert-if-newer LWW tests; no wall-clock or duplication issues. |
| `learning_tracker/test/core/database/daos/learning_order_dao_test.dart` | SOUND | t1-core-database-daos | Small, focused upsert/order tests; no wall-clock or duplication found. |
| `learning_tracker/test/core/database/daos/outbox_dao_test.dart` | SOUND | t1-core-database-daos | Checked attempts/lastError/limit semantics and FIFO ordering; deterministic; clean. |
| `learning_tracker/test/core/database/daos/point_config_dao_test.dart` | ISSUES | t1-core-database-daos | Inline track seeding (3) + wall-clock now() (8 sites); seedDefaults coverage strong. |
| `learning_tracker/test/core/database/daos/points_balance_dao_test.dart` | ISSUES | t1-core-database-daos | 476 lines exceeds AG-3; flaky delay-based stream sync (5); misleading debitRedemption title. |
| `learning_tracker/test/core/database/daos/prior_completion_import_dao_test.dart` | SOUND | t1-core-database-daos | Checked batch-insert/dedup/isImported coverage; deliberately documents missing UNIQUE. |
| `learning_tracker/test/core/database/daos/profile_dao_test.dart` | ISSUES | t1-core-database-daos | Wall-clock DateTime.now() (6 sites); otherwise good, incl. correct emitsInOrder stream test. |
| `learning_tracker/test/core/database/daos/profile_program_dao_test.dart` | SOUND | t1-core-database-daos | Checked upsert-on-conflict + per-profile isolation; no duplication/wall-clock issues. |
| `learning_tracker/test/core/database/daos/sacred_window_dao_test.dart` | SOUND | t1-core-database-daos | Checked batch insertAll, replace-cycle, nullable columns; deterministic dates; clean. |
| `learning_tracker/test/core/database/daos/stage_dao_extended_test.dart` | ISSUES | t1-core-database-daos | Inline curriculumTracks seeding instead of seedTrack() helper (4 sites). |
| `learning_tracker/test/core/database/daos/stage_dao_extra_test.dart` | ISSUES | t1-core-database-daos | Inline curriculumTracks seeding instead of seedTrack() helper (3 sites). |
| `learning_tracker/test/core/database/daos/stage_dao_test.dart` | ISSUES | t1-core-database-daos | Inline track seeding (3) + wall-clock now() (6 sites); UNIQUE-constraint test is good. |
| `learning_tracker/test/core/database/daos/streak_event_dao_test.dart` | SOUND | t1-core-database-daos | Checked idempotent natural-key append + ordering; deterministic dates; no issues. |
| `learning_tracker/test/core/database/daos/study_day_config_dao_test.dart` | ISSUES | t1-core-database-daos | Inline curriculumTracks seeding instead of seedTrack() helper (1 site). |
| `learning_tracker/test/core/database/daos/sync_kv_dao_test.dart` | SOUND | t1-core-database-daos | Checked LWW upsert/get round-trip, kind-namespacing, syncedAt-clear semantics; clean. |
| `learning_tracker/test/core/database/daos/text_download_status_dao_extended_test.dart` | SOUND | t1-core-database-daos | savePartialProgress/getPartialItemCount checked vs DAO source; fixed data, no vacuous tests. |
| `learning_tracker/test/core/database/daos/text_download_status_dao_extra_test.dart` | SOUND | t1-core-database-daos | Overlaps _extended conceptually (not verbatim); matches DAO source; hermetic. |
| `learning_tracker/test/core/database/daos/text_download_status_dao_test.dart` | SOUND | t1-core-database-daos | Base CRUD coverage matches DAO source exactly; no wall-clock, no mocking. |
| `learning_tracker/test/core/database/daos/track_dao_deactivate_test.dart` | ISSUES | t1-core-database-daos | toString test duplicated verbatim in track_dao_delete_test.dart (finding 4). |
| `learning_tracker/test/core/database/daos/track_dao_delete_test.dart` | ISSUES | t1-core-database-daos | Strong purgeHistory/outbox assertions; holds both halves of the cross-file duplication. |
| `learning_tracker/test/core/database/daos/track_dao_extended_test.dart` | DEFECTIVE | t1-core-database-daos | 411 lines (AG-3); its deactivateTrack group's 2 tests never call deactivateTrack. |
| `learning_tracker/test/core/database/daos/track_dao_extra_test.dart` | SOUND | t1-core-database-daos | Matches DAO source; overlaps other split files conceptually but each assertion is real. |
| `learning_tracker/test/core/database/daos/track_dao_last_curriculum_guard_test.dart` | SOUND | t1-core-database-daos | Verified TRK-HUB-04 fixed at screen layer; DAO-level bypass is intentional per code. |
| `learning_tracker/test/core/database/daos/track_dao_test.dart` | ISSUES | t1-core-database-daos | 412 lines (AG-3); DateTime.now() wall-clock filler; 1 test duplicated elsewhere. |
| `learning_tracker/test/core/database/daos/track_learning_order_dao_test.dart` | ISSUES | t1-core-database-daos | Assertions correct, but upsertOrder under test is unsafe (finding 1); no atomicity test. |
| `learning_tracker/test/core/database/daos/track_scoped_dao_test.dart` | ISSUES | t1-core-database-daos | 465 lines (AG-3, worst in batch); pervasive DateTime.now() wall-clock filler. |
| `learning_tracker/test/core/database/daos/user_profile_dao_extra_test.dart` | SOUND | t1-core-database-daos | findCloudBornByFirebaseUid/findByTier/UserTierX.fromDb verified vs source; fixed dates. |
| `learning_tracker/test/core/database/daos/user_profile_dao_test.dart` | SOUND | t1-core-database-daos | Full CRUD + LWW upsertProfile semantics verified against source; fixed UTC dates. |
| `learning_tracker/test/core/database/hebrew_migration_test.dart` | DEFECTIVE | t1-core-database-root | 'v23→v24' migration doesn't exist; hand-copied SQL, not the real path. |
| `learning_tracker/test/core/database/migration_test.dart` | DEFECTIVE | t1-core-database-root | 'v15 to v16' migration doesn't exist in onUpgrade; only tests onCreate. |
| `learning_tracker/test/core/database/registry/device_registry_managers_test.dart` | ISSUES | t1-core-database-root | 616 lines (AG-3); 2nd non-mirrored file for device_registry_database.dart. |
| `learning_tracker/test/core/database/registry/device_registry_test.dart` | ISSUES | t1-core-database-root | Good D10 behavioral coverage; wrong AG-5 filename, split from managers file. |
| `learning_tracker/test/core/database/schema_v1_smoke_test.dart` | ISSUES | t1-core-database-root | Honest scope and good coverage, but 17x wall-clock DateTime.now(); wrong AG-5 path. |
| `learning_tracker/test/core/database/seed_manager_test.dart` | ISSUES | t1-core-database-root | 794 lines (AG-3); 7 vacuous-pass guards; otherwise solid rollback/atomic-replace coverage. |
| `learning_tracker/test/core/database/text_cache_dao_test.dart` | SOUND | t1-core-database-root | 33 lines, 2 tests (null on miss, empty list fresh DB); hermetic in-memory DB; no issues. |
| `learning_tracker/test/core/database/track_scope_test.dart` | SOUND | t1-core-database-root | 63 lines: freezed field/equality/copyWith checks for TrackScope; hermetic, no issues. |
| `learning_tracker/test/core/database/user_database_companion_coverage_test.dart` | ISSUES | t1-core-database-root | 1109 lines (AG-3); duplicate group name; 3 manager tests duplicated elsewhere; weak throwsA. |
| `learning_tracker/test/core/database/user_database_dataclass_core_test.dart` | DEFECTIVE | t1-core-database-root | 1176 lines (AG-3); wholly duplicates dataclass_test.dart's 8 groups; own header claim is false. |
| `learning_tracker/test/core/database/user_database_dataclass_extended_test.dart` | ISSUES | t1-core-database-root | 1613 lines (AG-3, worst); 3 manager tests duplicated; confirms TrackLearningOrder lacks profileId. |
| `learning_tracker/test/core/database/user_database_dataclass_test.dart` | ISSUES | t1-core-database-root | 853 lines (AG-3); establishes 8 groups later duplicated wholesale by dataclass_core_test.dart. |
| `learning_tracker/test/core/database/user_database_managers_computed_fields2_test.dart` | DEFECTIVE | t1-core-database-root | 1308 lines (AG-3, 3.3x cap); all 102 tests assert isNotEmpty only, never the field value |
| `learning_tracker/test/core/database/user_database_managers_computed_fields_test.dart` | DEFECTIVE | t1-core-database-root | 916 lines (AG-3, 2.3x cap); all 57 tests assert isNotEmpty only, never the field value |
| `learning_tracker/test/core/database/user_database_managers_create_update_test.dart` | ISSUES | t1-core-database-root | 804 lines (AG-3, 2x cap); create/update asserts real values but 23 withReferences asserts are isNotEmpty-only |
| `learning_tracker/test/core/database/user_database_managers_crossref_filter_test.dart` | ISSUES | t1-core-database-root | 477 lines (AG-3, 1.2x cap); 9 tautological filter tests + 2 duplicate test names in one group |
| `learning_tracker/test/core/database/user_database_managers_orderby_test.dart` | DEFECTIVE | t1-core-database-root | 2435 lines (AG-3, 6.1x cap); all 283 tests hasLength(1)/isA only; verified 283/283 green today |
| `learning_tracker/test/core/database/user_database_managers_refs_test.dart` | ISSUES | t1-core-database-root | 676 lines (AG-3); 41/42 tests assert only isNotNull/isNotEmpty; completionEventsRefs never tested. |
| `learning_tracker/test/core/database/user_database_managers_test.dart` | ISSUES | t1-core-database-root | 1073 lines (AG-3); duplicate Completion/CompletionEvent groups; unused ProfileDao import. |
| `learning_tracker/test/core/domain/value_objects/calendar_system_test.dart` | SOUND | t1-core-domain-learning | Hermetic; storageKey/fromStorageKey/accessors/round-trip covered, no wall-clock. |
| `learning_tracker/test/core/domain/value_objects/pin_test.dart` | SOUND | t1-core-domain-learning | Hermetic; parse/tryParse/equality/masked-toString all covered, matches source. |
| `learning_tracker/test/core/domain/value_objects/profile_mode_account_tier_test.dart` | SOUND | t1-core-domain-learning | Hermetic; both enums' storageKey/fromStorageKey/accessors/round-trip covered. |
| `learning_tracker/test/core/domain/value_objects/program_starting_position_test.dart` | ISSUES | t1-core-domain-learning | Fixed-clock, thorough B2/B3/fromLegacyGrammar coverage; toLegacyGrammar untested. |
| `learning_tracker/test/core/domain/value_objects/scope_test.dart` | SOUND | t1-core-domain-learning | Hermetic; construction/equality/fromRaw edge cases covered for all 3 classes. |
| `learning_tracker/test/core/domain/value_objects/sefaria_ref_test.dart` | ISSUES | t1-core-domain-learning | titlePart test documents then asserts the regex bug instead of catching it. |
| `learning_tracker/test/core/domain/value_objects/stage_order_test.dart` | SOUND | t1-core-domain-learning | Hermetic; construction/ordering/monotonic/comparators/equality all covered. |
| `learning_tracker/test/core/domain/value_objects/study_day_pattern_test.dart` | SOUND | t1-core-domain-learning | Hermetic; construction/factories/dayKindFor/equality match source behavior. |
| `learning_tracker/test/core/exceptions/duplicate_completion_exception_test.dart` | ISSUES | t1-core-small-a | Tests only a dead exception class; zero production regression value |
| `learning_tracker/test/core/l10n/app_localizations_test.dart` | ISSUES | t1-core-l10n | Misplaced (no lib/core/l10n/); duplicates test/l10n/ coverage test; HE assertion weaker than EN's. |
| `learning_tracker/test/core/labels/curriculum_label_renderer_rtl_test.dart` | SOUND | t1-core-labels | Checked IL-7 separator-direction assertions; real constants, no shared state. |
| `learning_tracker/test/core/labels/curriculum_label_renderer_test.dart` | ISSUES | t1-core-labels | Named/ordinal/breadcrumb cases checked; no fullPath+Hebrew+named-ancestor case (masks P1 bug). |
| `learning_tracker/test/core/labels/curriculum_label_test.dart` | ISSUES | t1-core-labels | Only 3 of 8 CurriculumLabel modes covered; async/breadcrumb/parent modes untested. |
| `learning_tracker/test/core/labels/domain_term_labels_il2_test.dart` | SOUND | t1-core-labels | Checked Sephardi/Ashkenazi chazaros variant assertions against literal strings; sound. |
| `learning_tracker/test/core/labels/domain_term_labels_il5_test.dart` | SOUND | t1-core-labels | Checked stageLearn/resolveStoredStageName Limud normalisation against literal strings; sound. |
| `learning_tracker/test/core/labels/domain_term_labels_pp5_test.dart` | SOUND | t1-core-labels | Checked reverse-map collision fix (Chazara vs Review N) against literals; sound. |
| `learning_tracker/test/core/labels/domain_term_labels_vocab_test.dart` | SOUND | t1-core-labels | Checked 20+ toggle-driven vocab getters via real ProviderScope/pumpWidget; sound. |
| `learning_tracker/test/core/labels/hebrew_terms_follow_locale_test.dart` | SOUND | t1-core-labels | Checked resolveUseHebrewTerms truth table (locale OR toggle); pure function; sound. |
| `learning_tracker/test/core/logging/crashlytics_service_test.dart` | SOUND | t1-core-analytics-logging | Hand-rolled fake (TQ-4); directly asserts numeric-only PII-safe identifier encoding. |
| `learning_tracker/test/core/logging/logger_extended_test.dart` | SOUND | t1-core-analytics-logging | Thorough content-asserting coverage of structured/legacy API + PiiRedactor. |
| `learning_tracker/test/core/logging/logger_extra_test.dart` | ISSUES | t1-core-analytics-logging | Near-total weak-assertion duplicate of logger_extended_test.dart; adds no coverage. |
| `learning_tracker/test/core/logging/logger_test.dart` | ISSUES | t1-core-analytics-logging | Correct in isolation; 3 tests exercise dead-code setupFlutterErrorHandlers. |
| `learning_tracker/test/core/logging/riverpod_observer_test.dart` | SOUND | t1-core-analytics-logging | Exercises TalkerRiverpodObserver create/dispose wiring; proper teardown; no issues. |
| `learning_tracker/test/core/navigation/app_shell_test.dart` | ISSUES | t1-core-nav-utils | 1352 lines — AG-3 cap violation (3.4x); coverage itself thorough, non-tautological. |
| `learning_tracker/test/core/navigation/auth_guard_test.dart` | SOUND | t1-core-nav-utils | All 4 branches + fail-safe path covered; isolated DB seed, no tautologies. |
| `learning_tracker/test/core/navigation/child_mode_guard_test.dart` | SOUND | t1-core-nav-utils | All 5 branches incl. tutor-mirror + fail-closed throw covered; no tautologies. |
| `learning_tracker/test/core/navigation/pin_guard_test.dart` | ISSUES | t1-core-nav-utils | 646 lines — AG-3 violation; branch/session/scope coverage itself is thorough. |
| `learning_tracker/test/core/navigation/profile_guard_test.dart` | SOUND | t1-core-nav-utils | 4 branches + fail-open throw path covered; DB-backed, no shared containers. |
| `learning_tracker/test/core/navigation/restore_guard_reset_test.dart` | SOUND | t1-core-nav-utils | RESTORE-01 regression (R1-R4) verified against real guard cache-invalidation transitions. |
| `learning_tracker/test/core/navigation/restore_guard_test.dart` | SOUND | t1-core-nav-utils | 7 branches incl. cache + fail-open path; no wall-clock, no tautologies. |
| `learning_tracker/test/core/network/connectivity_service_test.dart` | ISSUES | t1-core-network | Tautological assertion, real network call, filename doesn't match renamed class. |
| `learning_tracker/test/core/network/dio_client_test.dart` | ISSUES | t1-core-network | Tests a dio client the real seed script never calls; reflection type-check. |
| `learning_tracker/test/core/network/sefaria/fetcher_test.dart` | ISSUES | t1-core-network | 831 lines testing a superseded fetcher pipeline; 'coverage' test is fake. |
| `learning_tracker/test/core/preferences/hebrew_terms_sentinel_test.dart` | ISSUES | t1-core-providers-prefs | 3 real tests plus 1 non-behavioral source-text-grep sub-test. |
| `learning_tracker/test/core/preferences/text_display_preferences_test.dart` | ISSUES | t1-core-providers-prefs | 184 lines testing a dead production class (TextDisplayPreferences). |
| `learning_tracker/test/core/providers/generated_providers_coverage_test.dart` | DEFECTIVE | t1-core-providers-prefs | 757 lines, every test only exercises riverpod_generator boilerplate. |
| `learning_tracker/test/core/services/calendar_program_registry_test.dart` | ISSUES | t1-core-services | Solid 20-program coverage; wrong dir, stale since May refactor (AG-5). |
| `learning_tracker/test/core/services/calendar_program_service_ref_extraction_test.dart` | DEFECTIVE | t1-core-services | Tests hand-copied dead logic; no production import; zero real coverage. |
| `learning_tracker/test/core/services/cross_curriculum_aggregator_test.dart` | ISSUES | t1-core-services | Deterministic aggregate() coverage is fine; stale test/core/services path (AG-5). |
| `learning_tracker/test/core/services/learning_program_repository_test.dart` | ISSUES | t1-core-services | Duplicates learning_program_service_test.dart almost entirely; also mispathed (AG-5). |
| `learning_tracker/test/core/services/learning_program_service_test.dart` | ISSUES | t1-core-services | Duplicate of repository_test + one tautological isNotNull assertion; mispathed. |
| `learning_tracker/test/core/streak/streak_event_test.dart` | ISSUES | t1-core-streak | Sound copyWith tests but misplaced (AG-5) and imports a name-colliding StreakEvent (AG-4). |
| `learning_tracker/test/core/streak/streak_state_provider_test.dart` | ISSUES | t1-core-streak | Solid D17 regression coverage; misplaced (AG-5), one weak assertion, TZ-dependent bucketing, delay-based sync. |
| `learning_tracker/test/core/sync/codecs_and_mergers_test.dart` | ISSUES | t1-core-sync-root | 1298 lines (AG-3); misplaced vs AG-5, no codec/merge mirrored path used. |
| `learning_tracker/test/core/sync/firestore_gateway_impl_test.dart` | ISSUES | t1-core-sync-root | 2039 lines; pushLedgerEntriesBatch missing FB-5 chunking; permission-denied test vacuous; FB-3 untested. |
| `learning_tracker/test/core/sync/firestore_listener_source_test.dart` | ISSUES | t1-core-sync-root | 281 lines, compliant size; one tautological self-comparison assertion at line 153. |
| `learning_tracker/test/core/sync/merge/drift_merge_store_test.dart` | ISSUES | t1-core-sync-merge | Excellent hermetic real-DB coverage incl. D15 clock-skew; 1842 lines exceeds AG-3 (B). |
| `learning_tracker/test/core/sync/merge/learning_ledger_merger_test.dart` | SOUND | t1-core-sync-merge | Hermetic real-DB regression coverage for the C1 snake_case bug; dedup asserted. |
| `learning_tracker/test/core/sync/merge/mergers_test.dart` | ISSUES | t1-core-sync-merge | Good hand-written fake pattern; fake remoteIsNewer drifts from production D15 logic (H); 460 lines (B). |
| `learning_tracker/test/core/sync/merge/notification_settings_merger_round_trip_test.dart` | ISSUES | t1-core-sync-merge | Strong WS5.clobber cross-profile regression coverage; fake omits clock-skew (H); 453 lines (B). |
| `learning_tracker/test/core/sync/merge/points_sync_merger_test.dart` | SOUND | t1-core-sync-merge | Hermetic real-DB cross-device convergence incl. redeem→decline refund loop. |
| `learning_tracker/test/core/sync/merge/streak_event_merger_test.dart` | SOUND | t1-core-sync-merge | Hermetic real-DB regression coverage for the C2 study_date bug; dedup asserted. |
| `learning_tracker/test/core/sync/outbox/outbox_processor_test.dart` | ISSUES | t1-core-sync-outbox | Thorough drain/backoff/dead-letter/guard coverage; 1773 lines (AG-3); R6-13 never constructs genuine drain overlap. |
| `learning_tracker/test/core/sync/push_pipeline_impl_test.dart` | ISSUES | t1-core-sync-root | 1295 lines (AG-3); ~17 duplicated routing tests; concurrency/single-flight coverage otherwise strong. |
| `learning_tracker/test/core/sync/sync_orchestrator_test.dart` | ISSUES | t1-core-sync-root | 1111 lines (AG-3); SY-3 timeout test tautological; throttle tests use wall-clock DateTime.now(). |
| `learning_tracker/test/core/theme/brand_coral_theme_test.dart` | SOUND | t1-core-theme-widgets | Real regression assertions on actual RGB/luminance values, not tautological. |
| `learning_tracker/test/core/theme/brand_wcag_il8_test.dart` | SOUND | t1-core-theme-widgets | Real WCAG contrast-ratio regression checks against computed luminance. |
| `learning_tracker/test/core/theme/text_styles_test.dart` | SOUND | t1-core-theme-widgets | Real assertions; 2 tests cover the dead methods flagged at lib level. |
| `learning_tracker/test/core/utils/.gitkeep` | ISSUES | t1-core-nav-utils | 0-byte placeholder; dir holds 7 real test files now — vestigial. |
| `learning_tracker/test/core/utils/date_utils_test.dart` | ISSUES | t1-core-nav-utils | Line 11 reads real DateTime.now() — wall-clock read, TQ-6 flake risk. |
| `learning_tracker/test/core/utils/gematriya_test.dart` | SOUND | t1-core-nav-utils | Exhaustive 1..999 round-trip + boundary/reject cases; strong, non-tautological. |
| `learning_tracker/test/core/utils/gematriya_ts6_test.dart` | SOUND | t1-core-nav-utils | TS-6 regression cases traced against forYear logic incl. millennium boundary. |
| `learning_tracker/test/core/utils/hebrew_calendar_utils_test.dart` | SOUND | t1-core-nav-utils | Coverage solid; ~40 lines test now-dead isShabbos/isYomTov (see source finding). |
| `learning_tracker/test/core/utils/hebrew_utils_test.dart` | SOUND | t1-core-nav-utils | Footnote-stripping (BUG-5) + nikud cases traced against source regex; correct. |
| `learning_tracker/test/core/utils/natural_sort_test.dart` | SOUND | t1-core-nav-utils | Digit-run boundary cases (9a/10a/99a/100a) covered; correct. |
| `learning_tracker/test/core/utils/pace_derivation_test.dart` | SOUND | t1-core-nav-utils | Clamp boundaries + ceil rounding covered; correct. |
| `learning_tracker/test/core/widgets/app_bar_title_test.dart` | SOUND | t1-core-theme-widgets | 5 tests, real widget-tree assertions covering text/child/scaling paths. |
| `learning_tracker/test/core/widgets/app_dialog_test.dart` | SOUND | t1-core-theme-widgets | Thorough overflow/keyboard/textScale edge-case coverage, real assertions. |
| `learning_tracker/test/core/widgets/app_error_view_test.dart` | SOUND | t1-core-theme-widgets | Well-formed tests; asserts on the hardcoded strings flagged at lib level. |
| `learning_tracker/test/core/widgets/curriculum_indicator_test.dart` | ISSUES | t1-core-theme-widgets | 207 lines of real assertions testing a widget with zero production callers. |
| `learning_tracker/test/core/widgets/empty_state_test.dart` | SOUND | t1-core-theme-widgets | 8 tests, real assertions, covers all optional-param branches. |
| `learning_tracker/test/core/widgets/error_display_test.dart` | SOUND | t1-core-theme-widgets | Real assertions; confirms the hardcoded 'Retry' text flagged at lib level. |
| `learning_tracker/test/core/widgets/loading_indicator_test.dart` | SOUND | t1-core-theme-widgets | Real assertions covering size/message optional branches correctly. |
| `learning_tracker/test/core/widgets/pin_entry_widget_test.dart` | ISSUES | t1-core-theme-widgets | Thorough overall; one test doesn't actually verify error-color styling. |
| `learning_tracker/test/core/widgets/track_progress_bar_test.dart` | ISSUES | t1-core-theme-widgets | 98 lines of real assertions testing a widget with zero production callers. |
| `learning_tracker/test/e2e/harness/e2e_harness.dart` | ISSUES | t1-test-cross | 664 lines (AG-3); harness design otherwise sound — guards, cleanup all correct. |
| `learning_tracker/test/e2e/journeys/auth_p0_test.dart` | SOUND | t1-test-cross | Read fully; skips justified as device-only; assertions real; harness/dispose counts matched. |
| `learning_tracker/test/e2e/journeys/auth_p1_test.dart` | ISSUES | t1-test-cross | 605 lines (AG-3); duplicates 4 override helpers also in 3 sibling files. |
| `learning_tracker/test/e2e/journeys/auth_sync_infra_p2_test.dart` | ISSUES | t1-test-cross | 601 lines (AG-3); duplicates same 4 override helpers verbatim (Finding C). |
| `learning_tracker/test/e2e/journeys/dashboard_p0_test.dart` | ISSUES | t1-test-cross | 582 lines (AG-3); _stubTrack/_dashboardActiveTracksOverrides duplicated verbatim in dashboard_p1. |
| `learning_tracker/test/e2e/journeys/dashboard_p1_test.dart` | ISSUES | t1-test-cross | 673 lines (AG-3); duplicates dashboard_p0's helpers byte-for-byte (Finding C). |
| `learning_tracker/test/e2e/journeys/gamification_p0_test.dart` | DEFECTIVE | t1-test-cross | E2E-601 skip is stale (bug fixed 2026-06-19); P0 journey has zero coverage. |
| `learning_tracker/test/e2e/journeys/gamification_p1_test.dart` | ISSUES | t1-test-cross | 933 lines (AG-3, batch's largest); E2E-608 Pt.2 under-asserts; swallow-all catch L136. |
| `learning_tracker/test/e2e/journeys/guards_p1_test.dart` | ISSUES | t1-test-cross | 496 lines (AG-3); duplicates _sacredWindowNullOverride/_incomingGrantsEmpty helpers (Finding C). |
| `learning_tracker/test/e2e/journeys/guards_sync_p0_test.dart` | ISSUES | t1-test-cross | 560 lines (AG-3); duplicates same silence-override helpers verbatim (Finding C). |
| `learning_tracker/test/e2e/journeys/hebrew_rtl_p1_test.dart` | ISSUES | t1-test-cross | Stale R-OB7 bug-skip (already fixed upstream); 655 lines exceeds AG-3. |
| `learning_tracker/test/e2e/journeys/infra_p0_test.dart` | ISSUES | t1-test-cross | Assertions sound, honest device-skip rationale; 478 lines exceeds AG-3. |
| `learning_tracker/test/e2e/journeys/infra_p1_test.dart` | ISSUES | t1-test-cross | EH-5 leak documented (E2E-1113), tautological E2E-1108, 924 lines exceeds AG-3. |
| `learning_tracker/test/e2e/journeys/learning_p0_test.dart` | ISSUES | t1-test-cross | Correct fakes but duplicated across files; 982 lines, worst AG-3 offender in batch. |
| `learning_tracker/test/e2e/journeys/learning_p1_test.dart` | ISSUES | t1-test-cross | Duplicated fake's filterByLevel silently drops filters; 833 lines exceeds AG-3. |
| `learning_tracker/test/e2e/journeys/learning_sched_gam_p2_test.dart` | ISSUES | t1-test-cross | Assertions sound, honest gap notes (R-GA10); 700 lines exceeds AG-3. |
| `learning_tracker/test/e2e/journeys/onboarding_p0_test.dart` | SOUND | t1-test-cross | Fresh harness/test, meaningful assertions, honest skips, 208 lines, no issues. |
| `learning_tracker/test/e2e/journeys/onboarding_p1_test.dart` | ISSUES | t1-test-cross | Assertions and skip rationale sound; 492 lines exceeds AG-3. |
| `learning_tracker/test/e2e/journeys/onboarding_tracks_p2_test.dart` | ISSUES | t1-test-cross | Assertions exercise real provider logic soundly; 570 lines exceeds AG-3. |
| `learning_tracker/test/e2e/journeys/overflow_sweep_p2_test.dart` | ISSUES | t1-test-cross | 1576 lines (AG-3); 14 skips falsely claim on-device overflow coverage exists. |
| `learning_tracker/test/e2e/journeys/profiles_p0_test.dart` | ISSUES | t1-test-cross | 672 lines (AG-3); shares duplicated fixture helpers with 4 sibling files. |
| `learning_tracker/test/e2e/journeys/profiles_p1_test.dart` | ISSUES | t1-test-cross | 918 lines (AG-3); duplicates _navigateTo/silence-override helpers verbatim from siblings. |
| `learning_tracker/test/e2e/journeys/profiles_tutoring_p2_test.dart` | ISSUES | t1-test-cross | 551 lines (AG-3); E2E-721 rename sub-test silently no-ops, no weaken-ok tag. |
| `learning_tracker/test/e2e/journeys/progress_p0_test.dart` | ISSUES | t1-test-cross | 729 lines (AG-3); duplicate _EmptyContentRepository; toggle tests assert label not state. |
| `learning_tracker/test/e2e/journeys/progress_p1_test.dart` | ISSUES | t1-test-cross | 861 lines (AG-3); E2E-812 false locale claim; E2E-806 never exercises its own claim. |
| `learning_tracker/test/e2e/journeys/reference_onboarding_to_dashboard_journey_test.dart` | SOUND | t1-test-cross | 141 lines; hermetic, real DB assertions, no wall-clock, no duplication, checked fully. |
| `learning_tracker/test/e2e/journeys/scheduler_p0_test.dart` | ISSUES | t1-test-cross | 676 lines (AG-3); Dafim toggle test asserts label presence not real selection. |
| `learning_tracker/test/e2e/journeys/scheduler_p1_test.dart` | ISSUES | t1-test-cross | AG-3 1066 lines; E2E-516 fake RTL pump; R-SC1/R-SC2 assert known bugs as correct. |
| `learning_tracker/test/e2e/journeys/settings_p0_test.dart` | ISSUES | t1-test-cross | AG-3 762 lines only; otherwise clean: fresh harness, DateTimeFactory, one justified device-only skip. |
| `learning_tracker/test/e2e/journeys/settings_p1_test.dart` | ISSUES | t1-test-cross | AG-3 1011 lines; E2E-922 skipped on false 'locale hardcoded' claim; zero tile-hiding coverage. |
| `learning_tracker/test/e2e/journeys/sync_p1_test.dart` | ISSUES | t1-test-cross | AG-3 828 lines only; other device-only skips verified genuine; DB/outbox assertions solid. |
| `learning_tracker/test/e2e/journeys/tracks_p0_test.dart` | ISSUES | t1-test-cross | AG-3 560 lines only; otherwise clean: real DB assertions after every UI action. |
| `learning_tracker/test/e2e/journeys/tracks_p1_test.dart` | ISSUES | t1-test-cross | AG-3 675 lines; E2E-416 fake RTL pump; dangling R-TR5 comment cites a missing assertion. |
| `learning_tracker/test/e2e/journeys/tutoring_p0_test.dart` | ISSUES | t1-test-cross | AG-3 972 lines only; otherwise clean: hand-written fakes, real interaction assertions, justified skips. |
| `learning_tracker/test/e2e/journeys/tutoring_p1_test.dart` | ISSUES | t1-test-cross | 1344 lines (AG-3); fakes/clock/assertions sound; well-documented device-only skips. |
| `learning_tracker/test/features/account/data/services/magic_link_service_test.dart` | ISSUES | t1-feat-account | Excellent coverage; 20x wall-clock Future.delayed(50ms); shares duplicated _extractFirebaseCode with upgrade service. |
| `learning_tracker/test/features/account/domain/services/account_lifecycle_db_delete_test.dart` | SOUND | t1-feat-account | Solid targeted regression test; underlying _deleteDbFile duplicated in pending_local_signup.dart (see finding). |
| `learning_tracker/test/features/account/domain/services/pending_local_signup_file_cleanup_test.dart` | SOUND | t1-feat-account | Solid targeted regression test; same _deleteDbFile logic duplicated in account_lifecycle_service.dart. |
| `learning_tracker/test/features/account/domain/services/upgrade_to_cloud_service_test.dart` | SOUND | t1-feat-account | Exhaustive coverage of all upgrade/collision paths; _extractFirebaseCode duplicated (see finding). |
| `learning_tracker/test/features/account/onboarding/presentation/screens/onboarding_intent_screen_l10n_test.dart` | SOUND | t1-feat-account | Checked EN/HE l10n regression coverage and callback wiring; correctly mirrored, no issues. |
| `learning_tracker/test/features/account/onboarding/presentation/screens/signup_screen_l1_test.dart` | ISSUES | t1-feat-account | Good UI coverage; offline tap-through untested; demonstrates raw-English InvalidInputException reaching UI. |
| `learning_tracker/test/features/account/onboarding/signup_screen_an10_test.dart` | DEFECTIVE | t1-feat-account | Never imports/renders real SignupScreen; tests a decoupled synthetic replica widget only. |
| `learning_tracker/test/features/account/pending_signup_and_mode_card_test.dart` | SOUND | t1-feat-account | 20 well-structured cases, real widget under test, EN+HE coverage; no issues. |
| `learning_tracker/test/features/account/presentation/account_picker_switch_test.dart` | ISSUES | t1-feat-account | Excellent switch-account coverage; file misplaced outside mirrored screens/ subdirectory (AG-5). |
| `learning_tracker/test/features/account/presentation/notifiers/sign_in_controller_routing_test.dart` | SOUND | t1-feat-account | Thorough branch coverage; argon2id-blocked branches transparently documented and justified skip. |
| `learning_tracker/test/features/account/presentation/notifiers/sign_in_controller_test.dart` | ISSUES | t1-feat-account | 807 lines (AG-3); duplicate mock class; no ref.mounted/dispose-mid-flight coverage (SM-4). |
| `learning_tracker/test/features/account/presentation/notifiers/sign_in_google_signout_throws_test.dart` | ISSUES | t1-feat-account | Duplicate mock class; unseeded DateTime.now() in fixtures; otherwise solid regression tests. |
| `learning_tracker/test/features/account/presentation/notifiers/sign_in_local_signout_throws_test.dart` | ISSUES | t1-feat-account | Duplicate _MockAuthRepository class; otherwise a solid, focused signOut-throws regression test. |
| `learning_tracker/test/features/account/presentation/notifiers/sign_in_verify_signout_throws_test.dart` | ISSUES | t1-feat-account | Duplicate _MockAuthRepository class; otherwise a clean, minimal, well-targeted regression test. |
| `learning_tracker/test/features/account/presentation/notifiers/sign_in_wrong_password_no_callback_test.dart` | ISSUES | t1-feat-account | Duplicate mock class; manual end-of-test cleanup skipped when an assertion fails. |
| `learning_tracker/test/features/account/presentation/providers/connectivity_providers_test.dart` | ISSUES | t1-feat-account | 450 lines (AG-3); otherwise excellent hermetic debounce/self-heal coverage with mocked HTTP. |
| `learning_tracker/test/features/account/presentation/screens/account_picker_an4_test.dart` | DEFECTIVE | t1-feat-account | Regression tests exercise a hand-copied replica, never the real AccountPickerScreen sort/tap-guard code. |
| `learning_tracker/test/features/account/presentation/screens/account_picker_local_data_missing_test.dart` | ISSUES | t1-feat-account | Hardcoded expected SnackBar string instead of l10n getter; otherwise tests the real screen well. |
| `learning_tracker/test/features/account/presentation/screens/account_picker_screen_l1_test.dart` | ISSUES | t1-feat-account | 815 lines (AG-3); manual teardown skips DB close on failure; duplicated fixture boilerplate. |
| `learning_tracker/test/features/account/presentation/widgets/email_verification_confirm_panel_overflow_test.dart` | SOUND | t1-feat-account | Verified via flutter test: LTR/RTL overflow matrix passes; confirms the H1 fix elsewhere. |
| `learning_tracker/test/features/account/presentation/widgets/email_verification_confirm_panel_test.dart` | DEFECTIVE | t1-feat-account | 1017 lines (AG-3); pins hardcoded English strings as correct; stale skip hides a now-passing test. |
| `learning_tracker/test/features/account/presentation/widgets/offline_top_banner_l1_test.dart` | ISSUES | t1-feat-account | 610 lines (AG-3); otherwise a model l10n-aware RTL regression suite for this banner. |
| `learning_tracker/test/features/account/presentation/widgets/sign_in_form_an9_an11_an12_test.dart` | SOUND | t1-feat-account | Tests the real SignInForm widget; clean AN-9/11/12 regression coverage; no gaps found. |
| `learning_tracker/test/features/account/sign_in_context_reset_test.dart` | ISSUES | t1-feat-account | Wiring tests grep source text instead of exercising the real runtime call chain. |
| `learning_tracker/test/features/auth/.gitkeep` | SOUND | t1-feat-auth | Empty placeholder; harmless but vestigial once dir populated (see AG-5 finding). |
| `learning_tracker/test/features/auth/auth_integration_test.dart` | ISSUES | t1-feat-auth | AG-5 misplaced; fully redundant with auth_repository_impl_test.dart (identical mocks/setup). |
| `learning_tracker/test/features/auth/data/repositories/auth_repository_impl_test.dart` | ISSUES | t1-feat-auth | AG-5 misplaced; 536 lines over AG-3 cap; coverage itself is thorough/accurate. |
| `learning_tracker/test/features/auth/domain/models/auth_state_test.dart` | ISSUES | t1-feat-auth | AG-5 misplaced; 3 groups triplicate the same AuthState assertions. |
| `learning_tracker/test/features/auth/domain/services/auth_exceptions_test.dart` | ISSUES | t1-feat-auth | AG-5 misplaced/misnamed; asserts inconsistent PII redaction across sibling exceptions. |
| `learning_tracker/test/features/auth/domain/services/local_auth_service_test.dart` | ISSUES | t1-feat-auth | AG-5 misplaced only; hermetic in-memory-DB signUp/signIn coverage is accurate. |
| `learning_tracker/test/features/auth/domain/services/pending_local_registration_test.dart` | ISSUES | t1-feat-auth | AG-5 misplaced/misnamed; near-total duplicate of pending_local_signup_test.dart, same batch. |
| `learning_tracker/test/features/auth/domain/services/pending_local_signup_test.dart` | ISSUES | t1-feat-auth | AG-5 misplaced; duplicated by pending_local_registration_test.dart (same batch, same subject). |
| `learning_tracker/test/features/auth/presentation/screens/sign_in_screen_test.dart` | ISSUES | t1-feat-auth | AG-5 misplaced; HOTSPOT's registry-mode + forgot-password logic entirely untested. |
| `learning_tracker/test/features/content_browsing/.gitkeep` | SOUND | t1-feat-content_browsing | Empty placeholder file, 0 lines. |
| `learning_tracker/test/features/content_browsing/content_tile_search_providers_test.dart` | ISSUES | t1-feat-content_browsing | 1268 lines, unmirrored to one lib file; one dead-container test. |
| `learning_tracker/test/features/content_browsing/data/repositories/content_repository_impl_logic_test.dart` | SOUND | t1-feat-content_browsing | Correctly exercises real repository methods via fake subclass. |
| `learning_tracker/test/features/content_browsing/data/repositories/content_repository_impl_test.dart` | DEFECTIVE | t1-feat-content_browsing | Tautological where()-only tests plus stale/false-premise skipped group. |
| `learning_tracker/test/features/content_browsing/data/repositories/content_repository_test.dart` | ISSUES | t1-feat-content_browsing | False skip hides working content-load path + a real, confirmed search bug. |
| `learning_tracker/test/features/content_browsing/data/repositories/scoped_content_test.dart` | SOUND | t1-feat-content_browsing | getScopedContent: empty/single/multi-value/level1-4/no-match all verified via seeded subclass. |
| `learning_tracker/test/features/content_browsing/data/repositories/text_cache_repository_extended_test.dart` | ISSUES | t1-feat-content_browsing | ~80% scenario-duplicate of extra_test.dart; same-day parallel coverage-wave commits. |
| `learning_tracker/test/features/content_browsing/data/repositories/text_cache_repository_extra_test.dart` | ISSUES | t1-feat-content_browsing | Duplicates extended_test.dart's scenarios; added same day by a separate coverage pass. |
| `learning_tracker/test/features/content_browsing/data/repositories/text_cache_repository_test.dart` | SOUND | t1-feat-content_browsing | Only file covering the null/uncached-ref path; real Drift DAOs, fixed clock. |
| `learning_tracker/test/features/content_browsing/data/services/cloud_content_service_test.dart` | SOUND | t1-feat-content_browsing | Manifest/hierarchy/text-chunk parsing + checkForUpdates covered via injected-fetcher seam. |
| `learning_tracker/test/features/content_browsing/data/services/text_download_service_test.dart` | SOUND | t1-feat-content_browsing | Mocktail interaction checks match the documented deprecated-stub behavior. |
| `learning_tracker/test/features/content_browsing/domain/strategies/composite_curriculum_strategy_test.dart` | SOUND | t1-feat-content_browsing | Registry, default remap, Tanach-specific remap covered; isSyntheticContainerLevel1 untested but trivial. |
| `learning_tracker/test/features/content_browsing/integration/hierarchy_navigation_test.dart` | ISSUES | t1-feat-content_browsing | First test's assertion accepts any exception — verifies nothing about navigation. |
| `learning_tracker/test/features/content_browsing/integration/text_display_integration_test.dart` | SOUND | t1-feat-content_browsing | Small but real: null/uncached-ref path against real DAOs, twice. |
| `learning_tracker/test/features/content_browsing/presentation/screens/content_hierarchy_screen_i18n_test.dart` | SOUND | t1-feat-content_browsing | CH-01 Hebrew/English AppBar + empty-state strings verified against real screen+locale. |
| `learning_tracker/test/features/content_browsing/presentation/screens/content_hierarchy_screen_test.dart` | SOUND | t1-feat-content_browsing | Thorough real-widget nav: back button, root chip, ancestor crumb, R5-6 depth clamp. |
| `learning_tracker/test/features/content_browsing/presentation/screens/content_search_screen_test.dart` | ISSUES | t1-feat-content_browsing | Renders real screen but never asserts the clear-button/suffixIcon exists. |
| `learning_tracker/test/features/content_browsing/presentation/screens/curriculum_list_screen_test.dart` | ISSUES | t1-feat-content_browsing | Same 'any exception' navigation tautology as hierarchy_navigation_test.dart. |
| `learning_tracker/test/features/content_browsing/presentation/screens/pp18_content_search_clear_button_test.dart` | DEFECTIVE | t1-feat-content_browsing | Tests a hand-rolled TextField clone; never imports/renders real ContentSearchScreen. |
| `learning_tracker/test/features/content_browsing/presentation/screens/r2_content_hierarchy_nav_test.dart` | SOUND | t1-feat-content_browsing | Real widget; real chevron-direction + real handlePopRoute() system-back verification. |
| `learning_tracker/test/features/content_browsing/presentation/screens/text_display_screen_deep_l1_test.dart` | ISSUES | t1-feat-content_browsing | Strong overall; one 'Gematriya correctness' test checks a hand-copied table against itself. |
| `learning_tracker/test/features/content_browsing/presentation/screens/text_display_screen_l1_test.dart` | ISSUES | t1-feat-content_browsing | High quality but ~50% scenario-overlap with text_display_screen_test.dart, unconsolidated. |
| `learning_tracker/test/features/content_browsing/presentation/screens/text_display_screen_test.dart` | ISSUES | t1-feat-content_browsing | Largely subsumed by later text_display_screen_l1_test.dart, added without removing this one. |
| `learning_tracker/test/features/content_browsing/presentation/widgets/breadcrumb_navigation_test.dart` | SOUND | t1-feat-content_browsing | Tap-to-navigate, current-level style, empty stack, depth-4, scroll all on real widget. |
| `learning_tracker/test/features/content_browsing/presentation/widgets/content_item_tile_overflow_test.dart` | SOUND | t1-feat-content_browsing | Real device-matrix long-press overflow guard on the real _StageBreakdownSheet. |
| `learning_tracker/test/features/content_browsing/presentation/widgets/content_item_tile_test.dart` | SOUND | t1-feat-content_browsing | Hebrew/English toggle, badges, chazara showReviewBadge gate verified on real widget. |
| `learning_tracker/test/features/content_browsing/presentation/widgets/il7_il9_breadcrumb_selection_test.dart` | SOUND | t1-feat-content_browsing | IL-7 verified on real widget; IL-9 l10n string checked (widget coverage lives elsewhere). |
| `learning_tracker/test/features/content_browsing/presentation/widgets/r2_breadcrumb_current_crumb_test.dart` | SOUND | t1-feat-content_browsing | Real widget; ellipsis/no-overflow verified in both LTR and RTL at scale 1.3. |
| `learning_tracker/test/features/content_browsing/presentation/widgets/r2_panel_leaf_crumb_ellipsis_test.dart` | ISSUES | t1-feat-content_browsing | Mutation-verified real regression pin; but ConstrainedBox assertion tautological, RTL chevron bug unpinned. |
| `learning_tracker/test/features/dashboard/.gitkeep` | ISSUES | t1-feat-dashboard | Redundant placeholder; dir already populated via domain/ and presentation/ subdirs. |
| `learning_tracker/test/features/dashboard/domain/services/dashboard_track_completion_migration_test.dart` | SOUND | t1-feat-dashboard | Real Drift DB; pins live TrackProgressService/TrackCompletionService parity across tiers. |
| `learning_tracker/test/features/dashboard/domain/services/next_reward_selector_test.dart` | SOUND | t1-feat-dashboard | Thorough milestone-selection edge cases; deterministic, no wall clock. |
| `learning_tracker/test/features/dashboard/domain/services/track_completion_service_test.dart` | SOUND | t1-feat-dashboard | Unit tests pin live production formula; edge cases well covered. |
| `learning_tracker/test/features/dashboard/domain/use_cases/compute_pace_status_use_case_test.dart` | SOUND | t1-feat-dashboard | Pace/deadline paths and UTC-normalization helper both covered. |
| `learning_tracker/test/features/dashboard/presentation/providers/dashboard_child_next_reward_test.dart` | SOUND | t1-feat-dashboard | Low-value ctor/field tests but harmless; no defects found. |
| `learning_tracker/test/features/dashboard/presentation/providers/dashboard_completion_percentage_test.dart` | ISSUES | t1-feat-dashboard | Excellent regression guards (curriculum scoping, stageOrder-vs-id); 759 lines exceeds AG-3. |
| `learning_tracker/test/features/dashboard/presentation/providers/dashboard_pace_status_test.dart` | SOUND | t1-feat-dashboard | Real PaceCalculator math; explicit old-placeholder-bug regression guard. |
| `learning_tracker/test/features/dashboard/presentation/providers/dashboard_providers_test.dart` | ISSUES | t1-feat-dashboard | Excellent coverage; 1325 lines (AG-3) and one wall-clock DateTime.now() (TQ-6). |
| `learning_tracker/test/features/dashboard/presentation/providers/dashboard_user_mode_test.dart` | SOUND | t1-feat-dashboard | Fresh containers/DB per test; tutor-mode Bug-1 regression covered well. |
| `learning_tracker/test/features/dashboard/presentation/screens/dashboard_screen_test.dart` | ISSUES | t1-feat-dashboard | Verbose l10n boilerplate; flagship/hotspot screen has no Locale('he') variant. |
| `learning_tracker/test/features/dashboard/presentation/widgets/active_track_card_layout_test.dart` | SOUND | t1-feat-dashboard | Uses clean AppLocalizations.localizationsDelegates shortcut; overflow/prominence well covered. |
| `learning_tracker/test/features/dashboard/presentation/widgets/active_track_unit_label_test.dart` | SOUND | t1-feat-dashboard | Thorough Hebrew/English label and ref-ordering regression coverage. |
| `learning_tracker/test/features/dashboard/presentation/widgets/active_tracks_carousel_rtl_test.dart` | SOUND | t1-feat-dashboard | Explicit LTR+RTL chevron-mirroring regression test; correctly exercises Locale('he'). |
| `learning_tracker/test/features/dashboard/presentation/widgets/dashboard_body_stats_resolve_test.dart` | SOUND | t1-feat-dashboard | Good BUG-#35 regression via mocktail; minor l10n-boilerplate pattern noted elsewhere. |
| `learning_tracker/test/features/dashboard/presentation/widgets/dashboard_body_streak_nav_test.dart` | SOUND | t1-feat-dashboard | Good E1 nav regression via mocktail verify/captureAny; no defects. |
| `learning_tracker/test/features/dashboard/presentation/widgets/dashboard_empty_states_overflow_test.dart` | SOUND | t1-feat-dashboard | Uses shared overflow_harness helper correctly across device/text-scale matrix. |
| `learning_tracker/test/features/dashboard/presentation/widgets/dashboard_level_points_card_gating_test.dart` | SOUND | t1-feat-dashboard | Good BUG-7 adult/child points-gating test; no defects found. |
| `learning_tracker/test/features/dashboard/presentation/widgets/dashboard_level_points_card_skeleton_pp15_test.dart` | SOUND | t1-feat-dashboard | Good PP-15 skeleton-guard test across three readiness states. |
| `learning_tracker/test/features/dashboard/presentation/widgets/dashboard_tier_row_test.dart` | ISSUES | t1-feat-dashboard | Excellent real-DB integration coverage; 793 lines exceeds AG-3 cap. |
| `learning_tracker/test/features/dashboard/presentation/widgets/dashboard_todays_missions_heading_test.dart` | ISSUES | t1-feat-dashboard | Heading-truncation checks sound; leaks real DB, dead exception-drain, untracked tags. |
| `learning_tracker/test/features/gamification/.gitkeep` | SOUND | t1-feat-gamification | Empty placeholder file; nothing to audit. |
| `learning_tracker/test/features/gamification/domain/models/reward_milestone_test.dart` | SOUND | t1-feat-gamification | Checked round-trip/copyWith/edge-case coverage of both model classes. |
| `learning_tracker/test/features/gamification/domain/reward_milestone_icons_test.dart` | SOUND | t1-feat-gamification | Checked clampIndex/iconForIndex boundary and negative-index coverage. |
| `learning_tracker/test/features/gamification/domain/services/points_service_test.dart` | ISSUES | t1-feat-gamification | 429 lines, exceeds AG-3's 400-line cap. |
| `learning_tracker/test/features/gamification/domain/services/reward_milestone_service_extended_test.dart` | ISSUES | t1-feat-gamification | 468 lines, exceeds AG-3's 400-line cap. |
| `learning_tracker/test/features/gamification/domain/services/reward_milestone_service_test.dart` | DEFECTIVE | t1-feat-gamification | 1337 lines; duplicate test groups for 3+ methods, dup of sibling file too. |
| `learning_tracker/test/features/gamification/domain/services/streak_service_extended_test.dart` | ISSUES | t1-feat-gamification | Fully redundant with streak_service_recovery_test.dart; weaker assertions. |
| `learning_tracker/test/features/gamification/domain/services/streak_service_recovery_test.dart` | ISSUES | t1-feat-gamification | Sound tests, but duplicated wholesale by streak_service_extended_test.dart. |
| `learning_tracker/test/features/gamification/domain/services/streak_service_test.dart` | SOUND | t1-feat-gamification | Scoped to getStreakCalendar only; checked no overlap with sibling files. |
| `learning_tracker/test/features/gamification/ga2_input_bounds_test.dart` | SOUND | t1-feat-gamification | Checked exact boundary tests for name-length/points-cost caps. |
| `learning_tracker/test/features/gamification/ga3_duplicate_threshold_test.dart` | SOUND | t1-feat-gamification | Checked duplicate-threshold-removed regression; persistence verified. |
| `learning_tracker/test/features/gamification/ga4_reentrance_guard_test.dart` | ISSUES | t1-feat-gamification | Docstring describes an InviteTutor test this file doesn't contain. |
| `learning_tracker/test/features/gamification/ga7_reward_edit_mode_test.dart` | SOUND | t1-feat-gamification | Checked thorough canSave/isEditing boundary coverage incl. whitespace/non-numeric. |
| `learning_tracker/test/features/gamification/ga8_capitalization_test.dart` | ISSUES | t1-feat-gamification | 2 of 3 groups assert tutoring-feature ARB keys, not gamification. |
| `learning_tracker/test/features/gamification/presentation/providers/achievements_overview_provider_test.dart` | SOUND | t1-feat-gamification | Checked field-report regression + boundary-equal-threshold case, fresh containers. |
| `learning_tracker/test/features/gamification/presentation/providers/achievements_overview_staleness_after_redemption_test.dart` | SOUND | t1-feat-gamification | Checked deterministic invalidate()+read(.future) sync, multi-redemption case. |
| `learning_tracker/test/features/gamification/presentation/providers/curriculum_breakdown_staleness_test.dart` | ISSUES | t1-feat-gamification | Wall-clock Future.delayed(50ms) used to await provider re-evaluation. |
| `learning_tracker/test/features/gamification/presentation/providers/points_providers_reactive_test.dart` | ISSUES | t1-feat-gamification | 6x wall-clock Future.delayed calls to synchronize stream emissions. |
| `learning_tracker/test/features/gamification/presentation/providers/reward_config_controller_test.dart` | ISSUES | t1-feat-gamification | 3 tests pin unreachable RewardSaveNoTrack/per-track branches; DB never closed; 1041 lines. |
| `learning_tracker/test/features/gamification/presentation/screens/child_redemption_balance_reactive_test.dart` | SOUND | t1-feat-gamification | Real DAO writes + stream assertions for DG-RDMP-01; DB closed correctly; checked wall-clock sync. |
| `learning_tracker/test/features/gamification/presentation/screens/child_redemption_rewards_staleness_test.dart` | SOUND | t1-feat-gamification | Real controller.saveReward/deleteMilestone drive invalidation; DB closed; verified DG-RDMP-02 regression is real. |
| `learning_tracker/test/features/gamification/presentation/screens/child_redemption_screen_l1_test.dart` | ISSUES | t1-feat-gamification | Thorough L1 coverage incl. tutor guard/RTL/#31/#39; 2 of 9 db factories never close; 859 lines. |
| `learning_tracker/test/features/gamification/presentation/screens/gamification_screen_l1_test.dart` | ISSUES | t1-feat-gamification | Good filter/RTL/streak coverage; wildcard arm on sealed AsyncValue switch (EH-6); 672 lines; no db leak. |
| `learning_tracker/test/features/gamification/presentation/screens/parent_pending_redemptions_screen_l1_test.dart` | ISSUES | t1-feat-gamification | Excellent DB-backed coverage incl. real double-tap guard; header comment stale re: fixed BUG; 748 lines. |
| `learning_tracker/test/features/gamification/presentation/screens/pending_redemptions_reactive_test.dart` | SOUND | t1-feat-gamification | Real watchPendingRedemptions stream assertions for DG-PND-05; DB closed correctly. |
| `learning_tracker/test/features/gamification/presentation/screens/reward_configuration_screen_l1_test.dart` | ISSUES | t1-feat-gamification | Strong fake-controller coverage; 1 test pins dead RewardSaveDuplicateThreshold path; DB unclosed; 709 lines. |
| `learning_tracker/test/features/gamification/presentation/widgets/achievement_cards_unlock_test.dart` | SOUND | t1-feat-gamification | Focused #36/#37 regression coverage on real widgets; no DB/mocks needed; checked clean. |
| `learning_tracker/test/features/gamification/presentation/widgets/achievement_unlock_celebration_overflow_test.dart` | SOUND | t1-feat-gamification | Reuses shared overflow_harness across device/locale matrix; verified genuine widget-level check. |
| `learning_tracker/test/features/gamification/presentation/widgets/achievement_unlock_celebration_test.dart` | DEFECTIVE | t1-feat-gamification | ~400 of 575 lines simulate a dialog unreachable in prod since DEC-32; DB never closed. |
| `learning_tracker/test/features/gamification/presentation/widgets/points_display_widget_test.dart` | SOUND | t1-feat-gamification | Real provider overrides, checks child/adult gating + Hebrew curriculum labels; no issues found. |
| `learning_tracker/test/features/gamification/presentation/widgets/streak_widget_test.dart` | SOUND | t1-feat-gamification | Real widget rendering, adult/child variants + singular-day pluralization regression; no issues found. |
| `learning_tracker/test/features/gamification/r_ga2_global_milestone_stays_unlocked_after_redemption_test.dart` | SOUND | t1-feat-gamification | Real DB pre/post-condition regression proving lifetime-earned vs balance semantics; DB closed correctly. |
| `learning_tracker/test/features/labels/domain_term_rendering_modes_test.dart` | ISSUES | t1-feat-labels | 1088 lines (AG-3); all 11 groups duplicate mirrored per-feature/core tests (AG-5) |
| `learning_tracker/test/features/learning/.gitkeep` | SOUND | t1-feat-learning | Empty placeholder file; nothing to audit. |
| `learning_tracker/test/features/learning/data/completion_writer_test.dart` | ISSUES | t1-feat-learning | 1065 lines; duplicates CompletionSource matrix and tutor-block tests owned elsewhere. |
| `learning_tracker/test/features/learning/data/repositories/bookmark_repository_impl_test.dart` | ISSUES | t1-feat-learning | Good coverage of bookmark/merge logic; wall-clock DateTime.now() in fixtures. |
| `learning_tracker/test/features/learning/data/repositories/completion_repository_curriculum_dedup_test.dart` | SOUND | t1-feat-learning | Real-DB R6-19 dedup-key regression; checked cross-curriculum isolation, consistent UTC fixtures. |
| `learning_tracker/test/features/learning/data/repositories/completion_repository_impl_test.dart` | ISSUES | t1-feat-learning | Solid real-DB coverage of markComplete/bulkMark/streak; 465 lines, wall-clock fixture. |
| `learning_tracker/test/features/learning/data/repositories/completion_repository_streak_tee_test.dart` | SOUND | t1-feat-learning | Checked real OutboxSyncWriteFacade wiring for streak tee and null-facade path. |
| `learning_tracker/test/features/learning/data/repositories/h4_lifetime_only_detection_test.dart` | ISSUES | t1-feat-learning | Good H4 regression coverage; masks fire-and-forget race with a delay() hack. |
| `learning_tracker/test/features/learning/data/repositories/learning_ledger_repository_impl_test.dart` | ISSUES | t1-feat-learning | Thorough coverage incl. careful UTC sentinel-date handling; 465 lines over AG-3 cap. |
| `learning_tracker/test/features/learning/data/repositories/track_repository_test.dart` | SOUND | t1-feat-learning | Checked per-curriculum track initialization against real in-memory Drift DB. |
| `learning_tracker/test/features/learning/domain/entities/batch_plan_test.dart` | SOUND | t1-feat-learning | Checked BatchPlan.classify, credit-tier predicates, exhaustive switch, toString. |
| `learning_tracker/test/features/learning/domain/entities/bookmark_entity_test.dart` | SOUND | t1-feat-learning | Checked copyWith overrides and fromFirestore parse/error path. |
| `learning_tracker/test/features/learning/domain/services/completion_detection_service_test.dart` | ISSUES | t1-feat-learning | Rigorous N+1/scope-string regression coverage; 753 lines, wall-clock fixture. |
| `learning_tracker/test/features/learning/domain/use_cases/bulk_mark_completion_use_case_test.dart` | SOUND | t1-feat-learning | Checked engagement gate + sentinel-date enforcement via clean interaction verification. |
| `learning_tracker/test/features/learning/domain/use_cases/mark_completion_use_case_b1_test.dart` | ISSUES | t1-feat-learning | Canonical 3x3 credit matrix; later duplicated in completion_writer_test.dart. |
| `learning_tracker/test/features/learning/domain/use_cases/mark_completion_use_case_siyum_routing_test.dart` | ISSUES | t1-feat-learning | Good real-DB routing test; masks fire-and-forget race with delay() hack. |
| `learning_tracker/test/features/learning/learning_task_card_overflow_test.dart` | SOUND | t1-feat-learning | Checked overflow guard via documented faithful-copy pattern precedented elsewhere. |
| `learning_tracker/test/features/learning/presentation/screens/learning_screen_l1_test.dart` | DEFECTIVE | t1-feat-learning | Real-DB leak every pump (TQ-6); no HE error coverage; 1021 lines; duplicate tests. |
| `learning_tracker/test/features/learning/presentation/screens/learning_screen_test.dart` | DEFECTIVE | t1-feat-learning | Real-DB leak; dead provider overrides; near-duplicate of l1 file's coverage. |
| `learning_tracker/test/features/learning/presentation/widgets/completion_button_optimistic_test.dart` | ISSUES | t1-feat-learning | Tests provider correctly but misnamed/misplaced — CompletionButton widget no longer exists. |
| `learning_tracker/test/features/learning_order/data/repositories/learning_order_repository_impl_test.dart` | DEFECTIVE | t1-feat-learning_order | Fixtures seed profileId 1 under a profileId-0 repo; 2 tests certify a P0 cross-profile DAO bug. |
| `learning_tracker/test/features/learning_order/presentation/screens/learning_order_screen_reset_test.dart` | ISSUES | t1-feat-learning_order | Solid race-condition regression test; wrong directory per AG-5; never asserts app-bar title text. |
| `learning_tracker/test/features/learning_order/presentation/screens/learning_order_screen_test.dart` | ISSUES | t1-feat-learning_order | Smoke test only checks Scaffold exists; wrong directory per AG-5; misses hardcoded-string regressions. |
| `learning_tracker/test/features/notifications/.gitkeep` | SOUND | t1-feat-notifications | Empty placeholder directory marker, no content to violate. |
| `learning_tracker/test/features/notifications/domain/services/notification_gateway_test.dart` | ISSUES | t1-feat-notifications | Well-written, non-tautological; ~55% of 1415 lines pin dead legacy API. |
| `learning_tracker/test/features/notifications/domain/services/notification_scheduler_test.dart` | ISSUES | t1-feat-notifications | All but one test exercises the dead schedule()/cancel() legacy wrapper API. |
| `learning_tracker/test/features/notifications/domain/services/notification_service_test.dart` | ISSUES | t1-feat-notifications | cancelDailyReminder/cancelStreakAlert tests exercise dead methods; initialize() tests are live. |
| `learning_tracker/test/features/notifications/domain/services/streak_alert_service_test.dart` | SOUND | t1-feat-notifications | Fake clock, real Drift DB, mocktail verification; covers evaluate/schedule/cancel branches well. |
| `learning_tracker/test/features/notifications/presentation/providers/notification_providers_deep_test.dart` | ISSUES | t1-feat-notifications | Good per-profile isolation coverage; G1-G4 signature tests tautological; wall-clock sleeps. |
| `learning_tracker/test/features/notifications/presentation/providers/notification_providers_test.dart` | ISSUES | t1-feat-notifications | Solid default/toggle/persist coverage; one wall-clock Future.delayed sleep. |
| `learning_tracker/test/features/notifications/presentation/providers/reminder_enabled_cold_start_test.dart` | ISSUES | t1-feat-notifications | Valuable, well-targeted regression suite; 8 wall-clock Future.delayed sleeps. |
| `learning_tracker/test/features/notifications/presentation/providers/reminder_sync_sacred_time_test.dart` | ISSUES | t1-feat-notifications | Strong recording-fake design; own comments confirm real StateError needing 10x retry. |
| `learning_tracker/test/features/notifications/presentation/providers/reminder_time_cold_start_test.dart` | ISSUES | t1-feat-notifications | Well-targeted mirror of reminder_enabled suite; 6 wall-clock Future.delayed sleeps. |
| `learning_tracker/test/features/notifications/presentation/screens/hot_streak_badge_visibility_test.dart` | SOUND | t1-feat-notifications | Fresh ProviderScope per test, virtualized pump timing, clear regression framing. |
| `learning_tracker/test/features/notifications/presentation/screens/notification_switch_a11y_test.dart` | SOUND | t1-feat-notifications | tester.getSemantics assertions correctly verify AX-3 Switch labels; no issues. |
| `learning_tracker/test/features/notifications/presentation/screens/notifications_screen_l1_test.dart` | ISSUES | t1-feat-notifications | 977 lines (AG-3 cap 400); 7x duplicated ProviderScope boilerplate; stale test title; fragile .last finder. |
| `learning_tracker/test/features/notifications/presentation/screens/notifications_screen_test.dart` | DEFECTIVE | t1-feat-notifications | Un-isolated pump opens real Drift DB (confirmed warning); duplicate mock class; unregistered tag. |
| `learning_tracker/test/features/notifications/ws5_key_prefs_test.dart` | SOUND | t1-feat-notifications | All 10 tests call real static key-namespacing methods directly; hermetic and deterministic. |
| `learning_tracker/test/features/notifications/ws5_per_profile_test.dart` | ISSUES | t1-feat-notifications | ID-allocation tests hit real code (good); 3 payload-format tests are tautological/redundant. |
| `learning_tracker/test/features/notifications/ws5_two_layers_test.dart` | ISSUES | t1-feat-notifications | Shares notifications_screen_test.dart's missing sync-effect override; duplicate mock class; unregistered tag. |
| `learning_tracker/test/features/onboarding/.gitkeep` | SOUND | t1-feat-onboarding | Empty directory placeholder, nothing to audit |
| `learning_tracker/test/features/onboarding/domain/services/bulk_prior_completion_service_test.dart` | ISSUES | t1-feat-onboarding | 578 lines (AG-3); never passes profileId, so DI-bypass branch untested |
| `learning_tracker/test/features/onboarding/domain/services/bulk_prior_completion_siyum_detection_test.dart` | ISSUES | t1-feat-onboarding | Exercises profileId/BookmarkRepositoryImpl branch but never asserts the bookmark outcome |
| `learning_tracker/test/features/onboarding/domain/services/curriculum_import_service_test.dart` | SOUND | t1-feat-onboarding | Clean mocktail unit tests; paired lib file has bare catch(e) (EH-4) |
| `learning_tracker/test/features/onboarding/domain/services/hierarchy_selection_test.dart` | SOUND | t1-feat-onboarding | Focused ==/hashCode tests for re-exported core value type; sound |
| `learning_tracker/test/features/onboarding/domain/services/learning_process_wizard_service_test.dart` | ISSUES | t1-feat-onboarding | 619 lines (AG-3); ~50% duplicate coverage across parallel group pairs |
| `learning_tracker/test/features/onboarding/domain/services/user_profile_service_test.dart` | SOUND | t1-feat-onboarding | Fresh in-memory DB per test; asserts real persisted state; sound |
| `learning_tracker/test/features/onboarding/domain/validators/auth_validators_test.dart` | ISSUES | t1-feat-onboarding | Locks in hardcoded English validator strings as the correct behavior |
| `learning_tracker/test/features/onboarding/presentation/screens/account_creation_validation_test.dart` | ISSUES | t1-feat-onboarding | Duplicates auth_validators_test.dart; also locks in hardcoded English strings |
| `learning_tracker/test/features/onboarding/presentation/screens/app_intro_rewards_cta_overlap_test.dart` | SOUND | t1-feat-onboarding | Well-built geometric regression test; real device dims; non-tautological |
| `learning_tracker/test/features/onboarding/presentation/screens/app_intro_screen_l1_test.dart` | ISSUES | t1-feat-onboarding | 472 lines (AG-3) but legitimate coverage; consistent _rig helper; otherwise sound |
| `learning_tracker/test/features/onboarding/presentation/screens/bulk_mark_screen_test.dart` | ISSUES | t1-feat-onboarding | 5x inline-duplicated MaterialApp/ProviderScope boilerplate instead of a shared helper |
| `learning_tracker/test/features/onboarding/presentation/screens/empty_login_ws2_test.dart` | ISSUES | t1-feat-onboarding | 2 tests skip the file's own _wrapWithProviders helper, duplicate boilerplate inline |
| `learning_tracker/test/features/onboarding/presentation/screens/onboarding_bulk_l1_test.dart` | DEFECTIVE | t1-feat-onboarding | 1262 lines (AG-3); locks in raw e.toString() UI leak as correct |
| `learning_tracker/test/features/onboarding/presentation/screens/onboarding_screen_l1_test.dart` | ISSUES | t1-feat-onboarding | 841 lines (AG-3); one Hebrew assertion checks a string absent from ARB |
| `learning_tracker/test/features/onboarding/presentation/screens/onboarding_screen_test.dart` | ISSUES | t1-feat-onboarding | ~90% duplicate of onboarding_bulk_l1_test.dart's profileCreation + childAwareText coverage |
| `learning_tracker/test/features/onboarding/presentation/screens/permission_prompt_screen_l1_test.dart` | ISSUES | t1-feat-onboarding | 985 lines (AG-3); dup harness (Finding 4); correct EN/HE l10n pinning otherwise |
| `learning_tracker/test/features/onboarding/presentation/screens/signup_screen_test.dart` | ISSUES | t1-feat-onboarding | 429 lines; missed hint literal; 3 async flows untested past validation; DB leak |
| `learning_tracker/test/features/onboarding/presentation/steps/onboarding_steps_overflow_test.dart` | ISSUES | t1-feat-onboarding | Solid overflow matrix coverage; zero cases run under Locale('he') |
| `learning_tracker/test/features/onboarding/presentation/steps/wizard_steps_l1_test.dart` | DEFECTIVE | t1-feat-onboarding | Pins hardcoded EN under he-locale; untested Slider crash at round 5 |
| `learning_tracker/test/features/parent_mode/.gitkeep` | SOUND | t1-feat-parent_mode | Empty placeholder file; nothing to review. |
| `learning_tracker/test/features/parent_mode/child_mode_guard_test.dart` | DEFECTIVE | t1-feat-parent_mode | Stale duplicate of test/core/navigation version; narrower coverage, wall-clock, wrong path. |
| `learning_tracker/test/features/parent_mode/domain/services/parent_dashboard_aggregator_compute_test.dart` | ISSUES | t1-feat-parent_mode | Duplicates extended_test coverage; wall-clock DateTime.now() line 122; wrong path. |
| `learning_tracker/test/features/parent_mode/domain/services/parent_dashboard_aggregator_extended_test.dart` | ISSUES | t1-feat-parent_mode | Duplicates compute_test coverage; content otherwise sound; wrong path (AG-5). |
| `learning_tracker/test/features/parent_mode/domain/services/parent_dashboard_aggregator_migration_test.dart` | ISSUES | t1-feat-parent_mode | Content sound, distinct tier-migration coverage; only issue is wrong path. |
| `learning_tracker/test/features/parent_mode/domain/services/parent_dashboard_aggregator_test.dart` | ISSUES | t1-feat-parent_mode | Tautological 'DashboardStats model' test; computeEngagement tests fine; wrong path. |
| `learning_tracker/test/features/parent_mode/pin_service_extended_test.dart` | ISSUES | t1-feat-parent_mode | ~90% overlaps pin_service_profile_test; triplicated mock boilerplate; wrong path. |
| `learning_tracker/test/features/parent_mode/pin_service_profile_test.dart` | ISSUES | t1-feat-parent_mode | ~90% overlaps pin_service_extended_test; triplicated mock boilerplate; wrong path. |
| `learning_tracker/test/features/parent_mode/pin_service_test.dart` | ISSUES | t1-feat-parent_mode | Sound baseline coverage; contributes triplicated mock boilerplate; wrong path. |
| `learning_tracker/test/features/parent_mode/presentation/providers/pin_flow_controller_test.dart` | ISSUES | t1-feat-parent_mode | Thorough state coverage; 5 tests skip addTearDown; no ref.mounted/localization tests. |
| `learning_tracker/test/features/parent_mode/presentation/screens/pin_setup_screen_test.dart` | ISSUES | t1-feat-parent_mode | Stale name (tests PinFlowScreen); one smoke test only; no HE variant. |
| `learning_tracker/test/features/profiles/data/repositories/profile_repository_impl_test.dart` | ISSUES | t1-feat-profiles | 623 lines (AG-3); otherwise thorough FK/rollback/dup-name/self-heal coverage against real Drift DB |
| `learning_tracker/test/features/profiles/domain/use_cases/profile_creation_use_case_test.dart` | ISSUES | t1-feat-profiles | Wall-clock DateTime.now() (4x) instead of file's own DateTimeFactory; rollback/guard tests solid |
| `learning_tracker/test/features/profiles/pin_flow_and_setup_dialog_l1_test.dart` | ISSUES | t1-feat-profiles | 1575 lines (4x cap), combines 3 source files at non-mirrored path; tests excellent |
| `learning_tracker/test/features/profiles/presentation/an2_switcher_pin_guard_test.dart` | ISSUES | t1-feat-profiles | Only 2 of 5 documented escalating actions tested; no He/RTL variant; wrong mirror path |
| `learning_tracker/test/features/profiles/presentation/profile_switcher_sheet_test.dart` | ISSUES | t1-feat-profiles | 488 lines (AG-3); no He/RTL variant; test file one directory level off AG-5 path |
| `learning_tracker/test/features/profiles/presentation/providers/active_profile_tutored_test.dart` | SOUND | t1-feat-profiles | Hermetic ProviderContainer tests, hand-written fake repo, fixed clock; pins BUG-NEW-2 correctly |
| `learning_tracker/test/features/profiles/presentation/providers/auto_selected_profile_id_test.dart` | SOUND | t1-feat-profiles | Hermetic self-heal/stale-id regression tests with a full hand-written fake repository |
| `learning_tracker/test/features/profiles/presentation/screens/manage_learners_screen_l1_test.dart` | ISSUES | t1-feat-profiles | 800 lines (AG-3); pins known FAB-cap UX bug as passing with no Linear id |
| `learning_tracker/test/features/profiles/presentation/screens/parent_settings_screen_l1_test.dart` | ISSUES | t1-feat-profiles | 999 lines (AG-3); _buildApp leaks inMemoryDb() when db: omitted (~30 tests). |
| `learning_tracker/test/features/profiles/presentation/screens/parent_track_management_screen_l1_test.dart` | ISSUES | t1-feat-profiles | 902 lines; DB leak; archive test too weak to catch config-wipe regression. |
| `learning_tracker/test/features/profiles/presentation/screens/profile_picker_screen_l1_test.dart` | ISSUES | t1-feat-profiles | 805 lines (AG-3); blanket FlutterError.onError overflow suppression in he-RTL test. |
| `learning_tracker/test/features/profiles/presentation/screens/profile_picker_segmentation_test.dart` | SOUND | t1-feat-profiles | Pure prop-driven OwnProfilesSection header-visibility test; no I/O; clean. |
| `learning_tracker/test/features/profiles/presentation/screens/rpr2_picker_offline_delete_test.dart` | ISSUES | t1-feat-profiles | Real-screen R-PR2 delete coverage is solid; shares blanket overflow suppression. |
| `learning_tracker/test/features/profiles/presentation/screens/ts14_parent_track_management_copy_test.dart` | ISSUES | t1-feat-profiles | Empty-state test solid; dialog-body test reads ARB getter not rendered dialog; DB leak. |
| `learning_tracker/test/features/profiles/presentation/screens/ts3_parent_track_archive_test.dart` | DEFECTIVE | t1-feat-profiles | Both tests bypass the real archive path; misses a live config-wipe regression (P0). |
| `learning_tracker/test/features/profiles/presentation/widgets/add_profile_dialog_test.dart` | SOUND | t1-feat-profiles | Real showAddProfileDialog + mock repo; error/success/autocorrect covered; db closed. |
| `learning_tracker/test/features/profiles/presentation/widgets/parent_pin_keypad_dialog_test.dart` | ISSUES | t1-feat-profiles | Thorough real-widget coverage; 1079 lines (AG-3); 7x duplicated MaterialApp boilerplate. |
| `learning_tracker/test/features/profiles/presentation/widgets/pp11_edit_dialog_autofocus_test.dart` | SOUND | t1-feat-profiles | Minimal real ProfileEditFormDialog render; single correct autofocus assertion. |
| `learning_tracker/test/features/profiles/presentation/widgets/pp12_pin_change_subtitle_test.dart` | SOUND | t1-feat-profiles | Real showParentPinChangeDialog flow; asserts actual rendered subtitle text. |
| `learning_tracker/test/features/profiles/presentation/widgets/pp13_add_profile_selects_new_profile_test.dart` | SOUND | t1-feat-profiles | Real showAddProfileDialog flow; captures provider value across create; solid. |
| `learning_tracker/test/features/profiles/presentation/widgets/pp16_profile_grid_tablet_height_test.dart` | ISSUES | t1-feat-profiles | Tests Flutter's SliverGrid math directly; never imports/pins ProfileGrid's config. |
| `learning_tracker/test/features/profiles/presentation/widgets/pp1_pin_setup_dialog_busy_guard_test.dart` | SOUND | t1-feat-profiles | Real showParentPinSetupDialog; verifies busy-guard via genuine keypad taps. |
| `learning_tracker/test/features/profiles/presentation/widgets/pp2_edit_profile_mode_persisted_test.dart` | SOUND | t1-feat-profiles | Real editProfileFlow; captures updateProfile call args; correctly asserts mode. |
| `learning_tracker/test/features/profiles/presentation/widgets/profile_edit_delete_actions_test.dart` | ISSUES | t1-feat-profiles | Strong R3-10/BugB/R-PR4 coverage; TutorWriteException catch is dead code, untested; 863 lines (AG-3). |
| `learning_tracker/test/features/profiles/presentation/widgets/profile_switcher_bar_badge_test.dart` | ISSUES | t1-feat-profiles | AN-3 badge states well covered; no lib mirror — ProfileSwitcherBar actually lives in app_shell.dart. |
| `learning_tracker/test/features/profiles/presentation/widgets/profile_switcher_sheet_overflow_test.dart` | SOUND | t1-feat-profiles | Real ProfileSwitcherSheet driven across device/text-scale/RTL matrix via shared harness; no gaps. |
| `learning_tracker/test/features/profiles/presentation/ws4_mode_boundaries_test.dart` | DEFECTIVE | t1-feat-profiles | WS4.boundary group tests an inline fabricated dialog with zero connection to production code. |
| `learning_tracker/test/features/profiles/profile_picker_and_tutored_l1_test.dart` | ISSUES | t1-feat-profiles | Thorough real-widget loading/error/RTL/integration coverage; 652 lines exceeds AG-3 ceiling. |
| `learning_tracker/test/features/profiles/profile_picker_deep_l1_test.dart` | ISSUES | t1-feat-profiles | Broad real-widget coverage; misses deleting the selected profile, where lib forked/regressed; 1010 lines. |
| `learning_tracker/test/features/progress/.gitkeep` | SOUND | t1-feat-progress | Empty marker file; no content to audit. |
| `learning_tracker/test/features/progress/data/repositories/progress_repository_test.dart` | SOUND | t1-feat-progress | Real Drift-backed CRUD tests, concrete assertions; wall-clock use is low-risk. |
| `learning_tracker/test/features/progress/domain/models/chart_data_test.dart` | ISSUES | t1-feat-progress | Tautological test pins a dead, unlocalized ChartTimeRange.displayName getter. |
| `learning_tracker/test/features/progress/domain/models/journey_view_model_test.dart` | SOUND | t1-feat-progress | Solid freezed-model construction/copyWith/equality tests, good regression rationale. |
| `learning_tracker/test/features/progress/domain/services/chart_data_service_extended_test.dart` | ISSUES | t1-feat-progress | Near-duplicate of chart_data_service_extra_test.dart's getTargetLine coverage. |
| `learning_tracker/test/features/progress/domain/services/chart_data_service_extra_test.dart` | ISSUES | t1-feat-progress | Near-duplicate of chart_data_service_extended_test.dart's getTargetLine coverage. |
| `learning_tracker/test/features/progress/domain/services/chart_data_service_migration_test.dart` | ISSUES | t1-feat-progress | Near-duplicate of chart_data_service_sentinel_test.dart's tier-migration coverage. |
| `learning_tracker/test/features/progress/domain/services/chart_data_service_recent_activity_test.dart` | SOUND | t1-feat-progress | Well-targeted tier-policy regression tests, no overlap with sibling files. |
| `learning_tracker/test/features/progress/domain/services/chart_data_service_sentinel_test.dart` | ISSUES | t1-feat-progress | Near-duplicate of chart_data_service_migration_test.dart's tier-migration coverage. |
| `learning_tracker/test/features/progress/domain/services/chart_data_service_test.dart` | SOUND | t1-feat-progress | Solid baseline coverage of 4 methods, distinct from other 4 test files. |
| `learning_tracker/test/features/progress/domain/services/chart_data_service_w1b_test.dart` | ISSUES | t1-feat-progress | Hermetic real-DB SQL-bound regression tests, correct; 633 lines exceeds AG-3 cap. |
| `learning_tracker/test/features/progress/domain/services/curriculum_progress_service_test.dart` | ISSUES | t1-feat-progress | Hierarchy/stage/breakdown coverage correct; unasserted DateTime.now() violates TQ-6. |
| `learning_tracker/test/features/progress/domain/services/lifetime_tree_builder_collision_test.dart` | SOUND | t1-feat-progress | Checked cross-masechta/cross-sefer qualified-id collision regressions; well evidenced. |
| `learning_tracker/test/features/progress/domain/services/lifetime_tree_builder_composite_test.dart` | SOUND | t1-feat-progress | Checked Tanach/Chumash composite over-credit P0 invariant; documented, pinned correctly. |
| `learning_tracker/test/features/progress/domain/services/lifetime_tree_builder_test.dart` | SOUND | t1-feat-progress | Checked buildTree/computeLearnedLeafRefs + F12 upgrade-path provenance regression; solid. |
| `learning_tracker/test/features/progress/domain/services/pace_calculator_test.dart` | ISSUES | t1-feat-progress | Every documented edge case tested except bulkBaseline>totalItems clamp. |
| `learning_tracker/test/features/progress/domain/services/track_dual_progress_migration_test.dart` | SOUND | t1-feat-progress | Checked migration-consistency vs TrackProgressService on real DB; proper mirror exists too. |
| `learning_tracker/test/features/progress/lifetime_folder_styled_and_notif_providers_test.dart` | DEFECTIVE | t1-feat-progress | Part B duplicates notifications-feature tests in wrong dir; 1654 lines; duplicate overflow harness. |
| `learning_tracker/test/features/progress/presentation/lifetime_knowledge_models_test.dart` | SOUND | t1-feat-progress | Checked pure model construction/getters incl. LifetimeTotals.percentage; correct, low-signal. |
| `learning_tracker/test/features/progress/presentation/providers/curriculum_pace_status_provider_test.dart` | ISSUES | t1-feat-progress | Excellent real-provider/real-DB/pinned-clock pace coverage; 554 lines exceeds AG-3 cap. |
| `learning_tracker/test/features/progress/presentation/providers/curriculum_progress_reactivity_test.dart` | DEFECTIVE | t1-feat-progress | CP-02 'regression guard' fully overrides the provider; never runs real code. |
| `learning_tracker/test/features/progress/presentation/providers/items_learned_reactivity_test.dart` | DEFECTIVE | t1-feat-progress | ILP-01 guard (3 providers) fully overrides each; never runs real code. |
| `learning_tracker/test/features/progress/presentation/providers/journey_providers_test.dart` | ISSUES | t1-feat-progress | Exemplary real-provider/real-DB milestone regression suite (F2/F22/F24); 836 lines (AG-3). |
| `learning_tracker/test/features/progress/presentation/providers/lifetime_knowledge_providers_test.dart` | ISSUES | t1-feat-progress | Strong B9/D9 dedup+reactivity coverage via real provider; 597 lines exceeds AG-3 cap. |
| `learning_tracker/test/features/progress/presentation/providers/pp4_lifetime_chazaros_count_test.dart` | DEFECTIVE | t1-feat-progress | PP-4 'regression test' never calls the provider; re-derives the formula inline. |
| `learning_tracker/test/features/progress/presentation/providers/recent_activity_reactivity_test.dart` | SOUND | t1-feat-progress | Real DB + real provider bodies; RA-03 reactivity genuinely pinned; hermetic, disposed. |
| `learning_tracker/test/features/progress/presentation/providers/track_dual_progress_reactivity_test.dart` | DEFECTIVE | t1-feat-progress | Both tests override the exact provider under test; zero real regression coverage. |
| `learning_tracker/test/features/progress/presentation/screens/curriculum_progress_screen_test.dart` | ISSUES | t1-feat-progress | Thorough dual-stats/l10n coverage; misses screen's hardcoded 'Curriculum settings' tooltip. |
| `learning_tracker/test/features/progress/presentation/screens/lifetime_knowledge_screen_test.dart` | ISSUES | t1-feat-progress | Good F3/F13/CTA coverage; exercises 657-line provider with silent catches, N+1 loop. |
| `learning_tracker/test/features/progress/presentation/screens/progress_screen_test.dart` | SOUND | t1-feat-progress | Comprehensive: loading placeholder, locale/toggle split, adaptive-precision regressions; clean overrides. |
| `learning_tracker/test/features/progress/presentation/screens/recent_activity_screen_test.dart` | ISSUES | t1-feat-progress | Solid live/bulk/lifetime + refetch coverage; screen file is 792 lines (AG-3). |
| `learning_tracker/test/features/progress/presentation/screens/siyumim_milestones_screen_test.dart` | SOUND | t1-feat-progress | Hierarchy, opacity-dimming, no-provenance and Hebrew-locale variant all covered. |
| `learning_tracker/test/features/progress/presentation/widgets/curriculum_breakdown_list_test.dart` | SOUND | t1-feat-progress | Focused pure-function EN/HE/toggle provenance-text matrix; no gaps found. |
| `learning_tracker/test/features/progress/presentation/widgets/monthly_activity_sliver_calendar_test.dart` | ISSUES | t1-feat-progress | Well-built virtualization tests for a widget that's dead code (unwired). |
| `learning_tracker/test/features/progress/presentation/widgets/overall_stats_card_i18n_test.dart` | SOUND | t1-feat-progress | Clean OS-01 EN/HE regression coverage of all five stat labels. |
| `learning_tracker/test/features/progress/presentation/widgets/progress_tier_counter_row_test.dart` | SOUND | t1-feat-progress | Excellent F17 loading-placeholder edge cases; adult/child mode both covered. |
| `learning_tracker/test/features/progress/presentation/widgets/progress_widgets_test.dart` | ISSUES | t1-feat-progress | Good assertions; bundles 4 widgets with no mirrored test files; odd child() name. |
| `learning_tracker/test/features/progress/presentation/widgets/siyum_milestone_label_ts12_test.dart` | SOUND | t1-feat-progress | Tight TS-12 pure-function regression, EN/HE, bare-key edge case covered. |
| `learning_tracker/test/features/progress/presentation/widgets/siyumim_grouped_view_test.dart` | ISSUES | t1-feat-progress | Thorough i18n/variant/date coverage; widget file is 437 lines (AG-3). |
| `learning_tracker/test/features/progress/presentation/widgets/siyumim_timeline_month_key_ts13_test.dart` | ISSUES | t1-feat-progress | Comment promises a fr-FR test that doesn't exist; no real locale-switch coverage. |
| `learning_tracker/test/features/progress/presentation/widgets/siyumim_timeline_view_test.dart` | SOUND | t1-feat-progress | Unit + aggregate name variant/Hebrew resolution correctly pinned, mirrors grouped view. |
| `learning_tracker/test/features/progress/presentation/widgets/streak_calendar_hebrew_date_test.dart` | SOUND | t1-feat-progress | Deterministic gematriya/weekday fixture dates; both pref states covered cleanly. |
| `learning_tracker/test/features/progress/progress_barrel_test.dart` | SOUND | t1-feat-progress | Minimal but correctly targets Rule-2 barrel export contract for dashboard consumer. |
| `learning_tracker/test/features/progress/recent_activity_and_hierarchy_panel_l1_test.dart` | ISSUES | t1-feat-progress | 1093 lines (AG-3); inMemoryDb() opened at 2 sites, never closed via tearDown. |
| `learning_tracker/test/features/progress/recent_activity_overflow_test.dart` | DEFECTIVE | t1-feat-progress | Hand-copied prod widgets drifted (missing _AllTimeStatPhrase tile); locale never set to he. |
| `learning_tracker/test/features/progress/siyumim_timeline_and_lifetime_providers_test.dart` | ISSUES | t1-feat-progress | 1328 lines (AG-3); B18 test skips the conflict entry its comment describes; DB unclosed. |
| `learning_tracker/test/features/sacred_time/data/services/sacred_time_preferences_test.dart` | ISSUES | t1-feat-sacred_time | thorough coverage; readInIsrael tested twice across two near-duplicate groups. |
| `learning_tracker/test/features/sacred_time/presentation/screens/city_picker_screen_l1_test.dart` | ISSUES | t1-feat-sacred_time | excellent branch coverage; he-locale test never asserts idle-hint text, masking the AX-2 bug. |
| `learning_tracker/test/features/sacred_time/presentation/widgets/sacred_time_lock_overlay_l10n_test.dart` | SOUND | t1-feat-sacred_time | checked all 4 window kinds x variant/Hebrew-terms combos against the real widget. |
| `learning_tracker/test/features/sacred_time/presentation/widgets/sacred_time_settings_card_l10n_test.dart` | SOUND | t1-feat-sacred_time | checked Hebrew strings + variant/Hebrew-terms combos render with no English leaks. |
| `learning_tracker/test/features/sacred_time/sacred_location_and_data_test.dart` | SOUND | t1-feat-sacred_time | hand-written fakes, fresh containers each test, exercises every branch + a real prior race fix. |
| `learning_tracker/test/features/sacred_time/sacred_time_lock_overlay_overflow_test.dart` | SOUND | t1-feat-sacred_time | checked all 4 window kinds across the device/text-scale matrix via shared harness. |
| `learning_tracker/test/features/sacred_time/zmanim_window_service_test.dart` | ISSUES | t1-feat-sacred_time | solid Shabbos/YT/cushion/YK coverage; no test forces the polar-fallback branch. |
| `learning_tracker/test/features/scheduler/.gitkeep` | SOUND | t1-feat-scheduler | Empty placeholder file, nothing to audit. |
| `learning_tracker/test/features/scheduler/collapse_daf_tasks_test.dart` | SOUND | t1-feat-scheduler | 4 real assertions covering coarse/fine, stage-separation, per-track cases; hermetic. |
| `learning_tracker/test/features/scheduler/data/repositories/daily_plan_repository_backfill_test.dart` | SOUND | t1-feat-scheduler | Hermetic, fixed clock, real assertions incl. cache wipe-safety contract. |
| `learning_tracker/test/features/scheduler/data/repositories/daily_plan_repository_test.dart` | SOUND | t1-feat-scheduler | Hermetic, fresh DB per test, fixed clock, real snapshot-cache assertions. |
| `learning_tracker/test/features/scheduler/data/repositories/goal_repository_impl_test.dart` | ISSUES | t1-feat-scheduler | Good CRUD/pace-target/R4-6 coverage; updateGoal not-found and deleteGoal sync payload unpinned. |
| `learning_tracker/test/features/scheduler/data/repositories/overdue_from_elapsed_study_days_test.dart` | ISSUES | t1-feat-scheduler | Strong hermetic projection assertions; file misplaced under data/repositories (AG-5). |
| `learning_tracker/test/features/scheduler/data/repositories/scheduler_content_repository_impl_test.dart` | ISSUES | t1-feat-scheduler | Correct getLeafItems coverage; duplicates domain/repositories/scheduler_content_repository_test.dart. |
| `learning_tracker/test/features/scheduler/domain/labels/program_label_resolver_test.dart` | SOUND | t1-feat-scheduler | Verified toggle wiring + wrapper fns are real/current via ProviderScope; hermetic, no duplication. |
| `learning_tracker/test/features/scheduler/domain/models/delta_value_test.dart` | ISSUES | t1-feat-scheduler | Thorough sealed-delta coverage; several tests duplicate an earlier test's body verbatim. |
| `learning_tracker/test/features/scheduler/domain/models/goal_entity_extended_test.dart` | ISSUES | t1-feat-scheduler | Near-total duplicate of goal_entity_extra_test.dart (DeadlineTarget/PacePeriodTarget/firestoreId/fromFirestore). |
| `learning_tracker/test/features/scheduler/domain/models/goal_entity_extra_test.dart` | ISSUES | t1-feat-scheduler | Near-total duplicate of goal_entity_extended_test.dart; same gaps re-covered independently. |
| `learning_tracker/test/features/scheduler/domain/models/goal_entity_test.dart` | SOUND | t1-feat-scheduler | Base PaceGranularity/paceTarget/toFirestore/fromFirestore round-trip coverage; no overlap issues. |
| `learning_tracker/test/features/scheduler/domain/repositories/scheduler_content_repository_test.dart` | ISSUES | t1-feat-scheduler | Good unique coarseUnitKey coverage; getLeafItems suite duplicates the data/repositories impl test. |
| `learning_tracker/test/features/scheduler/domain/services/daily_task_generator_extended_test.dart` | ISSUES | t1-feat-scheduler | Duplicates generateAll empty/sorted-priority tests already in generate_all_test.dart. |
| `learning_tracker/test/features/scheduler/domain/services/daily_task_generator_generate_all_test.dart` | ISSUES | t1-feat-scheduler | Duplicates generateAll empty/sorted-priority tests already in extended_test.dart. |
| `learning_tracker/test/features/scheduler/domain/services/daily_task_generator_test.dart` | ISSUES | t1-feat-scheduler | Good prioritization coverage; hardcodes trackId:1 over captured var, DateTime.now() in seed. |
| `learning_tracker/test/features/scheduler/domain/services/local_calendar_engine_test.dart` | SOUND | t1-feat-scheduler | Focused, hermetic R4-1 UTC-midnight regression against a real in-memory content DB. |
| `learning_tracker/test/features/scheduler/domain/services/pace_calculator_test.dart` | SOUND | t1-feat-scheduler | Thorough deadline/pace-goal + rounding-dead-zone regression coverage; fully hermetic, fixed clock. |
| `learning_tracker/test/features/scheduler/domain/services/scheduler_engine_dni346_test.dart` | ISSUES | t1-feat-scheduler | Excellent DNI-346 regression coverage; 553 lines, over AG-3's 400-line cap. |
| `learning_tracker/test/features/scheduler/domain/services/scheduler_engine_integration_test.dart` | ISSUES | t1-feat-scheduler | Good round-trip test; hardcodes trackId:1 over captured var, DateTime.now() in seed. |
| `learning_tracker/test/features/scheduler/domain/services/scheduler_engine_performance_test.dart` | ISSUES | t1-feat-scheduler | Passes today; hard 500ms Stopwatch threshold in hermetic suite risks CI flakiness. |
| `learning_tracker/test/features/scheduler/domain/services/scheduler_engine_schedule_types_test.dart` | ISSUES | t1-feat-scheduler | Good distinct weekly/rolling coverage; 507 lines over AG-3 cap; cross-feature import checker-blind. |
| `learning_tracker/test/features/scheduler/domain/services/scheduler_engine_self_paced_test.dart` | ISSUES | t1-feat-scheduler | Exemplary self-paced/coarse-batch coverage with exact-ref assertions; 431 lines over AG-3 cap. |
| `learning_tracker/test/features/scheduler/domain/services/scheduler_engine_test.dart` | ISSUES | t1-feat-scheduler | Solid legacy-pacing coverage via hand-rolled fakes; 516 lines, over AG-3 cap. |
| `learning_tracker/test/features/scheduler/domain/services/sefaria_ref_matcher_test.dart` | ISSUES | t1-feat-scheduler | Exhaustive real-function coverage; 1010 lines (AG-3); one order test can't verify itself. |
| `learning_tracker/test/features/scheduler/domain/study_day_chazara_gate_test.dart` | ISSUES | t1-feat-scheduler | Tests DAO count only, not the real chazara-gate provider it documents fixing. |
| `learning_tracker/test/features/scheduler/domain/study_day_toggle_write_test.dart` | ISSUES | t1-feat-scheduler | Tests DAO write visibility only, not the real invalidate-after-write race it claims. |
| `learning_tracker/test/features/scheduler/domain/study_day_trackid_fallback_test.dart` | ISSUES | t1-feat-scheduler | Re-implements the null-trackId guard inline instead of calling the real screen code. |
| `learning_tracker/test/features/scheduler/presentation/providers/scheduler_all_daily_tasks_test.dart` | ISSUES | t1-feat-scheduler | Strong real-provider SP1-11 coverage; 11 fixed-delay sleeps; 957 lines (AG-3). |
| `learning_tracker/test/features/scheduler/presentation/providers/scheduler_contiguous_overdue_no_gap_test.dart` | ISSUES | t1-feat-scheduler | Solid real-provider no-gap regression test; one fixed-delay sleep smell. |
| `learning_tracker/test/features/scheduler/presentation/providers/scheduler_providers_branches_test.dart` | ISSUES | t1-feat-scheduler | Excellent amnesty/deadline/zero-study-day branch coverage; fixed-delay sleeps; 684 lines (AG-3). |
| `learning_tracker/test/features/scheduler/presentation/providers/scheduler_providers_test.dart` | ISSUES | t1-feat-scheduler | Broad provider-unit coverage; fixed-delay sleeps; largest batch file, 1092 lines (AG-3). |
| `learning_tracker/test/features/scheduler/presentation/screens/goal_and_study_day_i18n_test.dart` | SOUND | t1-feat-scheduler | Direct EN/HE l10n-object parity checks; hermetic; no issues found. |
| `learning_tracker/test/features/scheduler/presentation/screens/scheduler_goal_card_pluralization_test.dart` | SOUND | t1-feat-scheduler | Real widget pump; EN+HE ICU plural assertions on _GoalCard; correct. |
| `learning_tracker/test/features/scheduler/presentation/screens/scheduler_screen_l1_test.dart` | ISSUES | t1-feat-scheduler | Thorough 14-scenario coverage incl. grouped-view toggle; 677 lines (AG-3); dupes screen_test.dart. |
| `learning_tracker/test/features/scheduler/presentation/screens/scheduler_screen_test.dart` | ISSUES | t1-feat-scheduler | Near-fully duplicates scheduler_screen_l1_test.dart's scenarios; candidate for deletion. |
| `learning_tracker/test/features/scheduler/presentation/screens/study_day_config_plural_test.dart` | SOUND | t1-feat-scheduler | Small focused EN plural-form checks for study-days-per-week label; correct. |
| `learning_tracker/test/features/scheduler/presentation/screens/study_day_config_screen_l1_test.dart` | ISSUES | t1-feat-scheduler | Comprehensive chazara/tutor/RTL/error coverage; 837 lines exceeds AG-3 cap. |
| `learning_tracker/test/features/scheduler/presentation/screens/study_day_config_screen_overflow_test.dart` | SOUND | t1-feat-scheduler | Targeted vertical-overflow regression guard across device/textScale matrix; sound. |
| `learning_tracker/test/features/scheduler/presentation/screens/study_day_config_screen_ts4_test.dart` | SOUND | t1-feat-scheduler | Pure studyDayLabel() unit tests for Shabbos nusach routing; sound, well-scoped. |
| `learning_tracker/test/features/scheduler/presentation/widgets/daily_task_card_overflow_test.dart` | SOUND | t1-feat-scheduler | Targeted overflow guard for long ref/stage-name/overdue badge; sound. |
| `learning_tracker/test/features/scheduler/presentation/widgets/daily_task_card_test.dart` | SOUND | t1-feat-scheduler | Exercises real domainTermLabels/curriculum providers, not mocks; sound coverage. |
| `learning_tracker/test/features/scheduler/presentation/widgets/pace_indicator_test.dart` | ISSUES | t1-feat-scheduler | Tests dead widget: scheduler PaceIndicator has zero lib/ callers, duplicates progress's. |
| `learning_tracker/test/features/scheduler/reorder_amnesty_test.dart` | ISSUES | t1-feat-scheduler | 599 lines; 3 amnesty tests hand-copy private cutoff instead of calling it. |
| `learning_tracker/test/features/scheduler/widgets/goal_setup_screen_test.dart` | ISSUES | t1-feat-scheduler | Excellent nusach/l10n/truncation coverage; wrong path (widgets/ not presentation/screens/), 509 lines. |
| `learning_tracker/test/features/scheduler/widgets/hebrew_date_picker_test.dart` | ISSUES | t1-feat-scheduler | Pins hardcoded-English dialog strings as correct; no he-locale test; wrong path. |
| `learning_tracker/test/features/settings/.gitkeep` | SOUND | t1-feat-settings | 0-line placeholder; directory is no longer empty so file is vestigial but harmless. |
| `learning_tracker/test/features/settings/curriculum_settings_and_change_password_l1_test.dart` | SOUND | t1-feat-settings | Read fully: error-branch + ChangePasswordDialog coverage, EN+HE, fresh mocks/DB per test. |
| `learning_tracker/test/features/settings/domain/services/account_management_service_test.dart` | ISSUES | t1-feat-settings | AG-5: tests features/account lib code from settings test tree; misses log-catch gap. |
| `learning_tracker/test/features/settings/domain/services/curriculum_activation_service_test.dart` | ISSUES | t1-feat-settings | AG-5: tests features/tracks lib code from settings test tree; otherwise strong. |
| `learning_tracker/test/features/settings/domain/services/data_export_extended_test.dart` | ISSUES | t1-feat-settings | 5 internally-duplicated full-schema JSON payload builders; coverage itself is solid. |
| `learning_tracker/test/features/settings/domain/services/data_export_import_service_extra_test.dart` | SOUND | t1-feat-settings | Checked: fresh inMemoryDb per test, exercises export branches, minimal duplication. |
| `learning_tracker/test/features/settings/domain/services/data_export_import_service_import_test.dart` | ISSUES | t1-feat-settings | Best-organized builder but independent schema copy; back-compat schedule branches untested. |
| `learning_tracker/test/features/settings/domain/services/data_export_import_service_test.dart` | ISSUES | t1-feat-settings | buildValidJson duplicate schema retains removed legacy activeCurricula key (stale). |
| `learning_tracker/test/features/settings/domain/services/data_export_roundtrip_test.dart` | ISSUES | t1-feat-settings | buildImportJson is one of 5 independently-duplicated schema builders across the suite. |
| `learning_tracker/test/features/settings/domain/services/data_export_service_extended_test.dart` | SOUND | t1-feat-settings | Checked: hermetic export-path tests, no shared-container/wall-clock issues found. |
| `learning_tracker/test/features/settings/domain/services/data_import_service_test.dart` | ISSUES | t1-feat-settings | Duplicate schema builder; 'no-op on invalid JSON' test never checks DB state. |
| `learning_tracker/test/features/settings/presentation/providers/scoped_coarse_unit_count_test.dart` | SOUND | t1-feat-settings | Checked: fresh ProviderContainer+dispose per test, real coarse-grouping assertions. |
| `learning_tracker/test/features/settings/presentation/screens/curriculum_settings_screen_l1_test.dart` | SOUND | t1-feat-settings | Checked: thorough EN+HE/RTL, loading/data/error states, product-rule assertions. |
| `learning_tracker/test/features/settings/presentation/screens/lifetime_marking_screen_test.dart` | ISSUES | t1-feat-settings | TQ-3: no Hebrew/RTL variant despite hardcoded copy-contract assertions. |
| `learning_tracker/test/features/settings/presentation/screens/lifetime_marking_toggle_level_test.dart` | ISSUES | t1-feat-settings | TQ-3: no Hebrew/RTL variant; otherwise strong IL-LEVEL/IL-TOGGLE regression coverage. |
| `learning_tracker/test/features/settings/presentation/screens/lifetime_route_guards_test.dart` | SOUND | t1-feat-settings | Checked: source-inspection guard assertions verified accurate against app_router.dart. |
| `learning_tracker/test/features/settings/presentation/screens/pp3_pp10_lifetime_marking_test.dart` | ISSUES | t1-feat-settings | TQ-3: no Hebrew/RTL locale variant tested for this picker screen. |
| `learning_tracker/test/features/settings/presentation/screens/scope_lifetime_l1_test.dart` | ISSUES | t1-feat-settings | 1499 lines; tautological lifetimeOnly test; raw DateTime.now(); local builder duplicates app scaffolding. |
| `learning_tracker/test/features/settings/presentation/screens/settings_screen_r5_regression_test.dart` | ISSUES | t1-feat-settings | 604 lines; local builder duplicates scaffolding; PIN-gate/R5 l10n logic verified correct against source. |
| `learning_tracker/test/features/settings/presentation/screens/settings_screen_test.dart` | ISSUES | t1-feat-settings | Local createTestWidget duplicates scaffolding; DEVICE/PROFILE grouping and tutored-session scoping verified correct. |
| `learning_tracker/test/features/settings/presentation/screens/st3_settings_switch_a11y_test.dart` | ISSUES | t1-feat-settings | Loop accepts any labelled Switch, not specifically Hebrew-Terms; local builder duplicates scaffolding. |
| `learning_tracker/test/features/settings/presentation/screens/upgrade_to_cloud_cancel_collision_test.dart` | DEFECTIVE | t1-feat-settings | Tests a hand-written simulator widget, never the real _CollisionBlock; cannot fail on regression. |
| `learning_tracker/test/features/settings/presentation/screens/upgrade_to_cloud_screen_l1_test.dart` | ISSUES | t1-feat-settings | 842 lines; 7 stale 'HARDCODED STRING' comments — those strings are l10n-sourced now. |
| `learning_tracker/test/features/settings/presentation/settings_overflow_guard_test.dart` | ISSUES | t1-feat-settings | Leaks an unclosed in-memory UserDatabase per test; overflow-matrix coverage itself is solid. |
| `learning_tracker/test/features/settings/presentation/utils/account_actions_test.dart` | ISSUES | t1-feat-settings | 1087 lines; leaks UserDatabase ~19x; local builder duplicates scaffolding; flow coverage otherwise thorough. |
| `learning_tracker/test/features/settings/presentation/widgets/account_actions_sheet_nav_test.dart` | ISSUES | t1-feat-settings | Title says SignInRoute, asserts AccountPickerRoute; leaks UserDatabase; local builder duplicates scaffolding. |
| `learning_tracker/test/features/settings/presentation/widgets/an7_destructive_icon_contrast_test.dart` | ISSUES | t1-feat-settings | Pins a Colors.white literal (no theme token); leaks UserDatabase; local builder duplication. |
| `learning_tracker/test/features/settings/presentation/widgets/backup_sync_error_l10n_test.dart` | DEFECTIVE | t1-feat-settings | Never exercises the identity-mismatch branch, which renders a raw unlocalized English sentence. |
| `learning_tracker/test/features/settings/presentation/widgets/backup_sync_section_l1_test.dart` | ISSUES | t1-feat-settings | 866 lines (AG-3); relative-time asserts read wall clock, not FakeLocalDayClock (TQ-6). |
| `learning_tracker/test/features/settings/presentation/widgets/delete_account_dialog_l10n_test.dart` | SOUND | t1-feat-settings | Calls real showDeleteAccountDialog; EN-absent/HE-present pairs correctly scoped; 202 lines. |
| `learning_tracker/test/features/settings/presentation/widgets/password_dialogs_l10n_test.dart` | SOUND | t1-feat-settings | Calls real showChangePasswordDialog/showReauthenticateDialog; correct l10n keys asserted; 203 lines. |
| `learning_tracker/test/features/settings/presentation/widgets/sign_out_dialog_l10n_test.dart` | ISSUES | t1-feat-settings | Never calls real showSignOutConfirmation; asserts against a hand-copied dialog duplicate. |
| `learning_tracker/test/features/settings/presentation/widgets/user_profile_header_card_l1_test.dart` | SOUND | t1-feat-settings | Pumps real widget; DG-HDR-01 regression matches lib's actual isLocalBorn/isSignedIn condition. |
| `learning_tracker/test/features/settings/settings_screen_and_point_config_l1_test.dart` | ISSUES | t1-feat-settings | 1255 lines (AG-3); tests gamification's PointConfigScreen from settings tree (AG-5). |
| `learning_tracker/test/features/settings/settings_utils_test.dart` | ISSUES | t1-feat-settings | 573 lines, no lib mirror (AG-5); docstring's A1/A2 delete-flow tests don't exist. |
| `learning_tracker/test/features/stages/data/repositories/stage_definition_repository_impl_26_26_test.dart` | ISSUES | t1-feat-tracks-extras | Rogue duplicate of the mirrored test file; misplaced ScheduleSpec coverage; 874 lines. |
| `learning_tracker/test/features/stages/data/repositories/stage_definition_repository_impl_test.dart` | ISSUES | t1-feat-tracks-extras | Solid mock+real-DB coverage; 415 lines exceeds AG-3 cap by 15. |
| `learning_tracker/test/features/stages/domain/exceptions/stage_exceptions_test.dart` | SOUND | t1-feat-tracks-extras | Checked: exception messages + StageValidator boundary test; deterministic, correctly placed. |
| `learning_tracker/test/features/stages/domain/models/stage_definition_test.dart` | SOUND | t1-feat-tracks-extras | Checked: freezed equality/copyWith smoke tests; small, correctly placed, no issues. |
| `learning_tracker/test/features/sync/.gitkeep` | SOUND | t1-feat-sync | empty scaffold placeholder, no content to audit |
| `learning_tracker/test/features/sync/data/local_data_upload_service_test.dart` | ISSUES | t1-feat-sync | 1184 lines (AG-3); one assertion-less, misleadingly-named test; otherwise thorough |
| `learning_tracker/test/features/sync/data/offline_queue_enqueue_test.dart` | ISSUES | t1-feat-sync | 100% skipped placeholder for deleted W2.35 class |
| `learning_tracker/test/features/sync/data/offline_queue_test.dart` | ISSUES | t1-feat-sync | 100% skipped placeholder for deleted W2.35 class |
| `learning_tracker/test/features/sync/data/sync_engine_test.dart.skip` | ISSUES | t1-feat-sync | 629 lines testing fully-deleted SyncEngine/FirestoreDataSource/OfflineQueue |
| `learning_tracker/test/features/sync/domain/merge_rules_test.dart` | ISSUES | t1-feat-sync | imports deprecated re-export path, not canonical core/sync file |
| `learning_tracker/test/features/sync/domain/models/sync_status_test.dart` | SOUND | t1-feat-sync | checked freezed pattern-matching/equality coverage, no wall-clock coupling |
| `learning_tracker/test/features/sync/domain/profile_scoped_preference_keys_test.dart` | ISSUES | t1-feat-sync | 555 lines (AG-3); 7 methods each duplicated across two redundant groups |
| `learning_tracker/test/features/sync/domain/reducers/streak_reducer_test.dart` | ISSUES | t1-feat-sync | AG-5: tests gamification/streak code, misfiled under sync test tree |
| `learning_tracker/test/features/sync/presentation/sync_status_indicator_l1_test.dart` | ISSUES | t1-feat-sync | 419 lines (AG-3); thorough but exercises a dead widget |
| `learning_tracker/test/features/sync/presentation/sync_status_provider_loading_state_test.dart` | ISSUES | t1-feat-sync | well-written regression test but targets the dead duplicate provider |
| `learning_tracker/test/features/track_learning_order/data/repositories/track_learning_order_repository_impl_test.dart` | ISSUES | t1-feat-tracks-extras | F1/F2 duplicate groups re-test same methods; bloats file to 675 lines. |
| `learning_tracker/test/features/track_setup/domain/entities/add_track_result_test.dart` | DEFECTIVE | t1-feat-tracks-extras | Hand-copied _getSmartDefault stale vs prod fix; test asserts already-fixed buggy behavior. |
| `learning_tracker/test/features/track_setup/presentation/controllers/add_track_controller_test.dart` | SOUND | t1-feat-tracks-extras | Checked: fresh container+addTearDown per test, real notifier exercised, no mocking, deterministic. |
| `learning_tracker/test/features/track_setup/presentation/steps/goal_helpers_test.dart` | SOUND | t1-feat-tracks-extras | Checked: pure-function tests, fixed dates, all 9 curricula covered, no flakiness. |
| `learning_tracker/test/features/track_setup/presentation/widgets/curriculum_picker_step_test.dart` | ISSUES | t1-feat-tracks-extras | Real widget interactions tested well; missing Locale('he') RTL variant, no shared pumpApp. |
| `learning_tracker/test/features/track_setup/presentation/widgets/program_selection_step_test.dart` | DEFECTIVE | t1-feat-tracks-extras | Never renders ProgramSelectionStep; tautological isNotNull asserts; widget has zero real coverage. |
| `learning_tracker/test/features/track_setup/presentation/widgets/track_label_step_test.dart` | ISSUES | t1-feat-tracks-extras | Real widget interactions tested well; missing Locale('he') RTL variant, no shared helper. |
| `learning_tracker/test/features/tracks/domain/services/track_progress_service_test.dart` | SOUND | t1-feat-tracks | Real in-memory DB; thorough tier/multi-stage/since-filter coverage; checked for gaps. |
| `learning_tracker/test/features/tracks/setup/data/repositories/track_blueprint_draft_repository_impl_test.dart` | SOUND | t1-feat-tracks | Round-trips every field; explicitly tests the documented null-skip-write behavior. |
| `learning_tracker/test/features/tracks/setup/domain/aggregates/track_blueprint_test.dart` | SOUND | t1-feat-tracks | Good sealed-hierarchy + fromLegacyResult bridge coverage; checked equality tests. |
| `learning_tracker/test/features/tracks/setup/domain/services/track_creation_service_atomicity_test.dart` | ISSUES | t1-feat-tracks | D7 rollback test solid; both B3 tests read wall clock, empirically flaky. |
| `learning_tracker/test/features/tracks/setup/domain/services/track_creation_stage_seeding_test.dart` | SOUND | t1-feat-tracks | Real DB + real services, not over-mocked; exact stage/push assertions. |
| `learning_tracker/test/features/tracks/setup/domain/use_cases/provision_track_use_case_test.dart` | SOUND | t1-feat-tracks | Correct FakeLocalDayClock usage; adversarial-validator group proves mutation sensitivity. |
| `learning_tracker/test/features/tracks/setup/edit_track_screen_l1_test.dart` | ISSUES | t1-feat-tracks | 3 vacuous tests for min-1/max-5 chazara rounds: wrong icons, length>=0 tautology. |
| `learning_tracker/test/features/tracks/setup/presentation/providers/resolve_track_title_test.dart` | SOUND | t1-feat-tracks | Small pure-function test; covers null/empty/whitespace/trim cases fully. |
| `learning_tracker/test/features/tracks/setup/presentation/screens/add_track_flow_screen_l1_test.dart` | ISSUES | t1-feat-tracks | Excellent suite; one redundant test's assertion is weaker than its own comment. |
| `learning_tracker/test/features/tracks/setup/presentation/screens/add_track_flow_ts11_test.dart` | SOUND | t1-feat-tracks | Focused regression tests for computeWizardStepTotal; verified against real function. |
| `learning_tracker/test/features/tracks/setup/presentation/screens/add_track_smart_label_test.dart` | ISSUES | t1-feat-tracks | Tests a local reimplementation; _getSmartDefault no longer calls transliterateNamedValue. |
| `learning_tracker/test/features/tracks/setup/presentation/screens/edit_track_and_detail_l1_test.dart` | ISSUES | t1-feat-tracks | 1733 lines; duplicates TrackDetailScreen suite; untested TutorWriteException swallow; weak floor assertion |
| `learning_tracker/test/features/tracks/setup/presentation/screens/edit_track_validation_test.dart` | SOUND | t1-feat-tracks | Pure-function tests for validateTrackName/studyDayCount cover blank, whitespace, zero-day branches |
| `learning_tracker/test/features/tracks/setup/presentation/screens/track_detail_goal_stale_test.dart` | SOUND | t1-feat-tracks | DB-backed regression test, fresh DB/fake clock, verifies provider invalidation on navigator pop |
| `learning_tracker/test/features/tracks/setup/presentation/screens/track_detail_screen_date_test.dart` | SOUND | t1-feat-tracks | Pure formatTrackDate unit test, both Gregorian/Hebrew branches checked against real formatters |
| `learning_tracker/test/features/tracks/setup/presentation/screens/track_detail_screen_test.dart` | ISSUES | t1-feat-tracks | 578 lines; duplicates edit_track_and_detail suite; no localDayClockProvider override (wall-clock dependent) |
| `learning_tracker/test/features/tracks/setup/presentation/screens/track_hub_ts16_test.dart` | ISSUES | t1-feat-tracks | Tests trackDeletionAllowed well; TrackDetailScreen bypasses it with inline duplicate logic |
| `learning_tracker/test/features/tracks/setup/presentation/steps/deadline_goal_card_zero_items_test.dart` | SOUND | t1-feat-tracks | Direct DeadlineGoalCard widget test; zero vs positive scope-item boundary, concrete text checks |
| `learning_tracker/test/features/tracks/setup/presentation/steps/goal_step_ts10_state_preserve_test.dart` | DEFECTIVE | t1-feat-tracks | Tautological: only checks constructor stores initialGoal, never pumps widget to verify restore |
| `learning_tracker/test/features/tracks/setup/presentation/steps/goal_step_ts5_continue_overlap_test.dart` | SOUND | t1-feat-tracks | Real interaction test: taps Continue, asserts emitted GoalEntity and no DatePickerDialog opens |
| `learning_tracker/test/features/tracks/setup/presentation/steps/self_paced_goal_step_scope_test.dart` | DEFECTIVE | t1-feat-tracks | Same tautology as TS-10 test: only checks constructor stores scopeSelections, never pumped |
| `learning_tracker/test/features/tracks/setup/presentation/steps/starting_position_calendar_overflow_test.dart` | ISSUES | t1-feat-tracks | Hand-rolled single-viewport overflow check bypasses the established expectNoOverflowAcrossDevices matrix harness |
| `learning_tracker/test/features/tracks/setup/presentation/steps/step_chazara_goal_l1_test.dart` | ISSUES | t1-feat-tracks | 1015 lines; thorough 22-scenario suite; one granularity assertion weaker than its own comment |
| `learning_tracker/test/features/tracks/setup/presentation/steps/step_scope_l1_test.dart` | ISSUES | t1-feat-tracks | Comprehensive, well-targeted interaction tests; 986 lines exceeds the 400-line AG-3 cap |
| `learning_tracker/test/features/tracks/setup/presentation/steps/step_starting_position_l1_test.dart` | ISSUES | t1-feat-tracks | 1510 lines (3 widgets), wall-clock DateTime.now() x6, 6 unclosed inMemoryDb(). |
| `learning_tracker/test/features/tracks/setup/presentation/steps/step_study_days_l1_test.dart` | SOUND | t1-feat-tracks | Verified Hebrew/nusach/avatar-initial fixes against real widget; hermetic, no DB/clock. |
| `learning_tracker/test/features/tracks/setup/presentation/widgets/program_selection_step_test.dart` | SOUND | t1-feat-tracks | Verified programStartsLabel regression against real implementation; hermetic pure function. |
| `learning_tracker/test/features/tracks/setup/presentation/widgets/track_info_card_pace_unit_test.dart` | SOUND | t1-feat-tracks | Verified paceGoalUnitNoun math (Dafim/Dapim/Hebrew/Mishnayos) against real implementation. |
| `learning_tracker/test/features/tracks/setup/presentation/widgets/track_info_card_test.dart` | SOUND | t1-feat-tracks | Verified elapsedRemainingLabel fix against real implementation; no leaks or clock use. |
| `learning_tracker/test/features/tracks/setup/track_management_hub_last_curriculum_guard_test.dart` | SOUND | t1-feat-tracks | DB create/close balanced 3/3; last-curriculum guard verified against real screen code. |
| `learning_tracker/test/features/tracks/setup/track_management_hub_screen_l1_test.dart` | ISSUES | t1-feat-tracks | 541 lines (AG-3); shared db default never closed; scaffolding duplicated from siblings. |
| `learning_tracker/test/features/tracks/track_management_body_and_order_l1_test.dart` | ISSUES | t1-feat-tracks | 1089 lines/2 screens; 5 unclosed DBs; race-safety test doesn't pin the seq guard. |
| `learning_tracker/test/features/tracks/track_order/domain/track_order_test.dart` | SOUND | t1-feat-tracks | Pure hermetic domain tests; verified TrackOrder/MasechtaOrderingPolicy math directly. |
| `learning_tracker/test/features/tracks/track_order/presentation/track_learning_order_reset_test.dart` | ISSUES | t1-feat-tracks | Exemplary Completer-based race test; but its 1 inMemoryDb() is never closed. |
| `learning_tracker/test/features/tracks_studydays_and_content_hierarchy_l1_test.dart` | ISSUES | t1-test-cross | 951 lines; tautological Container assertion (test 20); 4x unclosed inMemoryDb() leak. |
| `learning_tracker/test/features/tutor_pin_dialog_and_goal_setup_l1_test.dart` | ISSUES | t1-test-cross | 1407 lines (AG-3); GoalSetupForm/Screen has zero Hebrew/RTL test coverage. |
| `learning_tracker/test/features/tutoring/accept_invite_screen_l1_test.dart` | ISSUES | t1-feat-tutoring | excellent state-machine coverage but pins raw-English PreconditionError text as correct; no shared pumpApp helper |
| `learning_tracker/test/features/tutoring/accept_invite_screen_overflow_test.dart` | ISSUES | t1-feat-tutoring | solid device-matrix overflow guard; only gap is hand-rolled MaterialApp/delegate boilerplate |
| `learning_tracker/test/features/tutoring/data/repositories/firestore_tutor_grant_repository_test.dart` | ISSUES | t1-feat-tutoring | comprehensive real-seam repo coverage; one tautological constructor-tearoff test, one weak length-bound assertion |
| `learning_tracker/test/features/tutoring/decline_invite_screen_l1_test.dart` | ISSUES | t1-feat-tutoring | excellent coverage but pins raw-English PreconditionError text as correct; no shared pumpApp helper |
| `learning_tracker/test/features/tutoring/decline_invite_screen_overflow_test.dart` | ISSUES | t1-feat-tutoring | solid overflow guard; only gap is hand-rolled MaterialApp/delegate boilerplate |
| `learning_tracker/test/features/tutoring/domain/use_cases/mark_live_completion_use_case_test.dart` | SOUND | t1-feat-tutoring | pure domain test, real invariant assertions, no shared state; checked for tautology, found none |
| `learning_tracker/test/features/tutoring/f3_account_switch_reset_test.dart` | SOUND | t1-feat-tutoring | source-text regression guard is historically justified; real ProviderContainer state assertions, proper teardown |
| `learning_tracker/test/features/tutoring/firestore_audit_log_read_repository_test.dart` | ISSUES | t1-feat-tutoring | solid round-trip/malformed-input coverage; one tautological compile-check test |
| `learning_tracker/test/features/tutoring/firestore_tutor_grant_repository_test.dart` | ISSUES | t1-feat-tutoring | duplicate/misplaced (AG-5) file: tautological structural + self-referential exception tests, superseded by mirrored file |
| `learning_tracker/test/features/tutoring/ga5_resignation_childname_test.dart` | ISSUES | t1-feat-tutoring | domain-getter tests are correct but the file never imports/exercises the real screens it claims to guard |
| `learning_tracker/test/features/tutoring/incoming_tutor_grants_reconcile_test.dart` | SOUND | t1-feat-tutoring | fake repo, fresh container+teardown, hermetic in-memory DB; verified both D18 offline/online branches |
| `learning_tracker/test/features/tutoring/invite_tutor_screen_l1_test.dart` | ISSUES | t1-feat-tutoring | Strong coverage; one dead tautological test; no Hebrew/RTL locale variant. |
| `learning_tracker/test/features/tutoring/iter10_outgoing_grants_stale_cache_test.dart` | SOUND | t1-feat-tutoring | Real regression test via ProviderScope + mock repo; non-tautological, well-scoped; under 400 lines. |
| `learning_tracker/test/features/tutoring/manage_grants_screen_l1_test.dart` | ISSUES | t1-feat-tutoring | Thorough widget tests; no RTL variant; resign mirror-wipe side effect unverified. |
| `learning_tracker/test/features/tutoring/manage_tutors_screen_l1_test.dart` | ISSUES | t1-feat-tutoring | Excellent breadth; revoke mirror-wipe unverified; one stale test description string. |
| `learning_tracker/test/features/tutoring/mark_live_completion_invariant_test.dart` | ISSUES | t1-feat-tutoring | Core tutor-write-block invariant solidly tested; W7.11 analytics event unverified. |
| `learning_tracker/test/features/tutoring/r3_shell_revocation_exit_test.dart` | ISSUES | t1-feat-tutoring | 3 solid provider-layer regression tests; 1 block is source-text-grep only. |
| `learning_tracker/test/features/tutoring/s1_tutored_write_router_test.dart` | ISSUES | t1-feat-tutoring | Exhaustive router coverage; 4 always-pass-through methods never exercised in tutored mode. |
| `learning_tracker/test/features/tutoring/s2_entity_parity_test.dart` | ISSUES | t1-feat-tutoring | Real router+entity tests, non-tautological; 523 lines exceeds AG-3 400-line cap. |
| `learning_tracker/test/features/tutoring/s4_tutor_write_service_permission_test.dart` | SOUND | t1-feat-tutoring | Real service exercised; success/failure/permission-denied branches covered; under cap. |
| `learning_tracker/test/features/tutoring/t3_readonly_surfaces_gating_test.dart` | DEFECTIVE | t1-feat-tutoring | 23 of 24 tests grep raw source text via readAsStringSync, not rendered widgets. |
| `learning_tracker/test/features/tutoring/tutor_audit_log_screen_l1_test.dart` | ISSUES | t1-feat-tutoring | Thorough, real RTL geometry checks, no tautologies; 656 lines exceeds AG-3 cap. |
| `learning_tracker/test/features/tutoring/tutor_pin_entry_gate_l1_test.dart` | ISSUES | t1-feat-tutoring | Real testWidgets behavior coverage; 1283 lines (AG-3); flat placement (AG-5). |
| `learning_tracker/test/features/tutoring/tutor_pin_reset_screen_l1_test.dart` | ISSUES | t1-feat-tutoring | Real testWidgets coverage; missing RTL variant (TQ-3); flat placement (AG-5). |
| `learning_tracker/test/features/tutoring/tutor_pin_setup_screen_l1_test.dart` | ISSUES | t1-feat-tutoring | Real testWidgets coverage; 623 lines (AG-3); missing RTL; flat placement. |
| `learning_tracker/test/features/tutoring/v3c_ui_gating_exception_catching_test.dart` | DEFECTIVE | t1-feat-tutoring | All 14 tests grep source text only; zero runtime execution (TQ-8). |
| `learning_tracker/test/features/tutoring/w3_41_tutor_security_rules_test.dart` | ISSUES | t1-feat-tutoring | Documented structural rules checks (legit); 459 lines (AG-3); one dead skipped test. |
| `learning_tracker/test/features/tutoring/ws3_3a_manage_tutors_entry_test.dart` | ISSUES | t1-feat-tutoring | All 6 tests grep source text of 4 files; zero execution. |
| `learning_tracker/test/features/tutoring/ws3_3b_tutor_invitations_surface_test.dart` | ISSUES | t1-feat-tutoring | All 9 tests grep source text; visibility rule never actually executed. |
| `learning_tracker/test/features/tutoring/ws3_3c_talmid_access_pin_test.dart` | ISSUES | t1-feat-tutoring | Mostly source-grep for PIN-gate wiring; 3 genuine domain unit tests mixed in. |
| `learning_tracker/test/features/tutoring/ws3_3d_tutor_permissions_surface_test.dart` | ISSUES | t1-feat-tutoring | Mostly source-grep; genuine TutorPermissions domain unit tests cover AC5. |
| `learning_tracker/test/features/tutoring/ws3_3e_dual_role_fix_test.dart` | ISSUES | t1-feat-tutoring | All 4 tests source-grep; fragile duplicated method-body extraction heuristic. |
| `learning_tracker/test/features/tutoring/ws3_3f_manage_remove_tutors_test.dart` | ISSUES | t1-feat-tutoring | All 8 tests grep manage_tutors_screen.dart text only; zero execution. |
| `learning_tracker/test/features/tutoring/ws3_3g_notification_gateway_test.dart` | ISSUES | t1-feat-tutoring | All 12 tests grep source text across 5 files; zero execution. |
| `learning_tracker/test/features/tutoring/ws3_3h_corrections_test.dart` | ISSUES | t1-feat-tutoring | Mixed: 3 genuine TutorPermissions unit tests + 6 source-grep tests. |
| `learning_tracker/test/fixtures/.gitkeep` | SOUND | t1-test-helpers | Empty placeholder; directory now holds real files but file itself is inert. |
| `learning_tracker/test/fixtures/completion_fixtures.dart.skip` | DEFECTIVE | t1-test-helpers | Dead: imports removed app_database.dart/Completions table; zero callers repo-wide. |
| `learning_tracker/test/fixtures/content_fixtures.dart` | SOUND | t1-test-helpers | Pure fixture factories, fields match ContentItem ctor; no Rule-5/wall-clock issues. |
| `learning_tracker/test/fixtures/curriculum_fixtures.dart` | ISSUES | t1-test-helpers | CurriculumFixtures correct and used; StageFixtures class has zero callers anywhere. |
| `learning_tracker/test/fixtures/sefaria/bavli_shape.json` | SOUND | t1-test-helpers | Valid JSON; loaded by fetcher_test.dart; ran suite, 42/42 pass. |
| `learning_tracker/test/fixtures/sefaria/mishna_berurah_shape.json` | SOUND | t1-test-helpers | Valid JSON; consumed by fetcher_test.dart MussarFetcher cases. |
| `learning_tracker/test/fixtures/sefaria/mishnah_shape.json` | SOUND | t1-test-helpers | Valid JSON; core fixture for multiple fetcher_test.dart cases, confirmed live. |
| `learning_tracker/test/fixtures/sefaria/mussar_shape_chovot_halevavot.json` | SOUND | t1-test-helpers | Valid JSON; used by fetcher_test.dart Mussar-fetcher cases. |
| `learning_tracker/test/fixtures/sefaria/mussar_shape_mesillat_yesharim.json` | SOUND | t1-test-helpers | Valid JSON; used by fetcher_test.dart Mussar-fetcher cases. |
| `learning_tracker/test/fixtures/sefaria/mussar_shape_orchot_tzaddikim.json` | SOUND | t1-test-helpers | Valid JSON; used by fetcher_test.dart Mussar-fetcher cases. |
| `learning_tracker/test/fixtures/sefaria/nach_shape.json` | SOUND | t1-test-helpers | Valid JSON; used by NachFetcher tests; content internally consistent. |
| `learning_tracker/test/fixtures/sefaria/shulchan_aruch_oc_shape.json` | SOUND | t1-test-helpers | Valid JSON; used by fetcher_test.dart Shulchan-Aruch cases. |
| `learning_tracker/test/fixtures/sefaria/tanakh_shape.json` | SOUND | t1-test-helpers | Valid JSON; used by fetcher_test.dart Tanakh/Torah-exclusion cases. |
| `learning_tracker/test/fixtures/sefaria/text_response.json` | SOUND | t1-test-helpers | Valid JSON; used by fetcher_test.dart text-fetch cases, both locales present. |
| `learning_tracker/test/fixtures/sefaria/yerushalmi_shape.json` | SOUND | t1-test-helpers | Valid JSON; used by fetcher_test.dart Yerushalmi cases. |
| `learning_tracker/test/flutter_test_config.dart` | ISSUES | t1-test-helpers | No font loading (TQ-5 names this file); onError GoogleFonts filter dead, SDK-traced. |
| `learning_tracker/test/golden/store_screenshots_test.dart` | DEFECTIVE | t1-test-cross | Hardcoded /home/daniel font path; 3 of 5 shots test mockups, not app code. |
| `learning_tracker/test/helpers/drift_memory.dart` | ISSUES | t1-test-helpers | seedProfile/seedProfileZero byte-identical to test_database.dart; DateTimeFactory usage compliant. |
| `learning_tracker/test/helpers/firestore_fake.dart` | SOUND | t1-test-helpers | Lazy rules load, dual-cwd fallback, no real Firebase import; tradeoffs documented. |
| `learning_tracker/test/helpers/golden_runner.dart` | ISSUES | t1-test-helpers | matchesGoldenFile unexercised (11/11 callers skipGolden:true); probe showed blank captures. |
| `learning_tracker/test/helpers/migration_test_helper.dart` | ISSUES | t1-test-helpers | Functionally sound and used; usage doc says v19, actual schemaVersion is 32. |
| `learning_tracker/test/helpers/overflow_harness.dart` | SOUND | t1-test-helpers | Ran suite; self-test proves the guard catches a deliberately-overflowing widget. |
| `learning_tracker/test/helpers/test_database.dart` | ISSUES | t1-test-helpers | seedProfile/seedProfileZero duplicate drift_memory.dart; forces show/hide in 26 files. |
| `learning_tracker/test/infrastructure_test.dart` | DEFECTIVE | t1-test-helpers | Tautological assertions throughout; 'isolated between tests' checks only identical(). |
| `learning_tracker/test/integration/bulk_mark_prior_streak_suppression_test.dart` | SOUND | t1-test-cross | Fresh in-memory DB, injected FakeLocalDayClock, reasoned assertions tied to DNI-370 ACs. |
| `learning_tracker/test/integration/bulk_prior_completion_b6_b8_test.dart` | ISSUES | t1-test-cross | 1225 lines; wall-clock bound-check; weak >=2 assertion; stale AC3; dup mock class. |
| `learning_tracker/test/integration/bypass_cleanup_offline_test.dart` | SOUND | t1-test-cross | Fresh harness/gateway per test; deterministic clock; verifies outbox retain+drain roundtrip. |
| `learning_tracker/test/integration/firestore_wipe_install_test.dart` | ISSUES | t1-test-cross | 429 lines (AG-3); duplicates existing MockAuthRepository via 75-line hand-rolled stub. |
| `learning_tracker/test/integration/pull_on_launch_test.dart` | SOUND | t1-test-cross | Fresh db/router per test; explicit UTC times; real view/idempotency assertions. |
| `learning_tracker/test/integration/restore_skip_onboarding_test.dart` | SOUND | t1-test-cross | Fresh db per test; hand-written fake orchestrator; documented route-decision limitation. |
| `learning_tracker/test/integration/sacred_time_overlay_scope_test.dart` | ISSUES | t1-test-cross | No Locale('he') variant for this access-control overlay; pins Ashkenazi-English throughout. |
| `learning_tracker/test/integration/shabbos_notification_suppression_test.dart` | SOUND | t1-test-cross | Deterministic tz fixture; mocktail verified via verify(); explicit UTC boundary assertions. |
| `learning_tracker/test/integration/stage_sync_test.dart` | ISSUES | t1-test-cross | _insertTrack helper uses DateTime.now() instead of the DateTimeFactory clock seam. |
| `learning_tracker/test/integration/two_device_sync_test.dart` | SOUND | t1-test-cross | Fresh dual DBs per test; explicit UTC; real LWW/idempotency via production API. |
| `learning_tracker/test/l10n/account_picker_subtitle_copy_test.dart` | SOUND | t1-app-l10n | Reads real ARB via json.decode; assertions match current EN/HE content. |
| `learning_tracker/test/l10n/app_localizations_coverage_test.dart` | ISSUES | t1-app-l10n | 1482 lines (AG-3), zero expect() calls — pads CI coverage floor. |
| `learning_tracker/test/l10n/b1_vocab_keys_present_test.dart` | ISSUES | t1-app-l10n | Dup ARB-load helper (no CWD fallback); pins 2 dead keys (milestoneAggregate, recentActivityShort). |
| `learning_tracker/test/l10n/hebrew_shabbos_strings_il9_test.dart` | ISSUES | t1-app-l10n | Duplicated _loadArb helper; assertions verified correct against live app_he.arb content. |
| `learning_tracker/test/l10n/icu_plural_il3_test.dart` | ISSUES | t1-app-l10n | Duplicated _loadArb helper; ICU-plural assertions verified against real ARB values, all pass. |
| `learning_tracker/test/l10n/no_hardcoded_percent_in_chart_subtitle_test.dart` | ISSUES | t1-app-l10n | Inlined dup ARB-load logic; regex misses unsigned/non-percent fabricated stats. |
| `learning_tracker/test/l10n/tier_counter_pluralization_test.dart` | SOUND | t1-app-l10n | Ran green; asserts real generated AppLocalizations output incl. Hebrew dual forms. |
| `learning_tracker/test/migration/v15_to_v16_test.dart` | ISSUES | t1-test-cross | Skipped group contains dead expect(true, isFalse/isTrue) placeholder assertions (landmine). |
| `learning_tracker/test/migration/v16_to_v17_test.dart` | ISSUES | t1-test-cross | FK-violation test uses throwsA(anything), weaker than sibling tests' typed matchers. |
| `learning_tracker/test/migration/v17_to_v18_test.dart` | SOUND | t1-test-cross | Fresh db per test; asserts purgedAt tombstone + row-count invariant precisely. |
| `learning_tracker/test/migration/v18_to_v19_test.dart` | SOUND | t1-test-cross | Cleanly skipped with reason and empty bodies; no dead assertions. |
| `learning_tracker/test/migration/v19_to_v20_test.dart` | SOUND | t1-test-cross | Fresh db per test; explicit UTC; verifies view purge-filter both directions. |
| `learning_tracker/test/migration/v21_to_v22_test.dart` | SOUND | t1-test-cross | Fresh db per test; verifies natural-key widening + dedup precisely. |
| `learning_tracker/test/migration/v25_to_v27_test.dart` | SOUND | t1-test-cross | Raw-SQL fixture + real upgrade; FK-check/CHECK-constraint/row-preservation asserted precisely. |
| `learning_tracker/test/migration/v26_to_v29_test.dart` | SOUND | t1-test-cross | Raw-SQL v26 fixture; asserts backfill, FK integrity, additive columns precisely. |
| `learning_tracker/test/migration/v27_to_v28_test.dart` | SOUND | t1-test-cross | Raw-SQL v27 fixture; asserts CHECK constraint enforcement via typed exception. |
| `learning_tracker/test/migration/v27_to_v29_test.dart` | SOUND | t1-test-cross | Raw-SQL fixture distinguishes synced vs local-born rows; precise backfill assertions. |
| `learning_tracker/test/migration/v31_to_v32_test.dart` | SOUND | t1-test-cross | Raw-SQL fixture with legitimate/spurious rows; precise survive/delete assertions. |
| `learning_tracker/test/mocks/.gitkeep` | SOUND | t1-test-helpers | Empty placeholder; directory now holds real files but file itself is inert. |
| `learning_tracker/test/mocks/mock_repositories.dart` | SOUND | t1-test-helpers | Mocktail per TQ-4; both classes genuinely used across dozens of test files. |
| `learning_tracker/test/mocks/mock_services.dart` | SOUND | t1-test-helpers | Mocktail per TQ-4; sole consumer is infrastructure_test.dart's tautological smoke test. |
| `learning_tracker/test/overflow/overflow_guard_test.dart` | SOUND | t1-test-cross | Self-testing harness; positive+negative self-test cases; deterministic device matrix. |
| `learning_tracker/test/scheduler/overdue_durability_test.dart` | ISSUES | t1-feat-scheduler | Real Drift DB, real sync-gate code, compliant teardown; 579 lines, wrong test dir. |
| `learning_tracker/test/scheduler/overdue_notifications_test.dart` | ISSUES | t1-feat-scheduler | Never invokes reminderSyncEffect; hand-duplicates D1/D2 filter+guard; dead Mock class. |
| `learning_tracker/test/scheduler/overdue_projection_test.dart` | ISSUES | t1-feat-scheduler | Best file in batch: real production calls, fixed clock, named regressions; 1000 lines, wrong dir. |
| `learning_tracker/test/story_acceptance/epic_01_foundation_test.dart` | ISSUES | t1-story-epics-01-08 | 31 compile-tautological isNotNull/true-isTrue asserts across 6 of 12 stories verify nothing |
| `learning_tracker/test/story_acceptance/epic_02_content_test.dart` | ISSUES | t1-story-epics-01-08 | 11 tautological isNotNull checks; 2 schema-removal tests assert nothing about schema |
| `learning_tracker/test/story_acceptance/epic_03_learning_cycle_test.dart` | ISSUES | t1-story-epics-01-08 | Solid DB-backed completion/points/progress tests; one wall-clock 5s-window assertion |
| `learning_tracker/test/story_acceptance/epic_05_stages_order_test.dart` | ISSUES | t1-story-epics-01-08 | Solid stage/order repo tests, deterministic; Story 5.2 group missing tags: entry |
| `learning_tracker/test/story_acceptance/epic_06_scheduler_test.dart` | SOUND | t1-story-epics-01-08 | Checked scheduler engine, pace calc, goals, bulk-sentinel regression; deterministic, real DB, no tautologies |
| `learning_tracker/test/story_acceptance/epic_07_dashboard_test.dart` | ISSUES | t1-story-epics-01-08 | 2 tests verify unrelated trivial logic vs their titles; breadcrumb test mirrors a private fn |
| `learning_tracker/test/story_acceptance/epic_08_gamification_test.dart` | SOUND | t1-story-epics-01-08 | Checked points/streak/completion-feedback state machine; real DB+services, proper FakeLocalDayClock use |
| `learning_tracker/test/story_acceptance/epic_09_onboarding_test.dart` | ISSUES | t1-story-epics-09-16 | Dup _insertTrack helper (shared seedTrack exists); otherwise solid fixed-date tests. |
| `learning_tracker/test/story_acceptance/epic_10_parent_mode_test.dart` | ISSUES | t1-story-epics-09-16 | Streak test UTC-seeds vs local-day clock (timezone-dependent); dup _insertTrack helper. |
| `learning_tracker/test/story_acceptance/epic_12_notifications_test.dart` | ISSUES | t1-story-epics-09-16 | Best-in-batch fixed-clock/streak pattern; only shares dup _insertTrack helper. |
| `learning_tracker/test/story_acceptance/epic_13_cloud_sync_test.dart` | SOUND | t1-story-epics-09-16 | Checked clock/date handling, stub fakes, skip reasons; uses shared seedTrack correctly. |
| `learning_tracker/test/story_acceptance/epic_14_settings_test.dart` | ISSUES | t1-story-epics-09-16 | 2 TODOs lack DNI id (AG-6); dup _insertTrack helper. |
| `learning_tracker/test/story_acceptance/epic_15_multi_profile_test.dart` | ISSUES | t1-story-epics-09-16 | 2 tautological tests; 1 sleep-polling stream test (4 sites); dup helper. |
| `learning_tracker/test/story_acceptance/epic_16_pace_dashboard_test.dart` | DEFECTIVE | t1-story-epics-09-16 | 8 tests tautological or assert a proven-stale fabricated enum copy; dup helper. |
| `learning_tracker/test/story_acceptance/epic_18_story_18x_track_restore_test.dart` | ISSUES | t1-story-epics-17-20 | purgeHistory test doesn't prove tombstone-vs-delete; other 2 tests correct. |
| `learning_tracker/test/story_acceptance/epic_18_track_overhaul_test.dart` | ISSUES | t1-story-epics-17-20 | Tautological childAwareText copy, dead mocktail import, 689 lines over AG-3 cap. |
| `learning_tracker/test/story_acceptance/epic_19_offline_first_test.dart` | ISSUES | t1-story-epics-17-20 | AT-19.3.6 misleads on gzip coverage; stale Story-19.5 dup; 2 empty catches; 624 lines. |
| `learning_tracker/test/story_acceptance/epic_20_hard_tier_auth_test.dart` | SOUND | t1-story-epics-17-20 | Real DB-backed auth/merge/reducer assertions, fixed clocks, no dead imports or tautologies. |
| `learning_tracker/test/story_acceptance/epic_21_multi_account_test.dart` | ISSUES | t1-story-epics-21-24 | 1048 lines (AG-3); ad-hoc cleanup skips on failure (20 tests); 2 shallow ACs |
| `learning_tracker/test/story_acceptance/epic_24_stop_bleeding_test.dart` | ISSUES | t1-story-epics-21-24 | Near-duplicate epic-24 file; 2 tautological verifyNever; weak payload check; redeclares MockContentRepository |
| `learning_tracker/test/story_acceptance/epic_24_stop_the_bleeding_test.dart` | ISSUES | t1-story-epics-21-24 | 423 lines (AG-3); near-duplicate epic-24 file; unscoped rules-text checks; Crashlytics fake drift risk |
| `learning_tracker/test/story_acceptance/epic_25_schema_core_test.dart` | ISSUES | t1-story-epic-25 | 2036 lines (AG-3); tautological AuthRepository mock test; wall-clock race in today() test |
| `learning_tracker/test/story_acceptance/epic_25_story_12_sync_decomp_part1_test.dart` | ISSUES | t1-story-epic-25 | 718 lines (AG-3); two hand-rolled FirestoreGateway fakes duplicate all 40 methods |
| `learning_tracker/test/story_acceptance/epic_25_story_13_merge_router_test.dart` | ISSUES | t1-story-epic-25 | 501 lines (AG-3) only; MergeRouter/LWW invariant tests otherwise thorough and sound |
| `learning_tracker/test/story_acceptance/epic_25_story_14_listener_lifecycle_test.dart` | SOUND | t1-story-epic-25 | 364 lines; real WidgetsBinding-driven lifecycle tests, hand fakes, no wall-clock/shared state |
| `learning_tracker/test/story_acceptance/epic_25_story_15_completion_writer_test.dart` | SOUND | t1-story-epic-25 | 277 lines; real-Drift transaction rollback and idempotency tests, no issues found |
| `learning_tracker/test/story_acceptance/epic_25_story_16_streak_test.dart` | ISSUES | t1-story-epic-25 | 564 lines (AG-3) only; local-day-boundary and merger dedup tests are thorough |
| `learning_tracker/test/story_acceptance/epic_25_story_18_pin_guard_test.dart` | ISSUES | t1-story-epic-25 | 402 lines (AG-3, barely); PinGuard session-cache/scope-isolation interaction tests sound |
| `learning_tracker/test/story_acceptance/epic_25_story_21_multi_account_threading_test.dart` | ISSUES | t1-story-epic-25 | local wrap() harness duplicated instead of a shared pumpApp helper (TQ-3) |
| `learning_tracker/test/story_acceptance/epic_25_story_22_firewall_test.dart` | SOUND | t1-story-epic-25 | 264 lines; schema/onboarding/device-isolation checks against real in-memory Drift, clean |
| `learning_tracker/test/story_acceptance/epic_25_story_25_20_locale_theme_test.dart` | ISSUES | t1-story-epic-25 | 449 lines (AG-3); 4-path candidate search copy-pasted 3x in this file |
| `learning_tracker/test/story_acceptance/epic_25_story_25_9_lints_test.dart` | SOUND | t1-story-epic-25 | 218 lines; documented allow-list grep tests with DRY helpers, no issues |
| `learning_tracker/test/story_acceptance/epic_25_story_25_9_test.dart` | ISSUES | t1-story-epic-25 | local _wrap() harness omits AppLocalizations delegates entirely (TQ-3 gap) |
| `learning_tracker/test/story_acceptance/epic_25_story_2_append_only_uniques_test.dart` | SOUND | t1-story-epic-25 | 399 lines; UNIQUE-index and INSERT-OR-IGNORE dedup tests against real Drift, clean |
| `learning_tracker/test/story_acceptance/epic_26_story_11_onboarding_controller_test.dart` | ISSUES | t1-story-epic-26 | Controller/step tests solid; dead-prefs-key check via toString proxy is weak (TQ-8). |
| `learning_tracker/test/story_acceptance/epic_26_story_13_reader_purity_test.dart` | ISSUES | t1-story-epic-26 | Counter tests good; reader-purity file check is a no-op, claimed CI grep doesn't exist. |
| `learning_tracker/test/story_acceptance/epic_26_story_15_composite_strategy_test.dart` | ISSUES | t1-story-epic-26 | isComposite/remap/transaction tests solid; 'leaf curricula' loop has inverted guard, can't fail. |
| `learning_tracker/test/story_acceptance/epic_26_story_23_data_export_round_trip_test.dart` | ISSUES | t1-story-epic-26 | Strong round-trip/tombstone coverage; file is 742 lines (AG-3), copy-pasted duplicate deletes. |
| `learning_tracker/test/story_acceptance/epic_26_story_26_16_stat_card_test.dart` | ISSUES | t1-story-epic-26 | Widget tests solid but EN-only; 1 tautological isNotNull; reimplements file-lookup helper. |
| `learning_tracker/test/story_acceptance/epic_26_story_26_20_preference_tiles_test.dart` | ISSUES | t1-story-epic-26 | Good source-grep ACs; 2 tautological isNotNull, 5x duplicated file-lookup blocks, stale comment. |
| `learning_tracker/test/story_acceptance/epic_26_story_26_22_track_management_body_test.dart` | ISSUES | t1-story-epic-26 | AC2-4 exception tests solid; AC1 unit-tests widget in isolation — zero production callers. |
| `learning_tracker/test/story_acceptance/epic_26_story_26_31_rtl_audit_test.dart` | ISSUES | t1-story-epic-26 | Strong repo-wide RTL regex sweep (AC1-3); AC4's add_track_flow check is dead, mis-pathed. |
| `learning_tracker/test/story_acceptance/epic_26_story_26_6_track_card_test.dart` | ISSUES | t1-story-epic-26 | Short file; 4 of 6 tests are tautological isNotNull filler on providers/enum values. |
| `learning_tracker/test/story_acceptance/epic_26_story_26_7_dashboard_model_provider_test.dart` | ISSUES | t1-story-epic-26 | AC2-4 solid; AC1 group is 6/7 tautological isNotNull filler; reimplements file-lookup helper 3x. |
| `learning_tracker/test/story_acceptance/epic_27_integration_lockout_redaction_atomic_test.dart` | ISSUES | t1-story-epic-27 | AC1/AC2 solid; AC3 tests Drift's own rollback, not CompletionRepositoryImpl (prod violates FR20). |
| `learning_tracker/test/story_acceptance/epic_27_story_05_bulk_mark_prior_test.dart` | ISSUES | t1-story-epic-27 | Tautological empty-list reducer check; 2nd test depends on unmocked real wall clock. |
| `learning_tracker/test/story_acceptance/epic_27_story_06_streak_reconciles_test.dart` | SOUND | t1-story-epic-27 | Checked: fixed clocks/timestamps throughout, real DAO+StreakRestorer+reducer calls, ran green. |
| `learning_tracker/test/story_acceptance/epic_27_story_14_analytics_test.dart` | ISSUES | t1-story-epic-27 | crash_reported test name contradicts its assertion; file is 493 lines (AG-3). |
| `learning_tracker/test/story_acceptance/epic_27_story_27_8_rules_and_offline_flush_test.dart` | ISSUES | t1-story-epic-27 | Rules tests string-match text only; 953-line file duplicates a 22x-repeated gateway fake. |
| `learning_tracker/test/story_acceptance/epic_27_story_4_widget_golden_test.dart` | ISSUES | t1-story-epic-27 | 3 vacuous 'AC structural verification' asserts; one untracked TODO (AG-6). |
| `learning_tracker/test/story_acceptance/epic_27_story_7_isolation_and_canonical_layout_test.dart` | SOUND | t1-story-epic-27 | Checked: 15 isolation ACs against real CompletionDao queries, deterministic fixtures, ran green. |
| `learning_tracker/test/story_acceptance/epic_27_story_f5_prior_learning_filter_test.dart` | ISSUES | t1-story-epic-27 | Regression test mirrors an unexported private closure instead of calling production code. |
| `learning_tracker/test/story_acceptance/epic_27_test_infrastructure_test.dart` | ISSUES | t1-story-epic-27 | schemaVersion self-comparison tautology; stale docstring; one misnamed rules test. |
| `learning_tracker/test/story_acceptance/epic_28_curriculum_overlap_test.dart` | ISSUES | t1-story-epics-28plus | 445 lines (AG-3); union helper diverged from prod fix; dupes seed helpers; missing dart_test.yaml tags |
| `learning_tracker/test/story_acceptance/regression_invariants_test.dart` | ISSUES | t1-story-epics-01-08 | N7 never calls the production code it's meant to guard; N5 has a wall-clock window |
| `learning_tracker/test/story_acceptance/story_i3_items_learned_test.dart` | SOUND | t1-story-epics-01-08 | Checked tier-filtering summary tests; real production functions, fixed dates, meaningful asserts |
| `learning_tracker/test/story_acceptance/track_lifecycle_test.dart` | SOUND | t1-story-epics-01-08 | Checked overdue-projection/delete-restore/multi-profile tests; deterministic, real DAOs, strong net |
| `learning_tracker/test/sync/bookmark_outbox_entity_key_test.dart` | SOUND | t1-feat-sync | checked entity-key collision logic, deterministic clock, real DB |
| `learning_tracker/test/sync/codec_rules_contract_test.dart` | SOUND | t1-feat-sync | checked static codec/rules parser oracle, self-guards parser drift |
| `learning_tracker/test/sync/learner_profile_delete_enqueue_profile0_test.dart` | SOUND | t1-feat-sync | Real DB, fake clock, precise profile-0 vs target-id assertions; no defects found. |
| `learning_tracker/test/sync/lifecycle_observer_test.dart` | ISSUES | t1-feat-sync | Hand-rolled hook fakes solid; 'detached' claimed in title, never exercised. |
| `learning_tracker/test/sync/listener_limit_test.dart` | SOUND | t1-feat-sync | Hand-rolled gateway fake; verifies limit=500 + orderField per collection; hermetic. |
| `learning_tracker/test/sync/listener_overflow_recovery_test.dart` | ISSUES | t1-feat-sync | Throttle test uses real SystemLocalDayClock instead of project's fake-clock seam. |
| `learning_tracker/test/sync/listener_parking_test.dart` | SOUND | t1-feat-sync | Injectable durations keep timer tests fast; park/unpark ordering well covered. |
| `learning_tracker/test/sync/location_device_scope_test.dart` | ISSUES | t1-feat-sync | Solid DEC-26 regression; overlaps codecs_and_mergers_test.dart UiPreferences coverage. |
| `learning_tracker/test/sync/merge/bookmark_content_item_id_test.dart` | SOUND | t1-feat-sync | Focused live-shape regression; real Drift store; clear pass/fail signal. |
| `learning_tracker/test/sync/merge/bookmarks_roundtrip_test.dart` | SOUND | t1-feat-sync | Codec/merger/legacy-fallback round-trip verified against real DB. |
| `learning_tracker/test/sync/merge/completions_roundtrip_test.dart` | SOUND | t1-feat-sync | Thorough codec-key coverage incl. dedup, track_id, prior_mark_only. |
| `learning_tracker/test/sync/merge/curriculum_tracks_roundtrip_test.dart` | ISSUES | t1-feat-sync | Good LWW coverage; TrackConfigMerger duplicated in test/core/sync/merge/mergers_test.dart. |
| `learning_tracker/test/sync/merge/gamification_reward_merge_test.dart` | SOUND | t1-feat-sync | Callback-wiring regression correctly exercised with real merger+store. |
| `learning_tracker/test/sync/merge/goals_roundtrip_test.dart` | SOUND | t1-feat-sync | Pace/date fields and LWW skip verified against real DB round-trip. |
| `learning_tracker/test/sync/merge/learner_profile_roundtrip_test.dart` | ISSUES | t1-feat-sync | Solid; LearnerProfileMerger duplicated in test/core/sync/merge/mergers_test.dart. |
| `learning_tracker/test/sync/merge/learning_ledger_roundtrip_test.dart` | ISSUES | t1-feat-sync | Solid; duplicates test/core/sync/merge/learning_ledger_merger_test.dart's C1 coverage. |
| `learning_tracker/test/sync/merge/learning_order_roundtrip_test.dart` | SOUND | t1-feat-sync | Bulk insert + LWW-skip verified; no issues. |
| `learning_tracker/test/sync/merge/lww_symmetric_test.dart` | ISSUES | t1-feat-sync | 1237 lines (AG-3); overlaps test/core/sync merger suites; doc drift revealed. |
| `learning_tracker/test/sync/merge/persist_updated_at_test.dart` | ISSUES | t1-feat-sync | Correct per-merger persistence checks; duplicates test/core/sync coverage for 3+ mergers. |
| `learning_tracker/test/sync/merge/profile_program_roundtrip_test.dart` | SOUND | t1-feat-sync | R3-6 key-scoping regression well covered; legacy fallback tested. |
| `learning_tracker/test/sync/merge/stage_definitions_roundtrip_test.dart` | ISSUES | t1-feat-sync | Solid schedule-shape coverage; overlaps codecs_and_mergers_test.dart. |
| `learning_tracker/test/sync/merge/streak_events_roundtrip_test.dart` | ISSUES | t1-feat-sync | Solid; duplicates test/core/sync/merge/streak_event_merger_test.dart's C2 coverage. |
| `learning_tracker/test/sync/merge/study_day_config_roundtrip_test.dart` | SOUND | t1-feat-sync | Bulk 7-day + wrong-profileId rejection both verified. |
| `learning_tracker/test/sync/new_listener_coverage_test.dart` | ISSUES | t1-feat-sync | Hand-duplicates private _channelToKind switch instead of testing the real one. |
| `learning_tracker/test/sync/pull_identity_mismatch_guard_test.dart` | SOUND | t1-feat-sync | Exploding-gateway fake proves pull is skipped on identity mismatch. |
| `learning_tracker/test/sync/sacred_time_all_profiles_test.dart` | ISSUES | t1-feat-sync | Correct; overlaps codecs_and_mergers_test.dart's sacred_time-clobber coverage. |
| `learning_tracker/test/sync/stage_definition_single_path_test.dart` | ISSUES | t1-feat-sync | Wall-clock SystemLocalDayClock (TQ-6); doc-id/kind-routing assertions otherwise correct. |
| `learning_tracker/test/sync/study_day_config_sync_test.dart` | ISSUES | t1-feat-sync | 409 lines (AG-3); LWW and Bug-3 track-remap merge coverage is thorough. |
| `learning_tracker/test/sync/sy3_sync_error_message_sanitize_test.dart` | SOUND | t1-feat-sync | Checked SY-3 sanitized-message assertions and fakes; deterministic, no leaks. |
| `learning_tracker/test/sync/sync_orchestrator_connectivity_test.dart` | SOUND | t1-feat-sync | Checked debounce/seed/dispose transitions; deterministic fake timers, no findings. |
| `learning_tracker/test/sync/sync_orchestrator_drain_triggers_test.dart` | ISSUES | t1-feat-sync | 514 lines (AG-3); five drain-trigger scenarios otherwise correctly isolated. |
| `learning_tracker/test/sync/sync_orchestrator_profile0_status_test.dart` | SOUND | t1-feat-sync | Checked D13 profile-0 outbox sweep; concise, deterministic, Fake-based, clean. |
| `learning_tracker/test/sync/sync_rework_curriculum_completion_doc_id_test.dart` | ISSUES | t1-feat-sync | 662 lines (AG-3); duplicates _StubAuthRepository verbatim from sync_rework_push_test.dart. |
| `learning_tracker/test/sync/sync_rework_engine_test.dart` | ISSUES | t1-feat-sync | All 5 groups are skip-only placeholders for deleted SyncEngine; zero assertions. |
| `learning_tracker/test/sync/sync_rework_orchestrator_test.dart` | ISSUES | t1-feat-sync | 642 lines (AG-3); ~240-line boilerplate FirestoreGateway stub duplicated batch-wide. |
| `learning_tracker/test/sync/sync_rework_profile_programs_pull_test.dart` | ISSUES | t1-feat-sync | 405 lines (AG-3); ~250-line boilerplate FirestoreGateway stub duplicated batch-wide. |
| `learning_tracker/test/sync/sync_rework_push_test.dart` | ISSUES | t1-feat-sync | 455 lines (AG-3); duplicates _StubAuthRepository verbatim from doc-id test file. |
| `learning_tracker/test/sync/sync_rework_writepath_test.dart` | SOUND | t1-feat-sync | Checked S1-S3 transaction-count/rollback/dedup invariants via real txn counter; clean. |
| `learning_tracker/test/sync/sync_status_emission_test.dart` | ISSUES | t1-feat-sync | One test has zero expect() calls (vacuous); also 672 lines (AG-3). |
| `learning_tracker/test/sync/tutored_listener_supervisor_test.dart` | ISSUES | t1-feat-sync | DateTime.now() filler in 3 spots (TQ-6 nit); isolation/lifecycle coverage otherwise clean. |
| `learning_tracker/test/sync/tutored_mirror_projection_inputs_test.dart` | SOUND | t1-feat-sync | Checked Bug-3 remap across 4 mergers, deterministic; revealed cross-merger duplication (see finding). |
| `learning_tracker/test/sync/tutored_mirror_wipe_test.dart` | ISSUES | t1-feat-sync | 858 lines (AG-3); _RevokedGateway/_ErrorGateway are ~95% duplicate boilerplate (diffed). |
| `learning_tracker/test/sync/tutored_pull_isolation_test.dart` | ISSUES | t1-feat-sync | 767 lines (AG-3); duplicated gateway/pipeline stubs; 2 raw DateTime.now() calls. |
| `learning_tracker/test/sync/tutored_wipe_wrong_id_test.dart` | ISSUES | t1-feat-sync | Regression-tests wipeRevokedMirrors/resolveOwnerAccountIdForWipe — both uncalled in production; real path untested. |
| `learning_tracker/test/sync/two_device_sync_test.dart` | ISSUES | t1-feat-sync | Hand-simulates pull bypassing MergeRouter; duplicates test/integration twin; missing Drift multi-db flag. |
| `learning_tracker/test/sync/write_tee_status_update_test.dart` | ISSUES | t1-feat-sync | Tests recordDrainAttempt() directly; never exercises the onEnqueueDrain wiring the bug lived in. |
| `learning_tracker/test/tool/android_manifest_deep_links_test.dart` | SOUND | t1-test-cross | Text-based manifest assertions correctly scoped to the intent-filter block. |
| `learning_tracker/test/tool/audit_and_arb_parity_test.dart` | SOUND | t1-test-cross | Shells real make/dart processes; asserts real stdout/exit codes, not mocked. |
| `learning_tracker/test/tool/build_cities_db_admin1_test.dart` | SOUND | t1-test-cross | Synthetic fixtures + real subprocess; asserts resolved region names precisely. |
| `learning_tracker/test/tool/schema_check_test.dart` | SOUND | t1-test-cross | Fixture Dart tables + real subprocess; asserts exit codes/remediation text. |
| `learning_tracker/test/track_setup/clear_overdue_button_test.dart` | ISSUES | t1-feat-tracks | AG-5 unmirrored dir, 650 lines; push test (E) mocks the wrong collaborator. |
| `learning_tracker/test/track_setup/mandatory_pace_test.dart` | ISSUES | t1-feat-tracks | Content verified correct against goal_helpers.dart; AG-5 unmirrored directory only. |
| `learning_tracker/test/widget/step_overflow_test.dart` | SOUND | t1-test-cross | Deterministic viewport override with addTearDown(reset); asserts no overflow exception. |

## Tier 2 — Config / CI / tooling (184 files)

| File | Verdict | Batch | Note |
|---|---|---|---|
| `.firebaserc` | SOUND | t2-build-ci-guardrails | Correct default project id; pairs with a broken root firebase.json (see finding). |
| `.gitattributes` | ISSUES | t2-build-ci-guardrails | merge=beads driver targets a gitignored, never-tracked path; entirely inert. |
| `.github/workflows/build.yml` | SOUND | t2-build-ci-guardrails | Manual APK builder; secrets cleaned up on all paths (if: always()); no bypass flags. |
| `.github/workflows/ci.yml` | ISSUES | t2-build-ci-guardrails | Stale 50%-vs-60% coverage comment; duplicated bootstrap steps; other soft-skips baselined. |
| `.github/workflows/deploy-play-store.yml` | ISSUES | t2-build-ci-guardrails | No dependency on ci.yml passing before shipping to Play Store production. |
| `.gitignore` | SOUND | t2-build-ci-guardrails | Root-scope ignores correct; generated-file patterns live in nested learning_tracker/.gitignore. |
| `CLAUDE.md` | SOUND | t2-build-ci-guardrails | 18 lines, within AG-2 bound; all 5 linked docs verified to exist. |
| `Makefile` | DEFECTIVE | t2-build-ci-guardrails | Dead schema-check gate, swallowed custom_lint exit code, weaker analyze/test, divergent arb-parity. |
| `coding-standards.md` | ISSUES | t2-build-ci-guardrails | Confirmed stale duplicate of docs/coding-standards.md (already captured); no new defects. |
| `docs/firestore-collection-layout.md` | ISSUES | t2-firebase-rules-functions | Stale vs current rules: wrong index count, missing tutor subsystem, superseded collections. |
| `docs/stories/implementation/DNI-384-firestore-rules-and-offline-flush.md` | POINT-IN-TIME | t2-firebase-rules-functions | Story-27.8 implementation record; its now-superseded references are expected for a dated snapshot. |
| `firebase.json` | ISSUES | t2-build-ci-guardrails | References firestore.rules/firestore.indexes.json that don't exist at repo root. |
| `hooks/README.md` | ISSUES | t2-lints-hooks | CI claim checked true; install is manual-only, no automated wiring (F6). |
| `hooks/pre-commit` | ISSUES | t2-lints-hooks | Hardcodes format/analyze instead of make targets; never auto-installed (F5/F6). |
| `learning_tracker/.gitignore` | SOUND | t2-build-ci-guardrails | *.g.dart/*.freezed.dart/*.gr.dart/build/ patterns present and correctly scoped. |
| `learning_tracker/.metadata` | SOUND | t2-build-ci-guardrails | Flutter-tool-managed housekeeping file; unedited, no anomalies. |
| `learning_tracker/CLAUDE.md` | ISSUES | t2-build-ci-guardrails | False custom-lint "Enforced by" claims; cites a Makefile target that doesn't exist. |
| `learning_tracker/Makefile` | ISSUES | t2-build-ci-guardrails | Dead TODO/FIXME grep, mislabeled check counters, hardcoded personal path in emit-fixtures. |
| `learning_tracker/README.md` | ISSUES | t2-build-ci-guardrails | "Key Targets" table cites 3 make commands that don't exist in the Makefile. |
| `learning_tracker/analysis_options.yaml` | SOUND | t2-build-ci-guardrails | custom_lint omission correctly explained; hand-rolled lint list is a known judgment call. |
| `learning_tracker/android/.gitignore` | ISSUES | t2-platform-config | gradle-wrapper.jar wrongly gitignored/untracked; rest matches standard Flutter ignores. |
| `learning_tracker/android/app/build.gradle.kts` | ISSUES | t2-platform-config | Release signingConfig silently falls back to debug keystore when key.properties missing. |
| `learning_tracker/android/app/src/debug/AndroidManifest.xml` | SOUND | t2-platform-config | Checked: single dev-only INTERNET permission, matches vanilla Flutter debug manifest. |
| `learning_tracker/android/app/src/main/AndroidManifest.xml` | ISSUES | t2-platform-config | Permissions/receivers correct; both autoVerify deep-link intent-filters are unverifiable. |
| `learning_tracker/android/app/src/main/kotlin/com/jcom/torah/learning_tracker/MainActivity.kt` | SOUND | t2-platform-config | Checked: vanilla FlutterActivity subclass, no custom platform-channel code. |
| `learning_tracker/android/app/src/main/res/drawable-v21/launch_background.xml` | SOUND | t2-platform-config | Checked: identical to drawable/ variant, standard flutter_native_splash output. |
| `learning_tracker/android/app/src/main/res/drawable/launch_background.xml` | SOUND | t2-platform-config | Checked: matches v21 variant and pubspec flutter_native_splash config. |
| `learning_tracker/android/app/src/main/res/values-night-v31/styles.xml` | SOUND | t2-platform-config | Checked: splash colors match pubspec flutter_native_splash android_12 config exactly. |
| `learning_tracker/android/app/src/main/res/values-night/styles.xml` | SOUND | t2-platform-config | Checked: dark theme parent + launch_background ref consistent with light variant. |
| `learning_tracker/android/app/src/main/res/values-v31/styles.xml` | SOUND | t2-platform-config | Checked: matches pubspec flutter_native_splash android_12 color/icon config exactly. |
| `learning_tracker/android/app/src/main/res/values/colors.xml` | ISSUES | t2-platform-config | heritage_navy color resource defined but unused anywhere in android/. |
| `learning_tracker/android/app/src/main/res/values/styles.xml` | SOUND | t2-platform-config | Checked: light theme, windowBackground + splash items consistent with other variants. |
| `learning_tracker/android/app/src/profile/AndroidManifest.xml` | SOUND | t2-platform-config | Checked: identical to debug variant, standard Flutter profile-build manifest. |
| `learning_tracker/android/build.gradle.kts` | SOUND | t2-platform-config | Checked: standard build-dir redirection + repositories, matches vanilla template. |
| `learning_tracker/android/build/reports/problems/problems-report.html` | ISSUES | t2-platform-config | Tracked Gradle build-output artifact; baselined orchestrator hygiene finding, not re-filed. |
| `learning_tracker/android/gradle.properties` | SOUND | t2-platform-config | Checked: 8G jvmargs generous but plausible for Firebase-heavy build; no other issues. |
| `learning_tracker/android/gradle/wrapper/gradle-wrapper.properties` | ISSUES | t2-platform-config | Missing distributionSha256Sum — unpinned wrapper download integrity. |
| `learning_tracker/android/settings.gradle.kts` | SOUND | t2-platform-config | Checked: plugin version pins consistent with app/build.gradle.kts, no drift. |
| `learning_tracker/build.yaml` | SOUND | t2-build-ci-guardrails | Codegen builders (drift/auto_route/freezed/riverpod/json_serializable) match pubspec generators used. |
| `learning_tracker/dart_test.yaml` | ISSUES | t2-build-ci-guardrails | 295 of ~400 tags actually used in test/ are undeclared; registry is stale. |
| `learning_tracker/firebase.json` | SOUND | t2-build-ci-guardrails | Internally consistent, correctly paired with the real firestore.rules; port gap baselined. |
| `learning_tracker/firestore.indexes.json` | SOUND | t2-firebase-rules-functions | 6 tutor_grants composite indexes checked against index.ts queries; shapes match observed usage. |
| `learning_tracker/firestore.rules` | DEFECTIVE | t2-firebase-rules-functions | Append-only collections mutable/unvalidated (SR-1/3), hasOnly() lacks type/size checks (SR-2/4). |
| `learning_tracker/functions/.gitignore` | SOUND | t2-firebase-rules-functions | Correctly ignores build output (lib/) and node_modules/, matching package.json's main field. |
| `learning_tracker/functions/package.json` | ISSUES | t2-firebase-rules-functions | No `test` script; nothing gives cf_*.test.mjs an automated/CI-reachable entry point. |
| `learning_tracker/functions/src/index.ts` | DEFECTIVE | t2-firebase-rules-functions | P0 unverified-email invite bypass; unwhitelisted tutor writes; a race; an orphaned index; weak audit log. |
| `learning_tracker/functions/test/_cf_helpers.mjs` | ISSUES | t2-firebase-rules-functions | seedActiveGrant stores child_profile_id as a number; every production writer uses a string. |
| `learning_tracker/functions/test/cf_deletes.test.mjs` | SOUND | t2-firebase-rules-functions | Real-handler tests for 3 delete CFs; meaningful assertions incl. idempotency and recursive-delete depth. |
| `learning_tracker/functions/test/cf_grant_invite.test.mjs` | ISSUES | t2-firebase-rules-functions | Self-documents the untested emailVerified/token security gate this audit flags as P0. |
| `learning_tracker/functions/test/cf_grant_revoke.test.mjs` | ISSUES | t2-firebase-rules-functions | listTutorGrants outgoing-mode 'happy path' assertion weakened to a near-tautology. |
| `learning_tracker/functions/test/cf_triggers.test.mjs` | ISSUES | t2-firebase-rules-functions | onUserDeleted Step-2 test never asserts tutor_active_access cleanup, unlike the symmetric Step-3 test. |
| `learning_tracker/functions/test/cf_tutor_completions.test.mjs` | ISSUES | t2-firebase-rules-functions | Header claims tutorBulkPriorCompletions coverage the file doesn't contain; those tests live elsewhere. |
| `learning_tracker/functions/test/cf_tutor_content.test.mjs` | SOUND | t2-firebase-rules-functions | 6 CRUD CFs: thorough auth/arg/grant/permission/happy-path coverage; no size/whitelist probing. |
| `learning_tracker/functions/test/cf_tutor_goals_tracks.test.mjs` | SOUND | t2-firebase-rules-functions | 4 CRUD CFs thoroughly covered incl. audit-log assertions; no malicious-payload cases tried. |
| `learning_tracker/functions/test/cf_tutor_settings_profile.test.mjs` | SOUND | t2-firebase-rules-functions | Covers gamification/profile/bulk-completions incl. length caps for tutorEditProfile; NaN-points untested. |
| `learning_tracker/functions/test/firestore_rules.test.mjs` | ISSUES | t2-firebase-rules-functions | 887-line canonical suite; SR-1/2/3/4/5 pending-hardening tests absent, oracle gaps, one weak assertion. |
| `learning_tracker/functions/test/fixtures/write_payloads.json` | ISSUES | t2-firebase-rules-functions | 'Single source of truth' fixture omits points_ledger and reward_redemptions payloads. |
| `learning_tracker/functions/tsconfig.json` | SOUND | t2-firebase-rules-functions | Standard CF tsconfig; rootDir/outDir match package.json build script; no duplicate tsconfig drift. |
| `learning_tracker/integration_test/.gitkeep` | ISSUES | t2-build-ci-guardrails | Vestigial — directory already holds a real tracked file (app_test.dart). |
| `learning_tracker/integration_test/app_test.dart` | ISSUES | t2-build-ci-guardrails | TODO comment carries no Linear DNI id (AG-6); only test file, otherwise fine. |
| `learning_tracker/ios/.gitignore` | SOUND | t2-platform-config | Checked: standard Flutter iOS ignores; GoogleService-Info.plist correctly excluded. |
| `learning_tracker/ios/Flutter/AppFrameworkInfo.plist` | SOUND | t2-platform-config | Checked: generic Flutter engine framework plist, version fields are boilerplate. |
| `learning_tracker/ios/Flutter/Debug.xcconfig` | SOUND | t2-platform-config | Checked: single include of Generated.xcconfig, matches documented pre-CocoaPods state. |
| `learning_tracker/ios/Flutter/Release.xcconfig` | SOUND | t2-platform-config | Checked: same as Debug.xcconfig; no-CocoaPods gap is documented, not novel. |
| `learning_tracker/ios/Runner.xcodeproj/project.pbxproj` | ISSUES | t2-platform-config | Invalid ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS in Debug/Release; no-Podfile gap already documented. |
| `learning_tracker/ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata` | SOUND | t2-platform-config | Checked: self-references Runner.xcodeproj only, consistent with no CocoaPods. |
| `learning_tracker/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist` | SOUND | t2-platform-config | Checked: harmless Xcode IDE metadata, identical to Runner.xcworkspace copy. |
| `learning_tracker/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings` | SOUND | t2-platform-config | Checked: PreviewsEnabled=false, harmless Xcode workspace setting. |
| `learning_tracker/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` | SOUND | t2-platform-config | Checked: scheme references valid Runner/RunnerTests targets, standard actions. |
| `learning_tracker/ios/Runner.xcworkspace/contents.xcworkspacedata` | SOUND | t2-platform-config | Checked: references group:Runner.xcodeproj only, consistent with no Pods.xcodeproj. |
| `learning_tracker/ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist` | SOUND | t2-platform-config | Checked: identical duplicate of project.xcworkspace copy, harmless. |
| `learning_tracker/ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings` | SOUND | t2-platform-config | Checked: identical duplicate of project.xcworkspace copy, harmless. |
| `learning_tracker/ios/Runner/AppDelegate.swift` | SOUND | t2-platform-config | Checked: standard FirebaseApp.configure() + notification delegate + plugin registration. |
| `learning_tracker/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` | SOUND | t2-platform-config | Checked: flutter_launcher_icons-generated icon manifest, standard legacy format. |
| `learning_tracker/ios/Runner/Assets.xcassets/LaunchBackground.imageset/Contents.json` | SOUND | t2-platform-config | Checked: standard template, background.png referenced at 1x scale only. |
| `learning_tracker/ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json` | SOUND | t2-platform-config | Checked: vanilla flutter create template, superseded by native-splash, harmless. |
| `learning_tracker/ios/Runner/Base.lproj/LaunchScreen.storyboard` | SOUND | t2-platform-config | Checked LaunchImage/LaunchBackground assets exist and Info.plist key matches; sound. |
| `learning_tracker/ios/Runner/Base.lproj/Main.storyboard` | SOUND | t2-platform-config | Default unmodified Flutter template; matches Info.plist Main-storyboard/scene keys. |
| `learning_tracker/ios/Runner/Info.plist` | ISSUES | t2-platform-config | UIBackgroundModes fetch/remote-notification unused (no handler/FCM); location string verified accurate. |
| `learning_tracker/ios/Runner/Runner-Bridging-Header.h` | SOUND | t2-platform-config | Standard 1-line GeneratedPluginRegistrant import; correctly wired, no issues. |
| `learning_tracker/ios/Runner/SceneDelegate.swift` | SOUND | t2-platform-config | Empty FlutterSceneDelegate subclass matches Info.plist scene-delegate class name. |
| `learning_tracker/ios/RunnerTests/RunnerTests.swift` | SOUND | t2-platform-config | Default XCTest stub, unwired from CI; outside Dart TQ rules' scope. |
| `learning_tracker/l10n.yaml` | SOUND | t2-build-ci-guardrails | Minimal config; arb-dir/paths verified to match actual ARB file locations. |
| `learning_tracker/pubspec.yaml` | SOUND | t2-build-ci-guardrails | mockito is override-only transitive pin, unused directly; no ads SDK (PV-4 clean). |
| `learning_tracker/tool/arb_parity_check.dart` | SOUND | t2-app-tool | Clean parity checker; matches Makefile/CI usage, correct exit codes. |
| `learning_tracker/tool/argon2id_benchmark.dart` | ISSUES | t2-app-tool | Stale password_hasher.dart path printed (says features/auth, actual is features/account). |
| `learning_tracker/tool/audit_seed.py` | SOUND | t2-app-tool | Dev-only seed audit script; checked subprocess use, excepts, no secrets. |
| `learning_tracker/tool/build_cities_db.dart` | SOUND | t2-app-tool | GeoNames CSV-to-sqlite builder; has covering test build_cities_db_admin1_test.dart. |
| `learning_tracker/tool/curate_curricula/README.md` | ISSUES | t2-app-tool | Status table stale: 13/14 rows say TODO though main.py implements all. |
| `learning_tracker/tool/curate_curricula/main.py` | ISSUES | t2-app-tool | TOC category-walk loop duplicated 3x (twice in-file, once in audit_seed.py). |
| `learning_tracker/tool/curate_curricula/sefaria_settings.py` | ISSUES | t2-app-tool | Vestigial placeholder, never imported, contradicts README's actual setup steps. |
| `learning_tracker/tool/emit_fixture_payloads.dart` | SOUND | t2-app-tool | Checked each fixture against its codec / LocalDataUploadService push shape. |
| `learning_tracker/tool/hebcal_fetch/main.mjs` | SOUND | t2-app-tool | Checked date-range loop, category mapping, deterministic key ordering. |
| `learning_tracker/tool/hebcal_fetch/package.json` | SOUND | t2-app-tool | Minimal manifest, pinned deps, matches main.mjs usage. |
| `learning_tracker/tool/lib/dio_client.dart` | ISSUES | t2-app-tool | Raw Talker import; outside make audit's lib/-only Rule 3/4 scan scope. |
| `learning_tracker/tool/lib/sefaria/bavli_fetcher.dart` | ISSUES | t2-app-tool | Duplicates _sederHebrewName map also in mishna_fetcher.dart, not shared via base. |
| `learning_tracker/tool/lib/sefaria/chumash_fetcher.dart` | ISSUES | t2-app-tool | Duplicates _torahTitles list also present in nach_fetcher.dart. |
| `learning_tracker/tool/lib/sefaria/mishna_berurah_fetcher.dart` | SOUND | t2-app-tool | Checked seif-katan distribution math and item shape; no issues found. |
| `learning_tracker/tool/lib/sefaria/mishna_fetcher.dart` | ISSUES | t2-app-tool | Duplicates _sederHebrewName map also present in bavli_fetcher.dart. |
| `learning_tracker/tool/lib/sefaria/mussar_fetcher.dart` | SOUND | t2-app-tool | Checked complex/simple text branching and leaf emission; no issues. |
| `learning_tracker/tool/lib/sefaria/nach_fetcher.dart` | ISSUES | t2-app-tool | Duplicates _torahTitles list also present in chumash_fetcher.dart. |
| `learning_tracker/tool/lib/sefaria/sefaria_fetcher_base.dart` | SOUND | t2-app-tool | Checked typed catch/rethrow on every Dio call site; no swallowed errors. |
| `learning_tracker/tool/lib/sefaria/yerushalmi_fetcher.dart` | SOUND | t2-app-tool | Checked chapter/halacha segment-count parsing and zero-segment skip logic. |
| `learning_tracker/tool/lib/sequences/halakhah_yomit_seq.dart` | ISSUES | t2-app-tool | AG-3: 1619-line hand-written Dart file, not a generated file. |
| `learning_tracker/tool/prepare_asset.dart` | SOUND | t2-app-tool | Checked xz/gzip pipeline and exit codes; matches CI/Makefile usage. |
| `learning_tracker/tool/run2_test_sweep.workflow.js` | ISSUES | t2-app-tool | Completed-round device-test script; no stated tool/ retention policy. |
| `learning_tracker/tool/run2_tutoring_gamification.workflow.js` | ISSUES | t2-app-tool | Same: completed-round script, no retention policy. |
| `learning_tracker/tool/run2_tutoring_retest.workflow.js` | ISSUES | t2-app-tool | Same: completed-round script, no retention policy. |
| `learning_tracker/tool/run3_cycle3_single.workflow.js` | ISSUES | t2-app-tool | Same: completed-round script, no retention policy. |
| `learning_tracker/tool/run3_test_cycle.workflow.js` | ISSUES | t2-app-tool | Same: completed-round script, no retention policy. |
| `learning_tracker/tool/run3_tutor_extensive.workflow.js` | ISSUES | t2-app-tool | App Check curl uses operator's own gcloud token, not a secret; retention. |
| `learning_tracker/tool/seed/build_daily_content.dart` | SOUND | t2-app-tool | Checked ref-resolution regexes and external-fallback logic; no issues found. |
| `learning_tracker/tool/seed/build_text_cache.dart` | SOUND | t2-app-tool | Checked manifest loading and sample-mode output path branch; no issues. |
| `learning_tracker/tool/seed/docker-compose.yml` | SOUND | t2-app-tool | Localhost-only port bind, read-only dump mount; no-auth is appropriate locally. |
| `learning_tracker/tool/seed/lib/sefaria_mongo.dart` | ISSUES | t2-app-tool | 542 lines (AG-3); complex ref/address-parsing engine has zero automated tests |
| `learning_tracker/tool/seed/sample_validate.dart` | SOUND | t2-app-tool | Checked: prints 9 sample refs for manual eyeball review; small, correct, no bugs |
| `learning_tracker/tool/seed_content.dart` | ISSUES | t2-app-tool | Dead: live-Sefaria-API fetcher for canceled Story 15.13 pipeline (see F1) |
| `learning_tracker/tool/seed_content_db.dart` | ISSUES | t2-app-tool | 809 lines (AG-3); xz-failure stderr printed as undecoded bytes; pipeline otherwise sound |
| `learning_tracker/tool/seed_text_content.dart` | ISSUES | t2-app-tool | Dead (F1), output unconsumed by anything; 2 log-less catch(_) swallow fetch errors |
| `learning_tracker/tool/sefaria_fetch/go.mod` | SOUND | t2-app-tool | Checked: 3-line module decl, module/go-version match main.go; nothing else to review |
| `learning_tracker/tool/sefaria_fetch/main.go` | SOUND | t2-app-tool | Checked: atomic cache writes, backoff+jitter, circuit breakers, signal handling; no bugs, no secrets |
| `learning_tracker/tool/text_extract/README.md` | ISSUES | t2-app-tool | Presents itself as current; docs/seed-build.md calls sibling main.py 'retired' |
| `learning_tracker/tool/text_extract/extract_books.py` | ISSUES | t2-app-tool | Superseded; _clean() drops footnote-strip its sibling/replacement has — corruption risk |
| `learning_tracker/tool/text_extract/main.py` | ISSUES | t2-app-tool | Explicitly called 'retired' in docs/seed-build.md:123; one log-less except at line 78 |
| `learning_tracker/tool/upload_to_firebase.js` | ISSUES | t2-app-tool | Dead (F1): uploads to Storage path nothing in-app reads; no dry-run unlike .sh twin |
| `learning_tracker/tool/upload_to_firebase.sh` | ISSUES | t2-app-tool | Dead (F1), diverged from .js twin; fragile bash-into-python heredoc manifest fallback |
| `learning_tracker/tool/validate_seed_coverage.dart` | ISSUES | t2-app-tool | 401 lines (AG-3); wired into make ci, mirrors build-tool program sources correctly |
| `learning_tracker/tool/verify_local_calendar_e2e.dart` | SOUND | t2-app-tool | Checked: in-memory Drift e2e harness, asserts registry/DAO/engine/service invariants; no bugs |
| `learning_tracker/tool/verify_seed_calendar.dart` | ISSUES | t2-app-tool | Log-less 'on Object' catch swallows live-fetch failures; seeded RNG(42) is good practice |
| `packages/custom_lints/README.md` | ISSUES | t2-lints-hooks | Rule 2/3 paths wrong; documents only 5 of 9 shipped rules (F1a/F1b/F2). |
| `packages/custom_lints/lib/learning_tracker_lints.dart` | ISSUES | t2-lints-hooks | Doc comment says 'eight rules'; registers and lists nine (F2). |
| `packages/custom_lints/lib/src/rules/no_color_literal_outside_theme.dart` | SOUND | t2-lints-hooks | Read in full; whitelist + hex-literal detection correct, matches own doc. |
| `packages/custom_lints/lib/src/rules/no_curriculum_display_name_bypass.dart` | SOUND | t2-lints-hooks | Read in full; matches coding-standards Rule 5 exactly, node coverage correct. |
| `packages/custom_lints/lib/src/rules/no_e_to_string_in_ui.dart` | ISSUES | t2-lints-hooks | Logic is reasonable but zero test coverage, never run anywhere (F3/F8). |
| `packages/custom_lints/lib/src/rules/no_feature_cross_import.dart` | ISSUES | t2-lints-hooks | _isBarrel checks `<feature>.dart`, contradicting documented `providers.dart` (F1a). |
| `packages/custom_lints/lib/src/rules/no_firebase_outside_core.dart` | ISSUES | t2-lints-hooks | 2-dir whitelist misses features/auth/ and firebase_providers.dart (F1b). |
| `packages/custom_lints/lib/src/rules/no_hardcoded_domain_term.dart` | SOUND | t2-lints-hooks | Read in full; exemptions, whole-word matching, UI-context detection correct. |
| `packages/custom_lints/lib/src/rules/no_hardcoded_text_direction.dart` | SOUND | t2-lints-hooks | Read in full, matches AX-1 table; broader than its Makefile backstop (F9). |
| `packages/custom_lints/lib/src/rules/no_raw_logevent.dart` | ISSUES | t2-lints-hooks | Filename-only whitelist match, not dir-anchored; zero tests (F3/F7/F8). |
| `packages/custom_lints/lib/src/rules/no_raw_talker.dart` | SOUND | t2-lints-hooks | Read in full; matches coding-standards Rule 4 exactly, dir-anchored whitelist. |
| `packages/custom_lints/pubspec.yaml` | SOUND | t2-lints-hooks | analyzer ^8/custom_lint_builder ^0.8.1 pin; the 8-vs-9 break is baselined. |
| `packages/custom_lints/test/no_color_literal_outside_theme_test.dart` | ISSUES | t2-lints-hooks | Duplicates private _isWhitelisted; suite never runs in CI (F4/F8). |
| `packages/custom_lints/test/no_curriculum_display_name_bypass_test.dart` | ISSUES | t2-lints-hooks | Duplicates private _isWhitelisted; suite never runs in CI (F4/F8). |
| `packages/custom_lints/test/no_feature_cross_import_test.dart` | ISSUES | t2-lints-hooks | Encodes the providers.dart divergence; duplicates 2 helpers; never runs (F1a/F4/F8). |
| `packages/custom_lints/test/no_firebase_outside_core_test.dart` | ISSUES | t2-lints-hooks | Duplicates private _isWhitelisted; no features/auth/ coverage; never runs (F1b/F4/F8). |
| `packages/custom_lints/test/no_hardcoded_domain_term_test.dart` | ISSUES | t2-lints-hooks | Well-written, no duplication, but suite never runs in any CI/make target (F8). |
| `packages/custom_lints/test/no_hardcoded_text_direction_test.dart` | ISSUES | t2-lints-hooks | Duplicates private _isGenerated; suite never runs in CI (F4/F8). |
| `packages/custom_lints/test/no_raw_talker_test.dart` | ISSUES | t2-lints-hooks | Duplicates private _isWhitelisted; suite never runs in CI (F4/F8). |
| `test/firestore-rules/.gitignore` | ISSUES | t2-firebase-rules-functions | Content correct, but part of a dead, doc-contradicted duplicate test suite (see sibling files). |
| `test/firestore-rules/firestore.rules.test.js` | ISSUES | t2-firebase-rules-functions | Dead suite for obsolete top-level schema; unwired from CI; contradicted by 4 live docs. |
| `test/firestore-rules/package.json` | ISSUES | t2-firebase-rules-functions | Duplicate Jest/firebase toolchain backing the dead suite above; zero live test value. |
| `tool/adb-connect-wsl.sh` | ISSUES | t2-root-tool | Site of AVD-name drift (lt_api28_pixel2) vs avd-setup.ps1; hardcoded ADB path. |
| `tool/adb-keepalive.sh` | SOUND | t2-root-tool | Reconnect-loop dev script; fallback device detection and reconnect logic verified correct. |
| `tool/arb_parity_check.dart` | SOUND | t2-root-tool | Rule-0 ARB-parity checker; exit codes and JSON error handling all correct. |
| `tool/avd-setup.ps1` | ISSUES | t2-root-tool | First AVD entry (API24/Nexus5/port5554) drifted from the other 2 launch scripts. |
| `tool/device_e2e/README.md` | SOUND | t2-root-tool | Doc's driver/journey description matches driver.py and journey_01 behavior; scope accurate. |
| `tool/device_e2e/address_deferred.mjs` | SOUND | t2-root-tool | 4-item deferred-fix orchestration; distinct content, workflow/schema reviewed, no defects. |
| `tool/device_e2e/driver.py` | ISSUES | t2-root-tool | Sound uiautomator driver class; hardcoded ADB path diverges from 2 sibling files. |
| `tool/device_e2e/fix_run6_tests.mjs` | SOUND | t2-root-tool | Stale-test-fix orchestration; distinct correct content, no defects found. |
| `tool/device_e2e/fix_tests.mjs` | SOUND | t2-root-tool | 42-test-fix orchestration; distinct correct content, no defects found. |
| `tool/device_e2e/journey_01_signup_profile.py` | ISSUES | t2-root-tool | Real E2E journey against prod Firestore; TEST_UID cleanup promise unfulfilled. |
| `tool/device_e2e/run2_fix.mjs` | SOUND | t2-root-tool | 23-finding fix-wave orchestration; distinct cluster content, no defects found. |
| `tool/device_e2e/run2_full_suite.mjs` | ISSUES | t2-root-tool | Reference copy of a 6-file near-verbatim duplication family; see finding. |
| `tool/device_e2e/run3_fix.mjs` | SOUND | t2-root-tool | 21-finding fix-wave orchestration; distinct cluster content, no defects found. |
| `tool/device_e2e/run3_full_suite.mjs` | ISSUES | t2-root-tool | Byte-diffed vs run2: only run-number/dir/description differ (3 of 256 lines). |
| `tool/device_e2e/run4_fix.mjs` | SOUND | t2-root-tool | 11-finding fix-wave orchestration; distinct cluster content, no defects found. |
| `tool/device_e2e/run4_full_suite.mjs` | ISSUES | t2-root-tool | Byte-diffed vs run2: only run-number/dir/description differ (3 of 256 lines). |
| `tool/device_e2e/run5_fix.mjs` | SOUND | t2-root-tool | 15-finding fix-wave orchestration; distinct cluster content, no defects found. |
| `tool/device_e2e/run5_full_suite.mjs` | ISSUES | t2-root-tool | Byte-diffed vs run2: only run-number/dir/description differ (3 of 256 lines). |
| `tool/device_e2e/run6_fix.mjs` | SOUND | t2-root-tool | 22-finding fix-wave orchestration; distinct cluster content, no defects found. |
| `tool/device_e2e/run6_full_suite.mjs` | ISSUES | t2-root-tool | Byte-diffed vs run2: only run-number/dir/description differ (3 of 256 lines). |
| `tool/device_e2e/run7_full_suite.mjs` | ISSUES | t2-root-tool | Byte-diffed vs run2: only run-number/dir/description differ (3 of 256 lines). |
| `tool/emulators-start.ps1` | ISSUES | t2-root-tool | Well-structured parallel launcher; first AVD name mismatches avd-setup.ps1's matrix. |
| `tool/gen_arch_tables.dart` | SOUND | t2-root-tool | Doc-table generator; snake_case heuristic has an explicit override dict, no bug. |
| `tool/linear-sync.sh` | ISSUES | t2-root-tool | 5 sites concatenate unescaped strings into YAML; embedded quote chars corrupt it. |
| `tool/merge_arb.py` | ISSUES | t2-root-tool | All 4 hardcoded source branches are now deleted from git; script silently no-ops. |
| `tool/r1_fix_wave.js` | SOUND | t2-root-tool | 4-worker R1 fix-wave orchestration; distinct findings/owned files per worker, no defects. |
| `tool/r1v2_fix_wave.js` | SOUND | t2-root-tool | 2-worker R1v2 fix-wave orchestration; distinct findings, red-green tests, no defects. |
| `tool/r2_fix_wave.js` | SOUND | t2-root-tool | 2-worker R2 fix-wave orchestration; distinct findings, no defects found. |
| `tool/r3_fix_wave.js` | SOUND | t2-root-tool | 3-worker R3 fix-wave orchestration; distinct findings, no defects found. |
| `tool/schema_check.dart` | ISSUES | t2-root-tool | Rule-0 profileId-in-PK checker; Goals table exempted, docstring cites closed tickets. |
| `tool/seed_content_db.dart` | DEFECTIVE | t2-root-tool | 242-line fragment: no imports/main/types; dead duplicate, real tool lives elsewhere. |
| `tool/upload_store_assets.py` | ISSUES | t2-root-tool | Sound upload/rollback-on-error flow; screenshot names[] list duplicated verbatim 3x. |
| `tool/vision_find_pass.js` | ISSUES | t2-root-tool | KNOWN block duplicated+truncated; 4 unused ARCHIVED screen arrays (~180 dead lines). |

## Tier 4 — Documentation (239 files)

| File | Verdict | Batch | Note |
|---|---|---|---|
| `CONTRIBUTING.md` | ISSUES | t4-docs-canonical | 18-feature-module count stale (actual 15); setup/workflow instructions verified accurate. |
| `README.md` | ISSUES | t4-docs-canonical | Roadmap lists shipped Epic 23 hard-tier auth as upcoming; setup/links/curricula verified accurate. |
| `V1_OUT_OF_SCOPE.md` | POINT-IN-TIME | t4-docs-canonical | Dated 2026-04-21 audit/recommendation snapshot; not presented as current state. |
| `docs/api-contracts.md` | DEFECTIVE | t4-docs-canonical | Tutor Firestore/Functions surface entirely undocumented; indexes.json claimed empty (has 6). |
| `docs/architecture.md` | DEFECTIVE | t4-docs-canonical | schemaVersion wrong (v14 vs 32); feature-module list and CI job count both stale. |
| `docs/_archive/superseded/bug-fix-plan-2026-05-15.md` | POINT-IN-TIME | t4-docs-canonical | Dated one-time bug-fix plan for a past session; historical artifact. |
| `docs/_archive/superseded/bug-fix-prompt-2026-05-15.md` | POINT-IN-TIME | t4-docs-canonical | Paste-into-session prompt for a past bug-fix run; historical artifact. |
| `docs/_archive/superseded/bug-reports-2026-05-15.md` | POINT-IN-TIME | t4-docs-canonical | Dated manual-test bug reports from one session; historical artifact. |
| `docs/coding-standards.md` | ISSUES | t4-docs-canonical | 22 checks/9 lints/schemaVersion 32/CLAUDE.md sizes all verified correct; lint count (83) and appcheck-doc ref wrong. |
| `docs/component-inventory.md` | DEFECTIVE | t4-docs-canonical | firebaseFirestoreProvider location stale; screen roster majority-mismatched post-rebuild (dated 2026-03-18). |
| `docs/data-models.md` | DEFECTIVE | t4-docs-canonical | Self-contradictory schemaVersion (v4/v15 vs actual 32); describes extinct pre-rebuild schema. |
| `docs/delete-policy.md` | SOUND | t4-docs-canonical | Verified purgeHistory() location and N8 invariant test both match current code. |
| `docs/deployment-guide.md` | DEFECTIVE | t4-docs-canonical | CI job count wrong (8 vs actual 7); indexes.json-empty and golden-path claims stale. |
| `docs/developer-handbook.md` | DEFECTIVE | t4-docs-canonical | schemaVersion badly stale (v4/v3 vs actual 32/5); rest of doc checked, accurate. |
| `docs/development-guide.md` | DEFECTIVE | t4-docs-canonical | Audit-check, ARB-key, and test-file counts all stale (13/468/359 vs 22/1421/770). |
| `docs/_archive/superseded/exec-prompt-2026-05-17.md` | POINT-IN-TIME | t4-docs-canonical | One-shot execution prompt referencing an external plan file; historical artifact. |
| `docs/explainers/content-database.md` | ISSUES | t4-docs-triage | Code-map shows nonexistent content/tables/ dir; tables actually live in shared lib/core/database/tables/. |
| `docs/explainers/data-model.md` | ISSUES | t4-docs-triage | Schema v23 / 22 tables / 13 audit-checks all stale; current code is v32 / 24 tables / 22 checks. |
| `docs/explainers/sync-subsystem.md` | DEFECTIVE | t4-docs-triage | Core narrative (dual-stack SyncEngine, missing learning_order merger, merger count) all now false. |
| `docs/flows/add-track-flow.md` | DEFECTIVE | t4-docs-canonical | File Map paths point at extinct track_setup/ dir; lists nonexistent 'torah' curriculum. |
| `docs/flows/dashboard-redesign-analysis.md` | POINT-IN-TIME | t4-docs-canonical | Self-flags Epic 20 canceled/not-built; verified still accurate, correctly archival. |
| `docs/hebrew-terms.md` | ISSUES | t4-docs-canonical | Well-maintained; one §11 drift item (audit-grep symbol) already fixed but unmarked. |
| `docs/index.md` | ISSUES | t4-docs-canonical | All 30+ linked paths & Makefile targets resolve; DB table-count summary stale (F2). |
| `docs/_archive/superseded/issues-2026-05-17.md` | POINT-IN-TIME | t4-docs-canonical | Dated review capture; I-5 tracked closed in open-items.md; not presented as current. |
| `docs/linear-status.md` | ISSUES | t4-docs-canonical | Epic table checked; Epics 25-27 'all Backlog' contradicted by populated non-skipped tests (F5). |
| `docs/open-items.md` | ISSUES | t4-docs-canonical | C1/C2/C3/I-5 closure claims checked; C1's completions-table detail wrong (F6). |
| `docs/_archive/superseded/overdue-refactor-exec-prompt-2026-05-19.md` | POINT-IN-TIME | t4-docs-canonical | Dated wave-execution script for one historical scheduler refactor run; not current-state doc. |
| `docs/_archive/superseded/perf-findings-2026-05-17.md` | POINT-IN-TIME | t4-docs-canonical | Dated fix-log for specific provider rebuild bugs, described as already applied. |
| `docs/planning/architecture-design.md` | SOUND | t4-docs-triage | Self-aware 2026-04-19 staleness banner checked accurate; no stale DB code samples found. |
| `docs/planning/architecture-offline-v2.md` | ISSUES | t4-docs-triage | "Deliberate tech debt" box stale — the March-era auth symbols it cites are fully removed already. |
| `docs/planning/architecture-quick-reference.md` | DEFECTIVE | t4-docs-triage | Bulk of doc (queries, models) is pre-3-DB-split single-database era; plus a dead link. |
| `docs/_archive/superseded/b1-b11-review-fix-plan.md` | POINT-IN-TIME | t4-docs-triage | Remediation prompt self-marked "complete (2026-05-19)"; historical execution record. |
| `docs/_archive/superseded/bug-hunt-findings-2026-05-31.md` | POINT-IN-TIME | t4-docs-triage | Dated, adversarially-verified bug-hunt report; self-contained historical artifact. |
| `docs/_archive/superseded/bug-hunt-round2-findings-2026-05-31.md` | POINT-IN-TIME | t4-docs-triage | Same series; dated verification report with reachability reasoning per finding. |
| `docs/_archive/superseded/bug-hunt-round3-findings-2026-05-31.md` | POINT-IN-TIME | t4-docs-triage | Dated report; includes a "Rejected" section from adversarial re-verification. |
| `docs/_archive/superseded/bug-hunt-round4-findings-2026-05-31.md` | POINT-IN-TIME | t4-docs-triage | Dated report; fixes and one rejected finding listed, closed-loop artifact. |
| `docs/_archive/superseded/bug-hunt-round5-findings-2026-05-31.md` | POINT-IN-TIME | t4-docs-triage | Dated report; fixes and two rejected findings listed, closed-loop artifact. |
| `docs/_archive/superseded/bug-hunt-round6-findings-2026-05-31.md` | POINT-IN-TIME | t4-docs-triage | Dated report; spot-checked entries read as genuine, closed findings. |
| `docs/planning/calendar-cycle-analysis.md` | SOUND | t4-docs-triage | Verified D-CAL-3 (Nach Yomi->hebcal) and apiKey fixes are implemented in the current registry. |
| `docs/planning/catchup-and-amnesty-scenarios.md` | POINT-IN-TIME | t4-docs-triage | Self-labeled OBSOLETE/superseded 2026-05-19; confirmed zero implementation exists in code. |
| `docs/_archive/superseded/daf-unit-display-scope.md` | ISSUES | t4-docs-triage | Header says "Phase 1 in progress" though body and 5 verified commits show all phases shipped. |
| `docs/planning/e2e-test-suite-plan.md` | ISSUES | t4-docs-triage | "Status: Planning" is stale; the harness and 35 P0-P2 journey test files already exist. |
| `docs/_archive/superseded/entity-model-audit-2026-05-24.md` | POINT-IN-TIME | t4-docs-triage | Explicitly self-labeled "point-in-time against the code on this date". |
| `docs/_archive/superseded/entity-model-remediation-log.md` | POINT-IN-TIME | t4-docs-triage | Append-only execution log; ends COMPLETE plus one resolved post-commit regression. |
| `docs/_archive/superseded/entity-model-remediation-orchestration-prompt.md` | POINT-IN-TIME | t4-docs-triage | One-shot orchestrator kickoff script, no ongoing-currency claims. |
| `docs/_archive/superseded/entity-model-remediation-plan-2026-05-24.md` | POINT-IN-TIME | t4-docs-triage | Dated plan; companion tracker confirms every workstream verified done. |
| `docs/_archive/superseded/entity-model-remediation-tracker.md` | POINT-IN-TIME | t4-docs-triage | All WS1-9 plus gates plus verification phase marked done/verified. |
| `docs/planning/epics-greenfield-rebuild.md` | POINT-IN-TIME | t4-docs-triage | Epics 24-27 breakdown; epics.md confirms every one of these stories shipped Done. |
| `docs/planning/epics.md` | ISSUES | t4-docs-triage | Title says "Epic 19 Breakdown" but content runs through Epic 27, all marked Done. |
| `docs/_archive/superseded/exhaustive-test-and-fix-KICKOFF-PROMPT.md` | POINT-IN-TIME | t4-docs-triage | Reusable one-shot kickoff script; makes no current-state claims of its own. |
| `docs/_archive/superseded/exhaustive-test-and-fix-plan-2026-05-29.md` | POINT-IN-TIME | t4-docs-triage | Dated plan, superseded by the later on-device-exhaustive-test-plan and loop-progress docs. |
| `docs/_archive/superseded/loop-progress.md` | POINT-IN-TIME | t4-docs-triage | Heartbeat log for an autonomous test loop; entries stop 2026-06-15. |
| `docs/_archive/superseded/on-device-exhaustive-test-plan-2026-05-31.md` | POINT-IN-TIME | t4-docs-triage | 4708-line dated test script with an empty defect-log/checklist template; one-time artifact. |
| `docs/planning/on-device-preflight-cheatsheet.md` | DEFECTIVE | t4-docs-triage | GoalSetupScreen "provably-dead, delete" verdict is now contradicted by a live call site. |
| `docs/_archive/superseded/on-device-test-KICKOFF-PROMPT.md` | POINT-IN-TIME | t4-docs-triage | One-shot kickoff script referencing a dated companion plan. |
| `docs/_archive/superseded/outstanding-bugs-handoff-2026-05-31.md` | POINT-IN-TIME | t4-docs-triage | Dated bug list; spot-checked D20 and found its fix present in code (comment cites D20). |
| `docs/planning/overdue-refactor-architecture.md` | ISSUES | t4-docs-triage | Header "Draft - for review" is stale; code comments show the design is substantially implemented. |
| `docs/planning/prd.md` | POINT-IN-TIME | t4-docs-triage | Self-labeled "SUPERSEDED - 2026-04-19 review" banner is accurate; kept as historical original. |
| `docs/_archive/superseded/progress-ia-execution-plan.md` | POINT-IN-TIME | t4-docs-triage | Dated wave plan, superseded same-day by the final report's "Complete" status. |
| `docs/_archive/superseded/progress-ia-final-report.md` | POINT-IN-TIME | t4-docs-triage | "status: Complete", dated 2026-05-20, commit-by-commit historical record. |
| `docs/_archive/superseded/progress-ia-redesign.md` | POINT-IN-TIME | t4-docs-triage | Proposal superseded same-day by the final report showing it shipped. |
| `docs/_archive/superseded/refactor-orchestration-prompt.md` | POINT-IN-TIME | t4-docs-triage | One-shot orchestrator kickoff script for the v3.3 tech-debt remediation plan. |
| `docs/planning/research/technical-firebase-sync-optimization-research-2026-05-18.md` | POINT-IN-TIME | t4-docs-triage | Dated research feeding a specific, since-executed exec prompt; correctly historical. |
| `docs/planning/research/technical-torah-learning-app-competitors-research-2026-03-17.md` | POINT-IN-TIME | t4-docs-triage | Competitor market-snapshot research, inherently time-bound by nature. |
| `docs/_archive/superseded/self-resuming-test-fix-loop-KICKOFF-2026-06-09.md` | POINT-IN-TIME | t4-docs-triage | One-shot orchestrator kickoff script for the self-resuming test loop. |
| `docs/planning/sync-architecture-plan.md` | ISSUES | t4-docs-triage | Current-state audit; outbox-drain headline finding now empirically false, no staleness marker. |
| `docs/planning/tech-debt-remediation-plan.md` | POINT-IN-TIME | t4-docs-triage | Dated wave/stream refactor plan; consistent with shipped hotspot files, no drift found. |
| `docs/planning/test-coverage-matrix.md` | ISSUES | t4-docs-triage | Point-in-time coverage log; ends with leaked stray `</content>` tool-tag. |
| `docs/planning/test-fix-bug-log.md` | ISSUES | t4-docs-triage | Point-in-time bug log; ends with leaked `</content></invoke>` tool-tags. |
| `docs/planning/testing-quick-reference.md` | DEFECTIVE | t4-docs-triage | Teaches banned mockito; cites nonexistent files and a wrong runtime-API architecture. |
| `docs/_archive/superseded/track-detail-and-ordering-plan.md` | POINT-IN-TIME | t4-docs-triage | Dated implementation plan; matches shipped bulk_mark/track_detail screens. |
| `docs/_archive/superseded/tracks-and-completion-bug-report.md` | POINT-IN-TIME | t4-docs-triage | Dated bug report; self-updates its own remediation-status table, all 11 fixed. |
| `docs/_archive/superseded/tracks-and-completion-fix-plan.md` | POINT-IN-TIME | t4-docs-triage | Orchestrator prompt companion to bug report; consistent, no drift found. |
| `docs/_archive/superseded/tutor-edit-propagation-log.md` | POINT-IN-TIME | t4-docs-triage | Append-only orchestration log dated 2026-05-28; internally consistent. |
| `docs/_archive/superseded/tutor-edit-propagation-orchestration-prompt.md` | POINT-IN-TIME | t4-docs-triage | Paste-into-fresh-session kickoff prompt; dated artifact, consistent with plan. |
| `docs/_archive/superseded/tutor-edit-propagation-plan.md` | POINT-IN-TIME | t4-docs-triage | Dated CF-routing plan; matches tracker's completed status. |
| `docs/_archive/superseded/tutor-edit-propagation-tracker.md` | POINT-IN-TIME | t4-docs-triage | Checkbox stream tracker; make ci GREEN recorded, consistent close-out. |
| `docs/_archive/superseded/tutor-mode-brief.md` | POINT-IN-TIME | t4-docs-triage | Draft requirements brief; accurately predicts the shipped tutoring/ feature. |
| `docs/_archive/superseded/tutor-talmid-view-log.md` | POINT-IN-TIME | t4-docs-triage | Append-only orchestration log dated 2026-05-26; internally consistent. |
| `docs/_archive/superseded/tutor-talmid-view-orchestration-prompt.md` | POINT-IN-TIME | t4-docs-triage | Paste-into-fresh-session kickoff prompt; dated artifact, consistent. |
| `docs/_archive/superseded/tutor-talmid-view-plan-2026-05-26.md` | POINT-IN-TIME | t4-docs-triage | Dated design doc; 'current state verified in code' section, superseded by trackers. |
| `docs/_archive/superseded/tutor-talmid-view-tracker.md` | POINT-IN-TIME | t4-docs-triage | Stream tracker; Wave 3 re-scoped inline, later completed per edit-propagation docs. |
| `docs/planning/two-database-architecture.md` | POINT-IN-TIME | t4-docs-triage | Exemplary self-correcting evolution note; defers to current docs. Model example. |
| `docs/_archive/superseded/ux-audit-2026-05-20-copy-review.md` | POINT-IN-TIME | t4-docs-triage | Dated copy audit; companion to fix-plan/hebrew-terms-findings, self-consistent. |
| `docs/_archive/superseded/ux-audit-2026-05-20-fix-plan.md` | POINT-IN-TIME | t4-docs-triage | Draft fix plan, 10 lettered streams; internally consistent, no drift found. |
| `docs/_archive/superseded/ux-audit-2026-05-20-hebrew-terms-findings.md` | POINT-IN-TIME | t4-docs-triage | 14-violation audit; matches fix-plan/copy-review, consistent. |
| `docs/_archive/superseded/ux-audit-2026-05-20-orchestration-prompt.md` | POINT-IN-TIME | t4-docs-triage | Dated orchestration kickoff prompt; consistent with its 3 companion docs. |
| `docs/planning/ux-patterns-quick-reference.md` | ISSUES | t4-docs-triage | Partial staleness note; stale TutorPinGuard reference + dead link to archived doc. |
| `docs/planning/ux-upgrade-flow-spec.md` | ISSUES | t4-docs-triage | Password-verify upgrade UX now stale post credential-less redesign, no marker. |
| `docs/planning/ux-upgrade-flow-visual.md` | ISSUES | t4-docs-triage | W-02 'Confirm password' wireframe stale post credential-less redesign. |
| `docs/_archive/superseded/v1-developer-roadmap.md` | POINT-IN-TIME | t4-docs-triage | Exemplary HISTORICAL banner; defers to linear-status.md/epics.md. Model example. |
| `docs/privacy-policy.md` | DEFECTIVE | t4-docs-canonical | 'Data We Do NOT Collect' contradicted by live FirebaseAnalyticsService + unconditional Crashlytics (F1). |
| `docs/product-rules.md` | ISSUES | t4-docs-canonical | 7 concrete code claims verified accurate; one open item (Q-Term) stale (F7). |
| `docs/project-overview.md` | DEFECTIVE | t4-docs-canonical | Tech-stack/DB/feature/file-count inventory and Project-status table both stale post-rebuild (F2, F3). |
| `docs/project-scan-report.json` | POINT-IN-TIME | t4-docs-canonical | Machine-generated workflow record, self-dated 2026-05-19, explicitly closed ('no resume needed'). |
| `docs/qa/legacy/00-testing-methodology.md` | DEFECTIVE | t4-docs-triage | §9 document index lists 18 filenames that don't exist anywhere in the repo. |
| `docs/qa/legacy/01-product-overview.md` | ISSUES | t4-docs-triage | §8 describes obsolete argon2id local-born password model. |
| `docs/qa/legacy/02-auth-and-accounts.md` | DEFECTIVE | t4-docs-triage | Entire 26-scenario doc built on obsolete password-based local-born signup. |
| `docs/qa/legacy/03-onboarding.md` | ISSUES | t4-docs-triage | OB-03 precondition assumes obsolete local-born password signup. |
| `docs/qa/legacy/04-learning-and-completions.md` | POINT-IN-TIME | t4-docs-triage | 45 completion scenarios; checked invariants + cross-refs, no drift found. |
| `docs/qa/legacy/05-multi-track.md` | ISSUES | t4-docs-triage | TRACK-10 self-service tutor-PIN setup flow is now obsolete. |
| `docs/qa/legacy/06-scheduler-and-goals.md` | POINT-IN-TIME | t4-docs-triage | 42 scheduler scenarios; checked cross-refs, no drift found. |
| `docs/qa/legacy/07-content-browsing.md` | POINT-IN-TIME | t4-docs-triage | 21 scenarios incl. bundled-content note; matches FR6, no drift found. |
| `docs/qa/legacy/08-dashboard-and-progress.md` | POINT-IN-TIME | t4-docs-triage | 45 dashboard scenarios; checked cross-refs, no drift found. |
| `docs/qa/legacy/09-gamification.md` | POINT-IN-TIME | t4-docs-triage | 26 gamification scenarios; checked cross-refs, no drift found. |
| `docs/qa/legacy/10-parent-mode.md` | ISSUES | t4-docs-triage | Cross-ref table repeats obsolete 'tutor mode is read-only' claim. |
| `docs/qa/legacy/11-tutor-mode.md` | DEFECTIVE | t4-docs-triage | Entire doc + its own callout describe obsolete PIN-only, read-only tutor mode. |
| `docs/qa/legacy/12-notifications.md` | POINT-IN-TIME | t4-docs-triage | 30 notification scenarios; checked cross-refs, no drift found. |
| `docs/qa/legacy/13-settings.md` | ISSUES | t4-docs-triage | SET-18/22/23/25-29 assume obsolete local-born password model. |
| `docs/qa/legacy/14-sync-and-offline.md` | ISSUES | t4-docs-triage | seed.db.gz named as bundled APK asset twice; real asset is content.db.gz (confirmed). |
| `docs/qa/legacy/15-profiles.md` | POINT-IN-TIME | t4-docs-triage | self-discloses post-hoc reconstruction status; tells reader to verify against current code. |
| `docs/qa/legacy/16-stages-and-order.md` | SOUND | t4-docs-triage | spot-checked schedule types, 10-stage cap, Learn-protected rule against code; all match. |
| `docs/qa/legacy/17-catchup-and-amnesty.md` | POINT-IN-TIME | t4-docs-triage | self-discloses FORWARD-LOOKING/unimplemented; target Epic 22 since fully Canceled, framing still holds. |
| `docs/qa/legacy/EPIC-PROMPT.md` | POINT-IN-TIME | t4-docs-triage | one-time paste-to-create-epic prompt; resulting Epic 23 already created and Canceled. |
| `docs/qa/legacy/seed-content-db-build-guide.md` | SOUND | t4-docs-triage | build/verify steps and content.db.gz naming cross-checked against tool/*.dart; all match. |
| `docs/scenarios/dashboard-redesign-set/dashboard-redesign/00-scenario-overview.md` | POINT-IN-TIME | t4-docs-triage | explicit banner: Epic 20 canceled 2026-04-15, redesign unshipped; accurate self-disclosure. |
| `docs/scenarios/dashboard-redesign-set/dashboard-redesign/01-dashboard.md` | ISSUES | t4-docs-triage | full ready-to-build spec, no cancellation banner unlike sibling 00 (see finding). |
| `docs/scenarios/dashboard-redesign-set/dashboard-redesign/02-card-program.md` | ISSUES | t4-docs-triage | same missing cancellation-banner gap as 01-dashboard.md. |
| `docs/scenarios/dashboard-redesign-set/dashboard-redesign/03-card-deadline.md` | ISSUES | t4-docs-triage | same missing cancellation-banner gap as 01-dashboard.md. |
| `docs/scenarios/dashboard-redesign-set/dashboard-redesign/04-card-velocity.md` | ISSUES | t4-docs-triage | same missing cancellation-banner gap as 01-dashboard.md. |
| `docs/scenarios/dashboard-redesign-set/dashboard-redesign/05-card-momentum.md` | ISSUES | t4-docs-triage | same missing cancellation-banner gap as 01-dashboard.md. |
| `docs/scenarios/dashboard-redesign-set/dashboard-redesign/06-progress-screen.md` | ISSUES | t4-docs-triage | same missing cancellation-banner gap as 01-dashboard.md. |
| `docs/scenarios/dashboard-redesign-set/dashboard-redesign/07-track-detail.md` | ISSUES | t4-docs-triage | same missing cancellation-banner gap as 01-dashboard.md. |
| `docs/scenarios/evolution/README.md` | ISSUES | t4-docs-triage | top banner correct (OBSOLETE); frontmatter status:backlog + inner text still contradict it. |
| `docs/scenarios/evolution/scenarios/01-catchup-sheet.md` | POINT-IN-TIME | t4-docs-triage | carries correct OBSOLETE/superseded banner; content consistent with disclosure. |
| `docs/scenarios/evolution/scenarios/02-triage-sheet.md` | POINT-IN-TIME | t4-docs-triage | carries correct OBSOLETE/superseded banner; content consistent with disclosure. |
| `docs/scenarios/evolution/scenarios/03-pause-control.md` | POINT-IN-TIME | t4-docs-triage | carries correct OBSOLETE/superseded banner; content consistent with disclosure. |
| `docs/scenarios/evolution/scenarios/04-review-debt-view.md` | POINT-IN-TIME | t4-docs-triage | carries correct OBSOLETE/superseded banner; content consistent with disclosure. |
| `docs/scenarios/evolution/scenarios/05-learning-journey-view.md` | POINT-IN-TIME | t4-docs-triage | carries correct OBSOLETE/superseded banner; content consistent with disclosure. |
| `docs/scenarios/evolution/scenarios/06-amnesty-history.md` | POINT-IN-TIME | t4-docs-triage | carries correct OBSOLETE/superseded banner; content consistent with disclosure. |
| `docs/scenarios/evolution/scenarios/07-setup-seeding-flow.md` | POINT-IN-TIME | t4-docs-triage | carries correct OBSOLETE/superseded banner; content consistent with disclosure. |
| `docs/scenarios/evolution/scenarios/08-returning-learner-onboarding.md` | POINT-IN-TIME | t4-docs-triage | carries correct OBSOLETE/superseded banner; content consistent with disclosure. |
| `docs/scenarios/evolution/scenarios/09-cycle-boundary-welcome.md` | POINT-IN-TIME | t4-docs-triage | carries correct OBSOLETE/superseded banner; content consistent with disclosure. |
| `docs/scenarios/evolution/specs/01-catchup-sheet-spec.md` | POINT-IN-TIME | t4-docs-triage | carries correct OBSOLETE/superseded banner; content consistent with disclosure. |
| `docs/scenarios/evolution/specs/02-triage-sheet-spec.md` | POINT-IN-TIME | t4-docs-triage | carries correct OBSOLETE/superseded banner; content consistent with disclosure. |
| `docs/scenarios/evolution/specs/03-pause-control-spec.md` | POINT-IN-TIME | t4-docs-triage | carries correct OBSOLETE/superseded banner; content consistent with disclosure. |
| `docs/scenarios/evolution/specs/04-review-debt-view-spec.md` | POINT-IN-TIME | t4-docs-triage | carries correct OBSOLETE/superseded banner; content consistent with disclosure. |
| `docs/scenarios/evolution/specs/05-learning-journey-view-spec.md` | POINT-IN-TIME | t4-docs-triage | carries correct OBSOLETE/superseded banner; content consistent with disclosure. |
| `docs/scenarios/evolution/specs/06-amnesty-history-spec.md` | POINT-IN-TIME | t4-docs-triage | carries correct OBSOLETE/superseded banner; content consistent with disclosure. |
| `docs/scenarios/evolution/specs/07-setup-seeding-flow-spec.md` | POINT-IN-TIME | t4-docs-triage | carries correct OBSOLETE/superseded banner; content consistent with disclosure. |
| `docs/scenarios/evolution/specs/08-returning-learner-spec.md` | POINT-IN-TIME | t4-docs-triage | carries correct OBSOLETE/superseded banner; content consistent with disclosure. |
| `docs/scenarios/evolution/specs/09-cycle-boundary-welcome-spec.md` | POINT-IN-TIME | t4-docs-triage | carries correct OBSOLETE/superseded banner; content consistent with disclosure. |
| `docs/scenarios/stitch-prompts/01-sign-in.md` | SOUND | t4-docs-triage | generic auth-form prompt; email/password + Google both real; no drift found. |
| `docs/scenarios/stitch-prompts/02-sign-up.md` | SOUND | t4-docs-triage | generic auth-form prompt; no confirmed drift vs current sign-up capability. |
| `docs/scenarios/stitch-prompts/03-mode-selection.md` | ISSUES | t4-docs-triage | describes Self-Learner/Parent/Tutor mode pick; real onboarding is child/adult per profile. |
| `docs/scenarios/stitch-prompts/04-curriculum-selection.md` | ISSUES | t4-docs-triage | states exactly 5 curricula; CurriculumId enum currently has 9. |
| `docs/scenarios/stitch-prompts/05-goal-setup.md` | SOUND | t4-docs-triage | 2-option deadline/pace structure matches real goalType split; no contradiction found. |
| `docs/scenarios/stitch-prompts/06-dashboard.md` | ISSUES | t4-docs-triage | 5-tab bottom nav (incl. Calendar/Browse); real app_shell.dart has 4 tabs. |
| `docs/scenarios/stitch-prompts/07-daily-tasks.md` | SOUND | t4-docs-triage | generic task-list prompt; no confirmed contradiction found on spot-check. |
| `docs/scenarios/stitch-prompts/08-content-browser.md` | POINT-IN-TIME | t4-docs-triage | Feb-2026 Stitch design-generation prompt; aesthetic spec, not a claim about shipped UI. |
| `docs/scenarios/stitch-prompts/09-learning-screen.md` | POINT-IN-TIME | t4-docs-triage | Same series; historical design-tool input, no currency claim. |
| `docs/scenarios/stitch-prompts/10-mark-completion-bulk.md` | POINT-IN-TIME | t4-docs-triage | Same series; historical design-tool input. |
| `docs/scenarios/stitch-prompts/11-learning-history.md` | POINT-IN-TIME | t4-docs-triage | Same series; historical design-tool input. |
| `docs/scenarios/stitch-prompts/12-progress-charts.md` | POINT-IN-TIME | t4-docs-triage | Same series; historical design-tool input. |
| `docs/scenarios/stitch-prompts/13-parent-dashboard.md` | POINT-IN-TIME | t4-docs-triage | Same series; historical design-tool input. |
| `docs/scenarios/stitch-prompts/14-parent-rewards.md` | POINT-IN-TIME | t4-docs-triage | Same series; historical design-tool input. |
| `docs/scenarios/stitch-prompts/15-tutor-dashboard.md` | POINT-IN-TIME | t4-docs-triage | Same series; historical design-tool input. |
| `docs/scenarios/stitch-prompts/16-settings.md` | POINT-IN-TIME | t4-docs-triage | Same series; historical design-tool input. |
| `docs/scenarios/stitch-prompts/17-stage-editor.md` | POINT-IN-TIME | t4-docs-triage | Same series; historical design-tool input. |
| `docs/scenarios/stitch-prompts/README.md` | POINT-IN-TIME | t4-docs-triage | Self-dated Feb 2026; explicitly redirects readers to component-inventory.md/architecture.md for current state. |
| `docs/seed-build.md` | ISSUES | t4-docs-canonical | Pipeline/prereqs/merger-file claims accurate; bundledSeedVersion off by one, 14 vs 15 (F9). |
| `docs/source-tree-analysis.md` | DEFECTIVE | t4-docs-canonical | DB schema, DAO list, feature list, test-file counts all stale post-rebuild (F2). |
| `docs/_archive/superseded/standards-audit-orchestrator-prompt-2026-07-03.md` | POINT-IN-TIME | t4-docs-canonical | Self-referential prompt for this audit run; not app documentation, nothing to drift-check. |
| `docs/status/bmm-workflow-status.yaml` | POINT-IN-TIME | t4-docs-triage | One-time Jan-2026 BMM planning-gate checklist; gates don't change post-completion. |
| `docs/status/linear-mapping.yaml` | ISSUES | t4-docs-triage | Presents as live sync cache but frozen since 2026-03-12; missing epics 18/19/21/25 (Finding 1). |
| `docs/status/sprint-status.yaml` | DEFECTIVE | t4-docs-triage | Presents as source of truth; epic-18 stale post-cancellation, epic-19 'done' contradicted by own story files (Findings 1+2). |
| `docs/status/wds-workflow-status.yaml` | POINT-IN-TIME | t4-docs-triage | One-time Feb-2026 WDS design-phase checklist, all 7 gates static/complete. |
| `docs/stories/implementation/1-1-initialize-flutter-project-with-architecture-foundations.md` | POINT-IN-TIME | t4-docs-triage | Status ready-for-dev/empty record contradicts yaml 'done'; filename≠tracker slug (Finding 2 evidence). |
| `docs/stories/implementation/16-1-pace-based-goal-mode.md` | POINT-IN-TIME | t4-docs-triage | Status done, full Dev Agent Record+File List, matches sprint-status.yaml exactly. |
| `docs/stories/implementation/18-1-extract-reusable-add-track-flow.md` | POINT-IN-TIME | t4-docs-triage | Accurate as of March 2026; Epic 18 later Canceled per linear-status.md (Finding 1 evidence). |
| `docs/stories/implementation/18-10-add-delete-profile-from-profile-picker.md` | POINT-IN-TIME | t4-docs-triage | Finding 1 evidence (Epic 18 Canceled). |
| `docs/stories/implementation/18-11-fix-edit-profile-button-settings.md` | POINT-IN-TIME | t4-docs-triage | Finding 1 evidence (Epic 18 Canceled). |
| `docs/stories/implementation/18-12-delete-account-redirects-to-welcome.md` | POINT-IN-TIME | t4-docs-triage | Finding 1 evidence (Epic 18 Canceled). |
| `docs/stories/implementation/18-2-slim-global-onboarding.md` | POINT-IN-TIME | t4-docs-triage | Same as 18.1; Finding 1 evidence (Epic 18 Canceled, DNI-167). |
| `docs/stories/implementation/18-3-track-management-hub.md` | POINT-IN-TIME | t4-docs-triage | Same as 18.1; Finding 1 evidence (Epic 18 Canceled, DNI-168). |
| `docs/stories/implementation/18-4-hebrew-terms-chazara-curriculum-names.md` | POINT-IN-TIME | t4-docs-triage | Finding 1 evidence; also documents pre-Rule-5 direct displayNameHe usage since cleaned up (not re-reported). |
| `docs/stories/implementation/18-5-track-editing-from-settings.md` | POINT-IN-TIME | t4-docs-triage | Finding 1 evidence (Epic 18 Canceled). |
| `docs/stories/implementation/18-6-child-mode-onboarding-post-setup-rewards.md` | POINT-IN-TIME | t4-docs-triage | Finding 1 evidence (Epic 18 Canceled). |
| `docs/stories/implementation/18-7-navigation-state-cleanup.md` | POINT-IN-TIME | t4-docs-triage | Finding 1 evidence (Epic 18 Canceled). |
| `docs/stories/implementation/18-8-instant-mark-complete.md` | POINT-IN-TIME | t4-docs-triage | Finding 1 evidence (Epic 18 Canceled). |
| `docs/stories/implementation/18-9-prevent-duplicate-profile-names.md` | POINT-IN-TIME | t4-docs-triage | Finding 1 evidence (Epic 18 Canceled). |
| `docs/stories/implementation/19-1-fix-calendar-registry-bugs.md` | POINT-IN-TIME | t4-docs-triage | Status done, full completion evidence, matches sprint-status.yaml; internally consistent. |
| `docs/stories/implementation/19-10-navigation-state-cleanup.md` | DEFECTIVE | t4-docs-triage | ready-for-dev/0 tasks/empty record vs yaml 'done'; confirmed AC-4 deletions never happened in lib/ (Finding 2 anchor). |
| `docs/stories/implementation/19-11-e2e-offline-integration-testing.md` | POINT-IN-TIME | t4-docs-triage | ready-for-dev/0 tasks vs yaml 'done' (Finding 2 evidence); self-notes future v2-refactor supersession. |
| `docs/stories/implementation/19-12-content-db-resilience-error-recovery.md` | POINT-IN-TIME | t4-docs-triage | ready-for-dev/0 tasks/empty record vs yaml 'done' (Finding 2 evidence). |
| `docs/stories/implementation/19-2-two-database-split.md` | POINT-IN-TIME | t4-docs-triage | ready-for-dev/0 tasks/empty record vs yaml 'done' (Finding 2 evidence). |
| `docs/stories/implementation/19-2b-content-db-runtime-upgrade-flow.md` | POINT-IN-TIME | t4-docs-triage | ready-for-dev/0 tasks/empty record vs yaml 'done' (Finding 2 evidence). |
| `docs/stories/implementation/19-3-seed-database-build-tool.md` | POINT-IN-TIME | t4-docs-triage | ready-for-dev/0 tasks/empty record vs yaml 'done' (Finding 2 evidence). |
| `docs/stories/implementation/19-4-local-calendar-engine.md` | POINT-IN-TIME | t4-docs-triage | ready-for-dev/0 tasks/empty record vs yaml 'done' (Finding 2 evidence). |
| `docs/stories/implementation/19-5-local-first-auth-abstraction.md` | POINT-IN-TIME | t4-docs-triage | Exemplary dated SUPERSEDED banner + canonical-doc pointer; still a Finding-2 site (yaml says done). |
| `docs/stories/implementation/19-6-startup-sequence-hardening.md` | POINT-IN-TIME | t4-docs-triage | ready-for-dev/0 tasks/empty record vs yaml 'done' (Finding 2 evidence). |
| `docs/stories/implementation/19-7-optional-account-creation-settings.md` | POINT-IN-TIME | t4-docs-triage | Exemplary dated SUPERSEDED banner like 19.5; still a Finding-2 site (yaml says done). |
| `docs/stories/implementation/19-8-syncengine-conditional-activation.md` | DEFECTIVE | t4-docs-triage | ready-for-dev but targets deleted SyncEngine/syncEngineProvider architecture; see finding. |
| `docs/stories/implementation/19-9-multi-device-sync.md` | DEFECTIVE | t4-docs-triage | ready-for-dev; whole SyncEngine/OfflineQueue/FirestoreDataSource surface it audits is gone. |
| `docs/stories/implementation/21-1-device-account-registry.md` | POINT-IN-TIME | t4-docs-triage | done; device_registry_database.dart + tier fields confirmed present in lib/. |
| `docs/stories/implementation/21-10-signout-to-picker.md` | POINT-IN-TIME | t4-docs-triage | done; picker/registry sign-out flow plausible, paths since renamed auth→account. |
| `docs/stories/implementation/21-11-add-account-from-picker.md` | POINT-IN-TIME | t4-docs-triage | done; account_picker_screen.dart exists, 5-cap logic plausible, not re-verified. |
| `docs/stories/implementation/21-12-upgrade-multi-account.md` | POINT-IN-TIME | t4-docs-triage | done; upgrade_to_cloud_service.dart + tier fields confirmed present in lib/. |
| `docs/stories/implementation/21-13-remove-cloud-from-device.md` | POINT-IN-TIME | t4-docs-triage | done; account_lifecycle_service.dart present, matches remove-from-device intent. |
| `docs/stories/implementation/21-14-delete-local-account.md` | POINT-IN-TIME | t4-docs-triage | done; local-account delete flow plausible given account_lifecycle_service.dart. |
| `docs/stories/implementation/21-15-delete-cloud-account-full.md` | POINT-IN-TIME | t4-docs-triage | done; wipe ordering matches account_management_service.dart deleteAccount doc-comment. |
| `docs/stories/implementation/21-16-cloud-function-deletion.md` | POINT-IN-TIME | t4-docs-triage | done; functions/src/index.ts onUserDeleted confirmed present, matches intent. |
| `docs/stories/implementation/21-2-per-account-database-isolation.md` | POINT-IN-TIME | t4-docs-triage | done; multi-DB-per-account architecture confirmed live in lib/. |
| `docs/stories/implementation/21-3-session-auto-resume.md` | POINT-IN-TIME | t4-docs-triage | done; auth_state_provider.dart present under renamed path, design plausible. |
| `docs/stories/implementation/21-4-session-persistence.md` | POINT-IN-TIME | t4-docs-triage | done; dual-write session persistence plausible, not line-verified. |
| `docs/stories/implementation/21-5-unified-signup-email-password.md` | POINT-IN-TIME | t4-docs-triage | done; signup_screen.dart exists under later-renamed account/onboarding path. |
| `docs/stories/implementation/21-6-unified-signup-google.md` | POINT-IN-TIME | t4-docs-triage | done; builds on 21-5, Google sign-in plausible, not independently re-verified. |
| `docs/stories/implementation/21-7-unified-signin-smart-routing.md` | POINT-IN-TIME | t4-docs-triage | done; sign_in_screen.dart / sign_in_controller.dart present under account/. |
| `docs/stories/implementation/21-8-unified-signin-google.md` | POINT-IN-TIME | t4-docs-triage | done; builds on 21-7, not independently re-verified. |
| `docs/stories/implementation/21-9-account-picker-screen.md` | POINT-IN-TIME | t4-docs-triage | done; account_picker_screen.dart confirmed present at renamed path. |
| `docs/stories/implementation/25-3-composite-indexes-hot-path.md` | POINT-IN-TIME | t4-docs-triage | review, self-consistent; test-story-25.3 Makefile target confirmed present. |
| `docs/stories/implementation/DNI-323-append-only-event-tables-unique-constraints.md` | POINT-IN-TIME | t4-docs-triage | review; completion_events.dart + dayUtc/ulid columns confirmed in lib/. |
| `docs/stories/implementation/DNI-327-schema-check-profileid-invariants.md` | POINT-IN-TIME | t4-docs-triage | review; short, self-consistent, matches later stories' schema-check mentions. |
| `docs/stories/implementation/DNI-328-profile-scoped-preference-primitives.md` | POINT-IN-TIME | t4-docs-triage | review; core/preferences/ primitives confirmed present in lib/. |
| `docs/stories/implementation/DNI-329-content-index-program-ref-resolver.md` | POINT-IN-TIME | t4-docs-triage | review; internally consistent, file list plausible, not independently verified. |
| `docs/stories/implementation/DNI-331-local-day-clock-time-provider.md` | POINT-IN-TIME | t4-docs-triage | review; local_day_clock.dart confirmed present, notes self-consistent. |
| `docs/stories/implementation/DNI-333-sync-engine-decomp-part1-gateway-pipelines.md` | POINT-IN-TIME | t4-docs-triage | done; firestore_gateway_impl.dart / pull_pipeline.dart confirmed present in lib/. |
| `docs/stories/implementation/DNI-334-sync-engine-decomp-part2-merge-router.md` | POINT-IN-TIME | t4-docs-triage | done; core/sync/merge/ mergers + merge_router.dart confirmed present. |
| `docs/stories/implementation/DNI-335-sync-engine-decomp-part3-listener-lifecycle.md` | POINT-IN-TIME | t4-docs-triage | done; ListenerSupervisor/LifecycleObserver wired into sync_orchestrator.dart, confirmed. |
| `docs/stories/implementation/DNI-336-completion-writer-transactional-commit.md` | POINT-IN-TIME | t4-docs-triage | review; completion_writer.dart plausible, candid scope-deferral notes. |
| `docs/stories/implementation/DNI-337-streak-event-log-reducer-sync.md` | POINT-IN-TIME | t4-docs-triage | review; core/streak/ files plausible, self-flags cross-branch merge conflicts. |
| `docs/stories/implementation/DNI-339-typed-auto-route-pinscope-guard.md` | POINT-IN-TIME | t4-docs-triage | review; pin_scope.dart/pin_guard.dart plausible; itself updates architecture.md. |
| `docs/stories/implementation/DNI-340-finalize-applogger-migrate-production-logs.md` | POINT-IN-TIME | t4-docs-triage | review; AppLogger migration plausible, consistent with Rule 4 (talker confinement). |
| `docs/stories/implementation/DNI-341-materialapp-locale-noto-hebrew-dark-theme.md` | POINT-IN-TIME | t4-docs-triage | review; dark-theme/locale-null wiring plausible, detailed candid dev notes. |
| `docs/stories/implementation/DNI-342-multi-account-threading-replace-hardcoded-account-id.md` | POINT-IN-TIME | t4-docs-triage | review; currentAccountIdProvider threading plausible, predates auth→account rename. |
| `docs/stories/implementation/DNI-352-add-track-controller-state-machine.md` | POINT-IN-TIME | t4-docs-triage | Status in-progress but checklist/notes read complete; files confirmed under renamed path. |
| `docs/stories/implementation/DNI-378-unit-tests-pure-functions.md` | POINT-IN-TIME | t4-docs-triage | review; unit-test coverage claim plausible, self-aware skip-stub noted. |
| `docs/stories/implementation/DNI-379-dao-tests-real-drift.md` | POINT-IN-TIME | t4-docs-triage | review; DAO test migration plausible, detailed file list, self-consistent. |
| `docs/stories/implementation/DNI-380-widget-golden-tests.md` | POINT-IN-TIME | t4-docs-triage | review; golden-test skip-golden rationale explicit and self-consistent. |
| `docs/stories/implementation/DNI-381-bulk-mark-prior-does-not-credit-streak.md` | POINT-IN-TIME | t4-docs-triage | review; narrow regression-test scope, self-consistent with DNI-337 dependency. |
| `docs/stories/implementation/DNI-382-streak-reducer-integration-tests.md` | POINT-IN-TIME | t4-docs-triage | in-progress but content complete; cherry-pick conflict notes internally consistent. |
| `docs/stories/implementation/DNI-383-integration-tests-profile-isolation-trackcard.md` | POINT-IN-TIME | t4-docs-triage | review; isolation-test scope explicit, honest skip-stub for unbuilt TrackCardViewModel. |
| `docs/stories/implementation/seed-database-build-tool-design.md` | POINT-IN-TIME | t4-docs-triage | Draft tool design (2026-03-29), feeds stories 19-2b/3/4/6/12; since implemented (tool/seed_content_db.dart exists). |
| `docs/stories/implementation/tech-spec-learning-tracker-v1-complete.md` | POINT-IN-TIME | t4-docs-triage | Self-labeled 'historical — superseded by shipped v1' w/ 2026-04-19 banner to current docs; verified accurate. |
| `docs/sync-conflict-resolution.md` | SOUND | t4-docs-canonical | All 10 named merger files + both integration test files verified to exist. |
| `docs/_archive/superseded/sync-rework-exec-prompt-2026-05-18.md` | POINT-IN-TIME | t4-docs-canonical | Dated wave-execution script; its test/sync/sync_rework_* files confirmed to exist, run completed. |
| `docs/test-options.md` | ISSUES | t4-docs-canonical | Layer table/CI list/~10k-test count/paths verified accurate; night_runner.py fabricated (F8). |
| `docs/testing-guide.md` | DEFECTIVE | t4-docs-canonical | Every primary code example references DB/enum types deleted in schema-v1 rebuild (F4). |
| `docs/_archive/superseded/tracking-system-review-2026-05-17.md` | POINT-IN-TIME | t4-docs-canonical | Dated bug-assessment; its C1/C2/C3 items correctly tracked forward and closed in open-items.md. |

## Tier 3 — Generated files (80 files)

Checked by regeneration diff (build_runner + gen-l10n on clean tree). 3 files showed drift — see finding on stale codegen; the rest were byte-identical.

<details><summary>File list</summary>

- `learning_tracker/lib/core/content/content_index.g.dart`
- `learning_tracker/lib/core/content/content_tree.g.dart`
- `learning_tracker/lib/core/database/content/content_database.g.dart`
- `learning_tracker/lib/core/database/content/daos/calendar_cycle_dao.g.dart`
- `learning_tracker/lib/core/database/content/daos/daily_content_dao.g.dart`
- `learning_tracker/lib/core/database/content/daos/seed_metadata_dao.g.dart`
- `learning_tracker/lib/core/database/content/daos/text_cache_dao.g.dart`
- `learning_tracker/lib/core/database/daos/active_curriculum_dao.g.dart`
- `learning_tracker/lib/core/database/daos/bookmark_dao.g.dart`
- `learning_tracker/lib/core/database/daos/completion_dao.g.dart`
- `learning_tracker/lib/core/database/daos/completion_event_dao.g.dart`
- `learning_tracker/lib/core/database/daos/curriculum_scope_dao.g.dart`
- `learning_tracker/lib/core/database/daos/daily_plan_dao.g.dart`
- `learning_tracker/lib/core/database/daos/goal_dao.g.dart`
- `learning_tracker/lib/core/database/daos/learning_ledger_dao.g.dart`
- `learning_tracker/lib/core/database/daos/learning_order_dao.g.dart`
- `learning_tracker/lib/core/database/daos/outbox_dao.g.dart`
- `learning_tracker/lib/core/database/daos/point_config_dao.g.dart`
- `learning_tracker/lib/core/database/daos/profile_dao.g.dart`
- `learning_tracker/lib/core/database/daos/profile_program_dao.g.dart`
- `learning_tracker/lib/core/database/daos/stage_dao.g.dart`
- `learning_tracker/lib/core/database/daos/streak_event_dao.g.dart`
- `learning_tracker/lib/core/database/daos/study_day_config_dao.g.dart`
- `learning_tracker/lib/core/database/daos/sync_kv_dao.g.dart`
- `learning_tracker/lib/core/database/daos/text_download_status_dao.g.dart`
- `learning_tracker/lib/core/database/daos/track_dao.g.dart`
- `learning_tracker/lib/core/database/daos/track_learning_order_dao.g.dart`
- `learning_tracker/lib/core/database/daos/user_profile_dao.g.dart`
- `learning_tracker/lib/core/database/registry/device_registry_database.g.dart`
- `learning_tracker/lib/core/database/track_scope.freezed.dart`
- `learning_tracker/lib/core/database/user/user_database.g.dart`
- `learning_tracker/lib/core/labels/curriculum_label_providers.g.dart`
- `learning_tracker/lib/core/navigation/pin_scope.freezed.dart`
- `learning_tracker/lib/core/preferences/preference_providers.g.dart`
- `learning_tracker/lib/core/providers/database_provider.g.dart`
- `learning_tracker/lib/core/providers/registry_provider.g.dart`
- `learning_tracker/lib/features/content_browsing/presentation/providers/cloud_content_providers.g.dart`
- `learning_tracker/lib/features/content_browsing/presentation/providers/content_providers.g.dart`
- `learning_tracker/lib/features/content_browsing/presentation/providers/text_display_providers.g.dart`
- `learning_tracker/lib/features/dashboard/domain/models/calendar_position.freezed.dart`
- `learning_tracker/lib/features/dashboard/domain/models/chazara_status.freezed.dart`
- `learning_tracker/lib/features/dashboard/domain/models/momentum_status.freezed.dart`
- `learning_tracker/lib/features/dashboard/presentation/providers/calendar_position_providers.g.dart`
- `learning_tracker/lib/features/dashboard/presentation/providers/dashboard_providers.g.dart`
- `learning_tracker/lib/features/gamification/domain/models/streak_recovery_info.freezed.dart`
- `learning_tracker/lib/features/gamification/presentation/providers/reward_config_controller.g.dart`
- `learning_tracker/lib/features/gamification/presentation/screens/gamification_screen.g.dart`
- `learning_tracker/lib/features/learning/presentation/providers/completion_providers.g.dart`
- `learning_tracker/lib/features/learning/presentation/providers/learning_ledger_providers.g.dart`
- `learning_tracker/lib/features/learning/presentation/providers/optimistic_completion_provider.g.dart`
- `learning_tracker/lib/features/learning/presentation/providers/track_providers.g.dart`
- `learning_tracker/lib/features/notifications/presentation/providers/notification_providers.g.dart`
- `learning_tracker/lib/features/onboarding/presentation/providers/onboarding_controller.g.dart`
- `learning_tracker/lib/features/profiles/domain/models/profile_model.freezed.dart`
- `learning_tracker/lib/features/profiles/presentation/providers/active_profile_provider.g.dart`
- `learning_tracker/lib/features/profiles/presentation/providers/profile_providers.g.dart`
- `learning_tracker/lib/features/progress/domain/models/journey_view_model.freezed.dart`
- `learning_tracker/lib/features/progress/presentation/providers/journey_providers.g.dart`
- `learning_tracker/lib/features/progress/presentation/providers/progress_providers.g.dart`
- `learning_tracker/lib/features/sacred_time/domain/models/city.freezed.dart`
- `learning_tracker/lib/features/sacred_time/domain/models/sacred_location.freezed.dart`
- `learning_tracker/lib/features/sacred_time/domain/models/sacred_window.freezed.dart`
- `learning_tracker/lib/features/sacred_time/presentation/providers/cities_provider.g.dart`
- `learning_tracker/lib/features/sacred_time/presentation/providers/sacred_location_provider.g.dart`
- `learning_tracker/lib/features/sacred_time/presentation/providers/sacred_windows_provider.g.dart`
- `learning_tracker/lib/features/scheduler/domain/models/daily_task.freezed.dart`
- `learning_tracker/lib/features/scheduler/domain/models/goal_entity.freezed.dart`
- `learning_tracker/lib/features/scheduler/domain/models/pace_status.freezed.dart`
- `learning_tracker/lib/features/scheduler/domain/models/schedule_config.freezed.dart`
- `learning_tracker/lib/features/scheduler/domain/models/scheduler_analysis.freezed.dart`
- `learning_tracker/lib/features/scheduler/domain/models/scheduler_input.freezed.dart`
- `learning_tracker/lib/features/scheduler/domain/models/study_day_config.freezed.dart`
- `learning_tracker/lib/features/scheduler/domain/models/task_assembly.freezed.dart`
- `learning_tracker/lib/features/scheduler/presentation/providers/scheduler_providers.g.dart`
- `learning_tracker/lib/features/scheduler/presentation/providers/study_day_config_providers.g.dart`
- `learning_tracker/lib/features/sync/domain/models/restore_status.freezed.dart`
- `learning_tracker/lib/features/sync/domain/models/sync_status.freezed.dart`
- `learning_tracker/lib/l10n/app_localizations.dart`
- `learning_tracker/lib/l10n/app_localizations_en.dart`
- `learning_tracker/lib/l10n/app_localizations_he.dart`

</details>

## Excluded (2288 files)

| Reason | Files |
|---|---|
| vendored-agent-tooling | 2094 |
| binary asset | 70 |
| archived/test-artifact per Part C | 59 |
| superseded-output-dir (hygiene finding) | 29 |
| content/data asset or cache | 25 |
| lockfile/license | 6 |
| accidental/binary artifact (hygiene finding) | 5 |

<details><summary>Full excluded-file list</summary>

- `.agents/skills/bmad-advanced-elicitation/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-advanced-elicitation/methods.csv` — vendored-agent-tooling
- `.agents/skills/bmad-agent-analyst/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-agent-analyst/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-agent-architect/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-agent-architect/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-agent-dev/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-agent-dev/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-agent-pm/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-agent-pm/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-agent-tech-writer/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-agent-tech-writer/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-agent-tech-writer/explain-concept.md` — vendored-agent-tooling
- `.agents/skills/bmad-agent-tech-writer/mermaid-gen.md` — vendored-agent-tooling
- `.agents/skills/bmad-agent-tech-writer/validate-doc.md` — vendored-agent-tooling
- `.agents/skills/bmad-agent-tech-writer/write-document.md` — vendored-agent-tooling
- `.agents/skills/bmad-agent-ux-designer/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-agent-ux-designer/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-analyst/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-architect/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-brainstorming/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-brainstorming/brain-methods.csv` — vendored-agent-tooling
- `.agents/skills/bmad-brainstorming/steps/step-01-session-setup.md` — vendored-agent-tooling
- `.agents/skills/bmad-brainstorming/steps/step-01b-continue.md` — vendored-agent-tooling
- `.agents/skills/bmad-brainstorming/steps/step-02a-user-selected.md` — vendored-agent-tooling
- `.agents/skills/bmad-brainstorming/steps/step-02b-ai-recommended.md` — vendored-agent-tooling
- `.agents/skills/bmad-brainstorming/steps/step-02c-random-selection.md` — vendored-agent-tooling
- `.agents/skills/bmad-brainstorming/steps/step-02d-progressive-flow.md` — vendored-agent-tooling
- `.agents/skills/bmad-brainstorming/steps/step-03-technique-execution.md` — vendored-agent-tooling
- `.agents/skills/bmad-brainstorming/steps/step-04-idea-organization.md` — vendored-agent-tooling
- `.agents/skills/bmad-brainstorming/template.md` — vendored-agent-tooling
- `.agents/skills/bmad-brainstorming/workflow.md` — vendored-agent-tooling
- `.agents/skills/bmad-check-implementation-readiness/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-check-implementation-readiness/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-check-implementation-readiness/steps/step-01-document-discovery.md` — vendored-agent-tooling
- `.agents/skills/bmad-check-implementation-readiness/steps/step-02-prd-analysis.md` — vendored-agent-tooling
- `.agents/skills/bmad-check-implementation-readiness/steps/step-03-epic-coverage-validation.md` — vendored-agent-tooling
- `.agents/skills/bmad-check-implementation-readiness/steps/step-04-ux-alignment.md` — vendored-agent-tooling
- `.agents/skills/bmad-check-implementation-readiness/steps/step-05-epic-quality-review.md` — vendored-agent-tooling
- `.agents/skills/bmad-check-implementation-readiness/steps/step-06-final-assessment.md` — vendored-agent-tooling
- `.agents/skills/bmad-check-implementation-readiness/templates/readiness-report-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-checkpoint-preview/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-checkpoint-preview/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-checkpoint-preview/generate-trail.md` — vendored-agent-tooling
- `.agents/skills/bmad-checkpoint-preview/step-01-orientation.md` — vendored-agent-tooling
- `.agents/skills/bmad-checkpoint-preview/step-02-walkthrough.md` — vendored-agent-tooling
- `.agents/skills/bmad-checkpoint-preview/step-03-detail-pass.md` — vendored-agent-tooling
- `.agents/skills/bmad-checkpoint-preview/step-04-testing.md` — vendored-agent-tooling
- `.agents/skills/bmad-checkpoint-preview/step-05-wrapup.md` — vendored-agent-tooling
- `.agents/skills/bmad-code-review/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-code-review/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-code-review/steps/step-01-gather-context.md` — vendored-agent-tooling
- `.agents/skills/bmad-code-review/steps/step-02-review.md` — vendored-agent-tooling
- `.agents/skills/bmad-code-review/steps/step-03-triage.md` — vendored-agent-tooling
- `.agents/skills/bmad-code-review/steps/step-04-present.md` — vendored-agent-tooling
- `.agents/skills/bmad-correct-course/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-correct-course/checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-correct-course/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-create-architecture/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-create-architecture/architecture-decision-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-create-architecture/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-create-architecture/data/domain-complexity.csv` — vendored-agent-tooling
- `.agents/skills/bmad-create-architecture/data/project-types.csv` — vendored-agent-tooling
- `.agents/skills/bmad-create-architecture/steps/step-01-init.md` — vendored-agent-tooling
- `.agents/skills/bmad-create-architecture/steps/step-01b-continue.md` — vendored-agent-tooling
- `.agents/skills/bmad-create-architecture/steps/step-02-context.md` — vendored-agent-tooling
- `.agents/skills/bmad-create-architecture/steps/step-03-starter.md` — vendored-agent-tooling
- `.agents/skills/bmad-create-architecture/steps/step-04-decisions.md` — vendored-agent-tooling
- `.agents/skills/bmad-create-architecture/steps/step-05-patterns.md` — vendored-agent-tooling
- `.agents/skills/bmad-create-architecture/steps/step-06-structure.md` — vendored-agent-tooling
- `.agents/skills/bmad-create-architecture/steps/step-07-validation.md` — vendored-agent-tooling
- `.agents/skills/bmad-create-architecture/steps/step-08-complete.md` — vendored-agent-tooling
- `.agents/skills/bmad-create-epics-and-stories/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-create-epics-and-stories/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-create-epics-and-stories/steps/step-01-validate-prerequisites.md` — vendored-agent-tooling
- `.agents/skills/bmad-create-epics-and-stories/steps/step-02-design-epics.md` — vendored-agent-tooling
- `.agents/skills/bmad-create-epics-and-stories/steps/step-03-create-stories.md` — vendored-agent-tooling
- `.agents/skills/bmad-create-epics-and-stories/steps/step-04-final-validation.md` — vendored-agent-tooling
- `.agents/skills/bmad-create-epics-and-stories/templates/epics-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-create-prd/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-create-prd/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-create-story/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-create-story/checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-create-story/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-create-story/discover-inputs.md` — vendored-agent-tooling
- `.agents/skills/bmad-create-story/template.md` — vendored-agent-tooling
- `.agents/skills/bmad-customize/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-customize/scripts/list_customizable_skills.py` — vendored-agent-tooling
- `.agents/skills/bmad-customize/scripts/tests/test_list_customizable_skills.py` — vendored-agent-tooling
- `.agents/skills/bmad-dev-story/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-dev-story/checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-dev-story/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-dev/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-document-project/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-document-project/checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-document-project/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-document-project/documentation-requirements.csv` — vendored-agent-tooling
- `.agents/skills/bmad-document-project/instructions.md` — vendored-agent-tooling
- `.agents/skills/bmad-document-project/templates/deep-dive-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-document-project/templates/index-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-document-project/templates/project-overview-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-document-project/templates/project-scan-report-schema.json` — vendored-agent-tooling
- `.agents/skills/bmad-document-project/templates/source-tree-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-document-project/workflows/deep-dive-instructions.md` — vendored-agent-tooling
- `.agents/skills/bmad-document-project/workflows/deep-dive-workflow.md` — vendored-agent-tooling
- `.agents/skills/bmad-document-project/workflows/full-scan-instructions.md` — vendored-agent-tooling
- `.agents/skills/bmad-document-project/workflows/full-scan-workflow.md` — vendored-agent-tooling
- `.agents/skills/bmad-domain-research/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-domain-research/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-domain-research/domain-steps/step-01-init.md` — vendored-agent-tooling
- `.agents/skills/bmad-domain-research/domain-steps/step-02-domain-analysis.md` — vendored-agent-tooling
- `.agents/skills/bmad-domain-research/domain-steps/step-03-competitive-landscape.md` — vendored-agent-tooling
- `.agents/skills/bmad-domain-research/domain-steps/step-04-regulatory-focus.md` — vendored-agent-tooling
- `.agents/skills/bmad-domain-research/domain-steps/step-05-technical-trends.md` — vendored-agent-tooling
- `.agents/skills/bmad-domain-research/domain-steps/step-06-research-synthesis.md` — vendored-agent-tooling
- `.agents/skills/bmad-domain-research/research.template.md` — vendored-agent-tooling
- `.agents/skills/bmad-edit-prd/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-edit-prd/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-editorial-review-prose/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-editorial-review-structure/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-generate-project-context/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-generate-project-context/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-generate-project-context/project-context-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-generate-project-context/steps/step-01-discover.md` — vendored-agent-tooling
- `.agents/skills/bmad-generate-project-context/steps/step-02-generate.md` — vendored-agent-tooling
- `.agents/skills/bmad-generate-project-context/steps/step-03-complete.md` — vendored-agent-tooling
- `.agents/skills/bmad-help/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-index-docs/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-investigate/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-investigate/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-investigate/references/case-file-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-market-research/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-market-research/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-market-research/research.template.md` — vendored-agent-tooling
- `.agents/skills/bmad-market-research/steps/step-01-init.md` — vendored-agent-tooling
- `.agents/skills/bmad-market-research/steps/step-02-customer-behavior.md` — vendored-agent-tooling
- `.agents/skills/bmad-market-research/steps/step-03-customer-pain-points.md` — vendored-agent-tooling
- `.agents/skills/bmad-market-research/steps/step-04-customer-decisions.md` — vendored-agent-tooling
- `.agents/skills/bmad-market-research/steps/step-05-competitive-analysis.md` — vendored-agent-tooling
- `.agents/skills/bmad-market-research/steps/step-06-research-completion.md` — vendored-agent-tooling
- `.agents/skills/bmad-master/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-party-mode/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-pm/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-prd/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-prd/assets/headless-schemas.md` — vendored-agent-tooling
- `.agents/skills/bmad-prd/assets/prd-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-prd/assets/prd-validation-checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-prd/assets/validation-report-template.html` — vendored-agent-tooling
- `.agents/skills/bmad-prd/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-prd/references/headless.md` — vendored-agent-tooling
- `.agents/skills/bmad-prd/references/validate.md` — vendored-agent-tooling
- `.agents/skills/bmad-prfaq/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-prfaq/agents/artifact-analyzer.md` — vendored-agent-tooling
- `.agents/skills/bmad-prfaq/agents/web-researcher.md` — vendored-agent-tooling
- `.agents/skills/bmad-prfaq/assets/prfaq-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-prfaq/bmad-manifest.json` — vendored-agent-tooling
- `.agents/skills/bmad-prfaq/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-prfaq/references/customer-faq.md` — vendored-agent-tooling
- `.agents/skills/bmad-prfaq/references/internal-faq.md` — vendored-agent-tooling
- `.agents/skills/bmad-prfaq/references/press-release.md` — vendored-agent-tooling
- `.agents/skills/bmad-prfaq/references/verdict.md` — vendored-agent-tooling
- `.agents/skills/bmad-product-brief/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-product-brief/assets/brief-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-product-brief/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-qa-generate-e2e-tests/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-qa-generate-e2e-tests/checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-qa-generate-e2e-tests/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-qa/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-quick-dev/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-quick-dev/compile-epic-context.md` — vendored-agent-tooling
- `.agents/skills/bmad-quick-dev/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-quick-dev/spec-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-quick-dev/step-01-clarify-and-route.md` — vendored-agent-tooling
- `.agents/skills/bmad-quick-dev/step-02-plan.md` — vendored-agent-tooling
- `.agents/skills/bmad-quick-dev/step-03-implement.md` — vendored-agent-tooling
- `.agents/skills/bmad-quick-dev/step-04-review.md` — vendored-agent-tooling
- `.agents/skills/bmad-quick-dev/step-05-present.md` — vendored-agent-tooling
- `.agents/skills/bmad-quick-dev/step-oneshot.md` — vendored-agent-tooling
- `.agents/skills/bmad-quick-dev/sync-sprint-status.md` — vendored-agent-tooling
- `.agents/skills/bmad-quick-flow-solo-dev/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-retrospective/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-retrospective/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-review-adversarial-general/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-review-edge-case-hunter/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-shard-doc/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-sm/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-spec/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-spec/assets/headless-schemas.md` — vendored-agent-tooling
- `.agents/skills/bmad-spec/assets/spec-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-spec/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-sprint-planning/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-sprint-planning/checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-sprint-planning/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-sprint-planning/sprint-status-template.yaml` — vendored-agent-tooling
- `.agents/skills/bmad-sprint-status/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-sprint-status/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-tea/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/adr-quality-readiness-checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/api-request.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/api-testing-patterns.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/auth-session.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/burn-in.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/ci-burn-in.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/component-tdd.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/confidence-gate.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/contract-testing.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/data-factories.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/email-auth.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/error-handling.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/feature-flags.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/file-utils.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/fixture-architecture.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/fixtures-composition.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/intercept-network-call.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/log.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/network-error-monitor.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/network-first.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/network-recorder.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/nfr-criteria.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/overview.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/pact-broker-webhooks.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/pact-consumer-di.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/pact-consumer-framework-setup.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/pact-mcp.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/pactjs-utils-consumer-helpers.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/pactjs-utils-overview.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/pactjs-utils-provider-verifier.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/pactjs-utils-request-filter.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/pactjs-utils-zod-to-pact.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/playwright-cli.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/playwright-config.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/probability-impact.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/recurse.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/risk-governance.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/selective-testing.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/selector-resilience.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/test-healing-patterns.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/test-levels-framework.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/test-priorities-matrix.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/test-quality.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/timing-debugging.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/visual-debugging.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/webhook-module-setup.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/webhook-providers.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/webhook-risk-guidance.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/webhook-template-matchers.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/webhook-testing-fundamentals.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/webhook-timeout-error.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/knowledge/webhook-waiting-querying.md` — vendored-agent-tooling
- `.agents/skills/bmad-tea/resources/tea-index.csv` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/data/curriculum.yaml` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/data/quiz-questions.yaml` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/data/role-paths.yaml` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/data/session-content-map.yaml` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/data/tea-resources-index.yaml` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/instructions.md` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/steps-c/step-01-init.md` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/steps-c/step-01b-continue.md` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/steps-c/step-02-assess.md` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/steps-c/step-03-session-menu.md` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/steps-c/step-04-session-01.md` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/steps-c/step-04-session-02.md` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/steps-c/step-04-session-03.md` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/steps-c/step-04-session-04.md` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/steps-c/step-04-session-05.md` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/steps-c/step-04-session-06.md` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/steps-c/step-04-session-07.md` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/steps-c/step-05-completion.md` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/steps-e/step-e-01-assess-workflow.md` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/steps-e/step-e-02-apply-edits.md` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/steps-v/step-v-01-validate.md` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/templates/certificate-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/templates/progress-template.yaml` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/templates/session-notes-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-teach-me-testing/workflow-plan-teach-me-testing.md` — vendored-agent-tooling
- `.agents/skills/bmad-tech-writer/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-technical-research/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-technical-research/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-technical-research/research.template.md` — vendored-agent-tooling
- `.agents/skills/bmad-technical-research/technical-steps/step-01-init.md` — vendored-agent-tooling
- `.agents/skills/bmad-technical-research/technical-steps/step-02-technical-overview.md` — vendored-agent-tooling
- `.agents/skills/bmad-technical-research/technical-steps/step-03-integration-patterns.md` — vendored-agent-tooling
- `.agents/skills/bmad-technical-research/technical-steps/step-04-architectural-patterns.md` — vendored-agent-tooling
- `.agents/skills/bmad-technical-research/technical-steps/step-05-implementation-research.md` — vendored-agent-tooling
- `.agents/skills/bmad-technical-research/technical-steps/step-06-research-synthesis.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/atdd-checklist-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/instructions.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/adr-quality-readiness-checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/api-request.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/api-testing-patterns.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/auth-session.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/burn-in.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/ci-burn-in.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/component-tdd.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/contract-testing.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/data-factories.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/email-auth.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/error-handling.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/feature-flags.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/file-utils.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/fixture-architecture.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/fixtures-composition.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/intercept-network-call.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/log.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/network-error-monitor.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/network-first.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/network-recorder.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/nfr-criteria.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/overview.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/pact-broker-webhooks.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/pact-consumer-di.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/pact-consumer-framework-setup.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/pact-mcp.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/pactjs-utils-consumer-helpers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/pactjs-utils-overview.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/pactjs-utils-provider-verifier.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/pactjs-utils-request-filter.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/pactjs-utils-zod-to-pact.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/playwright-cli.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/playwright-config.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/probability-impact.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/recurse.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/risk-governance.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/selective-testing.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/selector-resilience.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/test-healing-patterns.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/test-levels-framework.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/test-priorities-matrix.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/test-quality.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/timing-debugging.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/visual-debugging.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/webhook-module-setup.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/webhook-providers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/webhook-risk-guidance.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/webhook-template-matchers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/webhook-testing-fundamentals.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/webhook-timeout-error.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/knowledge/webhook-waiting-querying.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/resources/tea-index.csv` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/steps-c/step-01-preflight-and-context.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/steps-c/step-01b-resume.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/steps-c/step-02-generation-mode.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/steps-c/step-03-test-strategy.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/steps-c/step-04-generate-tests.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/steps-c/step-04a-subagent-api-failing.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/steps-c/step-04b-subagent-e2e-failing.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/steps-c/step-04c-aggregate.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/steps-c/step-05-validate-and-complete.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/steps-e/step-01-assess.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/steps-e/step-02-apply-edit.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/steps-v/step-01-validate.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/validation-report-20260127-095021.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/validation-report-20260127-102401.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/workflow-plan.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-atdd/workflow.yaml` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/instructions.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/adr-quality-readiness-checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/api-request.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/api-testing-patterns.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/auth-session.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/burn-in.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/ci-burn-in.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/component-tdd.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/contract-testing.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/data-factories.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/email-auth.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/error-handling.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/feature-flags.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/file-utils.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/fixture-architecture.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/fixtures-composition.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/intercept-network-call.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/log.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/network-error-monitor.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/network-first.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/network-recorder.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/nfr-criteria.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/overview.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/pact-broker-webhooks.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/pact-consumer-di.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/pact-consumer-framework-setup.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/pact-mcp.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/pactjs-utils-consumer-helpers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/pactjs-utils-overview.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/pactjs-utils-provider-verifier.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/pactjs-utils-request-filter.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/playwright-cli.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/playwright-config.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/probability-impact.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/recurse.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/risk-governance.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/selective-testing.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/selector-resilience.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/test-healing-patterns.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/test-levels-framework.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/test-priorities-matrix.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/test-quality.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/timing-debugging.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/visual-debugging.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/webhook-module-setup.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/webhook-providers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/webhook-risk-guidance.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/webhook-template-matchers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/webhook-testing-fundamentals.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/webhook-timeout-error.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/knowledge/webhook-waiting-querying.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/resources/tea-index.csv` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/steps-c/step-01-preflight-and-context.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/steps-c/step-01b-resume.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/steps-c/step-02-identify-targets.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/steps-c/step-03-generate-tests.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/steps-c/step-03a-subagent-api.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/steps-c/step-03b-subagent-backend.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/steps-c/step-03b-subagent-e2e.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/steps-c/step-03c-aggregate.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/steps-c/step-04-validate-and-summarize.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/steps-e/step-01-assess.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/steps-e/step-02-apply-edit.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/steps-v/step-01-validate.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/validation-report-20260127-095021.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/validation-report-20260127-102401.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/workflow-plan.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-automate/workflow.yaml` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/azure-pipelines-template.yaml` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/github-actions-template.yaml` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/gitlab-ci-template.yaml` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/harness-pipeline-template.yaml` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/instructions.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/jenkins-pipeline-template.groovy` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/adr-quality-readiness-checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/api-request.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/api-testing-patterns.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/auth-session.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/burn-in.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/ci-burn-in.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/component-tdd.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/contract-testing.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/data-factories.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/email-auth.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/error-handling.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/feature-flags.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/file-utils.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/fixture-architecture.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/fixtures-composition.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/intercept-network-call.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/log.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/network-error-monitor.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/network-first.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/network-recorder.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/nfr-criteria.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/overview.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/pact-broker-webhooks.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/pact-consumer-di.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/pact-consumer-framework-setup.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/pact-mcp.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/pactjs-utils-consumer-helpers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/pactjs-utils-overview.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/pactjs-utils-provider-verifier.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/pactjs-utils-request-filter.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/playwright-cli.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/playwright-config.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/probability-impact.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/recurse.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/risk-governance.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/selective-testing.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/selector-resilience.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/test-healing-patterns.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/test-levels-framework.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/test-priorities-matrix.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/test-quality.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/timing-debugging.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/visual-debugging.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/webhook-module-setup.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/webhook-providers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/webhook-risk-guidance.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/webhook-template-matchers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/webhook-testing-fundamentals.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/webhook-timeout-error.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/knowledge/webhook-waiting-querying.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/resources/tea-index.csv` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/steps-c/step-01-preflight.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/steps-c/step-01b-resume.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/steps-c/step-02-generate-pipeline.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/steps-c/step-03-configure-quality-gates.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/steps-c/step-04-validate-and-summary.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/steps-e/step-01-assess.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/steps-e/step-02-apply-edit.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/steps-v/step-01-validate.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/validation-report-20260127-095021.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/validation-report-20260127-102401.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/workflow-plan.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-ci/workflow.yaml` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/instructions.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/adr-quality-readiness-checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/api-request.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/api-testing-patterns.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/auth-session.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/burn-in.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/ci-burn-in.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/component-tdd.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/contract-testing.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/data-factories.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/email-auth.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/error-handling.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/feature-flags.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/file-utils.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/fixture-architecture.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/fixtures-composition.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/intercept-network-call.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/log.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/network-error-monitor.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/network-first.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/network-recorder.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/nfr-criteria.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/overview.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/pact-broker-webhooks.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/pact-consumer-di.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/pact-consumer-framework-setup.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/pact-mcp.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/pactjs-utils-consumer-helpers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/pactjs-utils-overview.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/pactjs-utils-provider-verifier.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/pactjs-utils-request-filter.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/playwright-cli.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/playwright-config.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/probability-impact.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/recurse.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/risk-governance.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/selective-testing.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/selector-resilience.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/test-healing-patterns.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/test-levels-framework.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/test-priorities-matrix.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/test-quality.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/timing-debugging.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/visual-debugging.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/webhook-module-setup.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/webhook-providers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/webhook-risk-guidance.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/webhook-template-matchers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/webhook-testing-fundamentals.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/webhook-timeout-error.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/knowledge/webhook-waiting-querying.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/resources/tea-index.csv` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/steps-c/step-01-preflight.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/steps-c/step-01b-resume.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/steps-c/step-02-select-framework.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/steps-c/step-03-scaffold-framework.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/steps-c/step-04-docs-and-scripts.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/steps-c/step-05-validate-and-summary.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/steps-e/step-01-assess.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/steps-e/step-02-apply-edit.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/steps-v/step-01-validate.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/validation-report-20260127-095021.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/validation-report-20260127-102401.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/workflow-plan.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-framework/workflow.yaml` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/instructions.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/nfr-report-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/adr-quality-readiness-checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/api-request.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/api-testing-patterns.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/auth-session.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/burn-in.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/ci-burn-in.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/component-tdd.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/contract-testing.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/data-factories.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/email-auth.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/error-handling.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/feature-flags.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/file-utils.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/fixture-architecture.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/fixtures-composition.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/intercept-network-call.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/log.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/network-error-monitor.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/network-first.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/network-recorder.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/nfr-criteria.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/overview.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/pact-broker-webhooks.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/pact-consumer-di.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/pact-consumer-framework-setup.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/pact-mcp.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/pactjs-utils-consumer-helpers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/pactjs-utils-overview.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/pactjs-utils-provider-verifier.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/pactjs-utils-request-filter.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/playwright-cli.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/playwright-config.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/probability-impact.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/recurse.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/risk-governance.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/selective-testing.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/selector-resilience.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/test-healing-patterns.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/test-levels-framework.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/test-priorities-matrix.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/test-quality.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/timing-debugging.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/visual-debugging.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/webhook-module-setup.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/webhook-providers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/webhook-risk-guidance.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/webhook-template-matchers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/webhook-testing-fundamentals.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/webhook-timeout-error.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/knowledge/webhook-waiting-querying.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/resources/tea-index.csv` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/steps-c/step-01-load-context.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/steps-c/step-01b-resume.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/steps-c/step-02-define-thresholds.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/steps-c/step-03-gather-evidence.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/steps-c/step-04-evaluate-and-score.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/steps-c/step-04a-subagent-security.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/steps-c/step-04b-subagent-performance.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/steps-c/step-04c-subagent-reliability.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/steps-c/step-04d-subagent-scalability.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/steps-c/step-04e-aggregate-nfr.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/steps-c/step-05-generate-report.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/steps-e/step-01-assess.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/steps-e/step-02-apply-edit.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/steps-v/step-01-validate.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/validation-report-20260127-095021.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/validation-report-20260127-102401.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/workflow-plan.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-nfr/workflow.yaml` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/instructions.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/adr-quality-readiness-checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/api-request.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/api-testing-patterns.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/auth-session.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/burn-in.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/ci-burn-in.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/component-tdd.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/contract-testing.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/data-factories.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/email-auth.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/error-handling.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/feature-flags.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/file-utils.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/fixture-architecture.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/fixtures-composition.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/intercept-network-call.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/log.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/network-error-monitor.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/network-first.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/network-recorder.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/nfr-criteria.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/overview.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/pact-broker-webhooks.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/pact-consumer-di.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/pact-consumer-framework-setup.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/pact-mcp.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/pactjs-utils-consumer-helpers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/pactjs-utils-overview.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/pactjs-utils-provider-verifier.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/pactjs-utils-request-filter.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/playwright-cli.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/playwright-config.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/probability-impact.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/recurse.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/risk-governance.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/selective-testing.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/selector-resilience.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/test-healing-patterns.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/test-levels-framework.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/test-priorities-matrix.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/test-quality.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/timing-debugging.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/visual-debugging.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/webhook-module-setup.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/webhook-providers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/webhook-risk-guidance.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/webhook-template-matchers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/webhook-testing-fundamentals.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/webhook-timeout-error.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/knowledge/webhook-waiting-querying.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/resources/tea-index.csv` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/steps-c/step-01-detect-mode.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/steps-c/step-01b-resume.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/steps-c/step-02-load-context.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/steps-c/step-03-risk-and-testability.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/steps-c/step-04-coverage-plan.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/steps-c/step-05-generate-output.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/steps-e/step-01-assess.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/steps-e/step-02-apply-edit.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/steps-v/step-01-validate.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/test-design-architecture-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/test-design-handoff-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/test-design-qa-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/test-design-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/validation-report-20260127-095021.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/validation-report-20260127-102401.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/workflow-plan.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-design/workflow.yaml` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/instructions.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/adr-quality-readiness-checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/api-request.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/api-testing-patterns.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/auth-session.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/burn-in.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/ci-burn-in.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/component-tdd.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/contract-testing.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/data-factories.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/email-auth.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/error-handling.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/feature-flags.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/file-utils.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/fixture-architecture.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/fixtures-composition.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/intercept-network-call.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/log.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/network-error-monitor.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/network-first.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/network-recorder.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/nfr-criteria.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/overview.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/pact-broker-webhooks.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/pact-consumer-di.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/pact-consumer-framework-setup.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/pact-mcp.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/pactjs-utils-consumer-helpers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/pactjs-utils-overview.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/pactjs-utils-provider-verifier.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/pactjs-utils-request-filter.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/playwright-cli.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/playwright-config.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/probability-impact.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/recurse.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/risk-governance.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/selective-testing.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/selector-resilience.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/test-healing-patterns.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/test-levels-framework.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/test-priorities-matrix.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/test-quality.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/timing-debugging.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/visual-debugging.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/webhook-module-setup.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/webhook-providers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/webhook-risk-guidance.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/webhook-template-matchers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/webhook-testing-fundamentals.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/webhook-timeout-error.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/knowledge/webhook-waiting-querying.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/resources/tea-index.csv` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/steps-c/step-01-load-context.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/steps-c/step-01b-resume.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/steps-c/step-02-discover-tests.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/steps-c/step-03-quality-evaluation.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/steps-c/step-03a-subagent-determinism.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/steps-c/step-03b-subagent-isolation.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/steps-c/step-03c-subagent-maintainability.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/steps-c/step-03e-subagent-performance.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/steps-c/step-03f-aggregate-scores.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/steps-c/step-04-generate-report.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/steps-e/step-01-assess.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/steps-e/step-02-apply-edit.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/steps-v/step-01-validate.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/test-review-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/validation-report-20260127-095021.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/validation-report-20260127-102401.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/workflow-plan.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-test-review/workflow.yaml` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/instructions.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/adr-quality-readiness-checklist.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/api-request.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/api-testing-patterns.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/auth-session.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/burn-in.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/ci-burn-in.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/component-tdd.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/contract-testing.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/data-factories.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/email-auth.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/error-handling.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/feature-flags.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/file-utils.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/fixture-architecture.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/fixtures-composition.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/intercept-network-call.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/log.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/network-error-monitor.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/network-first.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/network-recorder.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/nfr-criteria.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/overview.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/pact-broker-webhooks.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/pact-consumer-di.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/pact-consumer-framework-setup.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/pact-mcp.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/pactjs-utils-consumer-helpers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/pactjs-utils-overview.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/pactjs-utils-provider-verifier.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/pactjs-utils-request-filter.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/playwright-cli.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/playwright-config.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/probability-impact.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/recurse.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/risk-governance.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/selective-testing.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/selector-resilience.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/test-healing-patterns.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/test-levels-framework.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/test-priorities-matrix.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/test-quality.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/timing-debugging.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/visual-debugging.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/webhook-module-setup.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/webhook-providers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/webhook-risk-guidance.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/webhook-template-matchers.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/webhook-testing-fundamentals.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/webhook-timeout-error.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/knowledge/webhook-waiting-querying.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/resources/tea-index.csv` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/steps-c/step-01-load-context.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/steps-c/step-01b-resume.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/steps-c/step-02-discover-tests.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/steps-c/step-03-map-criteria.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/steps-c/step-04-analyze-gaps.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/steps-c/step-05-gate-decision.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/steps-e/step-01-assess.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/steps-e/step-02-apply-edit.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/steps-v/step-01-validate.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/trace-template.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/validation-report-20260127-095021.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/validation-report-20260127-102401.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/workflow-plan.md` — vendored-agent-tooling
- `.agents/skills/bmad-testarch-trace/workflow.yaml` — vendored-agent-tooling
- `.agents/skills/bmad-ux-designer/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-ux/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-ux/assets/color-themes.md` — vendored-agent-tooling
- `.agents/skills/bmad-ux/assets/design-directions.md` — vendored-agent-tooling
- `.agents/skills/bmad-ux/assets/design-example-editorial.md` — vendored-agent-tooling
- `.agents/skills/bmad-ux/assets/design-example-mobile.md` — vendored-agent-tooling
- `.agents/skills/bmad-ux/assets/design-example-shadcn.md` — vendored-agent-tooling
- `.agents/skills/bmad-ux/assets/excalidraw-wireframe.md` — vendored-agent-tooling
- `.agents/skills/bmad-ux/assets/experience-example-mobile.md` — vendored-agent-tooling
- `.agents/skills/bmad-ux/assets/experience-example-shadcn.md` — vendored-agent-tooling
- `.agents/skills/bmad-ux/assets/headless-schemas.md` — vendored-agent-tooling
- `.agents/skills/bmad-ux/assets/key-screens.md` — vendored-agent-tooling
- `.agents/skills/bmad-ux/assets/validation-report-template.html` — vendored-agent-tooling
- `.agents/skills/bmad-ux/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-ux/references/creative-tools.md` — vendored-agent-tooling
- `.agents/skills/bmad-ux/references/design-md-spec.md` — vendored-agent-tooling
- `.agents/skills/bmad-ux/references/headless.md` — vendored-agent-tooling
- `.agents/skills/bmad-ux/references/validate.md` — vendored-agent-tooling
- `.agents/skills/bmad-validate-prd/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-validate-prd/customize.toml` — vendored-agent-tooling
- `.agents/skills/bmad-wds-Modular Component Architecture/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-Object Type Router/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-acceptance-test/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-acceptance-testing/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-agentic-development/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-alignment-signoff/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-analysis/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-analyze-product/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-asset-generation/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-browse-design-system/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-bugfixing/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-content-creation/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-create-design-system/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-deploy/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-design-solution/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-design-system/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-development/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-edit-components/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-evolution/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-figma-integration/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-handover/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-icons/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-images/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-implement/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-import-design-system/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-page-designs/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-product-evolution/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-project-brief/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-project-setup/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-prototyping/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-reverse-engineering/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-scenarios-validate/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-scenarios/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-scope-improvement/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-stitch-generation/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-trigger-mapping-validate/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-trigger-mapping/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-ui-elements/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-ux-design/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-videos/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-view-components/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-wireframes/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-workflow-design-system/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-workflow-discuss/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-workflow-dream/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-workflow-sketch/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-workflow-specify/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-workflow-suggest/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-workflow-validate/SKILL.md` — vendored-agent-tooling
- `.agents/skills/bmad-wds-workflow-visual/SKILL.md` — vendored-agent-tooling
- `.agents/skills/memory/SKILL.md` — vendored-agent-tooling
- `.agents/skills/sync/SKILL.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/SKILL.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/data/01-start-understand-routing.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/data/02-explore-sections-routing.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/data/03-synthesize-present-routing.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/data/04-generate-signoff-routing.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/data/05-build-contract-routing.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/data/06-build-signoff-internal-routing.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-01a-understand-situation.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-01b-determine-if-needed.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-01c-offer-extract.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-01d-extract-info.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-01e-detect-starting-point.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-02a-explore-realization.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-02b-explore-solution.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-02c-explore-why-it-matters.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-02d-explore-how-we-see-it-working.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-02e-explore-paths-we-explored.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-02f-explore-recommended-solution.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-02g-explore-path-forward.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-02h-explore-value-we-create.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-02i-explore-cost-of-inaction.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-02j-explore-our-commitment.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-02k-explore-summary.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-03a-reflect-back.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-03b-synthesize-document.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-03d-present-approval.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-04a-offer-signoff.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-04b-determine-business-model.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-05a-contract-overview.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-05b-contract-business-model.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-05c-contract-scope.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-05d-contract-payment.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-05e-contract-timeline.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-05f-contract-availability.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-05g-contract-confidentiality.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-05h-contract-not-to-exceed.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-05i-contract-work-initiation.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-05j-contract-terms.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-05k-contract-approval.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-05l-finalize-contract.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-06a-build-internal-signoff.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/steps-c/step-06b-finalize-signoff.md` — vendored-agent-tooling
- `.agents/skills/wds-0-alignment-signoff/workflow.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/SKILL.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/agent-guides/freya/design-system.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/agent-guides/freya/specification-quality.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-1-project-brief/templates/00-project-info.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-1-project-brief/templates/content-language.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-1-project-brief/templates/contract.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-1-project-brief/templates/inspiration-analysis.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-1-project-brief/templates/pitch.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-1-project-brief/templates/platform-requirements.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-1-project-brief/templates/platform-requirements.template.yaml` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-1-project-brief/templates/project-brief-dialog/00-context.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-1-project-brief/templates/project-brief-dialog/02-vision.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-1-project-brief/templates/project-brief-dialog/03-users.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-1-project-brief/templates/project-brief-dialog/04-concept.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-1-project-brief/templates/project-brief-dialog/06-inspiration.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-1-project-brief/templates/project-brief-dialog/07-positioning.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-1-project-brief/templates/project-brief-dialog/USAGE.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-1-project-brief/templates/project-brief-dialog/decisions.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-1-project-brief/templates/project-brief-dialog/progress-tracker.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-1-project-brief/templates/project-brief.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-1-project-brief/templates/service-agreement.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-1-project-brief/templates/signoff.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-1-project-brief/templates/simplified-brief.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-1-project-brief/templates/visual-direction.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-2-trigger-mapping/templates/feature-impact.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-2-trigger-mapping/templates/persona-document.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-2-trigger-mapping/templates/trigger-map.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-4-ux-design/templates/page-specification.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-4-ux-design/templates/scenario-overview.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-7-design-system/templates/catalog.template.html` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-7-design-system/templates/component-library-config.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-7-design-system/templates/component.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/resources/wds-7-design-system/templates/design-tokens.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/steps/step-01-welcome.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/steps/step-02-structure.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/templates/folder-guides/00-design-log.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/templates/folder-guides/00-design-system.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/templates/folder-guides/00-product-brief.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/templates/folder-guides/00-trigger-map.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/templates/folder-guides/00-ux-scenarios.template.md` — vendored-agent-tooling
- `.agents/skills/wds-0-project-setup/workflow.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/SKILL.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/data/positioning-explore.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/data/positioning-open-conversation.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/data/positioning-reflect-confirm.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/data/positioning-synthesize.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/data/tone-of-voice-example.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/data/tone-of-voice-output-template.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/data/vision-explore.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/data/vision-open-conversation.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/data/vision-reflect-confirm.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/data/vision-synthesize.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-00-simplified-brief.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-01-init.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-01a-client-profile.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-02-vision.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-03-positioning.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-05-business-model.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-06-business-customers.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-07-target-users.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-07a-product-concept.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-08-success-criteria.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-09-competitive-landscape.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-10-constraints.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-10a-platform-strategy.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-11-tone-of-voice.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-12-create-product-brief.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-13-content-init.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-14-personality.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-15-tone.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-16-languages.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-17-seo-keywords.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-17a-content-structure.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-18-create-content-document.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-19-inspiration-workshop.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-20-visual-init.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-21-existing-brand.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-22-references.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-23-design-style.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-24-layout-effects.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-25-imagery.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-26-create-visual-document.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-27-platform-init.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-28-tech-stack.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-29-integrations.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-30-contact-strategy.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-31-multilingual.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-32-create-platform-document.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-33-analyze-brief.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-34-create-summary.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-35-update-design-log.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-c/step-36-provide-activation.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-v/step-01-brief-completeness.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-v/step-02-trigger-map-consistency.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-v/step-03-seo-strategy.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-v/step-04-content-language.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-v/step-05-visual-direction.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/steps-v/step-06-platform-requirements.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/templates/00-project-info.template.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/templates/client-profile.template.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/templates/content-language.template.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/templates/contract.template.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/templates/inspiration-analysis.template.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/templates/pitch.template.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/templates/platform-requirements.template.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/templates/platform-requirements.template.yaml` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/templates/project-brief-dialog/00-context.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/templates/project-brief-dialog/02-vision.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/templates/project-brief-dialog/03-users.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/templates/project-brief-dialog/04-concept.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/templates/project-brief-dialog/06-inspiration.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/templates/project-brief-dialog/07-positioning.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/templates/project-brief-dialog/USAGE.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/templates/project-brief-dialog/decisions.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/templates/project-brief-dialog/progress-tracker.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/templates/project-brief.template.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/templates/service-agreement.template.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/templates/signoff.template.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/templates/simplified-brief.template.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/templates/visual-direction.template.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/workflow-validate.md` — vendored-agent-tooling
- `.agents/skills/wds-1-project-brief/workflow.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/SKILL.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/data/business-goals-template.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/data/key-insights-structure.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/data/mermaid-formatting-guide.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/data/quality-checklist.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-00a-documentation-synthesis.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-00b-business-goals-extract.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-00c-target-groups-extract.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-00d-driving-forces-extract.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-00e-prioritization-extract.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-00f-gap-analysis.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-01-overview.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-02-business-goals.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-03-target-groups.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-04-driving-forces.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-05-prioritization.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-06a-extract-features.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-06b-confirm-assessment.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-06c-make-assessment.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-06d-generate-document.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-06e-feature-wrap-up.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-07a-generate-hub.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-07b-generate-business-goals.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-07c-generate-primary-persona.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-07d-generate-secondary-persona.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-07e-generate-tertiary-persona.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-07f-generate-key-insights.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-07g-quality-check.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-08a-mermaid-init-structure.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-08b-mermaid-business-goals.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-08c-mermaid-platform.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-08d-mermaid-target-groups.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-08e-mermaid-driving-forces.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-08f-mermaid-connections.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-08g-mermaid-styling.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-08h-mermaid-quality.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-09a-finalize-hub.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-09b-add-cross-references.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-09c-quality-check.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-09d-create-handover-package.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-09e-update-design-log.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-c/step-09f-provide-activation.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-v/step-01-target-group-coverage.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-v/step-02-prioritization-integrity.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-v/step-03-persona-consistency.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-v/step-04-feature-impact-alignment.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/steps-v/step-05-cross-document-coherence.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/templates/feature-impact.template.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/templates/persona-document.template.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/templates/trigger-map.template.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/workflow-validate.md` — vendored-agent-tooling
- `.agents/skills/wds-2-trigger-mapping/workflow.md` — vendored-agent-tooling
- `.agents/skills/wds-3-scenarios/SKILL.md` — vendored-agent-tooling
- `.agents/skills/wds-3-scenarios/data/quality-checklist.md` — vendored-agent-tooling
- `.agents/skills/wds-3-scenarios/data/scenario-outline-template.md` — vendored-agent-tooling
- `.agents/skills/wds-3-scenarios/data/validation-standards.md` — vendored-agent-tooling
- `.agents/skills/wds-3-scenarios/steps-c/step-01-load-context.md` — vendored-agent-tooling
- `.agents/skills/wds-3-scenarios/steps-c/step-02-analyze-scope.md` — vendored-agent-tooling
- `.agents/skills/wds-3-scenarios/steps-c/step-03-build-strategic-context.md` — vendored-agent-tooling
- `.agents/skills/wds-3-scenarios/steps-c/step-04-suggest-scenarios.md` — vendored-agent-tooling
- `.agents/skills/wds-3-scenarios/steps-c/step-05-outline-scenario.md` — vendored-agent-tooling
- `.agents/skills/wds-3-scenarios/steps-c/step-06-generate-overview.md` — vendored-agent-tooling
- `.agents/skills/wds-3-scenarios/steps-c/step-07-quality-review.md` — vendored-agent-tooling
- `.agents/skills/wds-3-scenarios/steps-c/step-08-update-design-log.md` — vendored-agent-tooling
- `.agents/skills/wds-3-scenarios/steps-c/step-09-handover.md` — vendored-agent-tooling
- `.agents/skills/wds-3-scenarios/steps-v/step-01-scenario-coverage.md` — vendored-agent-tooling
- `.agents/skills/wds-3-scenarios/steps-v/step-02-navigation-patterns.md` — vendored-agent-tooling
- `.agents/skills/wds-3-scenarios/steps-v/step-03-outline-completeness.md` — vendored-agent-tooling
- `.agents/skills/wds-3-scenarios/steps-v/step-04-cross-scenario-consistency.md` — vendored-agent-tooling
- `.agents/skills/wds-3-scenarios/steps-v/step-05-seo-keyword-alignment.md` — vendored-agent-tooling
- `.agents/skills/wds-3-scenarios/workflow-validate.md` — vendored-agent-tooling
- `.agents/skills/wds-3-scenarios/workflow.md` — vendored-agent-tooling
- `.agents/skills/wds-3-scenarios/workflow.xml` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/SKILL.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/delivery-templates.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/design-deliveries-guide.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/guides/DESIGN-LOOP-GUIDE.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/guides/HTML-VS-VISUAL-STYLES.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/guides/NANO-BANANA-PROMPT-GUIDE.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/guides/SKETCH-TEXT-ANALYSIS-GUIDE.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/guides/SKETCH-TEXT-QUICK-REFERENCE.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/guides/TRANSLATION-ORGANIZATION-GUIDE.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/guides/WDS-SPECIFICATION-PATTERN.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/handoff-dialog-scripts.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/modular-architecture/00-MODULAR-ARCHITECTURE-GUIDE.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/modular-architecture/00-foundation/agent-designer-collaboration.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/modular-architecture/01-core-concepts/complexity-detection.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/modular-architecture/01-core-concepts/content-placement-rules.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/modular-architecture/01-core-concepts/three-tier-overview.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/modular-architecture/02-workflows/01-what-are-storyboards.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/modular-architecture/02-workflows/01-when-to-use.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/modular-architecture/02-workflows/02-file-structure.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/modular-architecture/02-workflows/complexity-router-workflow.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/modular-architecture/02-workflows/page-specification-workflow.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/modular-architecture/02-workflows/storyboards-guide.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/modular-architecture/03-quick-refs/benefits.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/modular-architecture/03-quick-refs/decision-tree.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/modular-architecture/COMPONENT-FILE-STRUCTURE.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/modular-architecture/CONTENT-PLACEMENT-GUIDE.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/modular-architecture/CROSS-PAGE-CONSISTENCY.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/modular-architecture/STORYBOARD-INTEGRATION.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/modular-architecture/workflow.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/object-types/COMPLEXITY-ROUTER.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/object-types/ROUTER-FLOW-DIAGRAM.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/object-types/TEXT-DETECTION-PRIORITY.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/object-types/object-router.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/object-types/templates/button.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/object-types/templates/heading-text.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/object-types/templates/image.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/object-types/templates/link.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/object-types/templates/text-input.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/object-types/workflow.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/page-creation-flows/flow-a-sketch.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/page-creation-flows/flow-b-verbal.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/page-creation-flows/flow-c-ascii.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/page-creation-flows/flow-d-reference.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/page-creation-flows/flow-e-html.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/page-creation-flows/lightweight-page-template.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/page-creation-flows/page-init-lightweight.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/page-creation-flows/page-process-templates.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/page-creation-flows/placeholder-templates.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/page-creation-flows/workshop-c-placeholder-pages.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/page-creation-flows/workshop-page-creation.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/page-creation-flows/workshop-page-process.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/quality-guide.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/scenario-init/01-platform-confirmation.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/scenario-init/02-feature-selection.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/scenario-init/03-entry-point.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/scenario-init/04-mental-state.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/scenario-init/05-mutual-success.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/scenario-init/06-shortest-path.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/scenario-init/07-reference-trigger-map.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/scenario-init/examples/booking-example.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/scenario-init/examples/ecommerce-example.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/scenario-init/examples/saas-example.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/scenario-init/scenario-init-dialog.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/scenario-init/scenario-init-guide.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/scenario-init/scenario-init-process.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/specification-audit-workflow.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/substeps-guide.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/data/validation-standards.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-c/step-01-exploration.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-h/step-01-detect-completion.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-h/step-02-create-delivery.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-h/step-03-create-test-scenario.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-h/step-04-handoff-dialog.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-h/step-05-hand-off.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-h/step-06-continue.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-k/step-01-sketch-analysis.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-m/step-01-review-current.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-m/step-02-define-component.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-m/step-03-validate-usage.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-p/step-01-page-basics.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-p/step-02-layout-sections.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-p/step-03-components-objects.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-p/step-04-content-languages.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-p/step-05-interactions.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-p/step-06-states.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-p/step-07-validation.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-p/step-08-spacing-typography.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-p/step-09-generate-spec.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-s/step-01-core-feature.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-s/step-02-entry-point.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-s/step-03-mental-state.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-s/step-04-mutual-success.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-s/step-05-shortest-path.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-s/step-06-scenario-name.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-s/step-07-create-scenario-folder.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-s/step-08-page-context.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-s/step-09-page-name.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-s/step-10-page-purpose.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-s/step-11-entry-point.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-s/step-12-mental-state.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-s/step-13-desired-outcome.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-s/step-14-variants.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-s/step-15-create-page-structure.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-v/step-01-page-metadata.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-v/step-02-navigation.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-v/step-03-page-overview.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-v/step-04-page-sections.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-v/step-05-section-order.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-v/step-06-object-registry.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-v/step-07-design-system-separation.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-v/step-08-seo-compliance.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-v/step-09-design-system-consistency.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-v/step-10-final-validation.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-w/step-00-nb-setup.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-w/step-01-visual-approach.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-w/step-02-generate-visual.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-w/step-02w-nb-compose-prompt.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/steps-w/step-03-review-integrate.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/templates/audit-report.template.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/templates/design-delivery.template.yaml` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/templates/diagnostic-report-template.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/templates/instructions/accessibility-audit.workflow.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/templates/instructions/accessibility.instructions.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/templates/instructions/data-api.instructions.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/templates/instructions/form-validation.instructions.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/templates/instructions/meta-content.instructions.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/templates/instructions/open-questions.instructions.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/templates/instructions/responsive.instructions.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/templates/instructions/seo-content.instructions.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/templates/page-specification.template.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/templates/scenario-overview.template.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/templates/storyboard-specification.template.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/templates/test-scenario.template.yaml` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/workflow-conceptualize.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/workflow-design-system.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/workflow-dream.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/workflow-handover.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/workflow-sketch.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/workflow-specify.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/workflow-specify.xml` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/workflow-suggest.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/workflow-validate.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/workflow-visual.md` — vendored-agent-tooling
- `.agents/skills/wds-4-ux-design/workflow.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/SKILL.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/data/guides/AGENTIC-DEVELOPMENT-GUIDE.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/data/guides/CREATION-GUIDE.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/data/guides/EXECUTION-PRINCIPLES.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/data/guides/FEEDBACK-PROTOCOL.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/data/guides/FILE-INDEX.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/data/guides/INLINE-TESTING-GUIDE.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/data/guides/PROTOTYPE-ANALYSIS.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/data/guides/PROTOTYPE-INITIATION-DIALOG.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/data/guides/SEO-VALIDATION-GUIDE.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/data/guides/SESSION-PROTOCOL.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/data/issue-templates.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/data/test-result-templates.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/data/testing-guide.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-a/step-01-define-question.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-a/step-02-scan-codebase.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-a/step-03-map-architecture.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-a/step-04-document-findings.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-d/step-01-scope-and-plan.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-d/step-02-setup-environment.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-d/step-03-implement.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-d/step-04-verify.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-d/step-05-finalize.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-e/step-01-scope-change.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-e/step-02-analyze-impact.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-e/step-03-plan-implementation.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-e/step-04-implement.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-e/step-05-verify-and-document.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-f/step-01-reproduce.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-f/step-02-investigate.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-f/step-03-fix.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-f/step-04-verify.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-f/step-05-document.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-p/1-prototype-setup.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-p/2-scenario-analysis.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-p/3-logical-view-breakdown.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-p/4a-announce-and-gather.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-p/4b-create-story-file.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-p/4c-implement-section.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-p/4d-present-for-testing.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-p/4e-handle-issue.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-p/4f-handle-improvement.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-p/4g-section-approved.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-p/5-finalization.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-r/step-01-identify-target.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-r/step-02-explore-and-capture.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-r/step-03-generate-specs.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-r/step-04-extract-design-system.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-t/step-01-prepare.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-t/step-02-execute.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-t/step-03-document-issues.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-t/step-04-report.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/steps-t/step-05-iterate.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/templates/PROTOTYPE-ROADMAP-template.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/templates/components/DEV-MODE-GUIDE.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/templates/components/dev-mode.css` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/templates/components/dev-mode.html` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/templates/components/dev-mode.js` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/templates/demo-data-template.json` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/templates/page-template.html` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/templates/story-file-template.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/templates/work-file-template.yaml` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/workflow-acceptance-testing.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/workflow-analysis.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/workflow-bugfixing.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/workflow-development.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/workflow-evolution.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/workflow-prototyping.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/workflow-reverse-engineering.md` — vendored-agent-tooling
- `.agents/skills/wds-5-agentic-development/workflow.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/SKILL.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/00-purpose-examples.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/03-action-filter-example.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/04-badass-users-principles.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/04-example-empowerment-frame.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/05-example-golden-circle.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/05-golden-circle-guide.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/06-example-hairdresser-newsletter.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/06-generation-instructions.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/content-creation-workshop-guide.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/figma-designer-guide.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/figma-integration-guide.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/figma-integration-summary.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/figma-mcp-integration.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/figma-plugin-setup.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/figma-spec-preparation.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/mcp-server-integration.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/prototype-to-figma-workflow.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/styles/content-styles/3d-render.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/styles/content-styles/comic-book.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/styles/content-styles/flat-design.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/styles/content-styles/hyper-realistic.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/styles/content-styles/illustration.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/styles/content-styles/isometric.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/styles/content-styles/line-art.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/styles/content-styles/pencil-sketch.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/styles/content-styles/photorealistic.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/styles/content-styles/watercolor.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/styles/design-styles/brutalist.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/styles/design-styles/corporate.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/styles/design-styles/editorial.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/styles/design-styles/minimal.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/styles/design-styles/organic.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/styles/design-styles/playful.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/tools-reference.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/data/when-to-extract-decision-guide.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-c/step-00-define-purpose.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-c/step-01-load-trigger-map-context.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-c/step-02-awareness-strategy.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-c/step-03-action-filter.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-c/step-04-empowerment-frame.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-c/step-05-structural-order.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-c/step-06-generate-content.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-f/step-01-connection-check.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-f/step-02-identify-export-type.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-f/step-03-prepare-specifications.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-f/step-04-generate-validate.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-f/step-05-execute-export.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-i/step-01-load-context.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-i/step-02-inventory.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-i/step-03-select-style.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-i/step-04-generate.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-i/step-05-review.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-m/step-01-load-context.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-m/step-02-inventory.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-m/step-03-select-style.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-m/step-04-references.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-m/step-05-generate.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-m/step-06-review.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-p/step-01-load-context.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-p/step-02-inventory.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-p/step-03-select-style.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-p/step-04-generate.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-p/step-05-review.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-u/step-01-load-context.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-u/step-02-inventory.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-u/step-03-select-style.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-u/step-04-generate.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-u/step-05-review.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-v/step-01-load-context.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-v/step-02-inventory.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-v/step-03-select-style.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-v/step-04-generate.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-v/step-05-review.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-w/step-01-load-context.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-w/step-02-inventory.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-w/step-03-select-style.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-w/step-04-generate.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/steps-w/step-05-review.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/templates/content-output.template.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/templates/stitch-prompt.template.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/workflow-content.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/workflow-figma.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/workflow-icons.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/workflow-images.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/workflow-page-designs.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/workflow-stitch.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/workflow-ui-elements.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/workflow-videos.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/workflow-wireframes.md` — vendored-agent-tooling
- `.agents/skills/wds-6-asset-generation/workflow.md` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/SKILL.md` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/data/design-system-guide.md` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/steps-c/step-01-scan-existing.md` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/steps-c/step-02-compare-attributes.md` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/steps-c/step-03-calculate-similarity.md` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/steps-c/step-04-identify-opportunities.md` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/steps-c/step-05-identify-risks.md` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/steps-c/step-06-present-decision.md` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/steps-c/step-07-execute-decision.md` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/steps-c/step-08a-initialize-design-system.md` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/steps-c/step-08b-create-new-component.md` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/steps-c/step-08c-update-component.md` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/steps-c/step-08d-add-variant.md` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/steps-c/step-08e-generate-catalog.md` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/templates/catalog.template.html` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/templates/component-library-config.template.md` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/templates/component.template.md` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/templates/design-tokens.template.md` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/workflow-browse.md` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/workflow-create.md` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/workflow-edit.md` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/workflow-import.md` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/workflow-view.md` — vendored-agent-tooling
- `.agents/skills/wds-7-design-system/workflow.md` — vendored-agent-tooling
- `.agents/skills/wds-8-product-evolution/SKILL.md` — vendored-agent-tooling
- `.agents/skills/wds-8-product-evolution/data/context-templates.md` — vendored-agent-tooling
- `.agents/skills/wds-8-product-evolution/data/delivery-templates.md` — vendored-agent-tooling
- `.agents/skills/wds-8-product-evolution/data/design-templates.md` — vendored-agent-tooling
- `.agents/skills/wds-8-product-evolution/data/existing-product-guide.md` — vendored-agent-tooling
- `.agents/skills/wds-8-product-evolution/data/kaizen-iteration-guide.md` — vendored-agent-tooling
- `.agents/skills/wds-8-product-evolution/data/kaizen-principles.md` — vendored-agent-tooling
- `.agents/skills/wds-8-product-evolution/data/monitoring-guide.md` — vendored-agent-tooling
- `.agents/skills/wds-8-product-evolution/data/monitoring-templates.md` — vendored-agent-tooling
- `.agents/skills/wds-8-product-evolution/steps-a/step-01-identify.md` — vendored-agent-tooling
- `.agents/skills/wds-8-product-evolution/steps-a/step-02-gather-context.md` — vendored-agent-tooling
- `.agents/skills/wds-8-product-evolution/steps-d/step-01-design-update.md` — vendored-agent-tooling
- `.agents/skills/wds-8-product-evolution/steps-p/step-01-create-delivery.md` — vendored-agent-tooling
- `.agents/skills/wds-8-product-evolution/steps-p/step-02-hand-off.md` — vendored-agent-tooling
- `.agents/skills/wds-8-product-evolution/steps-t/step-01-validate.md` — vendored-agent-tooling
- `.agents/skills/wds-8-product-evolution/workflow-analyze.md` — vendored-agent-tooling
- `.agents/skills/wds-8-product-evolution/workflow-deploy.md` — vendored-agent-tooling
- `.agents/skills/wds-8-product-evolution/workflow-design.md` — vendored-agent-tooling
- `.agents/skills/wds-8-product-evolution/workflow-implement.md` — vendored-agent-tooling
- `.agents/skills/wds-8-product-evolution/workflow-scope.md` — vendored-agent-tooling
- `.agents/skills/wds-8-product-evolution/workflow-test.md` — vendored-agent-tooling
- `.agents/skills/wds-8-product-evolution/workflow.md` — vendored-agent-tooling
- `.agents/skills/wds-agent-freya-ux/SKILL.md` — vendored-agent-tooling
- `.agents/skills/wds-agent-freya-ux/customize.toml` — vendored-agent-tooling
- `.agents/skills/wds-agent-mimir-builder/SKILL.md` — vendored-agent-tooling
- `.agents/skills/wds-agent-mimir-builder/customize.toml` — vendored-agent-tooling
- `.agents/skills/wds-agent-saga-analyst/SKILL.md` — vendored-agent-tooling
- `.agents/skills/wds-agent-saga-analyst/customize.toml` — vendored-agent-tooling
- `.claude/settings.json` — vendored-agent-tooling
- `.claude/skills/bmad-advanced-elicitation/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-advanced-elicitation/methods.csv` — vendored-agent-tooling
- `.claude/skills/bmad-analyst/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-architect/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-brainstorming/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-brainstorming/brain-methods.csv` — vendored-agent-tooling
- `.claude/skills/bmad-brainstorming/steps/step-01-session-setup.md` — vendored-agent-tooling
- `.claude/skills/bmad-brainstorming/steps/step-01b-continue.md` — vendored-agent-tooling
- `.claude/skills/bmad-brainstorming/steps/step-02a-user-selected.md` — vendored-agent-tooling
- `.claude/skills/bmad-brainstorming/steps/step-02b-ai-recommended.md` — vendored-agent-tooling
- `.claude/skills/bmad-brainstorming/steps/step-02c-random-selection.md` — vendored-agent-tooling
- `.claude/skills/bmad-brainstorming/steps/step-02d-progressive-flow.md` — vendored-agent-tooling
- `.claude/skills/bmad-brainstorming/steps/step-03-technique-execution.md` — vendored-agent-tooling
- `.claude/skills/bmad-brainstorming/steps/step-04-idea-organization.md` — vendored-agent-tooling
- `.claude/skills/bmad-brainstorming/template.md` — vendored-agent-tooling
- `.claude/skills/bmad-brainstorming/workflow.md` — vendored-agent-tooling
- `.claude/skills/bmad-check-implementation-readiness/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-code-review/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-correct-course/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-create-architecture/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-create-epics-and-stories/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-create-prd/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-create-story/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-create-story/checklist.md` — vendored-agent-tooling
- `.claude/skills/bmad-create-story/discover-inputs.md` — vendored-agent-tooling
- `.claude/skills/bmad-create-story/template.md` — vendored-agent-tooling
- `.claude/skills/bmad-dev-story/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-dev/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-document-project/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-domain-research/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-domain-research/domain-steps/step-01-init.md` — vendored-agent-tooling
- `.claude/skills/bmad-domain-research/domain-steps/step-02-domain-analysis.md` — vendored-agent-tooling
- `.claude/skills/bmad-domain-research/domain-steps/step-03-competitive-landscape.md` — vendored-agent-tooling
- `.claude/skills/bmad-domain-research/domain-steps/step-04-regulatory-focus.md` — vendored-agent-tooling
- `.claude/skills/bmad-domain-research/domain-steps/step-05-technical-trends.md` — vendored-agent-tooling
- `.claude/skills/bmad-domain-research/domain-steps/step-06-research-synthesis.md` — vendored-agent-tooling
- `.claude/skills/bmad-domain-research/research.template.md` — vendored-agent-tooling
- `.claude/skills/bmad-edit-prd/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-editorial-review-prose/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-editorial-review-structure/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-generate-project-context/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-help/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-index-docs/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-market-research/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-master/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-party-mode/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-pm/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-qa-generate-e2e-tests/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-qa/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-quick-dev/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-quick-flow-solo-dev/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-retrospective/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-review-adversarial-general/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-review-edge-case-hunter/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-shard-doc/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-sm/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-sprint-planning/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-sprint-status/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-tech-writer/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-technical-research/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-ux-designer/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-validate-prd/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-Modular Component Architecture/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-Object Type Router/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-acceptance-test/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-acceptance-testing/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-agentic-development/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-alignment-signoff/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-analysis/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-analyze-product/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-asset-generation/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-browse-design-system/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-bugfixing/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-content-creation/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-create-design-system/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-deploy/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-design-solution/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-design-system/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-development/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-edit-components/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-evolution/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-figma-integration/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-handover/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-icons/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-images/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-implement/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-import-design-system/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-page-designs/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-product-evolution/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-project-brief/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-project-setup/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-prototyping/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-reverse-engineering/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-scenarios-validate/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-scenarios/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-scope-improvement/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-stitch-generation/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-trigger-mapping-validate/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-trigger-mapping/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-ui-elements/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-ux-design/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-videos/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-view-components/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-wireframes/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-workflow-design-system/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-workflow-discuss/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-workflow-dream/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-workflow-sketch/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-workflow-specify/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-workflow-suggest/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-workflow-validate/SKILL.md` — vendored-agent-tooling
- `.claude/skills/bmad-wds-workflow-visual/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-advanced-elicitation/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-advanced-elicitation/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.cursor/skills/bmad-advanced-elicitation/methods.csv` — vendored-agent-tooling
- `.cursor/skills/bmad-advanced-elicitation/workflow.md` — vendored-agent-tooling
- `.cursor/skills/bmad-analyst/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-architect/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-brainstorming/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-brainstorming/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.cursor/skills/bmad-brainstorming/brain-methods.csv` — vendored-agent-tooling
- `.cursor/skills/bmad-brainstorming/steps/step-01-session-setup.md` — vendored-agent-tooling
- `.cursor/skills/bmad-brainstorming/steps/step-01b-continue.md` — vendored-agent-tooling
- `.cursor/skills/bmad-brainstorming/steps/step-02a-user-selected.md` — vendored-agent-tooling
- `.cursor/skills/bmad-brainstorming/steps/step-02b-ai-recommended.md` — vendored-agent-tooling
- `.cursor/skills/bmad-brainstorming/steps/step-02c-random-selection.md` — vendored-agent-tooling
- `.cursor/skills/bmad-brainstorming/steps/step-02d-progressive-flow.md` — vendored-agent-tooling
- `.cursor/skills/bmad-brainstorming/steps/step-03-technique-execution.md` — vendored-agent-tooling
- `.cursor/skills/bmad-brainstorming/steps/step-04-idea-organization.md` — vendored-agent-tooling
- `.cursor/skills/bmad-brainstorming/template.md` — vendored-agent-tooling
- `.cursor/skills/bmad-brainstorming/workflow.md` — vendored-agent-tooling
- `.cursor/skills/bmad-check-implementation-readiness/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-code-review/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-correct-course/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-create-architecture/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-create-epics-and-stories/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-create-prd/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-create-product-brief/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-create-story/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-create-story/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.cursor/skills/bmad-create-story/checklist.md` — vendored-agent-tooling
- `.cursor/skills/bmad-create-story/discover-inputs.md` — vendored-agent-tooling
- `.cursor/skills/bmad-create-story/template.md` — vendored-agent-tooling
- `.cursor/skills/bmad-create-story/workflow.md` — vendored-agent-tooling
- `.cursor/skills/bmad-create-ux-design/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-dev-story/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-dev/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-document-project/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-domain-research/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-domain-research/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.cursor/skills/bmad-domain-research/domain-steps/step-01-init.md` — vendored-agent-tooling
- `.cursor/skills/bmad-domain-research/domain-steps/step-02-domain-analysis.md` — vendored-agent-tooling
- `.cursor/skills/bmad-domain-research/domain-steps/step-03-competitive-landscape.md` — vendored-agent-tooling
- `.cursor/skills/bmad-domain-research/domain-steps/step-04-regulatory-focus.md` — vendored-agent-tooling
- `.cursor/skills/bmad-domain-research/domain-steps/step-05-technical-trends.md` — vendored-agent-tooling
- `.cursor/skills/bmad-domain-research/domain-steps/step-06-research-synthesis.md` — vendored-agent-tooling
- `.cursor/skills/bmad-domain-research/research.template.md` — vendored-agent-tooling
- `.cursor/skills/bmad-domain-research/workflow.md` — vendored-agent-tooling
- `.cursor/skills/bmad-edit-prd/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-editorial-review-prose/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-editorial-review-prose/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.cursor/skills/bmad-editorial-review-prose/workflow.md` — vendored-agent-tooling
- `.cursor/skills/bmad-editorial-review-structure/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-editorial-review-structure/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.cursor/skills/bmad-editorial-review-structure/workflow.md` — vendored-agent-tooling
- `.cursor/skills/bmad-generate-project-context/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-help/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-help/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.cursor/skills/bmad-help/workflow.md` — vendored-agent-tooling
- `.cursor/skills/bmad-index-docs/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-index-docs/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.cursor/skills/bmad-index-docs/workflow.md` — vendored-agent-tooling
- `.cursor/skills/bmad-market-research/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-master/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-party-mode/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-party-mode/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.cursor/skills/bmad-party-mode/steps/step-01-agent-loading.md` — vendored-agent-tooling
- `.cursor/skills/bmad-party-mode/steps/step-02-discussion-orchestration.md` — vendored-agent-tooling
- `.cursor/skills/bmad-party-mode/steps/step-03-graceful-exit.md` — vendored-agent-tooling
- `.cursor/skills/bmad-party-mode/workflow.md` — vendored-agent-tooling
- `.cursor/skills/bmad-pm/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-qa-generate-e2e-tests/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-qa/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-quick-dev-new-preview/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-quick-dev-new-preview/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.cursor/skills/bmad-quick-dev-new-preview/steps/step-01-clarify-and-route.md` — vendored-agent-tooling
- `.cursor/skills/bmad-quick-dev-new-preview/steps/step-02-plan.md` — vendored-agent-tooling
- `.cursor/skills/bmad-quick-dev-new-preview/steps/step-03-implement.md` — vendored-agent-tooling
- `.cursor/skills/bmad-quick-dev-new-preview/steps/step-04-review.md` — vendored-agent-tooling
- `.cursor/skills/bmad-quick-dev-new-preview/steps/step-05-present.md` — vendored-agent-tooling
- `.cursor/skills/bmad-quick-dev-new-preview/tech-spec-template.md` — vendored-agent-tooling
- `.cursor/skills/bmad-quick-dev-new-preview/workflow.md` — vendored-agent-tooling
- `.cursor/skills/bmad-quick-dev/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-quick-dev/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.cursor/skills/bmad-quick-dev/steps/step-01-mode-detection.md` — vendored-agent-tooling
- `.cursor/skills/bmad-quick-dev/steps/step-02-context-gathering.md` — vendored-agent-tooling
- `.cursor/skills/bmad-quick-dev/steps/step-03-execute.md` — vendored-agent-tooling
- `.cursor/skills/bmad-quick-dev/steps/step-04-self-check.md` — vendored-agent-tooling
- `.cursor/skills/bmad-quick-dev/steps/step-05-adversarial-review.md` — vendored-agent-tooling
- `.cursor/skills/bmad-quick-dev/steps/step-06-resolve-findings.md` — vendored-agent-tooling
- `.cursor/skills/bmad-quick-dev/workflow.md` — vendored-agent-tooling
- `.cursor/skills/bmad-quick-flow-solo-dev/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-quick-spec/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-retrospective/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-review-adversarial-general/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-review-adversarial-general/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.cursor/skills/bmad-review-adversarial-general/workflow.md` — vendored-agent-tooling
- `.cursor/skills/bmad-review-edge-case-hunter/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-review-edge-case-hunter/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.cursor/skills/bmad-review-edge-case-hunter/workflow.md` — vendored-agent-tooling
- `.cursor/skills/bmad-shard-doc/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-shard-doc/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.cursor/skills/bmad-shard-doc/workflow.md` — vendored-agent-tooling
- `.cursor/skills/bmad-sm/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-sprint-planning/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-sprint-status/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-tech-writer/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-technical-research/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-ux-designer/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-validate-prd/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-Modular Component Architecture/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-Object Type Router/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-acceptance-test/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-acceptance-testing/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-agentic-development/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-alignment-signoff/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-analysis/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-analyze-product/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-asset-generation/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-browse-design-system/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-bugfixing/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-content-creation/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-create-design-system/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-deploy/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-design-solution/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-design-system/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-development/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-edit-components/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-evolution/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-figma-integration/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-handover/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-icons/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-images/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-implement/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-import-design-system/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-page-designs/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-product-evolution/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-project-brief/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-project-setup/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-prototyping/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-reverse-engineering/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-scenarios-validate/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-scenarios/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-scope-improvement/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-stitch-generation/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-trigger-mapping-validate/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-trigger-mapping/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-ui-elements/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-ux-design/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-videos/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-view-components/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-wireframes/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-workflow-design-system/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-workflow-discuss/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-workflow-dream/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-workflow-sketch/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-workflow-specify/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-workflow-suggest/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-workflow-validate/SKILL.md` — vendored-agent-tooling
- `.cursor/skills/bmad-wds-workflow-visual/SKILL.md` — vendored-agent-tooling
- `.github/agents/bmad-agent-analyst.agent.md` — vendored-agent-tooling
- `.github/agents/bmad-agent-architect.agent.md` — vendored-agent-tooling
- `.github/agents/bmad-agent-dev.agent.md` — vendored-agent-tooling
- `.github/agents/bmad-agent-pm.agent.md` — vendored-agent-tooling
- `.github/agents/bmad-agent-tech-writer.agent.md` — vendored-agent-tooling
- `.github/agents/bmad-agent-ux-designer.agent.md` — vendored-agent-tooling
- `.github/agents/bmad-tea.agent.md` — vendored-agent-tooling
- `.github/agents/wds-agent-freya-ux.agent.md` — vendored-agent-tooling
- `.github/agents/wds-agent-mimir-builder.agent.md` — vendored-agent-tooling
- `.github/agents/wds-agent-saga-analyst.agent.md` — vendored-agent-tooling
- `.github/skills/bmad-advanced-elicitation/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-advanced-elicitation/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.github/skills/bmad-advanced-elicitation/methods.csv` — vendored-agent-tooling
- `.github/skills/bmad-advanced-elicitation/workflow.md` — vendored-agent-tooling
- `.github/skills/bmad-analyst/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-architect/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-brainstorming/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-brainstorming/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.github/skills/bmad-brainstorming/brain-methods.csv` — vendored-agent-tooling
- `.github/skills/bmad-brainstorming/steps/step-01-session-setup.md` — vendored-agent-tooling
- `.github/skills/bmad-brainstorming/steps/step-01b-continue.md` — vendored-agent-tooling
- `.github/skills/bmad-brainstorming/steps/step-02a-user-selected.md` — vendored-agent-tooling
- `.github/skills/bmad-brainstorming/steps/step-02b-ai-recommended.md` — vendored-agent-tooling
- `.github/skills/bmad-brainstorming/steps/step-02c-random-selection.md` — vendored-agent-tooling
- `.github/skills/bmad-brainstorming/steps/step-02d-progressive-flow.md` — vendored-agent-tooling
- `.github/skills/bmad-brainstorming/steps/step-03-technique-execution.md` — vendored-agent-tooling
- `.github/skills/bmad-brainstorming/steps/step-04-idea-organization.md` — vendored-agent-tooling
- `.github/skills/bmad-brainstorming/template.md` — vendored-agent-tooling
- `.github/skills/bmad-brainstorming/workflow.md` — vendored-agent-tooling
- `.github/skills/bmad-check-implementation-readiness/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-code-review/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-correct-course/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-create-architecture/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-create-epics-and-stories/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-create-prd/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-create-product-brief/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-create-story/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-create-story/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.github/skills/bmad-create-story/checklist.md` — vendored-agent-tooling
- `.github/skills/bmad-create-story/discover-inputs.md` — vendored-agent-tooling
- `.github/skills/bmad-create-story/template.md` — vendored-agent-tooling
- `.github/skills/bmad-create-story/workflow.md` — vendored-agent-tooling
- `.github/skills/bmad-create-ux-design/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-dev-story/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-dev/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-document-project/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-domain-research/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-domain-research/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.github/skills/bmad-domain-research/domain-steps/step-01-init.md` — vendored-agent-tooling
- `.github/skills/bmad-domain-research/domain-steps/step-02-domain-analysis.md` — vendored-agent-tooling
- `.github/skills/bmad-domain-research/domain-steps/step-03-competitive-landscape.md` — vendored-agent-tooling
- `.github/skills/bmad-domain-research/domain-steps/step-04-regulatory-focus.md` — vendored-agent-tooling
- `.github/skills/bmad-domain-research/domain-steps/step-05-technical-trends.md` — vendored-agent-tooling
- `.github/skills/bmad-domain-research/domain-steps/step-06-research-synthesis.md` — vendored-agent-tooling
- `.github/skills/bmad-domain-research/research.template.md` — vendored-agent-tooling
- `.github/skills/bmad-domain-research/workflow.md` — vendored-agent-tooling
- `.github/skills/bmad-edit-prd/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-editorial-review-prose/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-editorial-review-prose/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.github/skills/bmad-editorial-review-prose/workflow.md` — vendored-agent-tooling
- `.github/skills/bmad-editorial-review-structure/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-editorial-review-structure/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.github/skills/bmad-editorial-review-structure/workflow.md` — vendored-agent-tooling
- `.github/skills/bmad-generate-project-context/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-help/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-help/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.github/skills/bmad-help/workflow.md` — vendored-agent-tooling
- `.github/skills/bmad-index-docs/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-index-docs/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.github/skills/bmad-index-docs/workflow.md` — vendored-agent-tooling
- `.github/skills/bmad-market-research/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-master/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-party-mode/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-party-mode/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.github/skills/bmad-party-mode/steps/step-01-agent-loading.md` — vendored-agent-tooling
- `.github/skills/bmad-party-mode/steps/step-02-discussion-orchestration.md` — vendored-agent-tooling
- `.github/skills/bmad-party-mode/steps/step-03-graceful-exit.md` — vendored-agent-tooling
- `.github/skills/bmad-party-mode/workflow.md` — vendored-agent-tooling
- `.github/skills/bmad-pm/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-qa-generate-e2e-tests/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-qa/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-quick-dev-new-preview/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-quick-dev-new-preview/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.github/skills/bmad-quick-dev-new-preview/steps/step-01-clarify-and-route.md` — vendored-agent-tooling
- `.github/skills/bmad-quick-dev-new-preview/steps/step-02-plan.md` — vendored-agent-tooling
- `.github/skills/bmad-quick-dev-new-preview/steps/step-03-implement.md` — vendored-agent-tooling
- `.github/skills/bmad-quick-dev-new-preview/steps/step-04-review.md` — vendored-agent-tooling
- `.github/skills/bmad-quick-dev-new-preview/steps/step-05-present.md` — vendored-agent-tooling
- `.github/skills/bmad-quick-dev-new-preview/tech-spec-template.md` — vendored-agent-tooling
- `.github/skills/bmad-quick-dev-new-preview/workflow.md` — vendored-agent-tooling
- `.github/skills/bmad-quick-dev/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-quick-dev/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.github/skills/bmad-quick-dev/steps/step-01-mode-detection.md` — vendored-agent-tooling
- `.github/skills/bmad-quick-dev/steps/step-02-context-gathering.md` — vendored-agent-tooling
- `.github/skills/bmad-quick-dev/steps/step-03-execute.md` — vendored-agent-tooling
- `.github/skills/bmad-quick-dev/steps/step-04-self-check.md` — vendored-agent-tooling
- `.github/skills/bmad-quick-dev/steps/step-05-adversarial-review.md` — vendored-agent-tooling
- `.github/skills/bmad-quick-dev/steps/step-06-resolve-findings.md` — vendored-agent-tooling
- `.github/skills/bmad-quick-dev/workflow.md` — vendored-agent-tooling
- `.github/skills/bmad-quick-flow-solo-dev/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-quick-spec/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-retrospective/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-review-adversarial-general/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-review-adversarial-general/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.github/skills/bmad-review-adversarial-general/workflow.md` — vendored-agent-tooling
- `.github/skills/bmad-review-edge-case-hunter/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-review-edge-case-hunter/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.github/skills/bmad-review-edge-case-hunter/workflow.md` — vendored-agent-tooling
- `.github/skills/bmad-shard-doc/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-shard-doc/bmad-skill-manifest.yaml` — vendored-agent-tooling
- `.github/skills/bmad-shard-doc/workflow.md` — vendored-agent-tooling
- `.github/skills/bmad-sm/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-sprint-planning/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-sprint-status/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-tech-writer/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-technical-research/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-ux-designer/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-validate-prd/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-Modular Component Architecture/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-Object Type Router/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-acceptance-test/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-acceptance-testing/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-agentic-development/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-alignment-signoff/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-analysis/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-analyze-product/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-asset-generation/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-browse-design-system/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-bugfixing/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-content-creation/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-create-design-system/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-deploy/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-design-solution/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-design-system/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-development/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-edit-components/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-evolution/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-figma-integration/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-handover/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-icons/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-images/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-implement/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-import-design-system/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-page-designs/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-product-evolution/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-project-brief/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-project-setup/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-prototyping/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-reverse-engineering/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-scenarios-validate/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-scenarios/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-scope-improvement/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-stitch-generation/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-trigger-mapping-validate/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-trigger-mapping/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-ui-elements/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-ux-design/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-videos/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-view-components/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-wireframes/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-workflow-design-system/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-workflow-discuss/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-workflow-dream/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-workflow-sketch/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-workflow-specify/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-workflow-suggest/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-workflow-validate/SKILL.md` — vendored-agent-tooling
- `.github/skills/bmad-wds-workflow-visual/SKILL.md` — vendored-agent-tooling
- `LICENSE` — lockfile/license
- `_bmad-output/adversarial-review-report.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/orchestration-log.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/refactor-bug-fix-verification.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/refactor-hardcoded-placeholder-audit.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/refactor-manual-smoke-checklist.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/refactor-orchestration-log.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/refactor-progress-aggregator-analysis.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/refactor-s1-log.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/refactor-s2-log.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/refactor-s3-log.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/refactor-s4-log.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/refactor-s5-log.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/refactor-task-tracker.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/refactor-v1-ci-report.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/refactor-v2-r1-sync-data-findings.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/refactor-v2-r2-domain-findings.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/refactor-v2-r3-tutor-findings.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/refactor-v2-r4-class-quality-findings.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/refactor-v2-r5-cross-cutting-findings.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/refactor-v2-r6-tests-ci-findings.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/refactor-v3-fix-pass-log.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/refactor-v5-a-truth-report.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/refactor-v5-b-truth-report.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/refactor-v5-c-truth-report.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/refactor-wake-up-summary.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/review/epic_24.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/review/epic_25.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/review/epic_26.md` — superseded-output-dir (hygiene finding)
- `_bmad-output/review/epic_27.md` — superseded-output-dir (hygiene finding)
- `_bmad/_config/agent-manifest.csv` — vendored-agent-tooling
- `_bmad/_config/agents/bmm-analyst.customize.yaml` — vendored-agent-tooling
- `_bmad/_config/agents/bmm-architect.customize.yaml` — vendored-agent-tooling
- `_bmad/_config/agents/bmm-dev.customize.yaml` — vendored-agent-tooling
- `_bmad/_config/agents/bmm-pm.customize.yaml` — vendored-agent-tooling
- `_bmad/_config/agents/bmm-qa.customize.yaml` — vendored-agent-tooling
- `_bmad/_config/agents/bmm-quick-flow-solo-dev.customize.yaml` — vendored-agent-tooling
- `_bmad/_config/agents/bmm-sm.customize.yaml` — vendored-agent-tooling
- `_bmad/_config/agents/bmm-tech-writer.customize.yaml` — vendored-agent-tooling
- `_bmad/_config/agents/bmm-ux-designer.customize.yaml` — vendored-agent-tooling
- `_bmad/_config/agents/core-bmad-master.customize.yaml` — vendored-agent-tooling
- `_bmad/_config/agents/wds-freya-ux.customize.yaml` — vendored-agent-tooling
- `_bmad/_config/agents/wds-saga-analyst.customize.yaml` — vendored-agent-tooling
- `_bmad/_config/bmad-help.csv` — vendored-agent-tooling
- `_bmad/_config/files-manifest.csv` — vendored-agent-tooling
- `_bmad/_config/ides/claude-code.yaml` — vendored-agent-tooling
- `_bmad/_config/ides/codex.yaml` — vendored-agent-tooling
- `_bmad/_config/ides/cursor.yaml` — vendored-agent-tooling
- `_bmad/_config/ides/github-copilot.yaml` — vendored-agent-tooling
- `_bmad/_config/manifest.yaml` — vendored-agent-tooling
- `_bmad/_config/skill-manifest.csv` — vendored-agent-tooling
- `_bmad/_config/task-manifest.csv` — vendored-agent-tooling
- `_bmad/_config/tool-manifest.csv` — vendored-agent-tooling
- `_bmad/_config/workflow-manifest.csv` — vendored-agent-tooling
- `_bmad/_memory/config.yaml` — vendored-agent-tooling
- `_bmad/_memory/tech-writer-sidecar/documentation-standards.md` — vendored-agent-tooling
- `_bmad/bmm/config.yaml` — vendored-agent-tooling
- `_bmad/bmm/module-help.csv` — vendored-agent-tooling
- `_bmad/bmm/workflows/3-solutioning/create-epics-and-stories/steps/step-02-design-epics.md.bak` — vendored-agent-tooling
- `_bmad/bmm/workflows/3-solutioning/create-epics-and-stories/steps/step-03-create-stories.md.bak` — vendored-agent-tooling
- `_bmad/bmm/workflows/3-solutioning/create-epics-and-stories/steps/step-04-final-validation.md.bak` — vendored-agent-tooling
- `_bmad/bmm/workflows/4-implementation/bmad-create-story/workflow.md.bak` — vendored-agent-tooling
- `_bmad/bmm/workflows/4-implementation/code-review/workflow.md.bak` — vendored-agent-tooling
- `_bmad/bmm/workflows/4-implementation/correct-course/workflow.md.bak` — vendored-agent-tooling
- `_bmad/bmm/workflows/4-implementation/dev-story/workflow.md.bak` — vendored-agent-tooling
- `_bmad/bmm/workflows/4-implementation/retrospective/workflow.md.bak` — vendored-agent-tooling
- `_bmad/bmm/workflows/4-implementation/sprint-planning/workflow.md.bak` — vendored-agent-tooling
- `_bmad/bmm/workflows/4-implementation/sprint-status/workflow.md.bak` — vendored-agent-tooling
- `_bmad/config.toml` — vendored-agent-tooling
- `_bmad/config.user.toml` — vendored-agent-tooling
- `_bmad/core/config.yaml` — vendored-agent-tooling
- `_bmad/core/module-help.csv` — vendored-agent-tooling
- `_bmad/custom/.gitignore` — vendored-agent-tooling
- `_bmad/custom/config.toml` — vendored-agent-tooling
- `_bmad/scripts/resolve_config.py` — vendored-agent-tooling
- `_bmad/scripts/resolve_customization.py` — vendored-agent-tooling
- `_bmad/scripts/tests/test_resolve_customization.py` — vendored-agent-tooling
- `_bmad/tea/config.yaml` — vendored-agent-tooling
- `_bmad/tea/module-help.csv` — vendored-agent-tooling
- `_bmad/tea/workflows/testarch/README.md` — vendored-agent-tooling
- `_bmad/wds/config.yaml` — vendored-agent-tooling
- `_bmad/wds/data/agent-contracts.md` — vendored-agent-tooling
- `_bmad/wds/data/agent-guides/freya/agentic-development.md` — vendored-agent-tooling
- `_bmad/wds/data/agent-guides/freya/content-creation.md` — vendored-agent-tooling
- `_bmad/wds/data/agent-guides/freya/design-system.md` — vendored-agent-tooling
- `_bmad/wds/data/agent-guides/freya/meta-content-guide.md` — vendored-agent-tooling
- `_bmad/wds/data/agent-guides/freya/specification-quality.md` — vendored-agent-tooling
- `_bmad/wds/data/agent-guides/freya/strategic-design.md` — vendored-agent-tooling
- `_bmad/wds/data/agent-guides/saga/content-structure-principles.md` — vendored-agent-tooling
- `_bmad/wds/data/agent-guides/saga/conversational-followups.md` — vendored-agent-tooling
- `_bmad/wds/data/agent-guides/saga/discovery-conversation.md` — vendored-agent-tooling
- `_bmad/wds/data/agent-guides/saga/dream-up-approach.md` — vendored-agent-tooling
- `_bmad/wds/data/agent-guides/saga/inspiration-analysis.md` — vendored-agent-tooling
- `_bmad/wds/data/agent-guides/saga/resources/project-brief.template.md` — vendored-agent-tooling
- `_bmad/wds/data/agent-guides/saga/seo-strategy-guide.md` — vendored-agent-tooling
- `_bmad/wds/data/agent-guides/saga/strategic-documentation.md` — vendored-agent-tooling
- `_bmad/wds/data/agent-guides/saga/trigger-mapping.md` — vendored-agent-tooling
- `_bmad/wds/data/agent-guides/saga/working-with-existing-materials.md` — vendored-agent-tooling
- `_bmad/wds/data/design-system/component-boundaries.md` — vendored-agent-tooling
- `_bmad/wds/data/design-system/figma-component-structure.md` — vendored-agent-tooling
- `_bmad/wds/data/design-system/naming-conventions.md` — vendored-agent-tooling
- `_bmad/wds/data/design-system/state-management.md` — vendored-agent-tooling
- `_bmad/wds/data/design-system/token-architecture.md` — vendored-agent-tooling
- `_bmad/wds/data/design-system/validation-patterns.md` — vendored-agent-tooling
- `_bmad/wds/data/presentations/freya-how-i-help.md` — vendored-agent-tooling
- `_bmad/wds/data/presentations/freya-intro.md` — vendored-agent-tooling
- `_bmad/wds/data/presentations/freya-presentation.md` — vendored-agent-tooling
- `_bmad/wds/data/presentations/freya-workflows-guide.md` — vendored-agent-tooling
- `_bmad/wds/data/presentations/mimir-agents-overview.md` — vendored-agent-tooling
- `_bmad/wds/data/presentations/mimir-tone-setting.md` — vendored-agent-tooling
- `_bmad/wds/data/presentations/saga-how-i-help.md` — vendored-agent-tooling
- `_bmad/wds/data/presentations/saga-intro.md` — vendored-agent-tooling
- `_bmad/wds/data/presentations/saga-presentation.md` — vendored-agent-tooling
- `_bmad/wds/data/presentations/saga-workflows-guide.md` — vendored-agent-tooling
- `_bmad/wds/data/shared-activation.md` — vendored-agent-tooling
- `_bmad/wds/data/wds-glossary.md` — vendored-agent-tooling
- `_bmad/wds/module-help.csv` — vendored-agent-tooling
- `_bmad/wds/scripts/README.md` — vendored-agent-tooling
- `_bmad/wds/scripts/wds-add-object.js` — vendored-agent-tooling
- `_bmad/wds/scripts/wds-add-spacing.js` — vendored-agent-tooling
- `_bmad/wds/scripts/wds-init-page.js` — vendored-agent-tooling
- `_bmad/wds/scripts/wds-init-scenario.js` — vendored-agent-tooling
- `_bmad/wds/scripts/wds-nav.js` — vendored-agent-tooling
- `_bmad/wds/scripts/wds-validate.js` — vendored-agent-tooling
- `_bmad/wds/skills/freya.activation.md` — vendored-agent-tooling
- `_bmad/wds/skills/handoff.md` — vendored-agent-tooling
- `_bmad/wds/skills/saga.activation.md` — vendored-agent-tooling
- `_bmad/wds/skills/shared/git.md` — vendored-agent-tooling
- `_bmad/wds/skills/start.md` — vendored-agent-tooling
- `_bmad/wds/skills/wrap.md` — vendored-agent-tooling
- `app-icon.png` — accidental/binary artifact (hygiene finding)
- `build/calendar_build.log` — accidental/binary artifact (hygiene finding)
- `build/seed.db` — accidental/binary artifact (hygiene finding)
- `build/seed.db.xz` — accidental/binary artifact (hygiene finding)
- `clear` — accidental/binary artifact (hygiene finding)
- `docs/_archive/README.md` — archived/test-artifact per Part C
- `docs/_archive/epic-qa-reports/QA_CHECKLIST_DNI32.md` — archived/test-artifact per Part C
- `docs/_archive/epic-qa-reports/coverage-report-dni-122.md` — archived/test-artifact per Part C
- `docs/_archive/epic-qa-reports/epic-1-qa-report.md` — archived/test-artifact per Part C
- `docs/_archive/epic-qa-reports/epic-4-retrospective-2026-03-12.md` — archived/test-artifact per Part C
- `docs/_archive/scrapped-ideas/epic-15-multi-profile-original-stories.md` — archived/test-artifact per Part C
- `docs/_archive/scrapped-ideas/school-and-tutor-tracks.md` — archived/test-artifact per Part C
- `docs/_archive/scrapped-ideas/tutor-companion-app.md` — archived/test-artifact per Part C
- `docs/_archive/scrapped-ideas/tutor-mode-epic-11.md` — archived/test-artifact per Part C
- `docs/_archive/superseded/architecture-v1-2026-01-04.md` — archived/test-artifact per Part C
- `docs/_archive/superseded/component-specifications-2026-02-11.md` — archived/test-artifact per Part C
- `docs/_archive/superseded/development-handoff-2026-02-11.md` — archived/test-artifact per Part C
- `docs/_archive/superseded/epic-15-stories/15.1-multi-profile-data-model.md` — archived/test-artifact per Part C
- `docs/_archive/superseded/epic-15-stories/15.10-dirshu-test-tracking.md` — archived/test-artifact per Part C
- `docs/_archive/superseded/epic-15-stories/15.11-profile-scoped-providers-sync.md` — archived/test-artifact per Part C
- `docs/_archive/superseded/epic-15-stories/15.12-appbar-fittedbox-fix.md` — archived/test-artifact per Part C
- `docs/_archive/superseded/epic-15-stories/15.13-cloud-content-storage.md` — archived/test-artifact per Part C
- `docs/_archive/superseded/epic-15-stories/15.14-test-suite-health.md` — archived/test-artifact per Part C
- `docs/_archive/superseded/epic-15-stories/15.2-profile-picker-management-ui.md` — archived/test-artifact per Part C
- `docs/_archive/superseded/epic-15-stories/15.3-new-curricula-support.md` — archived/test-artifact per Part C
- `docs/_archive/superseded/epic-15-stories/15.4-learning-program-presets.md` — archived/test-artifact per Part C
- `docs/_archive/superseded/epic-15-stories/15.5-expanded-stage-scheduling.md` — archived/test-artifact per Part C
- `docs/_archive/superseded/epic-15-stories/15.6-learning-process-wizard.md` — archived/test-artifact per Part C
- `docs/_archive/superseded/epic-15-stories/15.7-enhanced-bulk-mark.md` — archived/test-artifact per Part C
- `docs/_archive/superseded/epic-15-stories/15.8-revised-onboarding-flow.md` — archived/test-artifact per Part C
- `docs/_archive/superseded/epic-15-stories/15.9-program-management-settings.md` — archived/test-artifact per Part C
- `docs/_archive/superseded/product-brief-2026-01-03.md` — archived/test-artifact per Part C
- `docs/_archive/superseded/tech-spec-wip-2026-03-17.md` — archived/test-artifact per Part C
- `docs/_archive/superseded/ux-design-specification-2026-02-11.md` — archived/test-artifact per Part C
- `docs/_archive/tooling-notes/AGENTS.md` — archived/test-artifact per Part C
- `docs/_archive/tooling-notes/VALIDATION_NOTES.md` — archived/test-artifact per Part C
- `docs/_archive/tooling-notes/app_architecture.eraserdiagram` — archived/test-artifact per Part C
- `docs/_archive/tooling-notes/app_flow.md` — archived/test-artifact per Part C
- `docs/_archive/tooling-notes/bmad-progress/00-design-log.md` — archived/test-artifact per Part C
- `docs/_archive/tooling-notes/project-context.md` — archived/test-artifact per Part C
- `docs/_archive/tooling-notes/project-scan-report.json` — archived/test-artifact per Part C
- `docs/_archive/tooling-notes/ux-design-directions.html` — archived/test-artifact per Part C
- `docs/test-artifacts/bulk-fix-plan-2026-06-11.md` — archived/test-artifact per Part C
- `docs/test-artifacts/device-audit-run2/_REPORT.md` — archived/test-artifact per Part C
- `docs/test-artifacts/device-audit-run3/_REPORT.md` — archived/test-artifact per Part C
- `docs/test-artifacts/device-audit-run4/_REPORT.md` — archived/test-artifact per Part C
- `docs/test-artifacts/device-audit-run5/_REPORT.md` — archived/test-artifact per Part C
- `docs/test-artifacts/device-audit-run6/_REPORT.md` — archived/test-artifact per Part C
- `docs/test-artifacts/device-audit-run7/_REPORT.md` — archived/test-artifact per Part C
- `docs/test-artifacts/device-audit/_REPORT.md` — archived/test-artifact per Part C
- `docs/test-artifacts/device-audit/_TRIAGE.md` — archived/test-artifact per Part C
- `docs/test-artifacts/device-audit/findings_5554.md` — archived/test-artifact per Part C
- `docs/test-artifacts/device-audit/findings_5560.md` — archived/test-artifact per Part C
- `docs/test-artifacts/device-audit/findings_5562.md` — archived/test-artifact per Part C
- `docs/test-artifacts/e2e-test-design-2026-06-09.md` — archived/test-artifact per Part C
- `docs/test-artifacts/recalibration-detectability-2026-06-10.md` — archived/test-artifact per Part C
- `docs/test-artifacts/vision-findings/_ALL.json` — archived/test-artifact per Part C
- `docs/test-artifacts/vision-findings/batch01.json` — archived/test-artifact per Part C
- `docs/test-artifacts/vision-findings/batch02.json` — archived/test-artifact per Part C
- `docs/test-artifacts/vision-findings/batch03.json` — archived/test-artifact per Part C
- `docs/test-artifacts/vision-findings/batch04.json` — archived/test-artifact per Part C
- `docs/test-artifacts/vision-findings/batch05.json` — archived/test-artifact per Part C
- `docs/test-artifacts/vision-findings/batch06.json` — archived/test-artifact per Part C
- `docs/test-artifacts/vision-findings/redo_R1.json` — archived/test-artifact per Part C
- `learning_tracker/android/app/src/main/res/drawable-hdpi/android12splash.png` — binary asset
- `learning_tracker/android/app/src/main/res/drawable-mdpi/android12splash.png` — binary asset
- `learning_tracker/android/app/src/main/res/drawable-night-hdpi/android12splash.png` — binary asset
- `learning_tracker/android/app/src/main/res/drawable-night-mdpi/android12splash.png` — binary asset
- `learning_tracker/android/app/src/main/res/drawable-night-xhdpi/android12splash.png` — binary asset
- `learning_tracker/android/app/src/main/res/drawable-night-xxhdpi/android12splash.png` — binary asset
- `learning_tracker/android/app/src/main/res/drawable-night-xxxhdpi/android12splash.png` — binary asset
- `learning_tracker/android/app/src/main/res/drawable-v21/background.png` — binary asset
- `learning_tracker/android/app/src/main/res/drawable-xhdpi/android12splash.png` — binary asset
- `learning_tracker/android/app/src/main/res/drawable-xxhdpi/android12splash.png` — binary asset
- `learning_tracker/android/app/src/main/res/drawable-xxxhdpi/android12splash.png` — binary asset
- `learning_tracker/android/app/src/main/res/drawable/background.png` — binary asset
- `learning_tracker/android/app/src/main/res/mipmap-hdpi/ic_launcher.png` — binary asset
- `learning_tracker/android/app/src/main/res/mipmap-mdpi/ic_launcher.png` — binary asset
- `learning_tracker/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` — binary asset
- `learning_tracker/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` — binary asset
- `learning_tracker/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` — binary asset
- `learning_tracker/assets/content/hierarchy/arukh_hashulchan.json` — content/data asset or cache
- `learning_tracker/assets/content/hierarchy/bavli.json` — content/data asset or cache
- `learning_tracker/assets/content/hierarchy/chofetz_chaim.json` — content/data asset or cache
- `learning_tracker/assets/content/hierarchy/chumash.json` — content/data asset or cache
- `learning_tracker/assets/content/hierarchy/kitzur_shulchan_aruch.json` — content/data asset or cache
- `learning_tracker/assets/content/hierarchy/mishna_berurah.json` — content/data asset or cache
- `learning_tracker/assets/content/hierarchy/mishnayos.json` — content/data asset or cache
- `learning_tracker/assets/content/hierarchy/mishneh_torah.json` — content/data asset or cache
- `learning_tracker/assets/content/hierarchy/mussar.json` — content/data asset or cache
- `learning_tracker/assets/content/hierarchy/nach.json` — content/data asset or cache
- `learning_tracker/assets/content/hierarchy/pirkei_avot.json` — content/data asset or cache
- `learning_tracker/assets/content/hierarchy/sefer_hamitzvot.json` — content/data asset or cache
- `learning_tracker/assets/content/hierarchy/shemirat_halashon.json` — content/data asset or cache
- `learning_tracker/assets/content/hierarchy/shulchan_arukh.json` — content/data asset or cache
- `learning_tracker/assets/content/hierarchy/yerushalmi.json` — content/data asset or cache
- `learning_tracker/assets/data/NOTICE.txt` — content/data asset or cache
- `learning_tracker/assets/data/cities.sqlite` — content/data asset or cache
- `learning_tracker/assets/db/content.db.xz` — binary asset
- `learning_tracker/assets/fonts/.gitkeep` — content/data asset or cache
- `learning_tracker/assets/fonts/Inter-Bold.ttf` — binary asset
- `learning_tracker/assets/fonts/Inter-ExtraBold.ttf` — binary asset
- `learning_tracker/assets/fonts/Inter-ExtraLight.ttf` — binary asset
- `learning_tracker/assets/fonts/Inter-Light.ttf` — binary asset
- `learning_tracker/assets/fonts/Inter-Medium.ttf` — binary asset
- `learning_tracker/assets/fonts/Inter-Regular.ttf` — binary asset
- `learning_tracker/assets/fonts/Inter-SemiBold.ttf` — binary asset
- `learning_tracker/assets/fonts/NotoSansHebrew-Bold.ttf` — binary asset
- `learning_tracker/assets/fonts/NotoSansHebrew-Light.ttf` — binary asset
- `learning_tracker/assets/fonts/NotoSansHebrew-Medium.ttf` — binary asset
- `learning_tracker/assets/fonts/NotoSansHebrew-Regular.ttf` — binary asset
- `learning_tracker/assets/fonts/NotoSansHebrew-SemiBold.ttf` — binary asset
- `learning_tracker/assets/fonts/PlusJakartaSans-Bold.ttf` — binary asset
- `learning_tracker/assets/fonts/PlusJakartaSans-ExtraBold.ttf` — binary asset
- `learning_tracker/assets/fonts/PlusJakartaSans-ExtraLight.ttf` — binary asset
- `learning_tracker/assets/fonts/PlusJakartaSans-Light.ttf` — binary asset
- `learning_tracker/assets/fonts/PlusJakartaSans-Medium.ttf` — binary asset
- `learning_tracker/assets/fonts/PlusJakartaSans-Regular.ttf` — binary asset
- `learning_tracker/assets/fonts/PlusJakartaSans-SemiBold.ttf` — binary asset
- `learning_tracker/assets/fonts/README.md` — content/data asset or cache
- `learning_tracker/assets/images/.gitkeep` — content/data asset or cache
- `learning_tracker/assets/images/README.md` — content/data asset or cache
- `learning_tracker/assets/images/icon.png` — binary asset
- `learning_tracker/assets/images/splash_background.png` — binary asset
- `learning_tracker/flutter_01.png` — binary asset
- `learning_tracker/functions/package-lock.json` — lockfile/license
- `learning_tracker/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@1x.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@2x.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@1x.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@2x.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@1x.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@2x.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/LaunchBackground.imageset/background.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png` — binary asset
- `learning_tracker/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png` — binary asset
- `learning_tracker/pubspec.lock` — lockfile/license
- `learning_tracker/test/golden/goldens/phone_1_dashboard.png` — binary asset
- `learning_tracker/test/golden/goldens/phone_2_learning.png` — binary asset
- `learning_tracker/test/golden/goldens/phone_3_progress.png` — binary asset
- `learning_tracker/test/golden/goldens/phone_4_scheduler.png` — binary asset
- `learning_tracker/test/golden/goldens/phone_5_gamification.png` — binary asset
- `learning_tracker/tool/data/README.md` — content/data asset or cache
- `learning_tracker/tool/data/curriculum_books.json` — content/data asset or cache
- `learning_tracker/tool/data/hebcal_calendar_cache.json` — content/data asset or cache
- `learning_tracker/tool/data/sefaria_calendar_cache.json` — content/data asset or cache
- `memory/MEMORY.md` — vendored-agent-tooling
- `memory/feedback_toolchain_path.md` — vendored-agent-tooling
- `memory/project_deploy_process.md` — vendored-agent-tooling
- `memory/project_track_detail_feature.md` — vendored-agent-tooling
- `package-lock.json` — lockfile/license
- `packages/custom_lints/pubspec.lock` — lockfile/license
- `store_assets/app_icon_512.png` — vendored-agent-tooling
- `store_assets/feature_graphic_1024x500.png` — vendored-agent-tooling
- `store_assets/phone_1_dashboard.png` — vendored-agent-tooling
- `store_assets/phone_2_learning.png` — vendored-agent-tooling
- `store_assets/phone_3_progress.png` — vendored-agent-tooling
- `store_assets/phone_4_scheduler.png` — vendored-agent-tooling
- `store_assets/phone_5_gamification.png` — vendored-agent-tooling
- `store_assets/screenshots/phone_1_dashboard.png` — vendored-agent-tooling
- `store_assets/screenshots/phone_2_learning.png` — vendored-agent-tooling
- `store_assets/screenshots/phone_3_progress.png` — vendored-agent-tooling
- `store_assets/screenshots/phone_4_scheduler.png` — vendored-agent-tooling
- `store_assets/screenshots/phone_5_gamification.png` — vendored-agent-tooling
- `store_assets/store_listing.txt` — vendored-agent-tooling
- `store_assets/tablet_10inch_phone_1_dashboard.png` — vendored-agent-tooling
- `store_assets/tablet_10inch_phone_2_learning.png` — vendored-agent-tooling
- `store_assets/tablet_10inch_phone_3_progress.png` — vendored-agent-tooling
- `store_assets/tablet_10inch_phone_4_scheduler.png` — vendored-agent-tooling
- `store_assets/tablet_10inch_phone_5_gamification.png` — vendored-agent-tooling
- `store_assets/tablet_7inch_phone_1_dashboard.png` — vendored-agent-tooling
- `store_assets/tablet_7inch_phone_2_learning.png` — vendored-agent-tooling
- `store_assets/tablet_7inch_phone_3_progress.png` — vendored-agent-tooling
- `store_assets/tablet_7inch_phone_4_scheduler.png` — vendored-agent-tooling
- `store_assets/tablet_7inch_phone_5_gamification.png` — vendored-agent-tooling
- `test/firestore-rules/package-lock.json` — lockfile/license

</details>
