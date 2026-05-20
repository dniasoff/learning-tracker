# V3 Fix Pass Log

---

## V3-W1 — Sync/Data Criticals

- C1: FIXED / commit e7e8dffa / test test/core/sync/merge/learning_ledger_merger_test.dart (4 tests — snake_case row ingested, camelCase fallback, missing-field skip, dedup)
- C2: FIXED / commit e7e8dffa / test test/core/sync/merge/streak_event_merger_test.dart (4 tests — study_date shape, event_timestamp fallback, missing-both skip, dedup)
- C3: FIXED / commit e7e8dffa / test (covered by C2 test; channel rename verified via SyncOrchestrator._channelToKind)
- C4: FIXED / commit e7e8dffa / deploy torah-study-tracker rules (allow delete: if isOwner(uid)); no separate rules-unit test added (rules security tests require emulator — V3-W2 scope)
- H1: FIXED / commit e7e8dffa / (doc-id = curriculumId only in pushTrack)
- H2: FIXED / commit e7e8dffa / (deleteCurriculumTrack Cloud Function updated — trackType param removed)
- H4: FIXED / commit e7e8dffa / test test/features/learning/data/repositories/h4_lifetime_only_detection_test.dart (2 tests — lifetimeOnly no siyum, live completion creates siyum)
- H5: FIXED / commit e7e8dffa / deploy torah-study-tracker indexes ((state, updated_at) composite added)
- H7: FIXED / commit e7e8dffa / (pushAllLocalData iterates streak_events rows, per-event enqueue with event_type/study_date/ulid)

---

## V3-W3 — B1 Callpath Gaps

- C2 (BulkMarkCompletionUseCase): FIXED / commit fdc99249 / test test/features/learning/domain/use_cases/bulk_mark_completion_use_case_test.dart:C2 — BulkMarkCompletionUseCase B1 engagement gate (6 tests)
- H1 (MarkLiveCompletionUseCase wiring): FIXED / commit 8da0c443 / test test/features/tutoring/domain/use_cases/mark_live_completion_use_case_test.dart:H1 — MarkLiveCompletionUseCase tutor boundary enforcement (7 tests)

---

## V3-Cleanup — Last 2 CI Fails

### Fix 1 — audit_and_arb_parity_test.dart

- Root cause: Root-level Makefile (deleted in commit 99193333) used `[N/12]` bracket format; test was
  checking that format and running `make` from repo root (parent of `learning_tracker/`). After deletion,
  the audit target lives only in `learning_tracker/Makefile` using `N/15` and `N/17` format (no brackets).
- Fix: Updated test to run `make audit` from `packageDir` (= `learning_tracker/`); updated assertions
  to match current header format `N/15` (greps 1-15) and `N/17` (greps 16-17); updated total from 12→17.
- Commit: 75271bda / `fix(test): audit grep count 12 → 17, workingDir repo-root → packageDir`
- Result: PASS (8 tests, 1 skip)

### Fix 2 — store_screenshots_test.dart (Screenshot 1: Dashboard)

- Root cause: Golden file `phone_1_dashboard.png` was stale after W1-W6 refactor (AppErrorView migrations,
  AppBar tutor indicator, profile picker segmentation, god-screen splits).
- Fix: Regenerated golden via `flutter test --update-goldens`; sanity-checked all 5 screenshots pass.
- Commit: 005f4247 / `test(golden): regenerate store_screenshots after refactor`
- Result: PASS (5 tests)

### make ci status

- The 2 target tests now PASS.
- `make ci` still fails at `dart analyze --fatal-infos` due to pre-existing V3 refactor issues in
  unstaged files (`provision_track_use_case_test.dart` directives_ordering, tutoring cast warnings).
  These are NOT caused by V3-Cleanup fixes — they pre-existed and are in unstaged V3 agent work.
  Stopping per hard-rule: "if make ci still fails after your 2 fixes, log it and STOP."
