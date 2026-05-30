// Tests for:
//   • CitiesRepository — searchByPrefix, topCitiesByCountry, dispose/reuse
//   • LocationService — all 5 permission/result branches
//   • SacredLocationNotifier — setManualCity, setManualCoords, detect, load,
//     inIsrael auto-derive
//
// Coverage targets: sacred_location_provider (19%), cities_repository (0%),
//   location_service (18%).
//
// Strategy:
//   CitiesRepository — in-memory SQLite written to a temp file; a fake
//   PathProviderPlatform points CitiesRepository._doOpen() at that file so
//   asset extraction is bypassed.
//
//   LocationService — GeolocatorPlatform.instance + GeocodingPlatform.instance
//   swapped with fakes that return controllable outcomes; no real GPS.
//
//   SacredLocationNotifier — tested via ProviderContainer with fake
//   LocationService injection; SharedPreferences.setMockInitialValues resets
//   persistence between tests.
//
// Product rules asserted:
//   • No "Personal"/"Standard"/"Custom"/"אישי" track-type labels.
//   • cityLabel and countryCode set correctly on manualCity.
//   • manualCoords does NOT set countryCode (in-Israel toggle untouched).
//   • setManualCity with 'IL' country code → inIsrael true.

@Tags(['sacred_time', 'location', 'cities'])
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geocoding_platform_interface/geocoding_platform_interface.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:learning_tracker/features/sacred_time/data/services/cities_repository.dart';
import 'package:learning_tracker/features/sacred_time/data/services/location_service.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_location.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_location_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

// ── Fake PathProviderPlatform ─────────────────────────────────────────────────

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String docsPath;
  _FakePathProvider(this.docsPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;

  @override
  Future<String?> getTemporaryPath() async => docsPath;

  @override
  Future<String?> getApplicationSupportPath() async => docsPath;

  @override
  Future<String?> getApplicationCachePath() async => docsPath;

  @override
  Future<String?> getExternalStoragePath() async => null;

  @override
  Future<List<String>?> getExternalCachePaths() async => null;

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => null;

  @override
  Future<String?> getLibraryPath() async => docsPath;

  @override
  Future<String?> getDownloadsPath() async => docsPath;
}

// ── In-memory SQLite helper ───────────────────────────────────────────────────

const _citiesSchema = '''
  CREATE TABLE cities (
    id            INTEGER PRIMARY KEY,
    name          TEXT NOT NULL,
    ascii_lower   TEXT NOT NULL,
    country_code  TEXT NOT NULL,
    admin1        TEXT,
    latitude      REAL NOT NULL,
    longitude     REAL NOT NULL,
    timezone      TEXT,
    population    INTEGER NOT NULL DEFAULT 0
  );
''';

/// Create a SQLite database at [filePath] with the cities schema + seed rows.
void _writeCitiesDb(String filePath, List<Map<String, Object?>> rows) {
  final db = sqlite3.open(filePath);
  db.execute(_citiesSchema);
  final stmt = db.prepare('''
    INSERT INTO cities
      (id, name, ascii_lower, country_code, admin1,
       latitude, longitude, timezone, population)
    VALUES (?,?,?,?,?,?,?,?,?)
    ''');
  for (final r in rows) {
    stmt.execute([
      r['id'],
      r['name'],
      r['ascii_lower'],
      r['country_code'],
      r['admin1'],
      r['lat'],
      r['lng'],
      r['timezone'],
      r['population'],
    ]);
  }
  stmt.dispose();
  db.dispose();
}

