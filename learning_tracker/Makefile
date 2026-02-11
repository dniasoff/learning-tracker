# Learning Tracker -- Story Acceptance Tests
# Usage:
#   make help                Show all targets
#   make test-story-1.2      Run one story's acceptance tests
#   make test-epic-1         Run all Epic 1 stories
#   make test-all-stories    Run every acceptance test
#   make analyze             dart analyze
#   make format-check        dart format --set-exit-if-changed
#   make ci                  analyze + format-check + all stories

FLUTTER    ?= flutter
DART       ?= dart
TEST_DIR   := test/story_acceptance
DART_TEST  := $(FLUTTER) test --tags

.PHONY: help
help: ## Show available targets
	@grep -E '^[a-zA-Z0-9._-]+:.*##' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2}'

# ─── Per-story targets ───────────────────────────────────────────────

# Epic 1 -- Foundation
.PHONY: test-story-1.1 test-story-1.2 test-story-1.3 test-story-1.4 \
        test-story-1.5 test-story-1.6 test-story-1.7 test-story-1.8 \
        test-story-1.9 test-story-1.10 test-story-1.11 test-story-1.12
test-story-1.1:  ## Story 1.1  -- Project initialisation
	$(DART_TEST) story_1_1 $(TEST_DIR)/epic_01_foundation_test.dart
test-story-1.2:  ## Story 1.2  -- Database layer
	$(DART_TEST) story_1_2 $(TEST_DIR)/epic_01_foundation_test.dart
test-story-1.3:  ## Story 1.3  -- Firebase auth repository
	$(DART_TEST) story_1_3 $(TEST_DIR)/epic_01_foundation_test.dart
test-story-1.4:  ## Story 1.4  -- Sefaria API layer
	$(DART_TEST) story_1_4 $(TEST_DIR)/epic_01_foundation_test.dart
test-story-1.5:  ## Story 1.5  -- Navigation shell
	$(DART_TEST) story_1_5 $(TEST_DIR)/epic_01_foundation_test.dart
test-story-1.6:  ## Story 1.6  -- Theme & design tokens
	$(DART_TEST) story_1_6 $(TEST_DIR)/epic_01_foundation_test.dart
test-story-1.7:  ## Story 1.7  -- Riverpod state enums
	$(DART_TEST) story_1_7 $(TEST_DIR)/epic_01_foundation_test.dart
test-story-1.8:  ## Story 1.8  -- Logging infrastructure
	$(DART_TEST) story_1_8 $(TEST_DIR)/epic_01_foundation_test.dart
test-story-1.9:  ## Story 1.9  -- Sync infrastructure
	$(DART_TEST) story_1_9 $(TEST_DIR)/epic_01_foundation_test.dart
test-story-1.10: ## Story 1.10 -- CI / CD pipeline
	$(DART_TEST) story_1_10 $(TEST_DIR)/epic_01_foundation_test.dart
test-story-1.11: ## Story 1.11 -- Security (PIN service)
	$(DART_TEST) story_1_11 $(TEST_DIR)/epic_01_foundation_test.dart
test-story-1.12: ## Story 1.12 -- Hebrew calendar
	$(DART_TEST) story_1_12 $(TEST_DIR)/epic_01_foundation_test.dart

# Epic 2 -- Content
.PHONY: test-story-2.1 test-story-2.2 test-story-2.3 test-story-2.4 test-story-2.5
test-story-2.1: ## Story 2.1 -- Content repository
	$(DART_TEST) story_2_1 $(TEST_DIR)/epic_02_content_test.dart
test-story-2.2: ## Story 2.2 -- Hierarchy browser (backlog)
	$(DART_TEST) story_2_2 $(TEST_DIR)/epic_02_content_test.dart
test-story-2.3: ## Story 2.3 -- Text display & caching
	$(DART_TEST) story_2_3 $(TEST_DIR)/epic_02_content_test.dart
test-story-2.4: ## Story 2.4 -- Curriculum activation
	$(DART_TEST) story_2_4 $(TEST_DIR)/epic_02_content_test.dart
test-story-2.5: ## Story 2.5 -- Bundled content assets (backlog)
	$(DART_TEST) story_2_5 $(TEST_DIR)/epic_02_content_test.dart

