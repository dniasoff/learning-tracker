# V2-R2 Domain & DDD Adversarial Review

**Reviewer:** V2-R2 (Domain & DDD)  
**Date:** 2026-05-20  
**Branch:** dev  
**Scope:** `lib/features/*/domain/`, `lib/core/domain/value_objects/`, `lib/core/exceptions/`, aggregates, use cases, sealed unions, value objects  
**Reference:** tech-debt-remediation-plan.md v3.3, tutor-mode-brief.md, refactor-bug-fix-verification.md, refactor-s3-log.md, refactor-s4-log.md, refactor-s5-log.md, project_completion_credit_policy.md

---

## Executive Summary

The domain layer is substantially better than pre-refactor state. Most VOs enforce their invariants on construction, the sealed hierarchies are structurally sound, and the B2/B3 fixes are correctly integrated. However, six meaningful gaps remain that could silently break data integrity in production.

**Verdict: CONDITIONAL PASS.** The critical and high findings must be addressed before the domain layer is considered sound. The medium findings are important quality debt but do not break data invariants today.

---

## CRITICAL

### C1 — `CompletionDetectionService.checkAndRecordCompletions` is B1-unaware: siyum/ledger entries fire for `lifetimeOnly` source

**File:** `lib/features/learning/data/repositories/completion_repository_impl.dart:172-183`  
**Also:** `lib/features/learning/domain/services/completion_detection_service.dart:32-81`

`markComplete` in `CompletionRepositoryImpl` calls `CompletionDetectionService.checkAndRecordCompletions` unconditionally at line 173-183 — there is no gate on `awardGamificationPoints` (the B1 proxy flag). The detection service auto-writes a `LearningLedgerData` row when all leaves in a unit are complete. The ledger is the achievement-tier store (siyumim, reports).

Per the B1 three-tier policy, `lifetimeOnly` source completions MUST NOT write siyum/ledger entries. `bulkInTrack` completions SHOULD write ledger entries (achievement tier fires). The current code fires `checkAndRecordCompletions` for ALL three sources, including `lifetimeOnly`. This means a lifetime-import that happens to complete the last leaf of a masechta will auto-generate a siyum record, violating the policy.

The `CompletionDetectionService.checkAndRecordCompletions` signature has no `source` or `awardAchievement` parameter, so it cannot distinguish the two cases.

**Recommended fix:** Add a `bool creditsAchievement` parameter (or pass `CompletionSource` directly) to `checkAndRecordCompletions`. In `CompletionRepositoryImpl.markComplete`, derive `creditsAchievement` from `awardGamificationPoints` but distinguish `bulkInTrack` (true) vs `lifetimeOnly` (false) — currently both map to `awardGamificationPoints = false`, so the single boolean cannot make this distinction. The correct fix is to pass `CompletionSource` through `CompletionRepository.markComplete` (or via `CompletionRequest`) and gate the detection call on `source.creditsAchievement`.

---

### C2 — `BulkMarkCompletionUseCase` is completely B1-unaware: no source parameter, no credit-tier enforcement

**File:** `lib/features/learning/domain/use_cases/bulk_mark_completion_use_case.dart:1-22`

`BulkMarkCompletionUseCase.call(BulkCompletionRequest)` delegates directly to `CompletionRepository.bulkMarkComplete` with no mention of `CompletionSource`. It does not accept a source parameter, does not set `awardGamificationPoints`, and does not touch `BatchPlan`. The existing `BulkCompletionRequest` defaults `awardGamificationPoints = true`, so callers who forget to set it to `false` will inadvertently credit engagement for bulk-in-track operations.

`MarkCompletionUseCase` (single-item) was correctly updated to accept `CompletionSource`. Its bulk counterpart was not. They now have asymmetric B1 awareness even though both sit in the same `use_cases/` directory. The verification report (`refactor-bug-fix-verification.md`) does not list this use case as a verified integration site.

**Recommended fix:** Add `CompletionSource source = CompletionSource.live` parameter to `BulkMarkCompletionUseCase.call`. Map to `awardGamificationPoints: source.creditsEngagement` on the `BulkCompletionRequest`. This mirrors exactly what `MarkCompletionUseCase` does for the single-item path.

