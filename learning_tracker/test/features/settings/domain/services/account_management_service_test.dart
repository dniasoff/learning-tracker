import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/domain/services/account_management_service.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/tutoring/domain/services/tutor_pin_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/fake_secure_storage.dart';
import '../../../../helpers/test_database.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// In-memory [FlutterSecureStorage] backed by a Map, including [deleteAll].
///
/// Reuses the shared [MockFlutterSecureStorage] class from
/// `test/helpers/fake_secure_storage.dart` (AUD-t-parent_mode-02) instead
/// of redeclaring it; this file adds a `deleteAll()` stub on top of the
/// shared class because `AccountManagementService.deleteAccount()` calls
/// `secureStorage.deleteAll()` directly, which the shared
/// `createMockStorage()` factory does not stub.
MockFlutterSecureStorage createMockSecureStorage() {
  final mock = MockFlutterSecureStorage();
  final store = <String, String>{};

  when(
    () => mock.write(
      key: any(named: 'key'),
      value: any(named: 'value'),
    ),
  ).thenAnswer((invocation) async {
    final key = invocation.namedArguments[#key] as String;
    final value = invocation.namedArguments[#value] as String?;
    if (value == null) {
      store.remove(key);
    } else {
      store[key] = value;
    }
  });
  when(() => mock.read(key: any(named: 'key'))).thenAnswer((invocation) async {
    return store[invocation.namedArguments[#key] as String];
  });
  when(() => mock.delete(key: any(named: 'key'))).thenAnswer((
    invocation,
  ) async {
    store.remove(invocation.namedArguments[#key] as String);
  });
  when(() => mock.deleteAll()).thenAnswer((_) async => store.clear());

  return mock;
}

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
  late MockFlutterSecureStorage secureStorage;
  late AccountManagementService service;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    mockAuthRepo = MockAuthRepository();
    db = createTestDatabase();
    secureStorage = createMockSecureStorage();
    service = AccountManagementService(
      authRepository: mockAuthRepo,
      database: db,
      secureStorage: secureStorage,
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

    // AUD-account-13 (EH-3 log-less catch): _deleteFirestoreUserData's catch
    // block claims "Log but don't rethrow" but had no AppLogger call at all.
    // Firebase isn't initialised in this unit-test environment, so
    // FirebaseFunctions.instance.httpsCallable(...) always throws here —
    // this is precisely the "Cloud Function call fails" scenario the finding
    // describes, and it's already exercised by every other test in this
    // group; only the logging assertion was missing.
    test('logs an AppLogger error when the deleteAccountData Cloud Function '
        'call throws', () async {
      AppLogger.init();
      final before = AppLogger.instance.talker.history.length;

      await service.deleteAccount('test-uid');

      final newEntries = AppLogger.instance.talker.history.skip(before);
      final matching = newEntries.where(
        (e) => e.generateTextMessage().contains(
          'delete_firestore_user_data_failed',
        ),
      );
      expect(
        matching,
        isNotEmpty,
        reason:
            'the swallowed Cloud Function failure must be logged, not '
            'silently dropped',
      );
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

    // ── Bug 5 regression: onboarding-complete flag must not survive ─────────
    test(
      'clears the onboarding-complete flag so a fresh sign-up re-onboards',
      () async {
        SharedPreferences.setMockInitialValues({
          'onboarding_complete': true,
          'last_active_account_id': 'test-uid',
          'onboarding_phase': 'profile',
        });

        await service.deleteAccount('test-uid');

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool('onboarding_complete') ?? false,
          isFalse,
          reason: 'a stale onboarding-complete flag would skip the wizard',
        );
        expect(prefs.containsKey('last_active_account_id'), isFalse);
        expect(prefs.containsKey('onboarding_phase'), isFalse);
      },
    );

    // ── Bug 6 regression: tutor PIN must not survive ───────────────────────
    test('clears the tutor PIN so the old PIN no longer verifies', () async {
      final pinService = PinService(secureStorage);
      final tutorPinService = TutorPinService(pinService);
      await tutorPinService.setTutorPin(profileId: 7, rawPin: '1234');
      expect(await tutorPinService.hasTutorPin(7), isTrue);

      await service.deleteAccount('test-uid');

      expect(
        await tutorPinService.hasTutorPin(7),
        isFalse,
        reason: 'the tutor PIN must be wiped on account deletion',
      );
      expect(
        await tutorPinService.verifyTutorPin(profileId: 7, rawPin: '1234'),
        isA<TutorPinIncorrect>(),
        reason: 'the old PIN must no longer verify after deletion',
      );
    });

    // ── Bug 5/6 regression: teardown must run even if auth delete throws ────
    test(
      'wipes onboarding flag + tutor PIN even when Firebase Auth delete throws',
      () async {
        SharedPreferences.setMockInitialValues({'onboarding_complete': true});
        when(
          () => mockAuthRepo.deleteAccount(),
        ).thenThrow(StateError('requires-recent-login'));
        final pinService = PinService(secureStorage);
        final tutorPinService = TutorPinService(pinService);
        await tutorPinService.setTutorPin(profileId: 7, rawPin: '1234');

        await expectLater(
          () => service.deleteAccount('test-uid'),
          throwsA(isA<StateError>()),
        );

        // Local teardown ran in `finally` despite the auth failure.
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('onboarding_complete') ?? false, isFalse);
        expect(await tutorPinService.hasTutorPin(7), isFalse);
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
