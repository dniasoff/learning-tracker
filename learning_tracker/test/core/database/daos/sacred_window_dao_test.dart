/// DAO test for SacredWindowDao (DNI-367, Story 26.24).
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;

  setUp(() {
    db = inMemoryDb();
  });

  tearDown(() async {
    await db.close();
  });

  SacredWindowEntriesCompanion makeRow({
    DateTime? startUtc,
    DateTime? endUtc,
    String kind = 'shabbos',
    double? lat = 31.7683,
    double? lng = 35.2137,
    bool inIsrael = true,
  }) {
    return SacredWindowEntriesCompanion.insert(
      startUtc: startUtc ?? DateTime.utc(2026, 5, 8, 15, 0),
      endUtc: endUtc ?? DateTime.utc(2026, 5, 9, 20, 0),
      kind: kind,
      lat: Value(lat),
      lng: Value(lng),
      inIsrael: inIsrael,
    );
  }

  group('SacredWindowDao', () {
    group('insertAll', () {
      test('inserts multiple rows in a single batch', () async {
        await db.sacredWindowDao.insertAll([
          makeRow(kind: 'shabbos'),
          makeRow(
            kind: 'yomTov',
            startUtc: DateTime.utc(2026, 6, 1, 16, 0),
            endUtc: DateTime.utc(2026, 6, 2, 21, 0),
          ),
        ]);

        final rows = await db.sacredWindowDao.getAll();
        expect(rows, hasLength(2));
      });

      test('empty list is a no-op', () async {
        await db.sacredWindowDao.insertAll([]);
        final rows = await db.sacredWindowDao.getAll();
        expect(rows, isEmpty);
      });

      test('persists all column values correctly', () async {
        final start = DateTime.utc(2026, 5, 8, 15, 30);
        final end = DateTime.utc(2026, 5, 9, 20, 45);
        await db.sacredWindowDao.insertAll([
          makeRow(
            startUtc: start,
            endUtc: end,
            kind: 'yomKippur',
            lat: 40.0959,
            lng: -74.2222,
            inIsrael: false,
          ),
        ]);

        final row = (await db.sacredWindowDao.getAll()).first;
        // Drift NativeDatabase may return local-tz DateTime; compare via UTC.
        expect(row.startUtc.toUtc(), equals(start));
        expect(row.endUtc.toUtc(), equals(end));
        expect(row.kind, equals('yomKippur'));
        expect(row.lat, closeTo(40.0959, 0.0001));
        expect(row.lng, closeTo(-74.2222, 0.0001));
        expect(row.inIsrael, isFalse);
        expect(row.createdAt, isNotNull);
      });

      test('nullable lat/lng stored as null', () async {
        await db.sacredWindowDao.insertAll([makeRow(lat: null, lng: null)]);

        final row = (await db.sacredWindowDao.getAll()).first;
        expect(row.lat, isNull);
        expect(row.lng, isNull);
      });
    });

    group('clearAll', () {
      test('deletes all rows leaving an empty table', () async {
        await db.sacredWindowDao.insertAll([makeRow(), makeRow()]);
        expect(await db.sacredWindowDao.getAll(), hasLength(2));

        await db.sacredWindowDao.clearAll();

        expect(await db.sacredWindowDao.getAll(), isEmpty);
      });

      test('is a no-op on an empty table', () async {
        await db.sacredWindowDao.clearAll();
        expect(await db.sacredWindowDao.getAll(), isEmpty);
      });
    });

    group('getAll', () {
      test('returns empty list on a fresh database', () async {
        final rows = await db.sacredWindowDao.getAll();
        expect(rows, isEmpty);
      });

      test('returns all inserted rows', () async {
        await db.sacredWindowDao.insertAll([
          makeRow(kind: 'shabbos'),
          makeRow(kind: 'yomTov'),
          makeRow(kind: 'shabbosYomTov'),
        ]);

        final rows = await db.sacredWindowDao.getAll();
        expect(rows.map((r) => r.kind).toSet(), {
          'shabbos',
          'yomTov',
          'shabbosYomTov',
        });
      });
    });

    group('clearAll then insertAll (replace cycle)', () {
      test(
        'old rows are gone and new rows are present after replace',
        () async {
          await db.sacredWindowDao.insertAll([makeRow(kind: 'shabbos')]);

          await db.sacredWindowDao.clearAll();
          await db.sacredWindowDao.insertAll([makeRow(kind: 'yomKippur')]);

          final rows = await db.sacredWindowDao.getAll();
          expect(rows, hasLength(1));
          expect(rows.first.kind, equals('yomKippur'));
        },
      );
    });
  });
}