---

## HIGH

### H1 — `MarkLiveCompletionUseCase` is defined but NOT wired into the live completion call site

**File:** `lib/features/content_browsing/presentation/screens/text_display_screen.dart:632-640`  
**Also:** `lib/features/tutoring/domain/use_cases/mark_live_completion_use_case.dart:54-66`

`MarkLiveCompletionUseCase` (W4.34) exists and enforces the tutor-write-forbidden invariant. However, the actual live completion call site in `text_display_screen.dart` at line 632 calls `markCompletionUseCaseProvider` directly — it does NOT go through `MarkLiveCompletionUseCase`. The tutor gating in the screen is done ad hoc via `_isTutorSession()` (line 729-733), which checks `incomingTutorGrantsProvider` for any active grant. This means:

1. The domain invariant (`TutorWriteForbiddenException`) is never actually thrown in the live path — the check is a UI-layer boolean, not a domain-enforced exception.
2. Any future call site that calls `markCompletionUseCaseProvider` directly (e.g. a keyboard shortcut, a notification action) will bypass both the UI gate and the domain gate.
3. `MarkLiveCompletionUseCase` exists as dead domain code — it has no real consumer.

The `_isTutorSession` helper also has a subtle bug: it checks whether the user has ANY active incoming grant, not whether they are specifically viewing a tutored profile. A user could have an active tutor grant to someone else's child while legitimately marking their own child's completion.

**Recommended fix:** Wire `markCompletionUseCaseProvider` (or its presentation-layer equivalent) through `MarkLiveCompletionUseCase`. The use case accepts a `ResolvedSession` and a `LiveCompletionDelegate<T>` — inject the session from `permissionsProvider` and the delegate from `markCompletionUseCase.call`. Replace the ad hoc `_isTutorSession` check entirely.

---

### H2 — `AcceptTutorInviteUseCase` does not check whether a `PendingGrant` has already expired client-side

**File:** `lib/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart:127-133`  
**Also:** `lib/features/tutoring/domain/models/tutor_grant_aggregate.dart:135-147`

`TutorGrant.canAccept` returns `true` when `grantState is PendingGrant` — but `PendingGrant` carries `expiresAt` and a grant can be in `pending` state on the client while already past its 7-day expiry. The aggregate does not have an `isExpiredPending` predicate, and `canAccept` does not compare `expiresAt` against the current time.

The `AcceptTutorInviteUseCase` therefore allows the use case to dispatch an accept request to the Cloud Function for an expired pending grant. The server will reject it, but the client-side domain layer claims the operation is valid (`!canAccept` returns `false`), giving a misleading signal. The UI will then show the precondition error message "Grant is not in a state that can be accepted" (which refers to the state machine, not expiry), causing user confusion.

The `GrantState` hierarchy has an `ExpiredGrant` leaf, but it is only reached when Firestore's stored `state` is already `'expired'`. If expiry has occurred but the Cloud Function has not yet run the TTL cleanup, the local doc still shows `pending` and the aggregate gives a false positive.

**Recommended fix:** Add `bool get isExpiredPending` to `PendingGrant` that computes `DateTime.now().isAfter(expiresAt)`. Gate `canAccept` on `!isExpiredPending`. In `AcceptTutorInviteUseCase`, check this and return a `TutorGrantPreconditionError` with an expiry-specific message before dispatching to the repository.

---

### H3 — `PacePeriodTarget` accepts zero or negative rate with no invariant enforcement

**File:** `lib/features/scheduler/domain/models/goal_entity.dart:58-79`

`PacePeriodTarget` is a `const` class with fields `rate: int` and `period: String`. There is no constructor validation. A `rate` of 0 or -1 is constructable and will silently produce broken scheduler behaviour (division by zero when computing items/day, negative deadlines, etc.). Similarly, `period` accepts any string — passing `'per_month'` (unsupported) or an empty string will silently produce undefined scheduler calculations.

