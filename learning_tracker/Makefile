.PHONY: help test test-story-4.1 test-story-5.2 test-story-6.1 test-story-6.3 test-story-6.4 test-story-6.5 test-story-7.1 test-story-7.2 test-story-7.3 test-story-8.4 test-epic-8 test-story-9.4 test-epic-9 test-story-10.4 test-story-10.5 test-epic-10 test-story-12.4 test-epic-12 test-story-13.1 test-story-13.2 test-epic-13 test-story-14.1 test-story-14.2 test-story-14.3 test-epic-14 test-story-15.5 test-story-15.6 test-story-15.8 test-epic-15 test-epic-21 test-story-24.7 test-epic-24 test-story-25.3 test-story-25.5 test-story-25.8 test-story-25.11 test-epic-25 ci analyze format validate-calendar

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

test: ## Run all tests
	flutter test

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

test-story-25.11: ## Run Story 25.11 (AuthRepository sole firebase_auth consumer) acceptance tests
	flutter test test/story_acceptance/epic_25_schema_core_test.dart --name "Story 25.11"

test-epic-25: ## Run all Epic 25 (Schema + Core Foundation) acceptance tests
	flutter test test/story_acceptance/epic_25_schema_core_test.dart

ci: analyze validate-calendar test ## Run full CI pipeline (analyze + seed coverage + all tests)

analyze: ## Run dart analyze
	dart analyze

validate-calendar: ## Validate every (program, date) in seed has a ref + that ref resolves
	dart run tool/validate_seed_coverage.dart

format: ## Format all Dart code
	dart format .