# Epic 3 -- Learning Cycle
.PHONY: test-story-3.1 test-story-3.2 test-story-3.3
test-story-3.1: ## Story 3.1 -- Record completion (backlog)
	$(DART_TEST) story_3_1 $(TEST_DIR)/epic_03_learning_cycle_test.dart
test-story-3.2: ## Story 3.2 -- Chazara stages (backlog)
	$(DART_TEST) story_3_2 $(TEST_DIR)/epic_03_learning_cycle_test.dart
test-story-3.3: ## Story 3.3 -- Progress tracking (backlog)
	$(DART_TEST) story_3_3 $(TEST_DIR)/epic_03_learning_cycle_test.dart

# Epic 4 -- Multi-Track
.PHONY: test-story-4.1 test-story-4.2 test-story-4.3
test-story-4.1: ## Story 4.1 -- Track CRUD (backlog)
	$(DART_TEST) story_4_1 $(TEST_DIR)/epic_04_multi_track_test.dart
test-story-4.2: ## Story 4.2 -- Track switching (backlog)
	$(DART_TEST) story_4_2 $(TEST_DIR)/epic_04_multi_track_test.dart
test-story-4.3: ## Story 4.3 -- Per-track bookmarks (backlog)
	$(DART_TEST) story_4_3 $(TEST_DIR)/epic_04_multi_track_test.dart

# Epic 5 -- Stages & Order
.PHONY: test-story-5.1 test-story-5.2
test-story-5.1: ## Story 5.1 -- Custom stage definitions (backlog)
	$(DART_TEST) story_5_1 $(TEST_DIR)/epic_05_stages_order_test.dart
test-story-5.2: ## Story 5.2 -- Custom learning order (backlog)
	$(DART_TEST) story_5_2 $(TEST_DIR)/epic_05_stages_order_test.dart

# Epic 6 -- Scheduler
.PHONY: test-story-6.1 test-story-6.2 test-story-6.3 test-story-6.4 test-story-6.5
test-story-6.1: ## Story 6.1 -- Daily review scheduler (backlog)
	$(DART_TEST) story_6_1 $(TEST_DIR)/epic_06_scheduler_test.dart
test-story-6.2: ## Story 6.2 -- Spaced repetition algorithm (backlog)
	$(DART_TEST) story_6_2 $(TEST_DIR)/epic_06_scheduler_test.dart
test-story-6.3: ## Story 6.3 -- Session management (backlog)
	$(DART_TEST) story_6_3 $(TEST_DIR)/epic_06_scheduler_test.dart
test-story-6.4: ## Story 6.4 -- Calendar integration (backlog)
	$(DART_TEST) story_6_4 $(TEST_DIR)/epic_06_scheduler_test.dart
test-story-6.5: ## Story 6.5 -- Streak tracking (backlog)
	$(DART_TEST) story_6_5 $(TEST_DIR)/epic_06_scheduler_test.dart

# Epic 7 -- Dashboard
.PHONY: test-story-7.1 test-story-7.2 test-story-7.3
test-story-7.1: ## Story 7.1 -- Dashboard screen (backlog)
	$(DART_TEST) story_7_1 $(TEST_DIR)/epic_07_dashboard_test.dart
test-story-7.2: ## Story 7.2 -- Progress charts (backlog)
	$(DART_TEST) story_7_2 $(TEST_DIR)/epic_07_dashboard_test.dart
test-story-7.3: ## Story 7.3 -- Daily summary (backlog)
	$(DART_TEST) story_7_3 $(TEST_DIR)/epic_07_dashboard_test.dart

# Epic 8 -- Gamification
.PHONY: test-story-8.1 test-story-8.2 test-story-8.3
test-story-8.1: ## Story 8.1 -- Points system (backlog)
	$(DART_TEST) story_8_1 $(TEST_DIR)/epic_08_gamification_test.dart
test-story-8.2: ## Story 8.2 -- Rewards & badges (backlog)
	$(DART_TEST) story_8_2 $(TEST_DIR)/epic_08_gamification_test.dart
test-story-8.3: ## Story 8.3 -- Child mode animations (backlog)
	$(DART_TEST) story_8_3 $(TEST_DIR)/epic_08_gamification_test.dart

