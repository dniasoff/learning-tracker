# Story 19.10: Navigation & State Cleanup

> ⚠️ **Status — 2026-07-13 (AUD-docs-06):** sprint-status.yaml previously marked this story `done`; it is not. Re-verified against the live tree:
> - **AC-1/AC-2 (deprecated screen deletion + AuthGuard redirect) — premise is now WRONG, not just unimplemented.** `mode_selection_screen.dart` and `account_creation_screen.dart` are gone, but `AppIntroScreen` (`lib/features/onboarding/presentation/screens/app_intro_screen.dart`) is still live and is the app's `initial: true` route (`/intro` in `app_router.dart`) — the opposite of AC-1's premise that it's "no longer reachable." Onboarding evolved differently than this story anticipated.
> - **AC-4 (delete `TextDownloadService` / `TextDownloadStatusDao` / `TextDownloadStatuses` table / `cloud_content_providers.dart`) — confirmed still NOT done.** All four still exist (`lib/features/content_browsing/data/services/text_download_service.dart`, `lib/core/database/daos/text_download_status_dao.dart`, `TextDownloadStatuses` table in `user_database.dart` schemaVersion 35, `lib/features/content_browsing/presentation/providers/cloud_content_providers.dart`) and are confirmed **dead** — zero consumers of `cloudContentServiceProvider`, `contentDownloadStatusDaoProvider`, or `isTextDownloadedProvider` anywhere in `lib/` (grep-verified 2026-07-13). No legitimate retention justification was found; this is neglected cleanup, not an intentional keep. Deleting it requires a Drift schema migration (bump `schemaVersion`, drop table) — out of scope for this docs-accuracy pass; tracked as outstanding.
> - Given AC-1/AC-2's premise is obsolete and AC-4 is a real, still-valid outstanding cleanup, this story is **not** `done`. `sprint-status.yaml`'s `19-10-navigation-state-cleanup` entry is corrected to `in-progress` to match.

Status: in-progress

## Story

As a developer,
I want deprecated screens, dead services, orphaned database tables, stale route guards, and unused SharedPreferences keys removed after the Epic 18/19 overhaul,
so that the codebase contains no dead code, navigation is minimal and correct, and new contributors are not confused by vestigial artifacts.

Incorporates DNI-172 (dead code sweep for download-related services and DAOs).

## Acceptance Criteria

**AC-1: Deprecated screens deleted**
**Given** ModeSelectionScreen, AppIntroScreen, and the standalone AccountCreationScreen are no longer reachable after the Epic 18/19 navigation changes
**When** inspecting the codebase
**Then** `mode_selection_screen.dart`, `app_intro_screen.dart`, and `account_creation_screen.dart` are deleted
**And** their route entries (`/mode-selection`, `/intro`, `/create-account`) are removed from `app_router.dart`
**And** all imports referencing deleted files are removed

**AC-2: AuthGuard redirect updated**
**Given** AppIntroScreen no longer exists
**When** an unauthenticated user hits a guarded route
**Then** `AuthGuard` redirects to `WelcomeRoute` instead of the deleted `AppIntroRoute`
**And** all other code paths that referenced `AppIntroRoute` are updated to `WelcomeRoute`

**AC-3: SharedPreferences cleanup**
**Given** the slim onboarding (Epic 18.2) uses only 5 keys
**When** reviewing SharedPreferences usage
**Then** no stale keys from removed phases remain in the codebase
**And** a one-time migration clears any stale keys for existing users upgrading

**AC-4: TextDownloadService and related DAOs removed (DNI-172)**
**Given** text download is no longer triggered from the client (content is bundled or cloud-served)
**When** inspecting the codebase
**Then** `TextDownloadService` is deleted
**And** `TextDownloadStatusDao` and its table `TextDownloadStatuses` are removed from the database
**And** `ContentDownloadStatusDao` and its table `ContentDownloadStatuses` are removed from the database
**And** the `cloud_content_providers.dart` provider file is deleted
**And** the unused import of `TextDownloadService` in `text_display_providers.dart` is removed
**And** a Drift schema migration drops the two removed tables

