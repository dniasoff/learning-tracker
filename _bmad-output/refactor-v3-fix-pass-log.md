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

---

## V3-W2 — Tutor Mode Criticals

### C1 — MarkLiveCompletionUseCase never called

ALREADY FIXED in V3-W3 (commit 8da0c443). UI now routes via MarkLiveCompletionUseCase. No action.

### C2 — isActiveTutorGrant dead; tutors denied all subcollection reads

FIXED / commit 5a9347bc

- **Approach:** Added `hasActiveTutorAccess(ownerUid, profileId)` function to firestore.rules. Uses
  `exists()` on a new `tutor_active_access/{tutorUid}_{parentUid}_{profileId}` secondary index
  maintained by Cloud Functions. Avoids needing grantId in rules context (isActiveTutorGrant requires
  grantId which isn't available when reading subcollection paths). O(1) lookup.
- **Rules change:** Added `|| hasActiveTutorAccess(uid, profileId)` to `allow read` on all 12
  profile subcollections: completions, streak_events, learning_ledger, settings, stage_definitions,
  curriculum_tracks, bookmarks, learning_order, preferences, goals, import_metadata, profile_programs.
  Tutor WRITE rules unchanged — TUTOR WRITE BLOCK still holds.
- **New collection:** `tutor_active_access/{accessId}` — client writes denied, tutor read allowed.
- **Deploy:** Firestore rules deployed to torah-study-tracker. Compiled successfully with 3 expected
  warnings (unused isActiveTutorGrant function — retained for future per-grantId use).
- **Tests:** 12 new structural assertions added to w3_41_tutor_security_rules_test.dart (groups 5 + 6).
  22 pass, 1 intentionally skipped.

### C3 — No lifecycle Cloud Functions; entire invite/accept/revoke flow stub-only

FIXED / commit 14fd65e3

- **7 new Cloud Functions deployed** to torah-study-tracker (us-central1):
  - `inviteTutor` — creates pending grant with 256-bit invite_token (NFR-3) and default permissions.
  - `acceptTutorInvite` — validates auth.email == grant.tutor_email (security gate), writes
    tutor_active_access index, clears invite_token (single-use), captures tutor_name_snapshot from
    Firebase Auth (partial H3 fix), uses runTransaction for atomicity.
  - `declineTutorInvite` — validates by email or tutorUid, transitions to declined.
  - `rescindTutorInvite` — parent-only, transitions pending → rescinded.
  - `revokeTutorGrant` — parent-only, transitions active → revoked_by_parent, deletes
    tutor_active_access atomically via runTransaction.
  - `resignTutorGrant` — tutor-only, transitions active → revoked_by_tutor, deletes
    tutor_active_access atomically via runTransaction.
  - `listTutorGrants` — mode=incoming or outgoing, returns serialised grant docs.
  - `onUserDeleted` — updated to also delete tutor_active_access docs on account deletion.
- **FirestoreTutorGrantRepository** implemented at
  `lib/features/tutoring/data/repositories/firestore_tutor_grant_repository.dart`. Uses
  `cloud_functions` package (same pattern as AccountManagementService, no direct Firestore import).
- **Both stub providers replaced:** manage_tutors_providers.dart and tutor_grant_providers.dart
  both now wire FirestoreTutorGrantRepository (M1 fix in passing — both providers point to real repo).
- **Tests:** 10 unit tests in firestore_tutor_grant_repository_test.dart — all pass.
  TypeScript compiles clean (tsc exit 0).

### C4 — Pending invite 7-day TTL never enforced server-side

FIXED / commit 14fd65e3 (same commit as C3)

- **`expirePendingInvites` Cloud Function** added to functions/src/index.ts. Scheduled daily at
  01:00 UTC (offset from purgeExpiredAuditLogs at 02:00 to avoid simultaneous runs). Queries
  `tutor_grants` where `state == 'pending' AND expires_at <= now`. For each matching grant:
  uses runTransaction to update state='expired' + delete invite_token + write audit log entry.
  Logs per-grant and summary counts.
- **Deploy:** Deployed to torah-study-tracker as 1st Gen scheduled function.
- **Tests:** 3 structural assertions in w3_41_tutor_security_rules_test.dart (group 6: V2-R3 C4).

### Summary

| Fix | Commit | Deploy | Tests |
|-----|--------|--------|-------|
| C1 | Already fixed (8da0c443) | N/A | Already covered |
| C2 | 5a9347bc | Firestore rules ✓ | 12 new assertions (22 pass) |
| C3 | 14fd65e3 | 7 Cloud Functions ✓ | 10 unit tests pass |
| C4 | 14fd65e3 | 1 Cloud Function ✓ | 3 structural assertions |
