// Extra coverage for PinService — profile-scoped PIN and tutor PIN methods
// were not exercised by the baseline pin_service_test.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

MockFlutterSecureStorage createMockStorage() {
  final mock = MockFlutterSecureStorage();
  final store = <String, String>{};

  when(
    () => mock.write(key: any(named: 'key'), value: any(named: 'value')),
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
    final key = invocation.namedArguments[#key] as String;
    return store[key];
  });

  when(() => mock.delete(key: any(named: 'key'))).thenAnswer((
    invocation,
  ) async {
    final key = invocation.namedArguments[#key] as String;
    store.remove(key);
  });

  return mock;
}

void main() {
  late MockFlutterSecureStorage storage;
  late PinService pinService;

  setUp(() {
    storage = createMockStorage();
    pinService = PinService(storage);
  });

  // ---------------------------------------------------------------------------
  // clearParentPin
  // ---------------------------------------------------------------------------

  group('PinService.clearParentPin', () {
    test('removes stored hash and lockout state', () async {
      await pinService.setParentPin('1234');
      expect(await pinService.hasParentPin(), isTrue);

      await pinService.clearParentPin();
      expect(await pinService.hasParentPin(), isFalse);
    });

    test('is a no-op when no parent PIN is set', () async {
      await expectLater(pinService.clearParentPin(), completes);
      expect(await pinService.hasParentPin(), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // getParentLockoutRemainingMinutes
  // ---------------------------------------------------------------------------

  group('PinService.getParentLockoutRemainingMinutes', () {
    test('returns 0 when not locked out', () async {
      final mins = await pinService.getParentLockoutRemainingMinutes();
      expect(mins, 0);
    });

    test('returns positive value after lockout is triggered', () async {
      await pinService.setParentPin('1234');
      for (var i = 0; i < 5; i++) {
        await pinService.verifyParentPin('0000');
      }
      final mins = await pinService.getParentLockoutRemainingMinutes();
      expect(mins, greaterThan(0));
    });
  });

  // ---------------------------------------------------------------------------
  // Profile PIN — setProfilePin / verifyProfilePin / hasProfilePin / clearProfilePin
  // ---------------------------------------------------------------------------

  group('PinService — profile PIN', () {
    const profileId = 42;

    test('setProfilePin stores a bcrypt hash', () async {
      await pinService.setProfilePin(profileId, '5678');
      expect(await pinService.hasProfilePin(profileId), isTrue);
    });

    test('hasProfilePin returns false when no PIN set', () async {
      expect(await pinService.hasProfilePin(profileId), isFalse);
    });

    test('verifyProfilePin returns true for correct PIN', () async {
      await pinService.setProfilePin(profileId, '9999');
      expect(await pinService.verifyProfilePin(profileId, '9999'), isTrue);
    });

    test('verifyProfilePin returns false for incorrect PIN', () async {
      await pinService.setProfilePin(profileId, '9999');
      expect(await pinService.verifyProfilePin(profileId, '0000'), isFalse);
    });

    test('verifyProfilePin returns false when no PIN is set', () async {
      expect(await pinService.verifyProfilePin(profileId, '1234'), isFalse);
    });

    test('clearProfilePin removes the stored hash', () async {
      await pinService.setProfilePin(profileId, '1234');
      await pinService.clearProfilePin(profileId);
      expect(await pinService.hasProfilePin(profileId), isFalse);
    });

    test('profile PINs for different profiles are independent', () async {
      await pinService.setProfilePin(1, '1111');
      await pinService.setProfilePin(2, '2222');

      expect(await pinService.verifyProfilePin(1, '2222'), isFalse);
      expect(await pinService.verifyProfilePin(2, '1111'), isFalse);
      expect(await pinService.verifyProfilePin(1, '1111'), isTrue);
      expect(await pinService.verifyProfilePin(2, '2222'), isTrue);
    });

    test('setProfilePin rejects non-4-digit PINs', () async {
      expect(
        () => pinService.setProfilePin(profileId, '123'),
        throwsArgumentError,
      );
      expect(
        () => pinService.setProfilePin(profileId, 'abcd'),
        throwsArgumentError,
      );
    });

    test('setProfilePin resets lockout state', () async {
      await pinService.setProfilePin(profileId, '1234');
      for (var i = 0; i < 5; i++) {
        await pinService.verifyProfilePin(profileId, '0000');
      }
      // Locked out now; changing PIN should clear lockout.
      await pinService.setProfilePin(profileId, '5678');
      expect(
        await pinService.verifyProfilePin(profileId, '5678'),
        isTrue,
      );
    });

    test('profile PIN lockout triggers after max failed attempts', () async {
      await pinService.setProfilePin(profileId, '1234');
      for (var i = 0; i < 5; i++) {
        await pinService.verifyProfilePin(profileId, '0000');
      }
      expect(
        () => pinService.verifyProfilePin(profileId, '1234'),
        throwsA(isA<PinLockoutException>()),
      );
    });

    test('getProfileLockoutRemainingMinutes returns 0 when not locked', () async {
      final mins =
          await pinService.getProfileLockoutRemainingMinutes(profileId);
      expect(mins, 0);
    });

    test(
      'getProfileLockoutRemainingMinutes returns positive value after lockout',
      () async {
        await pinService.setProfilePin(profileId, '1234');
        for (var i = 0; i < 5; i++) {
          await pinService.verifyProfilePin(profileId, '0000');
        }
        final mins =
            await pinService.getProfileLockoutRemainingMinutes(profileId);
        expect(mins, greaterThan(0));
      },
    );

    test('verifyProfilePin resets counter on success', () async {
      await pinService.setProfilePin(profileId, '1234');
      for (var i = 0; i < 3; i++) {
        await pinService.verifyProfilePin(profileId, '0000');
      }
      await pinService.verifyProfilePin(profileId, '1234');

      // After success, 4 more failures should not trigger lockout.
      for (var i = 0; i < 4; i++) {
        await pinService.verifyProfilePin(profileId, '0000');
      }
      // Should NOT throw — lockout requires 5 consecutive failures.
      expect(
        await pinService.verifyProfilePin(profileId, '1234'),
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Tutor PIN — setTutorPin / verifyTutorPin / hasTutorPin / clearTutorPin
  // ---------------------------------------------------------------------------

  group('PinService — tutor PIN', () {
    const profileId = 7;

    test('hasTutorPin returns false when no PIN set', () async {
      expect(await pinService.hasTutorPin(profileId), isFalse);
    });

    test('setTutorPin stores a bcrypt hash', () async {
      await pinService.setTutorPin(profileId, '4321');
      expect(await pinService.hasTutorPin(profileId), isTrue);
    });

    test('verifyTutorPin returns true for correct PIN', () async {
      await pinService.setTutorPin(profileId, '7777');
      expect(await pinService.verifyTutorPin(profileId, '7777'), isTrue);
    });

    test('verifyTutorPin returns false for incorrect PIN', () async {
      await pinService.setTutorPin(profileId, '7777');
      expect(await pinService.verifyTutorPin(profileId, '0000'), isFalse);
    });

    test('verifyTutorPin returns false when no PIN is set', () async {
      expect(await pinService.verifyTutorPin(profileId, '1234'), isFalse);
    });

    test('clearTutorPin removes stored hash', () async {
      await pinService.setTutorPin(profileId, '4321');
      await pinService.clearTutorPin(profileId);
      expect(await pinService.hasTutorPin(profileId), isFalse);
    });

    test('setTutorPin rejects non-4-digit PINs', () async {
      expect(
        () => pinService.setTutorPin(profileId, '12'),
        throwsArgumentError,
      );
    });

    test('tutor PIN is independent from profile PIN (different namespace)',
        () async {
      await pinService.setProfilePin(profileId, '1111');
      await pinService.setTutorPin(profileId, '2222');

      // Knowing the tutor PIN should not grant profile PIN access.
      expect(await pinService.verifyProfilePin(profileId, '2222'), isFalse);
      expect(await pinService.verifyTutorPin(profileId, '1111'), isFalse);
    });

    test('tutor PIN lockout triggers after max failed attempts', () async {
      await pinService.setTutorPin(profileId, '9999');
      for (var i = 0; i < 5; i++) {
        await pinService.verifyTutorPin(profileId, '0000');
      }
      expect(
        () => pinService.verifyTutorPin(profileId, '9999'),
        throwsA(isA<PinLockoutException>()),
      );
    });

    test('getTutorLockoutRemainingMinutes returns 0 when not locked', () async {
      expect(
        await pinService.getTutorLockoutRemainingMinutes(profileId),
        0,
      );
    });

    test(
      'getTutorLockoutRemainingMinutes returns positive value after lockout',
      () async {
        await pinService.setTutorPin(profileId, '1234');
        for (var i = 0; i < 5; i++) {
          await pinService.verifyTutorPin(profileId, '0000');
        }
        final mins =
            await pinService.getTutorLockoutRemainingMinutes(profileId);
        expect(mins, greaterThan(0));
      },
    );

    test('verifyTutorPin resets counter on success', () async {
      await pinService.setTutorPin(profileId, '1234');
      for (var i = 0; i < 3; i++) {
        await pinService.verifyTutorPin(profileId, '0000');
      }
      await pinService.verifyTutorPin(profileId, '1234');

      // After success, 4 more failures should not trigger lockout.
      for (var i = 0; i < 4; i++) {
        await pinService.verifyTutorPin(profileId, '0000');
      }
      expect(await pinService.verifyTutorPin(profileId, '1234'), isTrue);
    });
  });
}
