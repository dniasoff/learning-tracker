# Round-6 bug hunt — 20 confirmed / 28 candidates

## [medium/merge-delegates] BookmarkMerger natural key does not match database unique constraint
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/core/sync/merge/bookmark_merger.dart`
- Symptom: BookmarkMerger uses natural key '${curriculumId}|${trackType}' (line 33), but DriftMergeStore._upsertBookmark resolves trackType to trackId and the Drift bookmarks table unique constraint is {profileId, curriculumId, trackId}. If a profile ever had multiple tracks per curriculum, or track assignments changed, a second bookmark for the same curriculum with a different trackType string but resolving to the same trackId would have a different natural key and would bypass LWW deduplication, causing duplicate upserts to the same unique key.
- Root cause: The natural key reflects the Firestore schema (curriculum_id, track_type) but the local Drift schema has evolved to use trackId FK instead. The mapping from track_type string to trackId is deterministic per-profile per-curriculum only if there is exactly one active track per curriculum. This assumption is fragile and not enforced by the schema or the merger logic.
- Reachability: High: Any pull of bookmark data triggers merge. The bug manifests only if: (1) a profile gains multiple tracks for a single curriculum, OR (2) trackType nomenclature changes in Firestore while trackId remains stable, OR (3) concurrent pulls arrive with different trackType strings for the same curriculum. Pre-launch status and controlled tutor writes make this low-probability but not impossible.
- Fix: Change BookmarkMerger natural key from '${curriculumId}|${trackType}' to '${curriculumId}' (matching the Drift unique constraint {profileId, curriculumId} after profileId scoping). This requires verifying that within a profile, there is at most one bookmark per curriculum. If multi-track bookmarks are intended, the Drift unique constraint should become {profileId, curriculumId, trackId} and the natural key should reflect that.

## [high/analytics-observers] Profile ID (PII) leaked in logParentModeEntered analytics event
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/core/analytics/analytics_service.dart`
- Symptom: Profile IDs are sent as analytics event parameters to Firebase Analytics, leaking personally identifiable information
- Root cause: Lines 85-88 define logParentModeEntered to accept and include profileId in event parameters: `parameters: {'profile_id': profileId}`. Profile IDs are unique per-user device identifiers and should not be sent to analytics
- Reachability: Called from showParentPinVerificationDialog in parent_pin_keypad_dialog.dart line 33 whenever a user successfully verifies their PIN to enter parent mode
- Fix: Remove profileId from the event parameters. The event can fire without the ID, or replace it with a hashed/anonymized identifier if profile-scoped analytics are needed. Change line 87 from `parameters: {'profile_id': profileId}` to `parameters: <String, Object>{}`

## [high/analytics-observers] Streak milestone analytics observer has no error handling, can crash app
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/core/analytics/streak_milestone_analytics_observer.dart`
- Symptom: If the streak state provider throws an exception during the await-for loop (lines 45-55), the entire async* generator errors, causing the StreamProvider to error, which propagates to the app's build method in learning_tracker_app.dart line 41 and crashes the app
- Root cause: The async* generator function has no try-catch block wrapping the `await for (final state in stateProvider.watch(...))` loop. If stateProvider.watch() throws (e.g., database error, clock error) or if analytics.logStreakMilestoneReached() throws, the stream errors without recovery. Additionally, learning_tracker_app.dart line 41 watches this provider with no error handling: `ref.watch(streakMilestoneAnalyticsObserverProvider);`
- Reachability: Active at app startup and whenever the active profile changes. The observer is a background task that must not crash the entire app even if the streak calculation fails temporarily
- Fix: Wrap the await-for loop in a try-catch block that catches and logs errors without re-throwing: `try { await for (...) { ... } } catch (e, st) { logger.error(...); }`. Also, optionally handle the provider error in learning_tracker_app.dart by using `.when()` instead of bare watch, though the try-catch is the primary fix

## [high/error-recovery] Unguarded null dereference on AsyncValue in learning_screen.dart
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/learning/presentation/screens/learning_screen.dart`
- Symptom: Screen crashes with null-pointer exception when dashboardStreakProvider is in loading or error state
- Root cause: Lines 46-47 access `.currentStreak` and `.maxStreak` properties on `streakAsync.asData?.value` without null-checking `.value` itself. When `asData` is null (loading/error state), the expression evaluates to null before attempting property access.
- Reachability: High - dashboardStreakProvider is a Stream provider that can emit loading/error states during provider setup, auth changes, or database errors. The screen is navigated to when user enters the app.
- Fix: Change lines 46-47 to guard against null: `final currentStreak = streakAsync.asData?.value?.currentStreak ?? 0;` and `final maxStreak = streakAsync.asData?.value?.maxStreak ?? 0;` OR wrap the entire initial watch block (lines 36-47) in a when() call with proper error/loading branches before accessing the values.

