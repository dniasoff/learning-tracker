.PHONY: help test test-invariants test-rules test-functions emit-fixtures test-story-4.1 test-story-5.2 test-story-6.1 test-story-6.3 test-story-6.4 test-story-6.5 test-story-7.1 test-story-7.2 test-story-7.3 test-epic-8 test-story-9.4 test-epic-9 test-story-10.4 test-story-10.5 test-epic-10 test-story-12.4 test-epic-12 test-story-13.1 test-story-13.2 test-epic-13 test-story-14.1 test-story-14.2 test-story-14.3 test-epic-14 test-story-15.5 test-story-15.6 test-story-15.8 test-epic-15 test-epic-21 test-story-24.1 test-story-24.4 test-story-24.7 test-epic-24 test-story-25.3 test-story-25.5 test-story-25.8 test-story-25.9 test-story-25.10 test-story-25.11 test-story-25.12 test-story-25.13 test-story-25.14 test-story-25.15 test-story-25.19 test-story-25.20 test-story-25.21 test-story-25.22 test-epic-25 test-story-26.7 test-story-26.11 test-story-26.13 test-story-26.15 test-story-26.16 test-epic-26 test-story-27.1 test-story-27.3 test-story-27.4 test-story-27.6 test-story-27.7 test-story-27.8 test-story-27.9 test-story-F5 test-epic-27 test-story-i4 test-epic-28 ci analyze format format-check validate-calendar seed seed-mongo-up seed-restore seed-down audit lint lint-rules-test gen-arch-tables check-arch-tables check-feature-graph gen-dart-test-tags check-dart-test-tags check-coverage-denominator check-profile-path-keying check-profile-id-int-sites test-quarantine

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

test: ## Run all tests with coverage instrumentation
	@# R6 (flake & CI-trust gate, docs/test-artifacts/reassurance-plan.md):
	@#   --exclude-tags "serial-tools || quarantine" — ONE flag with a boolean
	@#     selector expression, not two repeated --exclude-tags flags: unlike
	@#     `dart test` (whose underlying package:test parses --exclude-tags as
	@#     an addMultiOption that unions repeated occurrences), `flutter test`
	@#     registers --exclude-tags as a single-value addOption
	@#     (packages/flutter_tools/lib/src/commands/test.dart) — a second
	@#     occurrence silently OVERWRITES the first instead of adding to it.
	@#     Passing --exclude-tags serial-tools --exclude-tags quarantine here
	@#     would have silently dropped the serial-tools exclusion (verified:
	@#     it re-admitted the make-audit-shelling test/tool/
	@#     audit_and_arb_parity_test.dart into this parallel lane — the exact
	@#     30->60min job-blowup this tag split was created to prevent). The
	@#     quoted boolean-OR expression is the one form that actually excludes
	@#     both under `flutter test`.
	@#   --test-randomize-ordering-seed=random — catches order-dependent test
	@#     pollution (shared global/static state leaking between tests) that a
	@#     fixed declaration order can hide indefinitely. package:test prints
	@#     the seed it picked on every run; re-run with
	@#     --test-randomize-ordering-seed=<that seed> to reproduce a failure.
	@#   quarantine tag: the flake-isolation lane — a test tagged `quarantine`
	@#     (dart_test.yaml reserves the tag even before anything uses it — see
	@#     tool/check_dart_test_tags.dart) is excluded from the main lane
	@#     without being silently disabled/deleted.
	flutter test --coverage --exclude-tags "serial-tools || quarantine" --test-randomize-ordering-seed=random
	@# AUD-t-cross-16: generated Drift/Freezed code inflates line-coverage
	@# numbers without protecting any hand-written behavior (nothing in lib/
	@# calls db.managers.*) — strip it from the report so coverage reflects
	@# real, reachable code. Skips gracefully if lcov isn't installed (local
	@# dev machines); CI installs lcov before this target runs.
	@# AUD-t-cross-44: lib/l10n/app_localizations*.dart (flutter gen-l10n
	@# output, 5600+ lines each) is generated the same way and was never
	@# added to this exclusion, so docs/coding-standards.md's "generated
	@# files excluded" coverage-floor claim didn't hold for l10n — a
	@# zero-assertion test existed purely to walk every getter and pad the
	@# numerator with it. Exclude it here instead.
	@if command -v lcov >/dev/null 2>&1; then \
	  lcov --remove coverage/lcov.info '*.g.dart' '*.freezed.dart' \
	    'lib/l10n/app_localizations*.dart' \
	    --output-file coverage/lcov.info --ignore-errors unused >/dev/null; \
	  echo "coverage/lcov.info: excluded *.g.dart, *.freezed.dart and lib/l10n/app_localizations*.dart"; \
	else \
	  echo "lcov not installed — coverage/lcov.info still includes generated .g.dart/.freezed.dart/l10n lines (install lcov to exclude them)"; \
	fi

test-invariants: ## Run the N1–N7 quality-crisis invariant net
	flutter test test/story_acceptance/regression_invariants_test.dart --reporter=expanded

test-serial-tools: ## Run tool tests that shell out to `make audit` (serially; they contend under the parallel suite)
	flutter test --tags serial-tools --concurrency=1

test-quarantine: ## Run only tests tagged quarantine (R6 flake-isolation lane — excluded from the main `test:` lane, not disabled; run this to triage them)
	flutter test --tags quarantine

test-rules: ## Run Firestore security-rules tests + TQ-9 rule-coverage gate under the emulator (L5)
	firebase emulators:exec --only firestore --project demo-rules "node --test functions/test/firestore_rules.test.mjs && node functions/tool/check_rule_coverage.mjs demo-rules firestore.rules"

emit-fixtures: ## Regenerate write_payloads.json from Dart codec encode() outputs
	PATH=/home/daniel/flutter/bin:$$PATH dart run tool/emit_fixture_payloads.dart 2>/dev/null > functions/test/fixtures/write_payloads.json

gen-arch-tables: ## Print the Drift-derived DB schema table list (docs/architecture.md's Database Schema section)
	dart run tool/gen_arch_tables.dart

check-arch-tables: ## Fail if docs/architecture.md's Database Schema section doesn't match freshly-generated table counts (AUD-docs-15)
	dart run tool/gen_arch_tables.dart --check

gen-feature-graph: ## Print the mermaid Feature Dependency Graph derived from ls lib/features/ + cross-feature imports
	dart run tool/gen_feature_graph.dart

check-feature-graph: ## Fail if docs/architecture.md's Feature Dependency Graph node set doesn't match ls lib/features/ (AUD-docs-15)
	dart run tool/gen_feature_graph.dart --check

gen-dart-test-tags: ## Print dart_test.yaml regenerated (tags: block from @Tags([...])/tags: [...] usage under test/, plus the R6 global timeout + reserved tags)
	dart run tool/check_dart_test_tags.dart

check-dart-test-tags: ## Fail if dart_test.yaml's tags: block is missing any tag used under test/, or the R6 global timeout default is missing/altered (AUD-guardrails-34 / R6)
	dart run tool/check_dart_test_tags.dart --check

check-coverage-denominator: ## Fail if any lib/**.dart file has zero SF: entries in coverage/lcov.info (R6, ratchet) — requires coverage/lcov.info (run `make test` first); --strict since this is the CI/manual hard-gate entry point
	dart run tool/check_lcov_denominator.dart --strict

check-profile-path-keying: ## Run the profile-scoped-collection keying-split gate standalone
	dart run tool/check_profile_path_keying.dart

check-profile-id-int-sites: ## Run the int-keyed profile-identity-sites named-entry ratchet standalone
	dart run tool/check_profile_id_int_sites.dart

test-functions: ## Run Cloud Functions tests (real handlers vs firestore emulator) (L5)
	npm --prefix functions run build
	firebase emulators:exec --only firestore,auth --project demo-cf "npm --prefix functions test"

test-story-4.1: ## Run Story 4.1 (Track Management) acceptance tests
	flutter test test/story_acceptance/epic_04_multi_track_test.dart

test-story-5.2: ## Run Story 5.2 (Custom Learning Order) acceptance tests
	flutter test test/story_acceptance/epic_05_stages_order_test.dart --name "Story 5.2"

test-story-6.1: ## Run Story 6.1 (Parametric Scheduler Engine) acceptance tests
	flutter test test/story_acceptance/epic_06_scheduler_test.dart --name "Story 6.1"

test-story-6.3: ## Run Story 6.3 (Goal Management) acceptance tests
	flutter test test/story_acceptance/epic_06_scheduler_test.dart --name "Story 6.3"

test-story-6.4: ## Run Story 6.4 (Pace Tracking) acceptance tests
	flutter test test/story_acceptance/epic_06_scheduler_test.dart --name "Story 6.4"

test-story-6.5: ## Run Story 6.5 (Cross-Curriculum Daily Schedule Composer) acceptance tests
	flutter test test/story_acceptance/epic_06_scheduler_test.dart --name "Story 6.5"

test-story-7.1: ## Run Story 7.1 (Cross-Curriculum Dashboard) acceptance tests
	flutter test test/story_acceptance/epic_07_dashboard_test.dart --name "Story 7.1"

test-story-7.2: ## Run Story 7.2 (Per-Curriculum Progress Views) acceptance tests
	flutter test test/story_acceptance/epic_07_dashboard_test.dart --name "Story 7.2"

test-story-7.3: ## Run Story 7.3 (Progress Charts & Statistics) acceptance tests
	flutter test test/story_acceptance/epic_07_dashboard_test.dart --name "Story 7.3"

test-epic-8: ## Run all Epic 8 (Gamification) acceptance tests
	flutter test test/story_acceptance/epic_08_gamification_test.dart

test-story-9.4: ## Run Story 9.4 (Bulk Mark Prior Completions) acceptance tests
	flutter test test/story_acceptance/epic_09_onboarding_test.dart --name "Story 9.4"

test-epic-9: ## Run all Epic 9 (Onboarding) acceptance tests
	flutter test test/story_acceptance/epic_09_onboarding_test.dart

test-story-10.4: ## Run Story 10.4 (Point Value Configuration) acceptance tests
	flutter test test/story_acceptance/epic_10_parent_mode_test.dart --name "Story 10.4"

test-story-10.5: ## Run Story 10.5 (Parent Track Management) acceptance tests
	flutter test test/story_acceptance/epic_10_parent_mode_test.dart --name "Story 10.5"

test-epic-10: ## Run all Epic 10 (Parent Mode) acceptance tests
	flutter test test/story_acceptance/epic_10_parent_mode_test.dart

test-story-12.4: ## Run Story 12.4 (Notification Preferences & Shabbos Mode) acceptance tests
	flutter test test/story_acceptance/epic_12_notifications_test.dart --name "Story 12.4"

test-epic-12: ## Run all Epic 12 (Notifications) acceptance tests
	flutter test test/story_acceptance/epic_12_notifications_test.dart

test-story-13.1: ## Run Story 13.1 (Push-on-Write with Offline Queuing) acceptance tests
	flutter test test/story_acceptance/epic_13_cloud_sync_test.dart --name "Story 13.1"

test-story-13.2: ## Run Story 13.2 (Pull-on-Launch Merge) acceptance tests
	flutter test test/story_acceptance/epic_13_cloud_sync_test.dart --name "Story 13.2"

test-epic-13: ## Run all Epic 13 (Cloud Sync) acceptance tests
	flutter test test/story_acceptance/epic_13_cloud_sync_test.dart

test-story-14.1: ## Run Story 14.1 (General Settings & User Profile) acceptance tests
	flutter test test/story_acceptance/epic_14_settings_test.dart --name "Story 14.1"

test-story-14.2: ## Run Story 14.2 (Data Export & Import) acceptance tests
	flutter test test/story_acceptance/epic_14_settings_test.dart --name "Story 14.2"

test-story-14.3: ## Run Story 14.3 (Account Management) acceptance tests
	flutter test test/story_acceptance/epic_14_settings_test.dart --name "Story 14.3"

test-epic-14: ## Run all Epic 14 (Settings) acceptance tests
	flutter test test/story_acceptance/epic_14_settings_test.dart

test-story-15.5: ## Run Story 15.5 (Expanded Stage Scheduling Model) acceptance tests
	flutter test test/story_acceptance/epic_15_multi_profile_test.dart --name "Story 15.5"

test-story-15.6: ## Run Story 15.6 (Learning Process Wizard) acceptance tests
	flutter test test/story_acceptance/epic_15_multi_profile_test.dart --name "Story 15.6"

test-story-15.8: ## Run Story 15.8 (Revised Onboarding Flow) acceptance tests
	flutter test test/story_acceptance/epic_15_multi_profile_test.dart --name "Story 15.8"

test-epic-15: ## Run all Epic 15 (Multi-Profile) acceptance tests
	flutter test test/story_acceptance/epic_15_multi_profile_test.dart

test-epic-21: ## Run all Epic 21 (Multi-Account Device) acceptance tests
	flutter test test/story_acceptance/epic_21_multi_account_test.dart

test-story-24.1: ## Run Story 24.1 (Per-collection Firestore rules) acceptance tests
	flutter test test/story_acceptance/epic_24_story_24_1_rules_test.dart

test-story-24.4: ## Run Story 24.4 (Crashlytics wired in main.dart) acceptance tests
	flutter test test/story_acceptance/epic_24_story_24_4_crashlytics_test.dart

test-story-24.7: ## Run Story 24.7 (Sync Curriculum Track Activation) acceptance tests
	flutter test test/story_acceptance/epic_24_stop_bleeding_test.dart --name "Story 24.7"

test-epic-24: ## Run all Epic 24 (Stop-the-Bleeding) acceptance tests
	flutter test test/story_acceptance/epic_24_stop_bleeding_test.dart test/story_acceptance/epic_24_story_24_1_rules_test.dart test/story_acceptance/epic_24_story_24_4_crashlytics_test.dart

test-story-25.3: ## Run Story 25.3 (Composite indexes on hot-path queries) acceptance tests
	flutter test test/story_acceptance/epic_25_schema_core_test.dart --name "Story 25.3"

test-story-25.5: ## Run Story 25.5 (Outbox table + OutboxProcessor) acceptance tests
	flutter test test/story_acceptance/epic_25_schema_core_test.dart --name "Story 25.5"

