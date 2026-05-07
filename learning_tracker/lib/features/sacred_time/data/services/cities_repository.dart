import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:learning_tracker/features/sacred_time/domain/models/city.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Bundled cities lookup. Backed by a read-only SQLite asset
/// (assets/data/cities.sqlite) derived from GeoNames cities15000 (~33k cities,
/// see assets/data/NOTICE.txt for attribution).
///
/// Lifecycle: extracts the asset to the app documents directory on first use
/// and reuses the cached file on subsequent launches. The asset is small
/// enough (~3.4 MB) that re-extraction on app upgrade is acceptable; a version
/// stamp avoids unnecessary I/O on warm starts.
class CitiesRepository {
  CitiesRepository();

  static const _assetPath = 'assets/data/cities.sqlite';
  static const _cachedFileName = 'cities_v1.sqlite';

  Database? _db;
  Future<Database>? _opening;

  Future<Database> _open() {
    final existing = _db;
    if (existing != null) return Future.value(existing);
    return _opening ??= _doOpen();
  }

  Future<Database> _doOpen() async {
    final docs = await getApplicationDocumentsDirectory();
    final cachedPath = '${docs.path}/$_cachedFileName';
    final cached = File(cachedPath);

    if (!cached.existsSync()) {
      final bytes = await rootBundle.load(_assetPath);
      await cached.writeAsBytes(
        bytes.buffer.asUint8List(),
        flush: true,
      );
    }

    final db = sqlite3.open(cachedPath, mode: OpenMode.readOnly);
    _db = db;
    return db;
  }

  /// Prefix search by city ASCII name. Case-insensitive — query is lower-cased
  /// before matching the precomputed `ascii_lower` column. Results are sorted
  /// by population descending so the most prominent city for a name appears
  /// first.
  Future<List<City>> searchByPrefix(String query, {int limit = 50}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final db = await _open();
    final pattern = '${trimmed.toLowerCase()}%';
    final rows = db.select(
      '''
      SELECT id, name, country_code, admin1, latitude, longitude, timezone,
             population
      FROM cities
      WHERE ascii_lower LIKE ?
      ORDER BY population DESC
      LIMIT ?
      ''',
      [pattern, limit],
    );
    return rows.map(_rowToCity).toList(growable: false);
  }

  /// Top N most populous cities for the given country (used as the empty-state
  /// view of the picker).
  Future<List<City>> topCitiesByCountry(
    String countryCode, {
    int limit = 50,
  }) async {
    final db = await _open();
    final rows = db.select(
      '''
      SELECT id, name, country_code, admin1, latitude, longitude, timezone,
             population
      FROM cities
      WHERE country_code = ?
      ORDER BY population DESC
      LIMIT ?
      ''',
      [countryCode.toUpperCase(), limit],
    );
    return rows.map(_rowToCity).toList(growable: false);
  }

  void dispose() {
    _db?.dispose();
    _db = null;
    _opening = null;
  }

  static City _rowToCity(Row row) => City(
    id: row['id'] as int,
    name: row['name'] as String,
    countryCode: row['country_code'] as String,
    admin1: row['admin1'] as String?,
    latitude: row['latitude'] as double,
    longitude: row['longitude'] as double,
    timezone: row['timezone'] as String?,
    population: row['population'] as int,
  );
}
