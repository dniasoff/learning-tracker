# Story 18.8: Instant Mark Complete (Performance Fix)

Status: ready-for-dev

## Story

As a learner,
I want marking an item complete to feel instant,
so that the app doesn't break my learning flow with lag.

## Acceptance Criteria

**AC-1: Optimistic UI update**
**Given** the user taps "mark complete"
**When** the tap registers
**Then** the UI updates instantly (animation, points popup, next item) without waiting for DB write to finish

**AC-2: Background persistence**
**Given** the UI has updated optimistically
**When** the completion is being persisted
**Then** the DB write and Firestore sync happen in the background
**And** the user is never blocked

**AC-3: Sub-100ms perceived response**
**Given** the user marks an item complete
**When** measuring from tap to visual feedback
**Then** the response is < 100ms (perceived instant)

**AC-4: Error recovery**
**Given** the DB write fails after optimistic update
**When** the error is detected
**Then** the UI rolls back gracefully with a subtle error message
**And** the user can retry

## Tasks / Subtasks

### T1: Profile Current Mark-Complete Path (AC: 3)

- [ ] Trace the full completion path end-to-end:
  - UI tap → `MarkCompletionUseCase` → `CompletionRepository.markComplete()` → DB transaction → provider invalidation → scheduler recalc → UI rebuild
- [ ] Identify bottleneck: DB insert? Provider rebuild? Firestore sync? Scheduler recalculation?
- [ ] Measure current latency at each step
- [ ] Document findings in Debug Log

### T2: Implement Optimistic UI Update (AC: 1, 3)

- [ ] Create optimistic state management for completion:
  - On tap: immediately update UI state (animation, points, next item)
  - Use a local `StateProvider` or `StateNotifier` for optimistic completion state
  - UI reads optimistic state first, falls back to DB state
- [ ] Trigger celebration animation / points popup immediately on tap
- [ ] Advance to next item in the UI without waiting for DB
- [ ] Target: < 100ms from tap to visual feedback

### T3: Background Persistence (AC: 2)

- [ ] After optimistic UI update, fire DB write asynchronously:
  - Call `CompletionRepository.markComplete()` via `unawaited()` or separate isolate
  - DB transaction runs in background
  - Firestore sync already fire-and-forget (verify this)
- [ ] Scheduler recalculation should NOT block UI:
  - Move scheduler recalc to post-frame callback or microtask
  - Or debounce if multiple completions happen rapidly
- [ ] Verify provider invalidation doesn't cause full widget tree rebuild
  - Use selective invalidation (only affected providers)

### T4: Error Recovery & Rollback (AC: 4)

- [ ] If DB write fails after optimistic update:
  - Rollback optimistic state
  - Show subtle snackbar: "Couldn't save — tap to retry"
  - Log error with talker
- [ ] Retry mechanism:
  - Tap snackbar to retry the DB write
  - Or auto-retry with exponential backoff (max 3 attempts)
- [ ] If rollback occurs mid-animation, handle gracefully (no jarring UI)

### T5: Prevent Cascading Provider Rebuilds (AC: 3)

- [ ] Audit which providers are invalidated on completion:
  - `completionCount` provider
  - `isStageCompleted` provider
  - `allDailyTasks` provider (scheduler)
  - `paceStatus` provider
  - Dashboard aggregate providers
- [ ] Use `ref.invalidate()` selectively — only providers that actually changed
- [ ] Consider `select()` to narrow rebuild scope in widgets
- [ ] Debounce scheduler recalculation for rapid completions

### T6: Handle Rapid Completions (AC: 1, 2)

- [ ] If user marks multiple items in quick succession:
  - Each gets optimistic UI update immediately
  - DB writes queue in order
  - Scheduler recalculation debounced (run once after burst)
- [ ] No race conditions between optimistic state and DB state
- [ ] Test: mark 5 items in 3 seconds — all feel instant, all persist correctly

### T7: Tests (AC: 1-4)

- [ ] Unit test: optimistic state updates immediately on mark-complete call
- [ ] Unit test: DB write happens asynchronously after optimistic update
- [ ] Unit test: error recovery rolls back optimistic state
- [ ] Unit test: retry mechanism works after rollback
- [ ] Unit test: rapid completions all persist correctly
- [ ] Widget test: UI shows animation/points before DB write completes
- [ ] Integration test: full flow — tap → animation → DB → sync (verify order)
- [ ] Performance test: measure tap-to-visual-feedback latency

## Dev Notes

### Architecture

- **No dependencies** — can be done in parallel with other Epic 18 stories
- **Core change:** Separate UI response from persistence in the completion flow
- **Pattern:** Optimistic UI update with background persistence and rollback

### Current Completion Flow (Being Optimized)

```
tap → MarkCompletionUseCase → CompletionRepository.markComplete()
  → DB transaction (insert completion, advance bookmark)
  → Provider invalidation (multiple providers)
  → Scheduler recalculation (חזרה queue rebuild)
  → Firestore sync (fire-and-forget)
  → UI rebuild (celebration, next item)
```

### Target Flow

```
tap → Optimistic UI update (< 100ms)
  → Animation/points/next item IMMEDIATELY
  → Background: DB transaction → provider invalidation → scheduler recalc → sync
  → On error: rollback optimistic state + retry prompt
```

### Key Files

| File | Action |
|------|--------|
| `lib/features/learning/domain/use_cases/mark_completion_use_case.dart` | Modify — add optimistic path |
| `lib/features/learning/data/repositories/completion_repository_impl.dart` | Verify — transaction timing |
| `lib/features/learning/presentation/providers/completion_providers.dart` | Modify — optimistic state |
| Dashboard/task widgets | Modify — read optimistic state |

### Investigation Areas

- Is `CompletionRepository.markComplete()` the bottleneck? Or is it provider cascade?
- Does `CompletionDetectionService` (auto-detect unit/masechta completions) run synchronously?
- How many providers get invalidated per completion? Can we reduce?
- Is the scheduler `_calculateNewItemRate()` expensive for large curricula?

### Critical Constraints

- Append-only completions: optimistic state must NOT allow marking the same item twice
- Stage progression validation still required (can't skip stages)
- Duplicate detection: `DuplicateCompletionException` must still be caught
- Points calculation must be correct (even in optimistic mode)

### References

- [Source: _bmad-output/project-context.md — Completion Immutability section]
- [Source: docs/developer-guide.md#daily-tracking-flow]

## Dev Agent Record

### Agent Model Used

_To be filled during implementation_

### Debug Log References

### Completion Notes List

### File List
