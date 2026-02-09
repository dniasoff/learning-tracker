import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockFlutterSecureStorage mockStorage;
  late PinService pinService;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    pinService = PinService(mockStorage);
  });

  group('setParentPin', () {
    test('should store a bcrypt hash and not plaintext PIN', () async {
      const pin = '1234';
      String? storedValue;

      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        storedValue = invocation.namedArguments[Symbol('value')] as String;
      });
      when(
        () => mockStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      await pinService.setParentPin(pin);

      // Verify write was called
      verify(
        () => mockStorage.write(
          key: 'parent_pin_hash',
          value: any(named: 'value'),
        ),
      ).called(1);

      // Verify stored value is not plaintext
      expect(storedValue, isNot(pin));
      expect(storedValue, isNotNull);
      expect(storedValue!.length, greaterThan(pin.length));
      expect(storedValue!.startsWith(r'$2'), isTrue); // bcrypt hash prefix
    });

    test('should reset lockout state when PIN is changed', () async {
      const pin = '1234';

      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      await pinService.setParentPin(pin);

      verify(() => mockStorage.delete(key: 'parent_lockout_count')).called(1);
      verify(
        () => mockStorage.delete(key: 'parent_lockout_timestamp'),
      ).called(1);
    });

    test('should throw ArgumentError for invalid PIN length', () async {
      expect(() => pinService.setParentPin('123'), throwsArgumentError);
      expect(() => pinService.setParentPin('12345'), throwsArgumentError);
    });

    test('should throw ArgumentError for non-numeric PIN', () async {
      expect(() => pinService.setParentPin('abcd'), throwsArgumentError);
      expect(() => pinService.setParentPin('12a4'), throwsArgumentError);
    });
  });

  group('setTutorPin', () {
    test('should store a bcrypt hash separately from parent PIN', () async {
      const pin = '5678';
      String? storedValue;

      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        storedValue = invocation.namedArguments[Symbol('value')] as String;
      });
      when(
        () => mockStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      await pinService.setTutorPin(pin);

      // Verify write was called with tutor_pin_hash key
      verify(
        () => mockStorage.write(
          key: 'tutor_pin_hash',
          value: any(named: 'value'),
        ),
      ).called(1);

      // Verify stored value is a bcrypt hash
      expect(storedValue, isNot(pin));
      expect(storedValue!.startsWith(r'$2'), isTrue);
    });

    test('should reset lockout state when PIN is changed', () async {
      const pin = '5678';

      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      await pinService.setTutorPin(pin);

      verify(() => mockStorage.delete(key: 'tutor_lockout_count')).called(1);
      verify(
        () => mockStorage.delete(key: 'tutor_lockout_timestamp'),
      ).called(1);
    });
  });

  group('verifyParentPin', () {
    test('should return true for correct PIN', () async {
      const pin = '1234';

      // First set the PIN to get a real bcrypt hash
      String? storedHash;
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        if (invocation.namedArguments[Symbol('key')] == 'parent_pin_hash') {
          storedHash = invocation.namedArguments[Symbol('value')] as String;
        }
      });
      when(
        () => mockStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      await pinService.setParentPin(pin);

      // Now verify with the stored hash
      when(
        () => mockStorage.read(key: 'parent_pin_hash'),
      ).thenAnswer((_) async => storedHash);
      when(
        () => mockStorage.read(key: 'parent_lockout_timestamp'),
      ).thenAnswer((_) async => null);

      final result = await pinService.verifyParentPin(pin);

      expect(result, isTrue);
    });

    test('should return false for incorrect PIN', () async {
      const correctPin = '1234';
      const incorrectPin = '9999';

      String? storedHash;
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        if (invocation.namedArguments[Symbol('key')] == 'parent_pin_hash') {
          storedHash = invocation.namedArguments[Symbol('value')] as String;
        }
      });
      when(
        () => mockStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      await pinService.setParentPin(correctPin);

      when(
        () => mockStorage.read(key: 'parent_pin_hash'),
      ).thenAnswer((_) async => storedHash);
      when(
        () => mockStorage.read(key: 'parent_lockout_timestamp'),
      ).thenAnswer((_) async => null);
      when(
        () => mockStorage.read(key: 'parent_lockout_count'),
      ).thenAnswer((_) async => null);

      final result = await pinService.verifyParentPin(incorrectPin);

      expect(result, isFalse);
    });

    test('should return false when no PIN is set', () async {
      when(
        () => mockStorage.read(key: 'parent_pin_hash'),
      ).thenAnswer((_) async => null);
      when(
        () => mockStorage.read(key: 'parent_lockout_timestamp'),
      ).thenAnswer((_) async => null);

      final result = await pinService.verifyParentPin('1234');

      expect(result, isFalse);
    });

    test(
      'should reset lockout counter after successful verification',
      () async {
        const pin = '1234';

        String? storedHash;
        when(
          () => mockStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((invocation) async {
          if (invocation.namedArguments[Symbol('key')] == 'parent_pin_hash') {
            storedHash = invocation.namedArguments[Symbol('value')] as String;
          }
        });
        when(
          () => mockStorage.delete(key: any(named: 'key')),
        ).thenAnswer((_) async {});

        await pinService.setParentPin(pin);

        when(
          () => mockStorage.read(key: 'parent_pin_hash'),
        ).thenAnswer((_) async => storedHash);
        when(
          () => mockStorage.read(key: 'parent_lockout_timestamp'),
        ).thenAnswer((_) async => null);

        await pinService.verifyParentPin(pin);

        // Verify lockout state was reset
        verify(
          () => mockStorage.delete(key: 'parent_lockout_count'),
        ).called(greaterThanOrEqualTo(1));
        verify(
          () => mockStorage.delete(key: 'parent_lockout_timestamp'),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    test('should increment failed attempts counter on incorrect PIN', () async {
      const correctPin = '1234';
      const incorrectPin = '9999';

      String? storedHash;
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        if (invocation.namedArguments[Symbol('key')] == 'parent_pin_hash') {
          storedHash = invocation.namedArguments[Symbol('value')] as String;
        }
      });
      when(
        () => mockStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      await pinService.setParentPin(correctPin);

      when(
        () => mockStorage.read(key: 'parent_pin_hash'),
      ).thenAnswer((_) async => storedHash);
      when(
        () => mockStorage.read(key: 'parent_lockout_timestamp'),
      ).thenAnswer((_) async => null);
      when(
        () => mockStorage.read(key: 'parent_lockout_count'),
      ).thenAnswer((_) async => null);

      await pinService.verifyParentPin(incorrectPin);

      verify(
        () => mockStorage.write(key: 'parent_lockout_count', value: '1'),
      ).called(1);
    });

    test('should trigger lockout after max failed attempts', () async {
      const correctPin = '1234';
      const incorrectPin = '9999';

      String? storedHash;
      int attemptCount = 0;

      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        final key = invocation.namedArguments[Symbol('key')] as String;
        if (key == 'parent_pin_hash') {
          storedHash = invocation.namedArguments[Symbol('value')] as String;
        } else if (key == 'parent_lockout_count') {
          attemptCount++;
        }
      });
      when(
        () => mockStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      await pinService.setParentPin(correctPin);

      when(
        () => mockStorage.read(key: 'parent_pin_hash'),
      ).thenAnswer((_) async => storedHash);
      when(
        () => mockStorage.read(key: 'parent_lockout_timestamp'),
      ).thenAnswer((_) async => null);
      when(() => mockStorage.read(key: 'parent_lockout_count')).thenAnswer(
        (_) async => attemptCount > 0 ? attemptCount.toString() : null,
      );

      // Attempt 5 incorrect PINs
      for (var i = 0; i < 5; i++) {
        await pinService.verifyParentPin(incorrectPin);
      }

      // Verify lockout timestamp was set
      verify(
        () => mockStorage.write(
          key: 'parent_lockout_timestamp',
          value: any(named: 'value'),
        ),
      ).called(1);
    });

    test('should throw PinLockoutException when locked out', () async {
      // Set lockout timestamp to now
      final lockoutTimestamp = DateTime.now().millisecondsSinceEpoch;

      when(
        () => mockStorage.read(key: 'parent_lockout_timestamp'),
      ).thenAnswer((_) async => lockoutTimestamp.toString());

      expect(
        () => pinService.verifyParentPin('1234'),
        throwsA(isA<PinLockoutException>()),
      );
    });

    test('should allow verification after lockout period expires', () async {
      const pin = '1234';

      // Set lockout timestamp to 6 minutes ago (lockout is 5 minutes)
      final lockoutTimestamp = DateTime.now()
          .subtract(const Duration(minutes: 6))
          .millisecondsSinceEpoch;

      String? storedHash;
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        if (invocation.namedArguments[Symbol('key')] == 'parent_pin_hash') {
          storedHash = invocation.namedArguments[Symbol('value')] as String;
        }
      });
      when(
        () => mockStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      await pinService.setParentPin(pin);

      when(
        () => mockStorage.read(key: 'parent_pin_hash'),
      ).thenAnswer((_) async => storedHash);
      when(
        () => mockStorage.read(key: 'parent_lockout_timestamp'),
      ).thenAnswer((_) async => lockoutTimestamp.toString());

      // Should not throw exception
      final result = await pinService.verifyParentPin(pin);
      expect(result, isTrue);
    });
  });

  group('verifyTutorPin', () {
    test('should return true for correct PIN', () async {
      const pin = '5678';

      String? storedHash;
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        if (invocation.namedArguments[Symbol('key')] == 'tutor_pin_hash') {
          storedHash = invocation.namedArguments[Symbol('value')] as String;
        }
      });
      when(
        () => mockStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      await pinService.setTutorPin(pin);

      when(
        () => mockStorage.read(key: 'tutor_pin_hash'),
      ).thenAnswer((_) async => storedHash);
      when(
        () => mockStorage.read(key: 'tutor_lockout_timestamp'),
      ).thenAnswer((_) async => null);

      final result = await pinService.verifyTutorPin(pin);

      expect(result, isTrue);
    });

    test('should return false for incorrect PIN', () async {
      const correctPin = '5678';
      const incorrectPin = '1111';

      String? storedHash;
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        if (invocation.namedArguments[Symbol('key')] == 'tutor_pin_hash') {
          storedHash = invocation.namedArguments[Symbol('value')] as String;
        }
      });
      when(
        () => mockStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      await pinService.setTutorPin(correctPin);

      when(
        () => mockStorage.read(key: 'tutor_pin_hash'),
      ).thenAnswer((_) async => storedHash);
      when(
        () => mockStorage.read(key: 'tutor_lockout_timestamp'),
      ).thenAnswer((_) async => null);
      when(
        () => mockStorage.read(key: 'tutor_lockout_count'),
      ).thenAnswer((_) async => null);

      final result = await pinService.verifyTutorPin(incorrectPin);

      expect(result, isFalse);
    });
  });

  group('hasParentPin', () {
    test('should return false before any PIN is set', () async {
      when(
        () => mockStorage.read(key: 'parent_pin_hash'),
      ).thenAnswer((_) async => null);

      final result = await pinService.hasParentPin();

      expect(result, isFalse);
    });

    test('should return true after setParentPin is called', () async {
      const pin = '1234';

      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      await pinService.setParentPin(pin);

      when(
        () => mockStorage.read(key: 'parent_pin_hash'),
      ).thenAnswer((_) async => 'some_hash_value');

      final result = await pinService.hasParentPin();

      expect(result, isTrue);
    });
  });

  group('hasTutorPin', () {
    test('should return false before any PIN is set', () async {
      when(
        () => mockStorage.read(key: 'tutor_pin_hash'),
      ).thenAnswer((_) async => null);

      final result = await pinService.hasTutorPin();

      expect(result, isFalse);
    });

    test('should return true after setTutorPin is called', () async {
      const pin = '5678';

      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      await pinService.setTutorPin(pin);

      when(
        () => mockStorage.read(key: 'tutor_pin_hash'),
      ).thenAnswer((_) async => 'some_hash_value');

      final result = await pinService.hasTutorPin();

      expect(result, isTrue);
    });
  });

  group('lockout remaining minutes', () {
    test('should return 0 when not locked out', () async {
      when(
        () => mockStorage.read(key: 'parent_lockout_timestamp'),
      ).thenAnswer((_) async => null);

      final result = await pinService.getParentLockoutRemainingMinutes();

      expect(result, equals(0));
    });

    test('should return correct remaining minutes when locked out', () async {
      // Set lockout to 3 minutes ago (2 minutes remaining)
      final lockoutTimestamp = DateTime.now()
          .subtract(const Duration(minutes: 3))
          .millisecondsSinceEpoch;

      when(
        () => mockStorage.read(key: 'parent_lockout_timestamp'),
      ).thenAnswer((_) async => lockoutTimestamp.toString());

      final result = await pinService.getParentLockoutRemainingMinutes();

      // Should be approximately 2 minutes (with rounding)
      expect(result, greaterThanOrEqualTo(1));
      expect(result, lessThanOrEqualTo(3));
    });
  });
}
