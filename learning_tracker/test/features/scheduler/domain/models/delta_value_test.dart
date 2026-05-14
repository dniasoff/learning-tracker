/// Tests for [DateDelta], [PaceDelta], [DateScheduleDelta], [PaceScheduleDelta].
///
/// Verifies equality, hashCode, and toString for all delta value types.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/domain/models/delta_value.dart';

void main() {
  // ─── DateDelta ─────────────────────────────────────────────────────────────

  group('DateDelta', () {
    test('equality: same days are equal', () {
      expect(const DateDelta(5), const DateDelta(5));
    });

    test('equality: different days are not equal', () {
      expect(const DateDelta(5), isNot(const DateDelta(3)));
    });

    test('equality: not equal to different type', () {
      expect(const DateDelta(5) == const PaceDelta(5), isFalse);
    });

    test('hashCode: equal objects have equal hash', () {
      expect(const DateDelta(5).hashCode, const DateDelta(5).hashCode);
    });

    test('hashCode: unequal objects have different hash', () {
      expect(const DateDelta(5).hashCode, isNot(const DateDelta(6).hashCode));
    });

    test('toString includes days value', () {
      expect(const DateDelta(7).toString(), contains('7'));
    });

    test('positive days (ahead)', () {
      expect(const DateDelta(10).days, 10);
    });

    test('negative days (behind)', () {
      expect(const DateDelta(-3).days, -3);
    });

    test('zero delta', () {
      expect(const DateDelta(0).days, 0);
    });
  });

  // ─── PaceDelta ─────────────────────────────────────────────────────────────

  group('PaceDelta', () {
    test('equality: same itemsPerWeek are equal', () {
      expect(const PaceDelta(12), const PaceDelta(12));
    });

    test('equality: different itemsPerWeek are not equal', () {
      expect(const PaceDelta(12), isNot(const PaceDelta(5)));
    });

    test('equality: not equal to different type', () {
      expect(const PaceDelta(5) == const DateDelta(5), isFalse);
    });

    test('hashCode: equal objects have equal hash', () {
      expect(const PaceDelta(5).hashCode, const PaceDelta(5).hashCode);
    });

    test('hashCode: unequal objects have different hash', () {
      expect(const PaceDelta(5).hashCode, isNot(const PaceDelta(-5).hashCode));
    });

    test('toString includes itemsPerWeek value', () {
      expect(const PaceDelta(-3).toString(), contains('-3'));
    });

    test('positive itemsPerWeek (surplus)', () {
      expect(const PaceDelta(7).itemsPerWeek, 7);
    });

    test('negative itemsPerWeek (deficit)', () {
      expect(const PaceDelta(-5).itemsPerWeek, -5);
    });
  });

  // ─── DateScheduleDelta ─────────────────────────────────────────────────────

  group('DateScheduleDelta', () {
    test('wraps a DateDelta', () {
      const delta = DateScheduleDelta(DateDelta(4));
      expect(delta.value, const DateDelta(4));
    });

    test('equality: same value are equal', () {
      expect(
        const DateScheduleDelta(DateDelta(4)),
        const DateScheduleDelta(DateDelta(4)),
      );
    });

    test('equality: different values are not equal', () {
      expect(
        const DateScheduleDelta(DateDelta(4)),
        isNot(const DateScheduleDelta(DateDelta(5))),
      );
    });

    test('equality: not equal to PaceScheduleDelta', () {
      const a = DateScheduleDelta(DateDelta(5));
      const b = PaceScheduleDelta(PaceDelta(5));
      expect(a == b, isFalse);
    });

    test('hashCode: equal objects have equal hash', () {
      expect(
        const DateScheduleDelta(DateDelta(9)).hashCode,
        const DateScheduleDelta(DateDelta(9)).hashCode,
      );
    });

    test('toString includes nested value', () {
      expect(
        const DateScheduleDelta(DateDelta(3)).toString(),
        contains('3'),
      );
    });

    test('is a ScheduleDelta', () {
      expect(
        const DateScheduleDelta(DateDelta(1)),
        isA<ScheduleDelta>(),
      );
    });
  });

  // ─── PaceScheduleDelta ─────────────────────────────────────────────────────

  group('PaceScheduleDelta', () {
    test('wraps a PaceDelta', () {
      const delta = PaceScheduleDelta(PaceDelta(8));
      expect(delta.value, const PaceDelta(8));
    });

    test('equality: same value are equal', () {
      expect(
        const PaceScheduleDelta(PaceDelta(8)),
        const PaceScheduleDelta(PaceDelta(8)),
      );
    });

    test('equality: different values are not equal', () {
      expect(
        const PaceScheduleDelta(PaceDelta(8)),
        isNot(const PaceScheduleDelta(PaceDelta(9))),
      );
    });

    test('equality: not equal to DateScheduleDelta', () {
      const a = PaceScheduleDelta(PaceDelta(5));
      const b = DateScheduleDelta(DateDelta(5));
      expect(a == b, isFalse);
    });

    test('hashCode: equal objects have equal hash', () {
      expect(
        const PaceScheduleDelta(PaceDelta(6)).hashCode,
        const PaceScheduleDelta(PaceDelta(6)).hashCode,
      );
    });

    test('toString includes nested value', () {
      expect(
        const PaceScheduleDelta(PaceDelta(-7)).toString(),
        contains('-7'),
      );
    });

    test('is a ScheduleDelta', () {
      expect(
        const PaceScheduleDelta(PaceDelta(1)),
        isA<ScheduleDelta>(),
      );
    });
  });
}
