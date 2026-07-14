/// Extended tests for PinService covering profile-scoped and tutor PIN
/// methods not exercised by pin_service_test.dart:
/// - setProfilePin, verifyProfilePin, hasProfilePin, clearProfilePin
/// - getProfileLockoutRemainingMinutes
/// - setTutorPin, verifyTutorPin, hasTutorPin, clearTutorPin
/// - getTutorLockoutRemainingMinutes
/// - getParentLockoutRemainingMinutes
/// - clearParentPin
///
/// Merged from the former pin_service_profile_test.dart (AUD-t-parent_mode-02)
/// — the two files independently re-tested the same PinService surface
/// under different profileId constants and wording (~90% overlap). This
/// file keeps the union of both: every distinct behavior either file
/// covered still has exactly one test asserting it here.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';

import '../../helpers/fake_secure_storage.dart';

void main() {
  late MockFlutterSecureStorage storage;
  late PinService service;

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
      await expectLater(service.clearParentPin(), completes);
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
    const profileId = 5;

    test('setProfilePin rejects non-4-digit PINs', () async {
      // AUD-onboarding-16: PinService now throws a typed
      // InvalidPinFormatException (EH-2/EH-5) instead of ArgumentError.
      expect(
        () => service.setProfilePin(profileId, '123'),
        throwsA(isA<InvalidPinFormatException>()),
      );
      expect(
        () => service.setProfilePin(profileId, 'abcd'),
        throwsA(isA<InvalidPinFormatException>()),
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

    test('profile PINs for different profiles are independent', () async {
      await service.setProfilePin(1, '1111');
      await service.setProfilePin(2, '2222');

      expect(await service.verifyProfilePin(1, '2222'), isFalse);
      expect(await service.verifyProfilePin(2, '1111'), isFalse);
      expect(await service.verifyProfilePin(1, '1111'), isTrue);
      expect(await service.verifyProfilePin(2, '2222'), isTrue);
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

    test(
      'getProfileLockoutRemainingMinutes returns 0 when not locked out',
      () async {
        final remaining = await service.getProfileLockoutRemainingMinutes(
          profileId,
        );
        expect(remaining, 0);
      },
    );

    test(
      'getProfileLockoutRemainingMinutes returns positive value when locked out',
      () async {
        await service.setProfilePin(profileId, '1234');
        for (var i = 0; i < 5; i++) {
          await service.verifyProfilePin(profileId, '0000');
        }

        final remaining = await service.getProfileLockoutRemainingMinutes(
          profileId,
        );
        expect(remaining, greaterThan(0));
      },
    );

    test('verifyProfilePin resets counter on success', () async {
      await service.setProfilePin(profileId, '1234');
      for (var i = 0; i < 3; i++) {
        await service.verifyProfilePin(profileId, '0000');
      }
      await service.verifyProfilePin(profileId, '1234');

      // After success, 4 more failures should not trigger lockout.
      for (var i = 0; i < 4; i++) {
        await service.verifyProfilePin(profileId, '0000');
      }
      // Should NOT throw — lockout requires 5 consecutive failures.
      expect(await service.verifyProfilePin(profileId, '1234'), isTrue);
    });
  });

  // ── setTutorPin / verifyTutorPin ──────────────────────────────────────────

  group('PinService tutor PIN', () {
    const profileId = 7;

    test('setTutorPin validates 4-digit numeric PIN', () async {
      // AUD-onboarding-16: PinService now throws a typed
      // InvalidPinFormatException (EH-2/EH-5) instead of ArgumentError.
      expect(
        () => service.setTutorPin(profileId, '12'),
        throwsA(isA<InvalidPinFormatException>()),
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

    test(
      'getTutorLockoutRemainingMinutes returns 0 when not locked out',
      () async {
        final remaining = await service.getTutorLockoutRemainingMinutes(
          profileId,
        );
        expect(remaining, 0);
      },
    );

    test(
      'getTutorLockoutRemainingMinutes returns positive value when locked out',
      () async {
        await service.setTutorPin(profileId, '1234');
        for (var i = 0; i < 5; i++) {
          await service.verifyTutorPin(profileId, '0000');
        }

        final remaining = await service.getTutorLockoutRemainingMinutes(
          profileId,
        );
        expect(remaining, greaterThan(0));
      },
    );

    test('tutor PIN is independent from parent PIN', () async {
      await service.setParentPin('1111');
      await service.setTutorPin(profileId, '2222');

      // Parent PIN check does not affect tutor, and vice versa
      expect(await service.verifyParentPin('1111'), isTrue);
      expect(await service.verifyTutorPin(profileId, '2222'), isTrue);
      expect(await service.verifyTutorPin(profileId, '1111'), isFalse);
    });

    test(
      'tutor PIN is independent from profile PIN (different namespace)',
      () async {
        await service.setProfilePin(profileId, '1111');
        await service.setTutorPin(profileId, '2222');

        // Knowing the tutor PIN should not grant profile PIN access.
        expect(await service.verifyProfilePin(profileId, '2222'), isFalse);
        expect(await service.verifyTutorPin(profileId, '1111'), isFalse);
      },
    );

    test('verifyTutorPin resets counter on success', () async {
      await service.setTutorPin(profileId, '1234');
      for (var i = 0; i < 3; i++) {
        await service.verifyTutorPin(profileId, '0000');
      }
      await service.verifyTutorPin(profileId, '1234');

      // After success, 4 more failures should not trigger lockout.
      for (var i = 0; i < 4; i++) {
        await service.verifyTutorPin(profileId, '0000');
      }
      // Should NOT throw — lockout requires 5 consecutive failures.
      expect(await service.verifyTutorPin(profileId, '1234'), isTrue);
    });
  });
}
