import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/account/domain/services/local_auth_service.dart';
import 'package:learning_tracker/features/account/domain/services/password_hasher.dart';

void main() {
  late UserDatabase db;
  late LocalAuthService service;

  setUp(() {
    db = UserDatabase(NativeDatabase.memory());
    service = LocalAuthService(
      dao: db.userProfileDao,
      hasher: PasswordHasher(params: Argon2idParams.test),
    );
  });

  tearDown(() => db.close());

  group('LocalAuthService.signUp', () {
    test('creates a local-born row with a valid argon2id hash', () async {
      final profile = await service.signUp(
        email: 'alice@example.com',
        password: 'correct-horse',
        displayName: 'Alice',
      );

      expect(profile.email, 'alice@example.com');
      expect(profile.tier, 'localBorn');
      expect(profile.firebaseUid, isNull);
      expect(profile.passwordHash, isNotNull);
      expect(profile.passwordHash!.startsWith(r'argon2id$'), isTrue);
    });

    test('normalizes email (trim + lowercase)', () async {
      final profile = await service.signUp(
        email: '  Alice@Example.COM  ',
        password: 'correct-horse',
        displayName: 'Alice',
      );
      expect(profile.email, 'alice@example.com');
    });

    test('rejects duplicate email with DuplicateEmailException', () async {
      await service.signUp(
        email: 'alice@example.com',
        password: 'correct-horse',
        displayName: 'Alice',
      );

      expect(
        () => service.signUp(
          email: 'alice@example.com',
          password: 'another-pass',
          displayName: 'Alice 2',
        ),
        throwsA(isA<DuplicateEmailException>()),
      );
    });

    test('rejects malformed email', () async {
      expect(
        () => service.signUp(
          email: 'not-an-email',
          password: 'correct-horse',
          displayName: 'Alice',
        ),
        throwsA(isA<InvalidInputException>()),
      );
    });

    test('rejects too-short password', () async {
      expect(
        () => service.signUp(
          email: 'alice@example.com',
          password: 'short',
          displayName: 'Alice',
        ),
        throwsA(isA<InvalidInputException>()),
      );
    });
  });

  group('LocalAuthService.signIn', () {
    setUp(() async {
      await service.signUp(
        email: 'alice@example.com',
        password: 'correct-horse',
        displayName: 'Alice',
      );
    });

    test('succeeds with correct password', () async {
      final profile = await service.signIn(
        email: 'alice@example.com',
        password: 'correct-horse',
      );
      expect(profile.email, 'alice@example.com');
    });

    test('normalizes email on sign-in', () async {
      final profile = await service.signIn(
        email: '  ALICE@example.com ',
        password: 'correct-horse',
      );
      expect(profile.email, 'alice@example.com');
    });

    test('fails with wrong password (InvalidCredentialsException)', () async {
      expect(
        () =>
            service.signIn(email: 'alice@example.com', password: 'wrong-pass'),
        throwsA(isA<InvalidCredentialsException>()),
      );
    });

    test('fails with unknown email (InvalidCredentialsException)', () async {
      expect(
        () =>
            service.signIn(email: 'bob@example.com', password: 'correct-horse'),
        throwsA(isA<InvalidCredentialsException>()),
      );
    });

    test('cloud-born rows are invisible to local sign-in', () async {
      // Simulate a cloud-born row with the same email — signIn
      // must ignore it (findLocalBornByEmail filters on tier).
      await db.userProfileDao.upsertProfile(
        firebaseUid: 'cloud-uid',
        displayName: 'Cloud Alice',
        updatedAt: DateTime.utc(2025, 1, 1),
        email: 'cloudalice@example.com',
      );

      expect(
        () => service.signIn(
          email: 'cloudalice@example.com',
          password: 'irrelevant',
        ),
        throwsA(isA<InvalidCredentialsException>()),
      );
    });
  });

  group('PasswordHasher', () {
    test('hash and verify roundtrip', () async {
      final hasher = PasswordHasher(params: Argon2idParams.test);
      final encoded = await hasher.hash('my-password');
      expect(await hasher.verify('my-password', encoded), isTrue);
      expect(await hasher.verify('not-my-password', encoded), isFalse);
    });

    test('verify returns false on malformed hash (no crash)', () async {
      final hasher = PasswordHasher(params: Argon2idParams.test);
      expect(await hasher.verify('pw', 'garbage'), isFalse);
    });
  });
}
