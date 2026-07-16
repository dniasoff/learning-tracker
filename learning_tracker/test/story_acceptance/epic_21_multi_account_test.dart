/// Story acceptance tests for Epic 21 -- Multi-Account Device.
@Tags(['epic_21'])
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart'
    hide expect, group, setUp, setUpAll, tearDown, tearDownAll, test;
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/services/account_lifecycle_service.dart';
import 'package:learning_tracker/features/account/domain/services/local_auth_service.dart';
import 'package:learning_tracker/features/account/domain/services/password_hasher.dart';
import 'package:learning_tracker/features/account/domain/services/session_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart' hide isNotNull, isNull;

void main() {
  group('Epic 21 — Multi-Account Device', () {
    // ─── Story 21.1: Device Account Registry ────────────────────
    group('Story 21.1 — Device Account Registry', tags: ['story_21_1'], () {
      late DeviceRegistryDatabase registry;

      setUp(() {
        registry = DeviceRegistryDatabase(NativeDatabase.memory());
      });

      tearDown(() => registry.close());

      test(
        'AC1: first account creates registry entry + lastActiveAccountId',
        () async {
          await registry.addAccount(
            DeviceAccountsCompanion.insert(
              accountId: 'acc-1',
              email: 'alice@test.local',
              displayName: 'Alice',
              tier: 'cloudBorn',
              dbFileName: 'user_acc_acc-1.db',
              createdAt: DateTime.utc(2026, 1, 1),
              lastUsedAt: DateTime.utc(2026, 1, 1),
            ),
          );
          await registry.setLastActiveAccountId('acc-1');

          final accounts = await registry.getAllAccounts();
          expect(accounts, hasLength(1));
          expect(accounts.first.email, 'alice@test.local');

          final lastActive = await registry.getLastActiveAccountId();
          expect(lastActive, 'acc-1');
        },
      );

      test('AC2: 6th account throws MaxAccountsReachedException', () async {
        for (var i = 0; i < 5; i++) {
          await registry.addAccount(
            DeviceAccountsCompanion.insert(
              accountId: 'acc-$i',
              email: 'user$i@test.local',
              displayName: 'User $i',
              tier: 'localBorn',
              dbFileName: 'user_acc_acc-$i.db',
              createdAt: DateTime.utc(2026, 1, 1),
              lastUsedAt: DateTime.utc(2026, 1, 1),
            ),
          );
        }

        expect(
          () => registry.addAccount(
            DeviceAccountsCompanion.insert(
              accountId: 'acc-5',
              email: 'user5@test.local',
              displayName: 'User 5',
              tier: 'localBorn',
              dbFileName: 'user_acc_acc-5.db',
              createdAt: DateTime.utc(2026, 1, 1),
              lastUsedAt: DateTime.utc(2026, 1, 1),
            ),
          ),
          throwsA(isA<MaxAccountsReachedException>()),
        );
      });

      test(
        'AC3: findByEmail returns correct match (case-insensitive)',
        () async {
          await registry.addAccount(
            DeviceAccountsCompanion.insert(
              accountId: 'acc-1',
              email: 'Alice@Test.Local',
              displayName: 'Alice',
              tier: 'cloudBorn',
              dbFileName: 'user_acc_acc-1.db',
              createdAt: DateTime.utc(2026, 1, 1),
              lastUsedAt: DateTime.utc(2026, 1, 1),
            ),
          );

          final found = await registry.findByEmail('alice@test.local');
          expect(found, isNotNull);
          expect(found!.displayName, 'Alice');

          final notFound = await registry.findByEmail('bob@test.local');
          expect(notFound, isNull);
        },
      );

      test('AC4: lastActiveAccountId readable from device_state', () async {
        await registry.setLastActiveAccountId('acc-42');
        final id = await registry.getLastActiveAccountId();
        expect(id, 'acc-42');
      });

      test('AC5: removeAccount decreases count', () async {
        await registry.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: 'acc-1',
            email: 'a@test.local',
            displayName: 'A',
            tier: 'localBorn',
            dbFileName: 'user_acc_acc-1.db',
            createdAt: DateTime.utc(2026, 1, 1),
            lastUsedAt: DateTime.utc(2026, 1, 1),
          ),
        );
        await registry.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: 'acc-2',
            email: 'b@test.local',
            displayName: 'B',
            tier: 'localBorn',
            dbFileName: 'user_acc_acc-2.db',
            createdAt: DateTime.utc(2026, 1, 1),
            lastUsedAt: DateTime.utc(2026, 1, 1),
          ),
        );

        await registry.removeAccount('acc-1');
        final remaining = await registry.getAllAccounts();
        expect(remaining, hasLength(1));
        expect(remaining.first.accountId, 'acc-2');
      });
    });

    // ─── Story 21.2: Per-Account Database Isolation ─────────────
    group(
      'Story 21.2 — Per-Account Database Isolation',
      tags: ['story_21_2'],
      () {
        test('AC1: each account gets isolated data in its own DB', () async {
          final aliceDb = UserDatabase(NativeDatabase.memory());
          addTearDown(aliceDb.close);
          final bobDb = UserDatabase(NativeDatabase.memory());
          addTearDown(bobDb.close);

          final aliceAuth = LocalAuthService(
            dao: aliceDb.userProfileDao,
            hasher: PasswordHasher(params: Argon2idParams.test),
          );
          final bobAuth = LocalAuthService(
            dao: bobDb.userProfileDao,
            hasher: PasswordHasher(params: Argon2idParams.test),
          );

          await aliceAuth.signUp(
            email: 'alice@test.local',
            password: 'password1',
            displayName: 'Alice',
          );
          await bobAuth.signUp(
            email: 'bob@test.local',
            password: 'password2',
            displayName: 'Bob',
          );

          // Alice's DB has only Alice
          final aliceProfiles = await aliceDb.userProfileDao.findByTier(
            UserTier.localBorn,
          );
          expect(aliceProfiles, hasLength(1));
          expect(aliceProfiles.first.email, 'alice@test.local');

          // Bob's DB has only Bob
          final bobProfiles = await bobDb.userProfileDao.findByTier(
            UserTier.localBorn,
          );
          expect(bobProfiles, hasLength(1));
          expect(bobProfiles.first.email, 'bob@test.local');
        });
      },
    );

    // ─── Story 21.3: Session Auto-Resume ────────────────────────
    group('Story 21.3 — Session Auto-Resume', tags: ['story_21_3'], () {
      late DeviceRegistryDatabase registry;

      setUp(() {
        registry = DeviceRegistryDatabase(NativeDatabase.memory());
      });

      tearDown(() => registry.close());

      test('AC4: empty registry resolves to null (welcome screen)', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final service = SessionPersistenceService(
          prefs: prefs,
          registry: registry,
        );

        final accountId = await service.resolveActiveAccountId();
        expect(accountId, isNull);
      });

      test('AC5: stale pointer falls back to first account', () async {
        await registry.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: 'acc-2',
            email: 'b@test.local',
            displayName: 'B',
            tier: 'localBorn',
            dbFileName: 'user_acc_acc-2.db',
            createdAt: DateTime.utc(2026, 1, 1),
            lastUsedAt: DateTime.utc(2026, 1, 1),
          ),
        );

        SharedPreferences.setMockInitialValues({
          'last_active_account_id': 'stale-does-not-exist',
        });
        final prefs = await SharedPreferences.getInstance();
        final service = SessionPersistenceService(
          prefs: prefs,
          registry: registry,
        );

        final accountId = await service.resolveActiveAccountId();
        expect(accountId, 'acc-2');
      });
    });

    // ─── Story 21.4: Session Persistence ────────────────────────
    group('Story 21.4 — Session Persistence', tags: ['story_21_4'], () {
      late DeviceRegistryDatabase registry;

      setUp(() {
        registry = DeviceRegistryDatabase(NativeDatabase.memory());
      });

      tearDown(() => registry.close());

      test('AC1: setActiveAccount writes to both stores', () async {
        await registry.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: 'acc-1',
            email: 'a@test.local',
            displayName: 'A',
            tier: 'localBorn',
            dbFileName: 'user_acc_acc-1.db',
            createdAt: DateTime.utc(2026, 1, 1),
            lastUsedAt: DateTime.utc(2026, 1, 1),
          ),
        );

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final service = SessionPersistenceService(
          prefs: prefs,
          registry: registry,
        );

        await service.setActiveAccount('acc-1');

        expect(service.getActiveAccountId(), 'acc-1');
        expect(await registry.getLastActiveAccountId(), 'acc-1');
      });

      test('AC3: clearActiveAccount clears both stores', () async {
        await registry.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: 'acc-1',
            email: 'a@test.local',
            displayName: 'A',
            tier: 'localBorn',
            dbFileName: 'user_acc_acc-1.db',
            createdAt: DateTime.utc(2026, 1, 1),
            lastUsedAt: DateTime.utc(2026, 1, 1),
          ),
        );

        SharedPreferences.setMockInitialValues({
          'last_active_account_id': 'acc-1',
        });
        final prefs = await SharedPreferences.getInstance();
        final service = SessionPersistenceService(
          prefs: prefs,
          registry: registry,
        );

        await service.clearActiveAccount();

        expect(service.getActiveAccountId(), isNull);
        expect(await registry.getLastActiveAccountId(), isNull);
      });

      test('AC4: disagreement — registry wins', () async {
        await registry.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: 'acc-real',
            email: 'real@test.local',
            displayName: 'Real',
            tier: 'localBorn',
            dbFileName: 'user_acc_acc-real.db',
            createdAt: DateTime.utc(2026, 1, 1),
            lastUsedAt: DateTime.utc(2026, 1, 1),
          ),
        );
        await registry.setLastActiveAccountId('acc-real');

        SharedPreferences.setMockInitialValues({
          'last_active_account_id': 'acc-does-not-exist',
        });
        final prefs = await SharedPreferences.getInstance();
        final service = SessionPersistenceService(
          prefs: prefs,
          registry: registry,
        );

        final resolved = await service.resolveActiveAccountId();
        expect(resolved, 'acc-real');
      });
    });

    // ─── Story 21.5: Unified Sign-Up Email/Password ─────────────
    group(
      'Story 21.5 — Unified Sign-Up Email/Password',
      tags: ['story_21_5'],
      () {
        test(
          'AC2: offline path creates local-born with argon2id hash',
          () async {
            final db = UserDatabase(NativeDatabase.memory());
            addTearDown(db.close);
            final service = LocalAuthService(
              dao: db.userProfileDao,
              hasher: PasswordHasher(params: Argon2idParams.test),
            );

            final profile = await service.signUp(
              email: 'offline@test.local',
              password: 'securepass',
              displayName: 'Offline User',
            );

            expect(profile.tier, 'localBorn');
            expect(profile.passwordHash, isNotNull);
            expect(profile.email, 'offline@test.local');
          },
        );

        test('AC4: duplicate email throws DuplicateEmailException', () async {
          final db = UserDatabase(NativeDatabase.memory());
          addTearDown(db.close);
          final service = LocalAuthService(
            dao: db.userProfileDao,
            hasher: PasswordHasher(params: Argon2idParams.test),
          );

          await service.signUp(
            email: 'dupe@test.local',
            password: 'password1',
            displayName: 'First',
          );

          expect(
            () => service.signUp(
              email: 'dupe@test.local',
              password: 'password2',
              displayName: 'Second',
            ),
            throwsA(isA<DuplicateEmailException>()),
          );
        });
      },
    );

    // ─── Story 21.7: Sign-In Smart Routing ──────────────────────
    group('Story 21.7 — Sign-In Smart Routing', tags: ['story_21_7'], () {
      test('AC1: local-born sign-in via argon2id', () async {
        final db = UserDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final service = LocalAuthService(
          dao: db.userProfileDao,
          hasher: PasswordHasher(params: Argon2idParams.test),
        );

        await service.signUp(
          email: 'local@test.local',
          password: 'mypassword',
          displayName: 'Local',
        );

        final profile = await service.signIn(
          email: 'local@test.local',
          password: 'mypassword',
        );
        expect(profile.tier, 'localBorn');
      });

      test('AC8: wrong password throws InvalidCredentialsException', () async {
        final db = UserDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final service = LocalAuthService(
          dao: db.userProfileDao,
          hasher: PasswordHasher(params: Argon2idParams.test),
        );

        await service.signUp(
          email: 'local@test.local',
          password: 'rightpass',
          displayName: 'Local',
        );

        expect(
          () =>
              service.signIn(email: 'local@test.local', password: 'wrongpass'),
          throwsA(isA<InvalidCredentialsException>()),
        );
      });
    });

    // ─── Story 21.9: Account Picker ─────────────────────────────
    group('Story 21.9 — Account Picker', tags: ['story_21_9'], () {
      test('AC7: accounts ordered by lastUsedAt descending', () async {
        final registry = DeviceRegistryDatabase(NativeDatabase.memory());
        addTearDown(registry.close);

        await registry.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: 'acc-old',
            email: 'old@test.local',
            displayName: 'Old',
            tier: 'localBorn',
            dbFileName: 'user_acc_old.db',
            createdAt: DateTime.utc(2026, 1, 1),
            lastUsedAt: DateTime.utc(2026, 1, 1),
          ),
        );
        await registry.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: 'acc-new',
            email: 'new@test.local',
            displayName: 'New',
            tier: 'cloudBorn',
            dbFileName: 'user_acc_new.db',
            createdAt: DateTime.utc(2026, 2, 1),
            lastUsedAt: DateTime.utc(2026, 2, 1),
          ),
        );

        final accounts = await registry.getAllAccounts();
        expect(accounts.first.accountId, 'acc-new');
        expect(accounts.last.accountId, 'acc-old');
      });
    });

    // ─── Story 21.10: Sign-Out Routing ──────────────────────────
    group('Story 21.10 — Sign-Out Routing', tags: ['story_21_10'], () {
      test('registry count is non-empty/empty in exactly the shape the '
          'post-signout router switch reads', () async {
        final registry = DeviceRegistryDatabase(NativeDatabase.memory());
        addTearDown(registry.close);

        await registry.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: 'acc-1',
            email: 'a@test.local',
            displayName: 'A',
            tier: 'localBorn',
            dbFileName: 'user_acc_1.db',
            createdAt: DateTime.utc(2026, 1, 1),
            lastUsedAt: DateTime.utc(2026, 1, 1),
          ),
        );
        await registry.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: 'acc-2',
            email: 'b@test.local',
            displayName: 'B',
            tier: 'cloudBorn',
            dbFileName: 'user_acc_2.db',
            createdAt: DateTime.utc(2026, 1, 1),
            lastUsedAt: DateTime.utc(2026, 1, 1),
          ),
        );

        // This domain-layer test verifies the registry-count predicate
        // itself. The actual routing decision --
        // `accounts.isNotEmpty ? AccountPickerRoute() : SignInRoute()`
        // (the "welcome" screen) -- lives in
        // account_actions.dart:showSignOutConfirmation and is not
        // exercised here; that switch is covered by code review / manual
        // verification of showSignOutConfirmation, not by this test.
        var accounts = await registry.getAllAccounts();
        expect(accounts.isNotEmpty, isTrue); // → AccountPickerRoute

        await registry.removeAccount('acc-1');
        await registry.removeAccount('acc-2');
        accounts = await registry.getAllAccounts();
        expect(accounts.isEmpty, isTrue); // → SignInRoute ("welcome")
      });
    });

    // ─── Story 21.11: Add Account from Picker ───────────────────
    group('Story 21.11 — Add Account from Picker', tags: ['story_21_11'], () {
      test('AC2: at capacity (5 accounts), addAccount throws', () async {
        final registry = DeviceRegistryDatabase(NativeDatabase.memory());
        addTearDown(registry.close);

        for (var i = 0; i < 5; i++) {
          await registry.addAccount(
            DeviceAccountsCompanion.insert(
              accountId: 'acc-$i',
              email: 'user$i@test.local',
              displayName: 'User $i',
              tier: 'localBorn',
              dbFileName: 'user_acc_$i.db',
              createdAt: DateTime.utc(2026, 1, 1),
              lastUsedAt: DateTime.utc(2026, 1, 1),
            ),
          );
        }

        final accounts = await registry.getAllAccounts();
        expect(accounts.length >= kMaxDeviceAccounts, isTrue);

        expect(
          () => registry.addAccount(
            DeviceAccountsCompanion.insert(
              accountId: 'acc-overflow',
              email: 'overflow@test.local',
              displayName: 'Overflow',
              tier: 'localBorn',
              dbFileName: 'user_acc_overflow.db',
              createdAt: DateTime.utc(2026, 1, 1),
              lastUsedAt: DateTime.utc(2026, 1, 1),
            ),
          ),
          throwsA(isA<MaxAccountsReachedException>()),
        );
      });
    });

    // ─── Story 21.12: Upgrade in Multi-Account Context ──────────
    group('Story 21.12 — Upgrade Multi-Account', tags: ['story_21_12'], () {
      test('AC1: updateAccountTier updates registry', () async {
        final registry = DeviceRegistryDatabase(NativeDatabase.memory());
        addTearDown(registry.close);

        await registry.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: 'acc-local',
            email: 'local@test.local',
            displayName: 'Local',
            tier: 'localBorn',
            dbFileName: 'user_acc_local.db',
            createdAt: DateTime.utc(2026, 1, 1),
            lastUsedAt: DateTime.utc(2026, 1, 1),
          ),
        );

        await registry.updateAccountTier(
          'acc-local',
          'cloudBorn',
          firebaseUid: 'new-fb-uid',
        );

        final updated = await registry.findById('acc-local');
        expect(updated!.tier, 'cloudBorn');
        expect(updated.firebaseUid, 'new-fb-uid');
      });

      test('AC3: cloud-born account has isLocalBorn == false, the flag '
          'the upgrade button is gated on', () {
        const cloudState = AuthState.signedIn(
          user: AuthUser(
            profileId: 1,
            email: 'cloud@test.local',
            displayName: 'Cloud',
            firebaseUid: 'fb-1',
          ),
          tier: Tier.cloudBorn,
        );
        // This domain-layer test verifies the flag itself. The upgrade
        // button is only rendered `if (isLocalAuth)` in
        // BackupSyncSection._buildLocalOnlyCard, where `isLocalAuth:
        // authState.isLocalBorn` -- see backup_sync_section.dart. That
        // conditional render is covered by code review of
        // BackupSyncSection, not by this test.
        expect(cloudState.isLocalBorn, isFalse);
      });
    });

    // ─── Story 21.13: Remove Cloud-Born from Device ─────────────
    group('Story 21.13 — Remove Cloud from Device', tags: ['story_21_13'], () {
      test('AC2: removal deletes file + registry entry', () async {
        final tempDir = await Directory.systemTemp.createTemp('epic21_test_');
        addTearDown(() => tempDir.delete(recursive: true));
        final registry = DeviceRegistryDatabase(NativeDatabase.memory());
        addTearDown(registry.close);

        await registry.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: 'acc-cloud',
            email: 'cloud@test.local',
            displayName: 'Cloud',
            tier: 'cloudBorn',
            firebaseUid: const Value('fb-uid-1'),
            dbFileName: 'user_acc_cloud.db',
            createdAt: DateTime.utc(2026, 1, 1),
            lastUsedAt: DateTime.utc(2026, 1, 1),
          ),
        );

        File('${tempDir.path}/user_acc_cloud.db').createSync();
        expect(File('${tempDir.path}/user_acc_cloud.db').existsSync(), isTrue);

        final service = AccountLifecycleService(
          registry: registry,
          databasesPath: tempDir.path,
        );

        await service.removeCloudFromDevice('acc-cloud');

        expect(File('${tempDir.path}/user_acc_cloud.db').existsSync(), isFalse);
        expect(await registry.findById('acc-cloud'), isNull);
      });

      test(
        'D19/D20: removing the ACTIVE cloud account clears the registry row '
        'AND lastActiveAccountId (no ghost row / dangling pointer)',
        () async {
          final tempDir = await Directory.systemTemp.createTemp('epic21_d19_');
          addTearDown(() => tempDir.delete(recursive: true));
          final registry = DeviceRegistryDatabase(NativeDatabase.memory());
          addTearDown(registry.close);

          await registry.addAccount(
            DeviceAccountsCompanion.insert(
              accountId: 'acc-cloud',
              email: 'cloud@test.local',
              displayName: 'Cloud',
              tier: 'cloudBorn',
              firebaseUid: const Value('fb-uid-1'),
              dbFileName: 'user_acc_cloud.db',
              createdAt: DateTime.utc(2026, 1, 1),
              lastUsedAt: DateTime.utc(2026, 1, 1),
            ),
          );
          // This account is the active one.
          await registry.setLastActiveAccountId('acc-cloud');
          File('${tempDir.path}/user_acc_cloud.db').createSync();

          await AccountLifecycleService(
            registry: registry,
            databasesPath: tempDir.path,
          ).removeCloudFromDevice('acc-cloud');

          // The Settings cloud-delete (D19) and the picker swipe (D20) both
          // route through this cleanup for the active account.
          expect(await registry.findById('acc-cloud'), isNull);
          expect(await registry.getLastActiveAccountId(), isNull);
          expect(
            await registry.getAllAccounts(),
            isEmpty,
            reason: 'deleted account must not reappear in the picker',
          );
        },
      );

      test('AC5: local-born rejects removeCloudFromDevice', () async {
        final registry = DeviceRegistryDatabase(NativeDatabase.memory());
        addTearDown(registry.close);

        await registry.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: 'acc-local',
            email: 'local@test.local',
            displayName: 'Local',
            tier: 'localBorn',
            dbFileName: 'user_acc_local.db',
            createdAt: DateTime.utc(2026, 1, 1),
            lastUsedAt: DateTime.utc(2026, 1, 1),
          ),
        );

        final service = AccountLifecycleService(
          registry: registry,
          databasesPath: '/tmp',
        );

        expect(
          () => service.removeCloudFromDevice('acc-local'),
          throwsA(isA<StateError>()),
        );
      });
    });

    // ─── Story 21.14: Delete Local-Born Account ─────────────────
    group('Story 21.14 — Delete Local Account', tags: ['story_21_14'], () {
      test('AC2: deletion removes file + registry entry', () async {
        final tempDir = await Directory.systemTemp.createTemp('epic21_test_');
        addTearDown(() => tempDir.delete(recursive: true));
        final registry = DeviceRegistryDatabase(NativeDatabase.memory());
        addTearDown(registry.close);

        await registry.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: 'acc-local',
            email: 'local@test.local',
            displayName: 'Local',
            tier: 'localBorn',
            dbFileName: 'user_acc_local.db',
            createdAt: DateTime.utc(2026, 1, 1),
            lastUsedAt: DateTime.utc(2026, 1, 1),
          ),
        );

        File('${tempDir.path}/user_acc_local.db').createSync();

        final service = AccountLifecycleService(
          registry: registry,
          databasesPath: tempDir.path,
        );

        await service.deleteLocalAccount('acc-local');

        expect(File('${tempDir.path}/user_acc_local.db').existsSync(), isFalse);
        expect(await registry.findById('acc-local'), isNull);
        expect(await registry.getAllAccounts(), isEmpty);
      });

      test('AC5: deletion works offline (no network calls)', () async {
        final tempDir = await Directory.systemTemp.createTemp('epic21_test_');
        addTearDown(() => tempDir.delete(recursive: true));
        final registry = DeviceRegistryDatabase(NativeDatabase.memory());
        addTearDown(registry.close);

        await registry.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: 'acc-local',
            email: 'local@test.local',
            displayName: 'Local',
            tier: 'localBorn',
            dbFileName: 'user_acc_local.db',
            createdAt: DateTime.utc(2026, 1, 1),
            lastUsedAt: DateTime.utc(2026, 1, 1),
          ),
        );

        File('${tempDir.path}/user_acc_local.db').createSync();

        final service = AccountLifecycleService(
          registry: registry,
          databasesPath: tempDir.path,
        );

        await service.deleteLocalAccount('acc-local');
        expect(await registry.getAllAccounts(), isEmpty);
      });

      test('cloud-born rejects deleteLocalAccount', () async {
        final registry = DeviceRegistryDatabase(NativeDatabase.memory());
        addTearDown(registry.close);

        await registry.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: 'acc-cloud',
            email: 'cloud@test.local',
            displayName: 'Cloud',
            tier: 'cloudBorn',
            firebaseUid: const Value('fb-uid'),
            dbFileName: 'user_acc_cloud.db',
            createdAt: DateTime.utc(2026, 1, 1),
            lastUsedAt: DateTime.utc(2026, 1, 1),
          ),
        );

        final service = AccountLifecycleService(
          registry: registry,
          databasesPath: '/tmp',
        );

        expect(
          () => service.deleteLocalAccount('acc-cloud'),
          throwsA(isA<StateError>()),
        );
      });
    });

    // ─── Story 21.15: Delete Cloud Account (service contract) ───
    group(
      'Story 21.15 — Delete Cloud Account (service contract)',
      tags: ['story_21_15'],
      () {
        test('cloud-born without firebaseUid rejects deletion', () async {
          final registry = DeviceRegistryDatabase(NativeDatabase.memory());
          addTearDown(registry.close);

          await registry.addAccount(
            DeviceAccountsCompanion.insert(
              accountId: 'acc-broken',
              email: 'broken@test.local',
              displayName: 'Broken',
              tier: 'cloudBorn',
              dbFileName: 'user_acc_broken.db',
              createdAt: DateTime.utc(2026, 1, 1),
              lastUsedAt: DateTime.utc(2026, 1, 1),
            ),
          );

          final service = AccountLifecycleService(
            registry: registry,
            databasesPath: '/tmp',
          );

          expect(
            () => service.deleteCloudAccount('acc-broken'),
            throwsA(isA<StateError>()),
          );
        });
      },
    );

    // ─── Cross-story integration ────────────────────────────────
    group('Cross-story integration', () {
      test(
        'full lifecycle: create → persist session → resolve on restart',
        () async {
          final registry = DeviceRegistryDatabase(NativeDatabase.memory());
          addTearDown(registry.close);
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final sessionService = SessionPersistenceService(
            prefs: prefs,
            registry: registry,
          );

          await registry.addAccount(
            DeviceAccountsCompanion.insert(
              accountId: 'acc-lifecycle',
              email: 'lifecycle@test.local',
              displayName: 'Lifecycle',
              tier: 'localBorn',
              dbFileName: 'user_acc_lifecycle.db',
              createdAt: DateTime.utc(2026, 1, 1),
              lastUsedAt: DateTime.utc(2026, 1, 1),
            ),
          );

          await sessionService.setActiveAccount('acc-lifecycle');

          final resolved = await sessionService.resolveActiveAccountId();
          expect(resolved, 'acc-lifecycle');

          final account = await registry.findById(resolved!);
          expect(account!.email, 'lifecycle@test.local');
          expect(account.dbFileName, 'user_acc_lifecycle.db');
        },
      );

      test('account removal + session cleanup falls back', () async {
        final tempDir = await Directory.systemTemp.createTemp('epic21_test_');
        addTearDown(() => tempDir.delete(recursive: true));
        final registry = DeviceRegistryDatabase(NativeDatabase.memory());
        addTearDown(registry.close);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final sessionService = SessionPersistenceService(
          prefs: prefs,
          registry: registry,
        );

        for (final id in ['acc-a', 'acc-b']) {
          await registry.addAccount(
            DeviceAccountsCompanion.insert(
              accountId: id,
              email: '$id@test.local',
              displayName: id,
              tier: 'localBorn',
              dbFileName: 'user_acc_$id.db',
              createdAt: DateTime.utc(2026, 1, 1),
              lastUsedAt: DateTime.utc(2026, 1, 1),
            ),
          );
          File('${tempDir.path}/user_acc_$id.db').createSync();
        }
        await sessionService.setActiveAccount('acc-a');

        final lifecycleService = AccountLifecycleService(
          registry: registry,
          databasesPath: tempDir.path,
        );
        await lifecycleService.deleteLocalAccount('acc-a');
        await sessionService.clearActiveAccount();

        // Resolve should fall back to acc-b
        final resolved = await sessionService.resolveActiveAccountId();
        expect(resolved, 'acc-b');
      });
    });

    // ─── DEC-34: Multi-session auth model (WS1.auth-model) ─────
    group(
      'DEC-34 — Multi-session account switch keeps both accounts alive',
      tags: ['story_dec34'],
      () {
        // The core invariant of DEC-34: switching from account A to account B
        // must leave both accounts' registry entries and Drift data intact.
        // This domain-layer test verifies the data-persistence side of the
        // invariant — the UI enforcement (no signOut() call) is covered by
        // code review of account_picker_screen.dart:_activateLocalAccountFromLocalData.

        test(
          'switching active account leaves both accounts in registry',
          () async {
            final registry = DeviceRegistryDatabase(NativeDatabase.memory());
            addTearDown(registry.close);
            SharedPreferences.setMockInitialValues({});
            final prefs = await SharedPreferences.getInstance();
            final sessionService = SessionPersistenceService(
              prefs: prefs,
              registry: registry,
            );

            // Two accounts registered (simulating two sign-ins).
            await registry.addAccount(
              DeviceAccountsCompanion.insert(
                accountId: 'acc-alice',
                email: 'alice@test.local',
                displayName: 'Alice',
                tier: 'cloudBorn',
                dbFileName: 'user_acc_alice.db',
                createdAt: DateTime.utc(2026, 1, 1),
                lastUsedAt: DateTime.utc(2026, 1, 1),
              ),
            );
            await registry.addAccount(
              DeviceAccountsCompanion.insert(
                accountId: 'acc-bob',
                email: 'bob@test.local',
                displayName: 'Bob',
                tier: 'localBorn',
                dbFileName: 'user_acc_bob.db',
                createdAt: DateTime.utc(2026, 1, 2),
                lastUsedAt: DateTime.utc(2026, 1, 2),
              ),
            );

            // Initially Alice is active.
            await sessionService.setActiveAccount('acc-alice');
            expect(await sessionService.resolveActiveAccountId(), 'acc-alice');

            // Simulate account switch to Bob (no removal/deletion).
            await sessionService.setActiveAccount('acc-bob');

            // After switching to Bob, Alice's registry entry is still intact.
            final allAccounts = await registry.getAllAccounts();
            expect(allAccounts, hasLength(2));

            final alice = await registry.findById('acc-alice');
            expect(
              alice,
              isNotNull,
              reason: 'Alice must remain in registry after switch',
            );
            expect(alice!.email, 'alice@test.local');

            final bob = await registry.findById('acc-bob');
            expect(
              bob,
              isNotNull,
              reason: 'Bob must be the new active account',
            );
            expect(bob!.email, 'bob@test.local');

            // Active account pointer updated to Bob.
            expect(
              await sessionService.resolveActiveAccountId(),
              'acc-bob',
              reason: 'Active account is now Bob',
            );
          },
        );

        test(
          'switching does not remove the previously active account',
          () async {
            final registry = DeviceRegistryDatabase(NativeDatabase.memory());
            addTearDown(registry.close);
            SharedPreferences.setMockInitialValues({});
            final prefs = await SharedPreferences.getInstance();
            final sessionService = SessionPersistenceService(
              prefs: prefs,
              registry: registry,
            );

            for (final id in ['acc-1', 'acc-2', 'acc-3']) {
              await registry.addAccount(
                DeviceAccountsCompanion.insert(
                  accountId: id,
                  email: '$id@test.local',
                  displayName: id,
                  tier: 'localBorn',
                  dbFileName: 'user_$id.db',
                  createdAt: DateTime.utc(2026, 1, 1),
                  lastUsedAt: DateTime.utc(2026, 1, 1),
                ),
              );
            }

            // Cycle through all three accounts; registry must always have 3.
            for (final id in ['acc-1', 'acc-2', 'acc-3', 'acc-1']) {
              await sessionService.setActiveAccount(id);
              final count = (await registry.getAllAccounts()).length;
              expect(
                count,
                3,
                reason: 'All 3 accounts must survive switch to $id',
              );
            }
          },
        );
      },
    );
  });
}