test-story-25.8: ## Run Story 25.8 (ContentIndex + ProgramRefResolver) acceptance tests
	flutter test test/story_acceptance/epic_25_schema_core_test.dart --name "Story 25.8"

test-story-25.10: ## Run Story 25.10 (LocalDayClock single time provider) acceptance tests
	flutter test test/story_acceptance/epic_25_schema_core_test.dart --name "Story 25.10"

test-story-25.9: ## Run Story 25.9 (core/labels rebuild — three new modes + ContentIndex consumer) acceptance tests
	flutter test test/story_acceptance/epic_25_story_25_9_test.dart test/story_acceptance/epic_25_story_25_9_lints_test.dart

test-story-25.11: ## Run Story 25.11 (AuthRepository sole firebase_auth consumer) acceptance tests
	flutter test test/story_acceptance/epic_25_schema_core_test.dart --name "Story 25.11"

test-story-25.12: ## Run Story 25.12 (SyncEngine decomp Part 1 — FirestoreGateway, PushPipeline, PullPipeline) acceptance tests
	flutter test test/story_acceptance/epic_25_story_12_sync_decomp_part1_test.dart

test-story-25.13: ## Run Story 25.13 (SyncEngine decomp Part 2 — MergeRouter + sealed EntityMerger) acceptance tests
	flutter test test/story_acceptance/epic_25_story_13_merge_router_test.dart

test-story-25.14: ## Run Story 25.14 (SyncEngine decomp Part 3 — ListenerSupervisor + LifecycleObserver) acceptance tests
	flutter test test/story_acceptance/epic_25_story_14_listener_lifecycle_test.dart

test-story-25.15: ## Run Story 25.15 (CompletionWriter transactional commit path) acceptance tests
	flutter test test/story_acceptance/epic_25_story_15_completion_writer_test.dart

test-story-25.19: ## Run Story 25.19 (Finalize AppLogger; migrate remaining production logs) acceptance tests
	flutter test test/story_acceptance/epic_25_schema_core_test.dart --name "Story 25.19"

test-story-25.21: ## Run Story 25.21 (Multi-account threading) acceptance tests
	flutter test test/story_acceptance/epic_25_story_21_multi_account_threading_test.dart

test-story-25.20: ## Run Story 25.20 (MaterialApp locale + Noto Sans Hebrew + dark theme) acceptance tests
	flutter test test/story_acceptance/epic_25_story_25_20_locale_theme_test.dart

test-story-25.22: ## Run Story 25.22 (FIREWALL — wipe-install cutover E2E verification) acceptance tests
	flutter test test/story_acceptance/epic_25_story_22_firewall_test.dart

test-epic-25: ## Run all Epic 25 (Schema + Core Foundation) acceptance tests
	flutter test test/story_acceptance/epic_25_schema_core_test.dart test/story_acceptance/epic_25_story_25_9_test.dart test/story_acceptance/epic_25_story_25_9_lints_test.dart test/story_acceptance/epic_25_story_12_sync_decomp_part1_test.dart test/story_acceptance/epic_25_story_13_merge_router_test.dart test/story_acceptance/epic_25_story_14_listener_lifecycle_test.dart test/story_acceptance/epic_25_story_15_completion_writer_test.dart test/story_acceptance/epic_25_story_21_multi_account_threading_test.dart test/story_acceptance/epic_25_story_25_20_locale_theme_test.dart test/story_acceptance/epic_25_story_22_firewall_test.dart

test-story-26.7: ## Run Story 26.7 (dashboardModelProvider + centralized onTrackChanged) acceptance tests
	flutter test test/story_acceptance/epic_26_story_26_7_dashboard_model_provider_test.dart

test-story-26.11: ## Run Story 26.11 (OnboardingController + OnboardingStep list pattern) acceptance tests
	flutter test test/story_acceptance/epic_26_story_11_onboarding_controller_test.dart

test-story-26.13: ## Run Story 26.13 (Reader purity — CompletionWriter + completionCommittedProvider) acceptance tests
	flutter test test/story_acceptance/epic_26_story_13_reader_purity_test.dart

test-story-26.15: ## Run Story 26.15 (CompositeCurriculumStrategy + transactional saveOrder) acceptance tests
	flutter test test/story_acceptance/epic_26_story_15_composite_strategy_test.dart

test-story-26.16: ## Run Story 26.16 (StatCard primitive + tappable stat cards) acceptance tests
	flutter test test/story_acceptance/epic_26_story_26_16_stat_card_test.dart

test-epic-26: ## Run all Epic 26 (UX Rebuild + Reader Purity) acceptance tests
	flutter test test/story_acceptance/epic_26_story_26_7_dashboard_model_provider_test.dart test/story_acceptance/epic_26_story_11_onboarding_controller_test.dart test/story_acceptance/epic_26_story_13_reader_purity_test.dart test/story_acceptance/epic_26_story_15_composite_strategy_test.dart test/story_acceptance/epic_26_story_26_16_stat_card_test.dart

test-story-27.1: ## Run Story 27.1 (Test infrastructure helpers) acceptance tests
	flutter test test/story_acceptance/epic_27_test_infrastructure_test.dart --name "Story 27.1"

test-story-27.3: ## Run Story 27.3 (DAO tests with real in-memory Drift) acceptance tests
	flutter test test/story_acceptance/epic_27_test_infrastructure_test.dart --name "Story 27.3"

test-story-27.4: ## Run Story 27.4 (Widget + golden suite, Hebrew variants) acceptance tests
	flutter test test/story_acceptance/epic_27_story_4_widget_golden_test.dart

test-story-27.6: ## Run Story 27.6 (DNI-382) streak reducer + cloud-restore integration tests
	flutter test test/story_acceptance/epic_27_story_06_streak_reconciles_test.dart --reporter=expanded

test-story-27.7: ## Run Story 27.7 (Profile-isolation + track-card canonical layout) acceptance tests
	flutter test test/story_acceptance/epic_27_story_7_isolation_and_canonical_layout_test.dart

test-story-27.8: ## Run Story 27.8 (Firestore rules + offline completion flush) acceptance tests
	flutter test test/story_acceptance/epic_27_story_27_8_rules_and_offline_flush_test.dart

test-story-27.9: ## Run Story 27.9 (PIN lockout + log redaction + bookmark atomic) acceptance tests
	flutter test test/story_acceptance/epic_27_integration_lockout_redaction_atomic_test.dart

test-story-F5: ## Run Story F5 (prior-learning filter — sentinel completions must not hide tasks) acceptance tests
	flutter test test/story_acceptance/epic_27_story_f5_prior_learning_filter_test.dart

test-epic-27: ## Run all Epic 27 (Test Infrastructure) acceptance tests
	flutter test test/story_acceptance/epic_27_test_infrastructure_test.dart test/story_acceptance/epic_27_story_4_widget_golden_test.dart test/story_acceptance/epic_27_story_05_bulk_mark_prior_test.dart test/story_acceptance/epic_27_story_06_streak_reconciles_test.dart test/story_acceptance/epic_27_story_7_isolation_and_canonical_layout_test.dart test/story_acceptance/epic_27_story_27_8_rules_and_offline_flush_test.dart test/story_acceptance/epic_27_integration_lockout_redaction_atomic_test.dart test/story_acceptance/epic_27_story_f5_prior_learning_filter_test.dart

test-story-i4: ## Run Story I-4 (Curriculum overlap deduplication) acceptance tests
	flutter test test/story_acceptance/epic_28_curriculum_overlap_test.dart

test-epic-28: ## Run all Epic 28 (Curriculum overlap) acceptance tests
	flutter test test/story_acceptance/epic_28_curriculum_overlap_test.dart

ci: analyze validate-calendar lint-rules-test test test-serial-tools test-rules test-functions check-profile-path-keying check-profile-id-int-sites ## Run full CI pipeline (analyze + seed validation + lint-rules-test + all tests + rules tests + Cloud Functions tests + profile-path-keying gate + profile-id-int-sites gate)

analyze: ## Run dart analyze (matches CI --fatal-infos flag)
	dart analyze --fatal-infos

validate-calendar: ## Validate every (program, date) in seed has a ref + that ref resolves
	dart run tool/validate_seed_coverage.dart

SEED_COMPOSE = tool/seed/docker-compose.yml
SEED_MONGO_CONTAINER = learning-tracker-sefaria-mongo

seed: seed-mongo-up seed-restore ## Build the bundled content DB FROM ZERO via local Sefaria Mongo (Docker). See docs/seed-build.md
	@echo "=== make seed: from-zero content DB build (local Sefaria Mongo) ==="
	@echo "[1/4] Building text_cache from curriculum_books.json (Mongo, cleaned)..."
	dart run tool/seed/build_text_cache.dart
	@echo "[2/4] Building daily_content from calendar caches (Mongo, cleaned)..."
	dart run tool/seed/build_daily_content.dart
	@echo "[3/4] Assembling seed.db + content.db.xz (text_cache + calendar + daily_content + metadata)..."
	dart run tool/seed_content_db.dart --build --no-resume
	@echo "[4/4] Re-compressing asset content.db.xz -> content.db.gz..."
	dart run tool/prepare_asset.dart
	dart run tool/seed_content_db.dart --validate-only
	@echo "=== make seed: DONE. Asset: assets/db/content.db.xz (+ .gz). Bump seed_version.dart if content changed. ==="

seed-mongo-up: ## Bring up the local Sefaria Mongo container (idempotent)
	docker compose -f $(SEED_COMPOSE) up -d
	@echo "Waiting for Mongo to be healthy..."
	@until [ "$$(docker inspect -f '{{.State.Health.Status}}' $(SEED_MONGO_CONTAINER) 2>/dev/null)" = "healthy" ]; do sleep 2; done
	@echo "Mongo healthy."

seed-restore: ## Restore the Sefaria dump into Mongo (idempotent — skips if texts already present)
	@if [ "$$(docker exec $(SEED_MONGO_CONTAINER) mongosh sefaria --quiet --eval 'db.texts.estimatedDocumentCount()' 2>/dev/null)" -gt 0 ] 2>/dev/null; then \
	  echo "Sefaria dump already restored (texts present) — skipping mongorestore."; \
	else \
	  echo "Restoring Sefaria dump (texts, index, calendar collections)..."; \
	  docker exec $(SEED_MONGO_CONTAINER) mongorestore \
	    --nsInclude='sefaria.texts' --nsInclude='sefaria.index' \
	    --nsInclude='sefaria.dafyomi' --nsInclude='sefaria.daily_mishnayot' \
	    --nsInclude='sefaria.daily_rambam' --nsInclude='sefaria.daily_rambam_three' \
	    --nsInclude='sefaria.halakhah_yomit' --nsInclude='sefaria.daf_weekly' \
	    --numInsertionWorkersPerCollection=4 /dump; \
	fi

seed-down: ## Stop + remove the local Sefaria Mongo container and volume
	docker compose -f $(SEED_COMPOSE) down -v

format: ## Format all Dart code
	dart format .

format-check: ## Dry-run format check (matches CI: exits non-zero if any file would change)
	dart format --set-exit-if-changed .

lint: ## Run custom_lint (skips gracefully if not in pubspec)
	@if dart pub deps --json 2>/dev/null | grep -q '"custom_lint"'; then \
	  dart run custom_lint; \
	else \
	  echo "custom_lint not in pubspec — skipping (add custom_lint to dev_dependencies when ready)"; \
	fi

lint-rules-test: ## Run packages/custom_lints unit tests (dart test) — AUD-guardrails-17
	@echo "Running packages/custom_lints unit tests..."
	@(cd ../packages/custom_lints && dart pub get && dart test) 1>&2

