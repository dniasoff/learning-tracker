# Bug-hunt round 3 — confirmed 12/15 (2026-05-31)

Adversarial find→verify workflow (10 finders × high-risk areas; each finding double-verified, refute-by-default). 3 rejected.

> **Status: RESOLVED — 10 fixed, 2 rejected-on-judgment.** Fixed at root cause + regression-tested,
> committed green to `dev` (`make ci` +9022, `format-check` clean), via parallel sub-agents on disjoint files:
> - **R3-1** dashboard: tutor session now returns `ProfileMode.adult` (no child-mode gamification for tutors).
> - **R3-2/3/4** tutoring-grants (one issue): `app_shell` now keeps `incomingTutorGrantsProvider` subscribed
>   during a tutored session, so the existing revocation reconciliation (wipe + auto-exit) fires live, not only
>   on grants screens.
> - **R3-5** sync: curriculum activation now enqueues `study_day_configs` to the outbox (was seeded but never pushed).
> - **R3-6** merge: `ProfileProgramMerger` natural key de-double-scoped (`bavli`, not `profileId|bavli`) — restores LWW symmetry.
> - **R3-7** rewards: tutor is barred from initiating the child's redemptions in a tutored session (UI disabled + hard guard).
> - **R3-9** points: `getPointsHistory` now uses `CompletionTierFilter.liveOnly` (sentinel bulk completions can't leak).
> - **R3-10** offline-first: profile deletion no longer gated on online status (local delete + queued cloud delete).
> - **R3-12** lifecycle: `dashboardChildNextReward` adds `if (!ref.mounted) return null;` after its async gap.
>
> **Rejected on judgment (NOT bugs / would violate explicit rules):**
> - **R3-8** (make the Settings parent profile-header open the *switcher*): REJECTED — contradicts
>   `feedback_settings_account_profile_separation` (Settings top header = account-only; the persistent switcher is a
>   *distinct* app-shell element). Current account-actions behavior is correct. The finder lacked that rule.
> - **R3-11** (offline-first sign-in for an expired cloud session): REJECTED as by-design — the offline path already
>   grants local access; routing to sign-in *when online* is the intended sync-recovery entry point (`badgeSignInAgain`).
>   Changing it needs a replacement in-app re-auth path (out of minimal scope); not a clear defect.

## R3-1 [high/tutoring-session] Tutor session renders child-mode gamification UI instead of adult management view
- File: `lib/features/dashboard/presentation/providers/dashboard_providers.dart:66`
- Symptom: When a tutor enters a child's profile context, the dashboard renders child-mode UI elements (ChildPointsRewardsTabCard with rewards/points, StreakRecoveryBanner) instead of the parent/adult management view. The tutor sees gamified surfaces meant for children instead of the admin-focused track/goal/reward configuration surfaces.
- Root cause: dashboardUserMode provider (lines 66-72) reads the active profile's mode directly without checking if activeTutoredProfileSelectionProvider is non-null (tutor session active). When in tutor mode, activeProfileIdProvider returns the tutored child's synthetic profile ID (from resolvedTutoredLocalProfileIdProvider), so dashboardUserMode returns ProfileMode.child even though the viewer is a tutor. This causes dashboardUserModeProvider to return 'child' and triggers child-mode UI rendering in dashboard_body.dart (lines 318-330) and dashboard_screen.dart.
- Reachability: Entry: Tutor enters child profile via TutorPinEntryGate → activeTutoredProfileSelection set non-null → activeProfileIdProvider returns tutored child's ID (via resolvedTutoredLocalProfileIdProvider) → dashboardUserMode reads child profile from DB → returns ProfileMode.child → dashboard_body.dart checks `if (userMode == ProfileMode.child)` at line 318 → renders ChildPointsRewardsTabCard and StreakRecoveryBanner (lines 319-330).
- Fix: In dashboardUserMode provider (lib/features/dashboard/presentation/providers/dashboard_providers.dart lines 66-72), add a check for tutor session context before returning the profile mode. When activeTutoredProfileSelectionProvider is non-null (tutor in child's context), always return ProfileMode.adult regardless of the child profile's actual mode. Example: `final tutoredSelection = ref.watch(activeTutoredProfileSelectionProvider); if (tutoredSelection != null) return ProfileMode.adult;` before line 67. This ensures tutors always see adult/management surfaces, never child-mode gamification.
- Confidence: high

## R3-2 [medium/tutoring-grants] Stale tutored grant access not detected until provider refresh
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/profiles/presentation/providers/active_profile_provider.dart:20-29`
- Symptom: A tutor can continue viewing and potentially editing a child's data even after the parent has revoked the grant, because the active tutored profile selection persists without re-validation. The grant revocation is only detected when the `incomingTutorGrantsProvider` is explicitly watched and refreshed.
- Root cause: The `activeProfileIdProvider` uses the cached `resolvedTutoredLocalProfileIdProvider` and `activeTutoredProfileSelectionProvider` values without verifying the grant is still active. The grant revocation detection logic in `manage_tutors_providers.dart` (lines 111-119) only fires if the tutor is actively watching the `incomingTutorGrantsProvider`, which is not guaranteed during active tutored viewing. A tutor accessing a talmid view (dashboard, learning, content) will not trigger a watch on the incoming grants provider unless they navigate to the profile picker or review grants screen.
- Reachability: Production entry point: (1) Tutor enters talmid via `TutoredChildRow._enterTalmidView()` → `TutoredPullService.pull()` → sets `resolvedTutoredLocalProfileIdProvider`. (2) Parent revokes grant via `_TutorGrantRowState._revoke()` → calls `wipeMirrorForGrant()` with `onWipe` callback that checks `activeGrantId == grantId`. (3) If tutor is not watching `incomingTutorGrantsProvider` (e.g., viewing dashboard, learning screen, or content), the revoked grant is never wiped and the stale selection persists. (4) Tutor continues rendering talmid data with stale permissions; Firestore rules will deny writes on next pull/listener event.
- Fix: Implement proactive grant validation: (a) Add a periodic check or listener that validates the active grant's state from `incomingTutorGrantsProvider` even when the tutor is in a talmid view. (b) Alternatively, require the `incomingTutorGrantsProvider` to be watched at the root App Shell or talmid shell level so revocations are always detected within seconds. (c) Or, add an explicit grant-state validation in the tutored listener supervisor before attaching/maintaining listeners — if the grant is no longer in the active set, auto-exit immediately.
- Confidence: high

## R3-3 [medium/tutoring-grants] Conditional grant exit in reconciliation may not fire due to race condition
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/tutoring/presentation/providers/manage_tutors_providers.dart:111-119`
- Symptom: When a parent revokes a grant that the tutor is currently viewing, the `onWipe` callback checks if `grantId == activeGrantId`. However, if the tutor is not watching `incomingTutorGrantsProvider` at the moment of revocation, the callback will not fire, leaving the stale grant active until the user happens to navigate to a screen that watches the provider.
- Root cause: The wipe callback is only executed when `incomingTutorGrantsProvider` is evaluated (await useCase.callWithStatus() at line 100). If no widget is watching this provider (e.g., tutor is deep in a talmid view, not on the profile picker or grants screen), the reconciliation never runs and the revoked grant is never detected. The grant reconciliation is lazy and event-driven, not proactive.
- Reachability: Production entry point: (1) Tutor enters talmid → sets `activeTutoredProfileSelectionProvider` with grantId. (2) Parent initiates revocation via `ManageTutorsScreen._TutorGrantRowState._revoke()` → calls Cloud Function. (3) Tutor does NOT navigate to a screen that watches `incomingTutorGrantsProvider` (e.g., stays in dashboard, learning, or content screens). (4) `incomingTutorGrantsProvider` is never evaluated until tutor navigates back to profile picker or explicitly refreshes grants. (5) During this window, the stale grant is never wiped and the tutored session remains active with outdated permissions.
- Fix: Ensure `incomingTutorGrantsProvider` is watched at a high level in the widget tree (e.g., AppShell or a root provider that is always active during tutored sessions). Set a polling interval or force a refresh whenever a tutored session is active. Alternatively, integrate grant-state validation into the tutored listener supervisor lifecycle so that if the grant becomes revoked mid-session, the listeners are detached and the session exits automatically without requiring a provider refresh.
- Confidence: high

## R3-4 [low/tutoring-grants] No re-validation of grant state during active tutored session
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/core/sync/tutored_pull_service.dart:74-115`
- Symptom: The `TutoredPullService.pull()` method accepts a grant ID and performs a pull under that grant's authority. However, there is no validation that the grant is still in an active state before or during the pull. If the grant was revoked between the decision to pull and the actual pull execution, the client will still attempt to sync, relying solely on Firestore rules to deny access.
- Root cause: The service is a thin, stateless operation that trusts the caller to have already validated the grant is active. No pre-check of the grant's state (active vs. revoked) occurs before the pull. The design assumes the Firestore rules (`hasActiveTutorAccess`) will enforce access, but there is no client-side early exit or explicit error message to the user before the network round-trip.
- Reachability: Production entry point: (1) Tutor taps tutored child row → `_TutoredChildRow._enterTalmidView()` reads the grant from the cached `incomingTutorGrantsProvider`. (2) Between the read and the pull, the parent revokes the grant via a different device/window. (3) `_fireEntryPullAndNavigate()` calls `TutoredPullService.pull()` without re-checking the grant state. (4) The service builds a gateway with `parentUid` and attempts to fetch the parent's data. (5) Firestore rules deny access (permissionDenied exception), but the user sees a generic error snackbar rather than understanding the grant was revoked.
- Fix: Before calling `TutoredPullService.pull()`, validate the grant is still active by checking the latest state from a freshly-fetched or cached incoming grants list. If the grant is no longer active/pending, show a specific error message to the user explaining the grant was revoked/expired rather than a generic network error.
- Confidence: medium

## R3-5 [high/sync-push] Study day configs NOT enqueued when curriculum activated via CurriculumActivationService
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/tracks/domain/services/curriculum_activation_service.dart:61-66`
- Symptom: When a curriculum is activated through CurriculumActivationService.activate() or activateForProfile(), study day configs are seeded locally via studyDayConfigDao.seedDefaults() but never pushed to Firestore. The subsequent _syncToFirestore() call only syncs the curriculum_tracks document, not the study_day_configs rows.
- Root cause: The _syncToFirestore() method (lines 170-192) retrieves and pushes curriculum_tracks via _pushCurriculumTrack, but there is no corresponding push for the study_day_configs that were just seeded. The seedDefaults() call at lines 39, 61, and 85 inserts rows into the local study_day_configs table, but these rows have no outbox entries enqueued, so OutboxProcessor never pushes them.
- Reachability: Entry point: User activates a curriculum in the UI → ActivationService.activate() / activateForProfile() → seedDefaults() + _syncToFirestore() → study day configs created locally but NOT pushed to cloud
- Fix: After _syncToFirestore() completes in each of the three activate methods (lines 44, 66, and 90), call a new helper method that enqueues the study day configs to the outbox via the sync facade, mirroring the pattern used in TrackCreationService._pushStudyDaysCloud(). Alternatively, move the seedDefaults() call to the transaction block and enqueue the rows before commit, similar to how CompletionWriter handles completion + outbox rows atomically.
- Confidence: high

## R3-6 [high/sync-pull-merge] ProfileProgramMerger uses double-scoped natural key causing LWW symmetry loss
- File: `lib/core/sync/merge/profile_program_merger.dart:57`
- Symptom: On pull, profile-program rows may be silently overwritten even when local edits are newer, because the merger constructs the SyncKv lookup key incorrectly: it includes profileId in the natural key, which _scopedKey then prefixes again, creating a malformed composite key that never matches previously-persisted timestamps. A second pull of the same profile+curriculum will construct a different SyncKv key than the first, losing the LWW history.
- Root cause: Line 57 constructs `naturalKey = '${decoded.profileId}|${decoded.curriculumId}'`, but since every call to currentUpdatedAt/persistUpdatedAt is already scoped to a profileId parameter and _scopedKey(profileId, naturalKey) composes `'$profileId|$naturalKey'`, the profileId is double-scoped. The natural key should be just curriculumId (like TrackConfigMerger uses on line 37). This is inconsistent with every other LWW merger in the codebase.
- Reachability: Entry: pullOnLaunch → PullPipeline.pullProfilePrograms → MergeRouter.dispatch → ProfileProgramMerger.merge. Any profile that syncs after making a local profile-program edit (e.g. changing the tracking-start-date or program-id) on device A, then syncs the same profile on a different device B, will have B's local edits silently lost on the next pull when B applies A's remote value. The bug is always live whenever profile_programs sync occurs.
- Fix: Change line 57 from `final naturalKey = '${decoded.profileId}|${decoded.curriculumId}';` to `final naturalKey = decoded.curriculumId;` to match the pattern used by TrackConfigMerger and other LWW mergers. The test file test/sync/merge/lww_symmetric_test.dart also uses the wrong key on lines that call persistUpdatedAt/currentUpdatedAt with `'$profileId|bavli'`; those test lines should also be updated to use `'bavli'` only.
- Confidence: high

## R3-7 [high/rewards-spend] Tutor can initiate child redemptions in tutored session (unauthorized spend)
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/gamification/presentation/screens/child_redemption_screen.dart:146`
- Symptom: When a tutor is viewing a tutored child (tutored session active), the tutor can navigate to ChildRedemptionScreen and redeem rewards, debiting the child's balance. The product rule 'tutor sees the PARENT/adult management view OF the child — NOT child mode' is violated.
- Root cause: ChildRedemptionScreen reads activeProfileIdProvider (line 31, 38, 146), which returns the tutored mirror profile ID when in a tutored session. The screen has no guard to prevent access during tutored sessions. The ChildModeGuard only checks selectedProfileIdProvider (the tutor's own child profile), not whether a tutored session is active. Thus a tutor can reach ChildRedemptionScreen and createRedemption is called with the tutored child's profile ID.
- Reachability: Route /redeem is guarded by childModeGuard only (app_router.dart:207-208). Guard passes if selectedProfileIdProvider is a child profile. When tutored session is active (activeTutoredProfileSelectionProvider != null), activeProfileIdProvider returns tutored mirror ID. Screen reads activeProfileIdProvider at lines 31, 38, 146, creating redemption with mirror profile ID via createRedemption(profileId: tutored_mirror_id).
- Fix: Add a check in ChildRedemptionScreen to gate access during tutored sessions. Either: (1) add a guard that checks activeTutoredProfileSelectionProvider is null, or (2) check in _confirmRedeem() before calling createRedemption(). Example: `if (ref.read(activeTutoredProfileSelectionProvider) != null) { show error; return; }`. Tutors should use ParentPendingRedemptionsScreen only (which is properly PIN-gated and for approval/decline, not initiation).
- Confidence: high

## R3-8 [high/profile-switcher] ParentSettingsScreen profile header opens account actions instead of profile switcher
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/settings/presentation/widgets/user_profile_header_card.dart:148-150`
- Symptom: When a parent enters parent mode to manage a child profile (via ParentSettingsScreen), tapping the profile header card opens the account/login management sheet instead of the profile switcher. This prevents the parent from switching back to their own profile or selecting a different child to manage without exiting parent mode and using the (now hidden) bottom nav.
- Root cause: UserProfileHeaderCard.build() always passes `onTap: () => showAccountActionsSheet(context, ref)` to _wrapSurface(), regardless of the surface type or context role. When surface=UserProfileHeaderSurface.parent (used by ParentSettingsScreen), the onTap should instead call showProfileSwitcherSheet to align with the product rule that a profile switcher must be tappable in EVERY context.
- Reachability: ParentSettingsScreen → line 103-109 renders UserProfileHeaderCard with surface=parent and contextRole=parent/tutor → UserProfileHeaderCard.build() line 148-150 always sets onTap to showAccountActionsSheet → _ParentProfileSurface line 315 makes it tappable but calls wrong sheet
- Fix: In UserProfileHeaderCard.build() around line 148-150, change the onTap logic to check the surface type: when surface == UserProfileHeaderSurface.parent, call showProfileSwitcherSheet(context) instead of showAccountActionsSheet(context, ref). This makes the profile header in parent mode switch learner profiles, matching the behavior in Settings screen where it switches accounts.
- Confidence: high

## R3-9 [medium/completion-credit] PointsService.getPointsHistory() loads completions without tier filtering
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/gamification/domain/services/points_service.dart:98-123`
- Symptom: getPointsHistory() method loads all completions (including sentinel-dated bulk-prior imports) via getCompletionsByCurriculumAndProfile(), then filters by points > 0. This violates the three-tier completion credit policy which mandates that points (engagement tier) use liveOnly filtering.
- Root cause: The method retrieves completions without applying CompletionTierFilter.liveOnly. Bulk-prior completions (with completedAt = DateTime.utc(2000,1,1)) are written with points=0, so the downstream points > 0 filter happens to exclude them. But the code violates the semantic contract that engagement-tier queries must exclude all bulk-prior rows via tier filtering, not by accident of points being 0.
- Reachability: Entry: getPointsHistory(CurriculumId?) → PointsService.getPointsHistory() [line 98] → calls getCompletionsByCurriculumAndProfile/getCompletionsByProfile [lines 102-106] which don't apply CompletionTierFilter. Used by pointsHistoryProvider in points_providers.dart.
- Fix: Change getPointsHistory() to use CompletionTierFilter.liveOnly via getCompletionsByTier() instead of the non-tier-filtered getCompletionsByCurriculumAndProfile/getCompletionsByProfile. The fix ensures semantic correctness per three-tier policy: points-history is engagement-tier and must exclude all bulk-import sources (bulkInTrack + lifetimeOnly), not just happen to exclude them because their points are 0.
- Confidence: high

## R3-10 [high/offline-first] Profile deletion gates on online status for cloud accounts
- File: `learning_tracker/lib/features/profiles/presentation/widgets/profile_edit_delete_actions.dart:99-114`
- Symptom: User cannot delete a profile when offline, even though the Drift delete operation is local-first and queues the sync operation.
- Root cause: Lines 99–114 check `if (!isOnline)` and block profile deletion for non-local-born (cloud) accounts. The guard assumes deletion requires internet, but the repository pattern at line 236 of profile_repository_impl.dart executes the local Drift delete first (line 229), then asynchronously notifies sync (line 236). The UI should allow deletion offline and queue the sync operation.
- Reachability: Entry point: user long-presses a profile on the profile picker → `_showManageSheet()` → `_showDeleteDialog()` → `deleteProfileFlow()` at profile_edit_delete_actions.dart:58–124 → online check blocks at line 101–102.
- Fix: Remove the online check at lines 99–114. Rely on the repository's offline-first pattern: local delete always succeeds, sync operation queues automatically. Show a snackbar post-delete if offline to inform the user sync is queued, not gated on it.
- Confidence: high

## R3-11 [high/offline-first] Sign-in with invalid session blocks on online status instead of queuing local session
- File: `learning_tracker/lib/features/account/presentation/screens/account_picker_screen.dart:400–411`
- Symptom: When a cloud account has an invalid/expired Firebase session and the device goes offline, the user cannot activate their local copy of the account. They are forced to wait for internet.
- Root cause: Lines 400–411 check online status and conditionally gate behavior: if online, route to SignInRoute; if offline, allow local activation via `_activateCloudAccountFromLocalData()`. This is backwards for offline-first: local activation should be the default path, with sign-in as an optional sync operation. The user has valid local data but cannot access it offline due to the session check.
- Reachability: Entry point: user taps cloud account tile with expired session → `_onTap()` → line 401 checks online → line 402–406 gates sign-in route on online → line 410 only then allows local activation.
- Fix: Always call `_activateCloudAccountFromLocalData()` first to grant offline access to local data. Optionally (on a background task when online) refresh the Firebase session, but do not gate local access on it.
- Confidence: high

## R3-12 [high/provider-lifecycle] Disposed ref.watch() calls after async gap in dashboardChildNextReward
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/dashboard/presentation/providers/dashboard_providers.dart:330`
- Symptom: ref.watch() is called at lines 330-331 immediately after an await at line 328, without a ref.mounted guard. If the widget is disposed/navigated away during the await, the ref will be disposed but these watch calls will still execute, causing errors.
- Root cause: dashboardChildNextReward is an autoDispose FutureProvider that calls `await ref.watch(stripStockMilestonesEffectProvider.future)` at line 328. The async gap created by this await allows the parent widget to be disposed and trigger autoDispose of this provider. However, lines 330-331 then call `ref.watch()` on the disposed ref without any lifecycle guard.
- Reachability: Production-reachable: dashboard screen watches dashboardChildNextReward via dashboardModelProvider. User navigation away from dashboard (or screen rotation/lifecycle events) during the stripStockMilestonesEffect.future await will trigger disposal.
- Fix: Add `if (!ref.mounted) return null;` guard immediately after line 328's await before accessing ref.watch() at lines 330-331. The pattern should be: `await ref.watch(...); if (!ref.mounted) return null; final db = ref.watch(...);`
- Confidence: high


---
## Rejected (did not survive adversarial verify)
- [offline-first] Profile deletion gates on online status in profile picker screen — `learning_tracker/lib/features/profiles/presentation/screens/profile_picker_screen.dart:385–402`
- [offline-first] Google sign-up checks returning-user status without Drift fallback, races on connectivity — `learning_tracker/lib/features/account/onboarding/presentation/screens/signup_screen.dart:405`
- [provider-lifecycle] Disposed ref.read() after async gap in stripStockMilestonesEffect — `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/dashboard/presentation/providers/dashboard_providers.dart:312`
