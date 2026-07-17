import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/program_starting_position.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';

/// B2 regression tests — ProgramStartingPosition window enforcement.
///
/// Verifies the [today − 30 days, today] constraint is applied uniformly,
/// with no per-program override.
void main() {
  // Reference "today" for all tests.
  final today = DateTime(2026, 5, 20); // 2026-05-20, local midnight

  group('ProgramStartingPosition.create — B2 window boundary tests', () {
    test('exact today is accepted (N = 0)', () {
      final pos = ProgramStartingPosition.create(
        startDate: today,
        today: today,
      );
      expect(pos.startDate, equals(today));
      expect(pos.daysFromToday(today), 0);
    });

    test('yesterday is accepted (N = 1)', () {
      final yesterday = today.subtract(const Duration(days: 1));
      final pos = ProgramStartingPosition.create(
        startDate: yesterday,
        today: today,
      );
      expect(pos.daysFromToday(today), 1);
    });

    test('30 days ago is accepted (max lookback)', () {
      final thirtyAgo = today.subtract(const Duration(days: 30));
      final pos = ProgramStartingPosition.create(
        startDate: thirtyAgo,
        today: today,
      );
      expect(pos.daysFromToday(today), 30);
    });

    test('31 days ago is rejected (outside window)', () {
      final thirtyOneAgo = today.subtract(const Duration(days: 31));
      expect(
        () => ProgramStartingPosition.create(
          startDate: thirtyOneAgo,
          today: today,
        ),
        throwsA(isA<StartDateWindowException>()),
      );
    });

    test('tomorrow is rejected (future date)', () {
      final tomorrow = today.add(const Duration(days: 1));
      expect(
        () => ProgramStartingPosition.create(startDate: tomorrow, today: today),
        throwsA(isA<StartDateWindowException>()),
      );
    });

    test('one year in future is rejected', () {
      final future = today.add(const Duration(days: 365));
      expect(
        () => ProgramStartingPosition.create(startDate: future, today: today),
        throwsA(isA<StartDateWindowException>()),
      );
    });

    test('StartDateWindowException extends ValidationException', () {
      final future = today.add(const Duration(days: 1));
      expect(
        () => ProgramStartingPosition.create(startDate: future, today: today),
        throwsA(isA<ValidationException>()),
      );
    });

    // AUD-core-domain-06 (EH-5): StartDateWindowException must expose a
    // stable, locale-independent identifier alongside its developer-facing
    // free-text message, so presentation can resolve the user-facing string
    // via AppLocalizations/ARB instead of displaying `message` directly (see
    // AppErrorView._configFor in app_error_view_test.dart for the EN+HE
    // resolution proof). The identifier is the inherited
    // `ValidationException.validationCode` field — every current
    // ValidationException leaf, including this one, carries
    // ValidationErrorCode.invalidInput without needing a leaf-specific
    // override.
    test(
      'StartDateWindowException exposes a stable validationCode (future date)',
      () {
        final future = today.add(const Duration(days: 1));
        try {
          ProgramStartingPosition.create(startDate: future, today: today);
          fail('expected StartDateWindowException');
        } on StartDateWindowException catch (e) {
          expect(e.validationCode, ValidationErrorCode.invalidInput);
        }
      },
    );

    test('StartDateWindowException exposes a stable validationCode '
        '(too-far-in-past date)', () {
      final thirtyOneAgo = today.subtract(const Duration(days: 31));
      try {
        ProgramStartingPosition.create(startDate: thirtyOneAgo, today: today);
        fail('expected StartDateWindowException');
      } on StartDateWindowException catch (e) {
        expect(e.validationCode, ValidationErrorCode.invalidInput);
      }
    });

    test('sefariaRef is preserved when provided', () {
      final pos = ProgramStartingPosition.create(
        startDate: today,
        today: today,
        sefariaRef: 'Berakhot 42a',
      );
      expect(pos.sefariaRef, 'Berakhot 42a');
    });
  });

  group('ProgramStartingPosition.allowedWindow — picker bounds', () {
    test('returns correct min and max dates', () {
      final (:minDate, :maxDate) = ProgramStartingPosition.allowedWindow(today);
      expect(maxDate, equals(today));
      expect(minDate, equals(today.subtract(const Duration(days: 30))));
    });

    test('window from different reference date', () {
      final refDate = DateTime(2026, 1, 1);
      final (:minDate, :maxDate) = ProgramStartingPosition.allowedWindow(
        refDate,
      );
      expect(maxDate, equals(refDate));
      expect(minDate, equals(DateTime(2025, 12, 2)));
    });
  });

  group('ProgramStartingPosition.daysFromToday', () {
    test('returns 0 when start = today', () {
      final pos = ProgramStartingPosition.create(
        startDate: today,
        today: today,
      );
      expect(pos.daysFromToday(today), 0);
    });

    test('returns 5 when start = today - 5', () {
      final fiveDaysAgo = today.subtract(const Duration(days: 5));
      final pos = ProgramStartingPosition.create(
        startDate: fiveDaysAgo,
        today: today,
      );
      expect(pos.daysFromToday(today), 5);
    });
  });

  group('ProgramStartingPosition.fromLegacyGrammar', () {
    test('null input → today, no sefariaRef', () {
      final pos = ProgramStartingPosition.fromLegacyGrammar(
        rawStartingRef: null,
        today: today,
      );
      expect(pos.startDate, equals(today));
      expect(pos.sefariaRef, isNull);
    });

    test('empty string → today, no sefariaRef', () {
      final pos = ProgramStartingPosition.fromLegacyGrammar(
        rawStartingRef: '',
        today: today,
      );
      expect(pos.startDate, equals(today));
    });

    test('offset:5 → today - 5 days', () {
      final pos = ProgramStartingPosition.fromLegacyGrammar(
        rawStartingRef: 'offset:5',
        today: today,
      );
      expect(pos.startDate, equals(today.subtract(const Duration(days: 5))));
      expect(pos.sefariaRef, isNull);
    });

    test('offset:5|ref:Berakhot 42a → today - 5, with ref', () {
      final pos = ProgramStartingPosition.fromLegacyGrammar(
        rawStartingRef: 'offset:5|ref:Berakhot 42a',
        today: today,
      );
      expect(pos.startDate, equals(today.subtract(const Duration(days: 5))));
      expect(pos.sefariaRef, 'Berakhot 42a');
    });

    test('bare sefariaRef → today, with ref', () {
      final pos = ProgramStartingPosition.fromLegacyGrammar(
        rawStartingRef: 'Berakhot 42a',
        today: today,
      );
      expect(pos.startDate, equals(today));
      expect(pos.sefariaRef, 'Berakhot 42a');
    });

    test('offset:31 rejects (outside window)', () {
      expect(
        () => ProgramStartingPosition.fromLegacyGrammar(
          rawStartingRef: 'offset:31',
          today: today,
        ),
        throwsA(isA<StartDateWindowException>()),
      );
    });
  });

  group('Equality', () {
    test('same date and ref are equal', () {
      final fiveDaysAgo = today.subtract(const Duration(days: 5));
      final a = ProgramStartingPosition.create(
        startDate: fiveDaysAgo,
        today: today,
        sefariaRef: 'Berakhot 42a',
      );
      final b = ProgramStartingPosition.create(
        startDate: fiveDaysAgo,
        today: today,
        sefariaRef: 'Berakhot 42a',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different dates are not equal', () {
      final fiveDaysAgo = today.subtract(const Duration(days: 5));
      final a = ProgramStartingPosition.create(startDate: today, today: today);
      final b = ProgramStartingPosition.create(
        startDate: fiveDaysAgo,
        today: today,
      );
      expect(a, isNot(equals(b)));
    });
  });
}