`DeadlineTarget` has the same problem: `dueDate` can be `DateTime(1970)` (past date), which is a logically incoherent goal.

**Recommended fix:**  
- `PacePeriodTarget`: assert `rate > 0` on construction; add `assert(period == 'per_day' || period == 'per_week')` or a `PacePeriod` enum.  
- `DeadlineTarget`: for new goals, assert `dueDate.isAfter(DateTime.now())` — or at minimum document the accepted range.

---

### H4 — `DelaySchedule` accepts negative `delayDays` with no validation

**File:** `lib/core/domain/value_objects/schedule_spec.dart:96-115`

`DelaySchedule` is a `const` constructor accepting `delayDays: int`. The class comment says "0 means due immediately" and there is no assert or range check. A value of `-3` is constructable and would produce a review date in the past, creating permanently-overdue tasks on first track provision with no user-visible explanation.

`WeeklySchedule` and `RollingSchedule` both validate their inputs (assert non-empty days, windowSize > 0), making the missing `DelaySchedule` validation an inconsistency in the same sealed class.

**Recommended fix:** Add `assert(delayDays >= 0, 'delayDays must be non-negative')` to `DelaySchedule`. All three leaves of `ScheduleSpec` then enforce their invariants consistently.

---

### H5 — `TutorGrantDoc.fromFirestore` uses unsafe `dynamic` call (`ts.toDate()`) that silently returns `null` on malformed data

**File:** `lib/features/tutoring/domain/models/tutor_grant.dart:162-172`

The `parseTs` helper inside `TutorGrantDoc.fromFirestore` catches all exceptions and returns `null`:

```dart
try {
  final ts = v as dynamic;
  final dt = ts.toDate() as DateTime?;
  return dt?.toLocal();
} catch (_) {
  return null;
}
```

`invitedAt` and `updatedAt` are required fields in `TutorGrantDoc` (non-nullable, no default). They use `DateTime.parse(data['invited_at'] as String)` directly (lines 184, 189) — so a Firestore `Timestamp` object for `invited_at` will throw a `TypeError` at the cast rather than silently return null. However, `acceptedAt`, `declinedAt`, `revokedAt`, and `expiresAt` use `parseTs`, which means a Firestore `Timestamp` stored in `accepted_at` will be silently dropped (returning `null`). This leaves an `ActiveGrant` with `acceptedAt = null`, causing `_buildState` at line 173 to fall back to `acceptedAt: doc.acceptedAt ?? doc.updatedAt` — a silent data loss without any diagnostic.

The comment `// Firestore Timestamp from the SDK has a toDate() method. Cast through dynamic to avoid importing firebase packages outside core/.` is a layering workaround, but the catch-all exception suppression is too broad.

**Recommended fix:** At minimum, log the suppressed exception via `AppLogger` before returning null so the data loss is observable. Better: accept a `dynamic Function(dynamic)? timestampConverter` argument in `fromFirestore` so the data layer can inject the Firebase `Timestamp.toDate` conversion, removing the dynamic call from the domain entirely.

---

## MEDIUM

### M1 — `TrackBlueprint.studyDays` field is `Map<int, String>` — raw string day-type values, not typed

**File:** `lib/features/tracks/setup/domain/aggregates/track_blueprint.dart:205-220`

`TrackBlueprint.studyDays` is typed `Map<int, String>` where the value is an unvalidated string (presumably `'study'` / `'skip'` / `'review'`). The aggregate was introduced as part of W4.12 specifically to replace `Object?` fields, yet this field remains a raw primitive. The `StudyDayPattern` VO (W4.4, at `lib/core/domain/value_objects/study_day_pattern.dart`) already models exactly this concept with proper key validation (1-7) and `DayKind` typed values.

The bridge `_toResult` in `ProvisionTrackUseCase` passes `blueprint.studyDays` through to `AddTrackResult.studyDays` (also `Map<int, String>`), meaning the primitive leak propagates all the way to the DB write.

**Recommended fix:** Change `TrackBlueprint.studyDays` to `StudyDayPattern`. Update `_toResult` to serialize via `pattern.entries.map((e) => MapEntry(e.key, e.value.storageKey)).toMap()`.

