# Test Coverage Report — DNI-122

Generated: 2026-03-17
Test suite: 1293 passed, 10 skipped, 0 failures

## Overall Coverage

**53.8%** (8216/15262 lines)

## Coverage by Feature Area

| Area | Lines Covered | Total | Coverage |
|------|-------------|-------|----------|
| features/profiles | 51 | 54 | 94% |
| features/gamification | 307 | 348 | 88% |
| core/other (enums, utils, services, widgets, navigation) | 812 | 976 | 83% |
| features/parent_mode | 543 | 726 | 75% |
| features/scheduler | 673 | 941 | 72% |
| features/content_browsing | 578 | 815 | 71% |
| features/notifications | 427 | 604 | 71% |
| features/learning | 497 | 796 | 62% |
| features/tutor_mode | 332 | 561 | 59% |
| features/stages | 182 | 309 | 59% |
| features/settings | 468 | 857 | 55% |
| features/sync | 442 | 844 | 52% |
| features/dashboard | 165 | 319 | 52% |
| features/onboarding | 490 | 1052 | 47% |
| core/database | 1798 | 4968 | 36% |
| features/auth | 52 | 190 | 27% |

## Critical Gaps Identified

### 1. Core Database Layer (36% coverage)
- All DAOs have 0% direct test coverage in lcov (tested indirectly via repositories)
- Generated code (app_database.g.dart) at 0% inflates the gap
- Migration logic untested directly

### 2. Auth Flow (27% coverage)
- Auth repository impl has basic tests
- Auth guard has tests
- Sign-in screen, account creation screen lack direct widget tests with Firebase mocking

### 3. Onboarding Flow (47% coverage)
- Bulk mark screen (270 lines) at 0% — complex UI untested
- Welcome screen, mode selection have tests
- Account creation screen has tests

### 4. Sync Engine (52% coverage)
- SyncEngine and OfflineQueue have dedicated test files
- Firestore data source untested (requires Firebase)
- Real-time listener logic partially tested

### 5. Dashboard (52% coverage)
- Dashboard screen tested indirectly via navigation
- Dashboard providers partially covered

### 6. Settings (55% coverage)
- Settings screen widget tests now pass (fixed in this story)
- Track management screen has tests

## Test File Inventory

- **113 test files** across all features
- **15 story acceptance test files** (one per epic)
- All major features have at least basic test coverage
- All DAOs tested indirectly through repository tests

## Recommendations for Phase 3

Priority gaps to fill:
1. Auth guard integration tests (auth flow end-to-end)
2. Dashboard screen widget tests
3. Profile DAO direct unit tests (new in DNI-109)
4. Sync engine integration tests (mock Firestore)
5. Onboarding flow integration tests
