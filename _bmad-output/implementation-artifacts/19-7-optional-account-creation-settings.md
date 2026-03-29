# Story 19.7: Optional Account Creation in Settings (Magic Link Auth)

Status: ready-for-dev

## Story

As a local-only learner,
I want to optionally create a cloud account from Settings using a magic link (no password),
so that I can back up and sync my data without being forced to create an account during onboarding.

## Context & Dependencies

This story implements Phase 6 of the local-first auth abstraction layer (see `_bmad-output/planning-artifacts/local-first-auth-abstraction-layer.md`). It assumes the following prior stories are complete:

- **19.5**: Auth abstraction (`localUid`, nullable `firebaseUid`, `hasAccount` columns on `UserProfiles`)
- **19.8**: `SyncEngine` conditional activation (dormant by default, activates on account link)

**Pre-requisites from Epic 18:**
- **18.13 (DNI-164)**: Account creation screen layout fix — already done before this story
- **18.14 (DNI-165)**: Magic link authentication (no passwords) — already done before this story

This story focuses on **relocating** the existing (already magic-link-enabled) account creation screen to Settings and wiring up UID migration + initial sync. It does NOT implement the auth mechanism itself.

### What This Story Does NOT Do

- Implement magic link auth (done in 18.14 / DNI-165)
- Fix account creation screen layout (done in 18.13 / DNI-164)
- Remove account creation from onboarding flow (done in 19.5)

## Acceptance Criteria

**AC-1: "Backup & Sync" section appears in Settings for local-only users**
**Given** the user has no cloud account (`hasAccount == false`)
**When** they open Settings
**Then** a "BACKUP & SYNC" section is displayed between "DATA & PRIVACY" and "ACCOUNT"
**And** it contains a card with:
  - An icon (cloud_upload_outlined) and title "Back Up Your Data"
  - Subtitle "Create a free account to sync across devices"
  - A prominent "Create Account" button
  - A secondary "Already have an account? Sign In" link

**AC-2: "Backup & Sync" section shows sync status for cloud users**
**Given** the user has a cloud account (`hasAccount == true`)
**When** they open Settings
**Then** the "BACKUP & SYNC" section shows:
  - Email address associated with the account
  - Sync status indicator (synced/syncing/error)
  - "Last synced: [relative time]" subtitle
  - Navigation chevron to existing SyncRoute for details

**AC-3: Magic link email is sent successfully**
**Given** the user taps "Create Account" from the Backup & Sync section
**When** they enter a valid email address and tap "Send Magic Link"
**Then** `AuthRepository.sendSignInLinkToEmail(email)` is called
**And** the email is persisted to SharedPreferences (key: `pending_magic_link_email`)
**And** a confirmation screen is shown: "Check your email! We sent a sign-in link to [email]"
**And** the screen includes a "Resend" button (disabled for 30 seconds after send)
**And** the screen includes an "Open Email App" button (uses `url_launcher` `mailto:`)
**And** the screen includes a "Use a different email" back link

**AC-4: Magic link deep link completes authentication**
**Given** the user taps the magic link from their email
**When** the app receives the deep link
**Then** `AuthRepository.isSignInWithEmailLink(link)` returns `true`
**And** the stored email is retrieved from SharedPreferences (`pending_magic_link_email`)
**And** `AuthRepository.signInWithEmailLink(email, link)` completes successfully
**And** the UID migration runs (AC-6)
**And** the pending email is cleared from SharedPreferences
**And** the user is returned to Settings with a success snackbar

**AC-5: Google Sign-In alternative works from Settings**
**Given** the user taps "Sign in with Google" on the account creation screen
**When** Google authentication completes
**Then** the UID migration runs (AC-6)
**And** the user is returned to Settings with a success snackbar
**And** `GoogleSignIn.instance.initialize()` is called lazily on first tap (DNI-164)

**AC-6: UID migration links local profile to Firebase account**
**Given** authentication (magic link or Google) completes with a Firebase `User`
**When** the migration runs
**Then** `UserProfiles` row is updated in a single DB transaction:
  - `firebaseUid` is set to the Firebase UID
  - `hasAccount` is set to `true`
  - `localUid` is unchanged
**And** `AuthStateNotifier.promoteToCloud(firebaseUser)` is called
**And** state transitions from `LocalAuthState` to `CloudAuthState`
**And** all providers watching `authStateNotifierProvider` rebuild

