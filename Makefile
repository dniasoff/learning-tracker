.PHONY: help test test-unit test-widget test-integration test-story-4.3 test-story-25.5 test-story-25.7 test-story-25.12 test-story-25.13 test-story-25.16 test-story-25.18 test-story-27.5 test-epic-25 test-epic-27 test-all ci analyze format schema-check audit arb-parity gen-arch-tables linear-sync linear-story linear-check

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
	@echo "  make test-story-27.5    - Run Story 27.5 (DNI-381) acceptance tests"
	@echo "  make test-epic-27       - Run Epic 27 acceptance tests"
	@echo "  make test-all           - Run all tests"
	@echo ""
	@echo "Quality:"
	@echo "  make analyze            - Run dart analyze"
	@echo "  make format             - Run dart format"
	@echo "  make schema-check       - Verify Drift v1 profileId/composite-index invariants"
	@echo "  make audit              - Run all 12 enforcement greps + custom_lint (NFR19)"
	@echo "  make arb-parity         - Check app_en.arb keys exist in app_he.arb (NFR14)"
	@echo "  make gen-arch-tables    - Print Markdown table of all Drift tables + column counts"
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

test-story-27.5:
	@echo "Running Story 27.5 acceptance tests (DNI-381 — bulk-mark-prior does not credit streak)..."
	@cd learning_tracker && flutter test test/story_acceptance/epic_27_story_05_bulk_mark_prior_test.dart --reporter=expanded

test-epic-27:
	@echo "Running Epic 27 acceptance tests..."
	@cd learning_tracker && flutter test test/story_acceptance/epic_27_story_05_bulk_mark_prior_test.dart --reporter=expanded

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

