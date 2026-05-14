// Tests for SacredTimePreferences — covers readLocation, writeLocation,
// readInIsrael, writeInIsrael using SharedPreferences mock.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sacred_time/data/services/sacred_time_preferences.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_location.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // =========================================================================
  // readLocation
  // =========================================================================

  group('SacredTimePreferences.readLocation', () {
    test('returns null when no location stored', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(SacredTimePreferences.readLocation(prefs), isNull);
    });

    test('returns null when lat/long present but fixedAt missing', () async {
      SharedPreferences.setMockInitialValues({
        'sacred_time_latitude': 31.7683,
        'sacred_time_longitude': 35.2137,
        // no sacred_time_fixed_at_ms
      });
      final prefs = await SharedPreferences.getInstance();
      expect(SacredTimePreferences.readLocation(prefs), isNull);
    });

    test('round-trips a location via write then read', () async {
      final prefs = await SharedPreferences.getInstance();
      final loc = SacredLocation(
        latitude: 31.7683,
        longitude: 35.2137,
        source: SacredLocationSource.detected,
        fixedAt: DateTime.utc(2026, 1, 15, 10),
        countryCode: 'IL',
        cityLabel: 'Jerusalem',
      );

      await SacredTimePreferences.writeLocation(prefs, loc);
      final restored = SacredTimePreferences.readLocation(prefs);

      expect(restored, isNotNull);
      expect(restored!.latitude, closeTo(31.7683, 0.0001));
      expect(restored.longitude, closeTo(35.2137, 0.0001));
      expect(restored.source, SacredLocationSource.detected);
      expect(restored.countryCode, 'IL');
      expect(restored.cityLabel, 'Jerusalem');
    });

    test('reads location without countryCode and cityLabel', () async {
      final prefs = await SharedPreferences.getInstance();
      final loc = SacredLocation(
        latitude: 51.5,
        longitude: -0.12,
        source: SacredLocationSource.manualCoords,
        fixedAt: DateTime.utc(2026, 2, 1),
      );

      await SacredTimePreferences.writeLocation(prefs, loc);
      final restored = SacredTimePreferences.readLocation(prefs);

      expect(restored, isNotNull);
      expect(restored!.countryCode, isNull);
      expect(restored.cityLabel, isNull);
      expect(restored.source, SacredLocationSource.manualCoords);
    });

    test('falls back to detected source for unknown source name', () async {
      SharedPreferences.setMockInitialValues({
        'sacred_time_latitude': 31.7,
        'sacred_time_longitude': 35.2,
        'sacred_time_fixed_at_ms': 1000000,
        'sacred_time_source': 'unknownSource',
      });
      final prefs = await SharedPreferences.getInstance();
      final loc = SacredTimePreferences.readLocation(prefs);
      expect(loc?.source, SacredLocationSource.detected);
    });
  });

  // =========================================================================
  // readInIsrael / writeInIsrael
  // =========================================================================

  group('SacredTimePreferences.readInIsrael', () {
    test('returns false by default', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(SacredTimePreferences.readInIsrael(prefs), isFalse);
    });

    test('returns persisted value', () async {
      final prefs = await SharedPreferences.getInstance();
      await SacredTimePreferences.writeInIsrael(prefs, true);
      expect(SacredTimePreferences.readInIsrael(prefs), isTrue);
    });

    test('writeInIsrael false persists correctly', () async {
      final prefs = await SharedPreferences.getInstance();
      await SacredTimePreferences.writeInIsrael(prefs, true);
      await SacredTimePreferences.writeInIsrael(prefs, false);
      expect(SacredTimePreferences.readInIsrael(prefs), isFalse);
    });
  });
}