**AC-7: Initial full data sync push runs after account creation**
**Given** the UID migration completes (AC-6)
**When** the `SyncEngine` activates (via `syncEngineProvider` rebuild)
**Then** `pullOnLaunch()` runs first (returns empty — new remote)
**And** `pushAllLocalData()` pushes all local data to Firestore under `users/{firebaseUid}/...`
**And** a progress indicator is shown during the push ("Syncing your data... X%")
**And** the user can dismiss the progress and continue using the app (sync continues in background)
**And** on completion, a snackbar confirms "All data synced successfully"

**AC-8: ACCOUNT section adapts to cloud vs local state**
**Given** the user has no cloud account
**When** they view the ACCOUNT section in Settings
**Then** "Sign Out", "Delete Account", "Change Password", and "Link Account" tiles are hidden
**And** only "User Mode" is shown
**Given** the user has a cloud account
**When** they view the ACCOUNT section
**Then** all existing account management tiles are visible (Sign Out, Delete Account, etc.)

**AC-9: Error handling covers network failures gracefully**
**Given** the user attempts account creation without internet
**When** the magic link send or Google Sign-In fails
**Then** a user-friendly error is shown: "Account creation requires an internet connection. Your data is safe locally — try again when you're online."
**And** no local data is modified
**And** the user remains on the account creation screen

**AC-10: "Already have an account? Sign In" navigates to existing SignInScreen**
**Given** the user taps "Already have an account? Sign In"
**When** the navigation completes
**Then** the existing `SignInScreen` is pushed onto the nav stack
**And** successful sign-in from there also triggers UID migration (AC-6) and initial sync (AC-7)
**And** after sign-in, the user is returned to Settings (not onboarding)

## Tasks / Subtasks

### T1: Add "Backup & Sync" Section to SettingsScreen (AC: 1, 2, 8)

- [ ] Create `_BackupSyncSection` widget in `settings_screen.dart`:
  - Watches `authStateNotifierProvider` to determine local vs cloud state
  - **Local-only state** renders:
    - `_SectionHeader(title: 'BACKUP & SYNC')`
    - Card with `cloud_upload_outlined` icon, "Back Up Your Data" title
    - "Create a free account to sync across devices" subtitle
    - `FilledButton` "Create Account" — navigates to `MagicLinkAccountRoute`
    - `TextButton` "Already have an account? Sign In" — navigates to `SignInRoute`
  - **Cloud state** renders:
    - `_SectionHeader(title: 'BACKUP & SYNC')`
    - Card with sync status tile showing email, last sync time, status icon
    - `onTap` navigates to existing `SyncRoute`
- [ ] Insert `_BackupSyncSection` into `SettingsScreen.build()` ListView between "DATA & PRIVACY" and "ACCOUNT" sections
- [ ] Conditionally hide "Sign Out", "Delete Account", "Change Password", "Link Account" tiles when `authState.hasCloudAccount == false`
  - Refactor `_UserProfileSection` to read from `authStateNotifierProvider` instead of `firebaseAuthProvider`
  - When local-only: show display name from local `UserProfiles`, hide email, show "LOCAL" badge instead of "SELF-LEARNER"
- [ ] Conditionally show account management tiles only when `authState.hasCloudAccount == true`

### T2: Create MagicLinkAccountScreen (AC: 3, 9)

- [ ] Create new route `MagicLinkAccountRoute` / `MagicLinkAccountScreen` at:
  `lib/features/settings/presentation/screens/magic_link_account_screen.dart`
- [ ] Screen layout (ConsumerStatefulWidget):
  - AppBar with "Create Account" title and back button
  - Descriptive text: "Enter your email to create an account. We'll send you a magic link — no password needed!"
  - Email `TextFormField` with validation (reuse `validators.validateEmail`)
  - `FilledButton` "Send Magic Link" (full width)
  - OR divider
  - `OutlinedButton.icon` "Continue with Google" (Google icon)
  - Terms of Service / Privacy Policy checkbox (reuse from `AccountCreationScreen`)
  - "Already have an account? Sign In" link
