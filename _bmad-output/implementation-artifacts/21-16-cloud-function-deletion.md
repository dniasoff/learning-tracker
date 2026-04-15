# Story 21.16: Firebase Cloud Function — Server-Side Deletion Cleanup

Status: done

## Story

As the system,
I want a server-side safety net that cleans up Firestore data when a Firebase Auth user is deleted,
so that even if the client crashes mid-deletion, no orphaned data remains.

## Acceptance Criteria (ACs)

1. **Given** a Firebase Auth user is deleted (from client or admin console)
   **When** the `onDelete` trigger fires
   **Then** all subcollections under `/users/{uid}/` are deleted within 30 seconds

2. **Given** the client crashed mid-deletion (some subcollections deleted, some not)
   **When** the Cloud Function runs
   **Then** remaining subcollections cleaned up — no orphaned data

3. **Given** a user document has no subcollections (edge case)
   **When** the Cloud Function runs
   **Then** user document deleted without errors

4. **Given** the Cloud Function is deployed
   **When** checking Firebase console
   **Then** function is listed, logs show trigger registration

## Tasks / Subtasks

- [ ] Initialize Firebase Cloud Functions project (AC: 4)
  - [ ] `cd learning_tracker && firebase init functions`
  - [ ] Choose TypeScript
  - [ ] Creates `functions/` directory with `src/index.ts`, `package.json`, `tsconfig.json`
- [ ] Implement `onUserDeleted` function (AC: 1,2,3)
  ```typescript
  import * as admin from 'firebase-admin';
  import { auth } from 'firebase-functions';

  admin.initializeApp();

  const SUBCOLLECTIONS = [
    'completions', 'bookmarks', 'settings', 'streaks',
    'profiles', 'goals', 'rewards', 'sync_queue',
    'learning_order', 'stage_definitions',
  ];

  async function deleteCollection(
    collectionRef: admin.firestore.CollectionReference,
    batchSize = 500,
  ): Promise<void> {
    const snapshot = await collectionRef.limit(batchSize).get();
    if (snapshot.empty) return;

    const batch = admin.firestore().batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();

    if (snapshot.size >= batchSize) {
      await deleteCollection(collectionRef, batchSize);
    }
  }

  export const onUserDeleted = auth.user().onDelete(async (user) => {
    const uid = user.uid;
    const db = admin.firestore();
    const userDoc = db.collection('users').doc(uid);

    for (const sub of SUBCOLLECTIONS) {
      await deleteCollection(userDoc.collection(sub));
    }

    await userDoc.delete();
    console.log(`Cleaned up all data for user ${uid}`);
  });
  ```
- [ ] Deploy function (AC: 4)
  - [ ] `cd functions && npm install`
  - [ ] `firebase deploy --only functions`
  - [ ] Verify in Firebase console → Functions tab
- [ ] Test with a throwaway test account
  - [ ] Create test user + seed some data in subcollections
  - [ ] Delete user from Firebase console
  - [ ] Verify all subcollections are gone within 30 seconds
- [ ] Add `functions/` to the repo `.gitignore` exclusion (or include in version control)

## Dev Notes

### Files to create
- `functions/src/index.ts` — the Cloud Function
- `functions/package.json` — Node.js dependencies
- `functions/tsconfig.json` — TypeScript config
- `.firebaserc` — may be updated by `firebase init`

### This is the FIRST Cloud Function in the project
The `functions/` directory doesn't exist yet. `firebase init functions` creates the scaffolding. Choose:
- Language: **TypeScript**
- ESLint: yes
- Install dependencies: yes

### Belt-and-suspenders pattern
- **Client (21.15):** does best-effort Firestore cleanup before calling `user.delete()`
- **Cloud Function (this story):** catches anything the client missed
- Even if the client deleted 8 of 10 subcollections before crashing, the function sweeps the remaining 2
- The function is triggered by `auth.user().onDelete()` — fires whenever a Firebase Auth user is deleted, regardless of how (client SDK, admin console, admin SDK)

### Subcollection list maintenance
The `SUBCOLLECTIONS` array must be kept in sync with whatever subcollections the app creates under `/users/{uid}/`. If a future epic adds a new subcollection (e.g., `notifications`), it must be added here too.

### Cost considerations
- Cloud Function execution: ~$0.40 per million invocations
- Firestore deletes: $0.02 per 100K operations
- For this app's scale (< 1000 users), the cost is negligible
- No always-on infrastructure — functions are serverless and scale to zero

### Testing
- Cannot unit test the actual trigger locally — use Firebase emulator suite:
  ```bash
  cd functions
  npm run serve  # starts local emulator
  ```
- Integration test: create + delete user via admin SDK, verify subcollections gone

### Guardrails
- NEVER use `firebase-admin` in client-side Flutter code — it's server-side only
- The function must handle the case where subcollections don't exist (empty `.get()`)
- Use batched deletes (500 per batch) to stay within Firestore limits
- Log the UID being cleaned up for audit trail

### References
- [Firebase Cloud Functions docs: auth triggers](https://firebase.google.com/docs/functions/auth-events)
- [Firestore batch operations](https://firebase.google.com/docs/firestore/manage-data/delete-data#collections)
- [Source: learning_tracker/firebase.json] — existing Firebase config

## Dev Agent Record

### Agent Model Used
### Completion Notes List
### Change Log
