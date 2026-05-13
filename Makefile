.PHONY: help test test-unit test-widget test-integration test-story-4.3 test-story-25.5 test-story-25.7 test-story-25.12 test-story-25.13 test-story-25.16 test-story-25.18 test-epic-25 test-all ci analyze format schema-check linear-sync linear-story linear-check

help:
	@echo "Learning Tracker - Make Commands"
	@echo ""
	@echo "Testing:"
	@echo "  make test-unit          - Run unit tests"
	@echo "  make test-widget        - Run widget tests"
	@echo "  make test-integration   - Run integration tests"
	@echo "  make test-story-4.3     - Run Story 4.3 acceptance tests"
	@echo "  make test-story-25.12   - Run Story 25.12 (DNI-333) acceptance tests"
	@echo "  make test-story-25.13   - Run Story 25.13 (DNI-334) acceptance tests"
	@echo "  make test-story-25.16   - Run Story 25.16 (DNI-337) acceptance tests"
	@echo "  make test-story-25.18   - Run Story 25.18 (DNI-339) acceptance tests"
	@echo "  make test-all           - Run all tests"
	@echo ""
	@echo "Quality:"
	@echo "  make analyze            - Run dart analyze"
	@echo "  make format             - Run dart format"
	@echo "  make schema-check       - Verify Drift v1 profileId/composite-index invariants"
	@echo "  make ci                 - Run full CI check (analyze + format + schema-check + all tests)"
	@echo ""
	@echo "Linear Cache:"
	@echo "  make linear-sync        - Full sync of Linear issues to .linear-cache/"
	@echo "  make linear-story STORY=DNI-XX - Refresh a single story"
	@echo "  make linear-check       - Check cache freshness"

test-unit:
	@echo "Running unit tests..."
	@cd learning_tracker && flutter test test/features/*/data/repositories/*_test.dart test/core/database/*_test.dart

test-widget:
	@echo "Running widget tests..."
	@cd learning_tracker && flutter test test/core/widgets/*_test.dart test/features/*/presentation/*_test.dart

test-integration:
	@echo "Running integration tests..."
	@cd learning_tracker && flutter test integration_test/

test-story-4.3:
	@echo "Running Story 4.3 acceptance tests..."
	@cd learning_tracker && flutter test test/story_acceptance/epic_04_multi_track_test.dart --reporter=expanded

test-story-25.5:
	@echo "Running Story 25.5 acceptance tests..."
	@cd learning_tracker && flutter test test/story_acceptance/epic_25_schema_core_test.dart --plain-name "Story 25.5" --reporter=expanded

test-story-25.7:
	@echo "Running Story 25.7 acceptance tests..."
	@cd learning_tracker && flutter test test/story_acceptance/epic_25_schema_core_test.dart --plain-name "Story 25.7" --reporter=expanded

test-story-25.12:
	@echo "Running Story 25.12 acceptance tests (DNI-333 — SyncEngine decomp Part 1)..."
	@cd learning_tracker && flutter test test/story_acceptance/epic_25_story_12_sync_decomp_part1_test.dart --reporter=expanded

test-story-25.13:
	@echo "Running Story 25.13 acceptance tests (DNI-334 — MergeRouter + sealed EntityMerger)..."
	@cd learning_tracker && flutter test test/story_acceptance/epic_25_story_13_merge_router_test.dart --reporter=expanded

test-story-25.16:
	@echo "Running Story 25.16 acceptance tests (DNI-337 — core/streak/ event log + reducer + sync)..."
	@cd learning_tracker && flutter test test/story_acceptance/epic_25_story_16_streak_test.dart --reporter=expanded

test-story-25.18:
	@echo "Running Story 25.18 acceptance tests (DNI-339 — PinGuard parameterised by PinScope)..."
	@cd learning_tracker && flutter test test/story_acceptance/epic_25_story_18_pin_guard_test.dart --reporter=expanded

test-epic-25:
	@echo "Running Epic 25 acceptance tests..."
	@cd learning_tracker && flutter test test/story_acceptance/epic_25_schema_core_test.dart --reporter=expanded

test-all:
	@echo "Running all tests..."
	@cd learning_tracker && flutter test

analyze:
	@echo "Running dart analyze..."
	@cd learning_tracker && dart analyze

format:
	@echo "Checking dart format..."
	@cd learning_tracker && dart format --set-exit-if-changed .

schema-check:
	@echo "Running schema-check (DNI-327)..."
	@dart run tool/schema_check.dart

ci: analyze format schema-check test-all
	@echo "✓ CI checks passed"

linear-sync:
	@tool/linear-sync.sh sync

linear-story:
	@tool/linear-sync.sh story $(STORY)

linear-check:
	@tool/linear-sync.sh check