# Epic 9 -- Onboarding
.PHONY: test-story-9.1 test-story-9.2 test-story-9.3 test-story-9.4 test-story-9.5
test-story-9.1: ## Story 9.1 -- Welcome flow (backlog)
	$(DART_TEST) story_9_1 $(TEST_DIR)/epic_09_onboarding_test.dart
test-story-9.2: ## Story 9.2 -- Curriculum selection (backlog)
	$(DART_TEST) story_9_2 $(TEST_DIR)/epic_09_onboarding_test.dart
test-story-9.3: ## Story 9.3 -- User mode selection (backlog)
	$(DART_TEST) story_9_3 $(TEST_DIR)/epic_09_onboarding_test.dart
test-story-9.4: ## Story 9.4 -- Import existing progress (backlog)
	$(DART_TEST) story_9_4 $(TEST_DIR)/epic_09_onboarding_test.dart
test-story-9.5: ## Story 9.5 -- Tutorial walkthrough (backlog)
	$(DART_TEST) story_9_5 $(TEST_DIR)/epic_09_onboarding_test.dart

# Epic 10 -- Parent Mode
.PHONY: test-story-10.1 test-story-10.2 test-story-10.3 \
        test-story-10.4 test-story-10.5 test-story-10.6
test-story-10.1: ## Story 10.1 -- Parent PIN setup (backlog)
	$(DART_TEST) story_10_1 $(TEST_DIR)/epic_10_parent_mode_test.dart
test-story-10.2: ## Story 10.2 -- Parent dashboard (backlog)
	$(DART_TEST) story_10_2 $(TEST_DIR)/epic_10_parent_mode_test.dart
test-story-10.3: ## Story 10.3 -- Content restrictions (backlog)
	$(DART_TEST) story_10_3 $(TEST_DIR)/epic_10_parent_mode_test.dart
test-story-10.4: ## Story 10.4 -- Time limits (backlog)
	$(DART_TEST) story_10_4 $(TEST_DIR)/epic_10_parent_mode_test.dart
test-story-10.5: ## Story 10.5 -- Progress reports (backlog)
	$(DART_TEST) story_10_5 $(TEST_DIR)/epic_10_parent_mode_test.dart
test-story-10.6: ## Story 10.6 -- Multi-child profiles (backlog)
	$(DART_TEST) story_10_6 $(TEST_DIR)/epic_10_parent_mode_test.dart

# Epic 11 -- Tutor Mode
.PHONY: test-story-11.1 test-story-11.2 test-story-11.3 test-story-11.4
test-story-11.1: ## Story 11.1 -- Tutor PIN setup (backlog)
	$(DART_TEST) story_11_1 $(TEST_DIR)/epic_11_tutor_mode_test.dart
test-story-11.2: ## Story 11.2 -- Assignment creation (backlog)
	$(DART_TEST) story_11_2 $(TEST_DIR)/epic_11_tutor_mode_test.dart
test-story-11.3: ## Story 11.3 -- Student progress view (backlog)
	$(DART_TEST) story_11_3 $(TEST_DIR)/epic_11_tutor_mode_test.dart
test-story-11.4: ## Story 11.4 -- Tutor notes (backlog)
	$(DART_TEST) story_11_4 $(TEST_DIR)/epic_11_tutor_mode_test.dart

# Epic 12 -- Notifications
.PHONY: test-story-12.1 test-story-12.2 test-story-12.3
test-story-12.1: ## Story 12.1 -- Local notifications (backlog)
	$(DART_TEST) story_12_1 $(TEST_DIR)/epic_12_notifications_test.dart
test-story-12.2: ## Story 12.2 -- Push notifications (backlog)
	$(DART_TEST) story_12_2 $(TEST_DIR)/epic_12_notifications_test.dart
test-story-12.3: ## Story 12.3 -- Notification preferences (backlog)
	$(DART_TEST) story_12_3 $(TEST_DIR)/epic_12_notifications_test.dart

# Epic 13 -- Cloud Sync
.PHONY: test-story-13.1 test-story-13.2 test-story-13.3
test-story-13.1: ## Story 13.1 -- Multi-device sync (backlog)
	$(DART_TEST) story_13_1 $(TEST_DIR)/epic_13_cloud_sync_test.dart
test-story-13.2: ## Story 13.2 -- Conflict resolution UI (backlog)
	$(DART_TEST) story_13_2 $(TEST_DIR)/epic_13_cloud_sync_test.dart
