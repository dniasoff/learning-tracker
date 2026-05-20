import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/pin.dart';

void main() {
  group('Pin', () {
    // -------------------------------------------------------------------------
    // Construction + validation
    // -------------------------------------------------------------------------

    group('parse', () {
      test('accepts exactly 4 digits', () {
        final pin = Pin.parse('1234');
        expect(pin.value, '1234');
      });

      test('accepts 4 zeros', () {
        expect(Pin.parse('0000').value, '0000');
      });

      test('throws FormatException for 3 digits', () {
        expect(() => Pin.parse('123'), throwsA(isA<FormatException>()));
      });

      test('throws FormatException for 5 digits', () {
        expect(() => Pin.parse('12345'), throwsA(isA<FormatException>()));
      });

      test('throws FormatException for empty string', () {
        expect(() => Pin.parse(''), throwsA(isA<FormatException>()));
      });

      test('throws FormatException when contains letters', () {
        expect(() => Pin.parse('12ab'), throwsA(isA<FormatException>()));
      });

      test('throws FormatException when contains spaces', () {
        expect(() => Pin.parse('12 4'), throwsA(isA<FormatException>()));
      });

      test('throws FormatException for whitespace-padded input', () {
        // Pin does NOT trim — caller must validate raw form exactly.
        expect(() => Pin.parse(' 123'), throwsA(isA<FormatException>()));
      });
    });

    group('tryParse', () {
      test('returns null for null', () {
        expect(Pin.tryParse(null), isNull);
      });

      test('returns null for invalid string', () {
        expect(Pin.tryParse('abc'), isNull);
      });

      test('returns null for empty string', () {
        expect(Pin.tryParse(''), isNull);
      });

      test('returns Pin for valid 4 digits', () {
        expect(Pin.tryParse('9876')?.value, '9876');
      });
    });

    // -------------------------------------------------------------------------
    // Equality + hash
    // -------------------------------------------------------------------------

    group('equality', () {
      test('equal for same digits', () {
        expect(Pin.parse('1111'), equals(Pin.parse('1111')));
      });

      test('not equal for different digits', () {
        expect(Pin.parse('1234'), isNot(equals(Pin.parse('4321'))));
      });

      test('hashCode consistent with equality', () {
        expect(
          Pin.parse('5678').hashCode,
          equals(Pin.parse('5678').hashCode),
        );
      });

      test('usable in Set', () {
        final set = {
          Pin.parse('1111'),
          Pin.parse('1111'),
          Pin.parse('2222'),
        };
        expect(set.length, 2);
      });
    });

    // -------------------------------------------------------------------------
    // Security — value must not leak via toString
    // -------------------------------------------------------------------------

    test('toString does not reveal digits', () {
      final pin = Pin.parse('9999');
      final str = pin.toString();
      expect(str.contains('9999'), isFalse);
      expect(str, contains('****'));
    });
  });
}
