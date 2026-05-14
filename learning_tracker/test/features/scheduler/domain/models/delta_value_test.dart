/// Tests for [DateDelta], [PaceDelta], [DateScheduleDelta], [PaceScheduleDelta].
///
/// Verifies equality, hashCode, and toString for all delta value types.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/domain/models/delta_value.dart';

void main() {
  // ─── DateDelta ─────────────────────────────────────────────────────────────

  group('DateDelta', () {
    test('stores the days value', () {
      expect(const DateDelta(5).days, 5);
      expect(const DateDelta(-3).days, -3);
      expect(const DateDelta(0).days, 0);
    });

    test('equality: same days are equal', () {
      expect(const DateDelta(5), const DateDelta(5));
    });

    test('equality: different days are not equal', () {
      expect(const DateDelta(5), isNot(const DateDelta(3)));
    });

    test('equality: not equal to different type', () {
      expect(const DateDelta(5) == const PaceDelta(5), isFalse);
    });

    test('equality: DateDelta != non-DateDelta', () {
      expect(const DateDelta(5), isNot(equals('five')));
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

    test('toString exact format', () {
      expect(const DateDelta(5).toString(), 'DateDelta(5)');
      expect(const DateDelta(-3).toString(), 'DateDelta(-3)');
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
    test('stores the itemsPerWeek value', () {
      expect(const PaceDelta(10).itemsPerWeek, 10);
      expect(const PaceDelta(-2).itemsPerWeek, -2);
    });

    test('equality: same itemsPerWeek are equal', () {
      expect(const PaceDelta(12), const PaceDelta(12));
    });

    test('equality: different itemsPerWeek are not equal', () {
      expect(const PaceDelta(12), isNot(const PaceDelta(5)));
    });

    test('equality: not equal to different type', () {
      expect(const PaceDelta(5) == const DateDelta(5), isFalse);
    });

    test('equality: PaceDelta != non-PaceDelta', () {
      expect(const PaceDelta(7), isNot(equals('seven')));
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

    test('toString exact format', () {
      expect(const PaceDelta(10).toString(), 'PaceDelta(10)');
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
    const inner = DateDelta(3);

    test('wraps a DateDelta', () {
      const delta = DateScheduleDelta(DateDelta(4));
      expect(delta.value, const DateDelta(4));
    });

    test('stores the inner DateDelta', () {
      expect(const DateScheduleDelta(DateDelta(3)).value, inner);
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

    test('hashCode is consistent for equal instances', () {
      expect(
        const DateScheduleDelta(DateDelta(3)).hashCode,
        const DateScheduleDelta(DateDelta(3)).hashCode,
      );
    });

    test('toString includes nested value', () {
      expect(
        const DateScheduleDelta(DateDelta(3)).toString(),
        contains('3'),
      );
    });

    test('toString exact format', () {
      expect(
        const DateScheduleDelta(DateDelta(3)).toString(),
        'DateScheduleDelta(DateDelta(3))',
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
    const inner = PaceDelta(5);

    test('wraps a PaceDelta', () {
      const delta = PaceScheduleDelta(PaceDelta(8));
      expect(delta.value, const PaceDelta(8));
    });

    test('stores the inner PaceDelta', () {
      expect(const PaceScheduleDelta(PaceDelta(5)).value, inner);
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

    test('equality: PaceScheduleDelta != DateScheduleDelta', () {
      expect(
        const PaceScheduleDelta(PaceDelta(5)),
        isNot(equals(const DateScheduleDelta(DateDelta(5)))),
      );
    });

    test('hashCode: equal objects have equal hash', () {
      expect(
        const PaceScheduleDelta(PaceDelta(6)).hashCode,
        const PaceScheduleDelta(PaceDelta(6)).hashCode,
      );
    });

    test('hashCode is consistent for equal instances', () {
      expect(
        const PaceScheduleDelta(PaceDelta(5)).hashCode,
        const PaceScheduleDelta(PaceDelta(5)).hashCode,
      );
    });

    test('toString includes nested value', () {
      expect(
        const PaceScheduleDelta(PaceDelta(-7)).toString(),
        contains('-7'),
      );
    });

    test('toString exact format', () {
      expect(
        const PaceScheduleDelta(PaceDelta(5)).toString(),
        'PaceScheduleDelta(PaceDelta(5))',
      );
    });

    test('is a ScheduleDelta', () {
      expect(
        const PaceScheduleDelta(PaceDelta(1)),
        isA<ScheduleDelta>(),
      );
    });
  });

  // ─── Cross-type checks ─────────────────────────────────────────────────────

  group('ScheduleDelta — sealed type checks', () {
    test('DateScheduleDelta and PaceScheduleDelta share ScheduleDelta base', () {
      const a = DateScheduleDelta(DateDelta(1));
      const b = PaceScheduleDelta(PaceDelta(1));
      expect(a, isA<ScheduleDelta>());
      expect(b, isA<ScheduleDelta>());
    });

    test('pattern matching on ScheduleDelta works', () {
      const ScheduleDelta delta = DateScheduleDelta(DateDelta(7));
      final days = switch (delta) {
        DateScheduleDelta(value: DateDelta(days: final d)) => d,
        PaceScheduleDelta() => 0,
      };
      expect(days, 7);
    });
  });
}
