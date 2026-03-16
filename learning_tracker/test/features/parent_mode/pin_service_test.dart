/// Unit tests for PinService — covers hashing, verification, lockout, and persistence.
@Tags(['story_10_1'])
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

/// Simple in-memory secure storage backed by a Map, using mocktail stubs.
MockFlutterSecureStorage createMockStorage() {
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

  group('PIN hashing', () {
    test('setParentPin stores a bcrypt hash, not plaintext', () async {
      await pinService.setParentPin('1234');
      final stored = await storage.read(key: 'parent_pin_hash');
      expect(stored, isNotNull);
      expect(stored, isNot('1234'));
      expect(stored, startsWith(r'$2'));
    });

    test('rejects non-4-digit PINs', () async {
      expect(() => pinService.setParentPin('123'), throwsArgumentError);
      expect(() => pinService.setParentPin('12345'), throwsArgumentError);
      expect(() => pinService.setParentPin('abcd'), throwsArgumentError);
    });
  });

  group('PIN verification', () {
    test('correct PIN returns true', () async {
      await pinService.setParentPin('5678');
      final result = await pinService.verifyParentPin('5678');
      expect(result, isTrue);
    });

    test('incorrect PIN returns false', () async {
      await pinService.setParentPin('5678');
      final result = await pinService.verifyParentPin('0000');
      expect(result, isFalse);
    });

    test('returns false when no PIN set', () async {
      final result = await pinService.verifyParentPin('1234');
      expect(result, isFalse);
    });
  });

  group('Lockout', () {
    test('lockout triggers after exactly 5 failed attempts', () async {
      await pinService.setParentPin('1234');
      for (var i = 0; i < 4; i++) {
        expect(await pinService.verifyParentPin('0000'), isFalse);
      }
      // 5th failure triggers lockout
      expect(await pinService.verifyParentPin('0000'), isFalse);
      // Next attempt throws
      expect(
        () => pinService.verifyParentPin('1234'),
        throwsA(isA<PinLockoutException>()),
      );
    });

    test('lockout exception includes remaining minutes', () async {
      await pinService.setParentPin('1234');
      for (var i = 0; i < 5; i++) {
        await pinService.verifyParentPin('0000');
      }
      try {
        await pinService.verifyParentPin('1234');
        fail('Should have thrown');
      } on PinLockoutException catch (e) {
        expect(e.remainingMinutes, greaterThan(0));
        expect(e.remainingMinutes, lessThanOrEqualTo(16));
      }
    });

    test('successful verification resets failed attempt counter', () async {
      await pinService.setParentPin('1234');
      for (var i = 0; i < 3; i++) {
        await pinService.verifyParentPin('0000');
      }
      await pinService.verifyParentPin('1234');

      // Verify count and timestamp are cleared in storage
      final count = await storage.read(key: 'parent_lockout_count');
      expect(count, isNull);
      final timestamp = await storage.read(key: 'parent_lockout_timestamp');
      expect(timestamp, isNull);

      // Counter reset; 4 failures should not trigger lockout
      for (var i = 0; i < 4; i++) {
        expect(await pinService.verifyParentPin('0000'), isFalse);
      }
    });

    test('lockout state persists across PinService instances', () async {
      await pinService.setParentPin('1234');
      for (var i = 0; i < 5; i++) {
        await pinService.verifyParentPin('0000');
      }
      final newService = PinService(storage);
      expect(
        () => newService.verifyParentPin('1234'),
        throwsA(isA<PinLockoutException>()),
      );
    });
  });

  group('hasParentPin', () {
    test('returns false when no PIN set', () async {
      expect(await pinService.hasParentPin(), isFalse);
    });

    test('returns true after PIN is set', () async {
      await pinService.setParentPin('1234');
      expect(await pinService.hasParentPin(), isTrue);
    });
  });

  group('PIN change', () {
    test('setting new PIN resets lockout state', () async {
      await pinService.setParentPin('1234');
      for (var i = 0; i < 5; i++) {
        await pinService.verifyParentPin('0000');
      }
      await pinService.setParentPin('5678');
      expect(await pinService.verifyParentPin('5678'), isTrue);
    });
  });

  group('Device-local only', () {
    test('PIN hash stored only in secure storage', () async {
      await pinService.setParentPin('1234');
      verify(
        () => storage.write(
          key: 'parent_pin_hash',
          value: any(named: 'value'),
        ),
      ).called(1);
    });
  });
}
