# V2-R3 Adversarial Review — Tutor Mode
**Reviewer:** V2-R3
**Date:** 2026-05-20
**Scope:** End-to-end tutor mode: domain, data, presentation, Firestore rules, Cloud Functions
**Severity legend:** CRITICAL / HIGH / MEDIUM / LOW

---

## Executive summary

The security architecture is sound in its intent and the primary Firestore-layer defence (live-completion write block) holds. However, four significant gaps exist that collectively mean the tutor mode is **not production-ready**. The most critical is that `MarkLiveCompletionUseCase` is never called in the actual completion code path — the defence is implemented but not wired. Several other issues combine incomplete data-layer wiring with architectural choices that will cause real problems at runtime.

Total findings: **21**

---

## CRITICAL

### C1 — `MarkLiveCompletionUseCase` is never invoked on the live completion path

**File:** `learning_tracker/lib/features/content_browsing/presentation/screens/text_display_screen.dart:632`
**Also:** `learning_tracker/lib/features/learning/domain/use_cases/mark_completion_use_case.dart:53`

`_handleComplete()` calls `markCompletionUseCaseProvider` directly:
```dart
final useCase = ref.read(markCompletionUseCaseProvider);
final result = await useCase(CompletionRequest(...));
```

`markCompletionUseCaseProvider` resolves to `MarkCompletionUseCase` (the learning-feature use case), which does no tutor-session check at all. `MarkLiveCompletionUseCase` from `tutoring/domain/use_cases/mark_live_completion_use_case.dart` — the use case that throws `TutorWriteForbiddenException` — is exported by the barrel but is **never constructed, never provided, and never called**.

The UI catches `TutorWriteForbiddenException` (line 679) and shows a friendly dialog, but the exception is never thrown because the guard use case is never run.

**Impact:** The ONE client-side prohibition is not enforced at the application layer. The only actual defence is the Firestore rule `isOwner(uid)` on the completions subcollection, which requires the tutor to have a different Firebase auth uid from the profile owner. If the data layer is ever wired and the tutor somehow obtains the owner's credentials, the client guard provides zero resistance. More practically: if a tutor is simultaneously a parent (FR-1.4 scenario) viewing their own child, the ownership check would pass and they could mark a live completion for their own child while "in tutor mode".

**Disposition:** Wire `MarkLiveCompletionUseCase` as a wrapping layer around `markCompletionUseCaseProvider`. The provider should read `permissionsProvider` (W4.35), construct a `MarkLiveCompletionUseCase`, and call it with the delegate pointing to `MarkCompletionUseCase.call`.

---

### C2 — `isActiveTutorGrant` helper is defined but never used; tutor read access on subcollections is silently blocked

**File:** `learning_tracker/firestore.rules:60–67` (function defined but never referenced), `firestore.rules:153–157` (comment acknowledges the gap)

`isActiveTutorGrant()` is declared but its only call site is its own definition block — it is never referenced in any `allow read` or `allow write` rule. Meanwhile the comment at line 153 explicitly states:

> "Subcollection reads are owner-only by default; tutor reads on subcollections flow through Cloud Functions in V1."

This means a tutor cannot directly read `completions`, `bookmarks`, `goals`, `curriculum_tracks`, `stage_definitions`, `settings`, `preferences`, `learning_ledger`, or any other profile subcollection from the client. However, the Cloud Function `tutorBulkPriorCompletions` only *writes* completions — it does not provide any read proxy. There is no Cloud Function that lets a tutor read the learner's existing data.

**Impact:** Tutors cannot read any child data at all once the real data layer is connected. The entire tutoring UI (bookmarks, progress, configuration screens) will receive Firestore permission-denied errors. The `isActiveTutorGrant` function is dead code. This is a fundamental data-access gap, not a polish issue.

**Disposition:** Either (a) apply `isActiveTutorGrant` to all subcollection `allow read` rules (requires grantId to be passed in the read request — feasible for direct reads but not for list queries), or (b) add Cloud Function read proxies for each subcollection type a tutor needs. Option (a) is cleaner. Requires design decision on how the client passes grantId for subcollection reads.

