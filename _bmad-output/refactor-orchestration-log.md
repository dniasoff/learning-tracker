# Refactor Orchestration Log

Append-only timestamped log for the v3.3 tech-debt remediation execution.

Plan: `docs/planning/tech-debt-remediation-plan.md` (v3.3)
Tutor brief: `docs/planning/tutor-mode-brief.md`
Tracker: `_bmad-output/refactor-task-tracker.md`

---

## [2026-05-20 02:05] orchestrator-setup
- stream: — | sync-point: — | review: setup | task: —
- detail: Refactor Orchestrator instantiated. Read source documents (plan v3.3, tutor brief, learning_tracker/CLAUDE.md, refactor-orchestration memory). Confirmed v3.3 plan unchanged. Verified `lib/app/` does NOT yet exist (W1.1 still pending). main.dart is 296 lines. _bmad-output directory exists and is empty (prior bmad outputs deleted in working tree).
- next: Pre-populate tracker with 225 W-tasks + B1-B3; create 17 high-level orchestration tasks (5 streams + 7 sync points + 5 verification phases); dispatch S1-S5 in parallel as background Sonnet agents.

## [2026-05-20 02:06] high-level-tasks-created
- stream: — | sync-point: — | review: setup | task: —
- detail: Created 17 high-level orchestration tasks via TaskCreate (#1-#17). Coverage: S1-S5 streams (#1-#5), P1-P7 sync gates (#6-#12), V1 CI gate (#13), V2 adversarial review (#14), V3 fix-all pass (#15), V5 task-truth verification (#16), V6 final smoke (#17). V4 = re-run of V1 after V3.
- next: Write tracker file; dispatch streams.

## [2026-05-20 02:07] user-offline
- stream: — | sync-point: — | review: setup | task: —
- detail: Daniel signalled going offline for the night, hoping the refactor would be complete on waking. Plan's own estimate is ~5-8 working days for AI squad — substantial overnight progress is realistic; full completion in 8 hours is not. Running autonomously per `[[fix-dont-defer]]` + `[[refactor-orchestration]]` memory.
- next: Dispatch S1-S5 streams in parallel.

## [2026-05-20 02:08] streams-dispatched
- stream: ALL | sync-point: — | review: — | task: —
- detail: Dispatched 5 background Sonnet agents (s1-foundation, s2-sync-data, s3-account-tutor, s4-tracks-completion, s5-cleanup-polish), each with self-contained prompts + per-stream log files to avoid concurrent-edit conflicts. Cross-stream coordination is tracker-read based, not SendMessage-based, so streams stay productive without blocking on orchestrator.
- next: Idle until notifications.

## [2026-05-20 02:46] s5-timed-out
- stream: S5 | sync-point: — | review: — | task: W4.21 (in flight at timeout)
- detail: S5 (cleanup-polish) hit a Stream Idle Timeout at 1845s / 224 tool uses with partial response. Reviewed S5's actual progress via git log + tracker filter: 10/50 done (W4.1-W4.5, W4.8-W4.9, W4.16-W4.17, W4.20), W4.21 in-progress, 39 pending. All committed work is preserved on `dev`. Likely cause: 50-task scope was too large for a single Sonnet agent run; agent ran out of API budget before reaching cleanup waves.
- next: Reset W4.21 to pending; dispatch focused S5-continuation agents in smaller chunks (≤10 tasks each) to stay under timeout. Hold W5.4/W5.5 (profile_picker, onboarding) until S3 finishes its tutor UI work to avoid file collisions.

## [2026-05-20 02:46] commit-velocity-update
- stream: — | sync-point: P1 | review: — | task: —
- detail: 30 commits on `dev` in ~38 min. Highlights: W1.1-W1.13, W1.15-W1.16, W1.19-W1.24 (S1 plowing through Foundation); W2.1-W2.9 tracks cluster + W4.7 ProgramStartingPosition VO with B2 enforcement + 20 regression tests (S4); W2.16-W2.20 parent_mode dissolution + W2.41 tutoring skeleton + W3.38-W3.43 tutor schema/rules/Cloud Functions (S3); W2.21-W2.26, W2.28-W2.30 mergers + promotions (S2); W4.1-W4.5, W4.8-W4.9, W4.16-W4.17, W4.20 VOs/domain extractions (S5). P1 cleared at commit f16c2586/c290f94f (W1.10 + W1.11 + barrel files + lint rewrite).
- next: Continue background agents; dispatch S5 continuation.

## [2026-05-20 ~03:08] s5a-continuation-complete
- stream: S5 | sync-point: — | review: — | task: W4.19, W4.21, W4.23, W4.24, W7.1-W7.4
- detail: S5a-continuation (a248816c863801ec5) returned cleanly: 8/9 tasks done (W4.19 SaveLearningOrderUseCase, W4.21 NotificationPreferencesRepository, W4.23 ProfileSession aggregate, W4.24 dashboard side-effect removal, W7.1 reparent 18 exception classes, W7.2 new exceptions (Merge/OutboxDeadLetter/FirestorePermissionDenied), W7.3 SyncPushException + BatchPushException typedef, W7.4 InvalidTrackOperationException). W4.22 blocked on S4's pending W4.15.
- next: Dispatch S5b (W7.12-W7.18 Firebase Analytics + Crashlytics + AppErrorView) and S5c (W5.7-W5.13 sealed unions + primitive obsession) in parallel.

## [2026-05-20 ~03:00] s1-stream-complete
- stream: S1 | sync-point: P1 | review: — | task: W1.x + W7.20-W7.23
- detail: S1 (a8e20975087c77e7f) returned: ~33/34 tasks done across W1 + W7.20-23. ONE blocker: W1.14 (CI hard-fail for custom_lint) blocked by `custom_lint 0.8.1` incompatibility with `analyzer ^9` (exit code 255). Will unblock when custom_lint releases analyzer ^9 support — surfacing to Daniel as wake-up item. Notable: AppLogger.instance now returns singleton (T18 fixed), exception hierarchy + log events constants landed, two new lint rules (no_e_to_string_in_ui WARNING, no_raw_logevent ERROR) registered.
- next: S1 done. P1 cleared earlier. Monitor S2, S4, S5b/S5c.

## [2026-05-20 ~07:00] p5-cleared-and-s2-complete
- stream: S2 | sync-point: P5 | review: — | task: W3.30-W3.37, W3.45-W3.47, W7.5-W7.11
- detail: S2-firestore (ae8970c35bd0797c1) cleared P5 — Firestore wiped, new rules + indexes + Cloud Functions deployed live to torah-study-tracker. Story-27.8 rewritten (17/17 pass). S3 tutor-UI tasks unblocked. S2-telemetry (a45358d1dbb20d192) wired all 7 crisis-class events (merge_row_skipped 10 sites, merge_router_halt, outbox_dead_lettered 2 sites, listener_error, sync_pull_started/completed/failed, permission_denied, 8 tutor events + **B1 regression events bulk_engagement_skipped + lifetime_achievement_skipped in MarkCompletionUseCase**). S2 stream now 67/67 done. dart analyze clean on all 16 telemetry-touched files.
- next: Dispatch S3-UI-A + S3-UI-B continuations for the 19 tutor-UI tasks (P5 unblocked them). Hold S5 god-screens W5.4/W5.5 until S3 finishes onboarding + profile picker.

## [2026-05-20 ~04:00] s4-continuation-complete-all-bugs-coded
- stream: S4 | sync-point: — | review: — | task: W4.12-W4.15, W4.18, W4.25, W4.26
- detail: S4-continuation (a118e6db9e856ef58) returned: all 7 remaining tasks done with regression tests. W4.12 TrackBlueprint aggregate (+ fix pre-existing ScopeEntry type mismatch from in-flight cluster carve), W4.13 TrackBlueprintDraftRepository, W4.14 ProvisionTrackUseCase with **B3 back-date integration check** (5 overdue tasks generated for start=today-5), W4.15 TrackOrder aggregate + OrderingLevel VO + MasechtaOrderingPolicy, W4.18 **B1 CompletionSource discriminator + MarkCompletionUseCase**, W4.25 **B1 sealed BatchPlan with 3 credit-tier leaves + 12 tests**, W4.26 **B1 prior_completion_imports table split** (priorMarkOnly column removed; 25 total B1 tests pass). S4 stream now 20/20 done. **All three bug fix domain layers are now coded; remaining bug-fix surfaces are S2's W7.11 telemetry and S5's W7.25 final smoke.**
- next: S4 done. W4.22 (was blocked on W4.15) is now unblockable — pick up in next S5 cleanup agent.

## [2026-05-20 ~03:40] s5b-and-s5c-complete
- stream: S5 | sync-point: — | review: — | task: W7.12-W7.18 + W5.7-W5.13
- detail: S5b (a914d5662567283e7) returned cleanly — 7/7 done (W7.12 firebase_analytics dep, W7.13 FirebaseAnalyticsService, W7.14-W7.16 Crashlytics routing + non-fatal listener errors, W7.17 AppErrorView with 5-category mapping, W7.18 14 screens migrated). S5c (first run) hit socket disconnection at 11min; S5c-rerun (a1c15bfa9f40a857b) returned cleanly — 7/7 done (W5.7 sealed states in add_track_flow + onboarding, W5.8 SyncOrchestrator pull-guard sealed, W5.9 ListenerSupervisor restart cycle sealed, W5.10 5 sites mode-literal migrated, W5.11 6 sites tier-literal migrated, W5.12 partial SefariaRef migration at analytics boundary, W5.13 audit greps 16+17 added). S5 cumulative: 32/50 done.
- next: Dispatch S5d (W5.14-W5.18 theme + providers — incremental). Hold god screens (W5.1-W5.6) until S3 finishes onboarding/profile-picker. Hold W7.24/W7.25 verification for absolute end.

## [2026-05-20 ~02:50] s3-stream-paused-at-p5
- stream: S3 | sync-point: P5 | review: — | task: W6.x UI gated
- detail: S3 (a755d00b6372b0d36) returned with 26/54 done. Major: account cluster carving (W2.10-W2.20), tutor schema + Firestore rules + Cloud Functions deployed to torah-study-tracker (W3.38-W3.43), full tutor domain layer (W4.27-W4.35), TransactionalEmailService abstraction (W6.8), TutorAuditLogWriter + onUserDeleted cascade Cloud Function + TutorNotificationService (W6.20-W6.25), PiiRedactor extended (W7.19). 17 tutor UI tasks (W6.1-W6.7, W6.9-W6.19) blocked on P5 (S2's W3.46 Firestore rules deploy). P5 partial: S3 has deployed its tutor Cloud Functions; S2 still needs to deploy the rebuilt Firestore rules.
- next: Re-dispatch S3-UI continuation when P5 fully clears (S2 W3.46 done).

---

## [2026-05-20 ~09:00] W7.24-W7.25-V1-complete — verification and CI triage done

- stream: V1 (final verification) | sync-point: P7 | review: W7.24+W7.25 | task: W7.24, W7.25, V1
- detail: W7.24 DONE — B1/B2/B3 all VERIFIED with green unit tests (12+20+13 tests). Integration sites confirmed at correct files: MarkCompletionUseCase, BatchPlan, ProgramStartingPosition, ProvisionTrackUseCase, LifetimeTreeBuilder, step_starting_position_calendar. Detailed report at `_bmad-output/refactor-bug-fix-verification.md`. W7.25 DONE — manual smoke checklist (14 items) written to `_bmad-output/refactor-manual-smoke-checklist.md`. V1 CI gate PARTIAL PASS: lib/ compiles clean (0 errors); tool/ and integration_test/ compile clean after 3 targeted fixes (ambiguous authStateProvider import, missing null guard on contentHash, LearningTrackerApp prefix after bootstrap split). Test suite: 1040 errors remain across 107 test files — all pre-existing from Wave-3 schema rebuild (stream agents did not update existing tests). Made 2 fix commits (854acb82, ecb3f269). Fixes applied: deleted 3 orphaned test files, renamed 8 notification service paths, renamed connectivity service, bulk-fixed CompletionEventsCompanion/StreakEventsCompanion/streakEventDao/table renames across 130+ files, fixed CurriculumTracksCompanion.insert() schema in 106 files. Remaining 1040 errors classified as: delayDays/scheduleType (ScheduleSpec migration W3.27), isActive/deactivatedAt (state+stateChangedAt W3.28), priorMarkOnly (removed W4.26), StreakData fields (W3.37), Drift manager APIs. Options A/B/C documented in V1 report for Daniel's decision.
- next: Daniel to: (1) run 14-item manual smoke checklist; (2) decide Option A/B/C for remaining test errors; (3) once CI passes, tag v1.0 pre-launch milestone.

---