test-story-13.3: ## Story 13.3 -- Backup & restore (backlog)
	$(DART_TEST) story_13_3 $(TEST_DIR)/epic_13_cloud_sync_test.dart

# Epic 14 -- Settings
.PHONY: test-story-14.1 test-story-14.2 test-story-14.3 test-story-14.4
test-story-14.1: ## Story 14.1 -- Settings screen (backlog)
	$(DART_TEST) story_14_1 $(TEST_DIR)/epic_14_settings_test.dart
test-story-14.2: ## Story 14.2 -- Data export (backlog)
	$(DART_TEST) story_14_2 $(TEST_DIR)/epic_14_settings_test.dart
test-story-14.3: ## Story 14.3 -- Account management (backlog)
	$(DART_TEST) story_14_3 $(TEST_DIR)/epic_14_settings_test.dart
test-story-14.4: ## Story 14.4 -- App info & legal (backlog)
	$(DART_TEST) story_14_4 $(TEST_DIR)/epic_14_settings_test.dart

# ─── Per-epic targets ────────────────────────────────────────────────

.PHONY: test-epic-1 test-epic-2 test-epic-3 test-epic-4 test-epic-5 \
        test-epic-6 test-epic-7 test-epic-8 test-epic-9 test-epic-10 \
        test-epic-11 test-epic-12 test-epic-13 test-epic-14

test-epic-1:  ## Epic 1  -- Foundation (12 stories)
	$(DART_TEST) epic_1 $(TEST_DIR)/epic_01_foundation_test.dart
test-epic-2:  ## Epic 2  -- Content (5 stories)
	$(DART_TEST) epic_2 $(TEST_DIR)/epic_02_content_test.dart
test-epic-3:  ## Epic 3  -- Learning Cycle (3 stories)
	$(DART_TEST) epic_3 $(TEST_DIR)/epic_03_learning_cycle_test.dart
test-epic-4:  ## Epic 4  -- Multi-Track (3 stories)
	$(DART_TEST) epic_4 $(TEST_DIR)/epic_04_multi_track_test.dart
test-epic-5:  ## Epic 5  -- Stages & Order (2 stories)
	$(DART_TEST) epic_5 $(TEST_DIR)/epic_05_stages_order_test.dart
test-epic-6:  ## Epic 6  -- Scheduler (5 stories)
	$(DART_TEST) epic_6 $(TEST_DIR)/epic_06_scheduler_test.dart
test-epic-7:  ## Epic 7  -- Dashboard (3 stories)
	$(DART_TEST) epic_7 $(TEST_DIR)/epic_07_dashboard_test.dart
test-epic-8:  ## Epic 8  -- Gamification (3 stories)
	$(DART_TEST) epic_8 $(TEST_DIR)/epic_08_gamification_test.dart
test-epic-9:  ## Epic 9  -- Onboarding (5 stories)
	$(DART_TEST) epic_9 $(TEST_DIR)/epic_09_onboarding_test.dart
test-epic-10: ## Epic 10 -- Parent Mode (6 stories)
	$(DART_TEST) epic_10 $(TEST_DIR)/epic_10_parent_mode_test.dart
test-epic-11: ## Epic 11 -- Tutor Mode (4 stories)
	$(DART_TEST) epic_11 $(TEST_DIR)/epic_11_tutor_mode_test.dart
test-epic-12: ## Epic 12 -- Notifications (3 stories)
	$(DART_TEST) epic_12 $(TEST_DIR)/epic_12_notifications_test.dart
test-epic-13: ## Epic 13 -- Cloud Sync (3 stories)
	$(DART_TEST) epic_13 $(TEST_DIR)/epic_13_cloud_sync_test.dart
test-epic-14: ## Epic 14 -- Settings (4 stories)
	$(DART_TEST) epic_14 $(TEST_DIR)/epic_14_settings_test.dart

# ─── Aggregate targets ───────────────────────────────────────────────

.PHONY: test-all-stories analyze format-check ci

test-all-stories: ## Run every story acceptance test
	$(FLUTTER) test $(TEST_DIR)/

analyze: ## Run dart analyze
	$(DART) analyze --fatal-infos

format-check: ## Check dart formatting
	$(DART) format --set-exit-if-changed -o none lib/ test/

ci: analyze format-check test-all-stories ## Full CI: analyze + format + all stories
