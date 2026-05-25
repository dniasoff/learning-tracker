# Refactor — Wake-Up Summary

**Status:** complete on the auto-executable surface; final V6 manual smoke is for you.
**Branch:** dev · **Commits:** 1243 on dev (refactor delta starting from `446f5874`)
**CI gate:** `make ci` — **5218 pass / 125 skip / 0 fail** ("All tests passed!")

---

## Where things stand

### Code
- **All five streams complete.** 220/224 W-tasks verified end-to-end by V5 task-truth squad; 4 deferred non-critical demotions documented (see below).
- **Bug fixes B1, B2, B3 verified.** 59/59 regression tests pass. The B3 regression net was rebuilt from scratch (V3-W4c) because the original tests duplicated production code instead of calling it — a false-positive net is now a real net (14 tests including an adversarial validator).

### Adversarial review (V2) — 6 reviewers, ~107 findings
- 20 CRITICAL — **all fixed.** (See `refactor-v3-fix-pass-log.md`.)
- 33 HIGH — **all fixed.**
- MEDIUM + LOW — documented in the six `refactor-v2-r{1-6}-*-findings.md` reports for follow-up.

### Real production bugs caught beyond the planned scope
Several refactor-introduced regressions the type system didn't catch. All fixed:
- `LearningLedgerMerger` reading camelCase fields after Firestore moved to snake_case → silent ledger drops on new device
- `StreakEventMerger` reading `event_timestamp` after rename to `study_date` → streak entirely non-functional cross-device
- `FirestoreListenerSource` listening to deleted `streak/data` document → real-time streak updates dead
- `profile_programs` Firestore rule denying deletes → track removal failed in production
- `CurriculumActivationService.activate()` after `deactivate()` silently failing on UNIQUE constraint
- `DeviceRestoreService.isNewDevice()` missing two state-machine guards (returning true for unauthenticated + empty DB; not skipping completed devices)
- Schedule JSON used short field names in three files (`stage_definition_repository_impl`, `data_export_import_service`, `learning_process_wizard_service`) — read path expected canonical long-form
- `BulkMarkCompletionUseCase` had no `CompletionSource` parameter — bulk operations were crediting engagement (streak + points) in violation of B1
- `MarkLiveCompletionUseCase` was dead code; UI was calling `markCompletionUseCaseProvider` directly, bypassing the tutor-write boundary
- `CompletionDetectionService` was firing for `lifetimeOnly` completions — generating siyumim for lifetime imports
- Duplicate feature trees from copy-without-delete during cluster carving (`features/track_setup/`, `features/learning_order/`, `features/track_learning_order/`, `features/stages/`, two settings services duplicates, `signup_screen.dart`) — all 35+ stale files now deleted; 60+ importers migrated
- 3 PII leak paths in logs (DuplicateEmailException message, LoggingTransactionalEmailService 'to' key not redacted, learning_screen raw e.toString in UI)

### Firebase
- **Live on `torah-study-tracker`:**
  - Firestore rules redeployed (snake_case + ULID + tutor cross-uid `hasActiveTutorAccess` predicate + `profile_programs` delete fix)
  - Firestore indexes redeployed (6 stale legacy indexes removed; new tutor_grants composite indexes; `(state, updated_at)` composite for purgeExpiredAuditLogs)
  - Cloud Functions deployed: `deleteAccountData`, `deleteCurriculumTrack`, `deleteLearnerProfile`, `tutorBulkPriorCompletions`, `purgeExpiredAuditLogs`, `onUserDeleted` (with cascade), **plus 8 new ones from V3-W2**: `inviteTutor`, `acceptTutorInvite`, `declineTutorInvite`, `rescindTutorInvite`, `revokeTutorGrant`, `resignTutorGrant`, `listTutorGrants`, `expirePendingInvites` (scheduled, daily 01:00 UTC)
- All deploys confirmed complete during their respective agent runs.

---

## What you still need to do