## [high/error-recovery] Unguarded null dereference on AsyncValue in parent_track_management_screen.dart
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/profiles/presentation/screens/parent_track_management_screen.dart`
- Symptom: FloatingActionButton visibility logic crashes when activeTracksProvider enters loading/error state
- Root cause: Line 51 accesses `.isNotEmpty` on `activeAsync.asData?.value` without null-checking value. When asData is null, value is null and .isNotEmpty causes null-pointer exception.
- Reachability: High - screen is shown when parent manages learner tracks, and activeTracksProvider can error during database queries or profile switches.
- Fix: Change line 51 to: `final showAddTrackFab = activeAsync.asData?.value?.isNotEmpty ?? false;`

## [medium/error-recovery] Error message leak to user in scheduler_screen.dart
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/scheduler/presentation/screens/scheduler_screen.dart`
- Symptom: Raw exception stack trace/message displayed to user when allDailyTasksProvider fails
- Root cause: Line 122 uses `error.toString()` directly in localized string: `l10n.errorLoadingTasks(error.toString())`. This exposes technical error details to the user instead of a friendly error message.
- Reachability: High - error branch is visible when tasks fail to load, which can occur on sync failures or database errors.
- Fix: Replace `error.toString()` with a friendly localized error message. Use `l10n.errorLoadingTasks()` without the error detail, or map common error types to user-friendly messages.

## [medium/error-recovery] Error message leak to user in tutor_pin_entry_gate.dart
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/tutoring/presentation/screens/tutor_pin_entry_gate.dart`
- Symptom: Raw exception stack trace displayed to user when PIN check fails
- Root cause: Line 91 uses `'$e'` (error.toString()) in localized string: `l10n.tutorPinErrorPrefix('$e')`. This exposes technical exception details to users.
- Reachability: High - error branch shown if tutorPinIsSetProvider fails, which can occur on profile switches or database errors.
- Fix: Replace `'$e'` with a friendly error message or localized string without technical details.

## [high/deep-link-routing] Missing @QueryParam annotation on token parameter in AcceptInviteScreen
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/tutoring/presentation/screens/accept_invite_screen.dart`
- Symptom: Deep-link navigation to /invite?token=<grantId> fails to extract the token query parameter from the URI, resulting in a missing required parameter error when the AcceptInviteScreen tries to use widget.token
- Root cause: The token parameter in the AcceptInviteScreen constructor (line 45) lacks the @QueryParam('token') annotation. Without this annotation, auto_route's code generation does not create logic to extract the token from the deep-link query string. The generated PageInfo builder only attempts data.argsAs<AcceptInviteRouteArgs>() without any fallback to query parameters, causing the parameter to remain uninitialized when the route is reached via deep-link
- Reachability: When a user clicks a tutoring invite link (e.g., from Firebase Dynamic Links or email) that matches the pattern /invite?token=<grantId>, the deep-link handler routes to the /invite path, but the token query parameter is not extracted due to missing annotation. This occurs before auth checks, so any unauthenticated user can potentially reach this broken state.
- Fix: Add the @QueryParam('token') annotation to the token parameter in AcceptInviteScreen constructor. Change line 45 from:
  const AcceptInviteScreen({required this.token, super.key});

to:
  const AcceptInviteScreen({
    @QueryParam('token') required this.token,
    super.key,
  });

