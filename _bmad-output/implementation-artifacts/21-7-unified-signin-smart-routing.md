# Story 21.7: Unified Sign-In Page — Smart Credential Routing

Status: ready-for-dev

## Story

As a returning user,
I want a single sign-in page that figures out where to check my credentials,
so that I just type my email and password and the app does the right thing.

## Acceptance Criteria (ACs)

1. **Given** email matches a local-born account on device
   **When** user enters correct password and taps Sign In
   **Then** argon2id verification passes, session starts, dashboard shown

2. **Given** email matches a cloud-born account on device + online
   **When** user enters correct password
   **Then** Firebase sign-in succeeds, session starts

3. **Given** email matches a cloud-born account + offline + cached session valid
   **When** user taps Sign In
   **Then** `tryResumeCloudSession` succeeds, instant switch without network

4. **Given** email is not on device + online
   **When** Firebase sign-in succeeds
   **Then** new local DB created, account added to registry, data synced from Firestore

5. **Given** email is not on device + offline
   **Then** "This email isn't on this device and we can't reach the cloud" shown

6. **Given** Firebase returns `user-not-found` for an email that's in the registry
   **Then** "This account no longer exists in the cloud" + cleanup offer shown

7. **Given** user types email in the email field
   **Then** live hint appears below field: "Found on this device (Cloud/Local)" or "Not on this device"

8. **Given** wrong password entered (any tier)
   **Then** "Incorrect password" shown (same message regardless of tier — anti-enumeration)

## Tasks / Subtasks

- [ ] Create `lib/features/auth/presentation/screens/sign_in_screen_v2.dart` (AC: 7)
  - [ ] `@RoutePage()` ConsumerStatefulWidget
  - [ ] Email field with debounced live lookup (300ms) against `deviceRegistry.findByEmail`
  - [ ] `_AccountHint` widget below email: tier badge + "Found on this device" / "Not on this device"
  - [ ] Password field
  - [ ] Google Sign-In button (visible when online, implemented in 21.8)
  - [ ] "Don't have an account? Sign up" link
- [ ] Implement smart credential routing on submit (AC: 1,2,3,4,5)
  ```
  registry found + local-born    → LocalAuthService.signIn
  registry found + cloud-born    → one-shot check:
    online  → Firebase.signInWithEmailAndPassword
    offline → tryResumeCloudSession(firebaseUid)
      success → instant switch
      fail    → "Connect to sign in"
  not found + online             → Firebase.signInWithEmailAndPassword
    success → new device: create DB, add registry, sync
  not found + offline            → error message
  ```
- [ ] Handle Firebase errors (AC: 6,8)
  - [ ] `user-not-found` + in registry → "Account no longer exists" + [Remove from device] + [Sign up again]
  - [ ] `user-disabled` → "Account disabled"
  - [ ] `wrong-password` → "Incorrect password"
  - [ ] `too-many-requests` → "Too many attempts"
- [ ] Post-sign-in sequence (AC: 1,2,4)
  - [ ] Update `registry.updateLastUsed(accountId)`
  - [ ] Set `lastActiveAccountId`
  - [ ] Open account's DB via `ActiveUserDatabaseProvider`
  - [ ] If new device for cloud account: SyncEngine pulls data
  - [ ] Navigate to dashboard (or onboarding if `kOnboardingComplete` false)
- [ ] Delete or deprecate old sign-in screens
  - [ ] `lib/features/auth/presentation/screens/sign_in_screen.dart` → delete
  - [ ] Update `app_router.dart` — replace `SignInRoute` with new route
- [ ] Run build_runner
- [ ] Write unit test: local-born path → argon2id called
- [ ] Write unit test: cloud-born online → Firebase called
- [ ] Write unit test: not found + online → new device flow
- [ ] Write widget test: email hint updates as user types

## Dev Notes

### Files to create
- `lib/features/auth/presentation/screens/sign_in_screen_v2.dart` (or replace existing in-place)

### Files to delete
- `lib/features/auth/presentation/screens/sign_in_screen.dart` (old cloud-only)
- `lib/features/auth/presentation/screens/local_sign_in_screen.dart` (if exists)

### Files to modify
- `lib/core/navigation/app_router.dart` — replace SignInRoute
- `lib/features/onboarding/presentation/screens/welcome_screen.dart` — route to new SignInRoute
- `lib/features/auth/presentation/screens/account_picker_screen.dart` — "Sign in again" routes here

### Live email lookup implementation
```dart
Timer? _debounceTimer;

void _onEmailChanged(String email) {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(const Duration(milliseconds: 300), () {
    final normalized = email.trim().toLowerCase();
    if (normalized.length < 5) { setState(() => _hint = null); return; }
    
    final account = ref.read(deviceRegistryProvider).findByEmail(normalized);
    final isOnline = ref.read(connectivityStreamProvider).maybeWhen(
      data: (v) => v, orElse: () => true,
    );
    
    setState(() {
      if (account != null) {
        _hint = 'Found on this device (${account.tier == "cloudBorn" ? "Cloud" : "Local"})';
        _hintTier = account.tier;
      } else if (isOnline) {
        _hint = "Not on this device — we'll check the cloud";
      } else {
        _hint = "Not on this device (offline — only device accounts available)";
      }
    });
  });
}
```

### New device for existing cloud account
When Firebase signIn succeeds for an email NOT in the registry:
1. User has this account on another device, signing in here for the first time
2. Create `user_acc_{uuid}.db`
3. Add to registry with Firebase user's uid, email, displayName
4. SyncEngine activates and pulls all data from Firestore
5. User sees their existing data once sync completes

### Security note on live lookup
The hint reveals whether an email exists in the LOCAL registry — NOT whether it exists in Firebase. This is safe because:
- The registry is local to the physical device
- An attacker with device access already has the DB files
- The hint never queries Firebase (no remote enumeration)

### Guardrails
- NEVER reveal whether an email exists in Firebase through the hint — only local registry
- The `tryResumeCloudSession` path must NOT call Firebase signIn — it only checks the cached currentUser
- "Incorrect password" must be the SAME message for wrong-password AND unknown-email (in the no-registry-match + offline case, a different message is OK because we're not confirming the email exists remotely)

### References
- [Source: lib/features/auth/domain/services/local_auth_service.dart] — signIn for local-born
- [Source: lib/features/auth/presentation/providers/connectivity_providers.dart] — stream + one-shot
- [Source: lib/core/database/registry/device_registry_database.dart] — findByEmail
- [Source: lib/features/auth/presentation/providers/auth_state_provider.dart] — session management

## Dev Agent Record

### Agent Model Used
### Completion Notes List
### Change Log
