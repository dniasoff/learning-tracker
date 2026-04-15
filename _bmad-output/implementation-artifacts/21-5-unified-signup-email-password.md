# Story 21.5: Unified Sign-Up Page — Email/Password Path

Status: done

## Story

As a new user,
I want a single sign-up page that adapts to my connectivity,
so that I create an account without choosing between "cloud" and "offline" myself.

## Acceptance Criteria (ACs)

1. **Given** the device is online
   **When** the user fills name/email/password/confirm and taps Create Account
   **Then** `Firebase.createUserWithEmailAndPassword` is called, a cloud-born account is created, user proceeds to onboarding

2. **Given** the device is offline
   **When** the user fills the form, ticks the acknowledgment checkbox, and taps Create Offline Account
   **Then** `LocalAuthService.signUp` creates a local-born account with argon2id hash, user proceeds to onboarding

3. **Given** the device is online at page load but goes offline before tap
   **When** the user taps Create Account
   **Then** the one-shot check detects offline, routes to local path (or Firebase fails → graceful fallback offered)

4. **Given** Firebase returns `email-already-in-use`
   **Then** "An account with this email already exists. Sign in instead?" with link to sign-in (email pre-filled)

5. **Given** Firebase returns `weak-password`
   **Then** "Password doesn't meet requirements" shown inline

6. **Given** connectivity flips while user is typing
   **Then** the banner/warning and Google button animate in/out live via `ref.watch(connectivityStreamProvider)`

7. **Given** Firebase call throws `network-request-failed` mid-execution
   **Then** dialog: "Connection lost during signup. Create an offline account instead?" with [Create Offline] and [Try Again]

8. **Given** successful signup (either tier)
   **Then** account DB file created (`user_acc_{uuid}.db`), added to device registry, set as lastActiveAccountId, navigate to onboarding

## Tasks / Subtasks

- [ ] Create `lib/features/auth/presentation/screens/sign_up_screen.dart` (AC: 1,2,6)
  - [ ] `@RoutePage()` ConsumerStatefulWidget
  - [ ] Form fields: name, email, password, confirm password (same for both tiers)
  - [ ] `ref.watch(connectivityStreamProvider)` → toggle between cloud banner / offline warning+checkbox
  - [ ] Google Sign-In button slot (visible when online, implemented in 21.6)
  - [ ] AnimatedSwitcher for banner/warning transitions
- [ ] Implement submit handler with one-shot connectivity check (AC: 1,2,3,7)
  - [ ] `final isOnline = await InternetConnectionChecker().hasConnection;`
  - [ ] Online path: Firebase.createUserWithEmailAndPassword
  - [ ] Offline path: LocalAuthService.signUp
  - [ ] Catch `network-request-failed` → fallback dialog
- [ ] Handle Firebase error codes (AC: 4,5)
  - [ ] `email-already-in-use` → inline error with "Sign in instead?" link
  - [ ] `weak-password` → inline error
  - [ ] `invalid-email` → inline error
  - [ ] `too-many-requests` → "Too many attempts" message
- [ ] Post-signup registry integration (AC: 8)
  - [ ] Generate UUID for accountId
  - [ ] Create `user_acc_{uuid}.db` via ActiveUserDatabaseProvider
  - [ ] `registry.addAccount(...)` with all fields
  - [ ] `registry.setLastActive(accountId)`
  - [ ] `AuthStateNotifier.setCloudBornSession()` or `.setLocalBornSession()`
  - [ ] Navigate to OnboardingRoute
- [ ] Delete or deprecate old screens:
  - [ ] `account_creation_screen.dart` → delete (replaced by this)
  - [ ] `local_signup_screen.dart` → delete (replaced by this)
  - [ ] Update `app_router.dart` — remove old routes, add `SignUpRoute`
- [ ] Run build_runner for auto_route regen
- [ ] Write unit test: submit online → Firebase called
- [ ] Write unit test: submit offline → LocalAuthService called
- [ ] Write widget test: offline → warning block + checkbox visible, Google button hidden

## Dev Notes

### Files to create
- `lib/features/auth/presentation/screens/sign_up_screen.dart`

### Files to delete
- `lib/features/onboarding/presentation/screens/account_creation_screen.dart`
- `lib/features/onboarding/presentation/screens/local_signup_screen.dart`

### Files to modify
- `lib/core/navigation/app_router.dart` — replace AccountCreationRoute + LocalSignupRoute with SignUpRoute
- `lib/features/onboarding/presentation/screens/welcome_screen.dart` — route to SignUpRoute instead
- Any file importing the old screens

### Connectivity pattern (CRITICAL)
- **UI rendering:** `ref.watch(connectivityStreamProvider)` — stream, rebuilds live
- **Execution:** `await InternetConnectionChecker().hasConnection` — one-shot, fresh at tap time
- **Why both:** stream keeps UI honest; one-shot prevents stale-stream race condition at execution time

### Form validation
- Reuse existing `auth_validators.dart` (`validateEmail`, `validatePassword`, `validateDisplayName`)
- Confirm password: inline check `value != _passwordController.text`
- Offline path requires `_acknowledged` checkbox to be true

### Post-signup flow
The critical sequence after successful signup:
1. Generate UUID → `const Uuid().v4()`
2. Create DB file → `UserDatabase(driftDatabase(name: 'user_acc_$uuid'))`
3. Write UserProfiles row inside that DB
4. Add to registry → `registry.addAccount(...)`
5. Set active → `registry.setLastActive(uuid)`
6. Set auth state → `notifier.setCloudBornSession(profile: ...)` or `.setLocalBornSession(...)`
7. Navigate → `context.router.replaceAll([OnboardingRoute()])`

### Testing
- Mock `InternetConnectionChecker` for one-shot checks
- Mock `FirebaseAuth` for cloud path
- Use in-memory Drift for local path
- Widget test with `ProviderScope` overrides

### Guardrails
- NEVER call Firebase on the offline path
- NEVER skip the acknowledgment checkbox on the offline path
- NEVER create a DB file without adding to registry (orphan prevention)
- Password is NOT carried through navigation arguments — user re-types if redirected

### References
- [Source: lib/features/auth/domain/services/local_auth_service.dart] — signUp
- [Source: lib/features/auth/presentation/providers/connectivity_providers.dart] — stream + one-shot
- [Source: lib/features/auth/presentation/providers/auth_state_provider.dart] — setCloudBornSession/setLocalBornSession
- [Source: lib/features/onboarding/domain/validators/auth_validators.dart] — form validators

## Dev Agent Record

### Agent Model Used
### Completion Notes List
### Change Log
