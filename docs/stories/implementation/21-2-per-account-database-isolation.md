# Story 21.2: Per-Account Database Isolation & ActiveUserDatabaseProvider

Status: done

## Story

As a user switching between accounts,
I want each account's data isolated in its own database file,
so that my data never leaks into another account's view.

## Acceptance Criteria (ACs)

1. **Given** two accounts (Alice cloud-born, Bob local-born) on device
   **When** Alice is active
   **Then** all DAOs, repositories, and providers return only Alice's data

2. **Given** user switches from Alice to Bob
   **When** switch completes
   **Then** `activeUserDatabaseProvider` invalidates, opens Bob's DB, provider tree rebuilds — Alice's data not visible

3. **Given** an existing single-account installation upgrading
   **When** app launches first time post-update
   **Then** existing `user.db` renamed to `user_acc_{id}.db`, registry entry created

4. **Given** active account's DB file is missing (corruption)
   **When** app tries to open it
   **Then** account removed from registry, "Account data was lost" shown

## Tasks / Subtasks

- [ ] Create `ActiveUserDatabaseProvider` (AC: 1,2)
  - [ ] Replace `userDatabaseProvider` in `lib/core/providers/database_provider.dart`
  - [ ] Watch `lastActiveAccountIdProvider` → open corresponding `user_acc_{id}.db`
  - [ ] `ref.onDispose` closes the DB
  - [ ] On account switch: provider invalidates → new DB opens → tree rebuilds
- [ ] Update ALL providers that reference `userDatabaseProvider` (AC: 1)
  - [ ] Run: `grep -rn 'userDatabaseProvider' lib/` to find all usages
  - [ ] Replace each with `activeUserDatabaseProvider`
  - [ ] Verify: zero references to old `userDatabaseProvider` remain
- [ ] Implement migration for existing installations (AC: 3)
  - [ ] On app startup: check if `user.db` exists AND registry is empty
  - [ ] If yes: read UserProfiles row, generate accountId, rename file, create registry entry
  - [ ] If no: normal startup
- [ ] Implement corruption recovery (AC: 4)
  - [ ] In `ActiveUserDatabaseProvider.build()`: wrap DB open in try/catch
  - [ ] On `FileSystemException` or `SqliteException`: remove from registry, show error
- [ ] Run `dart run build_runner build` for riverpod codegen
- [ ] Write test: two accounts, switching shows different data
- [ ] Write test: migration from single user.db
- [ ] Write test: missing DB file → graceful recovery

## Dev Notes

### Files to modify
- `lib/core/providers/database_provider.dart` — replace `userDatabaseProvider` with `activeUserDatabaseProvider`
- **47+ files** that reference `userDatabaseProvider` — all must be updated (grep to find them all)
- `lib/main.dart` — startup migration check

### This is the MOST INVASIVE change in Epic 21
Every DAO, repository, sync provider, and screen that touches user data flows through this provider. The change itself is mechanical (find-replace), but the sheer number of call sites means thorough testing is essential.

### File structure after this story
```
/databases/
  ├── content.db              ← shared, read-only (unchanged)
  ├── device_registry.db      ← from 21.1
  ├── user_acc_abc123.db      ← Account 1
  └── user_acc_def456.db      ← Account 2
```

### Provider architecture
```dart
@Riverpod(keepAlive: true)
UserDatabase activeUserDatabase(Ref ref) {
  final accountId = ref.watch(lastActiveAccountIdProvider);
  if (accountId == null) throw StateError('No active account');
  
  final registry = ref.read(deviceRegistryProvider);
  final account = registry.findById(accountId);
  if (account == null) throw StateError('Account not in registry');
  
  final dbPath = '${docsDir.path}/${account.dbFileName}';
  if (!File(dbPath).existsSync()) {
    registry.removeAccount(accountId);
    throw StateError('Account DB file missing');
  }
  
  final database = UserDatabase(driftDatabase(name: account.dbFileName));
  ref.onDispose(database.close);
  return database;
}
```

### Migration from single-account to multi-account
```dart
Future<void> migrateFromSingleAccount() async {
  final oldDbFile = File('${docsDir.path}/user.db');
  if (!oldDbFile.existsSync()) return; // nothing to migrate
  
  final registry = ref.read(deviceRegistryProvider);
  if ((await registry.getAllAccounts()).isNotEmpty) return; // already migrated
  
  // Open old DB to read the user's info
  final oldDb = UserDatabase(driftDatabase(name: 'user'));
  final profiles = await oldDb.userProfileDao.getAllUserProfiles();
  await oldDb.close();
  
  if (profiles.isEmpty) { oldDbFile.deleteSync(); return; }
  
  final profile = profiles.first;
  final accountId = const Uuid().v4();
  final newFileName = 'user_acc_$accountId.db';
  
  // Rename the file
  oldDbFile.renameSync('${docsDir.path}/$newFileName');
  
  // Add to registry
  await registry.addAccount(DeviceAccountsCompanion.insert(
    accountId: accountId,
    email: profile.email,
    displayName: profile.displayName,
    tier: profile.tier,
    firebaseUid: Value(profile.firebaseUid),
    dbFileName: newFileName,
    createdAt: profile.createdAt,
    lastUsedAt: DateTime.now(),
  ));
  
  await registry.setLastActiveAccountId(accountId);
}
```

### Testing
- Create two in-memory DBs, switch between them, verify isolation
- Test migration: create a `user.db` file, run migration, verify renamed + registry entry

### Guardrails
- NEVER open two user DBs simultaneously — close the old one before opening the new one
- NEVER skip the migration check on startup
- The content DB is NOT affected — it stays as `content.db`, shared across all accounts
- After migration, `user.db` must NOT exist (renamed, not copied)

### References
- [Source: lib/core/providers/database_provider.dart] — current userDatabaseProvider to replace
- [Source: lib/core/database/user/user_database.dart] — UserDatabase class
- [Source: lib/features/auth/presentation/providers/auth_state_provider.dart] — reads userDatabaseProvider

## Dev Agent Record

### Agent Model Used
### Completion Notes List
### Change Log