# audit — DNI-389 (Story 27.13, NFR19).
#
# Runs all 12 enforcement greps from PART 4 of the rebuild plan
# (docs/planning/epics-greenfield-rebuild.md) plus custom_lint.
# Every grep is run from the `learning_tracker/` directory so the
# `lib/` paths in the patterns resolve correctly.
# Exits non-zero on the first violation; prints file:line for each hit.
audit:
	@echo "Running audit — 12 enforcement greps + custom_lint (DNI-389)..."
	@FAIL=0; \
	LIB=learning_tracker/lib; \
	\
	echo ""; \
	echo "[1/12] FirebaseAuth.instance.signOut outside core/auth (NFR3/24.3)"; \
	HITS=$$(grep -rn 'FirebaseAuth\.instance\.signOut' "$$LIB/" \
	  --include='*.dart' \
	  | grep -v '/core/auth/' || true); \
	if [ -n "$$HITS" ]; then echo "$$HITS"; FAIL=1; else echo "  OK"; fi; \
	\
	echo ""; \
	echo "[2/12] import 'package:talker/talker.dart' outside core/logging (NFR24/24.5)"; \
	HITS=$$(grep -rn "import 'package:talker/talker\.dart'" "$$LIB/" \
	  --include='*.dart' \
	  | grep -v '/core/logging/' || true); \
	if [ -n "$$HITS" ]; then echo "$$HITS"; FAIL=1; else echo "  OK"; fi; \
	\
	echo ""; \
	echo "[3/12] .withDefault(const Constant(0)) in tables (Story 25.1)"; \
	HITS=$$(grep -rn '\.withDefault(const Constant(0))' "$$LIB/core/database/tables/" \
	  --include='*.dart' || true); \
	if [ -n "$$HITS" ]; then echo "$$HITS"; FAIL=1; else echo "  OK"; fi; \
	\
	echo ""; \
	echo "[4/12] useHebrewTermsProvider outside core/labels + core/preferences + settings + onboarding (Story 25.9)"; \
	HITS=$$(grep -rn 'useHebrewTermsProvider' "$$LIB/" \
	  --include='*.dart' \
	  | grep -v '/core/labels/' \
	  | grep -v '/core/preferences/' \
	  | grep -v '/features/settings/' \
	  | grep -v '/features/onboarding/' \
	  | grep -v ':[[:space:]]*//' || true); \
	if [ -n "$$HITS" ]; then echo "$$HITS"; FAIL=1; else echo "  OK"; fi; \
	\
	echo ""; \
	echo "[5/12] DateTime.now() outside core/time (NFR21/Story 25.10)"; \
	HITS=$$(grep -rn 'DateTime\.now()' "$$LIB/" \
	  --include='*.dart' \
	  | grep -v '/core/time/' || true); \
	if [ -n "$$HITS" ]; then echo "$$HITS"; FAIL=1; else echo "  OK"; fi; \
	\
	echo ""; \
	echo "[6/12] import package:firebase_auth outside core/auth+sync + features/auth (NFR3/Story 25.11)"; \
	HITS=$$(grep -rnE "^import 'package:firebase_auth" "$$LIB/" \
	  --include='*.dart' \
	  | grep -v '/core/auth/' \
	  | grep -v '/core/sync/' \
	  | grep -v '/features/auth/' || true); \
	if [ -n "$$HITS" ]; then echo "$$HITS"; FAIL=1; else echo "  OK"; fi; \
	\
	echo ""; \
	echo "[7/12] debugPrint / raw print() in production code (NFR24/Story 25.19)"; \
	HITS=$$(grep -rn 'debugPrint\|^\s*print(' "$$LIB/" \
	  --include='*.dart' \
	  | grep -v '\.g\.dart' \
	  | grep -v '\.freezed\.dart' || true); \
	if [ -n "$$HITS" ]; then echo "$$HITS"; FAIL=1; else echo "  OK"; fi; \
	\
	echo ""; \
	echo "[8/12] currentAccountId = 1 hardcoded (Story 25.21)"; \
	HITS=$$(grep -rn 'currentAccountId[[:space:]]*=[[:space:]]*1\b' "$$LIB/" \
	  --include='*.dart' || true); \
	if [ -n "$$HITS" ]; then echo "$$HITS"; FAIL=1; else echo "  OK"; fi; \
	\
	echo ""; \
	echo "[9/12] empty/comment-only catch blocks (NFR23, AUD-app-06)"; \
	HITS=$$(dart run tool/check_empty_catch_blocks.dart 2>&1) || FAIL=1; \
	echo "$$HITS"; \
	\
	echo ""; \
	echo "[10/12] EdgeInsets.only(left:|right:) — RTL violation (NFR16/UX-DR5/AX-1, AUD-profiles-18)"; \
	HITS=$$(dart run tool/check_edgeinsets_rtl.dart 2>&1) || FAIL=1; \
	echo "$$HITS"; \
	\
	echo ""; \
	echo "[10b/12] Positioned(left:|right:) — RTL violation (AX-1, AUD-profiles-23)"; \
	HITS=$$(dart run tool/check_positioned_rtl.dart 2>&1) || FAIL=1; \
	echo "$$HITS"; \
	\
	echo ""; \
	echo "[11/12] import package:cloud_firestore / firebase_storage outside core/sync + core/auth (NFR3)"; \
	HITS=$$(grep -rnE "^import 'package:(cloud_firestore|firebase_storage)" "$$LIB/" \
	  --include='*.dart' \
	  | grep -v '/core/sync/' \
	  | grep -v '/core/auth/' \
	  | grep -v 'core/providers/firebase_providers.dart' || true); \
	if [ -n "$$HITS" ]; then echo "$$HITS"; FAIL=1; else echo "  OK"; fi; \
	\
	echo ""; \
	echo "[12/12] Raw HebrewTerms. calls outside core/labels/ or core/constants/ (B11-7 — must go via label layer)"; \
	HITS=$$(grep -rn 'HebrewTerms\.' "$$LIB/" \
	  --include='*.dart' \
	  | grep -v '/core/labels/' \
	  | grep -v '/core/constants/' \
	  | grep -v '_test\.dart' \
	  | grep -v '\.g\.dart' || true); \
	if [ -n "$$HITS" ]; then echo "$$HITS"; FAIL=1; else echo "  OK"; fi; \
	\
	echo ""; \
	if [ $$FAIL -ne 0 ]; then \
	  echo "audit FAILED — fix violations above before committing."; \
	  exit 1; \
	fi; \
	echo "All 12 greps clean."; \
	echo ""; \
	echo "Running custom_lint..."; \
	cd learning_tracker && dart run custom_lint; \
	echo "audit PASSED."

arb-parity:
	@echo "Running arb-parity (DNI-389)..."
	@dart run tool/arb_parity_check.dart

gen-arch-tables:
	@echo "Generating architecture table list (DNI-391)..."
	@dart run tool/gen_arch_tables.dart

ci: analyze format schema-check test-all
	@echo "✓ CI checks passed"

linear-sync:
	@tool/linear-sync.sh sync

linear-story:
	@tool/linear-sync.sh story $(STORY)

linear-check:
	@tool/linear-sync.sh check