## [high/date-math-edge] _dayOnly() incorrectly constructs UTC datetime from LOCAL date components
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/scheduler/domain/projection/overdue_projection.dart`
- Symptom: Overdue/dueToday projections can shift by up to ±12 hours across timezone boundaries, causing units to be miscategorized (today's unit marked overdue, or vice versa) for users in non-UTC timezones
- Root cause: Line 68: `DateTime _dayOnly(DateTime dt) => DateTime.utc(dt.year, dt.month, dt.day);` assumes input is UTC, but callers pass LOCAL DateTime objects from `DateUtils.extractLocalDate()` (which returns `DateTime(local.year, local.month, local.day)` without `.utc`). When a LOCAL datetime's components are fed to `DateTime.utc()`, the date is shifted by the local UTC offset. Example: User in UTC+2 on May 2 at 10 AM local (May 2 8 AM UTC) — extractLocalDate returns `DateTime(2026, 5, 2)` (local); _dayOnly extracts 2026/5/2 and creates `DateTime.utc(2026, 5, 2, 0, 0, 0)` which is May 2 UTC midnight, not May 2 local midnight (May 1 10 PM UTC in UTC+2). The comparison in overdue_projection.dart line 42-47 then misclassifies scheduled units.
- Reachability: High: Called via `project()` which is invoked on every scheduler screen render and overdue calculation. Affects all non-UTC users whenever schedule/overdue is computed.
- Fix: Replace `_dayOnly()` with a proper UTC midnight constructor. Use `DateUtils.startOfLocalDay()` (which already handles LOCAL→UTC conversion correctly) or implement: `static DateTime _dayOnly(DateTime dt) { final utcDt = dt.isUtc ? dt : dt.toUtc(); return DateTime.utc(utcDt.year, utcDt.month, utcDt.day); }`

## [high/date-math-edge] _dayOnly() in overdue_schedule.dart has identical bug
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/scheduler/domain/projection/overdue_schedule.dart`
- Symptom: selfPacedSchedule() and elapsedStudyDays() produce incorrect results for users in non-UTC timezones, causing wrong study-day counts and incorrect pace calculations
- Root cause: Line 185: Identical implementation to overdue_projection.dart: `DateTime _dayOnly(DateTime dt) => DateTime.utc(dt.year, dt.month, dt.day);` receives LOCAL DateTime objects from `DateUtils.extractLocalDate()` and misinterprets LOCAL date components as UTC, shifting dates by the local offset. In selfPacedSchedule(), this corrupts both anchor and today boundaries (lines 112-113), causing elapsedStudyDays() to count the wrong set of study days.
- Reachability: High: Called whenever a self-paced track needs its schedule computed, which includes every scheduler render and progress/overdue check.
- Fix: Apply same fix as overdue_projection.dart. Replace line 185 with UTC-safe implementation that properly converts LOCAL dates to UTC midnights.

## [high/dao-queries] Incomplete WHERE clause in completion_events purge: missing curriculumId
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/core/database/daos/track_dao.dart`
- Symptom: purgeHistory() tombstones completion_events rows using a 4-column WHERE predicate (profileId, sefariaRef, stageId, trackType) when the UNIQUE index requires all 5 columns including curriculumId. If any two completions share the same 4-column key but differ in curriculumId, both would be tombstoned instead of just the one from the deleted track.
- Root cause: Line 402-407 constructs a WHERE clause filtering on (profileId, sefariaRef, stageId, trackType) but omits curriculumId, which is part of the natural-key UNIQUE constraint defined at completion_events.dart:20-22. The Completion object returned by getCompletionsByTrack() includes curriculumId, but it is not used in the UPDATE WHERE.
- Reachability: Triggered when a user calls 'purge history' on any track (track soft-delete path via purgeHistory). The bug manifests if: (1) a profile has completions with identical sefariaRef/stageId/trackType across different curricula, and (2) the user purges one of those tracks. Both curricula's completions for that key would be incorrectly tombstoned.
- Fix: Add `& t.curriculumId.equals(c.curriculumId)` to the WHERE predicate on line 407 so the UPDATE matches all 5 columns of the natural key, preventing cross-curriculum collisions.

## [high/dao-queries] Cross-profile stage deletion: deleteAllForCurriculum deletes other profiles' stages
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart`
- Symptom: resetToDefaults() calls deleteAllForCurriculum(curriculumId) which hard-deletes all stage definitions for that curriculum across ALL profiles in the database. When a user resets stages for their personal track in Mishnah, all other users' Mishnah stage definitions are also deleted, causing data loss across profiles.
- Root cause: Line 291 invokes _stageDao.deleteAllForCurriculum(curriculumId.storageKey) without a profileId or trackId filter. The method definition (stage_dao.dart:39-41) only filters on curriculumId. However, StageDefinitions table has profileId as part of its UNIQUE key (profileId, curriculumId, stageOrder, trackId per stage_definitions.dart:39-41), and a track-scoped method deleteStagesForTrack(trackId) exists and should be used instead.
- Reachability: Triggered when a user calls 'reset to defaults' on any track's stage configuration (e.g., via the track editor). Every such action deletes stages from all profiles' tracks using the same curriculum. Multiple concurrent users in the same curriculum would cause silent, unexplained data loss.
- Fix: Replace line 291 with: `await _stageDao.deleteStagesForTrack(trackId);` to delete only the stages for the specific track being reset, matching the profileId/trackId scope passed to the method.