**AC-5: Test files for deleted code removed or updated**
**Given** screens, services, and DAOs have been deleted
**When** running `make ci`
**Then** `mode_selection_screen_test.dart` is deleted
**And** `text_download_service_test.dart` is deleted
**And** `text_download_status_dao_test.dart` is deleted
**And** `auth_guard_test.dart` is updated to assert redirect to `WelcomeRoute`
**And** `epic_09_onboarding_test.dart` has no references to deleted screens
**And** `epic_02_content_test.dart` has no references to `TextDownloadService`
**And** all tests pass

**AC-6: Router codegen is clean**
**Given** routes have been removed and guards updated
**When** running `dart run build_runner build --delete-conflicting-outputs`
**Then** `app_router.gr.dart` regenerates without errors
**And** no generated code references deleted route pages

**AC-7: Database migration is correct**
**Given** two tables (`TextDownloadStatuses`, `ContentDownloadStatuses`) are removed
**When** an existing user upgrades
**Then** the Drift migration drops both tables without data loss to other tables
**And** the schema version is incremented
**And** a fresh install creates the database without the removed tables

## Tasks / Subtasks

### T1: Delete Deprecated Screens (AC: 1)

- [ ] Delete `lib/features/onboarding/presentation/screens/mode_selection_screen.dart`
- [ ] Delete `lib/features/onboarding/presentation/screens/app_intro_screen.dart`
- [ ] Delete `lib/features/onboarding/presentation/screens/account_creation_screen.dart`
- [ ] Remove route entries from `lib/core/navigation/app_router.dart`:
  - Line 81: `AutoRoute(path: '/intro', page: AppIntroRoute.page)` — delete
  - Line 84: `AutoRoute(path: '/create-account', page: AccountCreationRoute.page)` — delete
  - Line 85: `AutoRoute(path: '/mode-selection', page: ModeSelectionRoute.page)` — delete
- [ ] Remove the three corresponding import lines from `app_router.dart`:
  - Line 22: `import '…/account_creation_screen.dart'`
  - Line 23: `import '…/app_intro_screen.dart'`
  - Line 24: `import '…/mode_selection_screen.dart'`
- [ ] Remove `ModeSelectionRoute` reference from `account_creation_screen.dart` navigation (if the screen still has outbound navigation before deletion — verify)
- [ ] Remove `AccountCreationRoute` reference from:
  - `lib/features/onboarding/presentation/screens/welcome_screen.dart` (line 49) — replace with new onboarding entry point
  - `lib/features/auth/presentation/screens/sign_in_screen.dart` (line 552) — replace with new sign-up flow entry
- [ ] Remove `AppIntroRoute` reference from `settings_screen.dart` (lines 784, 848) — replace with `WelcomeRoute`

### T2: Update AuthGuard Redirect (AC: 2)

- [ ] Open `lib/core/navigation/guards/auth_guard.dart`
- [ ] Change line 30: `unawaited(router.replace(const AppIntroRoute()))` → `unawaited(router.replace(const WelcomeRoute()))`
- [ ] Update the import at the top if `AppIntroRoute` was the only reason for importing `app_router.dart` (it is still needed for `WelcomeRoute` since it is also generated)
- [ ] Open `lib/features/settings/presentation/screens/settings_screen.dart`:
  - Line 784: `await context.router.replaceAll([const AppIntroRoute()])` → `await context.router.replaceAll([const WelcomeRoute()])`
  - Line 848: same replacement
- [ ] Verify no other `.dart` files in `lib/` reference `AppIntroRoute` (grep confirmed: auth_guard.dart, settings_screen.dart, app_router.dart — all covered above)

### T3: SharedPreferences Cleanup (AC: 3)

- [ ] Audit all SharedPreferences keys in `onboarding_screen.dart`:
  - `_kOnboardingPhase` (line 52) — **keep** (used by slim onboarding)
  - `_kOnboardingProfileId` (line 53) — **keep**
  - `_kOnboardingProfileName` (line 54) — **keep**
  - `_kOnboardingProfileMode` (line 55) — **keep**
  - `_kOnboardingLanguage` (line 56) — **keep**
- [ ] Grep the entire `lib/` tree for any other `SharedPreferences` keys related to the old 17-phase wizard that are NOT in the keep list above:
  - `_kOnboardingSelectedCurricula` — if present anywhere (was removed in 18.2 but verify no lingering references)
  - Any key prefixed `onboarding_` that is not one of the 5 kept keys
