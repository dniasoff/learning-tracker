# Story 21.1: Device Account Registry

Status: done

## Story

As a user with multiple accounts,
I want the device to remember all my accounts across app restarts,
so that I can switch between them without re-entering credentials.

## Acceptance Criteria (ACs)

1. **Given** a fresh device with no accounts
   **When** the first account is created via sign-up
   **Then** `device_registry.db` is created with one row in `device_accounts` and `lastActiveAccountId` set

2. **Given** 5 accounts already exist in the registry
   **When** a 6th account creation is attempted
   **Then** `MaxAccountsReachedException` is thrown and the registry remains at 5

3. **Given** a registry with 3 accounts
   **When** `findByEmail('alice@test.com')` is called
   **Then** the matching account row is returned (or null if not found), in < 50ms

4. **Given** a registry with accounts
   **When** the app restarts
   **Then** `lastActiveAccountId` is readable from `device_state` without opening any user DB

5. **Given** an account is removed from the registry
   **When** the registry is queried
   **Then** the account no longer appears and the count decreases by 1

## Tasks / Subtasks

- [ ] Create Drift database `DeviceRegistryDatabase` (AC: 1,4)
  - [ ] `lib/core/database/registry/device_registry_database.dart`
  - [ ] Table: `DeviceAccounts` (accountId TEXT PK, email TEXT, displayName TEXT, tier TEXT, firebaseUid TEXT nullable, avatarIndex INT default 0, createdAt DATETIME, lastUsedAt DATETIME, dbFileName TEXT UNIQUE)
  - [ ] Table: `DeviceState` (key TEXT PK, value TEXT)
  - [ ] schemaVersion: 1
- [ ] Create DAO methods (AC: 1,2,3,5)
  - [ ] `addAccount(DeviceAccountsCompanion)` — enforces max 5 with check before insert
  - [ ] `removeAccount(String accountId)` — deletes row
  - [ ] `findByEmail(String email)` — case-insensitive lookup
  - [ ] `findByFirebaseUid(String uid)` — for cloud-born lookups
  - [ ] `updateLastUsed(String accountId, DateTime time)`
  - [ ] `updateAccountTier(String accountId, String tier, String? firebaseUid)` — for upgrade flow
  - [ ] `getAllAccounts()` — returns List sorted by lastUsedAt desc
- [ ] Create device state helpers (AC: 4)
  - [ ] `getLastActiveAccountId()` → String?
  - [ ] `setLastActiveAccountId(String? accountId)` — null clears it
- [ ] Create providers (AC: 1,3,4)
  - [ ] `deviceRegistryProvider` — opens and owns the DB, `ref.onDispose(db.close)`
  - [ ] `deviceAccountsProvider` — watches `getAllAccounts()` stream
  - [ ] `lastActiveAccountIdProvider` — reads from device state
- [ ] Create `MaxAccountsReachedException` (AC: 2)
- [ ] Generate Drift code: `dart run build_runner build`
- [ ] Write unit test: add 5 accounts, 6th throws exception
- [ ] Write unit test: findByEmail returns correct match
- [ ] Write unit test: lastActiveAccountId survives DB close/reopen
- [ ] Write unit test: removeAccount decreases count

## Dev Notes

### Files to create
- `lib/core/database/registry/device_registry_database.dart` — Drift DB class + tables + DAO
- `lib/core/database/registry/tables/device_accounts.dart` — Drift table definition
- `lib/core/database/registry/tables/device_state.dart` — Drift table definition
- `lib/core/providers/registry_provider.dart` — Riverpod providers
- `test/core/database/registry/device_registry_test.dart` — unit tests

### Architecture decisions
- **Separate Drift database** from UserDatabase — different lifecycle, different file, different migration path
- The registry DB opens at app startup BEFORE any user DB. It's the "table of contents" for what's on this device
- `accountId` is a UUID v4 generated at signup time. NOT the email, NOT the firebaseUid — those can collide across tiers
- `dbFileName` stores the full filename (e.g., `user_acc_abc123.db`) so file management doesn't need to reconstruct it

### Why not SharedPreferences for the registry?
SharedPreferences can't do relational queries (findByEmail), doesn't support transactions, and has no schema enforcement. A tiny Drift DB is the right tool. SharedPreferences is still used for `last_active_account_id` as a fast pre-Drift read at startup.

### Max 5 enforcement
```dart
Future<void> addAccount(DeviceAccountsCompanion account) async {
  final count = await (selectOnly(deviceAccounts)..addColumns([deviceAccounts.accountId.count()])).getSingle();
  if (count >= 5) throw MaxAccountsReachedException();
  await into(deviceAccounts).insert(account);
}
```

### Testing
- Use `NativeDatabase.memory()` for unit tests (same as UserDatabase tests)
- Test the max-5 constraint explicitly
- Test findByEmail case-insensitivity

### Guardrails
- NEVER store passwords or password hashes in the registry — it only holds metadata
- The registry must be openable WITHOUT opening any user DB
- `accountId` must be stable across the lifetime of the account (UUID, never changes)

### References
- [Source: lib/core/database/user/user_database.dart] — pattern for Drift database class
- [Source: lib/core/providers/database_provider.dart] — pattern for database providers
- [Source: lib/core/database/daos/user_profile_dao.dart] — pattern for DAO methods

## Dev Agent Record

### Agent Model Used
### Completion Notes List
### Change Log
