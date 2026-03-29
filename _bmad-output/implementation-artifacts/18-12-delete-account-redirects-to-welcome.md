# Story 18.12: Delete Account Redirects to Welcome (DNI-178)

Status: review

## Story

As a user,
I want to land on the Welcome screen after deleting my account,
so that I can create a new account or sign in with a different one without sitting through the intro carousel again.

## Acceptance Criteria

**AC-1: Delete account navigates to Welcome screen**
**Given** the user initiates account deletion from Settings
**When** they complete the full deletion flow (re-auth, type DELETE, confirm)
**Then** the app navigates to the Welcome screen (`WelcomeRoute`), NOT the AppIntro carousel

**AC-2: Welcome screen offers appropriate options**
**Given** the user has just deleted their account and landed on Welcome
**Then** they see "Get Started" (create new account) and "Already have an account? Sign in"

**AC-3: Back navigation is blocked**
**Given** the user landed on Welcome after account deletion
**When** they press the system back button
**Then** they cannot navigate back to Settings (because `replaceAll` cleared the stack)

**AC-4: No residual auth state**
**Given** the account has been deleted
**When** the app checks `FirebaseAuth.currentUser`
**Then** it returns `null`

## Tasks / Subtasks

### T1: Fix Post-Deletion Navigation (AC: 1)

- [x] Change line 848 in `settings_screen.dart` from `AppIntroRoute()` to `WelcomeRoute()`
- [x] One-line fix: `await context.router.replaceAll([const WelcomeRoute()]);`

### T2: Verify Navigation Stack (AC: 3)

- [x] `replaceAll` already used — clears entire navigation stack
- [x] No back navigation possible to authenticated screens

### T3: Verify Auth State (AC: 4)

- [x] `AccountManagementService.deleteAccount()` already deletes Firebase Auth account
- [x] After deletion, `FirebaseAuth.currentUser` is null

### T4: Verify Welcome Screen (AC: 2)

- [x] `WelcomeRoute` is already defined as unauthenticated route in `app_router.dart`
- [x] `WelcomeScreen` has "Get Started" and "Sign In" buttons
- [x] No route guard changes needed

## Dev Notes

### Architecture

- **One-line fix** — changed `AppIntroRoute()` to `WelcomeRoute()` in post-deletion navigation
- **Root cause:** After account deletion, navigating to `AppIntroRoute` (intro carousel) forced users through 4 carousel pages before reaching Welcome — confusing UX since they already know the app
- **`WelcomeRoute`** is already defined as an unauthenticated route — no guard changes needed

### Key Files

| File | Path | Role |
|------|------|------|
| SettingsScreen | `lib/features/settings/presentation/screens/settings_screen.dart` | `_showDeleteAccountFlow` — line 848 fix |
| WelcomeScreen | `lib/features/onboarding/presentation/screens/welcome_screen.dart` | Correct destination after deletion |
| AppIntroScreen | `lib/features/onboarding/presentation/screens/app_intro_screen.dart` | Previous (wrong) destination |
| AuthGuard | `lib/core/navigation/guards/auth_guard.dart` | Redirects unauthenticated to AppIntroRoute |
| AccountManagementService | `lib/features/settings/domain/services/account_management_service.dart` | Handles account deletion |

### The Bug (Before Fix)

```dart
// Line 848 — navigated to intro carousel after deletion
await context.router.replaceAll([const AppIntroRoute()]);
```

### The Fix

```dart
// Line 848 — now navigates to Welcome screen
await context.router.replaceAll([const WelcomeRoute()]);
```

### Flow Problem (Before Fix)

1. User taps "Delete Account" -> re-authenticates -> types "DELETE" -> confirms
2. `AccountManagementService.deleteAccount()` runs (Firestore + Auth + local DB cleared)
3. Code navigated to `AppIntroRoute` (4-page intro carousel)
4. User had to swipe through intro pages to reach Welcome — confusing after account deletion

### Flow (After Fix)

1. Same deletion flow
2. Code navigates to `WelcomeRoute` directly
3. User sees "Get Started" / "Sign In" options immediately

### Critical Constraints

- `WelcomeRoute` is an unauthenticated route — AuthGuard does not interfere
- `replaceAll` clears the entire navigation stack — no back navigation possible
- Error handling already in place (lines 851-858) — on failure, user stays on Settings with error snackbar
- Sign-out flow (line 784) also uses `AppIntroRoute` — noted as future follow-up but out of scope

### Testing Standards

- Verify post-deletion navigation target is `WelcomeRoute`
- Verify error case stays on Settings screen
- Verify navigation stack is fully replaced

### References

- [Source: _bmad-output/project-context.md#auto_route Navigation] — Route patterns, replaceAll
- [Source: _bmad-output/project-context.md#Firebase Integration] — Auth, account deletion

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

_None — one-line fix_

### Completion Notes List

- T1: Changed `AppIntroRoute()` to `WelcomeRoute()` on line 848 of `settings_screen.dart`. One-line fix.
- T2: Verified `replaceAll` clears navigation stack — no back navigation to authenticated screens.
- T3: Verified `AccountManagementService.deleteAccount()` clears Firebase Auth state.
- T4: Verified `WelcomeRoute` is unauthenticated, has "Get Started" and "Sign In" buttons.

### Change Log

- 2026-03-29: Initial fix — post-deletion navigation to WelcomeRoute. Commit `fbef12d`.

### File List

**Modified:**
- `lib/features/settings/presentation/screens/settings_screen.dart` — line 848: `AppIntroRoute()` -> `WelcomeRoute()`