## [high/sync-orchestrator] Outbox Drain Guard Stale Reclaim Logic Does Not Reset Wedged State
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/core/sync/outbox/outbox_processor.dart`
- Symptom: When a single outbox push hangs without completing or timing out (rare but possible with network socket issues), the drain guard remains locked at `_draining = true` indefinitely. After the stale threshold (90 seconds) elapses, the intended reclaim logic does not actually reset the wedged state. Instead, the code falls through and sets `_draining = true` again, allowing a second drain to run concurrently with the first. This causes two drains to execute in parallel, pushing the same rows twice, corrupting the outbox and creating duplicate Firestore writes.
- Root cause: At lines 181-184, the stale-guard reclaim check returns early when elapsed time is LESS than the stale threshold (correct). However, when elapsed >= staleAfter (the guard IS wedged), the code falls through to line 186 which sets `_draining = true` again without clearing the original `_drainingSince` timestamp or the presumed in-flight drain. The second caller believes it acquired a fresh guard, but the state machine is now inconsistent: _draining is true for TWO separate logical drains.
- Reachability: Triggered when: (1) A Firestore push Future never resolves (no error, no timeout—e.g., broken IPv6 route, half-open TCP, or hung grpc-java stream); (2) The periodic drain timer fires after the stale threshold (90s) without a successful drain in between; (3) The orchestrator's five drain triggers all coalesce near the 90s boundary.
- Fix: When the stale-guard reclaim logic detects a wedged drain (elapsed >= _drainStaleAfter), reset _drainingSince to null BEFORE allowing the new drain to proceed. This way, the subsequent `_draining = true; _drainingSince = _clock.nowUtc()` assignment creates a fresh guard state. Change line 182-184 to: `if (since != null && _clock.nowUtc().difference(since) < _drainStaleAfter) { return 0; } _drainingSince = null;` (before line 186). Alternatively, reset both fields: `_draining = false; _drainingSince = null;` at line 185 before the unconditional reassignment at line 186.

## [medium/accessibility-rtl] Chevron icons don't mirror in RTL across multiple screens
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/notifications/presentation/screens/notifications_screen.dart`
- Symptom: Line 319: trailing chevron in time-picker row uses `Icons.chevron_right_rounded` without RTL mirroring. In Hebrew RTL layout, this points in the wrong direction (should point left in RTL)
- Root cause: Icons.chevron_right and chevron_left are directional icons that do NOT auto-mirror in RTL per Flutter Material Design. In RTL, forward navigation should use chevron_left. No Directionality wrapper.
- Reachability: Always reachable: Settings → Notifications screen is accessible from main menu. Time picker rows displayed whenever notifications are enabled
- Fix: Wrap Icon in Directionality with textDirection from Localizations.localeOf(context), or use adaptive icon logic: `isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded`

