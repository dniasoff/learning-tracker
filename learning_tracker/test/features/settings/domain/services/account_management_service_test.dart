import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/domain/services/account_management_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/test_database.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// Returns a minimal [AppUser] with the given [uid].
AppUser _makeUser(String uid) => AppUser(
  uid: uid,
  email: '$uid@test.example',
  displayName: 'Test User',
  emailVerified: true,
  providers: const ['password'],
);

void main() {
  late MockAuthRepository mockAuthRepo;
  late UserDatabase db;
  late AccountManagementService service;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    mockAuthRepo = MockAuthRepository();
    db = createTestDatabase();
    service = AccountManagementService(
      authRepository: mockAuthRepo,
      database: db,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('signOut', () {
    test('clears onboarding state from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'onboarding_complete': true,
        'add_track_step': '1',
      });

      await service.signOut();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('onboarding_complete'), isFalse);
      expect(prefs.containsKey('add_track_step'), isFalse);
    });

    test('preserves local database data after sign out', () async {
      // Insert test profile
      await db.userProfileDao.upsertProfile(
        firebaseUid: 'test-uid',
        displayName: 'Test User',
        updatedAt: DateTime.now(),
      );

      await service.signOut();

      // Verify local data is still there
      final profile = await db.userProfileDao.getUserProfileByFirebaseUid(
        'test-uid',
      );
      expect(profile, isNotNull);
      expect(profile!.displayName, 'Test User');
    });
  });

  group('deleteAccount', () {
    setUp(() {
      // The guard reads currentUser before proceeding; stub it to match.
      when(() => mockAuthRepo.currentUser).thenReturn(_makeUser('test-uid'));
      when(() => mockAuthRepo.deleteAccount()).thenAnswer((_) async {});
    });

    // Firestore deletion is now server-side via the deleteAccountData Cloud
    // Function (recursiveDelete) — not testable in unit tests without Firebase
    // initialisation. The onUserDeleted trigger also handles any leftovers.

    test('deletes Firebase Auth account', () async {
      await service.deleteAccount('test-uid');

      verify(() => mockAuthRepo.deleteAccount()).called(1);
    });

    test('clears local database', () async {
      await db.userProfileDao.upsertProfile(
        firebaseUid: 'test-uid',
        displayName: 'Test User',
        updatedAt: DateTime.now(),
      );

      await service.deleteAccount('test-uid');

      final profile = await db.userProfileDao.getUserProfileByFirebaseUid(
        'test-uid',
      );
      expect(profile, isNull);
    });

    test(
      'clears the outbox — no pending push survives account deletion',
      () async {
        await db
            .into(db.outbox)
            .insert(
              OutboxCompanion.insert(
                profileId: 1,
                entityKind: 'completion',
                entityKey: '1:Berakhot 1:1:1:personal',
                payload: '{}',
                createdAt: DateTime.utc(2026, 5, 18),
              ),
            );
        expect(await db.select(db.outbox).get(), isNotEmpty);

        await service.deleteAccount('test-uid');

        expect(
          await db.select(db.outbox).get(),
          isEmpty,
          reason:
              'the outbox is a pending-command queue — it must not survive '
              'account deletion (a stale row would push to the next account)',
        );
      },
    );

    // ── R4-11 regression: UID guard ──────────────────────────────────────────

    test('throws StateError and does NOT call deleteAccount/signOut when '
        'currentUser is null', () async {
      when(() => mockAuthRepo.currentUser).thenReturn(null);

      await expectLater(
        () => service.deleteAccount('test-uid'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('no user is currently signed in'),
          ),
        ),
      );

      // Neither the Firebase Auth delete nor any signOut must have been called.
      verifyNever(() => mockAuthRepo.deleteAccount());
      verifyNever(() => mockAuthRepo.signOut());
    });

    test('throws StateError and does NOT call deleteAccount/signOut when '
        'currentUser.uid != the passed uid', () async {
      when(
        () => mockAuthRepo.currentUser,
      ).thenReturn(_makeUser('different-uid'));

      await expectLater(
        () => service.deleteAccount('test-uid'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('different-uid'), contains('test-uid')),
          ),
        ),
      );

      verifyNever(() => mockAuthRepo.deleteAccount());
      verifyNever(() => mockAuthRepo.signOut());
    });

    test(
      'proceeds normally when currentUser.uid matches the passed uid',
      () async {
        // currentUser already stubbed in outer setUp to return 'test-uid'.
        await service.deleteAccount('test-uid');

        verify(() => mockAuthRepo.deleteAccount()).called(1);
      },
    );
  });

  group('changePassword', () {
    test('calls authRepository.changePassword', () async {
      when(
        () => mockAuthRepo.changePassword('newPass'),
      ).thenAnswer((_) async {});

      await service.changePassword('newPass');

      verify(() => mockAuthRepo.changePassword('newPass')).called(1);
    });
  });

  group('reauthenticateWithEmail', () {
    test('calls authRepository.reauthenticateWithEmail', () async {
      when(
        () => mockAuthRepo.reauthenticateWithEmail('a@b.com', 'pass'),
      ).thenAnswer((_) async {});

      await service.reauthenticateWithEmail('a@b.com', 'pass');

      verify(
        () => mockAuthRepo.reauthenticateWithEmail('a@b.com', 'pass'),
      ).called(1);
    });
  });

  group('linkGoogleProvider', () {
    test('calls authRepository.linkGoogleProvider', () async {
      when(() => mockAuthRepo.linkGoogleProvider()).thenAnswer((_) async {});

      await service.linkGoogleProvider();

      verify(() => mockAuthRepo.linkGoogleProvider()).called(1);
    });
  });

  group('linkEmailProvider', () {
    test('calls authRepository.linkEmailProvider', () async {
      when(
        () => mockAuthRepo.linkEmailProvider('a@b.com', 'pass'),
      ).thenAnswer((_) async {});

      await service.linkEmailProvider('a@b.com', 'pass');

      verify(() => mockAuthRepo.linkEmailProvider('a@b.com', 'pass')).called(1);
    });
  });

  group('getLinkedProviders', () {
    test('returns providers from authRepository', () {
      when(
        () => mockAuthRepo.getLinkedProviders(),
      ).thenReturn(['password', 'google.com']);

      final providers = service.getLinkedProviders();

      expect(providers, ['password', 'google.com']);
    });
  });
}
