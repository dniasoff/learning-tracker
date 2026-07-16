/// Unit tests for UpgradeToCloudService.
///
/// Covers:
///   • upgrade() — happy path: verify → create → reload (verified) → DB flip
///   • upgrade() — wrong password (null hash → immediate mismatch exception)
///   • upgrade() — already cloud-born profile throws StateError
///   • upgrade() — Firebase creates account but email unverified → sendVerification + signOut + UpgradeEmailNotVerifiedException
///   • upgrade() — email-already-in-use → sign-in succeeds + verified → proceeds to finalize
///   • upgrade() — email-already-in-use → sign-in wrong-password → EmailCollisionException
///   • upgrade() — email-already-in-use → sign-in invalid-credential → EmailCollisionException
///   • upgrade() — email-already-in-use → sign-in user-not-found → EmailCollisionException
///   • upgrade() — finalize refresh: unverified on second reload → UpgradeEmailNotVerifiedException
///   • upgrade() — registry updated when registry+accountId are both provided
///   • upgrade() — registry NOT updated when registry is null
///   • tryFinalizeVerifiedCloudUpgrade() — not local-born returns null immediately
///   • tryFinalizeVerifiedCloudUpgrade() — verified sign-in flips DB + returns profile
///   • tryFinalizeVerifiedCloudUpgrade() — unverified → signOut + null
///   • tryFinalizeVerifiedCloudUpgrade() — sign-in throws → signOut + null
///   • resendUpgradeVerification() — not local-born throws StateError
///   • resendUpgradeVerification() — null hash throws UpgradePasswordMismatchException
///   • resendUpgradeVerification() — verified existing account → signOut (no sendEmailVerification)
///   • resendUpgradeVerification() — unverified existing account → sendEmailVerification + signOut
///   • resendUpgradeVerification() — wrong-password sign-in → EmailCollisionException
///   • signInToExistingCloud() — delegates to authRepository.signInAndGetUser
///   • discardLocalCredentials() — clears passwordHash in DB
///   • executeUploadLocalIntoCloud() — verified cloud → DB flip + registry update
///   • executeUploadLocalIntoCloud() — unverified → UpgradeEmailNotVerifiedException
///   • executeKeepCloudDiscardLocal() — verified cloud → clears hash + DB flip
///   • executeKeepCloudDiscardLocal() — unverified → UpgradeEmailNotVerifiedException
@Tags(['account', 'upgrade_to_cloud'])
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/account_tier.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/services/password_hasher.dart';
import 'package:learning_tracker/features/account/domain/services/upgrade_to_cloud_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_repositories.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class _MockPasswordHasher extends Mock implements PasswordHasher {}

// ── Fakes ────────────────────────────────────────────────────────────────────

class _FakeAppUser extends Fake implements AppUser {
  _FakeAppUser({
    required this.uid,
    this.emailVerified = true,
    String? emailOverride,
  }) : email = emailOverride ?? _email;

  @override
  final String uid;
  @override
  final bool emailVerified;
  @override
  final String? email;
  @override
  String? get displayName => 'Test User';
  @override
  List<String> get providers => const ['password'];
}

// ── Constants ─────────────────────────────────────────────────────────────────

const _email = 'tester@example.com';
const _password = 'secureP@ss1';
const _uid = 'firebase-uid-abc123';
const _storedHash = r'argon2id$m=256,t=1,p=1$aGFzaHNhbHQ=$aGFzaGVkdmFsdWU=';
const _accountId = 'acct-001';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Seeds a local-born account row into [db]. Returns the inserted row id.
Future<int> _seedLocalBorn(
  UserDatabase db, {
  String? hash = _storedHash,
}) async {
  return db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: _email,
          tier: UserTier.localBorn.dbValue,
          displayName: 'Test User',
          passwordHash: Value(hash),
          createdAt: DateTimeFactory.nowUtc(),
          updatedAt: DateTimeFactory.nowUtc(),
        ),
      );
}

/// Seeds a cloud-born account row into [db]. Returns the inserted row id.
Future<int> _seedCloudBorn(UserDatabase db) async {
  return db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: _email,
          tier: UserTier.cloudBorn.dbValue,
          displayName: 'Test User',
          firebaseUid: const Value(_uid),
          createdAt: DateTimeFactory.nowUtc(),
          updatedAt: DateTimeFactory.nowUtc(),
        ),
      );
}

/// Seeds a [DeviceAccount] row into [registry] using [accountId].
Future<void> _seedRegistry(DeviceRegistryDatabase registry) async {
  await registry.addAccount(
    DeviceAccountsCompanion.insert(
      accountId: _accountId,
      email: _email,
      displayName: 'Test User',
      tier: 'localBorn',
      createdAt: DateTimeFactory.nowUtc(),
      lastUsedAt: DateTimeFactory.nowUtc(),
      dbFileName: 'user_$_accountId.db',
    ),
  );
}

/// Builds a [UpgradeToCloudService] with a mock [PasswordHasher] and no
/// registry. The mock hasher is pre-stubbed to return [result] for any
/// [verify] call.
UpgradeToCloudService _buildService({
  required UserProfileDao dao,
  required MockAuthRepository auth,
  required _MockPasswordHasher hasher,
  bool verifyResult = true,
  DeviceRegistryDatabase? registry,
  String? accountId,
}) {
  when(
    () => hasher.verify(any<String>(), any<String>()),
  ).thenAnswer((_) async => verifyResult);
  return UpgradeToCloudService(
    dao: dao,
    authRepository: auth,
    hasher: hasher,
    registry: registry,
    accountId: accountId,
  );
}

// ── Test double for _extractFirebaseCode — an exception whose toString()
// embeds a Firebase error code in brackets.
class _FakeFirebaseException implements Exception {
  _FakeFirebaseException(this.code);
  final String code;