// Seed data for tests
final _seedRows = <Map<String, Object?>>[
  {
    'id': 1,
    'name': 'Jerusalem',
    'ascii_lower': 'jerusalem',
    'country_code': 'IL',
    'admin1': 'Jerusalem District',
    'lat': 31.7683,
    'lng': 35.2137,
    'timezone': 'Asia/Jerusalem',
    'population': 936425,
  },
  {
    'id': 2,
    'name': 'Tel Aviv',
    'ascii_lower': 'tel aviv',
    'country_code': 'IL',
    'admin1': 'Tel Aviv District',
    'lat': 32.0853,
    'lng': 34.7818,
    'timezone': 'Asia/Jerusalem',
    'population': 432892,
  },
  {
    'id': 3,
    'name': 'New York',
    'ascii_lower': 'new york',
    'country_code': 'US',
    'admin1': 'New York',
    'lat': 40.7128,
    'lng': -74.006,
    'timezone': 'America/New_York',
    'population': 8336817,
  },
  {
    'id': 4,
    'name': 'Los Angeles',
    'ascii_lower': 'los angeles',
    'country_code': 'US',
    'admin1': 'California',
    'lat': 34.0522,
    'lng': -118.2437,
    'timezone': 'America/Los_Angeles',
    'population': 3979576,
  },
  {
    'id': 5,
    'name': 'Jerez',
    'ascii_lower': 'jerez',
    'country_code': 'ES',
    'admin1': null,
    'lat': 36.6864,
    'lng': -6.1381,
    'timezone': 'Europe/Madrid',
    'population': 212879,
  },
];

// ── Fake GeolocatorPlatform ───────────────────────────────────────────────────

enum _GeoScenario {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  permissionWhileInUse,
  success,
  error,
}

class _FakeGeolocatorPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {
  final _GeoScenario scenario;
  final Position? position;

  _FakeGeolocatorPlatform(this.scenario, {this.position});

  @override
  Future<bool> isLocationServiceEnabled() async =>
      scenario != _GeoScenario.serviceDisabled;

  @override
  Future<LocationPermission> checkPermission() async {
    switch (scenario) {
      case _GeoScenario.serviceDisabled:
        return LocationPermission.denied;
      case _GeoScenario.permissionDenied:
        return LocationPermission.denied;
      case _GeoScenario.permissionDeniedForever:
        return LocationPermission.deniedForever;
      case _GeoScenario.permissionWhileInUse:
        return LocationPermission.whileInUse;
      case _GeoScenario.success:
        return LocationPermission.whileInUse;
      case _GeoScenario.error:
        return LocationPermission.whileInUse;
    }
  }

  @override
  Future<LocationPermission> requestPermission() async {
    switch (scenario) {
      case _GeoScenario.permissionDenied:
        return LocationPermission.denied;
      case _GeoScenario.permissionDeniedForever:
        return LocationPermission.deniedForever;
      default:
        return LocationPermission.whileInUse;
    }
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    if (scenario == _GeoScenario.error) {
      throw Exception('GPS hardware failure');
    }
    return position!;
  }

  @override
  Stream<ServiceStatus> getServiceStatusStream() => const Stream.empty();

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      const Stream.empty();

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => null;

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<bool> openLocationSettings() async => false;

  @override
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) => 0;

  @override
  double bearingBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) => 0;
}

// ── Fake GeocodingPlatform ────────────────────────────────────────────────────

class _FakeGeocodingPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements GeocodingPlatform {
  final List<geo.Placemark>? placemarks;
  final bool shouldThrow;

  _FakeGeocodingPlatform({this.placemarks, this.shouldThrow = false});

  @override
  Future<List<geo.Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude, {
    String? localeIdentifier,
  }) async {
    if (shouldThrow) throw Exception('geocoding unavailable');
    return placemarks ?? const [];
  }

  @override
  Future<List<geo.Location>> locationFromAddress(
    String address, {
    String? localeIdentifier,
  }) async => const [];

  @override
  Future<void> setLocaleIdentifier(String localeIdentifier) async {}

  @override
  Future<bool> isPresent() async => !shouldThrow;
}

// ── Helper: build a ProviderContainer with fakes ──────────────────────────────
// Uses a real SacredLocationNotifier with syncWriteFacadeProvider overridden
// to null so no sync I/O occurs in unit tests.

ProviderContainer _makeContainer({LocationService? locationService}) {
  return ProviderContainer(
    overrides: [
      syncWriteFacadeProvider.overrideWithValue(null),
      if (locationService != null)
        locationServiceProvider.overrideWithValue(locationService),
    ],
  );
}

