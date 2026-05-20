# Refactor S3 Log — Account, Profile, Tutor Stream

Stream: S3 (Account, Profile, Tutor)
Plan: docs/planning/tech-debt-remediation-plan.md v3.3
Tracker: _bmad-output/refactor-task-tracker.md

---

## [2026-05-20 04:30] task-complete
- task: W2.10-W2.15 (account cluster — adopted from S1 commit 96751411)
- commit: 96751411 (committed by S1 as part of W1.3 bootstrap split)
- detail: S1 already carved the account cluster in commit 96751411 as part of the W1.3 bootstrap split. features/auth/ was renamed to features/account/ with all models/repos/services/providers/screens/widgets migrated. The account.dart barrel was filled. All importers (lib/ + test/) updated from features/auth/ to features/account/. The ambiguous authStateProvider export in the barrel was resolved by hiding the legacy stream-based authStateProvider from auth_providers.dart. S3 adopted this work and verified the tracker.
- next: W2.16

## [2026-05-20 04:45] task-complete
- task: W2.16-W2.20, W2.41
- commit: 1f971a34
- detail: Dissolved features/parent_mode/ by relocating all content: reward_configuration_screen + point_config_screen → features/gamification/presentation/screens/ (W2.16); PinEntryWidget already in core/widgets/ (W2.17 no-op); parent_dashboard_aggregator → features/dashboard/domain/services/ (W2.18); PinFlowMachine domain skeleton stub created at features/profiles/domain/services/pin_flow_machine.dart + pin_service (W2.24 already done by S2) (W2.19); all remaining parent_mode files (pin_flow_screen, parent_settings_screen, parent_track_management_screen, PIN dialogs, providers) moved to features/profiles/. Generated .g.dart files copied. External importers in lib/ and test/ updated. features/parent_mode/ deleted (W2.20). tutoring/ skeleton created with empty barrel (W2.41). Remaining analyze errors are pre-existing S2 issues (core/services moves) and S4 issues (tracks duplication), not regressions.
- next: W3.38 (tutor schema)

## [2026-05-20 05:30] task-complete
- task: W3.38-W3.43 (tutor schema + Cloud Functions)
- commit: pending
- detail: W3.38 — TutorGrantDoc model + TutorGrantState enum in tutoring/domain/models/tutor_grant.dart (deterministic doc-id buildGrantId, full lifecycle enum, toFirestore/fromFirestore). W3.39 — three composite indexes added to firestore.indexes.json: (tutor_uid, state), (parent_uid, child_profile_id, state), (tutor_email, state). W3.40 — TutorAuditLogEntry + TutorAuditAction enum in tutoring/domain/models/tutor_audit_log_entry.dart (9 action types, toFirestore/fromFirestore, tutor_name_snapshot for FR-7.2). W3.41 — Firestore rules updated: tutor grant helper functions (isActiveTutorGrant, isTutorOf), tutor_grants top-level collection block (reads for tutor/parent, all client writes denied), audit_log sub-collection block (reads for tutor/parent, all client writes denied), completions block annotated with TUTOR WRITE BLOCK comment + explicit reasoning. 11 static security boundary tests written at test/features/tutoring/w3_41_tutor_security_rules_test.dart — all pass. W3.42 — purgeExpiredAuditLogs scheduled Cloud Function (daily 02:00 UTC, 12-month retention, pages 100 grants, uses Admin SDK recursiveDelete). W3.43 — tutorBulkPriorCompletions callable Cloud Function (5-layer validation: auth, input, grant existence/state, caller==tutor, canBulkPrior perm, bulk-prior-only enforcement, points range, then Admin SDK batch write + audit log entry). Both Cloud Functions deployed to torah-study-tracker successfully.
- next: W4.11 (PinFlowMachine domain)

## [2026-05-20 07:00] task-complete
- task: W4.11, W4.27-W4.35, W7.19
- commit: pending
- detail: W4.11 — PinFlowMachine expanded from stub to full pure-domain state machine (~200 LOC): PinFlowMode, PinFlowStep, PinFlowSnapshot, PinFlowMachine with addDigit/backspace/reset/transitionAfterAsync API. SetParentPinUseCase (returns SetPinResult sealed) and VerifyParentPinUseCase (returns VerifyPinResult sealed) created in features/profiles/domain/use_cases/. W4.27 — TutorGrant aggregate root in tutor_grant_aggregate.dart: 7 sealed GrantState subclasses (PendingGrant, ActiveGrant, DeclinedGrant, RescindedGrant, RevokedByParentGrant, RevokedByTutorGrant, ExpiredGrant), business guards (canRescind/canRevoke/canAccept/canDecline/canResign), TutorGrant.fromDoc() factory. W4.28 — TutorPermissions VO (8 boolean fields, canMarkLiveCompletion always-false invariant, toFirestore/fromFirestore, defaults/readOnly factories, copyWith, equality). W4.29 — ProfileSelection sealed union (OwnProfileSelection/TutoredProfileSelection) + SessionRole enum (parentOfOwn/childSelf/tutor) + ResolvedSession with effectivePermissions. W4.30 — TutorPin VO + TutorPinService facade delegating to PinService tutor-namespace methods (setTutorPin/verifyTutorPin/hasTutorPin/clearTutorPin/lockoutRemainingMinutes). W4.31 — InviteTutorUseCase, AcceptTutorInviteUseCase, DeclineTutorInviteUseCase, RescindTutorInviteUseCase in tutor_invite_use_cases.dart; includes TutorGrantRepository interface and TutorGrantResult sealed union. W4.32 — RevokeTutorGrantUseCase, ResignTutorGrantUseCase, ListIncomingTutorAccessUseCase, ListOutgoingTutorGrantsUseCase in tutor_grant_use_cases.dart. W4.33 — PermissionException abstract base + TutorWriteForbiddenException in core/exceptions/permission_exception.dart. W4.34 — MarkLiveCompletionUseCase<T> in tutoring/domain/use_cases/; uses LiveCompletionDelegate<T> function type to avoid cross-feature import. W4.35 — permissionsProvider(@riverpod) in tutoring/presentation/providers/ returning AsyncValue<ResolvedSession>; build_runner run to generate .g.dart. tutoring.dart barrel filled with all new exports. W7.19 — PiiRedactor.sensitiveKeys extended with displayName, firstName, lastName, city, lat/lon, deviceId, oauthCode, magicLinkUrl, tutor_email, invite_token (and snake/camel variants).
- next: W6.1 (tutor mode UI — gated on P5 cleared in S2 log)

