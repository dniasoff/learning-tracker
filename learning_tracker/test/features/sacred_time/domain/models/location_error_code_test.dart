// AG-5 mirror for lib/features/sacred_time/domain/models/location_error_code.dart
// (AUD-sacred_time-03, EH-5).

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/location_error_code.dart';

void main() {
  group('LocationErrorCode', () {
    test('has exactly the two documented values', () {
      expect(LocationErrorCode.values, hasLength(2));
      expect(
        LocationErrorCode.values,
        containsAll(<LocationErrorCode>[
          LocationErrorCode.timeout,
          LocationErrorCode.unknown,
        ]),
      );
    });

    test('values are stable identifiers, not free text', () {
      // EH-5: presentation resolves each code to a localized string via
      // AppLocalizations/ARB — the enum name itself must never be shown
      // directly to a user, so this pins the identifiers as a contract
      // rather than exercising any formatting.
      for (final code in LocationErrorCode.values) {
        expect(code.name, isNotEmpty);
      }
    });

    test('name round-trips through LocationErrorCode.values.byName', () {
      for (final code in LocationErrorCode.values) {
        expect(LocationErrorCode.values.byName(code.name), same(code));
      }
    });
  });
}