- [ ] `_sendMagicLink()` method:
  ```
  1. Validate email
  2. Check terms accepted
  3. Set loading state
  4. Call ref.read(authRepositoryProvider).sendSignInLinkToEmail(email)
  5. Store email in SharedPreferences: key 'pending_magic_link_email'
  6. Navigate to MagicLinkSentScreen (pass email)
  7. On error: show user-friendly message per AC-9
  ```
- [ ] `_signInWithGoogle()` method:
  ```
  1. Check terms accepted
  2. Set loading state
  3. Call ref.read(authRepositoryProvider).signInWithGoogle()
  4. On success: run UID migration (call _migrateAndSync)
  5. On error: show user-friendly message per AC-9
  ```
- [ ] Extract `_migrateAndSync(User firebaseUser)` helper:
  ```
  1. Call ref.read(uidMigrationServiceProvider).migrateToCloudAccount(firebaseUser.uid)
  2. Call ref.read(authStateNotifierProvider.notifier).promoteToCloud(firebaseUser)
  3. Navigate back to SettingsScreen
  4. Show success snackbar: "Account created! Syncing your data..."
  ```

### T3: Create MagicLinkSentScreen (AC: 3)

- [ ] Create `MagicLinkSentScreen` at:
  `lib/features/settings/presentation/screens/magic_link_sent_screen.dart`
- [ ] Screen layout (ConsumerStatefulWidget):
  - Centered content with email icon/illustration
  - "Check your email!" title
  - "We sent a sign-in link to [email]" body text
  - "Open Email App" button — launches `mailto:` via `url_launcher`
  - "Resend" button:
    - Disabled for 30 seconds after each send (countdown timer shown: "Resend in 25s")
    - Uses `Timer.periodic` with 1-second ticks
    - Calls `sendSignInLinkToEmail` again on tap
  - "Use a different email" `TextButton` — pops back to MagicLinkAccountScreen
- [ ] Dispose timer in `dispose()`
- [ ] Handle case where user returns to app without tapping link — screen remains, user can resend or go back

### T4: Handle Magic Link Deep Link Reception (AC: 4)

- [ ] Create or update deep link handler to intercept Firebase email link:
  - In `lib/features/auth/presentation/providers/` or a new `magic_link_handler.dart`
  - Listen for incoming deep links using `FirebaseDynamicLinks` or `uni_links` package (whichever is already in use)
  - When link received:
    ```
    1. Check: authRepo.isSignInWithEmailLink(link)
    2. Read stored email from SharedPreferences ('pending_magic_link_email')
    3. If email is null: show error "Session expired, please try again"
    4. Call authRepo.signInWithEmailLink(email, link)
    5. On success: clear 'pending_magic_link_email' from SharedPreferences
    6. Run _migrateAndSync(firebaseUser)
    7. Navigate to SettingsScreen with success feedback
    ```
- [ ] Handle edge cases:
  - App was killed between sending link and receiving it (cold start with deep link)
  - Email was stored but link is for a different email (should not happen with magic link, but guard)
  - Link expired (Firebase magic links expire after a configurable duration — show "Link expired, please request a new one")
- [ ] Register the deep link scheme in `AndroidManifest.xml` and `Info.plist` if not already configured:
  - The `ActionCodeSettings` in `auth_repository_impl.dart` already configures:
    - `url: 'https://torah-study-tracker.firebaseapp.com/sign-in'`
    - `handleCodeInApp: true`
    - `androidPackageName: 'com.jcom.torah.learning_tracker'`
  - Verify these match the Firebase Dynamic Links configuration

### T5: Create UidMigrationService (AC: 6)

- [ ] Create `UidMigrationService` at:
  `lib/features/auth/domain/services/uid_migration_service.dart`
- [ ] Riverpod provider: `uidMigrationServiceProvider`
- [ ] Core method:
  ```dart
  Future<void> migrateToCloudAccount(String firebaseUid) async {
    await _database.transaction(() async {
      final localUid = _prefs.getString('local_device_uid')!;
      final userProfile = await _database.userProfileDao
          .getUserProfileByLocalUid(localUid);

      if (userProfile == null) {
        throw StateError('No local profile found for UID migration');
      }

      if (userProfile.hasAccount) {
        _logger.warning('Profile already linked to cloud account, skipping migration');
        return; // Idempotent — already migrated
      }

      await _database.userProfileDao.linkFirebaseAccount(
        id: userProfile.id,
        firebaseUid: firebaseUid,
      );
    });
  }
  ```
