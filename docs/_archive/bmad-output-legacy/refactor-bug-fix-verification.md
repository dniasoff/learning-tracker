# Bug-Fix Integration Verification Report (W7.24)

**Agent:** W7.24 Final Verification  
**Date:** 2026-05-20  
**Branch:** dev  
**Status:** COMPLETE

---

## Summary

All three bug fixes (B1, B2, B3) are **VERIFIED** as correctly implemented at every integration site. Unit tests for all three pass green.

---

## B1 — Three-Tier Completion Credit Policy

**Verdict: VERIFIED**

### Integration sites checked:

**1. `CompletionSource` enum** — `lib/features/learning/domain/entities/completion_source.dart`
- ✓ Three values: `live`, `bulkInTrack`, `lifetimeOnly`
- ✓ `CompletionSourceX` extension provides `creditsEngagement`, `creditsAchievement`, `creditsLifetime` predicates
- ✓ Policy table matches spec: live=all three, bulkInTrack=achievement+lifetime, lifetimeOnly=lifetime only

**2. `MarkCompletionUseCase`** — `lib/features/learning/domain/use_cases/mark_completion_use_case.dart` (commit `9ea154bc`)
- ✓ Accepts `CompletionSource source = CompletionSource.live` parameter
- ✓ Fires `bulkEngagementSkipped` telemetry for `bulkInTrack` source (W7.11)
- ✓ Fires `lifetimeAchievementSkipped` telemetry for `lifetimeOnly` source (W7.11)
- ✓ Delegates `awardGamificationPoints: source.creditsEngagement` to repository

**3. Sealed `BatchPlan`** — `lib/features/learning/domain/entities/batch_plan.dart` (commit `eeea0a14`)
- ✓ Sealed class with three leaves: `LiveBatchPlan`, `BulkInTrackPlan`, `LifetimeOnlyPlan`
- ✓ `BatchPlan.classify({commands, source})` factory correctly routes to leaves
- ✓ Credit-tier predicates delegate to `CompletionSource`

**4. `prior_completion_imports` table** — `lib/core/database/tables/prior_completion_imports.dart` (commit `9612d7a0`)
- ✓ New table exists at correct path
- ✓ NOTE in `completion_events.dart` (line 47): "The `priorMarkOnly` column was removed in W4.26"
- ✓ `completion_events` table has no `priorMarkOnly` column

**5. Telemetry events** — `lib/core/logging/log_events.dart` (commit `b2569e04`, W7.11)
- ✓ `LogEvents.track.bulkEngagementSkipped` → `'bulk_engagement_skipped'`
- ✓ `LogEvents.track.lifetimeAchievementSkipped` → `'lifetime_achievement_skipped'`
- ✓ Both fired in `MarkCompletionUseCase.call()` for the correct source values

**6. `LifetimeTreeBuilder`** — `lib/features/progress/domain/services/lifetime_tree_builder.dart` (W4.16)
- ✓ Class exists as the B1 lifetime-tier subscriber
- ✓ `computeLearnedLeafRefs()` docs confirm it unifies: live completions (completedRefs), bulk-prior (ledger entries), lifetime-only (also ledger)
- ✓ All three CompletionSource values are handled via the union of completedRefs + ledgerEntries paths

### B1 regression tests:
```
flutter test test/features/learning/domain/entities/batch_plan_test.dart
# 12 tests — ALL PASS
```
Tests cover: classify round-trips, credit-tier predicates for each plan type, exhaustiveness, toString.

---

## B2 — Program-Track Start Window [today−30, today]

**Verdict: VERIFIED**

### Integration sites checked:

**1. `ProgramStartingPosition` VO** — `lib/core/domain/value_objects/program_starting_position.dart` (commit `c5b78eff`)
- ✓ `create({startDate, today, sefariaRef?})` factory throws `StartDateWindowException` for:
  - `startDate > today` (future dates)
  - `startDate < today − 30 days` (too far back)
- ✓ `kMaxLookBackDays = 30` constant
- ✓ `StartDateWindowException extends ValidationException`

**2. `ProgramStartingPosition.allowedWindow(today)`** — same file
- ✓ Returns `({DateTime minDate, DateTime maxDate})` record
- ✓ Used by `StepStartingPositionCalendarMode.initState()` in AddTrackFlow (W6.2)

**3. `AddTrackFlow` picker** — `lib/features/tracks/setup/presentation/steps/step_starting_position_calendar.dart` (W6.2)
- ✓ Line 80: `final window = ProgramStartingPosition.allowedWindow(_today);`
- ✓ `_minOffsetDays` computed from `window.minDate` (B2 enforcement comment present)
- ✓ `_maxOffsetDays = 0` (no future dates)

### B2 regression tests:
```
flutter test test/core/domain/value_objects/program_starting_position_test.dart
# 20 tests — ALL PASS
```
Tests cover: 20 window boundary cases including exact edges (day 0, day 30), rejections (day 31, future), legacy grammar parsing, equality.

---

## B3 — Back-Dated Enrolment Generates Overdue Catch-Up Tasks

**Verdict: VERIFIED**

### Integration sites checked:

**1. `ProvisionTrackUseCase`** — `lib/features/tracks/setup/domain/use_cases/provision_track_use_case.dart` (W4.14, commit `c6d255de`)
- ✓ B3 comment: "when `blueprint.startingPosition.daysFromToday` > 0 the track's program started in the past"
- ✓ Re-encodes `ProgramStartingPosition` to legacy grammar `offset:N|ref:...` for `TrackCreationService`
- ✓ The grammar encodes offset so service writes `trackingStartDate = today − offset` to `profile_programs`
- ✓ Integration test exists for back-date case (see below)

**2. Dashboard projection** — `lib/features/dashboard/presentation/widgets/dashboard_helpers.dart`
- ✓ `DailyTaskPriority.overdueProgram` and `DailyTaskPriority.overdueChazara` handled
- ✓ `overdueTasks` list populated from past-dated task priorities

**3. `LifetimeTreeBuilder` B3 projection** — `lib/features/progress/domain/services/lifetime_tree_builder.dart` (W4.16/W4.17)
- ✓ Handles all three completion sources (live, bulk-prior, lifetime-only) via completedRefs + ledgerEntries union

### B3 regression tests:
```
flutter test test/features/tracks/setup/domain/use_cases/provision_track_use_case_test.dart
# 13 tests — ALL PASS
```
Tests include: B3-1 (N=5 → 5 overdue), B3-2 (N=0 → 0 overdue), B3-3 (N=3 with 2 completions → 1 overdue remaining), B3-4 (daysFromToday reflects N), B3-5 (grammar round-trip).

---

## Conclusion

All three bug fixes are fully implemented and covered by green unit tests:
- B1: 12/12 batch_plan tests pass
- B2: 20/20 program_starting_position tests pass  
- B3: 13/13 provision_track_use_case tests pass

The fixes are integrated at the correct abstraction levels (domain use cases, VOs, data layer) with no regression detected in the B-test suites.
