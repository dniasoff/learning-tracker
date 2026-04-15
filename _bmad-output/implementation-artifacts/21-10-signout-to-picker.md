# Story 21.10: Sign-Out Routes to Account Picker

Status: done

## Story

As a user signing out,
I want to see my other accounts instead of the welcome screen,
so that signing out means "switch account" not "leave the app".

## Acceptance Criteria (ACs)

1. **Given** the user is signed into Account A and Account B also exists on device
   **When** the user taps Sign Out in Settings
   **Then** the account picker is shown (not the welcome screen) with Account B available

2. **Given** the user is signed into the ONLY account on the device
   **When** the user taps Sign Out
   **Then** the welcome screen is shown

3. **Given** the user signs out of a cloud-born account
   **When** sign-out completes
   **Then** `FirebaseAuth.instance.currentUser` is null (token cleared for that account)

4. **Given** the user signs out and the picker is shown
   **When** the user taps Account B
   **Then** Account B's session starts normally

5. **Given** the welcome screen is shown (zero accounts)
   **When** the user creates a new account
   **Then** normal signup flow runs (connectivity-aware, as in 21.5)

## Tasks / Subtasks

- [ ] Modify `settings_screen.dart` sign-out handler (AC: 1,2,3)
  - [ ] Call `AuthStateNotifier.signOut()`
  - [ ] Clear `SharedPreferences['last_active_account_id']`
  - [ ] For cloud-born: call `FirebaseAuth.instance.signOut()` to invalidate cached token
  - [ ] Read registry count: `ref.read(deviceAccountsProvider).length`
  - [ ] If count > 0 → `context.router.replaceAll([AccountPickerRoute()])`
  - [ ] If count == 0 → `context.router.replaceAll([WelcomeRoute()])`
- [ ] Update `AuthGuard` to check registry (AC: 5)
  - [ ] If `kOnboardingComplete` is false AND registry is empty → WelcomeRoute
  - [ ] If `kOnboardingComplete` is false AND registry has accounts → AccountPickerRoute
- [ ] Verify the welcome screen only appears when zero accounts exist
- [ ] Write test: sign-out with 2 accounts → picker shown
- [ ] Write test: sign-out with 1 account → welcome shown

## Dev Notes

### Files to modify
- `lib/features/settings/presentation/screens/settings_screen.dart` — sign-out handler (currently at line ~941: `ref.read(authStateProvider.notifier).demoteToLocal()`)
- `lib/core/navigation/guards/auth_guard.dart` — add registry count check
- `lib/core/navigation/router_provider.dart` — may need to pass registry reference to guard

### Key insight: `FirebaseAuth.instance.signOut()` only clears the CURRENT user's token
Firebase SDK only tracks one "current user" at a time. When we call `signOut()`, it clears only that user's cached session. Other cloud-born accounts in the registry retain their tokens — those tokens are stored by Firebase internally per-UID, and `signInWithEmailAndPassword` for a different user doesn't invalidate the previous one's refresh token. However, `FirebaseAuth.instance.currentUser` will return the last signed-in user, so after signing out, the next sign-in (from picker or fresh) sets a new `currentUser`.

### Testing
- Widget test for settings_screen sign-out button
- Unit test for AuthGuard registry-aware routing
- Integration test: sign-out → picker → tap account → dashboard

### Guardrails
- NEVER delete the account from the registry on sign-out — sign-out ≠ delete
- NEVER close the account's DB file on sign-out if other code might still reference it — let the provider disposal handle it
- The `replaceAll` navigation must clear the entire stack, not just push

### References
- [Source: lib/features/settings/presentation/screens/settings_screen.dart:941] — current sign-out
- [Source: lib/core/navigation/guards/auth_guard.dart] — onboarding guard
- [Source: lib/features/auth/presentation/providers/auth_state_provider.dart:80] — signOut()

## Dev Agent Record

### Agent Model Used
### Completion Notes List
### Change Log
