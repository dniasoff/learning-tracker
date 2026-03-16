.PHONY: help test test-story-4.1 test-story-5.2 test-story-6.1 test-story-6.3 test-story-6.4 test-story-6.5 test-story-7.1 test-story-7.2 test-story-7.3 test-story-8.4 test-epic-8 test-story-13.1 ci analyze format

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

test-story-13.1: ## Run Story 13.1 (Push-on-Write with Offline Queuing) acceptance tests
	flutter test test/story_acceptance/epic_13_cloud_sync_test.dart --name "Story 13.1"

ci: analyze test ## Run full CI pipeline (analyze + all tests)

analyze: ## Run dart analyze
	dart analyze

format: ## Format all Dart code
	dart format .
