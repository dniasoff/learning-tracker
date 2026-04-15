# Story 21.3: Session Auto-Resume on App Startup

Status: done

## Story

As a returning user,
I want the app to auto-resume my last-used account on startup,
so that I see my dashboard immediately without picking an account.

## Acceptance Criteria (ACs)

1. **Given** lastActiveAccountId points to a local-born account
   **When** app starts (even in airplane mode)
   **Then** session resumes instantly — user sees dashboard

2. **Given** lastActiveAccountId points to a cloud-born account with valid cached Firebase session
   **When** app starts offline
   **Then** session resumes — dashboard loads with locally cached data

3. **Given** lastActiveAccountId points to a cloud-born account whose Firebase session is gone
   **When** app starts
   **Then** account picker shown with that account marked "Sign in again"

4. **Given** device registry is empty
   **When** app starts
   **Then** welcome screen shown

5. **Given** lastActiveAccountId references an accountId not in registry (stale)
   **When** app starts
   **Then** fallback to first account in registry, or welcome if empty

## Tasks / Subtasks

- [ ] Rewrite `AuthStateNotifier._init()` (AC: 1,2,3,4,5)
  - [ ] Step 1: Read `SharedPreferences['last_active_account_id']` (fast, sync-like)
  - [ ] Step 2: If null → read from `device_registry.db` device_state as fallback
  - [ ] Step 3: If still null or registry empty → `AuthState.signedOut()` → welcome
  - [ ] Step 4: Look up account in registry by ID
  - [ ] Step 5: If not found (stale pointer) → try first account in registry
  - [ ] Step 6: If cloud-born → check `FirebaseAuth.instance.currentUser`
    - uid matches account.firebaseUid → resume cloud-born session
    - null or mismatch → mark as "needs re-auth" → show picker
  - [ ] Step 7: If local-born → resume immediately (no token check)
- [ ] Handle "needs re-auth" state (AC: 3)
  - [ ] Add `SessionStatus.needsReAuth` or use `signedOut` + route to picker
  - [ ] Picker shows the account with "Sign in again" badge
- [ ] Write test: local-born resumes offline
- [ ] Write test: cloud-born with cached token resumes offline
- [ ] Write test: expired cloud session → picker
- [ ] Write test: empty registry → welcome
- [ ] Write test: stale pointer → fallback

## Dev Notes

### Files to modify
- `lib/features/auth/presentation/providers/auth_state_provider.dart` — rewrite `_init()`

### Firebase offline session behavior (CRITICAL knowledge)
`FirebaseAuth.instance.currentUser` returns non-null as long as the refresh token is cached locally — even with zero network. Token only becomes null if:
- User explicitly signed out (`FirebaseAuth.instance.signOut()`)
- Admin revoked the refresh token server-side
- App local storage was cleared

So in practice, cloud-born session resume works offline for weeks/months. The "expired" case is rare.

### Startup sequence
```
App opens
  → Read SharedPreferences['last_active_account_id'] (< 1ms)
  → Open device_registry.db
  → Look up account
  → If cloud-born: check FirebaseAuth.instance.currentUser
  → If local-born: skip Firebase entirely
  → Open user_acc_{id}.db via ActiveUserDatabaseProvider
  → AuthState.signedIn(...)
  → Router sees signedIn → dashboard
```

Total time budget: < 500ms for the entire sequence. SharedPreferences read is ~1ms. Registry lookup is ~5ms. Firebase currentUser is synchronous (cached property). DB open is ~50ms. Well within budget.

### Guardrails
- NEVER call Firebase network APIs during startup — only check the cached `currentUser`
- NEVER hang on network during session restore (preserves 19.6 startup hardening)
- If registry lookup fails, ALWAYS fall back gracefully (never crash)

### References
- [Source: lib/features/auth/presentation/providers/auth_state_provider.dart] — current _init()
- [Source: lib/core/database/registry/device_registry_database.dart] — from 21.1

## Dev Agent Record

### Agent Model Used
### Completion Notes List
### Change Log
