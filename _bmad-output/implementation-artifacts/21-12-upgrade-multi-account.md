# Story 21.12: Local → Cloud Upgrade in Multi-Account Context

Status: ready-for-dev

## Story

As a local-born user on a multi-account device,
I want to upgrade my account to cloud-born,
so that my data is backed up and synced — using my existing email and password, not Google Sign-In.

## Acceptance Criteria (ACs)

1. **Given** a local-born account on a multi-account device
   **When** the user upgrades to cloud via Settings
   **Then** both the account's `user_acc_{id}.db` AND the device registry row show tier=cloudBorn and firebaseUid set

2. **Given** a successful upgrade
   **When** the user views the account picker
   **Then** the account tile shows cloud badge instead of local badge

3. **Given** a cloud-born account
   **When** the user opens Settings
   **Then** "Upgrade to Cloud" button is not shown

4. **Given** Firebase returns email-already-in-use during upgrade
   **Then** collision flow triggers, whichever merge option succeeds also updates the registry

## Tasks / Subtasks

- [ ] Extend `UpgradeToCloudService` to update device registry (AC: 1)
  - [ ] After `dao.upgradeLocalToCloud(...)` succeeds, call `registry.updateAccountTier(accountId, 'cloudBorn', firebaseUid)`
  - [ ] Add `updateAccountTier` method to `DeviceRegistryDatabase`
- [ ] Update `UpgradeToCloudScreen` collision handlers (AC: 4)
  - [ ] `executeUploadLocalIntoCloud` → also update registry
  - [ ] `executeKeepCloudDiscardLocal` → also update registry
- [ ] Verify picker shows updated badge (AC: 2)
  - [ ] Account picker reads from `deviceAccountsProvider` which watches registry → automatic
- [ ] Verify "Upgrade to Cloud" hidden for cloud-born (AC: 3)
  - [ ] Already gated on `authState.isLocalBorn` in Settings — verify still works with multi-account
- [ ] Write test: upgrade updates both DB and registry
- [ ] Write test: picker badge changes after upgrade

## Dev Notes

### Files to modify
- `lib/features/auth/domain/services/upgrade_to_cloud_service.dart` — add registry update after tier flip
- `lib/features/settings/presentation/screens/upgrade_to_cloud_screen.dart` — pass registry to collision handlers
- `lib/core/database/registry/device_registry_database.dart` — add `updateAccountTier` method

### Key principle: dual-write
The upgrade must update TWO stores atomically:
1. Account DB: `dao.upgradeLocalToCloud(profileId, firebaseUid, updatedAt)` — clears passwordHash, sets tier+firebaseUid
2. Device registry: `registry.updateAccountTier(accountId, 'cloudBorn', firebaseUid)` — updates tier+firebaseUid in registry row

If registry update fails after DB update, the account is cloud-born in the DB but local-born in the registry — inconsistency. To handle: if registry write fails, the next app launch can detect the mismatch (DB tier ≠ registry tier) and auto-correct the registry.

### No Google Sign-In for upgrades
The upgrade path is email + password ONLY. The user's existing local email and password are used to create the Firebase account. This avoids "which Google account?" confusion and keeps the flow simple.

### References
- [Source: lib/features/auth/domain/services/upgrade_to_cloud_service.dart] — existing upgrade service
- [Source: lib/features/settings/presentation/screens/upgrade_to_cloud_screen.dart] — existing upgrade UI
- [Source: lib/core/database/daos/user_profile_dao.dart:68] — upgradeLocalToCloud atomic transaction

## Dev Agent Record

### Agent Model Used
### Completion Notes List
### Change Log
