// AG-5 mirror for
// lib/features/sacred_time/domain/models/location_fetch_result.dart
// (AUD-sacred_time-05: moved out of data/services/location_service.dart so
// presentation stops importing data/ directly).

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/location_error_code.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/location_fetch_result.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_location.dart';

void main() {
  group('LocationFetchResult', () {
    test('all four variants extend the sealed LocationFetchResult base', () {
      final success = LocationFetchSuccess(
        SacredLocation(
          latitude: 31.7683,
          longitude: 35.2137,
          source: SacredLocationSource.detected,
          fixedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      const permissionDenied = LocationFetchPermissionDenied(
        permanentlyDenied: false,
      );
      const serviceDisabled = LocationFetchServiceDisabled();
      const error = LocationFetchError(LocationErrorCode.unknown);

      expect(success, isA<LocationFetchResult>());
      expect(permissionDenied, isA<LocationFetchResult>());
      expect(serviceDisabled, isA<LocationFetchResult>());
      expect(error, isA<LocationFetchResult>());
    });

    test('is exhaustively switchable over exactly the four variants (sealed '
        'contract relied on by sacred_location_provider.dart and '
        'sacred_time_settings_card.dart)', () {
      LocationFetchResult resultOf(int i) => switch (i) {
        0 => LocationFetchSuccess(
          SacredLocation(
            latitude: 0,
            longitude: 0,
            source: SacredLocationSource.manualCoords,
            fixedAt: DateTime.utc(2026, 1, 1),
          ),
        ),
        1 => const LocationFetchPermissionDenied(permanentlyDenied: true),
        2 => const LocationFetchServiceDisabled(),
        _ => const LocationFetchError(LocationErrorCode.timeout),
      };

      for (var i = 0; i < 4; i++) {
        final label = switch (resultOf(i)) {
          LocationFetchSuccess() => 'success',
          LocationFetchPermissionDenied() => 'permissionDenied',
          LocationFetchServiceDisabled() => 'serviceDisabled',
          LocationFetchError() => 'error',
        };
        expect(label, isNotEmpty);
      }
    });
  });

  group('LocationFetchSuccess', () {
    test('carries the fetched SacredLocation verbatim', () {
      final location = SacredLocation(
        latitude: 32.0853,
        longitude: 34.7818,
        source: SacredLocationSource.detected,
        fixedAt: DateTime.utc(2026, 1, 1),
        countryCode: 'IL',
      );
      final success = LocationFetchSuccess(location);
      expect(success.location, same(location));
    });
  });

  group('LocationFetchPermissionDenied', () {
    test('distinguishes permanently-denied from a plain denial', () {
      const permanent = LocationFetchPermissionDenied(permanentlyDenied: true);
      const transient = LocationFetchPermissionDenied(permanentlyDenied: false);
      expect(permanent.permanentlyDenied, isTrue);
      expect(transient.permanentlyDenied, isFalse);
    });
  });

  group('LocationFetchError', () {
    test('carries a stable LocationErrorCode, never free text (EH-5)', () {
      const error = LocationFetchError(LocationErrorCode.timeout);
      expect(error.code, LocationErrorCode.timeout);
      expect(error.debugDetail, isNull);
    });

    test('debugDetail is retained for logs but is optional', () {
      const error = LocationFetchError(
        LocationErrorCode.unknown,
        debugDetail: 'Exception: getCurrentPosition failed',
      );
      expect(error.debugDetail, 'Exception: getCurrentPosition failed');
    });
  });
}