- [ ] Add `getUserProfileByLocalUid(String localUid)` method to `UserProfileDao` if not already present from Story 19.1
- [ ] Add `linkFirebaseAccount({required int id, required String firebaseUid})` method to `UserProfileDao`:
  ```dart
  Future<void> linkFirebaseAccount({required int id, required String firebaseUid}) {
    return (update(userProfiles)..where((t) => t.id.equals(id)))
      .write(UserProfilesCompanion(
        firebaseUid: Value(firebaseUid),
        hasAccount: const Value(true),
        updatedAt: Value(DateTime.now()),
      ));
  }
  ```
- [ ] Dependencies: `AppDatabase`, `SharedPreferences`, `Talker` (logger)
- [ ] This service is intentionally minimal — it only touches `UserProfiles`. No other table needs UID migration (see table audit in auth abstraction layer doc, section 5.3)

### T6: Implement pushAllLocalData on SyncEngine (AC: 7)

- [ ] Add `pushAllLocalData()` method to `SyncEngine`:
  ```
  1. Read all local data for the current profile(s):
     - Completions
     - Bookmarks
     - Streaks
     - Goals
     - Rewards / RewardPools / RewardPoolItems
     - ActiveCurricula / CurriculumScopes / CurriculumTracks
     - StageDefinitions
     - PointConfigs
     - StudyDayConfigs
     - LearningOrder
     - TestScores
     - ProfilePrograms
  2. For each collection, batch-write to Firestore under users/{firebaseUid}/profiles/{profileId}/...
  3. Report progress via a Stream<SyncProgress> or callback:
     - SyncProgress { int completedCollections, int totalCollections, String currentCollection }
  4. Log each collection push with talker
  5. Handle partial failures gracefully — retry failed collections, don't abort entire push
  ```
- [ ] This method is called automatically by `syncEngineProvider` when it initializes after `promoteToCloud()` triggers a rebuild
- [ ] Distinguish "first link" from "returning sign-in" by checking if Firestore `users/{uid}` document exists:
  - If no remote user doc: this is first link — push all local data
  - If remote user doc exists: this is returning sign-in — run normal `pullOnLaunch()` (merge handled by future story per DNI-165)

### T7: Create SyncProgressIndicator Widget (AC: 7)

- [ ] Create `SyncProgressIndicator` widget at:
  `lib/features/settings/presentation/widgets/sync_progress_indicator.dart`
- [ ] Shows during initial full sync push:
  - Animated progress bar or circular indicator
  - "Syncing your data..." label
  - Collection name being synced (e.g., "Syncing completions...")
  - Percentage or fraction (e.g., "3 of 12 collections")
  - "Dismiss" button — hides the indicator but sync continues in background
- [ ] Displayed as a persistent bottom sheet or banner on SettingsScreen after account creation
- [ ] Watches a `syncProgressProvider` that emits `SyncProgress` states
- [ ] On completion: auto-dismiss after 2 seconds, show snackbar "All data synced successfully"
- [ ] On error: show "Some data couldn't sync. It will retry automatically." with option to view details

### T8: Register New Routes (AC: 1, 3, 4)

- [ ] Add to `AppRouter`:
  - `MagicLinkAccountRoute` → `MagicLinkAccountScreen`
  - `MagicLinkSentRoute` → `MagicLinkSentScreen`
- [ ] Both routes should be unguarded (no `localAuthGuard` needed — user already has local profile)
- [ ] Update `app_router.dart` with `AutoRoute` entries
- [ ] Run `dart run build_runner build --delete-conflicting-outputs` to generate route code

### T9: Adapt Existing SignInScreen for Settings Context (AC: 10)

- [ ] The existing `SignInScreen` currently navigates to onboarding/dashboard after sign-in
- [ ] Add a `fromSettings` parameter (optional boolean, default false):
  - When `true`: after successful sign-in, run UID migration + sync, then pop back to Settings
  - When `false`: preserve existing behavior (navigate to onboarding/dashboard)
- [ ] Update `SignInRoute` to accept this parameter
- [ ] In `_BackupSyncSection`, navigate with: `context.pushRoute(SignInRoute(fromSettings: true))`
- [ ] After sign-in success in Settings mode:
  ```
  1. Get firebaseUser from FirebaseAuth.instance.currentUser
  2. Call uidMigrationService.migrateToCloudAccount(firebaseUser.uid)
  3. Call authStateNotifier.promoteToCloud(firebaseUser)
  4. Pop back to Settings
  5. Show success snackbar
  ```

