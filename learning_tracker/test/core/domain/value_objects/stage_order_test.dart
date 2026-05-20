import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/stage_order.dart';

void main() {
  group('StageOrder', () {
    // -------------------------------------------------------------------------
    // Construction + validation
    // -------------------------------------------------------------------------

    group('construction', () {
      test('constructs with value 1', () {
        expect(StageOrder(1).value, 1);
      });

      test('constructs with value greater than 1', () {
        expect(StageOrder(3).value, 3);
      });

      test('throws ArgumentError for value 0', () {
        expect(() => StageOrder(0), throwsArgumentError);
      });

      test('throws ArgumentError for negative value', () {
        expect(() => StageOrder(-1), throwsArgumentError);
      });
    });

    // -------------------------------------------------------------------------
    // Ordering helpers
    // -------------------------------------------------------------------------

    group('isFirst', () {
      test('true for value 1', () {
        expect(StageOrder(1).isFirst, isTrue);
      });

      test('false for value 2', () {
        expect(StageOrder(2).isFirst, isFalse);
      });
    });

    group('precedes', () {
      test('true when other is exactly one greater', () {
        final s1 = StageOrder(1);
        final s2 = StageOrder(2);
        expect(s1.precedes(s2), isTrue);
      });

      test('false when other is two greater', () {
        final s1 = StageOrder(1);
        final s3 = StageOrder(3);
        expect(s1.precedes(s3), isFalse);
      });

      test('false for equal stages', () {
        final s2a = StageOrder(2);
        final s2b = StageOrder(2);
        expect(s2a.precedes(s2b), isFalse);
      });
    });

    group('next', () {
      test('returns value + 1', () {
        expect(StageOrder(1).next, StageOrder(2));
      });

      test('chained next works', () {
        expect(StageOrder(1).next.next.value, 3);
      });
    });

    group('isMonotonicFrom', () {
      test('empty list is monotonic', () {
        expect(StageOrder.isMonotonicFrom([]), isTrue);
      });

      test('single element starting at 1 is monotonic', () {
        expect(StageOrder.isMonotonicFrom([StageOrder(1)]), isTrue);
      });

      test('consecutive 1,2,3 is monotonic', () {
        expect(
          StageOrder.isMonotonicFrom([
            StageOrder(1),
            StageOrder(2),
            StageOrder(3),
          ]),
          isTrue,
        );
      });

      test('sequence with gap is not monotonic', () {
        expect(
          StageOrder.isMonotonicFrom([
            StageOrder(1),
            StageOrder(3), // gap: missing 2
          ]),
          isFalse,
        );
      });

      test('sequence starting at 2 is not monotonic from 1', () {
        expect(
          StageOrder.isMonotonicFrom([StageOrder(2), StageOrder(3)]),
          isFalse,
        );
      });

      test('out-of-order input is sorted before checking', () {
        expect(
          StageOrder.isMonotonicFrom([
            StageOrder(3),
            StageOrder(1),
            StageOrder(2),
          ]),
          isTrue,
        );
      });
    });

    // -------------------------------------------------------------------------
    // Comparators
    // -------------------------------------------------------------------------

    group('comparison operators', () {
      test('less-than', () {
        expect(StageOrder(1) < StageOrder(2), isTrue);
        expect(StageOrder(2) < StageOrder(1), isFalse);
      });

      test('less-than-or-equal', () {
        expect(StageOrder(2) <= StageOrder(2), isTrue);
        expect(StageOrder(3) <= StageOrder(2), isFalse);
      });

      test('greater-than', () {
        expect(StageOrder(3) > StageOrder(2), isTrue);
        expect(StageOrder(1) > StageOrder(2), isFalse);
      });

      test('greater-than-or-equal', () {
        expect(StageOrder(2) >= StageOrder(2), isTrue);
        expect(StageOrder(1) >= StageOrder(2), isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // Equality + hash
    // -------------------------------------------------------------------------

    group('equality', () {
      test('equal for same value', () {
        expect(StageOrder(2), equals(StageOrder(2)));
      });

      test('not equal for different values', () {
        expect(StageOrder(1), isNot(equals(StageOrder(2))));
      });

      test('hashCode consistent with equality', () {
        expect(StageOrder(3).hashCode, equals(StageOrder(3).hashCode));
      });

      test('usable in Set', () {
        final set = {StageOrder(1), StageOrder(1), StageOrder(2)};
        expect(set.length, 2);
      });
    });

    test('toString contains value', () {
      expect(StageOrder(1).toString(), contains('1'));
    });
  });
}
