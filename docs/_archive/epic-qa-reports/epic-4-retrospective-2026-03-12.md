# Retrospective — Epic 4: Multi-Track Learning
**Date:** 2026-03-12
**Facilitator:** Bob (Scrum Master)
**Project Lead:** Daniel Niasoff

---

## Epic Summary

| Metric | Value |
|--------|-------|
| Epic | 4 — Multi-Track Learning (DNI-8) |
| Stories Completed | 3/3 (100%) |
| Final Test Count | 671 passing |
| Code Review Rounds | 2 per story (all required fixes) |
| High Findings Resolved | 9/9 |
| Technical Debt Items | 1 (Firestore track sync — deferred to Epic 13) |
| Lines Deleted (cleanup) | ~4,744 |

**Stories:**
- DNI-38: [4.1] Track Management
- DNI-39: [4.2] Track Assignment & Duplicate Prevention
- DNI-40: [4.3] Track-Specific Progress Views

---

## Team Participants
- Bob (Scrum Master) — facilitator
- Alice (Product Owner)
- Charlie (Senior Dev)
- Dana (QA Engineer)
- Elena (Junior Dev)
- Daniel (Project Lead)

---

## Successes & Strengths

1. **Track model design held up** — The personal/school/tutor model maps cleanly to real-world Jewish learning contexts. No architectural regrets after implementation.
2. **Solid data layer foundation (DNI-38)** — `curriculum_tracks` table, `TrackDAO`, clean separation of activation state from completion data. DNI-39 and DNI-40 built on it without rework.
3. **Significant codebase cleanup** — ~4,744 lines of dead code removed (stale text download service, future-epic test stubs, unused utilities). Codebase is measurably cleaner entering Epic 5.
4. **Test infrastructure** — `make test-story-4.x` targets, 671 passing tests, acceptance test coverage across all 3 stories.
5. **All HIGH findings fixed** — Every critical code review finding was resolved before merge. Nothing was shipped broken.

---

## Challenges & Growth Areas

### Challenge 1: `contentItemId → sefariaRef` Migration Ghost (2/3 stories)
**What happened:** Epic 3 migrated the completions table from `contentItemId: int` to `sefariaRef: String`. Epic 4 implementation agents used the old field name, causing:
- DNI-38: compile error in `DuplicatePreventionService`
- DNI-39: 19 analysis errors across source and tests

**Root cause:** Story briefs didn't flag the schema change from the previous epic. Agents worked from a mental model that was one epic out of date.

**Impact:** Both stories required HIGH-severity code review findings and fix cycles.

### Challenge 2: Two Disconnected Track Implementations (DNI-39)
**What happened:** DNI-38 built `TrackRepository` (DB-backed). DNI-39, without finding it, built a parallel `TrackService` (in-memory). Production code was wired to the in-memory service — meaning no data was actually persisted to the database.

**Root cause:** No codebase search performed before creating a new abstraction. Implementation gap not caught until code review.

**Impact:** Required architectural fix at review; all tests passed incorrectly against in-memory service.

### Challenge 3: `riverpod_generator` Can't Handle `Map<K,V>` Return Types (DNI-40)
**What happened:** `progress_providers.g.dart` was never generated. `CurriculumProgressScreen` didn't compile — 8 cascade errors. `progressRepositoryProvider` also undefined in test file.

**Root cause:** Undocumented toolchain limitation. `riverpod_generator` doesn't support `Map<TrackType, int>` return types.

**Fix applied:** Manually authored `.g.dart` file with correct Riverpod 3 class structure.

**Impact:** Fragile workaround now in codebase; needs documentation to prevent future agents from unknowingly running build_runner over it.

### Challenge 4: `initializeDefaultTracks` Not Wired Into Activation Flow (DNI-38)
**What happened:** The method was correctly implemented but never called from `CurriculumActivationService`. AC1 ("curriculum starts with personal track only") never actually fired in production.

**Root cause:** Acceptance criteria verified logic existence, not integration/wiring.

**Fix applied:** `CurriculumActivationService.activate()` now calls `trackRepository.initializeDefaultTracks()`.

---

## Key Insights & Lessons Learned

1. **Schema migrations need explicit propagation.** When a field changes in one epic, the next epic's story briefs must flag it in a "Changed since last epic" section. A compile-error-free PR is a minimum bar, not a bonus.

2. **Search before you build.** Before implementing a new abstraction, dev agents must grep the codebase for existing implementations of the same concept. A 30-second search would have prevented the dual `TrackService`/`TrackRepository` situation.

3. **Code generators have limits — document them.** `riverpod_generator` + `Map<K,V>` return types = manual `.g.dart` file. This must be in the architecture quick reference so it's not rediscovered in every future epic.

4. **Wiring is an acceptance criterion.** Logic existing ≠ logic connected. Every AC involving a new service call should include an explicit "verify called from X" check.

