# Story 21.13: Remove Cloud-Born Account from Device

Status: done

## Story

As a user with a cloud-born account I no longer need on this device,
I want to remove it without deleting my cloud data,
so that I free up an account slot and can sign back in later.

## Acceptance Criteria (ACs)

1. **Given** a cloud-born account on the device
   **When** the user swipes left and taps "Remove from device"
   **Then** confirm dialog: "Remove [name]'s account? Your cloud data is safe — sign back in anytime."

2. **Given** the user confirms removal
   **Then** local DB file deleted, registry entry removed, account slot freed

3. **Given** the removed account was the active account
   **Then** picker shown (or welcome if zero accounts remain)

4. **Given** the user signs in again with the same email later
   **Then** new local DB created, Firestore data syncs — everything restored

5. **Given** a local-born account
   **Then** "Remove from device" is NOT available (only "Delete account" via 21.14)

## Tasks / Subtasks

- [ ] Add removal handler to AccountPickerScreen (AC: 1,5)
  - [ ] Swipe-left on cloud-born tile → `confirmDismiss` shows dialog
  - [ ] Local-born tiles get "Delete" not "Remove" (different flow, 21.14)
- [ ] Implement removal logic (AC: 2,3)
  - [ ] `File(dbPath).deleteSync()` — delete the `user_acc_{id}.db` file
  - [ ] `registry.removeAccount(accountId)` — remove registry row
  - [ ] If `accountId == lastActiveAccountId`:
    - Clear `SharedPreferences['last_active_account_id']`
    - Clear `AuthState` → signedOut
    - Check remaining accounts → picker or welcome
- [ ] Create `AccountRemovalService` in `lib/features/auth/domain/services/`
  - [ ] `removeFromDevice(String accountId)` — orchestrates file delete + registry removal
  - [ ] Verify account is cloud-born before allowing (local-born must use delete path)
- [ ] Write test: removal deletes file + registry entry
- [ ] Write test: active account removal → picker shown

## Dev Notes

### Files to create
- `lib/features/auth/domain/services/account_removal_service.dart`

### Files to modify
- `lib/features/auth/presentation/screens/account_picker_screen.dart` — swipe handler

### Critical: Firestore/Auth NOT touched
This is a light removal. The Firebase Auth account and all Firestore data remain intact. The user can sign in on this or any other device and get everything back. The only thing deleted is the local DB file and the registry entry.

### File deletion
```dart
final dbPath = '${docsDir.path}/${account.dbFileName}';
final file = File(dbPath);
if (file.existsSync()) {
  file.deleteSync();
}
```
Use `path_provider` to resolve the databases directory.

### Guardrails
- NEVER allow "Remove" for local-born accounts — their data has no cloud backup
- ALWAYS confirm before deleting the file
- ALWAYS clear SharedPreferences if removing the active account
- NEVER call `FirebaseAuth.instance.currentUser!.delete()` — that's the full deletion path (21.15)

### References
- [Source: lib/features/auth/presentation/screens/account_picker_screen.dart] — from 21.9
- [Source: lib/core/database/registry/device_registry_database.dart] — removeAccount

## Dev Agent Record

### Agent Model Used
### Completion Notes List
### Change Log