---

### C3 — No `acceptInvite` Cloud Function exists; the accept flow is entirely stub-backed

**File:** `learning_tracker/functions/src/index.ts` (entire file — no `acceptInvite` export)
**Also:** `learning_tracker/lib/features/tutoring/presentation/providers/tutor_grant_providers.dart:42` (stub returns `_notImplemented`)
**Also:** `learning_tracker/lib/features/tutoring/presentation/screens/accept_invite_screen.dart:109` (`_buildStubGrant()`)

The `AcceptInviteScreen` builds a fake stub grant instead of loading the real grant from Firestore, then calls `AcceptTutorInviteUseCase` which calls `_StubTutorGrantRepository.acceptInvite()` which returns `TutorGrantFailure(message: 'The tutoring backend is not yet connected.')`.

The invite lifecycle — `inviteTutor`, `acceptInvite`, `declineInvite`, `rescindInvite`, `revokeGrant`, `resignGrant` — has zero Cloud Function implementations. Only `tutorBulkPriorCompletions`, `purgeExpiredAuditLogs`, and `onUserDeleted` (cascade) are deployed.

**Impact:** The entire tutor invite/accept/revoke flow is non-functional at runtime. No grant documents can be created. No tutors can be activated. All downstream features (tutor PIN gate, profile picker segmentation, AppBar indicator) will show empty/default state because `incomingTutorGrantsProvider` always returns `[]`.

**Disposition:** This is tracked as gated work ("when the Cloud Functions data layer lands") but must be resolved before any end-to-end testing is possible. Needs Cloud Functions for each lifecycle operation, plus a real `FirestoreTutorGrantRepository` implementation.

---

### C4 — Invite token expiry is NOT enforced server-side; pending grants never expire

**File:** `learning_tracker/functions/src/index.ts` (no expiry logic anywhere in the accept path — accept path does not exist)
**Also:** `docs/planning/tutor-mode-brief.md:56` (FR-2.3: "A pending invite expires 7 days after creation")

There is no Cloud Function that periodically sweeps `tutor_grants` where `state == 'pending'` and `expires_at < now` and transitions them to `expired`. The `purgeExpiredAuditLogs` function handles audit-log retention but not grant expiry. The `onUserDeleted` cascade handles deletion but not expiry.

On the client side, `TutorGrant._buildState()` computes a client-local `PendingGrant(expiresAt: ...)` but this is display-only — it never fires a mutation.

**Impact:** A pending invite theoretically "expires" but the `state` field remains `pending` in Firestore forever. A tutor could accept an arbitrarily old invite, bypassing the 7-day security window. The NFR-3 requirement ("Invite tokens are 256-bit random, single-use, server-validated, expire in 7 days") is only partially met at the data-model level.

**Disposition:** Add a scheduled Cloud Function (daily) that queries `tutor_grants` where `state == 'pending'` and `expires_at <= Timestamp.now()` and updates `state = 'expired'`. The `accept` Cloud Function (when written) must also reject acceptance of expired grants atomically.

---

## HIGH

### H1 — Tutor PIN is keyed by profile ID, not by tutor account — violates FR-5.2

**File:** `learning_tracker/lib/features/profiles/domain/services/pin_service.dart:52`
**Also:** `learning_tracker/lib/features/tutoring/domain/services/tutor_pin_service.dart:87–130`

`PinService._tutorPinKey(profileId)` returns `'profile_${profileId}_tutor_pin_hash'`. The PIN is namespaced to the profile ID, not to the tutor's account.

FR-5.2 requires "Each tutor account has a **single Tutor PIN** that covers access to all their tutored children (one PIN per tutor, not per child)." The current implementation stores a separate PIN per `profileId`, meaning if tutor A tutors children with profile IDs 1 and 3, they would need to set two different PINs — or the code would treat them as separate PINs.