### T10: Tests (AC: 1-10)

- [ ] **Unit tests for UidMigrationService:**
  - Test: migration sets `firebaseUid` and `hasAccount = true` on correct row
  - Test: `localUid` is unchanged after migration
  - Test: migration is idempotent (calling twice does not error or double-write)
  - Test: throws `StateError` if no local profile found
  - Test: migration runs within a single DB transaction (verify rollback on failure)

- [ ] **Unit tests for MagicLinkAccountScreen logic:**
  - Test: email validation rejects invalid emails
  - Test: terms checkbox must be checked before send
  - Test: `sendSignInLinkToEmail` called with correct email
  - Test: email stored in SharedPreferences after successful send
  - Test: navigation to MagicLinkSentScreen on success
  - Test: error shown on network failure

- [ ] **Unit tests for deep link handler:**
  - Test: `isSignInWithEmailLink` returns true for valid links
  - Test: stored email retrieved and used for `signInWithEmailLink`
  - Test: pending email cleared from SharedPreferences after success
  - Test: error shown if no stored email found
  - Test: error shown if link is expired

- [ ] **Unit tests for pushAllLocalData:**
  - Test: all collection types are pushed to Firestore
  - Test: progress is reported for each collection
  - Test: partial failures are retried, not fatal
  - Test: first-link detection works (no remote doc = push, remote doc exists = pull)

- [ ] **Widget tests for _BackupSyncSection:**
  - Test: local-only state shows "Create Account" card
  - Test: cloud state shows email and sync status
  - Test: "Create Account" button navigates to MagicLinkAccountRoute
  - Test: "Already have an account?" link navigates to SignInRoute

- [ ] **Widget tests for MagicLinkSentScreen:**
  - Test: resend button is disabled for 30 seconds
  - Test: countdown timer decrements correctly
  - Test: resend button re-enables after 30 seconds
  - Test: "Use a different email" pops navigation

- [ ] **Widget tests for SyncProgressIndicator:**
  - Test: progress bar updates with collection count
  - Test: dismiss button hides indicator
  - Test: completion auto-dismisses after 2 seconds

- [ ] **Widget tests for SettingsScreen ACCOUNT section:**
  - Test: local-only user sees only "User Mode" tile, no Sign Out/Delete/Change Password
  - Test: cloud user sees all account management tiles

- [ ] **Integration test:**
  - Test: full flow — enter email, mock magic link, complete auth, verify UID migration, verify sync triggered
  - Test: full flow — Google sign-in from Settings, verify migration and sync

## Dev Notes

### Architecture

- **Dependencies:** Stories 19.1 (DB schema), 19.2 (AuthStateNotifier), 19.5 (SyncEngine conditional)
- **No password flow.** This story deliberately uses magic link (email link) as the primary auth method. The existing password-based `AccountCreationScreen` is NOT reused — it will be deprecated in a future story. Magic link is simpler, more secure, and avoids password UX complexity.
- **Google Sign-In as alternative.** Google is the only OAuth provider offered alongside magic link. Apple Sign-In can be added in a future story.

### Current Auth Repository Methods Already Available

The `AuthRepository` interface already has the magic link methods:
- `sendSignInLinkToEmail(String email)` — sends the email link
- `signInWithEmailLink(String email, String emailLink)` — completes sign-in
- `isSignInWithEmailLink(String link)` — validates a deep link

The `AuthRepositoryImpl` already implements these using Firebase. No changes needed to the auth layer.

### Current ActionCodeSettings Configuration

In `auth_repository_impl.dart` line 53-60:
```dart
ActionCodeSettings(
  url: 'https://torah-study-tracker.firebaseapp.com/sign-in',
  handleCodeInApp: true,
  androidPackageName: _packageName,  // 'com.jcom.torah.learning_tracker'
  androidInstallApp: true,
)
```

Verify that Firebase Dynamic Links are configured in the Firebase Console for this URL pattern. If not, this is a prerequisite setup step.

### UID Migration Is Trivially Simple