---

### M2 — `SefariaRef.titlePart` / `addressPart` silently accept Talmudic folio addresses like `"2a-3b"` but the regex only matches a single folio

**File:** `lib/core/domain/value_objects/sefaria_ref.dart:131-137`

The `_splitTail` regex is `r'^(.*?)(\d+[a-z]?)$'`. This correctly handles `"Shabbat 2a"` (single folio) but silently drops the second folio of a range like `"Shabbat 2a-3b"` — `titlePart` returns `"Shabbat 2a"` and `addressPart` returns `"3b"`, which inverts the semantics. A range reference is a valid Sefaria reference but the VO's segment operations produce misleading output for it.

This is not a construction invariant failure (the `value` is stored correctly), but callers who rely on `titlePart`/`addressPart` for display or fuzzy matching will get wrong results for ranges.

**Recommended fix:** Document the range limitation explicitly (a `// Note: range refs "Shabbat 2a-3b" are stored correctly but titlePart/addressPart operate on the trailing address token only`). If range refs are a real use case, extend the regex or add an `isRange` predicate.

---

### M3 — `InviteTutorUseCase` email validation is weak: only checks for `@` presence

**File:** `lib/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart:95-99`

The invite validation is `email.isEmpty || !email.contains('@')`. This accepts `"@"` and `"a@"` as valid emails. The tutor grant `grantId` is built from the email via `buildGrantId` which replaces non-alphanumerics with underscores — a badly-formed email like `"@"` produces a grantId of `"____parentUid____childProfileId"`, which is not meaningfully deterministic.

More importantly, the `tutorEmail` field on `TutorGrantDoc` is documented as "Canonical lower-cased tutor email" and is used for the Firebase Auth email-to-UID binding at accept time. A malformed email will never match any Firebase account and the invite will be permanently stuck pending until it expires.

**Recommended fix:** Use a minimal RFC 5322 check: `RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)`. The domain layer should reject obviously invalid emails before a Cloud Function round-trip is wasted.

---

### M4 — `ManualCompletionUseCase` is not B1-aware: the lifetime-mark path has no `CompletionSource` concept

**File:** `lib/features/learning/domain/use_cases/manual_completion_use_case.dart:14-65`

`ManualCompletionUseCase` calls `_repository.recordCompletion(... isManual: true)`. It does not carry a `CompletionSource` discriminator. The policy specifies that "lifetime marking" must only credit lifetime data — no streak, no points, no siyum. The `isManual: true` flag is not the same as `CompletionSource.lifetimeOnly`: it signals the siyum type (manual override), not the credit tier.

If lifetime-marking UI is wired through this use case, the credit policy for the lifetime-only tier cannot be enforced at the use-case boundary; enforcement depends entirely on whatever the repository does with `isManual`.

**Recommended fix:** Add `CompletionSource source` parameter to `ManualCompletionUseCase.call`. Pass it through to the repository so the repository can gate engagement and achievement side effects.

---

### M5 — `TutorAuditAction.fromJson` throws `ArgumentError` on unknown action strings — makes old audit logs unreadable after schema evolution

**File:** `lib/features/tutoring/domain/models/tutor_audit_log_entry.dart:35-46`

`TutorAuditAction.fromJson` has `_ => throw ArgumentError('Unknown TutorAuditAction: $value')` as the default case. The audit log is a 12-month retention store. If a future app version adds a new `TutorAuditAction` value and then the user downgrades or is on an older client, `TutorAuditLogEntry.fromFirestore` will throw on encountering the unknown action, crashing the entire audit log viewer.

This is a forward-compatibility issue common to all versioned serialized types, but it is especially important for an audit log that is explicitly designed to persist across version boundaries.

**Recommended fix:** Add an `unknown(String rawValue)` catch-all leaf to `TutorAuditAction` (or return a nullable and handle it gracefully in `fromFirestore`). This mirrors the pattern used in `PaceGranularity.fromStorageKey` which returns `null` for unknown values.

---