The `TutorPinEntryGate` is parameterised by `profileId` (line 29–36) and its doc comment says "the tutor's own learner-profile ID (the PIN namespace)". This is a semantically confused concept: the PIN namespace should be the tutor's auth UID, not a profile ID.

**Impact:** A tutor tutoring multiple children would encounter inconsistent PIN behaviour (different PIN per tutored child). The spec says one PIN covers all. This also means a tutor without any own children (a pure-tutor signup) has no natural `profileId` to supply.

**Disposition:** Change the PIN storage key to `tutor_${tutorUid}_pin_hash` (keyed on the tutor's Firebase auth UID, not a profile ID). Propagate the UID through `TutorPinService` and remove the `profileId` parameter.

---

### H2 — Audit log write is NOT in the same transaction as the completion batch

**File:** `learning_tracker/functions/src/index.ts:451–474` (batch commit), `index.ts:479–491` (audit log written AFTER)

The `tutorBulkPriorCompletions` function:
1. Commits the completion documents with `await batch.commit()` (line 474)
2. Then writes the audit entry with `await auditRef.set(...)` (line 483)

These are sequential `await` calls, not inside a Firestore transaction. If the process crashes between them, completions are recorded but the audit log entry is missing.

FR-4.4 requires "every config change, goal edit, bulk-prior, reset, bookmark advance, profile edit by a tutor produces an audit entry" and NFR-4 says "within the same transaction."

**Impact:** Audit log entries for bulk-prior completions can be silently lost on Cloud Function crash. In a production environment with high write volume or restarts, audit completeness cannot be guaranteed.

**Disposition:** Wrap both the completion `batch.set()` calls and the `auditRef.set()` in a single Firestore `runTransaction()`. The 500-document limit still applies within a transaction.

---

### H3 — `tutor_name_snapshot` in Cloud Function is read from the grant document, not from Firebase Auth

**File:** `learning_tracker/functions/src/index.ts:485`

```typescript
tutor_name_snapshot: grant.tutor_name_snapshot ?? "",
```

The Cloud Function reads `tutor_name_snapshot` from the grant doc itself. But there is no code that writes `tutor_name_snapshot` to the grant document in the first place — the field is never set during invite creation or acceptance.

The client-side `TutorAuditLogWriter` (dart) takes `tutorNameSnapshot` as a constructor parameter (line 61) with the intent that "the caller supplies it from Firebase Auth `displayName` at the time of action." But the Cloud Function does not have access to a caller-supplied name — it reads it from the stored grant data, which is always `null` (never written).

**Impact:** `tutor_name_snapshot` will always be `""` in every audit log entry. FR-7.2 ("parent's audit log records 'tutor account deleted' and retains the tutor's display name as a string") is broken. Parents will see blank tutor names in the audit log.

**Disposition:** During `acceptInvite` (when that Cloud Function is written), read the tutor's display name from `admin.auth().getUser(callerUid)` and store it as `tutor_name_snapshot` on the grant document. Update it on profile-name change events. In `tutorBulkPriorCompletions`, fall back to fetching from Auth if the grant snapshot is empty.

---

### H4 — AppBar tutor indicator shows based on "has any active grant" not "is currently viewing tutored profile"

**File:** `learning_tracker/lib/app/router/app_shell.dart:26–28`

```dart
final hasActiveTutoredProfiles =
    grantsAsync.asData?.value.any((g) => g.grantState is ActiveGrant) ?? false;
```

The indicator is shown whenever the user has **any** active grant on **any** child — regardless of which profile is currently selected. A parent who is also a tutor will see the amber bar even while viewing their own child's data.

The spec (FR-6.1) says: "While a tutor is **viewing a tutored child**, the UI displays a subtle indicator." The trigger should be the active `ProfileSelection`, not the existence of any grant.

**Impact:** False positive: parents who happen to also be tutors will see the amber "Tutor mode" indicator on every screen, even when parenting their own children. This is confusing and violates the spec intent.

**Disposition:** The indicator should observe the current `ProfileSelection` (once session management is wired), and only show when `selection is TutoredProfileSelection`. Until session management is wired, this is acceptable as a known limitation but should be documented.

---

### H5 — `_isTutorSession()` in `text_display_screen.dart` uses the same wrong signal

**File:** `learning_tracker/lib/features/content_browsing/presentation/screens/text_display_screen.dart:729–733`

```dart
bool _isTutorSession(WidgetRef ref) {
  final grantsAsync = ref.watch(incomingTutorGrantsProvider);
  return grantsAsync.asData?.value.any((g) => g.grantState is ActiveGrant) ?? false;
}
```

Same flaw as H4 but on the button-disable logic. A tutor who is also a parent viewing **their own** child's content will have the "Mark complete" button disabled and see the amber disabled style — because `incomingTutorGrantsProvider` returns active grants regardless of which profile is currently open.

**Impact:** A tutor-parent cannot mark their own child's content as complete because the button is erroneously disabled. This breaks the parent experience for the dual-role user (FR-1.4).

**Disposition:** Replace `incomingTutorGrantsProvider` with `permissionsProvider(currentProfileSelection)` and check `session.effectivePermissions.canMarkLiveCompletion`. This requires wiring `permissionsProvider` and knowing the current `ProfileSelection` in `_CompletionSection`.

---

### H6 — `TutoredChildrenSection` row `onTap` is `null` — tutored profile navigation is not wired

**File:** `learning_tracker/lib/features/profiles/presentation/widgets/tutored_children_section.dart:140–142`

```dart
// TODO(navigation): When tutored profile viewing is wired...
onTap: null,
```

The entire tutored profile entry in the profile picker is non-tappable. A user with active tutor grants sees the "Tutored children" section but cannot switch to the tutored profile. The Tutor PIN gate (`TutorPinEntryGate`) is implemented but never invoked.

**Impact:** Core UX of tutor mode — switching into a tutored profile — is not functional. The feature cannot be exercised end-to-end.

**Disposition:** Wire the `onTap` to present `TutorPinEntryGate` with the tutor's own profile ID, then on PIN verification, set the active session to `TutoredProfileSelection` and navigate. This requires the session-management layer to be wired.

---

## MEDIUM

### M1 — Duplicate `_StubTutorGrantRepository` and `tutorGrantRepositoryProvider` in two provider files

**File:** `learning_tracker/lib/features/tutoring/presentation/providers/manage_tutors_providers.dart:24–82`
**Also:** `learning_tracker/lib/features/tutoring/presentation/providers/tutor_grant_providers.dart:24–77`

Both files define a separate `_StubTutorGrantRepository` class and a `tutorGrantRepositoryProvider` (one as a `Provider`, one as a `@riverpod`-generated provider). The two stub implementations are slightly different (one returns `TutorGrantFailure`, the other also returns `TutorGrantFailure` with a slightly different message). Screens using each file get different provider instances.

`ManageTutorsScreen` and `ManageGrantsScreen` use `manage_tutors_providers.dart`; `AcceptInviteScreen` uses `tutor_grant_providers.dart`. They reference different provider instances and cannot share grant repository state.

**Impact:** When the real data layer lands, it must be wired in two places. If someone wires one but not the other, half the screens will remain stub-backed silently.

**Disposition:** Collapse to a single `tutorGrantRepositoryProvider` in `manage_tutors_providers.dart` (or a new dedicated file). The `@riverpod`-generated version in `tutor_grant_providers.dart` should be removed in favour of the single source.

---

### M2 — `RescindTutorInviteUseCase` provider is defined in `manage_tutors_providers.dart` but not in `tutor_grant_providers.dart`

**File:** `learning_tracker/lib/features/tutoring/presentation/providers/manage_tutors_providers.dart:90`

`rescindTutorInviteUseCaseProvider` is in the manage-tutors providers file. The tutor-grant-providers file has `revokeTutorGrantUseCaseProvider` and `resignTutorGrantUseCaseProvider` but is missing rescind. This means the two provider files share responsibilities without a clear boundary.

**Impact:** Code navigation confusion; minor risk that a screen navigating to rescind via the wrong provider import silently gets a non-analytics-wired use case.

**Disposition:** Consolidate as part of M1 resolution.

---

### M3 — `purgeExpiredAuditLogs` counts `totalEntriesPurged` incorrectly

**File:** `learning_tracker/functions/src/index.ts:242–244`

```typescript
await db.recursiveDelete(auditLogRef);
totalEntriesPurged++;
totalGrantsProcessed++;
```

Both counters are incremented by 1 per grant (not per audit entry). `totalEntriesPurged` is intended to count entries purged but actually counts grants processed (same as `totalGrantsProcessed`). The log message at line 253–255 is therefore misleading.

**Impact:** Minor operational issue — log-based monitoring of purge volume will show incorrect numbers. Not a security concern.

**Disposition:** Remove the `totalEntriesPurged` counter (it can never accurately count entries without a pre-count) or rename both to `totalGrantsPurged`.

---

### M4 — `purgeExpiredAuditLogs` uses `updated_at` as the retention clock, not `revoked_at` or `declined_at`

**File:** `learning_tracker/functions/src/index.ts:221–227`

The comment at line 181 says retention is "12 months after the grant's `revoked_at` / `declined_at`" but the query uses `updated_at`:

```typescript
.where("updated_at", "<=", cutoffTs)
```

For most grants, `updated_at` equals the terminal-event timestamp, but they are semantically different. If a grant document is touched after termination (e.g. a background job updates it), the `updated_at` clock resets and audit log retention extends unintentionally. Conversely, a grant that has no `revoked_at` field (e.g. manually inserted) but an old `updated_at` will be erroneously purged.

**Impact:** Medium: audit logs could be purged too early or too late depending on unrelated document updates. Compliance risk.

**Disposition:** Add a dedicated `terminated_at` field written when the grant enters any terminal state, and query on that field. Or query specifically on the terminal-state timestamp field corresponding to each state (e.g., `revoked_at` for `revoked_by_parent`/`revoked_by_tutor`, `declined_at` for `declined`).

---

### M5 — Accept invite flow builds a stub grant from the token without loading from Firestore

**File:** `learning_tracker/lib/features/tutoring/presentation/screens/accept_invite_screen.dart:152–165`

```dart
TutorGrant _buildStubGrant(String grantId) {
  final now = DateTime.now().toUtc();
  final doc = TutorGrantDoc(
    grantId: grantId,
    parentUid: '',
    childProfileId: '',
    ...
    state: TutorGrantState.pending,
    expiresAt: now.add(const Duration(days: 7)),
  );
  return TutorGrant.fromDoc(doc);
}
```

The stub grant is always `state: pending` with a fresh 7-day expiry regardless of the actual grant state in Firestore. If a grant has been rescinded, revoked, or has already expired, the `canAccept` guard will pass (because the stub is always `pending`) and the use case will proceed — then fail only at the repository level.

**Impact:** Misleading UX: users with revoked/expired invites see a confirmation screen and get "not implemented" failure instead of "this invite is no longer valid." Security concern: when the real accept Cloud Function exists, if the client passes a stale grant ID with a forged pending-state stub, the server validates the grant state anyway (which would catch it), but the client-side precondition guard is meaningless.

**Disposition:** Load the actual grant from Firestore before showing the confirmation screen. Use `tutor_grants/{grantId}` direct get (readable by tutor since Firestore rules allow read for `tutor_uid` or email-matched uid).

---

### M6 — `ManageGrantsScreen` exposes `parentUid` raw to the tutor

**File:** `learning_tracker/lib/features/tutoring/presentation/screens/manage_grants_screen.dart:239–244`

```dart
Text('Parent UID: ${widget.grant.parentUid}', ...)
```

The parent's Firebase Auth UID is displayed verbatim to the tutor. UIDs are not secrets per se (they appear in many Firestore paths) but they are internal identifiers that should not be surfaced in UI.

**Impact:** Low-severity privacy concern. The tutor has no useful purpose for knowing the raw parent UID; the parent's display name or first name would be appropriate.

**Disposition:** Replace with parent display name (once the cross-uid read is available) or remove the field entirely. The TODO on line 228 ("replace with child display name") applies here too.

---

### M7 — Onboarding intent screen does not guard against non-tutor users seeing the "Join to tutor" path

**File:** `learning_tracker/lib/features/account/onboarding/presentation/screens/onboarding_intent_screen.dart:69–78`

The "Join to tutor someone" card is always visible at signup. Any user can choose it and be routed to the dashboard with "Accept invites" CTA. The intent choice merely persists `kOnboardingJoinedToTutor` to SharedPreferences but does not enforce any restriction.

A parent creating an account for themselves would see this option and could accidentally choose it, landing on the skip-dashboard view with confusing CTAs instead of the track setup flow.

**Impact:** UX confusion. Minor since no permanent damage is done — the user can still set up a track from the dashboard CTA. Not a security issue.

**Disposition:** This is acceptable for v1 but should have copy that distinguishes "for parents" vs "for tutors" more clearly. The current "A parent will send you an invite link" copy helps but the card should maybe be hidden until there is a real pending invite to direct the user to.

---

### M8 — `InviteTutorUseCase` email validation is weak (only checks `@`)

**File:** `learning_tracker/lib/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart:96`

```dart
if (email.isEmpty || !email.contains('@')) {
  return const TutorGrantPreconditionError(...);
}
```

The validation checks only for presence of `@`. A string like `a@` or `@@@@` passes. The `InviteTutorScreen` adds a slightly stronger check (`contains('@') && contains('.')`) but this is UI-only and can be bypassed by calling the use case directly.

**Impact:** Low severity pre-launch since the real Cloud Function validates the email server-side. However, a malformed invite email address could cause silent failures or invalid grant document keys.

**Disposition:** Use the same `contains('@') && contains('.')` check in the use case, or use a proper email regex in the domain layer.

---

## LOW

### L1 — `InviteTutorScreen` share link always embeds the grantId as the token

**File:** `learning_tracker/lib/features/tutoring/presentation/screens/invite_tutor_screen.dart:98–101`

```dart
String _buildShareLink(String grantId) {
  return 'https://app.learningtracker.app/invite?token=$grantId';
}
```

The share link uses `grantId` as the `token` parameter. The `AcceptInviteScreen` receives the `token` parameter and uses it directly as the grantId (line 109). This conflates the invite token (which should be a separate, ephemeral secret) with the persistent grant document ID. Anyone who knows the deterministic grantId formula (`{encodedEmail}__{parentUid}__{childProfileId}`) could construct a valid invite link without having received one.

**Impact:** Invite token replay risk: the deterministic grantId is guessable if the attacker knows the parent UID, child profile ID, and tutor email. The separate `invite_token` field on the grant doc (NFR-3: "Invite tokens are 256-bit random, single-use") is never populated in the current code.

**Disposition:** When the accept Cloud Function is implemented, generate a real random token (256-bit via `crypto.randomBytes(32).toString('hex')`), store it in `invite_token` on the grant doc, include it in the invite email/link, and validate + clear it atomically on acceptance.

---

### L2 — `AcceptInviteScreen` PIN setup gate checks `_tutorProfileId` which is always `null`

**File:** `learning_tracker/lib/features/tutoring/presentation/screens/accept_invite_screen.dart:116–125`

```dart
final profileId = _tutorProfileId;
if (profileId != null) {
  final pinService = ref.read(tutorPinServiceProvider);
  final hasPin = await pinService.hasTutorPin(profileId);
  ...
}
setState(() => _step = _AcceptStep.success);
```

`_tutorProfileId` is declared as `int?` on line 73 and never assigned. The null check at line 117 always evaluates false, so the PIN setup step is unconditionally skipped after acceptance. A tutor accepts and is taken straight to `_AcceptStep.success` without ever being prompted to set a PIN.

**Impact:** FR-5.3 ("Tutor PIN is set during tutor onboarding — mandatory before the tutor can open their first tutored child's data") is violated. Tutors can accept grants without setting a PIN.

**Disposition:** Assign `_tutorProfileId` from the authenticated user's profile (or use the auth UID for the tutor PIN storage, per H1 fix). After the H1 fix makes the PIN UID-based, remove the `profileId` dependency entirely.

---

### L3 — "Decline" button on `AcceptInviteScreen` calls `context.router.pop()` rather than `DeclineTutorInviteUseCase`

**File:** `learning_tracker/lib/features/tutoring/presentation/screens/accept_invite_screen.dart:270–273`

The "Decline" TextButton simply pops the route without calling `DeclineTutorInviteUseCase`. The invite remains in `pending` state in Firestore indefinitely (until expiry — which itself is not enforced, per C4). The separate `DeclineInviteScreen` exists for this purpose but the "Decline" button on the accept screen does not route to it.

**Impact:** Tutors who mean to decline an invite by pressing "Decline" on the accept screen have no effect — the parent's pending invite remains and the tutor receives no confirmation. The grant remains pending.

**Disposition:** Wire the "Decline" button to `DeclineTutorInviteUseCase` (or navigate to `DeclineInviteScreen`).

---

### L4 — `_TutoredChildRow` displays `grant.childProfileId` (integer) instead of child display name

**File:** `learning_tracker/lib/features/profiles/presentation/widgets/tutored_children_section.dart:98–103`

```dart
title: Text('Child: ${grant.childProfileId}', ...)
```

The TODO at line 96 acknowledges this but it is a significant UX issue: a tutor with multiple grants sees "Child: 42", "Child: 7", etc., with no human-readable identification. The comment says cross-uid reads are needed but does not indicate a clear timeline.

**Impact:** Unusable UI for tutors with multiple grants. They cannot identify which child is which from the profile picker.

**Disposition:** The grant document should include the child's display name as a denormalised snapshot (write it when the invite is created/accepted, update it when the profile name changes). This avoids the cross-uid read complexity. Add `child_display_name` to the grant doc schema.

---

### L5 — AppBar "Switch profiles" text is hardcoded in English, not l10n'd

**File:** `learning_tracker/lib/app/router/app_shell.dart:202`

```dart
const Text('← Switch profiles', ...)
```

All other UI text added in W6 uses ARB l10n keys. This single string is hardcoded. Hebrew users will see English text in the tutor indicator bar.

**Impact:** l10n regression for the HE locale. Minor but inconsistent with the "both locales supported" requirement.

**Disposition:** Add `tutorModeExitAffordance` (or similar) key to both `app_en.arb` and `app_he.arb` and reference it here.

---

### L6 — `TutorPermissions.canEditProfile` is specified in the brief but absent from the permission VO

**File:** `learning_tracker/lib/features/tutoring/domain/models/tutor_permissions.dart`
**Also:** `docs/planning/tutor-mode-brief.md` — Permission matrix row: "Edit profile (name, avatar, mode) — Tutor: ✅"

The brief specifies `canEditProfile` as one of the 8 boolean policy fields in `TutorPermissions`. The Dart VO declares only 8 fields but they are: `canViewProgress`, `canViewContent`, `canBulkPriorCompletion`, `canResetCompletion`, `canEditGoals`, `canEditStages`, `canEditRewards`, `canEditStudyDays`. `canEditProfile` is absent — it is subsumed into defaults without an explicit flag.

**Impact:** Parent cannot configure whether the tutor can edit the child's profile name/avatar. The tutor always has full profile-edit ability (or none, depending on how the data layer interprets missing flags). Minor for v1 but diverges from the spec.

**Disposition:** Add `canEditProfile` field to `TutorPermissions` with default `true`. Update `toFirestore`/`fromFirestore`, equality, `copyWith`, and `toString`.

---

## Summary table

| # | Severity | Area | Description |
|---|---|---|---|
| C1 | CRITICAL | Domain/UI | `MarkLiveCompletionUseCase` never called — client guard is dead code |
| C2 | CRITICAL | Firestore rules | `isActiveTutorGrant` dead; tutors cannot read any subcollection data |
| C3 | CRITICAL | Cloud Functions | No accept/invite/revoke Cloud Functions; entire lifecycle is stub-only |
| C4 | CRITICAL | Cloud Functions | No pending-invite expiry sweep; 7-day TTL not enforced server-side |
| H1 | HIGH | PIN domain | Tutor PIN keyed by profile ID, not tutor UID — violates FR-5.2 |
| H2 | HIGH | Cloud Functions | Audit log written outside transaction; can be lost on crash |
| H3 | HIGH | Cloud Functions | `tutor_name_snapshot` always `""`; never populated on grant doc |
| H4 | HIGH | UI | AppBar indicator fires on any grant, not on active tutored-profile session |
| H5 | HIGH | UI | Mark-complete disabled for tutor-parents viewing their own children |
| H6 | HIGH | UI | Tutored profile row `onTap: null`; tutor cannot switch into any profile |
| M1 | MEDIUM | Providers | Two duplicate `_StubTutorGrantRepository` implementations |
| M2 | MEDIUM | Providers | `RescindTutorInviteUseCase` provider only in manage-tutors file |
| M3 | MEDIUM | Cloud Functions | `totalEntriesPurged` counts grants not entries |
| M4 | MEDIUM | Cloud Functions | Purge uses `updated_at` instead of terminal-event timestamp |
| M5 | MEDIUM | UI | Accept screen builds stub grant; grant state validation is bypassed |
| M6 | MEDIUM | UI | `ManageGrantsScreen` exposes raw `parentUid` to tutor |
| M7 | MEDIUM | Onboarding | "Join to tutor" option visible to all users without context |
| M8 | MEDIUM | Domain | Weak email validation in `InviteTutorUseCase` |
| L1 | LOW | Security | Share link uses deterministic grantId not a random invite token |
| L2 | LOW | UI | `_tutorProfileId` is always null; PIN setup step unconditionally skipped |
| L3 | LOW | UI | "Decline" button pops route without calling decline use case |
| L4 | LOW | UX | Tutored child rows show raw profile ID, not display name |
| L5 | LOW | l10n | "Switch profiles" hardcoded in English in AppBar bar |
| L6 | LOW | Domain | `canEditProfile` missing from `TutorPermissions` VO |

---

## Live-completion block assessment

The ONE prohibition was traced through three enforcement layers:

1. **Firestore rules (server):** `allow create: if isOwner(uid)` on `completions/{completionId}` — HOLDS. A tutor with a different UID is categorically blocked from writing live completions via the client.

2. **Cloud Function `tutorBulkPriorCompletions` (server):** `completedAt >= todayUtcMidnight` → `permission-denied` — HOLDS for bulk-prior path. Implemented correctly.

3. **`MarkLiveCompletionUseCase` (client):** NOT WIRED (finding C1). The guard is implemented but never invoked on the actual completion call path.

The Firestore rule at layer 1 is the true security boundary and it holds. The client guard at layer 3 is defence-in-depth and is currently dead code. For the dual-role scenario (tutor who is also the parent of the tutored child), the Firestore rule would actually allow the write because `isOwner(uid)` would pass — but this scenario is architecturally excluded: a parent cannot issue themselves a tutor grant on their own child. The deterministic grant ID includes `parentUid` and the Cloud Function (when written) should enforce `callerUid != grant.parent_uid` as an additional guard.

Overall verdict on the live-completion block: **the server-side defence holds, the client-side defence is dead code, the dual-role scenario is architecturally excluded but not explicitly guarded.**
