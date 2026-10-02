// Tests for:
//   • CitiesRepository — searchByPrefix, topCitiesByCountry, dispose/reuse
//   • LocationService — all 5 permission/result branches
//
// DNI-481 (R9) deleted SacredLocationNotifier / InIsraelNotifier and their
// device preferences; a learner's location, zone and Israel flag are now
// governed learnerSettings changes (learner_settings_editor_provider_test,
// learner_settings_command_test).
//
// Coverage targets: cities_repository (0%), location_service (18%).
//
// Strategy:
//   CitiesRepository — in-memory SQLite written to a temp file; a fake
//   PathProviderPlatform points CitiesRepository._doOpen() at that file so
//   asset extraction is bypassed.
//
//   LocationService — GeolocatorPlatform.instance + GeocodingPlatform.instance
//   swapped with fakes that return controllable outcomes; no real GPS.

//
// Product rules asserted:
//   • No "Personal"/"Standard"/"Custom"/"אישי" track-type labels.

@Tags(['sacred_time', 'location', 'cities'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geocoding_platform_interface/geocoding_platform_interface.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:learning_tracker/features/sacred_time/data/services/cities_repository.dart';
import 'package:learning_tracker/features/sacred_time/data/services/location_service.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/city_search_exception.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/location_error_code.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/location_fetch_result.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_location.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
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
  // AUD-sacred_time-03 (EH-5): getCurrentPosition() throws a TimeoutException
  // for this scenario — the common indoor/poor-signal case after the service's
  // 15s GPS timeLimit elapses — distinct from the plain `error` Exception
  // scenario, since it must classify to LocationErrorCode.timeout rather than
  // .unknown.
  timeout,
  // A genuine programming-bug scenario (e.g. a plugin-level type mismatch),
  // distinct from `error` (an ordinary Exception the service is expected to
  // catch and convert to LocationFetchError). getCurrentPosition() throws a
  // StateError for this scenario — see AUD-sacred_time-06.
  programmingError,
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
      case _GeoScenario.timeout:
        return LocationPermission.whileInUse;
      case _GeoScenario.programmingError:
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
    if (scenario == _GeoScenario.timeout) {
      throw TimeoutException(
        'Time limit reached while waiting for position update.',
        const Duration(seconds: 15),
      );
    }
    if (scenario == _GeoScenario.programmingError) {
      // Simulates a genuine programming bug (e.g. a plugin-level type
      // mismatch) — an Error subtype, not an Exception.
      throw StateError('unexpected null position field');
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
  // Distinct from [shouldThrow]: simulates a genuine programming bug (an
  // Error subtype) rather than the ordinary Exception the service is
  // expected to catch and convert to a null countryCode.
  final bool shouldThrowProgrammingError;

  _FakeGeocodingPlatform({
    this.placemarks,
    this.shouldThrow = false,
    this.shouldThrowProgrammingError = false,
  });

  @override
  Future<List<geo.Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude, {
    String? localeIdentifier,
  }) async {
    if (shouldThrowProgrammingError) {
      throw StateError('unexpected placemark field shape');
    }
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

    // AUD-sacred_time-03 (EH-5) — red-first regression: before the fix, a
    // raw SqliteException (e.g. "no such table: cities") propagated straight
    // out of searchByPrefix/topCitiesByCountry into citySearchProvider's
    // AsyncError, and from there to e.toString() in the UI. Point the repo
    // at a valid-but-schemaless SQLite file (no `cities` table) so the query
    // throws that raw SqliteException, and assert it never reaches the
    // caller untyped.
    group('I/O error conversion (EH-2/EH-5)', () {
      late Directory brokenDir;
      late CitiesRepository brokenRepo;

      setUp(() {
        brokenDir = Directory.systemTemp.createTempSync('cities_broken_');
        // An empty-but-valid SQLite file: opens fine, but any query against
        // the (never-created) `cities` table throws a raw SqliteException.
        sqlite3.open('${brokenDir.path}/cities_v1.sqlite').dispose();
        PathProviderPlatform.instance = _FakePathProvider(brokenDir.path);
        brokenRepo = CitiesRepository();
      });

      tearDown(() {
        brokenRepo.dispose();
        brokenDir.deleteSync(recursive: true);
        // Restore the seeded fixture path for any subsequent CitiesRepository
        // test in this file.
        PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
      });

      test('searchByPrefix converts a raw SqliteException into a typed '
          'CitySearchException(database)', () async {
        await expectLater(
          brokenRepo.searchByPrefix('je'),
          throwsA(
            isA<CitySearchException>()
                .having((e) => e.code, 'code', CitySearchErrorCode.database)
                .having((e) => e.debugDetail, 'debugDetail', isNotNull),
          ),
        );
      });

      test('topCitiesByCountry converts a raw SqliteException into a typed '
          'CitySearchException(database)', () async {
        await expectLater(
          brokenRepo.topCitiesByCountry('IL'),
          throwsA(
            isA<CitySearchException>().having(
              (e) => e.code,
              'code',
              CitySearchErrorCode.database,
            ),
          ),
        );
      });
    });
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
      'detectCurrent → LocationFetchError(unknown) on GPS hardware exception',
      () async {
        GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
          _GeoScenario.error,
        );
        GeocodingPlatform.instance = _FakeGeocodingPlatform();

        final result = await const LocationService().detectCurrent();
        expect(result, isA<LocationFetchError>());
        final error = result as LocationFetchError;
        // AUD-sacred_time-03 (EH-5): a stable code, not a raw message. A
        // plain Exception (not a TimeoutException) classifies as unknown.
        expect(error.code, LocationErrorCode.unknown);
        // debugDetail retains the raw text for logs only — never rendered.
        expect(error.debugDetail, contains('GPS hardware failure'));
      },
    );

    // AUD-sacred_time-03 (EH-5) — red-first regression: before the fix,
    // LocationFetchError carried e.toString() verbatim (a raw, untranslated
    // TimeoutException message) instead of a stable, localizable code. This
    // asserts the 15s GPS timeLimit's TimeoutException classifies distinctly
    // from a generic Exception.
    test('detectCurrent → LocationFetchError(timeout) on GPS TimeoutException '
        '(AUD-sacred_time-03 EH-5)', () async {
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
        _GeoScenario.timeout,
      );
      GeocodingPlatform.instance = _FakeGeocodingPlatform();

      final result = await const LocationService().detectCurrent();
      expect(result, isA<LocationFetchError>());
      final error = result as LocationFetchError;
      expect(error.code, LocationErrorCode.timeout);
      expect(
        error.debugDetail,
        contains('Time limit reached while waiting for position update'),
      );
    });

    // AUD-sacred_time-06 (EH-4): the outer `on Object catch (e)` at
    // location_service.dart:73 must not swallow programming errors
    // (Error subtypes) into LocationFetchError — only ordinary Exceptions
    // are the service's business to handle. A StateError thrown from
    // Geolocator.getCurrentPosition (e.g. a plugin-level type mismatch)
    // must propagate to the caller instead.
    test('detectCurrent → propagates a thrown Error (not LocationFetchError) '
        'when GPS surfaces a programming bug', () async {
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
        _GeoScenario.programmingError,
      );
      GeocodingPlatform.instance = _FakeGeocodingPlatform();

      await expectLater(
        const LocationService().detectCurrent(),
        throwsA(isA<StateError>()),
      );
    });

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

    // AUD-sacred_time-06 (EH-4): the inner `on Object` at
    // location_service.dart:86 must not swallow programming errors into a
    // silent null countryCode — only ordinary Exceptions are best-effort
    // "geocoding unavailable" cases. A StateError thrown from
    // geo.placemarkFromCoordinates must propagate all the way out of
    // detectCurrent (through both the inner AND outer try/catch), not be
    // downgraded to a null countryCode nor caught by the outer clause and
    // turned into LocationFetchError.
    test('detectCurrent → propagates a thrown Error (not swallowed to null '
        'countryCode) when geocoding surfaces a programming bug', () async {
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
      GeocodingPlatform.instance = _FakeGeocodingPlatform(
        shouldThrowProgrammingError: true,
      );

      await expectLater(
        const LocationService().detectCurrent(),
        throwsA(isA<StateError>()),
      );
    });

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
}