### M6 — `PinFlowMachine._afterChangeAsync` cannot distinguish verify-current failure from save failure because `step` has already advanced

**File:** `lib/features/profiles/domain/services/pin_flow_machine.dart:304-328`

In `_afterChangeAsync`, the success branch at line 322-328 advances `step` when `_state.step == PinFlowStep.verifyCurrent`. But the failure branch at line 306-318 also checks `_state.step == PinFlowStep.verifyCurrent` to decide which error message to show. The machine's `step` is in `verifyCurrent` before the async call and remains there after the async call (on failure). So far this is correct.

However, the failure branch at line 306-318 does NOT advance `step` — it stays in `verifyCurrent`. On the success path for `verifyCurrent`, `step` transitions to `enterNew` (line 324). So for verify-current success, the machine transitions. For verify-current failure, it stays. This is correct behaviour.

The subtler issue: when the machine is in `confirm` step of the change flow and the async save fails (line 313-318), the error says `'Failed to save PIN'` and resets to `enterNew`. But the `_state.step` at this point is `PinFlowStep.confirm` — the check `_state.step == PinFlowStep.verifyCurrent` is false, so the fallback case fires. This is correct. However: if the adapter calls `transitionAfterAsync` twice (e.g. due to a double-tap or race condition), the second call sees `_pendingPin = null` (cleared at line 196) and returns immediately. This is correctly guarded.

The real issue: `_afterChangeAsync` on success at line 322-326 checks `_state.step == PinFlowStep.verifyCurrent` but by the time `transitionAfterAsync` is called, the machine's step is still `verifyCurrent` (it was not advanced when `_pendingPin` was set). So the step check is valid. The flow is **correct** but difficult to reason about because the step during the async window is ambiguous (is it "waiting to verify current" or "waiting to save new"?). This creates a correctness risk for future maintainers.

**Recommended fix:** Introduce a `PinAsyncState { idle, waitingVerifyCurrent, waitingConfirmSave }` to make the awaited async type explicit. This eliminates the step-based discrimination in `_afterChangeAsync` and makes the state machine self-documenting. Medium priority — current behaviour is correct but fragile.

---

### M7 — `GrantState.isTerminal` delegates to `rawState.isTerminal` but `isActive` checks `this is ActiveGrant` — inconsistent abstraction level

**File:** `lib/features/tutoring/domain/models/tutor_grant_aggregate.dart:30-33`

```dart
bool get isActive => this is ActiveGrant;
bool get isTerminal => rawState.isTerminal;
```

`isActive` uses the sealed subtype check (stays in the sealed layer), but `isTerminal` delegates down to the raw `TutorGrantState` enum. Both approaches work, but the inconsistency means `GrantState` is not a full abstraction over `TutorGrantState` — callers can only rely on `isActive` being sealed-class-based; `isTerminal` leaks the raw enum's logic. If a new terminal state is added to `TutorGrantState` without updating both the sealed hierarchy and `rawState.isTerminal`, the two will diverge.

**Recommended fix:** Implement `isTerminal` directly in `GrantState` as a sealed check:
```dart
bool get isTerminal => switch (this) {
  DeclinedGrant() || RescindedGrant() || RevokedByParentGrant() || 
  RevokedByTutorGrant() || ExpiredGrant() => true,
  _ => false,
};
```
This keeps the abstraction clean and makes new-state additions exhaustively caught by the Dart compiler.

---

## LOW

### L1 — `StudyDayPattern` missing `toStorageMap()` / `fromStorageMap()` serialization helpers

**File:** `lib/core/domain/value_objects/study_day_pattern.dart`

`StudyDayPattern` has `entries` (the raw map) and `dayKindFor` but no first-class serialization helpers. Callers that serialize to the DB or Firestore must manually iterate `entries` and call `e.value.storageKey`. Compare `ScheduleSpec` (has `storageKey`, `delayDays`, `daysOfWeek`, `rollingWindowSize` for write-back) and `CalendarSystem` (has `storageKey` / `fromStorageKey`). The VO should own its own serialization round-trip to avoid scattered encoding logic.