- [ ] Write a one-time migration function in `onboarding_screen.dart` (or a dedicated migration helper):
  - On app start, check for stale keys (e.g., `onboarding_selected_curricula`) and remove them
  - Use a migration flag key like `_kOnboardingMigrationV2` to ensure it runs only once
  - Clear: `onboarding_selected_curricula`, any other stale keys found in the audit
- [ ] Verify the 5 kept keys are read/written consistently (no typos, no drift from old code)

### T4: Remove TextDownloadService (AC: 4, DNI-172)

- [ ] Delete `lib/features/content_browsing/data/services/text_download_service.dart`
- [ ] Remove the unused import of `TextDownloadService` from `lib/features/content_browsing/presentation/providers/text_display_providers.dart` (line 5)
  - Verify no provider in that file actually instantiates `TextDownloadService` (confirmed: it is an orphaned import)
- [ ] Grep for any other references to `TextDownloadService` in `lib/` — clean up all

### T5: Remove TextDownloadStatusDao and Table (AC: 4, 7, DNI-172)

- [ ] Delete `lib/core/database/daos/text_download_status_dao.dart`
- [ ] Delete `lib/core/database/daos/text_download_status_dao.g.dart` (generated)
- [ ] Delete `lib/core/database/tables/text_download_status.dart`
- [ ] Remove from `lib/core/database/app_database.dart`:
  - Table registration: `TextDownloadStatuses` (line 78 in tables list)
  - DAO registration: `TextDownloadStatusDao` (line 105 in daos list)
  - Import: `import '…/daos/text_download_status_dao.dart'` (line 24)
  - Import: `import '…/tables/text_download_status.dart'` (line 53)
- [ ] Grep for `textDownloadStatusDao` in `lib/` — remove any accessor usages

### T6: Remove ContentDownloadStatusDao and Table (AC: 4, 7, DNI-172)

- [ ] Delete `lib/core/database/daos/content_download_status_dao.dart`
- [ ] Delete `lib/core/database/daos/content_download_status_dao.g.dart` (generated)
- [ ] Delete `lib/core/database/tables/content_download_statuses.dart`
- [ ] Delete `lib/features/content_browsing/presentation/providers/cloud_content_providers.dart`
- [ ] Delete `lib/features/content_browsing/presentation/providers/cloud_content_providers.g.dart` (generated)
- [ ] Remove from `lib/core/database/app_database.dart`:
  - Table registration: `ContentDownloadStatuses` (line 79 in tables list)
  - DAO registration: `ContentDownloadStatusDao` (line 106 in daos list)
  - Import: `import '…/daos/content_download_status_dao.dart'` (line 6)
  - Import: `import '…/tables/content_download_statuses.dart'` (line 34)
- [ ] Grep for `contentDownloadStatusDao` in `lib/` — verify `cloud_content_providers.dart` was the only consumer (confirmed)
- [ ] Grep for `ContentDownloadStatusDao` and `ContentDownloadStatuses` in `lib/` — clean up all references

### T7: Drift Database Migration (AC: 7)

- [ ] Increment the schema version in `app_database.dart`
- [ ] Add a migration step that drops the two tables:
  ```dart
  // In the migration strategy:
  if (from < NEW_VERSION) {
    await m.deleteTable('text_download_statuses');
    await m.deleteTable('content_download_statuses');
  }
  ```
- [ ] Regenerate Drift code: `dart run build_runner build --delete-conflicting-outputs`
- [ ] Verify the generated `app_database.g.dart` no longer contains classes/mixins for the removed tables
- [ ] Test fresh database creation (no table creation for removed tables)
- [ ] Test upgrade from previous schema version (tables dropped, other data intact)
- [ ] Export new schema JSON for Drift schema testing (if schema test infrastructure exists)

### T8: Delete Test Files for Removed Code (AC: 5)

- [ ] Delete `test/features/onboarding/presentation/screens/mode_selection_screen_test.dart`
- [ ] Delete `test/features/content_browsing/data/services/text_download_service_test.dart`
- [ ] Delete `test/core/database/daos/text_download_status_dao_test.dart`
- [ ] Check for and delete any test for `ContentDownloadStatusDao` (grep: found reference in `epic_15_multi_profile_test.dart` — remove or update)
- [ ] Check for and delete any test for `cloud_content_providers` (grep if exists)

