# Story 21.4: Session Persistence — SharedPreferences Last-Active Tracking

Status: done

## Story

As a user,
I want the app to always remember which account I was last using,
so that every app launch takes me straight back.

## Acceptance Criteria (ACs)

1. **Given** user signs into Account A
   **When** any future app restart
   **Then** `SharedPreferences['last_active_account_id']` matches Account A's ID

2. **Given** user switches from Account A to Account B in picker
   **When** switch completes
   **Then** both `device_state` and `SharedPreferences` updated to Account B

3. **Given** user signs out
   **When** sign-out completes
   **Then** `SharedPreferences['last_active_account_id']` is cleared (null)

4. **Given** SharedPreferences and registry disagree on lastActiveAccountId
   **When** app starts
   **Then** registry is trusted as authoritative source

## Tasks / Subtasks

- [ ] Create `SessionPersistenceService` (AC: 1,2,3)
  - [ ] `lib/features/auth/domain/services/session_persistence_service.dart`
  - [ ] `setActiveAccount(String accountId)` — writes BOTH SharedPreferences + registry device_state
  - [ ] `clearActiveAccount()` — clears BOTH
  - [ ] `getActiveAccountId()` — reads SharedPreferences first (fast), falls back to registry
- [ ] Wire into all account-change flows (AC: 1,2)
  - [ ] Sign-up success → `setActiveAccount(newAccountId)`
  - [ ] Sign-in success → `setActiveAccount(accountId)`
  - [ ] Account switch in picker → `setActiveAccount(newAccountId)`
  - [ ] Sign-out → `clearActiveAccount()`
- [ ] Handle disagreement (AC: 4)
  - [ ] If SharedPreferences returns ID not in registry → clear SharedPreferences, use registry
  - [ ] If registry has a lastActiveAccountId but SharedPreferences is null → use registry value
- [ ] Write test: dual-write pattern works
- [ ] Write test: clear on sign-out
- [ ] Write test: disagreement resolution

## Dev Notes

### Files to create
- `lib/features/auth/domain/services/session_persistence_service.dart`

### Files to modify
- `lib/features/auth/presentation/providers/auth_state_provider.dart` — call `setActiveAccount` on session changes
- `lib/features/auth/presentation/screens/sign_up_screen.dart` — call on signup success (21.5)
- `lib/features/auth/presentation/screens/sign_in_screen_v2.dart` — call on signin success (21.7)
- `lib/features/auth/presentation/screens/account_picker_screen.dart` — call on switch (21.9)
- `lib/features/settings/presentation/screens/settings_screen.dart` — call on sign-out

### Dual-write pattern
```dart
class SessionPersistenceService {
  final SharedPreferences _prefs;
  final DeviceRegistryDatabase _registry;
  
  static const _key = 'last_active_account_id';
  
  Future<void> setActiveAccount(String accountId) async {
    await _prefs.setString(_key, accountId);
    await _registry.setLastActiveAccountId(accountId);
    await _registry.updateLastUsed(accountId, DateTime.now());
  }
  
  Future<void> clearActiveAccount() async {
    await _prefs.remove(_key);
    await _registry.setLastActiveAccountId(null);
  }
  
  String? getActiveAccountId() {
    return _prefs.getString(_key);
  }
}
```

### Why dual-write?
SharedPreferences is readable BEFORE Drift is initialized (synchronous-ish API via `SharedPreferences.getInstance()`). This lets the startup sequence know which account to open without waiting for the registry DB to initialize. The registry is the authoritative source; SharedPreferences is the fast cache.

### Guardrails
- ALWAYS write to BOTH stores — never just one
- On disagreement: trust registry, fix SharedPreferences
- `clearActiveAccount` must be called on EVERY sign-out path

### References
- [Source: lib/core/database/registry/device_registry_database.dart] — setLastActiveAccountId from 21.1
- [Source: lib/features/auth/presentation/providers/auth_state_provider.dart] — session lifecycle

## Dev Agent Record

### Agent Model Used
### Completion Notes List
### Change Log