---

### L2 — `ResolvedSession._ownerPermissions()` returns a `TutorPermissions` with `canMarkLiveCompletion = false` — semantically wrong for owners

**File:** `lib/features/tutoring/domain/models/session_role.dart:94-103`

`_ownerPermissions()` returns `const TutorPermissions(...)` which always sets `canMarkLiveCompletion = false` (hardcoded in the `TutorPermissions` constructor). The comment above says "live completion which is owner-only and always true for owner roles" — but `effectivePermissions.canMarkLiveCompletion` will return `false` for an owner session, contradicting the comment. Any code that checks `effectivePermissions.canMarkLiveCompletion` to decide whether to show the mark-complete button will incorrectly disable it for owners.

Currently this bug is masked because `MarkLiveCompletionUseCase` gates on `session.isTutorSession` (not on `effectivePermissions.canMarkLiveCompletion`), and the UI tutor gate uses `_isTutorSession()` directly. But once `MarkLiveCompletionUseCase` is properly wired (see H1), callers that use `effectivePermissions.canMarkLiveCompletion` will fail for owners.

**Recommended fix:** Introduce `OwnerPermissions` (not extending `TutorPermissions`) or add a separate `canMarkLiveCompletion` getter to `ResolvedSession` that returns `!isTutorSession`, bypassing `TutorPermissions` for owner roles.

---

### L3 — `TutorGrantDoc.buildGrantId` uses simple underscore-replacement that can collide for emails like `a.b@c.com` and `a_b@c_com`

**File:** `lib/features/tutoring/domain/models/tutor_grant.dart:122-136`

`buildGrantId` replaces all non-alphanumeric characters with `_`. The emails `a.b@example.com` and `a_b@example_com` produce the same encoded prefix (`a_b_example_com`), yielding the same `grantId` for different tutors on the same child profile. A collision would cause a second invite to silently overwrite the first in Firestore.

The comment `// Simple concatenation with separator...` acknowledges the approach is simple but does not acknowledge the collision risk.

**Recommended fix:** Use a content-addressable hash (e.g. `sha256(tutorEmail)`) for the email portion of the grant ID. This is collision-free, deterministic, and still pre-account (no UID required).

---

### L4 — `BatchPlan.classify` factory does not guard against empty `commands` list

**File:** `lib/features/learning/domain/entities/batch_plan.dart:44-53`

`BatchPlan.classify(commands: [], source: CompletionSource.live)` returns a `LiveBatchPlan` with zero commands. `CompletionWriter.commitBatch` will receive an empty batch and presumably no-op, but a domain invariant that `commands.isNotEmpty` would catch accidental empty-batch invocations at the classification boundary rather than silently in the data layer.

**Recommended fix:** Add `assert(commands.isNotEmpty, 'BatchPlan must have at least one command')` to the `BatchPlan` abstract constructor.

---

### L5 — `MarkCompletionUseCase` doc says it "Throws StageProgressionException" but this exception is never thrown by the use case itself

**File:** `lib/features/learning/domain/use_cases/mark_completion_use_case.dart:52-54`

The doc comment states `Throws [StageProgressionException] if stage progression is violated.` The use case does not throw this — it delegates to the repository, which may throw it. The misleading doc creates a false expectation that the use case validates stage progression (domain invariant), when in reality the repository does (data invariant). A caller who wraps only the use case call in a `try/catch` for `StageProgressionException` will catch it correctly, but the location of enforcement is architecturally wrong — stage progression is a domain invariant that should be enforced in the domain layer, not the data layer.

**Recommended fix (immediate):** Correct the doc comment to say `The underlying repository may throw [StageProgressionException] if stage progression is violated.` **(Longer-term):** Move stage progression validation into the use case (domain layer) using `StageOrder.isMonotonicFrom` on the prior completions — matching the existing `StageOrder.isMonotonicFrom` static method that appears to have been built for exactly this purpose.

---

## Summary Table