### T9: Update Remaining Test Files (AC: 5)

- [ ] Update `test/core/auth/auth_guard_test.dart`:
  - Change assertions from `AppIntroRoute` redirect to `WelcomeRoute` redirect
  - Update any mock setup that references `AppIntroRoute`
- [ ] Update `test/story_acceptance/epic_09_onboarding_test.dart`:
  - Remove any test groups or assertions referencing `ModeSelectionScreen`, `AppIntroScreen`, or `AccountCreationScreen`
  - Verify remaining onboarding tests align with slim 6-phase flow
- [ ] Update `test/story_acceptance/epic_02_content_test.dart`:
  - Remove any references to `TextDownloadService`
  - Update content download tests if they referenced the removed DAOs
- [ ] Update `test/story_acceptance/epic_15_multi_profile_test.dart`:
  - Remove any references to `ContentDownloadStatuses` or the removed DAOs
- [ ] Update `test/story_acceptance/epic_01_foundation_test.dart`:
  - Remove any `AuthGuard` tests that assert `AppIntroRoute` behavior (if present)
- [ ] Update `test/core/navigation/app_shell_test.dart`:
  - Remove references to `AppIntroRoute` if present
  - Update navigation assertions if they depend on deleted routes
- [ ] Update `test/features/onboarding/presentation/screens/account_creation_screen_test.dart` — **delete entirely** (screen is deleted)
- [ ] Update `test/features/onboarding/presentation/screens/welcome_screen_test.dart`:
  - Update navigation assertions: welcome should no longer push to `AccountCreationRoute`
  - Replace with whatever the new sign-up entry point is

### T10: Dead Code Sweep (AC: 1, 4)

- [ ] Run `dart analyze --fatal-infos` — fix all unused import warnings
- [ ] Grep for class names of all deleted files to catch any lingering references:
  - `ModeSelectionScreen`, `ModeSelectionRoute`
  - `AppIntroScreen`, `AppIntroRoute`
  - `AccountCreationScreen`, `AccountCreationRoute`
  - `TextDownloadService`, `TextDownloadProgress`, `TextDownloadState`
  - `TextDownloadStatusDao`, `TextDownloadStatuses`
  - `ContentDownloadStatusDao`, `ContentDownloadStatuses`
  - `contentDownloadStatusDaoProvider`, `cloudContentService`
- [ ] Check `docs/component-inventory.md` — remove entries for deleted screens/services
- [ ] Check `docs/source-tree-analysis.md` — remove entries for deleted files
- [ ] Verify no circular dependency issues after cleanup
- [ ] Run `dart run build_runner build --delete-conflicting-outputs` one final time
- [ ] Run `make ci` — all must pass

### T11: Router Codegen Verification (AC: 6)

- [ ] After all route changes, run `dart run build_runner build --delete-conflicting-outputs`
- [ ] Verify `app_router.gr.dart` no longer contains:
  - `AppIntroRoute` / `AppIntroPage`
  - `AccountCreationRoute` / `AccountCreationPage`
  - `ModeSelectionRoute` / `ModeSelectionPage`
- [ ] Verify all remaining routes resolve correctly (no broken references in generated code)
- [ ] Verify `routerProvider` in `router_provider.dart` still compiles (it uses `AuthGuard` which is kept but updated)

## Dev Notes

### Architecture

- **Dependencies:** Stories 18.1, 18.2, 18.3, and 18.7 must ALL be complete first. This story is the final cleanup pass.
- **This is a pure cleanup story** — no new features, only removing debt from the Epic 18/19 overhaul.
- **DNI-172 integration:** The dead download-related code (TextDownloadService, both download status DAOs/tables) was tracked as a separate Do-Not-Implement item and is consolidated here.

### Files to Delete

