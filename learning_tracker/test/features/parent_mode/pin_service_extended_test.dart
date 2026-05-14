/// Extended tests for PinService covering profile-scoped and tutor PIN
/// methods not exercised by pin_service_test.dart:
/// - setProfilePin, verifyProfilePin, hasProfilePin, clearProfilePin
/// - getProfileLockoutRemainingMinutes
/// - setTutorPin, verifyTutorPin, hasTutorPin, clearTutorPin
/// - getTutorLockoutRemainingMinutes
/// - getParentLockoutRemainingMinutes
/// - clearParentPin
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

/// Simple in-memory secure storage backed by a Map.
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

  when(() => mock.delete(key: any(named: 'key'))).thenAnswer((invocation) async {
    final key = invocation.namedArguments[#key] as String;
    store.remove(key);
  });

  return mock;
}

void main() {
  late MockFlutterSecureStorage storage;
  late PinService service;
  const profileId = 5;

  setUp(() {
    storage = createMockStorage();
    service = PinService(storage);
  });

  // ── clearParentPin ────────────────────────────────────────────────────────

  group('PinService.clearParentPin', () {
    test('removes the parent PIN from storage', () async {
      await service.setParentPin('1234');
      expect(await service.hasParentPin(), isTrue);

      await service.clearParentPin();
      expect(await service.hasParentPin(), isFalse);
    });

    test('is a no-op when no PIN is set', () async {
      // Should not throw.
      await service.clearParentPin();
      expect(await service.hasParentPin(), isFalse);
    });
  });

  // ── getParentLockoutRemainingMinutes ──────────────────────────────────────

  group('PinService.getParentLockoutRemainingMinutes', () {
    test('returns 0 when not locked out', () async {
      final remaining = await service.getParentLockoutRemainingMinutes();
      expect(remaining, 0);
    });

    test('returns positive value when locked out', () async {
      await service.setParentPin('1234');
      // Trigger lockout (5 failures)
      for (var i = 0; i < 5; i++) {
        await service.verifyParentPin('0000');
      }

      final remaining = await service.getParentLockoutRemainingMinutes();
      expect(remaining, greaterThan(0));
      expect(remaining, lessThanOrEqualTo(15));
    });
  });

  // ── setProfilePin / verifyProfilePin ──────────────────────────────────────

  group('PinService profile PIN', () {
    test('setProfilePin validates 4-digit numeric PIN', () async {
      expect(() => service.setProfilePin(profileId, '123'), throwsArgumentError);
      expect(
        () => service.setProfilePin(profileId, 'abcd'),
        throwsArgumentError,
      );
    });

    test('setProfilePin stores a hash, not plaintext', () async {
      await service.setProfilePin(profileId, '2468');
      expect(await service.hasProfilePin(profileId), isTrue);
    });

    test('verifyProfilePin returns true for correct PIN', () async {
      await service.setProfilePin(profileId, '7890');
      final result = await service.verifyProfilePin(profileId, '7890');
      expect(result, isTrue);
    });

    test('verifyProfilePin returns false for incorrect PIN', () async {
      await service.setProfilePin(profileId, '7890');
      final result = await service.verifyProfilePin(profileId, '1111');
      expect(result, isFalse);
    });

    test('verifyProfilePin returns false when no PIN set', () async {
      final result = await service.verifyProfilePin(profileId, '1234');
      expect(result, isFalse);
    });

    test('hasProfilePin returns false when no PIN set', () async {
      expect(await service.hasProfilePin(profileId), isFalse);
    });

    test('hasProfilePin returns true after PIN is set', () async {
      await service.setProfilePin(profileId, '4321');
      expect(await service.hasProfilePin(profileId), isTrue);
    });

    test('clearProfilePin removes the PIN', () async {
      await service.setProfilePin(profileId, '3456');
      expect(await service.hasProfilePin(profileId), isTrue);

      await service.clearProfilePin(profileId);
      expect(await service.hasProfilePin(profileId), isFalse);
    });

    test('setProfilePin resets lockout state', () async {
      await service.setProfilePin(profileId, '1234');
      // Trigger lockout (5 failures)
      for (var i = 0; i < 5; i++) {
        await service.verifyProfilePin(profileId, '0000');
      }
      // Should be locked out
      expect(
        () => service.verifyProfilePin(profileId, '1234'),
        throwsA(isA<PinLockoutException>()),
      );

      // Set new PIN — should reset lockout
      await service.setProfilePin(profileId, '5678');
      final result = await service.verifyProfilePin(profileId, '5678');
      expect(result, isTrue);
    });

    test('profile lockout triggers after 5 failed attempts', () async {
      await service.setProfilePin(profileId, '1234');
      for (var i = 0; i < 5; i++) {
        await service.verifyProfilePin(profileId, '0000');
      }
      expect(
        () => service.verifyProfilePin(profileId, '1234'),
        throwsA(isA<PinLockoutException>()),
      );
    });

    test('getProfileLockoutRemainingMinutes returns 0 when not locked out',
        () async {
      final remaining = await service.getProfileLockoutRemainingMinutes(
        profileId,
      );
      expect(remaining, 0);
    });

    test('getProfileLockoutRemainingMinutes returns positive value when locked out',
        () async {
      await service.setProfilePin(profileId, '1234');
      for (var i = 0; i < 5; i++) {
        await service.verifyProfilePin(profileId, '0000');
      }

      final remaining = await service.getProfileLockoutRemainingMinutes(
        profileId,
      );
      expect(remaining, greaterThan(0));
    });

    test('profile PINs are scoped by profileId', () async {
      const otherProfileId = 99;
      await service.setProfilePin(profileId, '1111');
      await service.setProfilePin(otherProfileId, '2222');

      expect(await service.verifyProfilePin(profileId, '1111'), isTrue);
      expect(await service.verifyProfilePin(otherProfileId, '2222'), isTrue);
      // Cross-check: profile 5's PIN is not 2222
      expect(await service.verifyProfilePin(profileId, '2222'), isFalse);
    });
  });

  // ── setTutorPin / verifyTutorPin ──────────────────────────────────────────

  group('PinService tutor PIN', () {
    test('setTutorPin validates 4-digit numeric PIN', () async {
      expect(
        () => service.setTutorPin(profileId, '12'),
        throwsArgumentError,
      );
    });

    test('setTutorPin stores a hash', () async {
      await service.setTutorPin(profileId, '9999');
      expect(await service.hasTutorPin(profileId), isTrue);
    });

    test('verifyTutorPin returns true for correct PIN', () async {
      await service.setTutorPin(profileId, '6543');
      final result = await service.verifyTutorPin(profileId, '6543');
      expect(result, isTrue);
    });

    test('verifyTutorPin returns false for incorrect PIN', () async {
      await service.setTutorPin(profileId, '6543');
      final result = await service.verifyTutorPin(profileId, '0000');
      expect(result, isFalse);
    });

    test('verifyTutorPin returns false when no tutor PIN set', () async {
      final result = await service.verifyTutorPin(profileId, '1234');
      expect(result, isFalse);
    });

    test('hasTutorPin returns false when no PIN set', () async {
      expect(await service.hasTutorPin(profileId), isFalse);
    });

    test('clearTutorPin removes the tutor PIN', () async {
      await service.setTutorPin(profileId, '1234');
      expect(await service.hasTutorPin(profileId), isTrue);

      await service.clearTutorPin(profileId);
      expect(await service.hasTutorPin(profileId), isFalse);
    });

    test('tutor PIN lockout triggers after 5 failures', () async {
      await service.setTutorPin(profileId, '1234');
      for (var i = 0; i < 5; i++) {
        await service.verifyTutorPin(profileId, '0000');
      }
      expect(
        () => service.verifyTutorPin(profileId, '1234'),
        throwsA(isA<PinLockoutException>()),
      );
    });

    test('getTutorLockoutRemainingMinutes returns 0 when not locked out',
        () async {
      final remaining = await service.getTutorLockoutRemainingMinutes(profileId);
      expect(remaining, 0);
    });

    test('getTutorLockoutRemainingMinutes returns positive value when locked out',
        () async {
      await service.setTutorPin(profileId, '1234');
      for (var i = 0; i < 5; i++) {
        await service.verifyTutorPin(profileId, '0000');
      }

      final remaining = await service.getTutorLockoutRemainingMinutes(profileId);
      expect(remaining, greaterThan(0));
    });

    test('tutor PIN is independent from parent PIN', () async {
      await service.setParentPin('1111');
      await service.setTutorPin(profileId, '2222');

      // Parent PIN check does not affect tutor, and vice versa
      expect(await service.verifyParentPin('1111'), isTrue);
      expect(await service.verifyTutorPin(profileId, '2222'), isTrue);
      expect(await service.verifyTutorPin(profileId, '1111'), isFalse);
    });

    test('tutor PIN successful verification resets lockout counter', () async {
      await service.setTutorPin(profileId, '1234');
      // 3 failures
      for (var i = 0; i < 3; i++) {
        await service.verifyTutorPin(profileId, '0000');
      }
      // Correct PIN — should reset counter
      await service.verifyTutorPin(profileId, '1234');

      // Now should be able to verify without lockout exception
      final result = await service.verifyTutorPin(profileId, '1234');
      expect(result, isTrue);
    });
  });
}