## [2026-05-20 07:30] task-complete
- task: W6.8 (transactional email abstraction)
- commit: pending
- detail: Created TransactionalEmailService abstract interface + 5 sealed payload types (TutorInviteEmail, TutorAcceptedEmail, TutorDeclinedEmail, TutorGrantRevokedEmail, TutorResignedEmail) in core/email/transactional_email_service.dart. Logging fallback (LoggingTransactionalEmailService) is the default implementation — logs to AppLogger but sends no actual email. Prominent INFRASTRUCTURE WAKE-UP NOTICE in the file header documents that no provider is provisioned and gives specific instructions for Firebase Extension / SendGrid / SMTP. Riverpod provider wired (transactionalEmailServiceProvider). All W6.x UI tasks (W6.7, W6.9-W6.25) remain pending until P5 is cleared in S2 log.
- status: W6.8 done; W6.1-W6.7, W6.9-W6.19, W6.25 gated on P5 (S2 log must show sync-point-cleared P5)

## [2026-05-20 08:00] task-complete
- task: W6.20-W6.25 (audit log writer, cascade Cloud Functions, notifications)
- commit: pending
- detail: W6.20-W6.22 — TutorAuditLogWriter domain service in tutoring/domain/services/tutor_audit_log_writer.dart: TutorAuditLogRepository abstract interface (appendEntry, idempotent on ULID entryId); TutorAuditLogWriter with 9 per-action methods (logConfigChanged, logCompletionBulkPrior, logCompletionReset, logBookmarkAdvanced, logProfileEdited, logGoalChanged, logStageChanged, logRewardChanged, logStudyDayChanged); tutorNameSnapshot captured at write-time (W6.21 FR-7.2); ULID-style entryId from millisecond timestamp + action name. W6.23-W6.24 — onUserDeleted Cloud Function extended with 3-step cascade: (1) delete user data via recursiveDelete [existing], (2) revoke all pending/active grants where user is parent (sets state=revoked_by_parent, stamps revoked_at, _delete_cascade=true sentinel), (3) resign all active grants where user is tutor (sets state=revoked_by_tutor). TypeScript compiled clean; all 6 functions re-deployed to torah-study-tracker successfully. W6.25 — TutorNotificationService created in tutoring/domain/services/: 3 typed methods (notifyParentOfDecline, notifyParentOfResignation, notifyTutorOfRevocation) wrapping TransactionalEmailService payload types; fire-and-forget (email service contract absorbs errors); currently backed by LoggingTransactionalEmailService until email infra is provisioned. tutoring.dart barrel updated. dart analyze --fatal-infos clean (0 issues).
- status: W6.20-W6.25 done. Remaining W6 work (W6.1-W6.7, W6.9-W6.19) still gated on P5 (S2 must mark W3.46 done).

## [2026-05-20 08:15] stream-status
- S3 has completed all non-gated tasks. Full completion list:
  W2.10-W2.20 (account cluster, parent_mode dissolution, tutoring skeleton)
  W3.38-W3.43 (tutor Firestore schema, Cloud Functions deployed)
  W4.11 (PinFlowMachine state machine + SetParentPinUseCase + VerifyParentPinUseCase)
  W4.27-W4.35 (tutor domain: TutorGrant, TutorPermissions, ProfileSelection, TutorPin, use cases, MarkLiveCompletionUseCase, permissionsProvider)
  W6.8 (TransactionalEmailService abstraction + LoggingTransactionalEmailService fallback)
  W6.20-W6.25 (TutorAuditLogWriter, onUserDeleted cascade, TutorNotificationService)
  W7.19 (PiiRedactor extended)
- Waiting on P5: W6.1-W6.7, W6.9-W6.19 (17 UI tasks) blocked until S2 marks W3.46 done
- Note: root Makefile deletion (W7.22/S1 task) landed incidentally in S3 commit 99193333
  as it was staged in the working tree; the canonical learning_tracker/Makefile exists.
