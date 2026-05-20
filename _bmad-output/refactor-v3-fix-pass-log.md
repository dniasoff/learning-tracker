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