// ── Fake LocationService ──────────────────────────────────────────────────────

class _FakeLocationService extends LocationService {
  final LocationFetchResult _result;
  _FakeLocationService(this._result);

  @override
  Future<LocationFetchResult> detectCurrent() async => _result;
}

// ════════════════════════════════════════════════════════════════════════════
// Tests
// ════════════════════════════════════════════════════════════════════════════

void main() {
  // ── CitiesRepository ────────────────────────────────────────────────────────

  group('CitiesRepository', () {
    late Directory tempDir;
    late CitiesRepository repo;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('cities_test_');
      // Write seeded SQLite to the path CitiesRepository._doOpen() will look for
      final cachedPath = '${tempDir.path}/cities_v1.sqlite';
      _writeCitiesDb(cachedPath, _seedRows);
      // Redirect path_provider to our temp directory
      PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
      repo = CitiesRepository();
    });

    tearDown(() {
      repo.dispose();
      tempDir.deleteSync(recursive: true);
    });

    test('searchByPrefix returns empty list for blank query', () async {
      final results = await repo.searchByPrefix('');
      expect(results, isEmpty);
    });

    test(
      'searchByPrefix returns empty list for whitespace-only query',
      () async {
        final results = await repo.searchByPrefix('   ');
        expect(results, isEmpty);
      },
    );

    test('searchByPrefix matches Jerusalem by prefix "jer"', () async {
      final results = await repo.searchByPrefix('jer');
      expect(results, isNotEmpty);
      expect(results.first.name, 'Jerusalem');
    });

    test('searchByPrefix is case-insensitive (upper-case query)', () async {
      final results = await repo.searchByPrefix('JER');
      expect(results.any((c) => c.name == 'Jerusalem'), isTrue);
    });

    test('searchByPrefix "je" matches both Jerusalem and Jerez', () async {
      final results = await repo.searchByPrefix('je');
      final names = results.map((c) => c.name).toList();
      expect(names, containsAll(['Jerusalem', 'Jerez']));
    });

    test('searchByPrefix sorts by population descending', () async {
      // "je" → Jerusalem (936 425) before Jerez (212 879)
      final results = await repo.searchByPrefix('je');
      expect(results.first.name, 'Jerusalem');
    });

    test('searchByPrefix respects limit parameter', () async {
      // 3 cities start with a letter that matches 'l' (los), limit to 1
      final results = await repo.searchByPrefix('l', limit: 1);
      expect(results.length, 1);
    });

    test('searchByPrefix returns correct City fields', () async {
      final results = await repo.searchByPrefix('jerusalem');
      expect(results, hasLength(1));
      final city = results.first;
      expect(city.id, 1);
      expect(city.countryCode, 'IL');
      expect(city.latitude, closeTo(31.7683, 0.001));
      expect(city.longitude, closeTo(35.2137, 0.001));
      expect(city.population, 936425);
      expect(city.admin1, 'Jerusalem District');
      expect(city.timezone, 'Asia/Jerusalem');
    });

    test('searchByPrefix returns null admin1 when DB row has NULL', () async {
      final results = await repo.searchByPrefix('jerez');
      expect(results, isNotEmpty);
      expect(results.first.admin1, isNull);
    });

    test('topCitiesByCountry returns IL cities sorted by population', () async {
      final results = await repo.topCitiesByCountry('IL');
      expect(results, hasLength(2));
      // Jerusalem is more populous than Tel Aviv
      expect(results.first.name, 'Jerusalem');
      expect(results.last.name, 'Tel Aviv');
    });

    test('topCitiesByCountry normalises country code to upper-case', () async {
      final resultsLower = await repo.topCitiesByCountry('il');
      final resultsUpper = await repo.topCitiesByCountry('IL');
      expect(resultsLower.length, resultsUpper.length);
    });

    test('topCitiesByCountry returns empty list for unknown country', () async {
      final results = await repo.topCitiesByCountry('ZZ');
      expect(results, isEmpty);
    });

    test('topCitiesByCountry respects limit', () async {
      final results = await repo.topCitiesByCountry('US', limit: 1);
      expect(results.length, 1);
      // Highest US population in seed is New York
      expect(results.first.name, 'New York');
    });

    test('dispose then re-create opens a fresh repo without error', () async {
      repo.dispose();
      // Create a fresh instance using the same cached file
      final repo2 = CitiesRepository();
      final results = await repo2.searchByPrefix('new');
      expect(results.any((c) => c.name == 'New York'), isTrue);
      repo2.dispose();
      // Prevent double-dispose in tearDown
      repo = CitiesRepository()..dispose();
    });

    test('consecutive searchByPrefix calls reuse the same DB handle', () async {
      // Two calls should both succeed (no double-dispose)
      final r1 = await repo.searchByPrefix('tel');
      final r2 = await repo.searchByPrefix('tel');
      expect(r1.length, r2.length);
      expect(r1.first.name, r2.first.name);
    });

    test(
      'returned City objects have correct countryCode for US rows',
      () async {
        final results = await repo.topCitiesByCountry('US');
        for (final city in results) {
          expect(city.countryCode, 'US');
        }
      },
    );
  });

  // ── LocationService ─────────────────────────────────────────────────────────

  group('LocationService', () {
    late GeolocatorPlatform originalGeolocator;
    late GeocodingPlatform originalGeocoding;

    setUpAll(() {
      originalGeolocator = GeolocatorPlatform.instance;
      // GeocodingPlatform.instance may be null in headless tests.
      // Assign a no-op platform so tearDown has something to restore.
      originalGeocoding =
          GeocodingPlatform.instance ?? _FakeGeocodingPlatform();
    });

    tearDown(() {
      GeolocatorPlatform.instance = originalGeolocator;
      GeocodingPlatform.instance = originalGeocoding;
    });

    test(
      'detectCurrent → ServiceDisabled when location service is off',
      () async {
        GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
          _GeoScenario.serviceDisabled,
        );

        final result = await const LocationService().detectCurrent();
        expect(result, isA<LocationFetchServiceDisabled>());
      },
    );

    test(
      'detectCurrent → PermissionDenied (non-permanent) when user denies request',
      () async {
        GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
          _GeoScenario.permissionDenied,
        );

        final result = await const LocationService().detectCurrent();
        expect(result, isA<LocationFetchPermissionDenied>());
        final denied = result as LocationFetchPermissionDenied;
        expect(denied.permanentlyDenied, isFalse);
      },
    );

    test(
      'detectCurrent → PermissionDenied (permanent) when deniedForever on check',
      () async {
        GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
          _GeoScenario.permissionDeniedForever,
        );

        final result = await const LocationService().detectCurrent();
        expect(result, isA<LocationFetchPermissionDenied>());
        final denied = result as LocationFetchPermissionDenied;
        expect(denied.permanentlyDenied, isTrue);
      },
    );

    test(
      'detectCurrent → LocationFetchError on GPS hardware exception',
      () async {
        GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
          _GeoScenario.error,
        );
        GeocodingPlatform.instance = _FakeGeocodingPlatform();

        final result = await const LocationService().detectCurrent();
        expect(result, isA<LocationFetchError>());
        final error = result as LocationFetchError;
        expect(error.message, contains('GPS hardware failure'));
      },
    );

    test(
      'detectCurrent → Success with correct lat/lng and IL country code',
      () async {
        final fakePosition = Position(
          latitude: 31.7683,
          longitude: 35.2137,
          timestamp: DateTime.utc(2026, 5, 1),
          accuracy: 10.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
        GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
          _GeoScenario.success,
          position: fakePosition,
        );
        GeocodingPlatform.instance = _FakeGeocodingPlatform(
          placemarks: [const geo.Placemark(isoCountryCode: 'IL')],
        );

        final result = await const LocationService().detectCurrent();
        expect(result, isA<LocationFetchSuccess>());
        final success = result as LocationFetchSuccess;
        expect(success.location.latitude, closeTo(31.7683, 0.001));
        expect(success.location.longitude, closeTo(35.2137, 0.001));
        expect(success.location.source, SacredLocationSource.detected);
        expect(success.location.countryCode, 'IL');
      },
    );

    test(
      'detectCurrent → Success with null countryCode when geocoding empty',
      () async {
        final fakePosition = Position(
          latitude: 40.7128,
          longitude: -74.006,
          timestamp: DateTime.utc(2026, 5, 1),
          accuracy: 10.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
        GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
          _GeoScenario.success,
          position: fakePosition,
        );
        // empty placemarks → countryCode null
        GeocodingPlatform.instance = _FakeGeocodingPlatform(
          placemarks: const [],
        );

        final result = await const LocationService().detectCurrent();
        expect(result, isA<LocationFetchSuccess>());
        final success = result as LocationFetchSuccess;
        expect(success.location.countryCode, isNull);
      },
    );

    test(
      'detectCurrent → Success with null countryCode when geocoding throws',
      () async {
        final fakePosition = Position(
          latitude: 40.0,
          longitude: -75.0,
          timestamp: DateTime.utc(2026, 5, 1),
          accuracy: 10.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
        GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
          _GeoScenario.success,
          position: fakePosition,
        );
        GeocodingPlatform.instance = _FakeGeocodingPlatform(shouldThrow: true);

        final result = await const LocationService().detectCurrent();
        expect(result, isA<LocationFetchSuccess>());
        final success = result as LocationFetchSuccess;
        // Reverse geocoding failure → countryCode is null (best-effort)
        expect(success.location.countryCode, isNull);
      },
    );

    test('detectCurrent normalises country code to upper-case', () async {
      final fakePosition = Position(
        latitude: 31.0,
        longitude: 34.0,
        timestamp: DateTime.utc(2026, 5, 1),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
        _GeoScenario.success,
        position: fakePosition,
      );
      // Simulate a platform that returns lowercase 'il'
      GeocodingPlatform.instance = _FakeGeocodingPlatform(
        placemarks: [const geo.Placemark(isoCountryCode: 'il')],
      );

      final result = await const LocationService().detectCurrent();
      final success = result as LocationFetchSuccess;
      expect(success.location.countryCode, 'IL');
    });
  });

  // ── SacredLocationNotifier ──────────────────────────────────────────────────

  group('SacredLocationNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state is null when no location persisted', () async {
      final container = _makeContainer();

      // Trigger build (and the async _load) by reading the provider.
      container.read(sacredLocationProvider);
      // Pump microtasks so that mock-synchronous SharedPreferences resolves
      // and _load() sets state (if any) before we assert.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(sacredLocationProvider), isNull);
      // Dispose AFTER the async _load() has settled to avoid
      // "Ref used after disposal" from the pending async continuation.
      container.dispose();
    });

    test(
      'initial state loads persisted location from SharedPreferences',
      () async {
        SharedPreferences.setMockInitialValues({
          'sacred_time_latitude': 31.7683,
          'sacred_time_longitude': 35.2137,
          'sacred_time_source': 'manualCity',
          'sacred_time_fixed_at_ms': 1_000_000,
          'sacred_time_country_code': 'IL',
          'sacred_time_city_label': 'Jerusalem',
        });

        final container = _makeContainer();

        // Trigger build and wait for async _load() to complete.
        container.read(sacredLocationProvider);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final loc = container.read(sacredLocationProvider);
        expect(loc, isNotNull);
        expect(loc!.latitude, closeTo(31.7683, 0.001));
        expect(loc.countryCode, 'IL');
        expect(loc.cityLabel, 'Jerusalem');
        expect(loc.source, SacredLocationSource.manualCity);
        container.dispose();
      },
    );

    test('setManualCity sets state with correct fields', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await container
          .read(sacredLocationProvider.notifier)
          .setManualCity(
            latitude: 32.0853,
            longitude: 34.7818,
            cityLabel: 'Tel Aviv',
            countryCode: 'IL',
          );

      final loc = container.read(sacredLocationProvider);
      expect(loc, isNotNull);
      expect(loc!.latitude, closeTo(32.0853, 0.001));
      expect(loc.longitude, closeTo(34.7818, 0.001));
      expect(loc.cityLabel, 'Tel Aviv');
      expect(loc.countryCode, 'IL');
      expect(loc.source, SacredLocationSource.manualCity);
    });

    test('setManualCity persists to SharedPreferences', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await container
          .read(sacredLocationProvider.notifier)
          .setManualCity(
            latitude: 51.5074,
            longitude: -0.1278,
            cityLabel: 'London',
            countryCode: 'GB',
          );

      // Read back from SharedPreferences directly
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('sacred_time_latitude'), closeTo(51.5074, 0.001));
      expect(prefs.getString('sacred_time_city_label'), 'London');
      expect(prefs.getString('sacred_time_country_code'), 'GB');
    });

    test('setManualCity(countryCode: IL) auto-sets inIsrael to true', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await container
          .read(sacredLocationProvider.notifier)
          .setManualCity(
            latitude: 31.7683,
            longitude: 35.2137,
            cityLabel: 'Jerusalem',
            countryCode: 'IL',
          );

      // inIsraelProvider should be invalidated and re-read from prefs
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('sacred_time_in_israel'), isTrue);
    });

    test(
      'setManualCity(countryCode: US) auto-sets inIsrael to false',
      () async {
        final container = _makeContainer();
        addTearDown(container.dispose);

        // First set IL to make sure the flag is being explicitly changed
        await container
            .read(sacredLocationProvider.notifier)
            .setManualCity(
              latitude: 31.7683,
              longitude: 35.2137,
              cityLabel: 'Jerusalem',
              countryCode: 'IL',
            );

        await container
            .read(sacredLocationProvider.notifier)
            .setManualCity(
              latitude: 40.7128,
              longitude: -74.006,
              cityLabel: 'New York',
              countryCode: 'US',
            );

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('sacred_time_in_israel'), isFalse);
      },
    );

    test('setManualCoords sets state without countryCode', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await container
          .read(sacredLocationProvider.notifier)
          .setManualCoords(latitude: 48.8566, longitude: 2.3522);

      final loc = container.read(sacredLocationProvider);
      expect(loc, isNotNull);
      expect(loc!.latitude, closeTo(48.8566, 0.001));
      expect(loc.longitude, closeTo(2.3522, 0.001));
      expect(loc.source, SacredLocationSource.manualCoords);
      // manualCoords MUST NOT set countryCode (product rule: in-Israel
      // toggle is user-controlled for manualCoords)
      expect(loc.countryCode, isNull);
    });

    test('setManualCoords persists to SharedPreferences', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await container
          .read(sacredLocationProvider.notifier)
          .setManualCoords(latitude: 48.8566, longitude: 2.3522);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('sacred_time_latitude'), closeTo(48.8566, 0.001));
      expect(prefs.getDouble('sacred_time_longitude'), closeTo(2.3522, 0.001));
      expect(prefs.getString('sacred_time_source'), 'manualCoords');
    });

    test(
      'detect → ServiceDisabled returns result and does NOT update state',
      () async {
        final fakeService = _FakeLocationService(
          const LocationFetchServiceDisabled(),
        );
        final container = _makeContainer(locationService: fakeService);
        addTearDown(container.dispose);

        final result = await container
            .read(sacredLocationProvider.notifier)
            .detect();

        expect(result, isA<LocationFetchServiceDisabled>());
        expect(container.read(sacredLocationProvider), isNull);
      },
    );

    test(
      'detect → PermissionDenied returns result and does NOT update state',
      () async {
        final fakeService = _FakeLocationService(
          const LocationFetchPermissionDenied(permanentlyDenied: false),
        );
        final container = _makeContainer(locationService: fakeService);
        addTearDown(container.dispose);

        final result = await container
            .read(sacredLocationProvider.notifier)
            .detect();

        expect(result, isA<LocationFetchPermissionDenied>());
        expect(
          (result as LocationFetchPermissionDenied).permanentlyDenied,
          isFalse,
        );
        expect(container.read(sacredLocationProvider), isNull);
      },
    );

    test('detect → PermissionDenied permanent flag propagates', () async {
      final fakeService = _FakeLocationService(
        const LocationFetchPermissionDenied(permanentlyDenied: true),
      );
      final container = _makeContainer(locationService: fakeService);
      addTearDown(container.dispose);

      final result = await container
          .read(sacredLocationProvider.notifier)
          .detect();

      final denied = result as LocationFetchPermissionDenied;
      expect(denied.permanentlyDenied, isTrue);
    });

    test(
      'detect → LocationFetchError returns result without updating state',
      () async {
        final fakeService = _FakeLocationService(
          const LocationFetchError('timeout'),
        );
        final container = _makeContainer(locationService: fakeService);
        addTearDown(container.dispose);

        final result = await container
            .read(sacredLocationProvider.notifier)
            .detect();

        expect(result, isA<LocationFetchError>());
        final error = result as LocationFetchError;
        expect(error.message, 'timeout');
        expect(container.read(sacredLocationProvider), isNull);
      },
    );

    test('detect → Success updates state with detected location', () async {
      final detectedLoc = SacredLocation(
        latitude: 31.7683,
        longitude: 35.2137,
        source: SacredLocationSource.detected,
        fixedAt: DateTime.utc(2026, 5, 1),
        countryCode: 'IL',
      );
      final fakeService = _FakeLocationService(
        LocationFetchSuccess(detectedLoc),
      );
      final container = _makeContainer(locationService: fakeService);
      addTearDown(container.dispose);

      final result = await container
          .read(sacredLocationProvider.notifier)
          .detect();

      expect(result, isA<LocationFetchSuccess>());
      final loc = container.read(sacredLocationProvider);
      expect(loc, isNotNull);
      expect(loc!.latitude, closeTo(31.7683, 0.001));
      expect(loc.source, SacredLocationSource.detected);
      expect(loc.countryCode, 'IL');
    });

    test('detect → Success persists location to SharedPreferences', () async {
      final detectedLoc = SacredLocation(
        latitude: 40.7128,
        longitude: -74.006,
        source: SacredLocationSource.detected,
        fixedAt: DateTime.utc(2026, 5, 1),
        countryCode: 'US',
      );
      final fakeService = _FakeLocationService(
        LocationFetchSuccess(detectedLoc),
      );
      final container = _makeContainer(locationService: fakeService);
      addTearDown(container.dispose);

      await container.read(sacredLocationProvider.notifier).detect();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('sacred_time_latitude'), closeTo(40.7128, 0.001));
      expect(prefs.getString('sacred_time_country_code'), 'US');
    });

    test(
      'detect → Success with IL country code sets inIsrael pref to true',
      () async {
        final detectedLoc = SacredLocation(
          latitude: 31.7683,
          longitude: 35.2137,
          source: SacredLocationSource.detected,
          fixedAt: DateTime.utc(2026, 5, 1),
          countryCode: 'IL',
        );
        final fakeService = _FakeLocationService(
          LocationFetchSuccess(detectedLoc),
        );
        final container = _makeContainer(locationService: fakeService);
        addTearDown(container.dispose);

        await container.read(sacredLocationProvider.notifier).detect();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('sacred_time_in_israel'), isTrue);
      },
    );

    test(
      'detect → Success with non-IL country code sets inIsrael pref false',
      () async {
        final detectedLoc = SacredLocation(
          latitude: 51.5074,
          longitude: -0.1278,
          source: SacredLocationSource.detected,
          fixedAt: DateTime.utc(2026, 5, 1),
          countryCode: 'GB',
        );
        final fakeService = _FakeLocationService(
          LocationFetchSuccess(detectedLoc),
        );
        final container = _makeContainer(locationService: fakeService);
        addTearDown(container.dispose);

        await container.read(sacredLocationProvider.notifier).detect();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('sacred_time_in_israel'), isFalse);
      },
    );

    test(
      'second setManualCity overwrites first — state holds latest city',
      () async {
        final container = _makeContainer();
        addTearDown(container.dispose);

        await container
            .read(sacredLocationProvider.notifier)
            .setManualCity(
              latitude: 31.7683,
              longitude: 35.2137,
              cityLabel: 'Jerusalem',
              countryCode: 'IL',
            );
        await container
            .read(sacredLocationProvider.notifier)
            .setManualCity(
              latitude: 51.5074,
              longitude: -0.1278,
              cityLabel: 'London',
              countryCode: 'GB',
            );

        final loc = container.read(sacredLocationProvider);
        expect(loc!.cityLabel, 'London');
        expect(loc.countryCode, 'GB');
      },
    );
  });

  // ── InIsraelNotifier ─────────────────────────────────────────────────────────

  group('InIsraelNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state is false when no prefs stored', () async {
      final container = _makeContainer();

      // Trigger build + _load() by reading the provider.
      container.read(inIsraelProvider);
      // Let mock-synchronous _load() settle (SharedPreferences is sync in tests).
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(inIsraelProvider), isFalse);
      // Dispose AFTER async settle to avoid "Ref used after disposal".
      container.dispose();
    });

    test('initial state is true when prefs store true', () async {
      SharedPreferences.setMockInitialValues({'sacred_time_in_israel': true});
      final container = _makeContainer();

      // Trigger build + _load() then wait for completion.
      container.read(inIsraelProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(inIsraelProvider), isTrue);
      container.dispose();
    });

    test('setInIsrael(true) updates state and persists', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await container.read(inIsraelProvider.notifier).setInIsrael(true);

      expect(container.read(inIsraelProvider), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('sacred_time_in_israel'), isTrue);
    });

    test('setInIsrael(false) after true updates state and persists', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await container.read(inIsraelProvider.notifier).setInIsrael(true);
      await container.read(inIsraelProvider.notifier).setInIsrael(false);

      expect(container.read(inIsraelProvider), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('sacred_time_in_israel'), isFalse);
    });

    test('setInIsrael can flip to true independent of location source — '
        'prefs reflect the manual override', () async {
      // Simulate a visitor scenario: set non-IL location, then manually
      // flip in-Israel to true (visitor keeping two-day chag).
      // We assert via SharedPreferences because the notifier state can race
      // with the async _load() re-triggered by ref.invalidate; see BUG note.
      final container = _makeContainer();
      addTearDown(container.dispose);

      await container
          .read(sacredLocationProvider.notifier)
          .setManualCity(
            latitude: 51.5074,
            longitude: -0.1278,
            cityLabel: 'London',
            countryCode: 'GB',
          );
      // GB → inIsrael = false in prefs; user overrides it
      await container.read(inIsraelProvider.notifier).setInIsrael(true);

      // The persisted value is authoritative — assert on prefs, not provider state,
      // because the async _load() triggered by ref.invalidate can race with
      // setInIsrael in unit tests (see BUG comment on skipped test below).
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('sacred_time_in_israel'), isTrue);
    });

    test(
      'setInIsrael provider state immediately true after call',
      // REGRESSION GUARD (was a race): InIsraelNotifier._load() is re-triggered
      // by ref.invalidate() inside SacredLocationNotifier.setManualCity/detect;
      // being async, it could resume AFTER the sync `state = value` in
      // setInIsrael and clobber it with the stale prefs value. Fixed via the
      // per-instance _explicitlySet guard: an explicit setInIsrael wins over a
      // racing _load. setInIsrael(true) must leave state == true.
      () async {
        final container = _makeContainer();
        addTearDown(container.dispose);

        await container
            .read(sacredLocationProvider.notifier)
            .setManualCity(
              latitude: 51.5074,
              longitude: -0.1278,
              cityLabel: 'London',
              countryCode: 'GB',
            );
        await container.read(inIsraelProvider.notifier).setInIsrael(true);

        expect(container.read(inIsraelProvider), isTrue);
      },
    );
  });
}
