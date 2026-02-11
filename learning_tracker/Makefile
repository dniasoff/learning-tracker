.PHONY: help test test-story-4.1 ci analyze format

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

test: ## Run all tests
	flutter test

test-story-4.1: ## Run Story 4.1 (Track Management) acceptance tests
	flutter test test/story_acceptance/epic_04_multi_track_test.dart

ci: analyze test ## Run full CI pipeline (analyze + all tests)

analyze: ## Run dart analyze
	dart analyze

format: ## Format all Dart code
	dart format .
