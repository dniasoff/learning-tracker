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

    test('returns null when only partial data stored (missing lat)', () async {
      SharedPreferences.setMockInitialValues({
        'sacred_time_longitude': 34.5,
        'sacred_time_fixed_at_ms': 1000000,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(SacredTimePreferences.readLocation(prefs), isNull);
    });

    test('returns null when missing fixedAt', () async {
      SharedPreferences.setMockInitialValues({
        'sacred_time_latitude': 31.5,
        'sacred_time_longitude': 34.5,
        // no fixed_at_ms
      });
      final prefs = await SharedPreferences.getInstance();
      expect(SacredTimePreferences.readLocation(prefs), isNull);
    });
  });

  group('SacredTimePreferences.writeLocation + readLocation', () {
    test('round-trips a location with all fields', () async {
      final prefs = await SharedPreferences.getInstance();
      final fixedAt = DateTime.utc(2026, 5, 14, 12, 0, 0);
      final loc = SacredLocation(
        latitude: 31.7683,
        longitude: 35.2137,
        source: SacredLocationSource.detected,
        fixedAt: fixedAt,
        countryCode: 'IL',
        cityLabel: 'Jerusalem',
      );

      await SacredTimePreferences.writeLocation(prefs, loc);
      final read = SacredTimePreferences.readLocation(prefs);

      expect(read, isNotNull);
      expect(read!.latitude, closeTo(31.7683, 0.0001));
      expect(read.longitude, closeTo(35.2137, 0.0001));
      expect(read.source, SacredLocationSource.detected);
      expect(read.countryCode, 'IL');
      expect(read.cityLabel, 'Jerusalem');
      expect(read.fixedAt.isUtc, isTrue);
      expect(
        read.fixedAt.millisecondsSinceEpoch,
        fixedAt.millisecondsSinceEpoch,
      );
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

    test('round-trips a location without optional fields', () async {
      final prefs = await SharedPreferences.getInstance();
      final loc = SacredLocation(
        latitude: 40.7128,
        longitude: -74.0060,
        source: SacredLocationSource.manualCoords,
        fixedAt: DateTime.utc(2026, 1, 1),
        // no countryCode or cityLabel
      );

      await SacredTimePreferences.writeLocation(prefs, loc);
      final read = SacredTimePreferences.readLocation(prefs);

      expect(read, isNotNull);
      expect(read!.countryCode, isNull);
      expect(read.cityLabel, isNull);
      expect(read.source, SacredLocationSource.manualCoords);
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

    test('unknown source name falls back to detected', () async {
      // Seed with a source name that does not match any enum value.
      SharedPreferences.setMockInitialValues({
        'sacred_time_latitude': 31.0,
        'sacred_time_longitude': 35.0,
        'sacred_time_fixed_at_ms': 0,
        'sacred_time_source': 'unknownSource',
      });
      final prefs = await SharedPreferences.getInstance();
      final loc = SacredTimePreferences.readLocation(prefs);

      expect(loc, isNotNull);
      expect(loc!.source, SacredLocationSource.detected);
    });

    test('overwriting location replaces previous values', () async {
      final prefs = await SharedPreferences.getInstance();
      final first = SacredLocation(
        latitude: 10.0,
        longitude: 20.0,
        source: SacredLocationSource.detected,
        fixedAt: DateTime.utc(2026, 1, 1),
        countryCode: 'US',
        cityLabel: 'New York',
      );
      final second = SacredLocation(
        latitude: 51.5,
        longitude: -0.12,
        source: SacredLocationSource.manualCity,
        fixedAt: DateTime.utc(2026, 5, 1),
        countryCode: 'GB',
        cityLabel: 'London',
      );

      await SacredTimePreferences.writeLocation(prefs, first);
      await SacredTimePreferences.writeLocation(prefs, second);
      final read = SacredTimePreferences.readLocation(prefs);

      expect(read!.latitude, closeTo(51.5, 0.01));
      expect(read.countryCode, 'GB');
      expect(read.cityLabel, 'London');
    });
  });

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