Per the auth abstraction layer document section 5.3 (Table Audit), the **entire schema chains through integer PKs**, not UIDs. The only table that stores `firebaseUid` is `UserProfiles`. The migration is a single UPDATE on one row. No cascading changes to `Profiles`, `Completions`, `Bookmarks`, or any other table.

### Settings Screen Current Layout

The current sections in order:
1. User Profile (avatar, name, email, badge)
2. LEARNING (Curricula, Manage Tracks, Goals, Study Days, Daily Reminder)
3. APPEARANCE (Theme, Accent Color)
4. NOTIFICATIONS (Notification Settings, Streak Alerts)
5. DATA & PRIVACY (Cloud Sync, Export Data)
6. ACCOUNT (User Mode, Change Password, Link Account, Sign Out, Delete Account)
7. App Version footer

The new "BACKUP & SYNC" section inserts between (5) and (6). The existing "Cloud Sync" tile in DATA & PRIVACY can be removed or consolidated into the new section to avoid redundancy.

### Key Files

| File | Action |
|------|--------|
| `lib/features/settings/presentation/screens/settings_screen.dart` | Modify — add `_BackupSyncSection`, conditionally hide account tiles |
| `lib/features/settings/presentation/screens/magic_link_account_screen.dart` | **New** — magic link email entry + Google Sign-In |
| `lib/features/settings/presentation/screens/magic_link_sent_screen.dart` | **New** — confirmation + resend + open email |
| `lib/features/settings/presentation/widgets/sync_progress_indicator.dart` | **New** — initial sync progress UI |
| `lib/features/auth/domain/services/uid_migration_service.dart` | **New** — UID migration transaction |
| `lib/features/auth/presentation/providers/magic_link_handler.dart` | **New** or modify existing deep link handler |
| `lib/core/navigation/app_router.dart` | Modify — register new routes |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | No changes — magic link methods already exist |
| `lib/features/auth/domain/repositories/auth_repository.dart` | No changes — magic link interface already defined |
| `lib/core/database/daos/user_profile_dao.dart` | Modify — add `getUserProfileByLocalUid`, `linkFirebaseAccount` |
| `lib/features/sync/data/sync_engine.dart` | Modify — add `pushAllLocalData()` method |
| `lib/features/onboarding/presentation/screens/account_creation_screen.dart` | No changes this story (deprecated in future story) |

### Edge Cases

1. **User taps magic link on a different device** — Firebase will still authenticate, but the local profile on the other device has a different `localUid`. The migration on the originating device works. The other device would need to sign in separately (DNI-165).
2. **User force-kills app between sending link and tapping it** — SharedPreferences persists the pending email. On cold start with deep link, the handler reads the stored email and completes sign-in.
3. **Duplicate Firebase UID** — if `firebaseUid` UNIQUE constraint conflicts (shouldn't happen for new accounts), surface a clear error: "This account is already linked to another profile."
4. **Sync fails mid-push** — partial data in Firestore is acceptable. The next app launch will run `pullOnLaunch()` which reconciles. Failed collections are retried.
5. **User navigates away from MagicLinkSentScreen** — the deep link handler is global, so it will catch the link regardless of current screen. Navigation to Settings + success feedback still works.

### Critical Constraints

- **No password fields.** The magic link flow intentionally has zero password fields. This is the core UX improvement over the current `AccountCreationScreen`.
- **No onboarding navigation.** After account creation from Settings, the user stays in Settings. Never redirect to onboarding or mode selection — the user already has a complete local profile.
- **Idempotent migration.** `migrateToCloudAccount()` must be safe to call multiple times (e.g., if the app crashes mid-flow and retries). Check `hasAccount` before writing.
- **Offline queue stays disabled for local-only users.** This story does not change that. The queue only activates after `promoteToCloud()` causes `SyncEngine` to initialize.

### References

- [Source: `_bmad-output/planning-artifacts/local-first-auth-abstraction-layer.md` — Sections 5 (UID Migration), 6 (SyncEngine Conditional Activation), 7.4 (Where "Create Account" Moves)]
- [Source: `_bmad-output/planning-artifacts/offline-first-analysis-2026-03-27.md` — Local-first architecture]
- [Source: Firebase Auth — Email Link Authentication docs]

## Dev Agent Record

### Agent Model Used

_To be filled during implementation_

### Debug Log References

### Completion Notes List

### File List