| # | Severity | Title | File:Line |
|---|---|---|---|
| C1 | CRITICAL | `CompletionDetectionService` B1-unaware: siyum fires for `lifetimeOnly` | `completion_repository_impl.dart:172` |
| C2 | CRITICAL | `BulkMarkCompletionUseCase` B1-unaware: no source param | `bulk_mark_completion_use_case.dart:1` |
| H1 | HIGH | `MarkLiveCompletionUseCase` exists but is not wired into live call site | `text_display_screen.dart:632` |
| H2 | HIGH | `AcceptTutorInviteUseCase` does not check `PendingGrant.isExpiredPending` | `tutor_invite_use_cases.dart:127` |
| H3 | HIGH | `PacePeriodTarget` accepts zero/negative rate; `period` unconstrained | `goal_entity.dart:58` |
| H4 | HIGH | `DelaySchedule` accepts negative `delayDays` — inconsistent vs sibling leaves | `schedule_spec.dart:96` |
| H5 | HIGH | `TutorGrantDoc.fromFirestore` silently drops Firestore `Timestamp` fields | `tutor_grant.dart:162` |
| M1 | MEDIUM | `TrackBlueprint.studyDays` remains `Map<int, String>` despite `StudyDayPattern` VO existing | `track_blueprint.dart:220` |
| M2 | MEDIUM | `SefariaRef.titlePart`/`addressPart` mishandles range refs like `"Shabbat 2a-3b"` | `sefaria_ref.dart:131` |
| M3 | MEDIUM | `InviteTutorUseCase` email validation too weak (only `@` presence) | `tutor_invite_use_cases.dart:95` |
| M4 | MEDIUM | `ManualCompletionUseCase` not B1-aware for lifetime-mark path | `manual_completion_use_case.dart:14` |
| M5 | MEDIUM | `TutorAuditAction.fromJson` throws on unknown values — breaks forward compat | `tutor_audit_log_entry.dart:45` |
| M6 | MEDIUM | `PinFlowMachine._afterChangeAsync` step discrimination fragile under async races | `pin_flow_machine.dart:304` |
| M7 | MEDIUM | `GrantState.isTerminal` delegates to raw enum rather than sealed check | `tutor_grant_aggregate.dart:33` |
| L1 | LOW | `StudyDayPattern` missing `toStorageMap`/`fromStorageMap` helpers | `study_day_pattern.dart` |
| L2 | LOW | `ResolvedSession._ownerPermissions()` sets `canMarkLiveCompletion = false` for owners | `session_role.dart:94` |
| L3 | LOW | `TutorGrantDoc.buildGrantId` can collide for emails with `.` vs `_` | `tutor_grant.dart:122` |
| L4 | LOW | `BatchPlan.classify` does not guard against empty `commands` | `batch_plan.dart:44` |
| L5 | LOW | `MarkCompletionUseCase` doc misattributes stage-progression enforcement to use case | `mark_completion_use_case.dart:52` |

**Total: 19 findings (2 CRITICAL · 5 HIGH · 7 MEDIUM · 5 LOW)**

---

## B-Fix Correctness Assessment

**B1 (three-tier credit policy):**  
Core enum (`CompletionSource`), `MarkCompletionUseCase`, `BatchPlan`, and `LifetimeTreeBuilder` are all correctly implemented. However, C1 and C2 above reveal that two callpaths (`CompletionDetectionService` and `BulkMarkCompletionUseCase`) are not wired into the B1 enforcement, meaning the policy is incomplete in production paths. B1 is PARTIALLY correct.

**B2 (start-window enforcement):**  
`ProgramStartingPosition.create` correctly enforces `[today-30, today]`. `StartDateWindowException` extends `ValidationException`. `fromLegacyGrammar` correctly delegates to `create`. `allowedWindow` is provided for UI pickers. The step_starting_position_calendar.dart wiring is verified. B2 is CORRECTLY INTEGRATED.

**B3 (back-dated overdue tasks):**  
`ProvisionTrackUseCase` re-encodes the VO to legacy grammar with the correct offset. `daysFromToday` is provided. The B3 verification tests pass. B3 is CORRECTLY INTEGRATED (noting that B3 depends on B2 which is correct).
