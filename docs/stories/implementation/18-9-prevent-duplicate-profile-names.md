# Story 18.9: Prevent Duplicate Profile Names (DNI-174)

Status: review

## Story

As a user,
I want the app to prevent creating two profiles with the same name (case-insensitive),
so that I do not accidentally create duplicate learner profiles.

## Acceptance Criteria

**AC-1: Case-insensitive duplicate prevention on create**
**Given** a profile named "Daniel" already exists for the account
**When** the user attempts to create "daniel" (or "DANIEL", "DaNiEl")
**Then** creation is rejected with a clear error message

**AC-2: Duplicate prevention on rename**
**Given** profiles "Daniel" and "Sarah" exist
**When** the user renames "Sarah" to "Daniel" (case-insensitive)
**Then** the rename is rejected with a clear error message

**AC-3: User-facing validation feedback**
**Given** the user is typing a profile name
**When** the entered name matches an existing profile (case-insensitive)
**Then** an inline validation message appears: "A profile with this name already exists"
**And** the Create/Save button is disabled

**AC-4: Whitespace-normalized comparison**
**Given** a profile named "Daniel" exists
**When** the user enters " Daniel " (with whitespace)
**Then** the name is trimmed before comparison and creation is rejected

**AC-5: Same name allowed after deletion**
**Given** a profile named "Daniel" was deleted
**When** the user creates a new profile "Daniel"
**Then** creation succeeds

## Tasks / Subtasks

### T1: Add DuplicateProfileNameException (AC: 1, 2)

- [x] Add `DuplicateProfileNameException` class to `lib/features/profiles/domain/repositories/profile_repository.dart`
- [x] Follows pattern of existing `MaxProfilesExceededException`

### T2: Add profileExistsByName DAO Method (AC: 1, 4)

- [x] Add `profileExistsByName(int accountId, String displayName)` to `ProfileDao`
- [x] Case-insensitive comparison using `LOWER()` + `TRIM()` in SQL
- [x] Unit tests in `profile_dao_test.dart`

### T3: Update createProfile with Duplicate Check (AC: 1, 4)

- [x] In `ProfileRepositoryImpl.createProfile()`, check `profileExistsByName()` before insert
- [x] Trim whitespace and compare case-insensitively at repository level
- [x] Throw `DuplicateProfileNameException` if exists

### T4: Update updateProfile with Duplicate Check (AC: 2)

- [x] In `ProfileRepositoryImpl.updateProfile()`, check for name conflict (excluding self by ID)
- [x] Throw `DuplicateProfileNameException` if rename conflicts

### T5: Add Inline Validation to Onboarding UI (AC: 3)

- [x] In `onboarding_screen.dart`, add listener on `_nameController` to check against `profileListProvider`
- [x] Show inline error message when duplicate detected
- [x] Disable Continue button when duplicate

### T6: Repository Tests (AC: 1-5)

- [x] Test exact duplicate name rejection
- [x] Test case-insensitive duplicate rejection
- [x] Test whitespace-padded duplicate rejection
- [x] Test different accounts can have same name
- [x] Test rename blocked when name conflicts
- [x] Test rename to same name (self-match) allowed
- [x] Test deleted profile name is reusable

## Dev Notes

### Architecture

- **Validation at repository level:** Normalization (trim + case-insensitive) happens in repository, not UI
- **Display name preserves casing:** Store as-entered, compare lowercased
- **Pattern follows `MaxProfilesExceededException`:** Same approach for the new `DuplicateProfileNameException`

### Key Files

| File | Path | Role |
|------|------|------|
| ProfileRepository | `lib/features/profiles/domain/repositories/profile_repository.dart` | Interface + DuplicateProfileNameException |
| ProfileRepositoryImpl | `lib/features/profiles/data/repositories/profile_repository_impl.dart` | Duplicate check in create + update |
| ProfileDao | `lib/core/database/daos/profile_dao.dart` | `profileExistsByName()` SQL query |
| OnboardingScreen | `lib/features/onboarding/presentation/screens/onboarding_screen.dart` | Inline validation UI |
| ProfileRepositoryTest | `test/features/profiles/data/repositories/profile_repository_impl_test.dart` | Extended tests |
| ProfileDaoTest | `test/core/database/daos/profile_dao_test.dart` | DAO query tests |

### Database Query

```sql
SELECT 1 FROM profiles
WHERE account_id = ? AND LOWER(display_name) = LOWER(TRIM(?))
LIMIT 1
```

### Critical Constraints

- Repository normalizes (trim + lowercase) — callers need not worry
- Display name preserves user's casing in DB
- Self-match on rename is allowed (renaming "Daniel" to "Daniel")
- Deleted profiles do not block new names

### Testing Standards

- 8 acceptance tests covering all edge cases
- DAO-level test for SQL query correctness
- Widget test for inline validation in onboarding

### References

- [Source: docs/_archive/tooling-notes/project-context.md#Error Handling] — Try-catch, error messages
- [Source: docs/_archive/tooling-notes/project-context.md#drift Database Patterns] — Query patterns

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

_None — clean implementation_

### Completion Notes List

- T1: Added `DuplicateProfileNameException` to `profile_repository.dart` following `MaxProfilesExceededException` pattern.
- T2: Added `profileExistsByName()` to `ProfileDao` with case-insensitive SQL query using `LOWER()` + `TRIM()`.
- T3: Updated `ProfileRepositoryImpl.createProfile()` — checks `profileExistsByName()` before insert, throws on duplicate.
- T4: Updated `ProfileRepositoryImpl.updateProfile()` — checks for name conflict excluding self by ID.
- T5: Added inline validation in `onboarding_screen.dart` — `_nameController` listener checks against existing profiles.
- T6: All acceptance tests passing — exact, case-insensitive, whitespace, cross-account, self-match, rename, deletion scenarios.

### Change Log

- 2026-03-29: Initial implementation — duplicate prevention in create + update, inline UI validation. Commit `0af52b9`.

### File List

**Modified:**
- `lib/features/profiles/domain/repositories/profile_repository.dart` — added `DuplicateProfileNameException`
- `lib/features/profiles/data/repositories/profile_repository_impl.dart` — duplicate check in create + update
- `lib/core/database/daos/profile_dao.dart` — added `profileExistsByName()` method
- `lib/features/onboarding/presentation/screens/onboarding_screen.dart` — inline validation UI
- `test/features/profiles/data/repositories/profile_repository_impl_test.dart` — extended tests
- `test/core/database/daos/profile_dao_test.dart` — DAO query tests