  @override
  String toString() => 'FirebaseAuthException: [$code] some message';
}

/// Mirrors the ACTUAL `firebase_auth` `FirebaseException.toString()` shape:
/// `[<plugin>/<code>] <message>`. See AUD-account-04 / AUD-account-10.
class _RealShapeFirebaseException implements Exception {
  _RealShapeFirebaseException(this.plugin, this.code);
  final String plugin;
  final String code;

  @override
  String toString() => '[$plugin/$code] some message.';
}

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  late UserDatabase db;
  late DeviceRegistryDatabase registry;
  late MockAuthRepository auth;
  late _MockPasswordHasher hasher;
  late UserProfileDao dao;

  setUp(() {
    db = UserDatabase(NativeDatabase.memory());
    registry = DeviceRegistryDatabase(NativeDatabase.memory());
    auth = MockAuthRepository();
    hasher = _MockPasswordHasher();
    dao = UserProfileDao(db);
  });

  tearDown(() async {
    await db.close();
    await registry.close();
  });

  // ── upgrade() ────────────────────────────────────────────────────────────────

  group('upgrade() — happy path', () {
    test(
      'verifies password, creates Firebase account, flips DB tier to cloudBorn',
      () async {
        final profileId = await _seedLocalBorn(db);
        final profile = (await dao.getUserProfileById(profileId))!;

        final verifiedUser = _FakeAppUser(uid: _uid, emailVerified: true);

        when(
          () => auth.createUserAccount(_email, _password),
        ).thenAnswer((_) async => _uid);
        when(
          () => auth.reloadCurrentUser(),
        ).thenAnswer((_) async => verifiedUser);
        when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
        when(() => auth.signOut()).thenAnswer((_) async {});

        final svc = _buildService(dao: dao, auth: auth, hasher: hasher);
        final result = await svc.upgrade(profile: profile, password: _password);

        // Tier flipped
        expect(result.tier, equals(UserTier.cloudBorn.dbValue));
        expect(result.firebaseUid, equals(_uid));
        // Password hash cleared
        expect(result.passwordHash, isNull);

        // Auth calls were made in the right sequence
        verify(() => auth.createUserAccount(_email, _password)).called(1);
        // reloadCurrentUser called at least once (once after create + once in _finalizeUpgrade)
        verify(() => auth.reloadCurrentUser()).called(greaterThanOrEqualTo(2));
        // sendEmailVerification NOT called on happy path
        verifyNever(() => auth.sendEmailVerification());
      },
    );

    test(
      'registry tier + firebaseUid updated when registry+accountId are provided',
      () async {
        final profileId = await _seedLocalBorn(db);
        final profile = (await dao.getUserProfileById(profileId))!;
        await _seedRegistry(registry);

        final verifiedUser = _FakeAppUser(uid: _uid, emailVerified: true);

        when(
          () => auth.createUserAccount(_email, _password),
        ).thenAnswer((_) async => _uid);
        when(
          () => auth.reloadCurrentUser(),
        ).thenAnswer((_) async => verifiedUser);
        when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
        when(() => auth.signOut()).thenAnswer((_) async {});

        final svc = _buildService(
          dao: dao,
          auth: auth,
          hasher: hasher,
          registry: registry,
          accountId: _accountId,
        );
        await svc.upgrade(profile: profile, password: _password);

        final updated = await registry.findById(_accountId);
        expect(updated!.tier, equals('cloudBorn'));
        expect(updated.firebaseUid, equals(_uid));
      },
    );

    test('registry NOT updated when registry is null', () async {
      final profileId = await _seedLocalBorn(db);
      final profile = (await dao.getUserProfileById(profileId))!;
      await _seedRegistry(registry);

      final verifiedUser = _FakeAppUser(uid: _uid, emailVerified: true);

      when(
        () => auth.createUserAccount(_email, _password),
      ).thenAnswer((_) async => _uid);
      when(
        () => auth.reloadCurrentUser(),
      ).thenAnswer((_) async => verifiedUser);
      when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
      when(() => auth.signOut()).thenAnswer((_) async {});

      // No registry passed
      final svc = _buildService(dao: dao, auth: auth, hasher: hasher);
      await svc.upgrade(profile: profile, password: _password);

      // Registry row stays localBorn
      final unchanged = await registry.findById(_accountId);
      expect(unchanged!.tier, equals('localBorn'));
    });
  });

  group('upgrade() — password verification failure', () {
    test('throws UpgradePasswordMismatchException when hash is null', () async {
      final profileId = await _seedLocalBorn(db, hash: null);
      final profile = (await dao.getUserProfileById(profileId))!;

      // With a null hash the service throws before calling the hasher at all
      final svc = UpgradeToCloudService(
        dao: dao,
        authRepository: auth,
        hasher: hasher,
      );

      expect(
        () => svc.upgrade(profile: profile, password: _password),
        throwsA(isA<UpgradePasswordMismatchException>()),
      );

      verifyNever(() => auth.createUserAccount(any<String>(), any<String>()));
    });

    test(
      'throws UpgradePasswordMismatchException when hasher.verify returns false',
      () async {
        final profileId = await _seedLocalBorn(db);
        final profile = (await dao.getUserProfileById(profileId))!;

        final svc = _buildService(
          dao: dao,
          auth: auth,
          hasher: hasher,
          verifyResult: false,
        );

        await expectLater(
          svc.upgrade(profile: profile, password: _password),
          throwsA(isA<UpgradePasswordMismatchException>()),
        );

        verifyNever(() => auth.createUserAccount(any<String>(), any<String>()));
      },
    );
  });

  group('upgrade() — already cloud-born', () {
    test('throws StateError when profile tier is cloudBorn', () async {
      final profileId = await _seedCloudBorn(db);
      final profile = (await dao.getUserProfileById(profileId))!;

      final svc = _buildService(dao: dao, auth: auth, hasher: hasher);

      await expectLater(
        svc.upgrade(profile: profile, password: _password),
        throwsStateError,
      );
    });
  });

  group('upgrade() — unverified email after account creation', () {
    test(
      'sends verification email, signs out, throws UpgradeEmailNotVerifiedException',
      () async {
        final profileId = await _seedLocalBorn(db);
        final profile = (await dao.getUserProfileById(profileId))!;

        final unverifiedUser = _FakeAppUser(uid: _uid, emailVerified: false);

        when(
          () => auth.createUserAccount(_email, _password),
        ).thenAnswer((_) async => _uid);
        when(
          () => auth.reloadCurrentUser(),
        ).thenAnswer((_) async => unverifiedUser);
        when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
        when(() => auth.signOut()).thenAnswer((_) async {});

        final svc = _buildService(dao: dao, auth: auth, hasher: hasher);

        await expectLater(
          svc.upgrade(profile: profile, password: _password),
          throwsA(isA<UpgradeEmailNotVerifiedException>()),
        );

        verify(() => auth.sendEmailVerification()).called(1);
        verify(() => auth.signOut()).called(1);
        // DB tier must NOT have been flipped
        final row = (await dao.getUserProfileById(profileId))!;
        expect(row.tier, equals(UserTier.localBorn.dbValue));
      },
    );

    test(
      'sends verification email + signs out when reload returns null',
      () async {
        final profileId = await _seedLocalBorn(db);
        final profile = (await dao.getUserProfileById(profileId))!;

        when(
          () => auth.createUserAccount(_email, _password),
        ).thenAnswer((_) async => _uid);
        when(() => auth.reloadCurrentUser()).thenAnswer((_) async => null);
        when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
        when(() => auth.signOut()).thenAnswer((_) async {});

        final svc = _buildService(dao: dao, auth: auth, hasher: hasher);

        await expectLater(
          svc.upgrade(profile: profile, password: _password),
          throwsA(isA<UpgradeEmailNotVerifiedException>()),
        );

        verify(() => auth.sendEmailVerification()).called(1);
        verify(() => auth.signOut()).called(1);
      },
    );
  });

  group('upgrade() — email-already-in-use retry path', () {
    test(
      'sign-in succeeds + verified → proceeds to finalize, returns cloudBorn profile',
      () async {
        final profileId = await _seedLocalBorn(db);
        final profile = (await dao.getUserProfileById(profileId))!;

        final verifiedUser = _FakeAppUser(uid: _uid, emailVerified: true);

        // First createUserAccount throws email-already-in-use
        when(
          () => auth.createUserAccount(_email, _password),
        ).thenThrow(_FakeFirebaseException('email-already-in-use'));
        when(
          () => auth.signInAndGetUser(_email, _password),
        ).thenAnswer((_) async => verifiedUser);
        when(
          () => auth.reloadCurrentUser(),
        ).thenAnswer((_) async => verifiedUser);
        when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
        when(() => auth.signOut()).thenAnswer((_) async {});

        final svc = _buildService(dao: dao, auth: auth, hasher: hasher);
        final result = await svc.upgrade(profile: profile, password: _password);

        expect(result.tier, equals(UserTier.cloudBorn.dbValue));
        expect(result.firebaseUid, equals(_uid));
        verify(() => auth.signInAndGetUser(_email, _password)).called(1);
      },
    );

    // AUD-account-04 / AUD-account-10: real FirebaseException.toString()
    // renders as "[firebase_auth/email-already-in-use] <message>" — the
    // plugin segment always precedes the code. The fixture above
    // (_FakeFirebaseException → "[$code] some message") uses the bare shape
    // and so never exercised the parser against the format Firebase
    // actually produces. This test uses the realistic shape.
    //
    // BUG LOG:
    //   - RED (pre-fix): _extractFirebaseCode's `RegExp(r'\[([a-z-]+)\]')`
    //     does not match "[firebase_auth/email-already-in-use]" (the
    //     character class excludes both `_` and `/`), so `code` resolved to
    //     null, the `code == 'email-already-in-use'` branch was skipped, and
    //     the original exception was rethrown instead of retrying the
    //     sign-in / raising EmailCollisionException.
    test('real "[plugin/code]" exception shape: email-already-in-use still '
        'triggers the retry-merge path', () async {
      final profileId = await _seedLocalBorn(db);
      final profile = (await dao.getUserProfileById(profileId))!;

      final verifiedUser = _FakeAppUser(uid: _uid, emailVerified: true);

      when(() => auth.createUserAccount(_email, _password)).thenThrow(
        _RealShapeFirebaseException('firebase_auth', 'email-already-in-use'),
      );
      when(
        () => auth.signInAndGetUser(_email, _password),
      ).thenAnswer((_) async => verifiedUser);
      when(
        () => auth.reloadCurrentUser(),
      ).thenAnswer((_) async => verifiedUser);

      final svc = _buildService(dao: dao, auth: auth, hasher: hasher);
      final result = await svc.upgrade(profile: profile, password: _password);

      expect(result.tier, equals(UserTier.cloudBorn.dbValue));
      expect(result.firebaseUid, equals(_uid));
      verify(() => auth.signInAndGetUser(_email, _password)).called(1);
    });

    test('sign-in throws wrong-password → EmailCollisionException', () async {
      final profileId = await _seedLocalBorn(db);
      final profile = (await dao.getUserProfileById(profileId))!;

      when(
        () => auth.createUserAccount(_email, _password),
      ).thenThrow(_FakeFirebaseException('email-already-in-use'));
      when(
        () => auth.signInAndGetUser(_email, _password),
      ).thenThrow(_FakeFirebaseException('wrong-password'));
      when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
      when(() => auth.signOut()).thenAnswer((_) async {});

      final svc = _buildService(dao: dao, auth: auth, hasher: hasher);

      await expectLater(
        svc.upgrade(profile: profile, password: _password),
        throwsA(isA<EmailCollisionException>()),
      );
    });

    test(
      'sign-in throws invalid-credential → EmailCollisionException',
      () async {
        final profileId = await _seedLocalBorn(db);
        final profile = (await dao.getUserProfileById(profileId))!;

        when(
          () => auth.createUserAccount(_email, _password),
        ).thenThrow(_FakeFirebaseException('email-already-in-use'));
        when(
          () => auth.signInAndGetUser(_email, _password),
        ).thenThrow(_FakeFirebaseException('invalid-credential'));
        when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
        when(() => auth.signOut()).thenAnswer((_) async {});

        final svc = _buildService(dao: dao, auth: auth, hasher: hasher);

        await expectLater(
          svc.upgrade(profile: profile, password: _password),
          throwsA(isA<EmailCollisionException>()),
        );
      },
    );

    test('sign-in throws user-not-found → EmailCollisionException', () async {
      final profileId = await _seedLocalBorn(db);
      final profile = (await dao.getUserProfileById(profileId))!;

      when(
        () => auth.createUserAccount(_email, _password),
      ).thenThrow(_FakeFirebaseException('email-already-in-use'));
      when(
        () => auth.signInAndGetUser(_email, _password),
      ).thenThrow(_FakeFirebaseException('user-not-found'));
      when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
      when(() => auth.signOut()).thenAnswer((_) async {});

      final svc = _buildService(dao: dao, auth: auth, hasher: hasher);

      await expectLater(
        svc.upgrade(profile: profile, password: _password),
        throwsA(isA<EmailCollisionException>()),
      );
    });

    test(
      'email-already-in-use + unverified existing account → sendVerification + signOut + UpgradeEmailNotVerifiedException',
      () async {
        final profileId = await _seedLocalBorn(db);
        final profile = (await dao.getUserProfileById(profileId))!;

        final unverifiedUser = _FakeAppUser(uid: _uid, emailVerified: false);

        when(
          () => auth.createUserAccount(_email, _password),
        ).thenThrow(_FakeFirebaseException('email-already-in-use'));
        when(
          () => auth.signInAndGetUser(_email, _password),
        ).thenAnswer((_) async => unverifiedUser);
        when(
          () => auth.reloadCurrentUser(),
        ).thenAnswer((_) async => unverifiedUser);
        when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
        when(() => auth.signOut()).thenAnswer((_) async {});

        final svc = _buildService(dao: dao, auth: auth, hasher: hasher);

        await expectLater(
          svc.upgrade(profile: profile, password: _password),
          throwsA(isA<UpgradeEmailNotVerifiedException>()),
        );

        verify(() => auth.sendEmailVerification()).called(1);
        verify(() => auth.signOut()).called(1);
      },
    );

    test(
      'non-firebase error from createUserAccount is rethrown unchanged',
      () async {
        final profileId = await _seedLocalBorn(db);
        final profile = (await dao.getUserProfileById(profileId))!;

        when(
          () => auth.createUserAccount(_email, _password),
        ).thenThrow(Exception('some-network-error'));
        when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
        when(() => auth.signOut()).thenAnswer((_) async {});

        final svc = _buildService(dao: dao, auth: auth, hasher: hasher);

        await expectLater(
          svc.upgrade(profile: profile, password: _password),
          throwsA(isA<Exception>()),
        );
      },
    );
  });

  group('upgrade() — finalize reload unverified', () {
    test(
      '_finalizeUpgrade: unverified on second reload → UpgradeEmailNotVerifiedException + no DB flip',
      () async {
        // First reload (after createUserAccount) returns verified,
        // second reload (inside _finalizeUpgrade) returns unverified.
        final profileId = await _seedLocalBorn(db);
        final profile = (await dao.getUserProfileById(profileId))!;

        final verifiedUser = _FakeAppUser(uid: _uid, emailVerified: true);
        final unverifiedUser = _FakeAppUser(uid: _uid, emailVerified: false);

        when(
          () => auth.createUserAccount(_email, _password),
        ).thenAnswer((_) async => _uid);
        // First call → verified, second call → unverified
        var callCount = 0;
        when(() => auth.reloadCurrentUser()).thenAnswer((_) async {
          callCount++;
          return callCount == 1 ? verifiedUser : unverifiedUser;
        });
        when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
        when(() => auth.signOut()).thenAnswer((_) async {});

        final svc = _buildService(dao: dao, auth: auth, hasher: hasher);

        await expectLater(
          svc.upgrade(profile: profile, password: _password),
          throwsA(isA<UpgradeEmailNotVerifiedException>()),
        );

        // DB tier must NOT have been flipped
        final row = (await dao.getUserProfileById(profileId))!;
        expect(row.tier, equals(UserTier.localBorn.dbValue));
      },
    );
  });

  // ── tryFinalizeVerifiedCloudUpgrade() ────────────────────────────────────────

  group('tryFinalizeVerifiedCloudUpgrade()', () {
    test(
      'returns null immediately when profile tier is not localBorn',
      () async {
        final profileId = await _seedCloudBorn(db);
        final profile = (await dao.getUserProfileById(profileId))!;

        final svc = _buildService(dao: dao, auth: auth, hasher: hasher);
        final result = await svc.tryFinalizeVerifiedCloudUpgrade(
          localProfile: profile,
          password: _password,
        );

        expect(result, isNull);
        verifyNever(() => auth.signInAndGetUser(any<String>(), any<String>()));
      },
    );

    test(
      'verified sign-in flips DB tier to cloudBorn and returns updated profile',
      () async {
        final profileId = await _seedLocalBorn(db);
        final profile = (await dao.getUserProfileById(profileId))!;

        final verifiedUser = _FakeAppUser(uid: _uid, emailVerified: true);

        when(
          () => auth.signInAndGetUser(_email, _password),
        ).thenAnswer((_) async => verifiedUser);
        when(
          () => auth.reloadCurrentUser(),
        ).thenAnswer((_) async => verifiedUser);
        when(() => auth.signOut()).thenAnswer((_) async {});

        final svc = _buildService(dao: dao, auth: auth, hasher: hasher);
        final result = await svc.tryFinalizeVerifiedCloudUpgrade(
          localProfile: profile,
          password: _password,
        );

        expect(result, isNotNull);
        expect(result!.tier, equals(UserTier.cloudBorn.dbValue));
        expect(result.firebaseUid, equals(_uid));
      },
    );

    test(
      'unverified sign-in → signs out and returns null (DB unchanged)',
      () async {
        final profileId = await _seedLocalBorn(db);
        final profile = (await dao.getUserProfileById(profileId))!;

        final unverifiedUser = _FakeAppUser(uid: _uid, emailVerified: false);

        when(
          () => auth.signInAndGetUser(_email, _password),
        ).thenAnswer((_) async => unverifiedUser);
        when(
          () => auth.reloadCurrentUser(),
        ).thenAnswer((_) async => unverifiedUser);
        when(() => auth.signOut()).thenAnswer((_) async {});

        final svc = _buildService(dao: dao, auth: auth, hasher: hasher);
        final result = await svc.tryFinalizeVerifiedCloudUpgrade(
          localProfile: profile,
          password: _password,
        );

        expect(result, isNull);
        verify(() => auth.signOut()).called(1);

        final row = (await dao.getUserProfileById(profileId))!;
        expect(row.tier, equals(UserTier.localBorn.dbValue));
      },
    );

    test('sign-in throws → signs out and returns null', () async {
      final profileId = await _seedLocalBorn(db);
      final profile = (await dao.getUserProfileById(profileId))!;

      when(
        () => auth.signInAndGetUser(_email, _password),
      ).thenThrow(Exception('wrong-password'));
      when(() => auth.signOut()).thenAnswer((_) async {});

      final svc = _buildService(dao: dao, auth: auth, hasher: hasher);
      final result = await svc.tryFinalizeVerifiedCloudUpgrade(
        localProfile: profile,
        password: _password,
      );

      expect(result, isNull);
      verify(() => auth.signOut()).called(1);
    });

    test(
      'registry updated when registry+accountId provided and sign-in verified',
      () async {
        final profileId = await _seedLocalBorn(db);
        final profile = (await dao.getUserProfileById(profileId))!;
        await _seedRegistry(registry);

        final verifiedUser = _FakeAppUser(uid: _uid, emailVerified: true);

        when(
          () => auth.signInAndGetUser(_email, _password),
        ).thenAnswer((_) async => verifiedUser);
        when(
          () => auth.reloadCurrentUser(),
        ).thenAnswer((_) async => verifiedUser);
        when(() => auth.signOut()).thenAnswer((_) async {});

        final svc = _buildService(
          dao: dao,
          auth: auth,
          hasher: hasher,
          registry: registry,
          accountId: _accountId,
        );
        await svc.tryFinalizeVerifiedCloudUpgrade(
          localProfile: profile,
          password: _password,
        );

        final updated = await registry.findById(_accountId);
        expect(updated!.tier, equals('cloudBorn'));
        expect(updated.firebaseUid, equals(_uid));
      },
    );
  });

  // ── resendUpgradeVerification() ──────────────────────────────────────────────

  group('resendUpgradeVerification()', () {
    test('throws StateError when profile is not local-born', () async {
      final profileId = await _seedCloudBorn(db);
      final profile = (await dao.getUserProfileById(profileId))!;

      final svc = _buildService(dao: dao, auth: auth, hasher: hasher);

      await expectLater(
        svc.resendUpgradeVerification(profile: profile, password: _password),
        throwsStateError,
      );
    });

    test('throws UpgradePasswordMismatchException when hash is null', () async {
      final profileId = await _seedLocalBorn(db, hash: null);
      final profile = (await dao.getUserProfileById(profileId))!;

      final svc = UpgradeToCloudService(
        dao: dao,
        authRepository: auth,
        hasher: hasher,
      );

      await expectLater(
        svc.resendUpgradeVerification(profile: profile, password: _password),
        throwsA(isA<UpgradePasswordMismatchException>()),
      );
    });

    test(
      'throws UpgradePasswordMismatchException when hasher.verify returns false',
      () async {
        final profileId = await _seedLocalBorn(db);
        final profile = (await dao.getUserProfileById(profileId))!;

        final svc = _buildService(
          dao: dao,
          auth: auth,
          hasher: hasher,
          verifyResult: false,
        );

        await expectLater(
          svc.resendUpgradeVerification(profile: profile, password: _password),
          throwsA(isA<UpgradePasswordMismatchException>()),
        );
      },
    );

    test(
      'already verified: sign out without calling sendEmailVerification',
      () async {
        final profileId = await _seedLocalBorn(db);
        final profile = (await dao.getUserProfileById(profileId))!;

        final verifiedUser = _FakeAppUser(uid: _uid, emailVerified: true);

        when(
          () => auth.signInAndGetUser(_email, _password),
        ).thenAnswer((_) async => verifiedUser);
        when(
          () => auth.reloadCurrentUser(),
        ).thenAnswer((_) async => verifiedUser);
        when(() => auth.signOut()).thenAnswer((_) async {});
        when(() => auth.sendEmailVerification()).thenAnswer((_) async {});

        final svc = _buildService(dao: dao, auth: auth, hasher: hasher);
        await svc.resendUpgradeVerification(
          profile: profile,
          password: _password,
        );

        verify(() => auth.signOut()).called(1);
        verifyNever(() => auth.sendEmailVerification());
      },
    );

    test('unverified: sends verification email then signs out', () async {
      final profileId = await _seedLocalBorn(db);
      final profile = (await dao.getUserProfileById(profileId))!;

      final unverifiedUser = _FakeAppUser(uid: _uid, emailVerified: false);

      when(
        () => auth.signInAndGetUser(_email, _password),
      ).thenAnswer((_) async => unverifiedUser);
      when(
        () => auth.reloadCurrentUser(),
      ).thenAnswer((_) async => unverifiedUser);
      when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
      when(() => auth.signOut()).thenAnswer((_) async {});

      final svc = _buildService(dao: dao, auth: auth, hasher: hasher);
      await svc.resendUpgradeVerification(
        profile: profile,
        password: _password,
      );

      verify(() => auth.sendEmailVerification()).called(1);
      verify(() => auth.signOut()).called(1);
    });

    test('sign-in throws wrong-password → EmailCollisionException', () async {
      final profileId = await _seedLocalBorn(db);
      final profile = (await dao.getUserProfileById(profileId))!;

      when(
        () => auth.signInAndGetUser(_email, _password),
      ).thenThrow(_FakeFirebaseException('wrong-password'));

      final svc = _buildService(dao: dao, auth: auth, hasher: hasher);

      await expectLater(
        svc.resendUpgradeVerification(profile: profile, password: _password),
        throwsA(isA<EmailCollisionException>()),
      );
    });

    test(
      'sign-in throws invalid-credential → EmailCollisionException',
      () async {
        final profileId = await _seedLocalBorn(db);
        final profile = (await dao.getUserProfileById(profileId))!;

        when(
          () => auth.signInAndGetUser(_email, _password),
        ).thenThrow(_FakeFirebaseException('invalid-credential'));

        final svc = _buildService(dao: dao, auth: auth, hasher: hasher);

        await expectLater(
          svc.resendUpgradeVerification(profile: profile, password: _password),
          throwsA(isA<EmailCollisionException>()),
        );
      },
    );
  });

  // ── signInToExistingCloud() ──────────────────────────────────────────────────

  group('signInToExistingCloud()', () {
    test(
      'delegates to authRepository.signInAndGetUser and returns AppUser',
      () async {
        final user = _FakeAppUser(uid: _uid);
        when(
          () => auth.signInAndGetUser(_email, _password),
        ).thenAnswer((_) async => user);

        final svc = _buildService(dao: dao, auth: auth, hasher: hasher);
        final result = await svc.signInToExistingCloud(
          email: _email,
          password: _password,
        );

        expect(result, same(user));
        verify(() => auth.signInAndGetUser(_email, _password)).called(1);
      },
    );

    test('returns null when authRepository returns null', () async {
      when(
        () => auth.signInAndGetUser(_email, _password),
      ).thenAnswer((_) async => null);

      final svc = _buildService(dao: dao, auth: auth, hasher: hasher);
      final result = await svc.signInToExistingCloud(
        email: _email,
        password: _password,
      );

      expect(result, isNull);
    });
  });

  // ── discardLocalCredentials() ────────────────────────────────────────────────

  group('discardLocalCredentials()', () {
    // REGRESSION GUARD (was a CRITICAL crash): discardLocalCredentials() used
    // updateUserProfile() → update(accounts).replace(entry), which requires a
    // COMPLETE row and threw InvalidDataException for the id+passwordHash-only
    // companion — crashing any collision-path user who chose "discard local".
    // Fixed by the dedicated UserProfileDao.clearPasswordHash() targeted write.
    test(
      'clears passwordHash in DB while preserving all other columns',
      () async {
        final profileId = await _seedLocalBorn(db);

        final svc = _buildService(dao: dao, auth: auth, hasher: hasher);
        await svc.discardLocalCredentials(profileId);

        final row = (await dao.getUserProfileById(profileId))!;
        expect(row.passwordHash, isNull);
        // Other columns preserved
        expect(row.email, equals(_email));
        expect(row.tier, equals(UserTier.localBorn.dbValue));
        expect(row.displayName, equals('Test User'));
      },
    );
  });

  // ── executeUploadLocalIntoCloud() ────────────────────────────────────────────

  group('executeUploadLocalIntoCloud()', () {
    test('verified cloud sign-in → DB flipped to cloudBorn', () async {
      final profileId = await _seedLocalBorn(db);
      final profile = (await dao.getUserProfileById(profileId))!;

      final verifiedUser = _FakeAppUser(uid: _uid, emailVerified: true);

      when(
        () => auth.signInAndGetUser(_email, _password),
      ).thenAnswer((_) async => verifiedUser);
      when(
        () => auth.reloadCurrentUser(),
      ).thenAnswer((_) async => verifiedUser);
      when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
      when(() => auth.signOut()).thenAnswer((_) async {});

      final svc = _buildService(dao: dao, auth: auth, hasher: hasher);
      final result = await svc.executeUploadLocalIntoCloud(
        localProfile: profile,
        cloudPassword: _password,
      );

      expect(result.tier, equals(UserTier.cloudBorn.dbValue));
      expect(result.firebaseUid, equals(_uid));
    });

    test(
      'unverified sign-in → sendEmailVerification + signOut + UpgradeEmailNotVerifiedException',
      () async {
        final profileId = await _seedLocalBorn(db);
        final profile = (await dao.getUserProfileById(profileId))!;

        final unverifiedUser = _FakeAppUser(uid: _uid, emailVerified: false);

        when(
          () => auth.signInAndGetUser(_email, _password),
        ).thenAnswer((_) async => unverifiedUser);
        when(
          () => auth.reloadCurrentUser(),
        ).thenAnswer((_) async => unverifiedUser);
        when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
        when(() => auth.signOut()).thenAnswer((_) async {});

        final svc = _buildService(dao: dao, auth: auth, hasher: hasher);

        await expectLater(
          svc.executeUploadLocalIntoCloud(
            localProfile: profile,
            cloudPassword: _password,
          ),
          throwsA(isA<UpgradeEmailNotVerifiedException>()),
        );

        verify(() => auth.sendEmailVerification()).called(1);
        verify(() => auth.signOut()).called(1);

        final row = (await dao.getUserProfileById(profileId))!;
        expect(row.tier, equals(UserTier.localBorn.dbValue));
      },
    );

    test('registry updated when registry+accountId provided', () async {
      final profileId = await _seedLocalBorn(db);
      final profile = (await dao.getUserProfileById(profileId))!;
      await _seedRegistry(registry);

      final verifiedUser = _FakeAppUser(uid: _uid, emailVerified: true);

      when(
        () => auth.signInAndGetUser(_email, _password),
      ).thenAnswer((_) async => verifiedUser);
      when(
        () => auth.reloadCurrentUser(),
      ).thenAnswer((_) async => verifiedUser);
      when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
      when(() => auth.signOut()).thenAnswer((_) async {});

      final svc = _buildService(
        dao: dao,
        auth: auth,
        hasher: hasher,
        registry: registry,
        accountId: _accountId,
      );
      await svc.executeUploadLocalIntoCloud(
        localProfile: profile,
        cloudPassword: _password,
      );

      final updated = await registry.findById(_accountId);
      expect(updated!.tier, equals('cloudBorn'));
      expect(updated.firebaseUid, equals(_uid));
    });
  });

  // ── executeKeepCloudDiscardLocal() ───────────────────────────────────────────

  group('executeKeepCloudDiscardLocal()', () {
    // REGRESSION GUARD: this path calls discardLocalCredentials() — previously a
    // CRITICAL crash (replace() on a partial row). Fixed via clearPasswordHash().
    test(
      'verified cloud sign-in → clears passwordHash + flips DB to cloudBorn',
      () async {
        final profileId = await _seedLocalBorn(db);
        final profile = (await dao.getUserProfileById(profileId))!;

        final verifiedUser = _FakeAppUser(uid: _uid, emailVerified: true);

        when(
          () => auth.signInAndGetUser(_email, _password),
        ).thenAnswer((_) async => verifiedUser);
        when(
          () => auth.reloadCurrentUser(),
        ).thenAnswer((_) async => verifiedUser);
        when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
        when(() => auth.signOut()).thenAnswer((_) async {});

        final svc = _buildService(dao: dao, auth: auth, hasher: hasher);
        final result = await svc.executeKeepCloudDiscardLocal(
          localProfile: profile,
          cloudPassword: _password,
        );

        expect(result.tier, equals(UserTier.cloudBorn.dbValue));
        expect(result.firebaseUid, equals(_uid));
        // Hash must have been cleared before upgrade
        expect(result.passwordHash, isNull);
      },
    );

    test(
      'unverified sign-in → sendEmailVerification + signOut + UpgradeEmailNotVerifiedException',
      () async {
        final profileId = await _seedLocalBorn(db);
        final profile = (await dao.getUserProfileById(profileId))!;

        final unverifiedUser = _FakeAppUser(uid: _uid, emailVerified: false);

        when(
          () => auth.signInAndGetUser(_email, _password),
        ).thenAnswer((_) async => unverifiedUser);
        when(
          () => auth.reloadCurrentUser(),
        ).thenAnswer((_) async => unverifiedUser);
        when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
        when(() => auth.signOut()).thenAnswer((_) async {});

        final svc = _buildService(dao: dao, auth: auth, hasher: hasher);

        await expectLater(
          svc.executeKeepCloudDiscardLocal(
            localProfile: profile,
            cloudPassword: _password,
          ),
          throwsA(isA<UpgradeEmailNotVerifiedException>()),
        );

        verify(() => auth.sendEmailVerification()).called(1);
        verify(() => auth.signOut()).called(1);
      },
    );

    test(
      'registry updated when registry+accountId provided on keep-cloud path',
      () async {
        final profileId = await _seedLocalBorn(db);
        final profile = (await dao.getUserProfileById(profileId))!;
        await _seedRegistry(registry);

        final verifiedUser = _FakeAppUser(uid: _uid, emailVerified: true);

        when(
          () => auth.signInAndGetUser(_email, _password),
        ).thenAnswer((_) async => verifiedUser);
        when(
          () => auth.reloadCurrentUser(),
        ).thenAnswer((_) async => verifiedUser);
        when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
        when(() => auth.signOut()).thenAnswer((_) async {});

        final svc = _buildService(
          dao: dao,
          auth: auth,
          hasher: hasher,
          registry: registry,
          accountId: _accountId,
        );
        await svc.executeKeepCloudDiscardLocal(
          localProfile: profile,
          cloudPassword: _password,
        );

        final updated = await registry.findById(_accountId);
        expect(updated!.tier, equals('cloudBorn'));
        expect(updated.firebaseUid, equals(_uid));
      },
    );
  });

  // ── upgradeWithNewCredentials() — credential-less (offline) path ──────────────

  group('upgradeWithNewCredentials() — credential-less path', () {
    const syntheticEmail = 'offline_abc123def456@offline.local';
    const realEmail = 'real@example.com';

    Future<int> seedSynthetic() => db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            email: syntheticEmail,
            tier: UserTier.localBorn.dbValue,
            displayName: '',
            passwordHash: const Value('synthetic-hash'),
            createdAt: DateTimeFactory.nowUtc(),
            updatedAt: DateTimeFactory.nowUtc(),
          ),
        );

    test('registers entered email+password, flips tier, replaces synthetic '
        'email, and never verifies a local password', () async {
      final profileId = await seedSynthetic();
      final profile = (await dao.getUserProfileById(profileId))!;
      final verifiedUser = _FakeAppUser(
        uid: _uid,
        emailVerified: true,
        emailOverride: realEmail,
      );

      when(
        () => auth.createUserAccount(realEmail, _password),
      ).thenAnswer((_) async => _uid);
      when(
        () => auth.reloadCurrentUser(),
      ).thenAnswer((_) async => verifiedUser);
      when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
      when(() => auth.signOut()).thenAnswer((_) async {});

      final svc = _buildService(dao: dao, auth: auth, hasher: hasher);
      final result = await svc.upgradeWithNewCredentials(
        profile: profile,
        email: realEmail,
        password: _password,
      );

      expect(result.tier, equals(UserTier.cloudBorn.dbValue));
      expect(result.firebaseUid, equals(_uid));
      // Synthetic @offline.local email replaced with the real one.
      expect(result.email, equals(realEmail));
      verify(() => auth.createUserAccount(realEmail, _password)).called(1);
      // No local password to verify on the credential-less path.
      verifyNever(() => hasher.verify(any<String>(), any<String>()));
    });

    test('updates the device registry email when registry+accountId are '
        'provided', () async {
      final profileId = await seedSynthetic();
      final profile = (await dao.getUserProfileById(profileId))!;
      await registry.addAccount(
        DeviceAccountsCompanion.insert(
          accountId: _accountId,
          email: syntheticEmail,
          displayName: '',
          tier: 'localBorn',
          createdAt: DateTimeFactory.nowUtc(),
          lastUsedAt: DateTimeFactory.nowUtc(),
          dbFileName: 'user_$_accountId.db',
        ),
      );
      final verifiedUser = _FakeAppUser(
        uid: _uid,
        emailVerified: true,
        emailOverride: realEmail,
      );
      when(
        () => auth.createUserAccount(realEmail, _password),
      ).thenAnswer((_) async => _uid);
      when(
        () => auth.reloadCurrentUser(),
      ).thenAnswer((_) async => verifiedUser);
      when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
      when(() => auth.signOut()).thenAnswer((_) async {});

      final svc = _buildService(
        dao: dao,
        auth: auth,
        hasher: hasher,
        registry: registry,
        accountId: _accountId,
      );
      await svc.upgradeWithNewCredentials(
        profile: profile,
        email: realEmail,
        password: _password,
      );

      final updated = await registry.findById(_accountId);
      expect(updated!.tier, equals('cloudBorn'));
      expect(updated.firebaseUid, equals(_uid));
      expect(updated.email, equals(realEmail));
    });

    test('email-already-in-use surfaces EmailCollisionException for the '
        'entered email', () async {
      final profileId = await seedSynthetic();
      final profile = (await dao.getUserProfileById(profileId))!;
      when(
        () => auth.createUserAccount(realEmail, _password),
      ).thenThrow(_FakeFirebaseException('email-already-in-use'));

      final svc = _buildService(dao: dao, auth: auth, hasher: hasher);
      await expectLater(
        () => svc.upgradeWithNewCredentials(
          profile: profile,
          email: realEmail,
          password: _password,
        ),
        throwsA(
          isA<EmailCollisionException>().having(
            (e) => e.email,
            'email',
            realEmail,
          ),
        ),
      );
    });

    test('rejects a non-local-born profile', () async {
      final profileId = await _seedCloudBorn(db);
      final profile = (await dao.getUserProfileById(profileId))!;
      final svc = _buildService(dao: dao, auth: auth, hasher: hasher);
      await expectLater(
        () => svc.upgradeWithNewCredentials(
          profile: profile,
          email: realEmail,
          password: _password,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ── AUD-core-domain-04 ───────────────────────────────────────────────────
  //
  // upgrade_to_cloud_service.dart hardcoded the raw literal 'cloudBorn' at
  // all 4 of its registry.updateAccountTier(...) call sites instead of
  // going through AccountTier.cloud.storageKey — the same typed accessor
  // DeviceAccountX.accountTier (the read path) already uses. Two unlinked
  // representations of the same storage key meant a future rename of the
  // storage key in the VO would not be caught by the compiler here.
  group('AUD-core-domain-04 — AccountTier.cloud.storageKey usage', () {
    test('AccountTier.cloud.storageKey is the literal this service writes '
        'to the registry (locks the coupling the fix relies on)', () {
      expect(AccountTier.cloud.storageKey, 'cloudBorn');
    });

    test('source contains zero raw \'cloudBorn\'/\'localBorn\' string literals '
        '— all go through AccountTier.*.storageKey', () {
      final candidates = [
        File(
          'lib/features/account/domain/services/upgrade_to_cloud_service.dart',
        ),
        File(
          '../lib/features/account/domain/services/upgrade_to_cloud_service.dart',
        ),
      ];
      final file = candidates.firstWhere(
        (f) => f.existsSync(),
        orElse: () => throw TestFailure(
          'Could not locate '
          'lib/features/account/domain/services/upgrade_to_cloud_service.dart.',
        ),
      );

      // Strip `//` line comments and `///` doc comments before scanning —
      // this finding is about executable string literals, not the prose
      // documentation that legitimately mentions the storage-key names
      // (e.g. "flipped to `cloudBorn`" in a doc comment).
      final codeOnly = file
          .readAsLinesSync()
          .map((line) => line.replaceFirst(RegExp(r'\s*//.*$'), ''))
          .join('\n');

      final hasRawCloudBornLiteral = codeOnly.contains("'cloudBorn'");
      final hasRawLocalBornLiteral = codeOnly.contains("'localBorn'");

      expect(
        hasRawCloudBornLiteral,
        isFalse,
        reason:
            "Found a raw 'cloudBorn' string literal outside comments — "
            'must use AccountTier.cloud.storageKey instead '
            '(AUD-core-domain-04).',
      );
      expect(
        hasRawLocalBornLiteral,
        isFalse,
        reason:
            "Found a raw 'localBorn' string literal outside comments — "
            'must use AccountTier.local.storageKey instead '
            '(AUD-core-domain-04).',
      );
    });
  });
}
