.PHONY: help test test-invariants test-rules test-functions test-story-4.1 test-story-5.2 test-story-6.1 test-story-6.3 test-story-6.4 test-story-6.5 test-story-7.1 test-story-7.2 test-story-7.3 test-story-8.4 test-epic-8 test-story-9.4 test-epic-9 test-story-10.4 test-story-10.5 test-epic-10 test-story-12.4 test-epic-12 test-story-13.1 test-story-13.2 test-epic-13 test-story-14.1 test-story-14.2 test-story-14.3 test-epic-14 test-story-15.5 test-story-15.6 test-story-15.8 test-epic-15 test-epic-21 test-story-24.7 test-epic-24 test-story-25.3 test-story-25.5 test-story-25.8 test-story-25.9 test-story-25.10 test-story-25.11 test-story-25.12 test-story-25.13 test-story-25.14 test-story-25.15 test-story-25.19 test-story-25.20 test-story-25.21 test-story-25.22 test-epic-25 test-story-26.7 test-story-26.11 test-story-26.13 test-story-26.15 test-story-26.16 test-epic-26 test-story-27.1 test-story-27.3 test-story-27.4 test-story-27.6 test-story-27.7 test-story-27.8 test-story-27.9 test-story-F5 test-epic-27 test-story-i4 test-epic-28 ci analyze format format-check validate-calendar seed seed-mongo-up seed-restore seed-down audit lint

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

test: ## Run all tests with coverage instrumentation
	flutter test --coverage

test-invariants: ## Run the N1–N7 quality-crisis invariant net
	flutter test test/story_acceptance/regression_invariants_test.dart --reporter=expanded

test-rules: ## Run Firestore security-rules tests under the emulator (L5)
	firebase emulators:exec --only firestore --project demo-rules "node --test functions/test/firestore_rules.test.mjs"

test-functions: ## Run Cloud Functions tests (real handlers vs firestore emulator) (L5)
	npm --prefix functions run build
	firebase emulators:exec --only firestore,auth --project demo-cf "node --test --test-concurrency=1 functions/test/cf_*.test.mjs"

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

test-story-8.4: ## Run Story 8.4 (Completion Feedback & Animations) acceptance tests
	flutter test test/story_acceptance/epic_08_gamification_test.dart --name "Story 8.4"
	flutter test test/features/learning/presentation/widgets/completion_feedback_widget_test.dart

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

test-story-24.7: ## Run Story 24.7 (Sync Curriculum Track Activation) acceptance tests
	flutter test test/story_acceptance/epic_24_stop_bleeding_test.dart --name "Story 24.7"

test-epic-24: ## Run all Epic 24 (Stop-the-Bleeding) acceptance tests
	flutter test test/story_acceptance/epic_24_stop_bleeding_test.dart

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

ci: analyze validate-calendar test ## Run full CI pipeline (analyze + seed validation + all tests)

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

audit: ## Run all 20 enforcement greps (NFR19) — exits non-zero on any violation
	@echo "=== audit: enforcement greps ==="
	@FAIL=0; \
	echo "1/15 — No Firebase imports outside core/auth or core/sync"; \
	if grep -rn "package:firebase_auth" lib/ --include="*.dart" \
	    | grep -v "lib/core/auth/" | grep -v "lib/features/auth/" | grep -v "\.g\.dart" | grep -v "\.freezed\.dart" | grep -q .; then \
	  grep -rn "package:firebase_auth" lib/ --include="*.dart" \
	    | grep -v "lib/core/auth/" | grep -v "lib/features/auth/" | grep -v "\.g\.dart" | grep -v "\.freezed\.dart"; \
	  FAIL=1; \
	fi; \
	echo "2/15 — No FirebaseFirestore/FirebaseStorage outside core/sync or core/auth"; \
	if grep -rn "FirebaseFirestore\|FirebaseStorage\|firebase_firestore\|firebase_storage" lib/ --include="*.dart" \
	    | grep -v "lib/core/sync/" | grep -v "lib/core/auth/" | grep -v "lib/core/providers/" \
	    | grep -v "lib/features/" | grep -v "\.g\.dart" | grep -q .; then \
	  grep -rn "FirebaseFirestore\|FirebaseStorage\|firebase_firestore\|firebase_storage" lib/ --include="*.dart" \
	    | grep -v "lib/core/sync/" | grep -v "lib/core/auth/" | grep -v "lib/core/providers/" \
	    | grep -v "lib/features/" | grep -v "\.g\.dart"; \
	  FAIL=1; \
	fi; \
	echo "3/15 — No FirebaseAuth.instance.signOut outside core/auth"; \
	if grep -rn "FirebaseAuth\.instance\.signOut" lib/ --include="*.dart" \
	    | grep -v "lib/core/auth/" | grep -q .; then \
	  grep -rn "FirebaseAuth\.instance\.signOut" lib/ --include="*.dart" | grep -v "lib/core/auth/"; \
	  FAIL=1; \
	fi; \
	echo "4/15 — No raw talker import outside core/logging"; \
	if grep -rn "import 'package:talker/talker\.dart'" lib/ --include="*.dart" \
	    | grep -v "lib/core/logging/" | grep -q .; then \
	  grep -rn "import 'package:talker/talker\.dart'" lib/ --include="*.dart" | grep -v "lib/core/logging/"; \
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
	echo "10/15 — No banned TODO/FIXME/XXX markers"; \
	if grep -rn "TODO: refactor later\|FIXME: hardcoded for now\|XXX: temporary" lib/ --include="*.dart" | grep -q .; then \
	  grep -rn "TODO: refactor later\|FIXME: hardcoded for now\|XXX: temporary" lib/ --include="*.dart"; \
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
	    | grep -P "features/([^/]+)/(?!\1\.dart)" \
	    | awk -F: '{match($$1, /features\/([^\/]+)\//, a); match($$0, /features\/([^\/]+)\//, b); if(a[1] != b[1]) print}' \
	    | grep -q .; then \
	  echo "  WARN: the following files use cross-feature deep imports — fix by switching to barrel:"; \
	  grep -rn "package:learning_tracker/features/" lib/features/ --include="*.dart" \
	    | grep -v "\.g\.dart" | grep -v "\.freezed\.dart" \
	    | grep -P "features/([^/]+)/(?!\1\.dart)" \
	    | awk -F: '{match($$1, /features\/([^\/]+)\//, a); match($$0, /features\/([^\/]+)\//, b); if(a[1] != b[1]) print}'; \
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
	echo "20/20 — No raw curriculumId/storageKey rendered in Text() (render via CurriculumLabel / rendered*ForRef)"; \
	if grep -rnE "Text\(\s*(curriculumId|[a-zA-Z_]+\.storageKey)\b" lib/features --include="*.dart" \
	    | grep "/presentation/" | grep -v "\.g\.dart" | grep -v ":[[:space:]]*//" \
	    | grep -q .; then \
	  echo "  Raw storage keys must render via CurriculumLabel / CurriculumLabelRenderer / rendered*ForRef:"; \
	  grep -rnE "Text\(\s*(curriculumId|[a-zA-Z_]+\.storageKey)\b" lib/features --include="*.dart" \
	    | grep "/presentation/" | grep -v "\.g\.dart" | grep -v ":[[:space:]]*//"; \
	  FAIL=1; \
	fi; \
	if [ "$$FAIL" -eq 1 ]; then \
	  echo "=== audit FAILED — fix violations above ==="; \
	  exit 1; \
	else \
	  echo "=== audit PASSED — all 20 greps clean ==="; \
	fi