5. **`dart analyze` is non-negotiable.** All HIGH findings in this epic would have been caught by a pre-submission `dart analyze` run. This must be a hard gate, not a suggestion.

---

## Previous Retrospective Follow-Through

N/A — This is the first retrospective for this project.

---

## Next Epic Preview — Epic 5: Configurable Stages & Learning Order (DNI-9)

**Stories:** 2
- 5.1: Stage Definition Configuration
- 5.2: Drag-and-Drop Learning Order

**Dependencies on Epic 4:** None direct (Epic 5 depends on Epic 3)
**Enables:** Epic 6 (Smart Scheduler — depends on stage definitions and learning order)

**Preparation needed before Epic 5 starts:**
- Epic 4's track model (TrackRepository, sefariaRef schema) must be understood by Epic 5 dev agents
- The manual riverpod provider pattern must be documented
- Dev checklist must enforce `dart analyze` gate and codebase search step

---

## Action Items

### Process Improvements

| # | Action | Owner | Deadline | Success Criteria |
|---|--------|-------|----------|-----------------|
| 1 | Enforce `dart analyze` as a hard pre-completion gate in dev story checklist | SM (checklist update) | Before Epic 5 story 5.1 | No HIGH compile-error findings in Epic 5 reviews |
| 2 | Add "codebase search before new abstraction" step to dev story checklist | SM (checklist update) | Before Epic 5 story 5.1 | No duplicate implementations discovered at review in Epic 5 |
| 3 | Add "Changed since last epic" section to story brief template | SM | Before Epic 5 sprint planning | Epic 5 briefs reference current schema |

### Technical Debt

| # | Item | Priority | Target Epic |
|---|------|----------|-------------|
| 1 | Firestore sync for track activation state (marked TODO in DNI-38) | MEDIUM | Epic 13 (Cloud Sync) |
| 2 | `TrackProgressBar` flex rounding for small-count tracks | LOW | Epic 7 (Dashboard) |

### Documentation

| # | Document | Owner | Deadline |
|---|----------|-------|----------|
| 1 | Add `riverpod_generator` Map<K,V> limitation to `architecture-quick-reference.md` | Dev/Architect | Before Epic 5 story 5.1 |
| 2 | Write "Entering Epic 5" codebase state brief (sefariaRef schema, TrackRepository as canonical, manual provider pattern, track colors in theme) | SM/Architect | Before Epic 5 story 5.1 |

### Team Agreements

- Story briefs for Epic 5+ include explicit "Changed since last epic" section
- Acceptance criteria must verify wiring, not just logic existence
- `make ci` must pass locally before any story is marked complete
- `dart analyze` zero-errors is a mandatory pre-submission gate

---

## Epic 5 Preparation Tasks

```
[ ] Update dev story checklist: dart analyze gate + codebase search step
    Owner: SM

[ ] Add riverpod_generator Map<K,V> limitation to architecture-quick-reference.md
    Owner: Dev/Architect

[ ] Write "Entering Epic 5" codebase state brief
    Owner: SM/Architect

[ ] Add Firestore track sync TODO as a note on Epic 13 (DNI-17) in Linear
    Owner: SM
```

---

## Critical Path Before Epic 5 Kickoff

| # | Item | Owner | Must Complete By |
|---|------|-------|-----------------|
| 1 | Dev checklist updated (dart analyze gate + search step) | SM | Before 5.1 assigned |
| 2 | Codebase state brief written | SM/Architect | Before 5.1 assigned |

No significant discoveries requiring Epic 5 replanning. Architecture and story plan are sound.

---

## Readiness Assessment

| Area | Status | Notes |
|------|--------|-------|
| Testing & Quality | ✅ Complete | 671 tests passing, all HIGH findings resolved |
| Deployment | 🔄 Dev branch | Merged to dev, not yet production release |
| Stakeholder Acceptance | ✅ Accepted | Daniel has visibility and expressed confidence in team |
| Technical Health | ✅ Healthy | Codebase cleaner post-Epic 4 (4,744 lines removed) |
| Unresolved Blockers | ⚠️ 1 open | Firestore track sync — correctly deferred to Epic 13 |

**Epic 4 verdict:** Functionally complete. Clear to proceed to Epic 5 once preparation tasks are done.

---

## Commitments Summary

- Action Items: 6
- Preparation Tasks: 4
- Critical Path Items: 2
- Significant Discoveries Requiring Epic Replan: 0

---

## Next Steps

1. Review this retrospective summary
2. Execute preparation tasks (checklist update, quick-reference update, codebase brief)
3. Begin Epic 5 sprint planning once preparation is complete
4. Review action items in next standup to confirm ownership

---

Bob (Scrum Master): "Great session, team. Epic 4 is in the books. Let's make Epic 5 cleaner."

Alice (Product Owner): "See you at sprint planning."

Charlie (Senior Dev): "Time to knock out that prep work."
