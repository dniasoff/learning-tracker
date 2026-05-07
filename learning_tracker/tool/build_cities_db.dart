// Builds learning_tracker/assets/data/cities.sqlite from the GeoNames
// cities15000 dataset (~33k cities, population ≥ 15,000).
//
// Source: https://download.geonames.org/export/dump/cities15000.zip
// License: Creative Commons Attribution 4.0 (see assets/data/NOTICE.txt).
//
// Usage:
//   1. Download cities15000.zip from the URL above and unzip into
//      learning_tracker/tool/data/.
//   2. From learning_tracker/: `dart run tool/build_cities_db.dart`
//
// Schema:
//   cities(id, name, ascii_lower, country_code, admin1, latitude, longitude,
//          timezone, population)
//   - ascii_lower is precomputed lowercase ASCII for indexed prefix search.
//
// The output .sqlite is committed under learning_tracker/assets/data/.

import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

const _inputPath = 'tool/data/cities15000.txt';
const _outputPath = 'assets/data/cities.sqlite';

void main() {
  final input = File(_inputPath);
  if (!input.existsSync()) {
    stderr.writeln(
      'Missing $_inputPath. Download cities15000.zip from '
      'https://download.geonames.org/export/dump/ and unzip into tool/data/.',
    );
    exit(2);
  }

  final out = File(_outputPath);
  if (out.existsSync()) out.deleteSync();
  out.parent.createSync(recursive: true);

  final db = sqlite3.open(_outputPath);
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
    final admin1 = f[10].isEmpty ? null : f[10];
    final pop = int.tryParse(f[14]) ?? 0;
    final tz = f[17].isEmpty ? null : f[17];

    if (id == null || lat == null || long == null) continue;
    if (name.isEmpty || asciiName.isEmpty || country.isEmpty) continue;

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
    'Built $_outputPath — $imported cities, ${(size / 1024 / 1024).toStringAsFixed(2)} MB',
  );
}
