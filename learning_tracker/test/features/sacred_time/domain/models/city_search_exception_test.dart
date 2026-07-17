// AG-5 mirror for lib/features/sacred_time/domain/models/city_search_exception.dart
// (AUD-sacred_time-03, EH-5).

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/city_search_exception.dart';

void main() {
  group('CitySearchErrorCode', () {
    test('has exactly the two documented values', () {
      expect(CitySearchErrorCode.values, hasLength(2));
      expect(
        CitySearchErrorCode.values,
        containsAll(<CitySearchErrorCode>[
          CitySearchErrorCode.database,
          CitySearchErrorCode.unknown,
        ]),
      );
    });

    test('values are stable identifiers, not free text', () {
      // EH-5: presentation resolves each code to a localized string via
      // AppLocalizations/ARB — the enum name itself must never be shown
      // directly to a user, so this pins the identifiers as a contract
      // rather than exercising any formatting.
      for (final code in CitySearchErrorCode.values) {
        expect(code.name, isNotEmpty);
      }
    });
  });

  group('CitySearchException', () {
    test('implements Exception (throwable via `throw`, EH-4)', () {
      const exception = CitySearchException(CitySearchErrorCode.database);
      expect(exception, isA<Exception>());
    });

    test('carries the code and optional debugDetail verbatim', () {
      const exception = CitySearchException(
        CitySearchErrorCode.database,
        debugDetail: 'SqliteException: no such table: cities',
      );
      expect(exception.code, CitySearchErrorCode.database);
      expect(exception.debugDetail, 'SqliteException: no such table: cities');
    });

    test('debugDetail defaults to null when not supplied', () {
      const exception = CitySearchException(CitySearchErrorCode.unknown);
      expect(exception.debugDetail, isNull);
    });

    test('toString() never includes debugDetail — logs/diagnostics only, must '
        'never leak into a caught-exception default-print path (EH-5)', () {
      const exception = CitySearchException(
        CitySearchErrorCode.database,
        debugDetail: 'raw SqliteException text that must stay out of toString',
      );
      expect(exception.toString(), isNot(contains('raw SqliteException text')));
      expect(exception.toString(), contains('database'));
    });
  });
}