audit: lint-rules-test ## Run all 68 enforcement greps (NFR19) — exits non-zero on any violation
	@echo "=== audit: enforcement greps ==="
	@FAIL=0; \
	echo "1/15 — No Firebase imports outside core/auth, core/sync, data/firestore, or data/repositories (Story 2.6: widened — legacy lib/core/sync|auth retained, lib/data/firestore/**+lib/data/repositories/** added per AD-3/AD-28)"; \
	if ! dart run tool/check_firebase_confinement.dart --auth > /tmp/firebase_confinement_auth_check.$$$$.log 2>&1; then \
	  cat /tmp/firebase_confinement_auth_check.$$$$.log; \
	  rm -f /tmp/firebase_confinement_auth_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/firebase_confinement_auth_check.$$$$.log; \
	fi; \
	echo "2/15 — No FirebaseFirestore/FirebaseStorage/cloud_firestore outside core/sync, core/auth, data/firestore, or data/repositories (Story 2.6: widened — legacy lib/core/sync|auth retained, lib/data/firestore/**+lib/data/repositories/** added; the former lib/core/providers/ + lib/features/ blanket carve-outs are RETIRED so a feature/service/provider file importing cloud_firestore actually fails the gate, per AD-3/AD-28)"; \
	if ! dart run tool/check_firebase_confinement.dart --storage > /tmp/firebase_confinement_storage_check.$$$$.log 2>&1; then \
	  cat /tmp/firebase_confinement_storage_check.$$$$.log; \
	  rm -f /tmp/firebase_confinement_storage_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/firebase_confinement_storage_check.$$$$.log; \
	fi; \
	echo "3/15 — No FirebaseAuth.instance.signOut outside core/auth"; \
	if grep -rn "FirebaseAuth\.instance\.signOut" lib/ tool/lib/ --include="*.dart" \
	    | grep -v "lib/core/auth/" | grep -q .; then \
	  grep -rn "FirebaseAuth\.instance\.signOut" lib/ tool/lib/ --include="*.dart" | grep -v "lib/core/auth/"; \
	  FAIL=1; \
	fi; \
	echo "4/15 — No raw talker import outside core/logging"; \
	if grep -rn "import 'package:talker/talker\.dart'" lib/ tool/lib/ --include="*.dart" \
	    | grep -v "lib/core/logging/" | grep -v "tool/lib/dio_client\.dart" | grep -q .; then \
	  grep -rn "import 'package:talker/talker\.dart'" lib/ tool/lib/ --include="*.dart" \
	    | grep -v "lib/core/logging/" | grep -v "tool/lib/dio_client\.dart"; \
	  FAIL=1; \
	fi; \
	echo "5/15 — No debugPrint or bare print() in production code"; \
	if grep -rn "debugPrint\|^\s*print(" lib/ --include="*.dart" \
	    | grep -v "\.g\.dart" | grep -v "\.freezed\.dart" | grep -q .; then \
	  grep -rn "debugPrint\|^\s*print(" lib/ --include="*.dart" \
	    | grep -v "\.g\.dart" | grep -v "\.freezed\.dart"; \
	  FAIL=1; \
	fi; \
	echo "6/15 — No DateTime.now() outside core/time"; \
	if grep -rn "DateTime\.now()" lib/ --include="*.dart" \
	    | grep -v "lib/core/time/" | grep -v "\.g\.dart" | grep -v "\.freezed\.dart" | grep -v "test/" | grep -q .; then \
	  grep -rn "DateTime\.now()" lib/ --include="*.dart" \
	    | grep -v "lib/core/time/" | grep -v "\.g\.dart" | grep -v "\.freezed\.dart" | grep -v "test/"; \
	  FAIL=1; \
	fi; \
	echo "7/15 — No useHebrewTermsProvider read outside core/labels, core/preferences, or settings/onboarding screens"; \
	# onboarding_profile_creation_step.dart is a writer (toggle persistence \
	# during initial profile setup), not a reader — explicitly whitelisted. \
	if grep -rn "useHebrewTermsProvider" lib/ --include="*.dart" \
	    | grep -v "lib/core/" | grep -v "lib/features/settings/.*_screen\.dart" \
	    | grep -v "lib/features/onboarding/presentation/screens/onboarding_screen\.dart" \
	    | grep -v "lib/features/onboarding/presentation/steps/onboarding_profile_creation_step\.dart" \
	    | grep -v "\.g\.dart" | grep -v ":[[:space:]]*//" | grep -q .; then \
	  grep -rn "useHebrewTermsProvider" lib/ --include="*.dart" \
	    | grep -v "lib/core/" | grep -v "lib/features/settings/.*_screen\.dart" \
	    | grep -v "lib/features/onboarding/presentation/screens/onboarding_screen\.dart" \
	    | grep -v "lib/features/onboarding/presentation/steps/onboarding_profile_creation_step\.dart" \
	    | grep -v "\.g\.dart" | grep -v ":[[:space:]]*//"; \
	  FAIL=1; \
	fi; \
	echo "8/15 — No displayNameEn/He() outside core/labels (excluding generated files)"; \
	if grep -rn "displayName(En\|He)" lib/ --include="*.dart" \
	    | grep -v "lib/core/labels/" | grep -v "\.g\.dart" | grep -v "\.freezed\.dart" | grep -q .; then \
	  grep -rn "displayName(En\|He)" lib/ --include="*.dart" \
	    | grep -v "lib/core/labels/" | grep -v "\.g\.dart" | grep -v "\.freezed\.dart"; \
	  FAIL=1; \
	fi; \
	echo "9/15 — No empty catch blocks"; \
	if grep -rn "catch\s*(_\?\w*)\s*{}" lib/ --include="*.dart" | grep -v "\.g\.dart" | grep -q .; then \
	  grep -rn "catch\s*(_\?\w*)\s*{}" lib/ --include="*.dart" | grep -v "\.g\.dart"; \
	  FAIL=1; \
	fi; \
	echo "10/15 — Every TODO/FIXME/XXX comment carries a Linear id DNI-#### (AG-6)"; \
	if grep -rnP '(//|/\*)\s*(TODO|FIXME|XXX)\b' lib/ test/ integration_test/ --include="*.dart" \
	    | grep -v "\.g\.dart" | grep -v "\.freezed\.dart" | grep -v "DNI-[0-9]" \
	    | grep -v "^lib/firebase_options.dart:" | grep -q .; then \
	  echo "  TODO/FIXME/XXX with no DNI-#### Linear id — file or link a ticket (AG-6):"; \
	  grep -rnP '(//|/\*)\s*(TODO|FIXME|XXX)\b' lib/ test/ integration_test/ --include="*.dart" \
	    | grep -v "\.g\.dart" | grep -v "\.freezed\.dart" | grep -v "DNI-[0-9]" \
	    | grep -v "^lib/firebase_options.dart:"; \
	  FAIL=1; \
	fi; \
	echo "11/15 — No .withDefault(const Constant(0)) in database tables"; \
	if grep -rn "\.withDefault(const Constant(0))" lib/core/database/tables/ --include="*.dart" | grep -q .; then \
	  grep -rn "\.withDefault(const Constant(0))" lib/core/database/tables/ --include="*.dart"; \
	  FAIL=1; \
	fi; \
	echo "12/15 — No currentAccountId hard-coded to 1"; \
	if grep -rn "currentAccountId.*=.*1\b" lib/ --include="*.dart" | grep -v "\.g\.dart" | grep -q .; then \
	  grep -rn "currentAccountId.*=.*1\b" lib/ --include="*.dart" | grep -v "\.g\.dart"; \
	  FAIL=1; \
	fi; \
	echo "13/15 — No raw HebrewTerms. calls in lib/features/ (B11-7)"; \
	if grep -rn "HebrewTerms\." lib/features/ --include="*.dart" | grep -v "_test\.dart" | grep -v "\.g\.dart" | grep -q .; then \
	  grep -rn "HebrewTerms\." lib/features/ --include="*.dart" | grep -v "_test\.dart" | grep -v "\.g\.dart"; \
	  FAIL=1; \
	fi; \
	echo "14/15 — No features/ imports inside lib/core/ (W1.12) [warn-only: pre-existing violations pending Wave-2 fix]"; \
	if grep -rn "package:learning_tracker/features/" lib/core/ --include="*.dart" | grep -v "\.g\.dart" | grep -v "\.freezed\.dart" | grep -q .; then \
	  echo "  WARN: the following lib/core/ files import from lib/features/ — fix in Wave 2:"; \
	  grep -rn "package:learning_tracker/features/" lib/core/ --include="*.dart" | grep -v "\.g\.dart" | grep -v "\.freezed\.dart"; \
	fi; \
	echo "15/15 — No cross-feature deep imports (must use barrel) (W1.13) [warn-only: pre-existing violations pending Wave-2 fix]"; \
	if grep -rn "package:learning_tracker/features/" lib/features/ --include="*.dart" \
	    | grep -v "\.g\.dart" | grep -v "\.freezed\.dart" \
	    | awk -F: '{ content = $$0; sub(/^[^:]*:[^:]*:/, "", content); if (match($$1, /features\/([^\/]+)\//, a) && match(content, /features\/([^\/]+)\//, b)) { if (a[1] != b[1]) { barrel = "features/" b[1] "/" b[1] ".dart"; if (index(content, barrel) == 0) print } } }' \
	    | grep -q .; then \
	  echo "  WARN: the following files use cross-feature deep imports — fix by switching to barrel:"; \
	  grep -rn "package:learning_tracker/features/" lib/features/ --include="*.dart" \
	    | grep -v "\.g\.dart" | grep -v "\.freezed\.dart" \
	    | awk -F: '{ content = $$0; sub(/^[^:]*:[^:]*:/, "", content); if (match($$1, /features\/([^\/]+)\//, a) && match(content, /features\/([^\/]+)\//, b)) { if (a[1] != b[1]) { barrel = "features/" b[1] "/" b[1] ".dart"; if (index(content, barrel) == 0) print } } }'; \
	fi; \
	echo "16/17 — No raw profile.mode string comparisons (use ProfileMode enum) (W5.10)"; \
	if grep -rn "\.mode == '" lib/ --include="*.dart" \
	    | grep -v "\.g\.dart" | grep -v "\.freezed\.dart" \
	    | grep -v "lib/core/domain/value_objects/profile_mode\.dart" \
	    | grep -v ":[[:space:]]*//" \
	    | grep -q .; then \
	  grep -rn "\.mode == '" lib/ --include="*.dart" \
	    | grep -v "\.g\.dart" | grep -v "\.freezed\.dart" \
	    | grep -v "lib/core/domain/value_objects/profile_mode\.dart" \
	    | grep -v ":[[:space:]]*//";\
	  FAIL=1; \
	fi; \
	echo "17/17 — No raw account.tier string comparisons (use AccountTier/UserTier enum) (W5.11)"; \
	if grep -rn "\.tier [!=]= '" lib/ --include="*.dart" \
	    | grep -v "\.g\.dart" | grep -v "\.freezed\.dart" \
	    | grep -v "lib/core/domain/value_objects/account_tier\.dart" \
	    | grep -v "lib/core/database/daos/user_profile_dao\.dart" \
	    | grep -v "lib/core/database/registry/device_registry_database\.dart" \
	    | grep -q .; then \
	  grep -rn "\.tier [!=]= '" lib/ --include="*.dart" \
	    | grep -v "\.g\.dart" | grep -v "\.freezed\.dart" \
	    | grep -v "lib/core/domain/value_objects/account_tier\.dart" \
	    | grep -v "lib/core/database/daos/user_profile_dao\.dart" \
	    | grep -v "lib/core/database/registry/device_registry_database\.dart"; \
	  FAIL=1; \
	fi; \
	echo "18/18 — No direct FirestoreGateway.push* outside lib/core/sync/ (Plan §F Phase 5 deliverable 8 — no-direct-gateway-push)"; \
	# Whitelist exclusions: \
	#   * lib/features/sync/ — the OutboxSyncWriteFacade lives here. \
	#   * send_logs_service.dart — pushDiagnosticLog is best-effort telemetry, \
	#     intentionally direct (out of scope for Phase 5; revisit if logs start \
	#     dropping offline). \
	# Known offenders being converted by Squad ALPHA (Phase 1 cleanup): \
	#   * notification_providers.dart  → outbox via OutboxSyncWriteFacade. \
	#   * user_profile_service.dart    → outbox via OutboxSyncWriteFacade. \
	# Whitelisted here so the audit gate doesn't block in-flight work; the grep \
	# itself still catches NEW regressions (anything that isn't on the whitelist). \
	if grep -rn "\(_firestoreGateway\|firestoreGateway\|gateway\|_gateway\)\.push" lib/features/ --include="*.dart" \
	    | grep -v "\.g\.dart" | grep -v "\.freezed\.dart" \
	    | grep -v "lib/features/sync/" \
	    | grep -v "lib/features/settings/presentation/utils/send_logs_service\.dart" \
	    | grep -v "lib/features/notifications/presentation/providers/notification_providers\.dart" \
	    | grep -v "lib/features/onboarding/domain/services/user_profile_service\.dart" \
	    | grep -v ":[[:space:]]*//" \
	    | grep -q .; then \
	  echo "  All cloud-bound writes must enqueue via OutboxSyncWriteFacade; the gateway is owned by lib/core/sync/ only:"; \
	  grep -rn "\(_firestoreGateway\|firestoreGateway\|gateway\|_gateway\)\.push" lib/features/ --include="*.dart" \
	    | grep -v "\.g\.dart" | grep -v "\.freezed\.dart" \
	    | grep -v "lib/features/sync/" \
	    | grep -v "lib/features/settings/presentation/utils/send_logs_service\.dart" \
	    | grep -v "lib/features/notifications/presentation/providers/notification_providers\.dart" \
	    | grep -v "lib/features/onboarding/domain/services/user_profile_service\.dart" \
	    | grep -v ":[[:space:]]*//"; \
	  FAIL=1; \
	fi; \
	echo "19/20 — No hardcoded Torah domain-term literals in presentation strings (Hebrew-terms consistency)"; \
	if grep -rnE "'[^']*\b(Mishnayos|Mishnayot|Masechtos|Masekhtot|Masekhet|Dafim|Dapim|Amudim|Perakim|Pesukim|Chazara|Siyumim|Sedarim)\b[^']*'" lib/features --include="*.dart" \
	    | grep "/presentation/" | grep -v "\.g\.dart" | grep -v "\.freezed\.dart" | grep -v ":[[:space:]]*//" \
	    | grep -q .; then \
	  echo "  Domain terms must render via domainTermLabels / CurriculumLabels / CurriculumLabelRenderer / l10n so they honour the Hebrew-terms + Ashkenazi/Sephardi settings:"; \
	  grep -rnE "'[^']*\b(Mishnayos|Mishnayot|Masechtos|Masekhtot|Masekhet|Dafim|Dapim|Amudim|Perakim|Pesukim|Chazara|Siyumim|Sedarim)\b[^']*'" lib/features --include="*.dart" \
	    | grep "/presentation/" | grep -v "\.g\.dart" | grep -v "\.freezed\.dart" | grep -v ":[[:space:]]*//"; \
	  FAIL=1; \
	fi; \
	echo "20/22 — No raw curriculumId/storageKey rendered in Text() (render via CurriculumLabel / rendered*ForRef)"; \
	if grep -rnE "Text\(\s*(curriculumId|[a-zA-Z_]+\.storageKey)\b" lib/features --include="*.dart" \
	    | grep "/presentation/" | grep -v "\.g\.dart" | grep -v ":[[:space:]]*//" \
	    | grep -q .; then \
	  echo "  Raw storage keys must render via CurriculumLabel / CurriculumLabelRenderer / rendered*ForRef:"; \
	  grep -rnE "Text\(\s*(curriculumId|[a-zA-Z_]+\.storageKey)\b" lib/features --include="*.dart" \
	    | grep "/presentation/" | grep -v "\.g\.dart" | grep -v ":[[:space:]]*//"; \
	  FAIL=1; \
	fi; \
	echo "21/22 — No nusach-specific domain-term ARB getter used directly in lib/features/ presentation (classC)"; \
	# Hebrew-terms bypass classC: an ARB getter whose VALUE is itself a hardcoded \
	# nusach-specific Torah term (dayNameShabbos="Shabbos", unitDafim="Dafim", …, \
	# and the scheduler*Label twins) must NEVER be read straight off \
	# AppLocalizations — it cannot switch Hebrew / Ashkenazi / Sephardi. Domain \
	# terms render via domainTermLabels(ref) / CurriculumLabels / \
	# CurriculumLabelRenderer instead, which honour the toggle + nusach. \
	# \
	# Deliberately NOT in this list: the sacredTime*Shabbos* / \
	# sacredTimeShabbosModeLabel getters — those are {term}-PLACEHOLDER templates \
	# ("Good {term}", "{term} MODE") that RECEIVE the already-resolved \
	# domainTermLabels(...).shabbos(variant:) value as an argument, so they are the \
	# CORRECT path and stay green. Matches `.<getter>(` and `.<getter>` (no-arg \
	# getters), covering l10n.x, AppLocalizations.of(context)!.x and aliases. \
	FORBIDDEN_L10N='\.(dayNameShabbos|unitDafim|unitAmudim|unitPerakim|unitPesukim|schedulerDafimLabel|schedulerAmudimLabel|schedulerPerakimLabel|schedulerPesukimLabel)\b'; \
	if grep -rnE "$$FORBIDDEN_L10N" lib/features --include="*.dart" \
	    | grep "/presentation/" | grep -v "\.g\.dart" | grep -v "\.freezed\.dart" | grep -v ":[[:space:]]*//" \
	    | grep -q .; then \
	  echo "  Nusach-specific ARB getters cannot switch script/nusach — route domain terms through domainTermLabels / CurriculumLabels:"; \
	  grep -rnE "$$FORBIDDEN_L10N" lib/features --include="*.dart" \
	    | grep "/presentation/" | grep -v "\.g\.dart" | grep -v "\.freezed\.dart" | grep -v ":[[:space:]]*//"; \
	  FAIL=1; \
	fi; \
	echo "22/22 — Every lib/core/labels/ file touching displayNameEn/He must be variant-aware (classA)"; \
	# Hebrew-terms bypass classA: a labels file that reads .displayNameEn / \
	# .displayNameHe but never references the nusach variant is rendering a name \
	# WITHOUT applying Ashkenazi/Sephardi transliteration — a bypass the displayName \
	# greps (check 8) intentionally exempt for core/labels. File-level heuristic: \
	# any non-generated core/labels file that touches displayName must also mention \
	# currentTransliterationVariantProvider OR TransliterationVariant OR `variant`. \
	# Add a narrow `// audit:classA-exempt` line to a legitimately Hebrew-only \
	# accessor file if one is ever introduced. \
	for f in $$(grep -rlE "displayName(En|He)\b" lib/core/labels/ --include="*.dart" \
	    | grep -v "\.g\.dart" | grep -v "\.freezed\.dart"); do \
	  if grep -q "audit:classA-exempt" "$$f"; then continue; fi; \
	  if ! grep -qE "currentTransliterationVariantProvider|TransliterationVariant|variant" "$$f"; then \
	    echo "  $$f reads displayNameEn/He but is NOT variant-aware (no TransliterationVariant / variant reference) — it must transliterate per nusach:"; \
	    grep -nE "displayName(En|He)\b" "$$f"; \
	    FAIL=1; \
	  fi; \
	done; \
	echo "23/25 — No custom_lint analyzer plugin marker (AUD-guardrails-03: breaks the dart analyze --fatal-infos hard gate)"; \
	# analysis_server's legacy plugin loader re-resolves `custom_lint` from \
	# pub.dev in an isolated pub context that ignores dependency_overrides — \
	# since only custom_lint 0.8.1 is published (this project needs the \
	# unreleased analyzer-9-compatible 0.8.2 git commit), enabling the marker \
	# crashes `dart analyze --fatal-infos` (exit 4, even on a clean tree). \
	# `flutter analyze` swallows the crash and still exits 0, so it will NOT \
	# catch a regression here — this grep is the real backstop. See \
	# docs/coding-standards.md "custom_lint toolchain status". \
	if grep -qE '^\s*-\s*custom_lint\s*$$' analysis_options.yaml; then \
	  echo "  analysis_options.yaml enables 'analyzer: plugins: [custom_lint]', which crashes"; \
	  echo "  dart analyze --fatal-infos via analysis_server's legacy plugin loader (see comment"; \
	  echo "  above the (now removed) plugins: key in analysis_options.yaml for the full story):"; \
	  grep -nE '^\s*-\s*custom_lint\s*$$' analysis_options.yaml; \
	  FAIL=1; \
	fi; \
	echo "24/25 — No duplicate public top-level type names across lib/ (AG-4)"; \
	DUPES=$$(grep -rnoP '^(sealed\s+|abstract\s+|base\s+|final\s+|interface\s+)*(mixin\s+class\s+|class\s+|enum\s+|mixin\s+)\K[A-Za-z_]\w*' lib/ --include="*.dart" \
	    | grep -v '\.g\.dart:' | grep -v '\.freezed\.dart:' \
	    | awk -F: '{name=$$3; if (name !~ /^_/) print $$1"\t"name}' \
	    | sort -u \
	    | awk -F'\t' '{count[$$2]++; files[$$2]=files[$$2]" "$$1} END {for (n in count) if (count[n] > 1) print n": "files[n]}' \
	    | sort); \
	if [ -n "$$DUPES" ]; then \
	  echo "  Public top-level type name defined in more than one lib/ file — rename or delete the duplicate (AG-4):"; \
	  echo "$$DUPES"; \
	  FAIL=1; \
	fi; \
	echo "25/26 — Only one file named coding-standards.md outside docs/_archive (AUD-docs-04, AG-8)"; \
	# docs/coding-standards.md is the sole canonical standards doc; a second \
	# file with the same name (e.g. a stale root copy) is a doc that can lie \
	# to an agent that lands on the wrong one — AG-8. \
	HITS=$$(find .. -name "coding-standards.md" \
	    -not -path "*/_archive/*" \
	    -not -path "*/.git/*" \
	    -not -path "*/.claude/*" \
	    -not -path "*/node_modules/*" \
	    -not -path "*/build/*" \
	    -not -path "*/.dart_tool/*"); \
	COUNT=$$(echo "$$HITS" | grep -c .); \
	if [ "$$COUNT" -ne 1 ]; then \
	  echo "  Expected exactly one coding-standards.md outside docs/_archive/ (docs/coding-standards.md is canonical); found $$COUNT:"; \
	  echo "$$HITS"; \
	  FAIL=1; \
	fi; \
	echo "26/40 — Every .logEvent() call site in lib/ uses an AnalyticsEvent.* catalog member (AUD-core-analytics-01, PV-1/PV-5)"; \
	if ! dart run tool/check_analytics_catalog.dart > /tmp/analytics_catalog_check.$$$$.log 2>&1; then \
	  cat /tmp/analytics_catalog_check.$$$$.log; \
	  rm -f /tmp/analytics_catalog_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/analytics_catalog_check.$$$$.log; \
	fi; \
	echo "60/60 — TQ-6 Rule-0: no DateTime.now() wall-clock filler in the AUD-t-cross-88 DAO test fixture setup files — use DateTimeFactory.nowUtc() (AUD-t-cross-88)"; \
	# Scoped to exactly the 8 files this finding named (completion_dao_test.dart, \
	# completion_event_dao_test.dart, curriculum_scope_dao_test.dart, \
	# goal_dao_test.dart, learning_ledger_dao_test.dart, point_config_dao_test.dart, \
	# profile_dao_test.dart, stage_dao_test.dart) — a hard gate against regression \
	# in this finding's own territory. bookmark_dao_test.dart, track_dao_test.dart, \
	# and track_scoped_dao_test.dart in the same directory still carry raw \
	# DateTime.now() calls but are the named territory of sibling findings \
	# AUD-t-cross-85 and AUD-t-cross-83 (not yet fixed) — deliberately not swept \
	# here, matching the AUD-t-cross-37 scope-note precedent (see that commit). \
	# Positioned here (out of numeric sequence, before check 27) rather than at \
	# the tail: appending it after check 27's SeedManager grep pattern (which \
	# contains a literal unbalanced '(' in "SeedManager(" / "SeedManager({") \
	# reproducibly corrupts GNU Make's recipe parsing — Make silently drops \
	# every subsequent check with no error (verified in isolation; a pre-existing \
	# latent issue in check 27, out of this finding's scope to fix). Placing this \
	# check before check 27 avoids the interaction entirely; verified `make audit` \
	# runs all 60 checks and reaches "audit PASSED" with this placement (see \
	# commit message for the isolated repro). \
	CROSS88_FILES="test/core/database/daos/completion_dao_test.dart \
	  test/core/database/daos/completion_event_dao_test.dart \
	  test/core/database/daos/curriculum_scope_dao_test.dart \
	  test/core/database/daos/goal_dao_test.dart \
	  test/core/database/daos/learning_ledger_dao_test.dart \
	  test/core/database/daos/point_config_dao_test.dart \
	  test/core/database/daos/profile_dao_test.dart \
	  test/core/database/daos/stage_dao_test.dart"; \
	CROSS88_HITS=$$(grep -n "DateTime\.now()" $$CROSS88_FILES 2>/dev/null); \
	if [ -n "$$CROSS88_HITS" ]; then \
	  echo "  DateTime.now() must not be reintroduced in these fixture-setup files — use DateTimeFactory.nowUtc() (AUD-t-cross-88):"; \
	  echo "$$CROSS88_HITS"; \
	  FAIL=1; \
	fi; \
	echo "27/40 — Every SeedManager( construction site in lib/ passes a logger: argument (AUD-app-07, EH-3)"; \
	# A SeedManager built without a logger silently no-ops every one of its \
	# ~13 internal _logger?.info/warning/error(...) diagnostic calls (first- \
	# launch extraction, version-driven upgrade, .bak rollback, corruption \
	# recovery) — exactly the AUD-app-07 defect (contentDbPathProvider built \
	# one with no logger: argument at all). Excludes the class's own \
	# constructor declaration ("SeedManager({") — only real construction call \
	# sites are checked. Windowed (5 lines) so a multi-line named-arg call \
	# still matches. \
	SITES=$$(grep -rn "SeedManager(" lib/ --include="*.dart" \
	    | grep -v "SeedManager({" \
	    | grep -v "\.g\.dart" | grep -v "\.freezed\.dart" || true); \
	for hit in $$(echo "$$SITES" | grep -oE "^[^:]+:[0-9]+" | sort -u); do \
	  FILE=$$(echo "$$hit" | cut -d: -f1); \
	  LN=$$(echo "$$hit" | cut -d: -f2); \
	  WINDOW=$$(sed -n "$${LN},$$((LN+4))p" "$$FILE"); \
	  if ! echo "$$WINDOW" | grep -q "logger:"; then \
	    echo "  $$FILE:$$LN — SeedManager( constructed without a logger: argument:"; \
	    echo "$$WINDOW" | sed 's/^/    /'; \
	    FAIL=1; \
	  fi; \
	done; \
	echo "28/40 — pushTrack/pushSettings/pushBookmark/pushGoal overwrite their LWW ordering field with a server Timestamp, never the caller's client-clock value (FB-2, AUD-core-sync-13)"; \
	GW=lib/core/sync/firestore_gateway_impl.dart; \
	UPDATED_AT_COUNT=$$(grep -c "'updated_at': FieldValue.serverTimestamp()," "$$GW"); \
	if [ "$$UPDATED_AT_COUNT" -lt 4 ]; then \
	  echo "  Expected at least 4 \"'updated_at': FieldValue.serverTimestamp(),\" sites in $$GW"; \
	  echo "  (pushLearnerProfile, pushSettings, pushBookmark, pushGoal — AUD-core-sync-24 collapsed pushGoal's"; \
	  echo "  former if(docId!=null)/else(add()) branches into a single set(merge:true) path, so pushGoal now"; \
	  echo "  contributes 1 site instead of 2 — see AUD-core-sync-24) — found $$UPDATED_AT_COUNT."; \
	  echo "  A push* method may have regressed to passing the caller's client-clock updated_at straight through (FB-2)."; \
	  FAIL=1; \
	fi; \
	if ! grep -q "'state_changed_at': FieldValue.serverTimestamp()," "$$GW"; then \
	  echo "  pushTrack must overwrite 'state_changed_at' (the field TrackCodec/TrackConfigMerger"; \
	  echo "  compare — see docs/sync-conflict-resolution.md) with FieldValue.serverTimestamp();"; \
	  echo "  found no such site in $$GW (FB-2)."; \
	  FAIL=1; \
	fi; \
	echo "29/40 — AG-5 test-mirroring ratchet: no NEW unmirrored lib/ file outside the tracked backlog (AUD-app-05)"; \
	if ! dart run tool/check_test_mirroring.dart > /tmp/ag5_mirroring_check.$$$$.log 2>&1; then \
	  cat /tmp/ag5_mirroring_check.$$$$.log; \
	  rm -f /tmp/ag5_mirroring_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/ag5_mirroring_check.$$$$.log; \
	fi; \
	echo "30/40 — DB-2: no multi-write method in features/onboarding/domain/services or core/database/registry without an enclosing transaction() (AUD-onboarding-06, AUD-core-database-08)"; \
	if ! dart run tool/check_db_transactions.dart > /tmp/db_transactions_check.$$$$.log 2>&1; then \
	  cat /tmp/db_transactions_check.$$$$.log; \
	  rm -f /tmp/db_transactions_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/db_transactions_check.$$$$.log; \
	fi; \
	echo "31/40 — The לימוד stage-name sentinel is never hand-typed; every write site references kLimudStageName (AUD-onboarding-14)"; \
	if grep -rn "stageName: 'לימוד'" lib/ --include="*.dart" | grep -q .; then \
	  echo "  stageName: 'לימוד' must not be hand-typed — reference kLimudStageName (lib/core/constants/hebrew_terms.dart) instead, so a typo in one copy cannot silently desync DomainTermLabels.resolveStoredStageName's lookup:"; \
	  grep -rn "stageName: 'לימוד'" lib/ --include="*.dart"; \
	  FAIL=1; \
	fi; \
	echo "32/40 — EH-4: catch clauses in core/sync's periodic-drain / recovery-pull / listener-dispatch paths are typed (AUD-core-sync-26)"; \
	if ! dart run tool/check_eh4_typed_catches.dart > /tmp/eh4_typed_catches_check.$$$$.log 2>&1; then \
	  cat /tmp/eh4_typed_catches_check.$$$$.log; \
	  rm -f /tmp/eh4_typed_catches_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/eh4_typed_catches_check.$$$$.log; \
	fi; \
	echo "33/40 — EH-5: sealed status/result types must carry a stable code, never a free-text 'message', and no raw error.toString()/e.toString() may flow into a 'message:' argument (AUD-sync-01)"; \
	for f in $$(grep -rlE "@freezed" lib/ --include="*.dart" | grep -v "\.g\.dart" | grep -v "\.freezed\.dart"); do \
	  if grep -qE "sealed class" "$$f" && grep -qE "required String message" "$$f"; then \
	    echo "  $$f: sealed status/result type has a free-text 'message' field — carry a stable code/enum instead (EH-5, see SyncErrorCode):"; \
	    grep -nE "required String message" "$$f"; \
	    FAIL=1; \
	  fi; \
	done; \
	if grep -rnE "message:\s*[A-Za-z_][A-Za-z0-9_]*\.toString\(\)" lib/ --include="*.dart" \
	    | grep -v "\.g\.dart" | grep -v "\.freezed\.dart" | grep -q .; then \
	  echo "  Raw error.toString()/e.toString() flowing into a 'message:' argument — a domain/data error must never carry a pre-formatted human message (EH-5):"; \
	  grep -rnE "message:\s*[A-Za-z_][A-Za-z0-9_]*\.toString\(\)" lib/ --include="*.dart" \
	    | grep -v "\.g\.dart" | grep -v "\.freezed\.dart"; \
	  FAIL=1; \
	fi; \
	echo "34/40 — No bare 'as int?'/'as num?'/'as double?'/'as bool?' casts in lib/core/sync/codec/*.dart (AUD-core-sync-05)"; \
	if grep -rnE "as (int|num|double|bool)\?" lib/core/sync/codec/*.dart | grep -q .; then \
	  echo "  Bare nullable-numeric/bool cast in a codec decode() — use FirestoreCodec.parseInt/parseDouble/parseBool instead:"; \
	  grep -rnE "as (int|num|double|bool)\?" lib/core/sync/codec/*.dart; \
	  FAIL=1; \
	fi; \
	echo "35/40 — EH-3: no log-less catch/catchError in the scoped sync-write-facade / content-db / seed-manager / device-registry files (AUD-sync-03, AUD-core-database-16)"; \
	if ! dart run tool/check_eh3_log_less_catch.dart > /tmp/eh3_log_less_catch_check.$$$$.log 2>&1; then \
	  cat /tmp/eh3_log_less_catch_check.$$$$.log; \
	  rm -f /tmp/eh3_log_less_catch_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/eh3_log_less_catch_check.$$$$.log; \
	fi; \
	echo "36/40 — DB-3: no looped singular outbox push/enqueue calls in local_data_upload_service.dart (AUD-sync-02)"; \
	if ! dart run tool/check_db3_batch_inserts.dart > /tmp/db3_batch_check.$$$$.log 2>&1; then \
	  cat /tmp/db3_batch_check.$$$$.log; \
	  rm -f /tmp/db3_batch_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/db3_batch_check.$$$$.log; \
	fi; \
	echo "37/40 — SM-7: no ad-hoc RewardMilestoneService construction inside the AUD-sync-05 fix sites (local_data_upload_service.dart, outbox_sync_write_facade.dart, reward_settings_merge_delegate.dart), and no ad-hoc ParentAnalyticsRepositoryImpl construction ANYWHERE in lib/ outside core/analytics/ (AUD-core-navigation-04 gate-repair: structural, not a 4-file allowlist)"; \
	if grep -nE "final +[A-Za-z_][A-Za-z0-9_]* += +RewardMilestoneService\(" \
	    lib/features/sync/data/local_data_upload_service.dart \
	    lib/features/sync/data/outbox_sync_write_facade.dart \
	    lib/features/sync/data/reward_settings_merge_delegate.dart \
	    | grep -q .; then \
	  echo "  Ad-hoc mid-method RewardMilestoneService construction reintroduced — inject via a constructor/factory parameter instead (AUD-sync-05, SM-7):"; \
	  grep -nE "final +[A-Za-z_][A-Za-z0-9_]* += +RewardMilestoneService\(" \
	    lib/features/sync/data/local_data_upload_service.dart \
	    lib/features/sync/data/outbox_sync_write_facade.dart \
	    lib/features/sync/data/reward_settings_merge_delegate.dart; \
	  FAIL=1; \
	fi; \
	if ! dart run tool/check_sm7_analytics_repository_construction.dart > /tmp/sm7_analytics_repo_check.$$$$.log 2>&1; then \
	  cat /tmp/sm7_analytics_repo_check.$$$$.log; \
	  rm -f /tmp/sm7_analytics_repo_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/sm7_analytics_repo_check.$$$$.log; \
	fi; \
	echo "38/40 — DB-2/DB-3: TrackLearningOrderDao.upsertOrder never regresses to an awaited per-row into( loop (AUD-core-database-05)"; \
	if ! dart run tool/check_db_dao_loop_writes.dart > /tmp/db_dao_loop_writes_check.$$$$.log 2>&1; then \
	  cat /tmp/db_dao_loop_writes_check.$$$$.log; \
	  rm -f /tmp/db_dao_loop_writes_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/db_dao_loop_writes_check.$$$$.log; \
	fi; \
	echo "39/40 — EH-5: the 4 AUD-core-database-14 DAO sites never regress to a raw pre-formatted StateError message"; \
	if ! dart run tool/check_dao_stateerror_messages.dart > /tmp/dao_stateerror_messages_check.$$$$.log 2>&1; then \
	  cat /tmp/dao_stateerror_messages_check.$$$$.log; \
	  rm -f /tmp/dao_stateerror_messages_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/dao_stateerror_messages_check.$$$$.log; \
	fi; \
	echo "40/41 — AX-2: no hardcoded literal passed to Text()/TextSpan(text:) under lib/features/**/presentation/** (AUD-account-05)"; \
	if ! dart run tool/check_hardcoded_presentation_text.dart > /tmp/ax2_hardcoded_text_check.$$$$.log 2>&1; then \
	  cat /tmp/ax2_hardcoded_text_check.$$$$.log; \
	  rm -f /tmp/ax2_hardcoded_text_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/ax2_hardcoded_text_check.$$$$.log; \
	fi; \
	echo "41/41 — AX-2: no AppLocalizations.of(context)?.<key> ?? '<literal>' null-coalescing hardcoded-string fallback in lib/features/profiles/ presentation (AUD-profiles-19)"; \
	for f in $$(grep -rlE "AppLocalizations\.of\(context\)\?\." lib/features/profiles --include="*.dart" \
	    | grep -v "\.g\.dart" | grep -v "\.freezed\.dart"); do \
	  if grep -Pzoq "AppLocalizations\.of\(context\)\?\.[A-Za-z0-9_]+\s*\?\?\s*\n?\s*'[^']*'" "$$f"; then \
	    echo "  $$f: AppLocalizations.of(context)?.<key> ?? '<literal>' null-coalescing fallback — drop the ?? (use AppLocalizations.of(context)!) or route the fallback through a second ARB key:"; \
	    grep -Pzo "AppLocalizations\.of\(context\)\?\.[A-Za-z0-9_]+\s*\?\?\s*\n?\s*'[^']*'" "$$f" | tr '\0' '\n' | sed 's/^/    /'; \
	    FAIL=1; \
	  fi; \
	done; \
	echo "42/43 — EH-4: catch clauses in content_browsing's search / repository / text-display / cloud-content-service paths are typed (AUD-content_browsing-09)"; \
	if ! dart run tool/check_eh4_content_browsing_catches.dart > /tmp/eh4_content_browsing_catches_check.$$$$.log 2>&1; then \
	  cat /tmp/eh4_content_browsing_catches_check.$$$$.log; \
	  rm -f /tmp/eh4_content_browsing_catches_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/eh4_content_browsing_catches_check.$$$$.log; \
	fi; \
	echo "43/44 — EH-4: DeviceAccountX.accountTier never catches an Error subtype (AUD-core-database-16, avoid_catching_errors)"; \
	if ! dart run tool/check_eh4_avoid_catching_errors.dart > /tmp/eh4_avoid_catching_errors_check.$$$$.log 2>&1; then \
	  cat /tmp/eh4_avoid_catching_errors_check.$$$$.log; \
	  rm -f /tmp/eh4_avoid_catching_errors_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/eh4_avoid_catching_errors_check.$$$$.log; \
	fi; \
	echo "44/45 — Tier-4 doc-lint: every ready-for-dev/backlog/todo docs/stories/implementation/*.md Key-Files target resolves under lib/ (AUD-docs-03)"; \
	if ! dart run tool/check_stale_story_file_targets.dart > /tmp/stale_story_targets_check.$$$$.log 2>&1; then \
	  cat /tmp/stale_story_targets_check.$$$$.log; \
	  rm -f /tmp/stale_story_targets_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/stale_story_targets_check.$$$$.log; \
	fi; \
	echo "45/45 — AG-9 story-DoD ratchet: no NEW docs/stories/implementation/*.md with Status: done/review, an unchecked Tasks/Subtasks line, or an empty Dev Agent Record outside the tracked epic-21 backlog (AUD-docs-24)"; \
	if ! dart run tool/check_story_dod.dart > /tmp/story_dod_check.$$$$.log 2>&1; then \
	  cat /tmp/story_dod_check.$$$$.log; \
	  rm -f /tmp/story_dod_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/story_dod_check.$$$$.log; \
	fi; \
	echo "46/49 — AG-8 doc-lint: docs/explainers/sync-subsystem.md's stated EntityMerger count matches lib/core/sync/merge/ (AUD-docs-18)"; \
	if ! dart run tool/check_sync_explainer_merger_count.dart > /tmp/sync_explainer_merger_count_check.$$$$.log 2>&1; then \
	  cat /tmp/sync_explainer_merger_count_check.$$$$.log; \
	  rm -f /tmp/sync_explainer_merger_count_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/sync_explainer_merger_count_check.$$$$.log; \
	fi; \
	echo "47/49 — Rule-0 doc-lint: no NEW docs/stories/implementation/*.md Status header disagreeing with sprint-status.yaml's \"done\" for the same story key (AUD-docs-06)"; \
	if ! dart run tool/check_story_status_reconciliation.dart > /tmp/story_status_reconciliation_check.$$$$.log 2>&1; then \
	  cat /tmp/story_status_reconciliation_check.$$$$.log; \
	  rm -f /tmp/story_status_reconciliation_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/story_status_reconciliation_check.$$$$.log; \
	fi; \
	echo "48/49 — AG-8 doc-lint: docs/architecture.md's Database Schema section matches a fresh tool/gen_arch_tables.dart run (AUD-docs-15/16)"; \
	if ! dart run tool/gen_arch_tables.dart --check > /tmp/gen_arch_tables_check.$$$$.log 2>&1; then \
	  cat /tmp/gen_arch_tables_check.$$$$.log; \
	  rm -f /tmp/gen_arch_tables_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/gen_arch_tables_check.$$$$.log; \
	fi; \
	echo "49/49 — AG-8 doc-lint: docs/architecture.md's Feature Dependency Graph node set matches ls lib/features/ (AUD-docs-15)"; \
	if ! dart run tool/gen_feature_graph.dart --check > /tmp/gen_feature_graph_check.$$$$.log 2>&1; then \
	  cat /tmp/gen_feature_graph_check.$$$$.log; \
	  rm -f /tmp/gen_feature_graph_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/gen_feature_graph_check.$$$$.log; \
	fi; \
	echo "50/52 — AG-8 doc-lint: no leaked tool-call framing artifacts (</content>, </invoke>) in committed docs/ (AUD-docs-36)"; \
	if grep -rnE "^</(content|invoke)>$$" ../docs/ | grep -q .; then \
	  echo "  A stray XML-ish tool-call closing tag was committed verbatim — an unstripped"; \
	  echo "  Write/Edit tool-call content boundary leaked into a tracked doc; delete the line(s):"; \
	  grep -rnE "^</(content|invoke)>$$" ../docs/; \
	  FAIL=1; \
	fi; \
	echo "51/57 — TQ-6: no duplicate public top-level function defined in more than one file under test/helpers/ (AUD-t-cross-12)"; \
	if ! dart run tool/check_test_helpers_duplicate_functions.dart > /tmp/test_helpers_dup_check.$$$$.log 2>&1; then \
	  cat /tmp/test_helpers_dup_check.$$$$.log; \
	  rm -f /tmp/test_helpers_dup_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/test_helpers_dup_check.$$$$.log; \
	fi; \
	echo "52/57 — AG-3: hand-written Dart files stay under 400 lines, generated files exempt [warn-only: introduce-then-ratchet per docs/coding-standards.md AG-3] (AUD-t-cross-15)"; \
	AG3_HITS=$$(find lib test -name '*.dart' ! -name '*.g.dart' ! -name '*.freezed.dart' | xargs wc -l | awk '$$2 != "total" && $$1 > 400'); \
	if [ -n "$$AG3_HITS" ]; then \
	  echo "  WARN: the following hand-written files exceed AG-3's 400-line cap — do not grow them further,"; \
	  echo "  ratchet the count down over time (see docs/coding-standards.md AG-3):"; \
	  echo "$$AG3_HITS"; \
	fi; \
	echo "53/57 — No hand-rolled ARB-loading helper in test/l10n/*.dart — use test/helpers/arb_loader.dart's loadArb() (AUD-t-cross-22)"; \
	if grep -rn "_loadArb(String locale)\|final file = File('lib/l10n/app_" test/l10n/*.dart | grep -v "test/helpers/" | grep -q .; then \
	  grep -rn "_loadArb(String locale)\|final file = File('lib/l10n/app_" test/l10n/*.dart | grep -v "test/helpers/"; \
	  FAIL=1; \
	fi; \
	echo "54/57 — TQ-5/Rule-0: no hardcoded /home/<user>/, /Users/<user>/, or /root/... developer-machine absolute path under test/ (AUD-t-cross-03)"; \
	if grep -rnE "['\"]/(home|Users|root)/[A-Za-z0-9_.-]+" test/ --include="*.dart" \
	    | grep -v ":[[:space:]]*//" | grep -v "isNot(contains(" | grep -q .; then \
	  echo "  A test hardcodes an absolute path into one developer's home directory — goldens/tests must resolve"; \
	  echo "  SDK/tool paths portably (e.g. Platform.environment['FLUTTER_ROOT'], see test/helpers/golden_font_loader.dart)"; \
	  echo "  instead of a machine-specific literal that doesn't exist in CI or on a teammate's machine (TQ-5):"; \
	  grep -rnE "['\"]/(home|Users|root)/[A-Za-z0-9_.-]+" test/ --include="*.dart" \
	    | grep -v ":[[:space:]]*//" | grep -v "isNot(contains("; \
	  FAIL=1; \
	fi; \
	echo "55/57 — AG-6: no NEW *.skip test file under test/ — dead/uncompiled test code (outside flutter test's glob, zero CI signal — AUD-t-cross-17) is deleted, not parked; RATCHET like AG-5's check_test_mirroring.dart, only a file NOT in the tracked legacy list below fails the gate"; \
	ALLOWED_SKIP_FILES=""; \
	SKIP_HITS=$$(find test/ -name "*.skip" | sort); \
	for f in $$SKIP_HITS; do \
	  case " $$ALLOWED_SKIP_FILES " in \
	    *" $$f "*) ;; \
	    *) \
	      echo "  $$f — new *.skip file under test/ is not permitted; delete dead/uncompiled test code instead of parking it (AG-6, AUD-t-cross-17)"; \
	      FAIL=1 ;; \
	  esac; \
	done; \
	echo "56/58 — profileId-in-PK Invariant: every non-exempt UserDatabase table carries profileId (AUD-t-cross-06, docs/coding-standards.md:692)"; \
	if ! dart run tool/check_profile_id_in_pk.dart > /tmp/profile_id_in_pk_check.$$$$.log 2>&1; then \
	  cat /tmp/profile_id_in_pk_check.$$$$.log; \
	  rm -f /tmp/profile_id_in_pk_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/profile_id_in_pk_check.$$$$.log; \
	fi; \
	echo "57/58 — TQ-6 Rule-0: no NEW test file pairs a .listen( call with a fixed-millisecond Future<void>.delayed(...) wait in the same test body (AUD-t-cross-36)"; \
	if ! dart run tool/check_test_stream_delay_race.dart > /tmp/stream_delay_race_check.$$$$.log 2>&1; then \
	  cat /tmp/stream_delay_race_check.$$$$.log; \
	  rm -f /tmp/stream_delay_race_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/stream_delay_race_check.$$$$.log; \
	fi; \
	echo "58/58 — Rule-0 (warn-only): no hand-rolled CurriculumTracksCompanion.insert( under test/core/database/daos/**/*.dart — use test/helpers/drift_memory.dart's seedTrack() (AUD-t-cross-37)"; \
	CT37_HITS=$$(grep -rn "CurriculumTracksCompanion\.insert(" test/core/database/daos/ --include="*.dart" 2>/dev/null | grep -v "test/helpers/drift_memory.dart"); \
	if [ -n "$$CT37_HITS" ]; then \
	  echo "  WARN: the following sites hand-roll CurriculumTracksCompanion.insert(...) instead of calling seedTrack() — convert them (AUD-t-cross-37):"; \
	  echo "$$CT37_HITS"; \
	fi; \
	echo "59/61 — Rule-0: every docs/planning/e2e-test-suite-plan.md row tagged dims=he has a matching Locale('he') usage in its test/e2e/journeys/*.dart section (AUD-t-cross-31)"; \
	if ! dart run tool/check_e2e_he_locale_coverage.dart > /tmp/e2e_he_locale_check.$$$$.log 2>&1; then \
	  cat /tmp/e2e_he_locale_check.$$$$.log; \
	  rm -f /tmp/e2e_he_locale_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/e2e_he_locale_check.$$$$.log; \
	fi; \
	echo "60/61 — TQ-6 Rule-0: every inMemoryDb()/createTestUserDatabase() call site under test/ has a matching close() reachable from the same scope (AUD-t-gamification-04)"; \
	if ! dart run tool/check_inmemory_db_close.dart > /tmp/inmemory_db_close_check.$$$$.log 2>&1; then \
	  cat /tmp/inmemory_db_close_check.$$$$.log; \
	  rm -f /tmp/inmemory_db_close_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/inmemory_db_close_check.$$$$.log; \
	fi; \
	echo "61/62 — TQ-6: inner check 6's \"No DateTime.now() outside core/time\" extended to test/ — RATCHET, only a NEW (non-baselined) test/ file calling DateTime.now() fails the gate (AUD-t-cross-84)"; \
	if ! dart run tool/check_tq6_test_wall_clock.dart > /tmp/tq6_test_wall_clock_check.$$$$.log 2>&1; then \
	  cat /tmp/tq6_test_wall_clock_check.$$$$.log; \
	  rm -f /tmp/tq6_test_wall_clock_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/tq6_test_wall_clock_check.$$$$.log; \
	fi; \
	echo "62/65 — TQ-3 Rule-0: GlobalCupertinoLocalizations.delegate occurrence count outside test/helpers/ (hand-rolled MaterialApp delegate blocks not yet migrated onto pumpApp) — RATCHET, only growth above the tracked baseline fails the gate (AUD-t-profiles-02)"; \
	if ! dart run tool/check_tq3_pump_app_migration.dart > /tmp/tq3_pump_app_migration_check.$$$$.log 2>&1; then \
	  cat /tmp/tq3_pump_app_migration_check.$$$$.log; \
	  rm -f /tmp/tq3_pump_app_migration_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/tq3_pump_app_migration_check.$$$$.log; \
	fi; \
	echo "63/65 — TQ-6 Rule-0: LearningScreen widget tests must never construct a real (named, on-disk) Drift UserDatabase — flutter test output for test/features/learning/presentation/screens/ must contain zero 'WARNING (drift)' occurrences (AUD-t-learning-01)"; \
	LSD_LOG=/tmp/learning_screen_drift_check.$$$$.log; \
	if ! timeout 300 flutter test test/features/learning/presentation/screens/ --concurrency=2 > "$$LSD_LOG" 2>&1; then \
	  cat "$$LSD_LOG"; \
	  echo "  FAIL: flutter test test/features/learning/presentation/screens/ itself failed to run/pass"; \
	  rm -f "$$LSD_LOG"; \
	  FAIL=1; \
	elif grep -q "WARNING (drift)" "$$LSD_LOG"; then \
	  grep -n "WARNING (drift)" "$$LSD_LOG"; \
	  echo "  FAIL: 'WARNING (drift)' found in flutter test output for test/features/learning/presentation/screens/ — a real Drift UserDatabase was constructed; override userDatabaseProvider (and any provider that reaches it, e.g. coarsePacedTrackIdsProvider) with an in-memory double (AUD-t-learning-01)"; \
	  rm -f "$$LSD_LOG"; \
	  FAIL=1; \
	else \
	  rm -f "$$LSD_LOG"; \
	fi; \
	echo "64/65 — TQ-6 Rule-0: any widget test that pumps NotificationsScreen overrides both reminderSyncEffectProvider/streakAlertSyncEffectProvider — RATCHET, only a NEW (non-baselined) test/ file skipping the override fails the gate (AUD-t-notifications-01)"; \
	if ! dart run tool/check_notifications_sync_effect_overrides.dart > /tmp/notifications_sync_effect_check.$$$$.log 2>&1; then \
	  cat /tmp/notifications_sync_effect_check.$$$$.log; \
	  rm -f /tmp/notifications_sync_effect_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/notifications_sync_effect_check.$$$$.log; \
	fi; \
	echo "65/66 — AG-4 candidate: no duplicate top-level class name defined in more than one file under test/features/notifications/ (AUD-t-notifications-03)"; \
	if ! dart run tool/check_notifications_duplicate_test_classes.dart > /tmp/notifications_dup_classes_check.$$$$.log 2>&1; then \
	  cat /tmp/notifications_dup_classes_check.$$$$.log; \
	  rm -f /tmp/notifications_dup_classes_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/notifications_dup_classes_check.$$$$.log; \
	fi; \
	echo "66/66 — TQ-7/Fowler candidate: no two files under test/features/scheduler/ share an identical test name or a >=80%-similar test body under the same group name (AUD-t-scheduler-01)"; \
	if ! dart run tool/check_scheduler_test_duplication.dart > /tmp/scheduler_test_dup_check.$$$$.log 2>&1; then \
	  cat /tmp/scheduler_test_dup_check.$$$$.log; \
	  rm -f /tmp/scheduler_test_dup_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/scheduler_test_dup_check.$$$$.log; \
	fi; \
	echo "67/67 — TQ-8 Rule-0: text_display_screen.dart carries zero ref.invalidate( calls — completionCommittedProvider is the sole signal mechanism (AUD-t-story-acceptance-13)"; \
	if grep -n "ref\.invalidate(" lib/features/content_browsing/presentation/screens/text_display_screen.dart \
	    | grep -v ":[[:space:]]*//" | grep -q .; then \
	  echo "  text_display_screen.dart must not reintroduce ref.invalidate() calls — Story 26.13 replaced 14 manual"; \
	  echo "  invalidations with completionCommittedProvider; every consumer watches that counter instead:"; \
	  grep -n "ref\.invalidate(" lib/features/content_browsing/presentation/screens/text_display_screen.dart \
	    | grep -v ":[[:space:]]*//"; \
	  FAIL=1; \
	fi; \
	echo "68/68 — Rule-0: no test/ file imports a lib path deleted in W2.35 (sync_engine.dart, firestore_data_source.dart, offline_queue.dart) — real coverage lives in outbox_processor_test.dart (AUD-t-sync-01)"; \
	if grep -rn "package:learning_tracker/.*/\(sync_engine\|firestore_data_source\|offline_queue\)\.dart" test/ | grep -q .; then \
	  echo "  test/ file imports a lib path deleted in W2.35 — resurrecting dead sync test scaffolding instead of using outbox_processor_test.dart (AUD-t-sync-01):"; \
	  grep -rn "package:learning_tracker/.*/\(sync_engine\|firestore_data_source\|offline_queue\)\.dart" test/; \
	  FAIL=1; \
	fi; \
	echo "69/69 — SM-6 doc hygiene: no lib/ doc comment claims 'Keeps alive' unless the file is actually annotated keepAlive: true (AUD-core-analytics-03)"; \
	for f in $$(grep -rlE '^\s*///.*[Kk]eeps alive' lib/ --include="*.dart" 2>/dev/null); do \
	  if ! grep -q "keepAlive: true" "$$f"; then \
	    echo "  $$f has a doc comment claiming 'Keeps alive' but is NOT annotated keepAlive: true — reword to avoid colliding with Riverpod's keepAlive terminology (AUD-core-analytics-03):"; \
	    grep -nE '^\s*///.*[Kk]eeps alive' "$$f"; \
	    FAIL=1; \
	  fi; \
	done; \
	echo "70/70 — Rule 1a dependency-direction: no lib/core/ file imports lib/app/ (W1.2 shim removal — AUD-core-navigation-02; cycle broken via guard DI — AUD-core-navigation-01) — hard gate, zero legacy debt"; \
	echo "  (deleting the app_router/app_shell/router_provider/guards/auth_guard re-export shims originally unmasked 3 pre-existing"; \
	echo "  lib/core/navigation/guards/{pin,profile,restore}_guard.dart -> app_router.dart sites; those guards now take"; \
	echo "  PageRouteInfo Function() constructor params supplied by app-layer router wiring instead of importing app/router/"; \
	echo "  directly, so the whitelist is gone — ANY lib/core/ -> lib/app/ site fails this gate)"; \
	if grep -rn "import 'package:learning_tracker/app/" lib/core/ --include="*.dart" | grep -q .; then \
	  echo "  lib/core/ file imports from lib/app/ — core/ must not depend on app/ (dependency direction is strictly app -> features -> core, coding-standards.md Layering Rules):"; \
	  grep -rn "import 'package:learning_tracker/app/" lib/core/ --include="*.dart"; \
	  FAIL=1; \
	fi; \
	echo "71/71 — PF-3: no RegExp( compiled inside a lib/core/labels/ method body — hoist to a static final field (AUD-core-labels-04)"; \
	if grep -rn "RegExp(" lib/core/labels/ --include="*.dart" \
	    | grep -v "static final RegExp" | grep -v "static const RegExp" | grep -q .; then \
	  echo "  RegExp(...) compiled inside a method body under lib/core/labels/ — hoist to a private"; \
	  echo "  'static final RegExp' class field (mirrors curriculum_label.dart's _hebrew pattern) to"; \
	  echo "  avoid reallocating the pattern on every call (PF-3, AUD-core-labels-04):"; \
	  grep -rn "RegExp(" lib/core/labels/ --include="*.dart" \
	    | grep -v "static final RegExp" | grep -v "static const RegExp"; \
	  FAIL=1; \
	fi; \
	echo "72/75 — SM-6: every @Riverpod(keepAlive: true) in lib/core/auth/auth_providers.dart carries an inline // keepAlive: justification comment on the line immediately above (diff-scoped to this file per AUD-core-auth-04; other repo-wide keepAlive sites — e.g. content_index.dart, registry_provider.dart, preference_providers.dart — are tracked separately, not yet in this gate)"; \
	if awk '/@Riverpod\(keepAlive: true\)/ && prev !~ /\/\/[ \t]*keepAlive:/ { print NR": "$$0 } { prev = $$0 }' \
	    lib/core/auth/auth_providers.dart | grep -q .; then \
	  echo "  @Riverpod(keepAlive: true) missing an inline // keepAlive: <reason> justification comment"; \
	  echo "  on the preceding line (SM-6, docs/coding-standards.md:167, AUD-core-auth-04):"; \
	  awk '/@Riverpod\(keepAlive: true\)/ && prev !~ /\/\/[ \t]*keepAlive:/ { print NR": "$$0 } { prev = $$0 }' \
	    lib/core/auth/auth_providers.dart; \
	  FAIL=1; \
	fi; \
	echo "73/75 — Rule-0: no .gitkeep in a non-empty lib/ directory — flags ANY such redundant .gitkeep, zero tolerated (AUD-core-constants-02)"; \
	if ! dart run tool/check_gitkeep_stray.dart > /tmp/gitkeep_stray_check.$$$$.log 2>&1; then \
	  cat /tmp/gitkeep_stray_check.$$$$.log; \
	  rm -f /tmp/gitkeep_stray_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/gitkeep_stray_check.$$$$.log; \
	fi; \
	echo "74/75 — EH-5: firebase_auth_gateway_impl.dart never regresses to a raw StateError precondition guard — throw NotAuthenticatedException instead (AUD-core-auth-03)"; \
	if grep -n "throw StateError(" lib/core/auth/firebase_auth_gateway_impl.dart | grep -q .; then \
	  echo "  lib/core/auth/firebase_auth_gateway_impl.dart: raw StateError(...) precondition guard reintroduced —"; \
	  echo "  a domain/data error must carry a stable type/code, never a pre-formatted human sentence (EH-5)."; \
	  echo "  Throw NotAuthenticatedException (defined in this file) instead:"; \
	  grep -n "throw StateError(" lib/core/auth/firebase_auth_gateway_impl.dart; \
	  FAIL=1; \
	fi; \
	echo "75/75 — EH-5: _DeletingAccountOverlayState (account_actions.dart) never renders a caught exception's raw message/toString() in the UI (AUD-core-auth-03)"; \
	if awk '/^class _DeletingAccountOverlayState/,/^}/' lib/features/settings/presentation/utils/account_actions.dart \
	    | grep -vE '^\s*//' | grep -qE "\.toString\(\)|\.message"; then \
	  echo "  lib/features/settings/presentation/utils/account_actions.dart: _DeletingAccountOverlayState renders a"; \
	  echo "  caught exception's raw .toString()/.message — an untranslated, developer-facing string reaching the UI"; \
	  echo "  (EH-5). Resolve display text via AppLocalizations only (l10n.deletingAccountError); log the raw error"; \
	  echo "  via AppLogger for diagnostics instead:"; \
	  awk '/^class _DeletingAccountOverlayState/,/^}/' lib/features/settings/presentation/utils/account_actions.dart \
	    | grep -vE '^\s*//' | grep -nE "\.toString\(\)|\.message"; \
	  FAIL=1; \
	fi; \
	echo "76/79 — SM-6: every @Riverpod(keepAlive: true) in lib/core/preferences/preference_providers.dart carries an inline // keepAlive: justification comment within 2 lines above (diff-scoped to this file per AUD-core-preferences-05)"; \
	if awk '/@Riverpod\(keepAlive: true\)/ && prev1 !~ /\/\/[ \t]*keepAlive:/ && prev2 !~ /\/\/[ \t]*keepAlive:/ { print NR": "$$0 } { prev2 = prev1; prev1 = $$0 }' \
	    lib/core/preferences/preference_providers.dart | grep -q .; then \
	  echo "  @Riverpod(keepAlive: true) missing an inline // keepAlive: <reason> justification comment"; \
	  echo "  within 2 lines above (SM-6, docs/coding-standards.md:167, AUD-core-preferences-05):"; \
	  awk '/@Riverpod\(keepAlive: true\)/ && prev1 !~ /\/\/[ \t]*keepAlive:/ && prev2 !~ /\/\/[ \t]*keepAlive:/ { print NR": "$$0 } { prev2 = prev1; prev1 = $$0 }' \
	    lib/core/preferences/preference_providers.dart; \
	  FAIL=1; \
	fi; \
	echo "77/79 — SM-6: every @Riverpod(keepAlive: true) under lib/features/content_browsing/presentation/providers/ carries an inline // keepAlive: justification comment within 2 lines above (AUD-content_browsing-07; cloud_content_providers.dart is out of scope — deleted as dead code by AUD-content_browsing-06)"; \
	for f in lib/features/content_browsing/presentation/providers/content_providers.dart \
	         lib/features/content_browsing/presentation/providers/text_display_providers.dart; do \
	  if awk '/@Riverpod\(keepAlive: true\)/ { if (prev1 !~ /\/\/[ \t]*keepAlive:/ && prev2 !~ /\/\/[ \t]*keepAlive:/) print FILENAME":"NR": "$$0 } { prev2 = prev1; prev1 = $$0 }' "$$f" | grep -q .; then \
	    echo "  $$f: @Riverpod(keepAlive: true) missing an inline // keepAlive: <reason> justification"; \
	    echo "  comment within 2 lines above (SM-6, docs/coding-standards.md:167, AUD-content_browsing-07):"; \
	    awk '/@Riverpod\(keepAlive: true\)/ { if (prev1 !~ /\/\/[ \t]*keepAlive:/ && prev2 !~ /\/\/[ \t]*keepAlive:/) print FILENAME":"NR": "$$0 } { prev2 = prev1; prev1 = $$0 }' "$$f"; \
	    FAIL=1; \
	  fi; \
	done; \
	echo "78/79 — SM-6: every @Riverpod(keepAlive: true) in lib/features/profiles/presentation/providers/{active_profile_provider,parent_pin_session_provider,profile_providers,pin_flow_controller}.dart carries an inline // keepAlive: justification comment on the line immediately above (diff-scoped to this batch per AUD-profiles-22; other repo-wide keepAlive sites remain tracked separately, not yet in this gate)"; \
	if awk 'FNR==1 { prev = "" } /@Riverpod\(keepAlive: true\)/ && prev !~ /\/\/[ \t]*keepAlive:/ { print FILENAME":"FNR": "$$0 } { prev = $$0 }' \
	    lib/features/profiles/presentation/providers/active_profile_provider.dart \
	    lib/features/profiles/presentation/providers/parent_pin_session_provider.dart \
	    lib/features/profiles/presentation/providers/profile_providers.dart \
	    lib/features/profiles/presentation/providers/pin_flow_controller.dart | grep -q .; then \
	  echo "  @Riverpod(keepAlive: true) missing an inline // keepAlive: <reason> justification comment"; \
	  echo "  on the preceding line (SM-6, docs/coding-standards.md:167, AUD-profiles-22):"; \
	  awk 'FNR==1 { prev = "" } /@Riverpod\(keepAlive: true\)/ && prev !~ /\/\/[ \t]*keepAlive:/ { print FILENAME":"FNR": "$$0 } { prev = $$0 }' \
	    lib/features/profiles/presentation/providers/active_profile_provider.dart \
	    lib/features/profiles/presentation/providers/parent_pin_session_provider.dart \
	    lib/features/profiles/presentation/providers/profile_providers.dart \
	    lib/features/profiles/presentation/providers/pin_flow_controller.dart; \
	  FAIL=1; \
	fi; \
	echo "79/82 — EH-3: no log-less catch in the profiles create/update/self-heal cloud-push paths or the add-profile-dialog duplicate-name check (AUD-profiles-16)"; \
	if ! dart run tool/check_eh3_profiles_log_less_catch.dart > /tmp/eh3_profiles_log_less_catch_check.$$$$.log 2>&1; then \
	  cat /tmp/eh3_profiles_log_less_catch_check.$$$$.log; \
	  rm -f /tmp/eh3_profiles_log_less_catch_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/eh3_profiles_log_less_catch_check.$$$$.log; \
	fi; \
	echo "80/83 — EH-2/SM-5 Rule-0: no unguarded await <prefs-or-dao-call> in a Future<void> Notifier method across the AUD-core-preferences-04 scope (core/preferences, notifications, sacred_time, scheduler, onboarding providers; the former tracks/setup entry, add_track_controller.dart, was deleted as dead code by AUD-tracks-11)"; \
	if ! dart run tool/check_guarded_persist.dart > /tmp/check_guarded_persist.$$$$.log 2>&1; then \
	  cat /tmp/check_guarded_persist.$$$$.log; \
	  rm -f /tmp/check_guarded_persist.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/check_guarded_persist.$$$$.log; \
	fi; \
	echo "81/83 — SM-6: every @Riverpod(keepAlive: true) in lib/features/sacred_time/presentation/providers/{cities_provider,sacred_location_provider,sacred_windows_provider}.dart carries an inline // keepAlive: justification comment on the line immediately above (diff-scoped to this batch per AUD-sacred_time-07; other repo-wide keepAlive sites remain tracked separately, not yet in this gate)"; \
	if awk 'FNR==1 { prev = "" } /@Riverpod\(keepAlive: true\)/ && prev !~ /\/\/[ \t]*keepAlive:/ { print FILENAME":"FNR": "$$0 } { prev = $$0 }' \
	    lib/features/sacred_time/presentation/providers/cities_provider.dart \
	    lib/features/sacred_time/presentation/providers/sacred_location_provider.dart \
	    lib/features/sacred_time/presentation/providers/sacred_windows_provider.dart | grep -q .; then \
	  echo "  @Riverpod(keepAlive: true) missing an inline // keepAlive: <reason> justification comment"; \
	  echo "  on the preceding line (SM-6, docs/coding-standards.md:167, AUD-sacred_time-07):"; \
	  awk 'FNR==1 { prev = "" } /@Riverpod\(keepAlive: true\)/ && prev !~ /\/\/[ \t]*keepAlive:/ { print FILENAME":"FNR": "$$0 } { prev = $$0 }' \
	    lib/features/sacred_time/presentation/providers/cities_provider.dart \
	    lib/features/sacred_time/presentation/providers/sacred_location_provider.dart \
	    lib/features/sacred_time/presentation/providers/sacred_windows_provider.dart; \
	  FAIL=1; \
	fi; \
	echo "82/83 — AUD-scheduler-19: no hand-written 'bool operator ==' under lib/features/scheduler/domain/ outside the documented judgment-call files (delta_value.dart, goal_entity.dart, overdue_types.dart — see docs/coding-standards.md #documented-judgment-calls); other repo-wide hand-rolled-equality sites (e.g. features/account/domain/models/auth_state.dart; features/progress/domain/models/lifetime_knowledge.dart and features/progress/domain/services/pace_calculator.dart converted to @freezed by AUD-progress-14; features/profiles/domain/models/profile_session.dart converted separately) are pre-existing and tracked separately, not yet in this gate"; \
	if grep -rn "bool operator ==" lib/features/scheduler/domain/ --include="*.dart" \
	    | grep -v "\.g\.dart:" | grep -v "\.freezed\.dart:" \
	    | grep -v "domain/models/delta_value.dart:" \
	    | grep -v "domain/models/goal_entity.dart:" \
	    | grep -v "domain/projection/overdue_types.dart:" \
	    | grep -q .; then \
	  echo "  Hand-written operator== outside the documented judgment-call list —"; \
	  echo "  convert to @freezed or add a documented judgment call (AUD-scheduler-19):"; \
	  grep -rn "bool operator ==" lib/features/scheduler/domain/ --include="*.dart" \
	    | grep -v "\.g\.dart:" | grep -v "\.freezed\.dart:" \
	    | grep -v "domain/models/delta_value.dart:" \
	    | grep -v "domain/models/goal_entity.dart:" \
	    | grep -v "domain/projection/overdue_types.dart:"; \
	  FAIL=1; \
	fi; \
	echo "83/83 — SM-5 Rule-0: every hand-rolled state.copyWith(busy|loading: true) in a @riverpod Notifier method or PinEntryMachine member carries a paired finally backstop or routes through AsyncValue.guard, so an untyped PinService/repository exception can never leave the flag stuck true and freeze the gated UI (AUD-profiles-11)"; \
	if ! dart run tool/check_sm5_busy_stuck.dart > /tmp/sm5_busy_stuck_check.$$$$.log 2>&1; then \
	  cat /tmp/sm5_busy_stuck_check.$$$$.log; \
	  rm -f /tmp/sm5_busy_stuck_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/sm5_busy_stuck_check.$$$$.log; \
	fi; \
	echo "84/84 — Fowler duplication: no inline db.select(db.curriculumTracks) (profileId, curriculumId) -> track lookup outside core/database/ — call TrackDao.getTrackByProfileAndCurriculum instead (AUD-settings-06). Excludes lib/features/scheduler/domain/services/study_day_toggle_service.dart, a pre-existing occurrence outside this finding's scope, tracked separately, not yet in this gate"; \
	CT_SETTINGS06_HITS=$$(grep -rn "db\.select(db\.curriculumTracks)" lib/ --include="*.dart" \
	    | grep -v "lib/core/database/" \
	    | grep -v "lib/features/scheduler/domain/services/study_day_toggle_service.dart"); \
	if [ -n "$$CT_SETTINGS06_HITS" ]; then \
	  echo "  The following sites re-implement TrackDao.getTrackByProfileAndCurriculum inline instead of reusing it (AUD-settings-06):"; \
	  echo "$$CT_SETTINGS06_HITS"; \
	  FAIL=1; \
	fi; \
	echo "85/85 — Rule-0/AG-6 companion: every non-generated *_screen.dart file has an @RoutePage( registration or a Navigator.push/direct-construction call site elsewhere in lib/ — RATCHET, only a NEW orphaned screen not in the tracked baseline fails the gate (AUD-settings-08)"; \
	if ! dart run tool/check_orphaned_screens.dart > /tmp/orphaned_screens_check.$$$$.log 2>&1; then \
	  cat /tmp/orphaned_screens_check.$$$$.log; \
	  rm -f /tmp/orphaned_screens_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/orphaned_screens_check.$$$$.log; \
	fi; \
	echo "86/86 — AUD-guardrails-10: no NEW diverging same-basename tool script between ../tool/** and tool/** (root vs learning_tracker duplicate-tool drift) — RATCHET, only a NEW collision not in the tracked baseline fails the gate"; \
	if ! dart run tool/check_dup_tool_basename.dart > /tmp/dup_tool_basename_check.$$$$.log 2>&1; then \
	  cat /tmp/dup_tool_basename_check.$$$$.log; \
	  rm -f /tmp/dup_tool_basename_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/dup_tool_basename_check.$$$$.log; \
	fi; \
	echo "87/87 — EH-5/ST-4: no raw exception .toString() flows into a Text()/l10n()/AppLocalizations.of() call site under lib/features/settings — grep-based backstop pending custom_lint's no_e_to_string_in_ui repair (AUD-settings-07)"; \
	if ! dart run tool/check_settings_no_tostring_in_ui.dart > /tmp/settings_tostring_check.$$$$.log 2>&1; then \
	  cat /tmp/settings_tostring_check.$$$$.log; \
	  rm -f /tmp/settings_tostring_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/settings_tostring_check.$$$$.log; \
	fi; \
	echo "88/88 — SM-8: no lib/features/tracks/ repository file imports another repository file (AUD-tracks-15)"; \
	if ! dart run tool/check_sm8_repo_repo_imports.dart > /tmp/sm8_repo_repo_imports_check.$$$$.log 2>&1; then \
	  cat /tmp/sm8_repo_repo_imports_check.$$$$.log; \
	  rm -f /tmp/sm8_repo_repo_imports_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/sm8_repo_repo_imports_check.$$$$.log; \
	fi; \
	echo "89/90 — SM-7 Rule-0: LearningProgramRepository.instance occurrence count under test/ — RATCHET, only growth above the tracked baseline (backlog paydown tracked at DNI-446) fails the gate (AUD-scheduler-23)"; \
	if ! dart run tool/check_sm7_learning_program_singleton.dart > /tmp/sm7_singleton_check.$$$$.log 2>&1; then \
	  cat /tmp/sm7_singleton_check.$$$$.log; \
	  rm -f /tmp/sm7_singleton_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/sm7_singleton_check.$$$$.log; \
	fi; \
	echo "90/90 — AG-1/Rule-0: dart_test.yaml's tags: block declares every tag used via @Tags([...])/tags: [...] under test/ — hard gate, comm -23 between used and declared must be empty (AUD-guardrails-34)"; \
	if ! dart run tool/check_dart_test_tags.dart --check > /tmp/dart_test_tags_check.$$$$.log 2>&1; then \
	  cat /tmp/dart_test_tags_check.$$$$.log; \
	  rm -f /tmp/dart_test_tags_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/dart_test_tags_check.$$$$.log; \
	fi; \
	echo "91/92 — Rule-0: no dead UIBackgroundModes entries in ios/Runner/Info.plist — a declared mode must have a matching AppDelegate.swift handler (App Review 2.5.4 friction + misleading signal for future push work, AUD-platform-02)"; \
	if grep -A2 "UIBackgroundModes" ios/Runner/Info.plist | grep -q .; then \
	  echo "  ios/Runner/Info.plist declares UIBackgroundModes with no corresponding AppDelegate.swift handler"; \
	  echo "  (no performFetchWithCompletionHandler/didReceiveRemoteNotification override, no registerForRemoteNotifications() call)."; \
	  echo "  Either remove the key (notification delivery is 100% local via zonedSchedule today), or land the real"; \
	  echo "  handler + firebase_messaging dependency in the same change and reference a Linear ticket (AUD-platform-02):"; \
	  grep -A2 "UIBackgroundModes" ios/Runner/Info.plist; \
	  FAIL=1; \
	fi; \
	echo "92/93 — AUD-platform-01: firebase.json declares a hosting block (auto-served assetlinks.json, appAssociation not disabled) and AndroidManifest.xml's autoVerify sign-in/invite intent-filters still match AuthRepositoryImpl's link domain — static half of the fix; the live half (assetlinks.json actually resolving 200) is tool/check_assetlinks_live.sh, run post-deploy in CI since it needs network access"; \
	if ! dart run tool/check_platform_deep_link_hosting.dart > /tmp/platform_deep_link_hosting_check.$$$$.log 2>&1; then \
	  cat /tmp/platform_deep_link_hosting_check.$$$$.log; \
	  rm -f /tmp/platform_deep_link_hosting_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/platform_deep_link_hosting_check.$$$$.log; \
	fi; \
	echo "93/94 — AUD-platform-04: no config drift/invalid value in ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS across the Debug/Release/Profile XCBuildConfiguration blocks in ios/Runner.xcodeproj/project.pbxproj (must all be the same valid YES/NO, never a copy-paste bleed like AppIcon from ASSETCATALOG_COMPILER_APPICON_NAME)"; \
	if ! dart run tool/check_ios_asset_symbol_extensions.dart > /tmp/ios_asset_symbol_extensions_check.$$$$.log 2>&1; then \
	  cat /tmp/ios_asset_symbol_extensions_check.$$$$.log; \
	  rm -f /tmp/ios_asset_symbol_extensions_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/ios_asset_symbol_extensions_check.$$$$.log; \
	fi; \
	echo "94/94 — Rule-0: no duplicate top-level key in lib/l10n/app_en.arb or app_he.arb — JSON last-key-wins silently shadows the first definition, defeating arb-parity/gen-l10n/analyze (which all parse via jsonDecode too) and letting dead ICU branches rot unnoticed (AUD-l10n-01)"; \
	if ! dart run tool/check_arb_duplicate_keys.dart > /tmp/arb_duplicate_keys_check.$$$$.log 2>&1; then \
	  cat /tmp/arb_duplicate_keys_check.$$$$.log; \
	  rm -f /tmp/arb_duplicate_keys_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/arb_duplicate_keys_check.$$$$.log; \
	fi; \
	echo "95/95 — R7/TEA-009 (docs/test-artifacts/reassurance-plan.md A1.1): no NEW test/ file reads lib/ source text at runtime (via test/helpers/lib_source.dart or File(...).readAsStringSync()/.readAsLinesSync() on a lib/ path) and asserts on the source string instead of on observable behavior — RATCHET, only growth above the tracked baseline fails the gate"; \
	if ! dart run tool/check_r7_source_text_assertion_ratchet.dart > /tmp/r7_source_text_assertion_check.$$$$.log 2>&1; then \
	  cat /tmp/r7_source_text_assertion_check.$$$$.log; \
	  rm -f /tmp/r7_source_text_assertion_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/r7_source_text_assertion_check.$$$$.log; \
	fi; \
	echo "96/96 — R6b (docs/test-artifacts/reassurance-plan.md Surface 6): the main test lane's RESOLVED recipe (via 'make -n test', filtered to the actual 'flutter test' command line — not this target's own rationale comments, which name the same flag in prose) still passes --test-randomize-ordering-seed=random — order-dependent test pollution (shared global/static state leaking between tests) must stay caught, not silently reverted to a fixed declaration order"; \
	if ! make -n test 2>/dev/null | grep "^flutter test" | grep -q -- "--test-randomize-ordering-seed=random"; then \
	  echo "  Makefile's test: target no longer runs flutter test with --test-randomize-ordering-seed=random (R6b) — order-dependent test pollution can hide again. Restore the flag."; \
	  FAIL=1; \
	fi; \
	echo "97/97 — R6c (docs/test-artifacts/reassurance-plan.md Surface 6): the main test lane's RESOLVED recipe (via 'make -n test', filtered to the actual 'flutter test' command line) still excludes the quarantine tag — a known-flaky test tagged quarantine must be isolatable from the main lane without silently disabling/deleting it. MUST be one quoted --exclude-tags \"serial-tools || quarantine\" boolean-selector expression, not two repeated --exclude-tags flags — flutter test's --exclude-tags is a single-value option (unlike dart test's), so a second occurrence silently overwrites the first instead of adding to it (verified: that shape re-admitted the make-audit-shelling audit_and_arb_parity_test.dart into this parallel lane)"; \
	RESOLVED_TEST_RECIPE=$$(make -n test 2>/dev/null | grep "^flutter test"); \
	if ! echo "$$RESOLVED_TEST_RECIPE" | grep -q -- "--exclude-tags quarantine" && ! echo "$$RESOLVED_TEST_RECIPE" | grep -Eq -- '--exclude-tags "?[^"]*quarantine[^"]*"?'; then \
	  echo "  Makefile's test: target no longer excludes the quarantine tag (R6c) — the flake-quarantine lane is not wired. Restore --exclude-tags \"serial-tools || quarantine\" (or equivalent)."; \
	  FAIL=1; \
	fi; \
	if echo "$$RESOLVED_TEST_RECIPE" | grep -oE -- '--exclude-tags' | wc -l | grep -q "^[2-9]"; then \
	  echo "  Makefile's test: target passes --exclude-tags more than once (R6c) — flutter test's --exclude-tags is a single-value option, so only the LAST occurrence takes effect and earlier ones (e.g. serial-tools) are silently dropped. Combine them into one quoted boolean-selector expression instead, e.g. --exclude-tags \"serial-tools || quarantine\"."; \
	  FAIL=1; \
	fi; \
	echo "98/98 — R6d (docs/test-artifacts/reassurance-plan.md Surface 6): no lib/**.dart file is absent from coverage/lcov.info's SF: denominator beyond the tracked baseline — RATCHET, soft-skips if coverage/lcov.info doesn't exist (run 'make test' or 'make check-coverage-denominator' for the hard-gated version), only growth above the tracked baseline fails when it does"; \
	if ! dart run tool/check_lcov_denominator.dart > /tmp/lcov_denominator_check.$$$$.log 2>&1; then \
	  cat /tmp/lcov_denominator_check.$$$$.log; \
	  rm -f /tmp/lcov_denominator_check.$$$$.log; \
	  FAIL=1; \
	else \
	  cat /tmp/lcov_denominator_check.$$$$.log; \
	  rm -f /tmp/lcov_denominator_check.$$$$.log; \
	fi; \
	echo "99/99 — device-audit-run9 systemic guard: raw Colors.white/Colors.black (+ numbered-opacity siblings) and Color(0xFFFFFFFF)/Color(0xFF000000) hex twins under lib/app/, lib/core/widgets/, lib/features/**/presentation/ — RATCHET, only growth above the tracked baseline fails the gate (device-audit-run9 white-surface cluster)"; \
	if ! dart run tool/check_raw_color_literal_ratchet.dart > /tmp/raw_color_literal_ratchet_check.$$$$.log 2>&1; then \
	  cat /tmp/raw_color_literal_ratchet_check.$$$$.log; \
	  rm -f /tmp/raw_color_literal_ratchet_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/raw_color_literal_ratchet_check.$$$$.log; \
	fi; \
	echo "100/100 — MCF-11/AD-5 (Story 2.4, docs/planning/drift-to-firestore-migration-baseline.md MCF-4/MCF-11; docs/test-artifacts/mcf11-autoincrement-id-in-payload-sweep.md): no NEW site outside lib/core/sync/merge/ feeds a track_id/account_id/child_profile_id payload key directly from the corresponding device-local Drift autoincrement field — RATCHET, only growth above the tracked baseline fails the gate (the baseline is today's already-load-bearing sync-engine design, pending the AD-25 canonical-stable-key redesign)"; \
	if ! dart run tool/check_mcf11_autoincrement_id_in_payload_ratchet.dart > /tmp/mcf11_autoincrement_id_in_payload_check.$$$$.log 2>&1; then \
	  cat /tmp/mcf11_autoincrement_id_in_payload_check.$$$$.log; \
	  rm -f /tmp/mcf11_autoincrement_id_in_payload_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/mcf11_autoincrement_id_in_payload_check.$$$$.log; \
	fi; \
	echo "101/101 — AD-2/AD-28 (Story 2.6): no NEW bare FirebaseFirestore.instance/FirebaseAuth.instance site outside the (not-yet-built, Phase 1) AccountFirebase registry at lib/data/firestore/account_firebase.dart — RATCHET, only growth above the tracked baseline fails the gate (baseline is today's already-load-bearing lib/core/auth/ + lib/core/sync/ singleton usage, pending the Phase-1 registry cutover)"; \
	if ! dart run tool/check_bare_firebase_instance_ratchet.dart > /tmp/bare_firebase_instance_check.$$$$.log 2>&1; then \
	  cat /tmp/bare_firebase_instance_check.$$$$.log; \
	  rm -f /tmp/bare_firebase_instance_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/bare_firebase_instance_check.$$$$.log; \
	fi; \
	echo "102/102 — AD-23/AD-28 (Story 2.6): no lib/features/** (outside its own data/repositories/ implementation dirs) or lib/domain/** file imports the data-access ring (lib/data/firestore/**) past a repository interface — hard gate, zero tolerated"; \
	if ! dart run tool/check_dependency_direction.dart > /tmp/dependency_direction_check.$$$$.log 2>&1; then \
	  cat /tmp/dependency_direction_check.$$$$.log; \
	  rm -f /tmp/dependency_direction_check.$$$$.log; \
	  FAIL=1; \
	else \
	  rm -f /tmp/dependency_direction_check.$$$$.log; \
	fi; \
	echo "103/103 — PROFILE-KEY-SPLIT (docs/firestore-rewrite-map.md item 10): every profile-scoped Firestore collection has exactly one live production keying scheme (Drift int vs ULID) across lib/core/sync/**, functions/src/**, and lib/data/repositories/** plus lib/features/**/data/repositories/** (liveness-filtered, no firestore_-prefix filename requirement) — RATCHET, only growth above the tracked baseline (tool/profile_path_keying_baseline.txt) fails the gate; today's tracked split is bookmarks + learning_order (the DNI-333/334/335 cutover regression)"; \
	if ! dart run tool/check_profile_path_keying.dart > /tmp/profile_path_keying_check.$$$$.log 2>&1; then \
	  cat /tmp/profile_path_keying_check.$$$$.log; \
	  rm -f /tmp/profile_path_keying_check.$$$$.log; \
	  FAIL=1; \
	else \
	  cat /tmp/profile_path_keying_check.$$$$.log; \
	  rm -f /tmp/profile_path_keying_check.$$$$.log; \
	fi; \
	echo "104/104 — PROFILE-ID-INT-SITES (docs/planning/firestore-phase2-plan.md §4 P2-1, hardened at P2-11): every known int-keyed profile-identity site (CF-side typeof/Number.isInteger guards + .doc(String(profileId)) doc-id formula in functions/src/**; int profileId params in the three named lib/core/sync interface/service files; int.tryParse and .id.toString() under lib/features/tutoring/**) is a NAMED entry (file:enclosing-symbol xN, N = occurrence count, never a line number) — RATCHET, a NEW entry fails, a STALE baseline entry (present in tool/profile_id_int_sites_baseline.txt but absent from the current scan) fails, and a baseline entry whose occurrence count N CHANGED (a site added or removed INSIDE an already-baselined symbol) ALSO fails, so a fix must remove/update its baseline line in the same commit; there is no requirement the set ever reach empty"; \
	if ! dart run tool/check_profile_id_int_sites.dart > /tmp/profile_id_int_sites_check.$$$$.log 2>&1; then \
	  cat /tmp/profile_id_int_sites_check.$$$$.log; \
	  rm -f /tmp/profile_id_int_sites_check.$$$$.log; \
	  FAIL=1; \
	else \
	  cat /tmp/profile_id_int_sites_check.$$$$.log; \
	  rm -f /tmp/profile_id_int_sites_check.$$$$.log; \
	fi; \
	if [ "$$FAIL" -eq 1 ]; then \
	  echo "=== audit FAILED — fix violations above ==="; \
	  exit 1; \
	else \
	  echo "=== audit PASSED — all 68 greps clean ==="; \
	fi
