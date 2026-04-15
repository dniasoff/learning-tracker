# Story 21.11: Add Account from Picker (Respects 5-Account Cap)

Status: done

## Story

As a user at the account picker,
I want to add another account directly from the picker,
so that I don't have to navigate back to the welcome screen.

## Acceptance Criteria (ACs)

1. **Given** 3 accounts on device (2 remaining slots)
   **When** the picker is displayed
   **Then** [+ Add another account] button is visible with "2 slots remaining" indicator

2. **Given** 5 accounts on device (at capacity)
   **When** the picker is displayed
   **Then** [+ Add] button is hidden or disabled with "Maximum accounts reached" text

3. **Given** user taps [+ Add] while online
   **When** sign-up completes
   **Then** new account is added to registry, set as active, navigates to onboarding

4. **Given** user taps [+ Add] while offline
   **When** local sign-up completes
   **Then** local-born account is added to registry, set as active, navigates to onboarding

5. **Given** user taps [+ Add] and then backs out of sign-up
   **When** returning to picker
   **Then** picker state is unchanged, no phantom account created

## Tasks / Subtasks

- [ ] Add [+ Add another account] button to AccountPickerScreen (AC: 1,2)
  - [ ] Position at bottom of the account list
  - [ ] Watch `deviceAccountsProvider` length for slot count
  - [ ] Show remaining: `"${5 - accounts.length} slots remaining"`
  - [ ] When length >= 5: disable button, show "Maximum accounts reached"
- [ ] Implement add-account routing (AC: 3,4)
  - [ ] On tap: read connectivity → online → push `SignUpRoute()`, offline → push `SignUpRoute()` (same page, adapts via connectivity stream)
  - [ ] After successful signup in `SignUpScreen`: new account auto-added to registry (handled by 21.5), session starts, onboarding runs
  - [ ] On back from signup without completing: picker is shown again, no change
- [ ] Handle edge case: user was at 4 accounts, goes to signup, another session adds 5th (AC: 5)
  - [ ] On return from signup, re-check registry count before inserting
  - [ ] If now at 5, show error and don't add
- [ ] Write widget test: button shows correct slot count
- [ ] Write widget test: button disabled at capacity

## Dev Notes

### Files to modify
- `lib/features/auth/presentation/screens/account_picker_screen.dart` — add the button below the account list

### Architecture notes
- The [+ Add] button uses `context.router.push(SignUpRoute())` (not `replace`) so the picker stays in the back stack
- When the signup flow completes, it calls `context.router.replaceAll([OnboardingRoute()])` which clears the picker from the stack — this is the same behavior as today's welcome → signup flow
- The 5-account cap is enforced at two levels:
  1. The button visibility (UI-level)
  2. `DeviceRegistryDatabase.addAccount()` throws `MaxAccountsReachedException` (data-level, from 21.1)
- Both gates must agree — the data-level check is the authoritative one

### Testing
- Widget test with `ProviderScope` override for `deviceAccountsProvider` returning 3 accounts → button visible
- Widget test with 5 accounts → button disabled
- Navigation test: tap [+ Add] → SignUpRoute pushed

### Guardrails
- NEVER allow adding if at 5 accounts — check BOTH UI state and data layer
- The button must use `push` not `replace` so picker survives in the back stack
- If signup fails or user backs out, the registry must not have been modified

### References
- [Source: lib/features/auth/presentation/screens/account_picker_screen.dart] — from 21.9
- [Source: lib/core/database/registry/device_registry_database.dart] — MaxAccountsReachedException from 21.1
- [Source: lib/features/auth/presentation/screens/sign_up_screen.dart] — from 21.5

## Dev Agent Record

### Agent Model Used
### Completion Notes List
### Change Log