## [medium/accessibility-rtl] Directionality.ltr forces LTR layout on numeric metrics (progress %), breaking RTL alignment
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/gamification/presentation/widgets/achievement_tier_card.dart`
- Symptom: Line 140-166: Directionality(textDirection: ui.TextDirection.ltr) wraps a Row containing milestone points + percentage. In Hebrew RTL, this forces the entire metric row into LTR, breaking card visual balance where metrics should align to end (right in LTR, left in RTL)
- Root cause: Explicit hardcoded `textDirection: TextDirection.ltr` ignores app's RTL layout direction. Intent is likely to force numeric content to be LTR (numbers are inherently LTR), but the wrapper affects the entire Row's layout direction
- Reachability: Always reachable: Achievements screen visible from dashboard gamification tab, displays all unlocked/upcoming tiers with progress
- Fix: Use `textAlign: TextAlign.end` or `TextAlignVertical.center` on individual Text widgets instead of Directionality wrapper. If LTR-only numeric is intended, apply textDirection only to Text, not the Row

## [medium/accessibility-rtl] Progress summary card forces LTR on metrics, breaks RTL visual balance
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/gamification/presentation/widgets/progress_summary_card.dart`
- Symptom: Line 67-94: Directionality(textDirection: TextDirection.ltr) wraps a Row showing fraction (e.g., '3/10 Rewards'). In Hebrew RTL, forces entire metric section into LTR, misaligning card layout
- Root cause: Hardcoded `textDirection: TextDirection.ltr` overrides device RTL layout. Likely intended to keep numeric fraction LTR, but incorrectly applied to entire Row instead of individual text elements
- Reachability: Always reachable: Achievements section on dashboard, blue summary card at top shows '3/10 Rewards Unlocked'
- Fix: Remove Directionality wrapper. Use RichText or separate Text widgets with `textAlign: TextAlign.end` if numeric ordering matters. Numbers auto-render LTR within Text regardless

## [medium/accessibility-rtl] Navigation chevron icons lack RTL mirroring across dashboard carousel and cards
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/dashboard/presentation/widgets/active_tracks_carousel_section.dart`
- Symptom: Lines 80, 93: ArrowButton uses Icons.chevron_left_rounded and Icons.chevron_right_rounded without RTL logic. In Hebrew layout, carousel navigation arrows point wrong direction (should swap)
- Root cause: Material icons chevron_left/chevron_right do not auto-mirror in RTL. ArrowButton passes icons directly without checking TextDirection.of(context)
- Reachability: Always reachable: Dashboard active tracks carousel visible on home screen (Story 2.2), navigation arrows used to browse multiple tracks
- Fix: In ArrowButton widget, check Directionality.of(context) and swap icons: if RTL, left-nav uses chevron_right and vice versa

## [high/firestore-roundtrip] ProfileRepositoryImpl._toFirestorePayload writes 'id' but LearnerProfileCodec expects 'profile_id'
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/profiles/data/repositories/profile_repository_impl.dart:27`
- Symptom: ProfileRepositoryImpl._toFirestorePayload() writes the profile id field as 'id' (line 27), but LearnerProfileCodec.decode() reads 'profile_id' (lib/core/sync/codec/learner_profile_codec.dart:46). When a profile is pushed to Firestore with 'id' key and then decoded via the codec, the decode returns null because the required profileId field cannot be read, causing the entire profile merge to be skipped.
- Root cause: Field name mismatch between the write path (ProfileRepositoryImpl._toFirestorePayload) and the codec read path. The write side uses 'id' as a shorthand key, but the codec expects the fully qualified 'profile_id' key. The LearnerProfileCodec.decode() checks if profileId is null at line 53 and returns null if it is, causing the entire row to be silently dropped from the merge (line 59 in learner_profile_merger.dart continues to next row).
- Reachability: High. The defect is reachable through: (1) App creates/updates a profile via ProfileRepositoryImpl.createProfile or updateProfile; (2) _syncEngine.pushLearnerProfile() is called with _toFirestorePayload(model) which has 'id' key; (3) Profile is pushed to Firestore; (4) During pull sync, LearnerProfileMerger calls codec.decode(row); (5) codec tries to read 'profile_id' which doesn't exist; (6) profileId is null, decode returns null; (7) merge skips the row silently.
- Fix: Change ProfileRepositoryImpl._toFirestorePayload() line 27 from 'id': profile.id to 'profile_id': profile.id to match the key expected by LearnerProfileCodec.decode().

