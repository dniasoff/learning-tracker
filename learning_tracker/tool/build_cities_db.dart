// Builds learning_tracker/assets/data/cities.sqlite from the GeoNames
// cities15000 dataset (~33k cities, population ≥ 15,000).
//
// Source: https://download.geonames.org/export/dump/cities15000.zip
// License: Creative Commons Attribution 4.0 (see assets/data/NOTICE.txt).
//
// Usage:
//   1. Download cities15000.zip from the URL above and unzip into
//      learning_tracker/tool/data/.
//   2. Download admin1CodesASCII.txt from the same URL into tool/data/.
//   3. From learning_tracker/: `dart run tool/build_cities_db.dart`
//
// Optional CLI overrides (for testing / CI):
//   --cities      <path>  path to cities15000.txt   (default: tool/data/cities15000.txt)
//   --admin1-codes <path> path to admin1CodesASCII.txt (default: tool/data/admin1CodesASCII.txt)
//   --output      <path>  output SQLite path        (default: assets/data/cities.sqlite)
//
// Schema:
//   cities(id, name, ascii_lower, country_code, admin1, latitude, longitude,
//          timezone, population)
//   - ascii_lower is precomputed lowercase ASCII for indexed prefix search.
//   - admin1 is the RESOLVED human-readable region name (joined from
//     admin1CodesASCII.txt), NOT the raw GeoNames admin1 code.
//     Example: Jerusalem stores "Jerusalem District", not "06".
//     If admin1CodesASCII.txt is absent the raw code is kept as fallback.
//
// The output .sqlite is committed under learning_tracker/assets/data/.

import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

const _defaultCitiesPath = 'tool/data/cities15000.txt';
const _defaultAdmin1Path = 'tool/data/admin1CodesASCII.txt';
const _defaultOutputPath = 'assets/data/cities.sqlite';

void main(List<String> args) {
  // Parse CLI args: --cities, --admin1-codes, --output
  var citiesPath = _defaultCitiesPath;
  var admin1Path = _defaultAdmin1Path;
  var outputPath = _defaultOutputPath;

  for (var i = 0; i < args.length - 1; i++) {
    switch (args[i]) {
      case '--cities':
        citiesPath = args[++i];
      case '--admin1-codes':
        admin1Path = args[++i];
      case '--output':
        outputPath = args[++i];
    }
  }

  final input = File(citiesPath);
  if (!input.existsSync()) {
    stderr.writeln(
      'Missing $citiesPath. Download cities15000.zip from '
      'https://download.geonames.org/export/dump/ and unzip into tool/data/.',
    );
    exit(2);
  }

  // ── Load admin1 code → readable name mapping ──────────────────────────────
  //
  // admin1CodesASCII.txt format (tab-separated):
  //   col 0: "CC.admin1code"  e.g. "IL.06"
  //   col 1: name             e.g. "Jerusalem District"
  //   col 2: asciiname        (unused here)
  //   col 3: geonameid        (unused here)
  //
  // Key stored as uppercase "CC.code" so lookup is case-insensitive.
  final admin1Map = _loadAdmin1Codes(admin1Path);
  if (admin1Map.isEmpty) {
    stderr.writeln(
      'Warning: admin1CodesASCII.txt not found at $admin1Path — '
      'admin1 codes will be stored verbatim (non-US cities will show '
      'opaque codes instead of region names). '
      'Download from https://download.geonames.org/export/dump/ to fix.',
    );
  }

  final out = File(outputPath);
  if (out.existsSync()) out.deleteSync();
  out.parent.createSync(recursive: true);

  final db = sqlite3.open(outputPath);
  db.execute('PRAGMA journal_mode = OFF');
  db.execute('PRAGMA synchronous = OFF');
  db.execute('PRAGMA page_size = 4096');

  db.execute('''
    CREATE TABLE cities (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      ascii_lower TEXT NOT NULL,
      country_code TEXT NOT NULL,
      admin1 TEXT,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      timezone TEXT,
      population INTEGER NOT NULL
    )
  ''');

  final insert = db.prepare('''
    INSERT INTO cities
      (id, name, ascii_lower, country_code, admin1, latitude, longitude,
       timezone, population)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  ''');

  db.execute('BEGIN');
  var imported = 0;

  final lines = input.readAsLinesSync();
  for (final line in lines) {
    if (line.isEmpty) continue;
    final f = line.split('\t');
    if (f.length < 19) continue;

    final id = int.tryParse(f[0]);
    final name = f[1];
    final asciiName = f[2];
    final lat = double.tryParse(f[4]);
    final long = double.tryParse(f[5]);
    final country = f[8];
    final admin1Code = f[10].isEmpty ? null : f[10];
    final pop = int.tryParse(f[14]) ?? 0;
    final tz = f[17].isEmpty ? null : f[17];

    if (id == null || lat == null || long == null) continue;
    if (name.isEmpty || asciiName.isEmpty || country.isEmpty) continue;

    // ── Resolve admin1 code → readable region name ──────────────────────────
    // GeoNames stores admin1 as a short code (e.g. "06" for Jerusalem District,
    // "11" for Île-de-France).  We join against admin1CodesASCII.txt using
    // the composite key "CC.admin1code" (e.g. "IL.06") to get the human-readable
    // name.  US postal abbreviations (e.g. "NY") happen to be readable already
    // but are also mapped — this join resolves them consistently.
    final admin1 = _resolveAdmin1(admin1Map, country, admin1Code);

    insert.execute([
      id,
      name,
      asciiName.toLowerCase(),
      country,
      admin1,
      lat,
      long,
      tz,
      pop,
    ]);
    imported++;
  }

  insert.dispose();
  db.execute('COMMIT');

  // Indices: prefix search by lowercase ASCII name; by-country fallback.
  db.execute('CREATE INDEX idx_cities_ascii ON cities(ascii_lower)');
  db.execute(
    'CREATE INDEX idx_cities_country_pop ON cities(country_code, population DESC)',
  );

  db.execute('VACUUM');
  db.dispose();

  final size = out.lengthSync();
  stdout.writeln(
    'Built $outputPath — $imported cities, ${(size / 1024 / 1024).toStringAsFixed(2)} MB',
  );
}

/// Parses `admin1CodesASCII.txt` into a `Map<"CC.CODE", name>` lookup.
/// Returns an empty map if the file is absent or unreadable.
Map<String, String> _loadAdmin1Codes(String path) {
  final file = File(path);
  if (!file.existsSync()) return const {};
  final map = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    if (line.isEmpty) continue;
    final parts = line.split('\t');
    if (parts.length < 2) continue;
    final key = parts[0].toUpperCase(); // e.g. "IL.06"
    final name = parts[1].trim();
    if (key.isNotEmpty && name.isNotEmpty) {
      map[key] = name;
    }
  }
  return map;
}

/// Returns the human-readable admin1 name for [country]/[admin1Code].
///
/// Lookup key is `"CC.admin1code"` (uppercase) — e.g. `"IL.06"`.
/// Falls back to [admin1Code] itself when no mapping is found (preserves
/// US postal abbreviations which are already readable, and avoids null for
/// unmapped regions).
String? _resolveAdmin1(
  Map<String, String> admin1Map,
  String country,
  String? admin1Code,
) {
  if (admin1Code == null) return null;
  if (admin1Map.isEmpty) return admin1Code; // no mapping file loaded
  final key = '${country.toUpperCase()}.${admin1Code.toUpperCase()}';
  return admin1Map[key] ?? admin1Code;
}
