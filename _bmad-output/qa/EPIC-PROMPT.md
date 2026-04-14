# Prompt: Create Manual QA Verification Epic

Copy everything below this line and paste it after invoking `/bmad-create-epics-and-stories` in a new session.

---

I need to create an epic for systematic manual QA verification of the entire Learning Tracker app.

## Context

A comprehensive manual testing suite has been created at `_bmad-output/qa/` containing 18 documents with ~500 test scenarios organized by feature area. A developer needs to work through these documents systematically, testing every scenario and filing bugs in Linear for anything that fails.

The test documents are:

| # | File | Feature Area | ~Scenarios |
|---|------|-------------|------------|
| 00 | `00-testing-methodology.md` | Process guide (read first) | 0 |
| 01 | `01-product-overview.md` | Product context (read first) | 0 |
| 02 | `02-auth-and-accounts.md` | Auth (cloud-born, local-born, upgrade) | 26 |
| 03 | `03-onboarding.md` | Onboarding flow | 31 |
| 04 | `04-learning-and-completions.md` | Core completions | 45 |
| 05 | `05-multi-track.md` | Multi-track learning | 25 |
| 06 | `06-scheduler-and-goals.md` | Scheduler & goals | 42 |
| 07 | `07-content-browsing.md` | Content hierarchy & search | 20 |
| 08 | `08-dashboard-and-progress.md` | Dashboard & progress | 30 |
| 09 | `09-gamification.md` | Points, streaks, rewards | 26 |
| 10 | `10-parent-mode.md` | Parent mode (PIN, rewards) | 36 |
| 11 | `11-tutor-mode.md` | Tutor mode (PIN, read-only) | 28 |
| 12 | `12-notifications.md` | Notifications & Shabbos awareness | 30 |
| 13 | `13-settings.md` | Settings & data export/import | 29 |
| 14 | `14-sync-and-offline.md` | Sync & offline-first | 34 |
| 15 | `15-profiles.md` | Multi-profile management | 22 |
| 16 | `16-stages-and-order.md` | Configurable stages & learning order | 25 |
| 17 | `17-catchup-and-amnesty.md` | Catch-up & amnesty (forward-looking) | 64 |

Each scenario has a priority tier:
- **P0** (~150 scenarios): Must-test. Happy paths, data integrity, security.
- **P1** (~150 scenarios): Should-test. Edge cases, cross-feature interactions.
- **P2** (~150 scenarios): Nice-to-test. Rare combinations, performance.

## What to create

Create an epic called **"Manual QA Verification"** with stories that follow this structure:

### Story groupings

**Group 1: Foundation (must be done first)**
- Story: Read methodology and product overview docs (00, 01)
- Story: Set up testing environments (emulator + physical device)

**Group 2: Core Features (sequential, each builds on previous)**
- Story: Test auth & accounts (doc 02, ~26 scenarios)
- Story: Test onboarding flow (doc 03, ~31 scenarios)
- Story: Test learning & completions (doc 04, ~45 scenarios) -- CRITICAL, most important
- Story: Test multi-track learning (doc 05, ~25 scenarios)
- Story: Test configurable stages & learning order (doc 16, ~25 scenarios)

**Group 3: Scheduling & Progress (depends on Group 2)**
- Story: Test scheduler & goals (doc 06, ~42 scenarios)
- Story: Test dashboard & progress (doc 08, ~30 scenarios)
- Story: Test content browsing & search (doc 07, ~20 scenarios)

**Group 4: Engagement & Modes (can be parallelized)**
- Story: Test gamification (doc 09, ~26 scenarios)
- Story: Test parent mode (doc 10, ~36 scenarios)
- Story: Test tutor mode (doc 11, ~28 scenarios)
- Story: Test notifications (doc 12, ~30 scenarios)

**Group 5: Infrastructure (depends on Groups 2-4)**
- Story: Test settings (doc 13, ~29 scenarios)
- Story: Test sync & offline (doc 14, ~34 scenarios)
- Story: Test profiles (doc 15, ~22 scenarios)

**Group 6: Forward-looking (skip until Epic 22 ships)**
- Story: Test catch-up & amnesty system (doc 17, ~64 scenarios) -- BLOCKED until Epic 22 is implemented

### Per-story structure

Each story should include:
- Reference to the specific QA doc file path
- The scenario count and ID range (e.g., "LEARN-01 to LEARN-45")
- Acceptance criteria: "All P0 scenarios pass. P1 scenarios pass or have bugs filed. P2 scenarios tested if time permits."
- A note that bugs should be filed in Linear using Claude Code (team DNI)

### Dependencies
- Group 1 blocks everything
- Group 2 is sequential (each story depends on the previous)
- Group 3 depends on Group 2 completion
- Group 4 can run in parallel after Group 2
- Group 5 depends on Groups 2-4
- Group 6 is blocked by Epic 22

Read the existing epics at `_bmad-output/planning-artifacts/epics.md` to match the format and numbering conventions.
The PRD is at `_bmad-output/planning-artifacts/prd.md` and the architecture at `_bmad-output/planning-artifacts/architecture.md`.