## [high/completion-concurrency] Missing curriculumId in duplicate completion detection
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/learning/data/repositories/completion_repository_impl.dart`
- Symptom: When markComplete() is called for the same (sefariaRef, stageId, trackType) tuple but different curriculumId values, the duplicate check incorrectly returns an existing completion from a different curriculum instead of creating a new one for the requested curriculum.
- Root cause: Lines 82-88 in markComplete() filter completions by stageId and trackType only, omitting curriculumId from the idempotency key. The _getExistingCompletion() helper at lines 602-604 has the same defect. The CompletionRequest includes curriculumId but the duplicate detection does not use it.
- Reachability: Reachable via any markComplete call where the same item is studied in multiple curricula. This is particularly likely in the bulk-mark-prior path which can mark items across different curriculum scopes.
- Fix: Add curriculumId to the duplicate detection filter: at line 85-86, add 'c.curriculumId == request.curriculumId' to the where() condition. Also update _getExistingCompletion() signature to accept curriculumId and filter on it at line 603.

## [high/completion-concurrency] OptimisticCompletionState provider methods never invoked
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/learning/presentation/providers/optimistic_completion_provider.dart`
- Symptom: OptimisticCompletionState.add() and .remove() methods (lines 23 and 28-30) are never called anywhere in the codebase. The optimistic completion state is watched by isStageCompletedProvider (line 42-48 in completion_providers.dart) but the UI never populates it.
- Root cause: The optimistic state management was defined as infrastructure but integration points to call .add() on button press and .remove() on error were never wired into the text_display_screen.dart _handleComplete() flow.
- Reachability: Observable if double-tapping the Mark Complete button: the UI guard at line 569 and button onPressed condition at line 827 prevent re-entrance, so the UNIQUE index in CompletionWriter protects against actual double-credits. However, the optimistic state is effectively dead code.
- Fix: Either (1) wire the optimistic state into _handleComplete by calling ref.read(optimisticCompletionStateProvider.notifier).add() before the write and .remove() in the catch block, or (2) delete the unused OptimisticCompletionState provider entirely to reduce dead code.


---
## Rejected: 8
- [merge-delegates] GoalCodec reads wrong Firestore field for pace period (dead code but confusing) — /home/daniel/repos/learning-tracker/learning_tracker/lib/core/sync/codec/goal_codec.dart
- [analytics-observers] Profile ID (PII) leaked in logPinLockedOut analytics event — /home/daniel/repos/learning-tracker/learning_tracker/lib/core/analytics/analytics_service.dart
- [error-recovery] Unguarded null dereference on AsyncValue in recent_activity_screen.dart — /home/daniel/repos/learning-tracker/learning_tracker/lib/features/progress/presentation/screens/recent_activity_screen.dart
- [error-recovery] Unguarded null dereference on AsyncValue in lifetime_marking_screen.dart — /home/daniel/repos/learning-tracker/learning_tracker/lib/features/settings/presentation/screens/lifetime_marking_screen.dart
- [error-recovery] Unguarded null dereference on AsyncValue in track_management_hub_screen.dart — /home/daniel/repos/learning-tracker/learning_tracker/lib/features/tracks/setup/presentation/screens/track_management_hub_screen.dart
- [date-math-edge] Fake calendar engine in test returns LOCAL DateTime (inconsistent with production) — /home/daniel/repos/learning-tracker/learning_tracker/test/scheduler/overdue_projection_test.dart
- [accessibility-rtl] TextFormField hardcoded to TextDirection.rtl breaks English input — /home/daniel/repos/learning-tracker/learning_tracker/lib/features/tracks/setup/presentation/widgets/track_label_step.dart
- [firestore-roundtrip] GoalEntity.toFirestore() writes 'pace_unit' but GoalMerger expects it; GoalCodec expects 'pace_period' — /home/daniel/repos/learning-tracker/learning_tracker/lib/features/scheduler/domain/models/goal_entity.dart:179
