# Story 21.14: Delete Local-Born Account

Status: done

## Story

As a user with a local-born account I no longer need,
I want to permanently delete it,
so that my data is gone and the account slot is freed.

## Acceptance Criteria (ACs)

1. **Given** a local-born account
   **When** user taps "Delete account" (swipe or Settings)
   **Then** hard confirm dialog with checkbox: "Permanently delete? All data lost. Cannot be undone."

2. **Given** user checks checkbox and confirms
   **Then** DB file deleted, registry entry removed, account gone permanently

3. **Given** deletion completes and this was the active account
   **Then** picker shown (or welcome if zero accounts)

4. **Given** deletion completes
   **When** user tries to sign in with same email
   **Then** "Not found on this device" — truly gone

5. **Given** no network connection
   **When** user deletes a local-born account
   **Then** deletion succeeds (no network calls needed)

## Tasks / Subtasks

- [ ] Add delete handler to AccountPickerScreen (AC: 1)
  - [ ] Swipe-left on local-born tile → `confirmDismiss` with hard confirm
  - [ ] Checkbox: "I understand this is permanent and cannot be recovered"
  - [ ] Button text: "Delete Account Forever"
- [ ] Add delete option in Settings → Account (AC: 1)
  - [ ] Only visible for local-born accounts
  - [ ] Same hard confirm dialog
- [ ] Implement deletion logic (AC: 2,3,5)
  - [ ] `File(dbPath).deleteSync()` — delete `user_acc_{id}.db`
  - [ ] `registry.removeAccount(accountId)` — remove registry row
  - [ ] If active → clear SharedPreferences, clear AuthState, show picker/welcome
  - [ ] Zero network calls — entirely local operation
- [ ] Write test: deletion removes file + registry
- [ ] Write test: deletion offline works

## Dev Notes

### Files to modify
- `lib/features/auth/presentation/screens/account_picker_screen.dart` — swipe delete for local-born
- `lib/features/settings/presentation/screens/settings_screen.dart` — add "Delete Account" in account section (local-born only)

### Hard confirm pattern
Reuse the same pattern from Epic 20's upgrade flow discard checkbox:
```dart
bool _confirmed = false;

AlertDialog(
  title: Text('Delete Account'),
  content: Column(children: [
    Text('Permanently delete this account? All learning data, profiles, and progress will be lost.'),
    CheckboxListTile(
      value: _confirmed,
      onChanged: (v) => setState(() => _confirmed = v ?? false),
      title: Text('I understand this is permanent'),
    ),
  ]),
  actions: [
    TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
    FilledButton(
      onPressed: _confirmed ? () { /* delete */ } : null,
      child: Text('Delete Account Forever'),
    ),
  ],
)
```

### Guardrails
- NEVER delete without the checkbox confirmation
- NEVER offer "Remove from device" for local-born — deletion is the ONLY option
- Deletion must work fully offline (no network dependency)

### References
- [Source: lib/features/auth/domain/services/account_removal_service.dart] — from 21.13 (reuse file delete logic)
- [Source: lib/features/settings/presentation/screens/upgrade_to_cloud_screen.dart] — hard confirm checkbox pattern

## Dev Agent Record

### Agent Model Used
### Completion Notes List
### Change Log
