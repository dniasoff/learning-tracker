# Story 21.15: Delete Cloud-Born Account (Full Wipe)

Status: done

## Story

As a user who wants to completely delete my cloud account,
I want all my data removed from both the device and the cloud,
so that nothing remains anywhere — full GDPR-style erasure.

## Acceptance Criteria (ACs)

1. **Given** a cloud-born account
   **When** user taps "Delete account forever"
   **Then** re-authentication is required before proceeding

2. **Given** re-auth succeeds
   **When** deletion executes
   **Then** Firestore subcollections deleted BEFORE local DB deleted (order critical)

3. **Given** Firestore + Auth deletion succeeds
   **Then** local DB file deleted, registry entry removed

4. **Given** network drops during Firestore deletion
   **Then** process halts, local data preserved, "Try again when online" shown

5. **Given** the account exists on another device
   **When** that device tries to sync
   **Then** "Account no longer exists" shown, orphaned data cleaned up

6. **Given** deletion completes and this was active account
   **Then** picker shown (or welcome if zero accounts)

## Tasks / Subtasks

- [ ] Add "Delete Account Forever" to Settings (AC: 1)
  - [ ] Only for cloud-born accounts
  - [ ] Hard confirm: "Permanently delete your account and ALL data from our servers?"
  - [ ] Re-auth: show password field (email pre-filled, read-only)
  - [ ] For Google accounts: re-auth via Google Sign-In
- [ ] Implement Firestore data deletion (AC: 2)
  - [ ] Delete ALL subcollections under `/users/{uid}/`:
    ```
    completions, bookmarks, settings, streaks, profiles,
    goals, rewards, sync_queue, learning_order, stage_definitions
    ```
  - [ ] Delete the user document itself
  - [ ] Use batched writes for efficiency
- [ ] Implement Firebase Auth user deletion (AC: 2)
  - [ ] `FirebaseAuth.instance.currentUser!.delete()`
  - [ ] This triggers the Cloud Function (21.16) as safety net
- [ ] Delete local data (AC: 3)
  - [ ] ONLY after Firestore + Auth succeed
  - [ ] Delete `user_acc_{id}.db` file
  - [ ] Remove from device registry
- [ ] Handle network failure (AC: 4)
  - [ ] Wrap Firestore deletion in try/catch
  - [ ] On failure: do NOT delete local, show error
  - [ ] "Deletion failed — your local data is safe. Try again when online."
- [ ] Handle multi-device orphan (AC: 5)
  - [ ] When SyncEngine on another device gets auth error → show "Account deleted" → clean up local
- [ ] Session cleanup (AC: 6)
  - [ ] Clear SharedPreferences, clear AuthState
  - [ ] Show picker or welcome
- [ ] Create `AccountDeletionService` in `lib/features/auth/domain/services/`
- [ ] Write test: full deletion sequence (Firestore → Auth → local → registry)
- [ ] Write test: network failure → rollback, local preserved

## Dev Notes

### Files to create
- `lib/features/auth/domain/services/account_deletion_service.dart`

### Files to modify
- `lib/features/settings/presentation/screens/settings_screen.dart` — add delete button for cloud-born
- `lib/features/auth/presentation/screens/account_picker_screen.dart` — swipe action alternative

### CRITICAL: Execution order
```
1. Re-authenticate user (Firebase requires recent auth)
2. Delete Firestore subcollections (client-side best-effort)
3. Delete Firebase Auth user → triggers Cloud Function (21.16) as safety net
4. Delete local DB file
5. Remove from registry
6. Clear session
```

**NEVER reverse steps 2-4.** If you delete local (step 4) before cloud (steps 2-3), the user loses their local copy AND their cloud copy might not get deleted if the network drops. They'd have nothing left anywhere.

### Re-authentication
Firebase requires recent authentication for destructive operations:
```dart
final credential = EmailAuthProvider.credential(
  email: user.email!,
  password: enteredPassword,
);
await user.reauthenticateWithCredential(credential);
// Now safe to call user.delete()
```

### Firestore subcollection deletion
Firestore doesn't support recursive document deletion from the client. Must iterate each subcollection:
```dart
Future<void> _deleteCollection(CollectionReference ref) async {
  final snapshots = await ref.limit(500).get();
  for (final doc in snapshots.docs) {
    await doc.reference.delete();
  }
  if (snapshots.docs.length == 500) {
    await _deleteCollection(ref); // recurse for large collections
  }
}
```

### Guardrails
- NEVER delete local before cloud succeeds
- ALWAYS re-authenticate before deletion
- Cloud Function (21.16) is the safety net — client deletion is best-effort
- Show progress indicator during deletion (may take seconds for large accounts)
- Disable all navigation during deletion (prevent partial state)

### References
- [Source: lib/features/auth/domain/services/account_removal_service.dart] — from 21.13 (local file deletion)
- [Source: lib/features/sync/data/firestore_data_source.dart] — Firestore collection references
- [Source: lib/core/providers/firebase_providers.dart] — firebaseAuthProvider

## Dev Agent Record

### Agent Model Used
### Completion Notes List
### Change Log
