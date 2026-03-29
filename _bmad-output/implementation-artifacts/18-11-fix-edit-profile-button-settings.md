# Story 18.11: Fix Edit Profile Button on Settings Screen (DNI-177)

Status: review

## Story

As a user,
I want the edit button next to my profile on the Settings screen to open an edit dialog,
so that I can change my display name without leaving the settings page.

## Acceptance Criteria

**AC-1: Edit button opens profile edit dialog**
**Given** the user is signed in and viewing the Settings screen
**When** they tap the edit (pencil) icon next to their profile name
**Then** a dialog appears with a text field pre-filled with their current display name

**AC-2: User can update their display name**
**Given** the edit profile dialog is open
**When** the user changes the name and taps "Save"
**Then** the display name is updated in Firebase Auth and the Settings screen reflects the new name

**AC-3: Empty name is rejected**
**Given** the edit profile dialog is open
**When** the user clears the text field and tries to save
**Then** the save button is disabled or a validation error is shown

**AC-4: Cancel preserves original name**
**Given** the edit profile dialog is open
**When** the user taps "Cancel"
**Then** the dialog closes and the display name remains unchanged

**AC-5: Error handling**
**Given** the user taps Save
**When** the Firebase update fails (e.g., network error)
**Then** an error snackbar is shown

## Tasks / Subtasks

### T1: Implement _showEditProfileDialog (AC: 1, 2, 3, 4, 5)

- [x] Create `_showEditProfileDialog()` function in `settings_screen.dart`
- [x] Follow existing dialog pattern from `_showChangePasswordFlow` and `_showDeleteAccountFlow`
- [x] `TextEditingController` pre-filled with current `displayName`
- [x] Save button calls `user.updateDisplayName(newName)` then `user.reload()`
- [x] Empty name validation — Save button disabled when field is empty
- [x] Cancel closes dialog without changes
- [x] Error handling with snackbar on Firebase failure

### T2: Wire Edit Button (AC: 1)

- [x] Replace empty `onPressed: () {}` closure on the edit `IconButton` (L481-486) with call to `_showEditProfileDialog()`
- [x] Pass current `User` object to the dialog

### T3: UI Refresh After Update (AC: 2)

- [x] After `user.updateDisplayName()` + `user.reload()`, the UI refreshes
- [x] `_UserProfileSection` reads from Firebase Auth user — reload triggers rebuild
- [x] Initials in `CircleAvatar` auto-update from new display name
- [x] Success snackbar shown on completion

## Dev Notes

### Architecture

- **Bug fix:** The edit `IconButton.onPressed` was an empty closure `() {}` — simply needed implementation
- **Dialog pattern:** Follows existing `_showChangePasswordFlow` and `_showDeleteAccountFlow` patterns in the same file
- **Firebase Auth:** `user.updateDisplayName(newName)` + `user.reload()` for persistence and UI refresh
- **Display name derivation:** `user.displayName ?? user.email?.split('@').first ?? 'User'` (L414-415)

### Key Files

| File | Path | Role |
|------|------|------|
| SettingsScreen | `lib/features/settings/presentation/screens/settings_screen.dart` | `_UserProfileSection` widget + new `_showEditProfileDialog()` |

### The Bug (Before Fix)

```dart
// Line 481-486 — empty handler
IconButton(
  icon: Icon(Icons.edit_outlined, color: theme.colorScheme.onSurfaceVariant),
  onPressed: () {},  // <-- Did nothing
),
```

### The Fix

```dart
IconButton(
  icon: Icon(Icons.edit_outlined, color: theme.colorScheme.onSurfaceVariant),
  onPressed: () => _showEditProfileDialog(context, user),
),
```

### Critical Constraints

- `_UserProfileSection` is a `StatelessWidget` — receives `User? user` from parent
- After `user.reload()`, the parent's `ref.watch(firebaseAuthProvider)` triggers rebuild
- Dialog follows Material Design 3 patterns

### Testing Standards

- Widget test: tap edit icon, verify dialog appears
- Test pre-filled display name
- Test empty name validation
- Test cancel behavior

### References

- [Source: _bmad-output/project-context.md#Firebase Integration] — Firebase Auth patterns
- [Source: _bmad-output/project-context.md#Error Handling] — User-facing error messages

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

_None — one-function fix_

### Completion Notes List

- T1: Created `_showEditProfileDialog()` with TextField, Save/Cancel buttons, empty name validation, error handling. Follows existing dialog patterns.
- T2: Wired `IconButton.onPressed` to call `_showEditProfileDialog()` — replaced empty closure.
- T3: After `updateDisplayName()` + `reload()`, `_UserProfileSection` rebuilds via Firebase Auth provider. Initials auto-update. Success snackbar shown.

### Change Log

- 2026-03-29: Initial implementation — edit profile dialog + button wiring. Commit `fbef12d`.

### File List

**Modified:**
- `lib/features/settings/presentation/screens/settings_screen.dart` — added `_showEditProfileDialog()`, wired edit button
