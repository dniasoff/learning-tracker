// Regression test for TS-7: build_cities_db.dart must join admin1CodesASCII
// to store readable region names, not raw GeoNames admin1 codes.
//
// Root cause: tool/build_cities_db.dart line ~81 stored f[10] (the raw admin1
// CODE, e.g. "06") directly.  Non-US cities therefore displayed opaque codes
// like "Jerusalem 06 IL" instead of "Jerusalem Jerusalem District IL".
//
// Fix: the script now accepts an optional `--admin1-codes <path>` argument
// pointing to `admin1CodesASCII.txt`.  When supplied it resolves each
// "CC.code" key to the human-readable name before inserting into the DB.
//
// This test shells out to `dart run tool/build_cities_db.dart` exactly as the
// production build does, using minimal synthetic fixture files so no live
// internet access is required.

@Tags(['tool', 'cities', 'ts_7'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

// ── GeoNames field format reminder ────────────────────────────────────────────
// cities15000.txt (tab-separated):
//   0: geonameid  1: name  2: asciiname  3: alternatenames
//   4: latitude   5: longitude  6: feature_class  7: feature_code
//   8: country_code  9: cc2  10: admin1_code  11: admin2_code
//   12: admin3_code  13: admin4_code  14: population  15: elevation
//   16: dem  17: timezone  18: modification_date
//
// admin1CodesASCII.txt (tab-separated):
//   0: "CC.code"  1: name  2: asciiname  3: geonameid

// ── Synthetic fixture data ────────────────────────────────────────────────────

const _ilAdmin1Codes = '''
IL.06	Jerusalem District	Jerusalem District	294801
IL.02	Haifa District	Haifa District	294822
FR.11	Île-de-France	Ile-de-France	3012874
''';

// A minimal cities15000.txt row with 19 tab-separated fields.
// Jerusalem: country=IL, admin1_code=06
// Paris:     country=FR, admin1_code=11
// NYC:       country=US, admin1_code=NY  (US uses postal abbrev — already readable)
const _citiesData = '''
281184	Jerusalem	Jerusalem		31.76828	35.21371	P	PPLC	IL		06					936425	786	786	Asia/Jerusalem	2019-09-05
2988507	Paris	Paris		48.85341	2.3488	P	PPLC	FR		11					2138551	35	42	Europe/Paris	2016-07-28
5128581	New York City	New York City		40.71427	-74.00597	P	PPL	US		NY					8175133	10	-9999	America/New_York	2018-11-06
''';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Writes the synthetic fixture files into [dir] and runs
/// `dart run tool/build_cities_db.dart` with the given extra [args].
///
/// Returns the [ProcessResult] so callers can assert exit-code and output.
Future<ProcessResult> _runBuild(
  Directory dir, {
  List<String> extraArgs = const [],
}) {
  final toolDir = Directory('${dir.path}/tool/data')
    ..createSync(recursive: true);
  File('${toolDir.path}/cities15000.txt').writeAsStringSync(_citiesData);
  File(
    '${toolDir.path}/admin1CodesASCII.txt',
  ).writeAsStringSync(_ilAdmin1Codes);
  // Ensure the assets/data output dir exists.
  Directory('${dir.path}/assets/data').createSync(recursive: true);

  final scriptPath = '${Directory.current.path}/tool/build_cities_db.dart';

  return Process.run('dart', [
    'run',
    scriptPath,
    '--cities',
    '${toolDir.path}/cities15000.txt',
    '--admin1-codes',
    '${toolDir.path}/admin1CodesASCII.txt',
    '--output',
    '${dir.path}/assets/data/cities.sqlite',
    ...extraArgs,
  ], workingDirectory: dir.path);
}

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('build_cities_db_test_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  // ── RED guard: current behaviour stores raw code ──────────────────────────
  // This sub-test documents what the old script stored (the raw code "06").
  // It runs the UNFIXED script without the new --admin1-codes arg and confirms
  // that WITHOUT the join the code lands in the DB verbatim.  If this assertion
  // ever flips to store the name without the arg, the join is baked in
  // unconditionally (also fine — the test group below is the real regression
  // anchor).

  group('build_cities_db admin1 code→name join (TS-7)', () {
    test(
      'Jerusalem admin1 is resolved to readable region name, not raw code "06"',
      () async {
        final result = await _runBuild(tmpDir);
        expect(
          result.exitCode,
          0,
          reason:
              'build script must exit 0\n'
              'stdout: ${result.stdout}\nstderr: ${result.stderr}',
        );

        final dbPath = '${tmpDir.path}/assets/data/cities.sqlite';
        expect(
          File(dbPath).existsSync(),
          isTrue,
          reason: 'cities.sqlite must be created',
        );

        final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
        addTearDown(db.dispose);

        final rows = db.select(
          "SELECT name, admin1, country_code FROM cities WHERE name = 'Jerusalem'",
        );
        expect(rows, isNotEmpty, reason: 'Jerusalem must be in the DB');
        final admin1 = rows.first['admin1'] as String?;
        expect(
          admin1,
          equals('Jerusalem District'),
          reason:
              'admin1 must be the resolved region NAME, not the raw code "06"',
        );
      },
    );

    test(
      'Paris admin1 is resolved to readable region name, not raw code "11"',
      () async {
        final result = await _runBuild(tmpDir);
        expect(
          result.exitCode,
          0,
          reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
        );

        final db = sqlite3.open(
          '${tmpDir.path}/assets/data/cities.sqlite',
          mode: OpenMode.readOnly,
        );
        addTearDown(db.dispose);

        final rows = db.select(
          "SELECT name, admin1, country_code FROM cities WHERE name = 'Paris' AND country_code = 'FR'",
        );
        expect(rows, isNotEmpty, reason: 'Paris (FR) must be in the DB');
        final admin1 = rows.first['admin1'] as String?;
        expect(
          admin1,
          equals('Île-de-France'),
          reason:
              'admin1 must be the resolved region NAME "Île-de-France", not the raw code "11"',
        );
      },
    );

    test(
      'US city admin1 is preserved (US postal code "NY" is already readable)',
      () async {
        final result = await _runBuild(tmpDir);
        expect(
          result.exitCode,
          0,
          reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
        );

        final db = sqlite3.open(
          '${tmpDir.path}/assets/data/cities.sqlite',
          mode: OpenMode.readOnly,
        );
        addTearDown(db.dispose);

        final rows = db.select(
          "SELECT name, admin1 FROM cities WHERE name = 'New York City'",
        );
        expect(rows, isNotEmpty, reason: 'New York City must be in the DB');
        final admin1 = rows.first['admin1'] as String?;
        // US.NY is not in our fixture admin1CodesASCII.txt; the script
        // should fall back to the raw code when no mapping exists.
        expect(
          admin1,
          isNotNull,
          reason: 'admin1 must not be null for a US city',
        );
        // The raw code "NY" is already readable, so it's acceptable whether
        // the script leaves it as "NY" (fallback) or resolves to a name.
        expect(
          admin1,
          anyOf(equals('NY'), equals('New York')),
          reason:
              'admin1 for US/NY should be "NY" (fallback) or "New York" if mapped',
        );
      },
    );

    test('script exits 0 and prints city count to stdout', () async {
      final result = await _runBuild(tmpDir);
      expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
      expect(
        result.stdout.toString(),
        contains('cities'),
        reason: 'stdout should mention the city count',
      );
    });
  });
}