| File | Reason |
|------|--------|
| `lib/features/onboarding/presentation/screens/mode_selection_screen.dart` | Mode selection embedded in profile creation (18.2) |
| `lib/features/onboarding/presentation/screens/app_intro_screen.dart` | Replaced by WelcomeScreen as entry point |
| `lib/features/onboarding/presentation/screens/account_creation_screen.dart` | Account creation folded into onboarding flow |
| `lib/features/content_browsing/data/services/text_download_service.dart` | DNI-172: text download no longer client-triggered |
| `lib/core/database/daos/text_download_status_dao.dart` | DNI-172: orphaned after TextDownloadService removal |
| `lib/core/database/daos/text_download_status_dao.g.dart` | Generated code for removed DAO |
| `lib/core/database/tables/text_download_status.dart` | DNI-172: table definition for removed DAO |
| `lib/core/database/daos/content_download_status_dao.dart` | DNI-172: only consumer is deleted cloud_content_providers |
| `lib/core/database/daos/content_download_status_dao.g.dart` | Generated code for removed DAO |
| `lib/core/database/tables/content_download_statuses.dart` | DNI-172: table definition for removed DAO |
| `lib/features/content_browsing/presentation/providers/cloud_content_providers.dart` | DNI-172: only consumer of ContentDownloadStatusDao |
| `lib/features/content_browsing/presentation/providers/cloud_content_providers.g.dart` | Generated code for removed provider |
| `test/features/onboarding/presentation/screens/mode_selection_screen_test.dart` | Tests for deleted screen |
| `test/features/onboarding/presentation/screens/account_creation_screen_test.dart` | Tests for deleted screen |
| `test/features/content_browsing/data/services/text_download_service_test.dart` | Tests for deleted service |
| `test/core/database/daos/text_download_status_dao_test.dart` | Tests for deleted DAO |

### Files to Modify

| File | Action |
|------|--------|
| `lib/core/navigation/app_router.dart` | Remove 3 route entries + 3 imports |
| `lib/core/navigation/guards/auth_guard.dart` | Change redirect from `AppIntroRoute` to `WelcomeRoute` |
| `lib/core/database/app_database.dart` | Remove 2 tables, 2 DAOs, 4 imports; bump schema version; add migration |
| `lib/features/content_browsing/presentation/providers/text_display_providers.dart` | Remove orphaned `TextDownloadService` import (line 5) |
| `lib/features/settings/presentation/screens/settings_screen.dart` | Replace `AppIntroRoute` with `WelcomeRoute` (lines 784, 848) |
| `lib/features/onboarding/presentation/screens/welcome_screen.dart` | Update navigation from `AccountCreationRoute` to new entry point |
| `lib/features/auth/presentation/screens/sign_in_screen.dart` | Update navigation from `AccountCreationRoute` to new sign-up entry |
| `lib/features/onboarding/presentation/screens/onboarding_screen.dart` | Add one-time SharedPreferences migration |
| `test/core/auth/auth_guard_test.dart` | Update redirect assertion to `WelcomeRoute` |
| `test/core/navigation/app_shell_test.dart` | Remove `AppIntroRoute` references if present |
| `test/story_acceptance/epic_09_onboarding_test.dart` | Remove refs to deleted screens |
| `test/story_acceptance/epic_02_content_test.dart` | Remove `TextDownloadService` refs |
| `test/story_acceptance/epic_15_multi_profile_test.dart` | Remove `ContentDownloadStatuses` refs |
| `test/features/onboarding/presentation/screens/welcome_screen_test.dart` | Update navigation assertions |
| `docs/component-inventory.md` | Remove entries for deleted screens/services |

### Navigation Flow After Cleanup

```
Fresh install:
  WelcomeScreen → (sign up inline or SignInScreen) → OnboardingScreen
    → profileCreation → languageSelection → addTrack → addAnotherPrompt → handoff → Dashboard

Returning user (authenticated):
  → ProfilePickerScreen → Dashboard

Unauthenticated hit on guarded route:
  → AuthGuard redirects to WelcomeRoute (was AppIntroRoute)

Sign out:
  → SettingsScreen sign-out → WelcomeRoute (was AppIntroRoute)
```

### Database Migration Plan

Current schema includes two tables to be dropped:
- `text_download_statuses` — tracked Sefaria text downloads per curriculum
- `content_download_statuses` — tracked cloud content hierarchy downloads per curriculum + language

Both tables are safe to drop because:
1. `TextDownloadService` is the only writer and it is being deleted
2. `ContentDownloadStatusDao` is only consumed by `cloud_content_providers.dart` which is being deleted
3. The data in these tables is purely cache metadata — no user-generated data is lost
4. Content is now bundled with the app or served directly from cloud without local download tracking

