# Story 21.8: Unified Sign-In Page — Google Sign-In Path

Status: done

## Story

As a returning user who signed up with Google,
I want to sign in via Google on the same sign-in page,
so that I have one consistent entry point.

## Acceptance Criteria (ACs)

1. **Given** Google Sign-In returns a firebaseUid matching an account in the registry
   **When** sign-in completes
   **Then** app switches to that account instantly

2. **Given** Google Sign-In returns a new firebaseUid (existing cloud account, new device)
   **When** sign-in completes
   **Then** new local DB created, account added to registry, Firestore data syncs

3. **Given** Google Sign-In returns email matching a local-born account on device
   **Then** collision/upgrade flow triggered

4. **Given** device is offline
   **Then** Google Sign-In button is hidden

5. **Given** 5 accounts on device
   **When** Google returns new account
   **Then** "Maximum accounts reached" shown

## Tasks / Subtasks

- [ ] Add Google Sign-In button to `sign_in_screen_v2.dart` (AC: 4)
  - [ ] Visible only when `connectivityStreamProvider` emits true
- [ ] Implement Google Sign-In handler (AC: 1,2,3)
  - [ ] Same flow as 21.6: GoogleSignIn → credential → Firebase signInWithCredential
  - [ ] Check registry for firebaseUid: found → switch; not found → new device flow
  - [ ] Check email against local-born registry entries → collision
- [ ] Handle 5-account cap (AC: 5)
- [ ] Write test: Google returns existing account → switch

## Dev Notes

### Files to modify
- `lib/features/auth/presentation/screens/sign_in_screen_v2.dart` — add Google button + handler (builds on 21.7)

### Code reuse
The Google Sign-In handler logic is nearly identical between 21.6 (sign-up) and 21.8 (sign-in). Extract a shared helper:
```dart
// lib/features/auth/domain/services/google_auth_service.dart
class GoogleAuthService {
  Future<GoogleAuthResult> signInWithGoogle({
    required DeviceRegistryDatabase registry,
  }) async { ... }
}
```
Both screens call this service. The difference is only in the success handling (sign-up goes to onboarding, sign-in goes to dashboard).

### Guardrails
- Same as 21.6: never silent merge, check cap after Google success, collision flow for local-born email match

### References
- [Source: 21-6-unified-signup-google.md] — shared Google flow logic
- [Source: lib/features/auth/presentation/screens/sign_in_screen_v2.dart] — from 21.7

## Dev Agent Record

### Agent Model Used
### Completion Notes List
### Change Log