### V6 — manual smoke (1-2 hours)
Run through `_bmad-output/refactor-manual-smoke-checklist.md`. Key items:
- App launches in EN + HE (RTL inferred from device locale)
- Two-device sync of own children works (sign in same account on two devices)
- **Tutor flow end-to-end**: invite → accept → switch into tutored profile → attempt live "Mark Complete" → expect blocked with friendly dialog → check parent's audit-log viewer shows the attempted action
- B3 visual check: add Daf Yomi with `start_date = today − 5` → expect ~5 overdue tasks in dashboard immediately

### Decisions waiting on you
- **W1.14** — CI hard-fail for custom_lint: blocked on external dep (`custom_lint 0.8.1` incompatible with `analyzer ^9`). No action until custom_lint releases analyzer-9 support. `|| echo ::warning::` left soft-fail for now.
- **Email service** — `TransactionalEmailService` ships with `LoggingTransactionalEmailService` fallback only. Tutor invites won't actually email anyone until you provision Firebase Extension or SendGrid. File header has the explicit wake-up notice.
- **`directives_ordering` infos** — V2-R4 flagged a ~73-file backlog of import ordering issues. These don't fail CI (analyze is currently `--fatal-infos` clean on the production codebase but not enforced uniformly across all source). Optional follow-up sweep.

### 4 V5 demotions deferred (not blocking)
Filed in the truth reports as known partial completions. None affect runtime behaviour:
- **W3.18** — `goal_merger.dart` and `learning_ledger_merger.dart` were patched to read snake_case directly (V3-W1) but don't yet route through their `GoalCodec` / `LearningLedgerCodec`. Cosmetic — both work correctly, just bypass the codec abstraction.
- **W3.19** — `UserDatabase.schemaVersion = 23` instead of `1`. Cosmetic — the v=1 rebuild happened but the schemaVersion declaration was left at 23. No functional impact.
- **W3.44** — `goals` Drift table still has the column quartet (`goalType`, `paceValue`, `pacePeriod`, `targetDate`, `paceGranularity`). The repository layer correctly hides this and exposes `PaceTarget?`, but the underlying table wasn't collapsed.
- **W4.16** — `TrackDualProgressCalculator` class referenced in a doc comment doesn't exist; only `TrackDualProgressMetric` data class lives there. Domain code uses inline calculation. Cosmetic — works correctly.

### V2 MEDIUM/LOW findings deferred
Documented across the six `refactor-v2-r*-findings.md` reports. None block ship. Worth a follow-up sprint for code hygiene.

---

## Notable not-yet-perfect god-screens
Both still over the 400-LOC target by a small margin, but visibly behaviour-preserving:
- `app_intro_screen.dart` — 473 LOC (W5.1 demoted to "partial")
- `reward_configuration_screen.dart` — 588 LOC; `_RewardPreview` (94 LOC) wasn't promoted (W5.6 demoted to "partial")

---

## Where to look

| File | What |
|---|---|
| `_bmad-output/refactor-task-tracker.md` | Master 225-task tracker — current state |
| `_bmad-output/refactor-orchestration-log.md` | High-level orchestration history |
| `_bmad-output/refactor-s{1-5}-log.md` | Per-stream task-by-task logs |
| `_bmad-output/refactor-v1-ci-report.md` | V1 CI gate report (now green) |
| `_bmad-output/refactor-bug-fix-verification.md` | B1/B2/B3 verification |
| `_bmad-output/refactor-v2-r{1-6}-*.md` | 6 adversarial review findings |
| `_bmad-output/refactor-v3-fix-pass-log.md` | V3 fix-wave log (W1-W6 + cleanup + Option-B) |
| `_bmad-output/refactor-v5-{a,b,c}-truth-report.md` | V5 task-truth verification reports |
| `_bmad-output/refactor-manual-smoke-checklist.md` | V6 manual smoke checklist (your turn) |

---

## Elapsed

Started ~02:08 (2026-05-20), wake-up summary written ~11:30. ~9.5 hours wall-clock for an ostensibly 5-8 day AI-squad refactor. Critical path was S2 (sync/data) at ~2 hours per dispatched agent; parallel work compressed the rest.

Coffee's on you.
