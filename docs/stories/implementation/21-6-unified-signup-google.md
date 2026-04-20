# Story 21.6: Unified Sign-Up Page — Google Sign-In Path

Status: done

## Story

As a new user with a Google account,
I want to sign up with one tap using Google Sign-In,
so that I don't have to type a password.

## Acceptance Criteria (ACs)

1. **Given** device is online and Google Play Services available
   **When** user taps Continue with Google
   **Then** Google picker opens, Firebase credential obtained, cloud-born account created

2. **Given** Google returns email matching a local-born account on device
   **When** Firebase sign-in succeeds
   **Then** collision/upgrade flow is triggered (not a silent merge)

3. **Given** device is offline
   **When** sign-up page renders
   **Then** Google Sign-In button is not visible

4. **Given** 5 accounts exist on device
   **When** Google Sign-In returns a new account
   **Then** "Maximum accounts reached. Remove one to add another." shown

5. **Given** Google returns existing user (not new)
   **When** check registry for firebaseUid
   **Then** if found on device → switch to that account; if not → create local DB, add to registry, sync

6. **Given** Google Play Services missing/outdated
   **When** user taps Google button
   **Then** PlatformException caught → "Google Sign-In unavailable. Use email and password instead."

7. **Given** user cancels Google picker
   **Then** return to form, no error shown

## Tasks / Subtasks

- [ ] Add Google Sign-In button to `sign_up_screen.dart` (AC: 3)
  - [ ] Only visible when `connectivityStreamProvider` emits true
  - [ ] AnimatedSwitcher or AnimatedOpacity for show/hide
- [ ] Implement Google Sign-In flow (AC: 1,5,7)
  - [ ] `GoogleSignIn().signIn()` → `GoogleSignInAuthentication` → `GoogleAuthProvider.credential`
  - [ ] `FirebaseAuth.instance.signInWithCredential(credential)`
  - [ ] Check `additionalUserInfo.isNewUser` for new vs existing
  - [ ] New user: create cloud-born account, registry, onboarding
  - [ ] Existing user + in registry: switch to that account
  - [ ] Existing user + not in registry: create local DB, add, sync
- [ ] Handle collision with local-born (AC: 2)
  - [ ] After Google returns email, check `registry.findByEmail(email)`
  - [ ] If found as local-born → navigate to upgrade/collision flow (Epic 20.9 screen)
- [ ] Handle 5-account cap (AC: 4)
  - [ ] After Google success, before adding: check `registry.accounts.length >= 5`
  - [ ] If at cap → show error dialog, do NOT add account
- [ ] Handle PlatformException (AC: 6)
  - [ ] Catch `PlatformException` → show SnackBar
- [ ] Write test: Google flow creates cloud-born account
- [ ] Write test: collision with local-born triggers upgrade

## Dev Notes

### Files to modify
- `lib/features/auth/presentation/screens/sign_up_screen.dart` — add Google button + handler (builds on 21.5)

### Google Sign-In flow detail
```dart
Future<void> _signInWithGoogle() async {
  final googleUser = await GoogleSignIn().signIn();
  if (googleUser == null) return; // user cancelled
  
  final googleAuth = await googleUser.authentication;
  final credential = GoogleAuthProvider.credential(
    accessToken: googleAuth.accessToken,
    idToken: googleAuth.idToken,
  );
  
  final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
  final isNew = userCredential.additionalUserInfo?.isNewUser ?? false;
  // ... handle new vs existing
}
```

### Collision detection sequence
1. Google returns `googleUser.email`
2. Check `registry.findByEmail(email)`
3. If found as local-born → this email has a local account AND a Google/cloud identity
4. Navigate to collision screen (reuse Epic 20.9's `UpgradeToCloudScreen` or a variant)
5. Collision screen offers: upload local into cloud / keep cloud discard local / cancel

### Guardrails
- NEVER silently merge a Google account with a local-born account — always go through collision flow
- Check registry count AFTER Google success but BEFORE adding to registry
- The Google Sign-In button must disappear instantly when connectivity drops (stream-driven)

### References
- [Source: lib/features/auth/presentation/providers/auth_providers.dart] — existing Google Sign-In helpers
- [Source: lib/features/settings/presentation/screens/upgrade_to_cloud_screen.dart] — collision flow from Epic 20.9
- [Source: lib/core/database/registry/device_registry_database.dart] — findByEmail, addAccount

## Dev Agent Record

### Agent Model Used
### Completion Notes List
### Change Log