Migration step:
```dart
if (from < N) {  // N = new schema version
  await m.deleteTable('text_download_statuses');
  await m.deleteTable('content_download_statuses');
}
```

### SharedPreferences Key Inventory

**Kept (used by slim onboarding):**
| Key | Purpose |
|-----|---------|
| `onboarding_phase` | Tracks current slim onboarding phase for resume |
| `onboarding_profile_id` | ID of profile created during onboarding |
| `onboarding_profile_name` | Display name entered during onboarding |
| `onboarding_profile_mode` | Adult/child mode selected |
| `onboarding_language` | Content language selected |

**Removed (stale from old 17-phase wizard):**
| Key | Reason |
|-----|--------|
| `onboarding_selected_curricula` | AddTrackFlow manages track selection now (18.1) |
| Any other `onboarding_*` keys from old phases | Superseded by slim onboarding (18.2) |

### AuthGuard Redirect Chain

Current (broken after this story without fix):
```
Unauthenticated → AuthGuard → AppIntroRoute (DELETED)
```

After fix:
```
Unauthenticated → AuthGuard → WelcomeRoute (exists, is the new entry point)
```

Files that reference `AppIntroRoute` in `lib/` (all must be updated):
1. `lib/core/navigation/app_router.dart` — route definition (delete)
2. `lib/core/navigation/guards/auth_guard.dart` — redirect target (change to WelcomeRoute)
3. `lib/features/settings/presentation/screens/settings_screen.dart` — sign-out destination (change to WelcomeRoute, lines 784 and 848)

### Critical Constraints

- **Database migration must be backward-compatible** — users upgrading from any previous version must not lose data in other tables when the two download status tables are dropped
- **Router codegen must be re-run** after route changes — `app_router.gr.dart` is generated by `auto_route_generator`
- **Drift codegen must be re-run** after table/DAO removal — `app_database.g.dart` and DAO `.g.dart` files are generated
- **No runtime references to deleted routes** — if any deep link or push notification handler references `/intro`, `/create-account`, or `/mode-selection`, those must be updated or removed
- **SharedPreferences migration must be idempotent** — safe to run multiple times without side effects

### Verification Checklist

```bash
# After all changes:
dart run build_runner build --delete-conflicting-outputs
dart analyze --fatal-infos
dart format --set-exit-if-changed .
make test-all-stories
make ci
```

### References

- [Source: Story 18.7 — prior cleanup story that this supersedes/extends]
- [Source: Story 18.2 — slim onboarding that removed old phases]
- [Source: Story 18.1 — AddTrackFlow that replaced curriculum selection in onboarding]
- [Source: DNI-172 — dead code sweep for download services]

## Dev Agent Record

### Agent Model Used

_Retroactively reconciled 2026-07-13 (AUD-docs-06) — no contemporaneous dev-agent record exists; sprint-status.yaml falsely showed `done` while this header still read the template default and the code confirms the story is genuinely incomplete (not just undocumented)._

### Debug Log References

### Completion Notes List

- AC-1/AC-2: partially done (2 of 3 deprecated screens deleted) but premise invalidated — `AppIntroScreen` was kept and is the live initial route, not deleted. Recommend re-scoping or closing this pair as superseded rather than re-attempting the original deletion.
- AC-3: not independently re-verified in this pass (out of scope for AUD-docs-06, which targeted the sprint-status.yaml drift and AC-4 specifically).
- AC-4: confirmed still outstanding — see status banner above. Recommend a follow-up story/finding to perform the Drift migration and delete the 4 dead-code artifacts, rather than folding a schema migration into this docs-accuracy pass.
- AC-5/AC-6/AC-7: not independently re-verified (downstream of AC-4; moot until AC-4 lands).

### File List

- `learning_tracker/lib/features/onboarding/presentation/screens/app_intro_screen.dart` (still live — AC-1 premise wrong)
- `learning_tracker/lib/features/content_browsing/data/services/text_download_service.dart` (still present — AC-4 outstanding)
- `learning_tracker/lib/core/database/daos/text_download_status_dao.dart` (still present — AC-4 outstanding)
- `learning_tracker/lib/features/content_browsing/presentation/providers/cloud_content_providers.dart` (still present — AC-4 outstanding)
