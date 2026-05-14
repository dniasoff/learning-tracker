/// Comprehensive tests for ContentDatabase — exercises all DAOs and
/// the generated DataClass serialization methods to raise line coverage
/// on content_database.g.dart.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';

ContentDatabase makeDb() => ContentDatabase(NativeDatabase.memory());

void main() {
  late ContentDatabase db;

  setUp(() {
    db = makeDb();
  });

  tearDown(() async {
    await db.close();
  });

  // ─── TextCache ────────────────────────────────────────────────────────────

  group('TextCache CRUD', () {
    final fetchedAt = DateTime.utc(2026, 1, 15, 12);

    Future<void> insertText(
      ContentDatabase db, {
      String ref = 'Berakhot 2a',
      String hebrew = 'ברכות',
      String english = 'Berakhot',
    }) async {
      await db.into(db.textCache).insert(
        TextCacheCompanion.insert(
          sefariaRef: ref,
          hebrewText: hebrew,
          englishText: english,
          fetchedAt: fetchedAt,
        ),
      );
    }

    test('insert and retrieve single row', () async {
      await insertText(db, ref: 'Genesis 1.1', hebrew: 'בראשית', english: 'Genesis');

      final row = await db.contentTextCacheDao.getText('Genesis 1.1');
      expect(row, isNotNull);
      expect(row!.sefariaRef, 'Genesis 1.1');
      expect(row.hebrewText, 'בראשית');
      expect(row.englishText, 'Genesis');
      expect(row.fetchedAt.millisecondsSinceEpoch, fetchedAt.millisecondsSinceEpoch);
    });

    test('getText returns null for missing ref', () async {
      final row = await db.contentTextCacheDao.getText('Missing 1');
      expect(row, isNull);
    });

    test('getAllCachedRefs returns all refs', () async {
      await insertText(db, ref: 'Berakhot 2a');
      await insertText(db, ref: 'Shabbat 10a');

      final refs = await db.contentTextCacheDao.getAllCachedRefs();
      expect(refs, hasLength(2));
      expect(refs, containsAll(['Berakhot 2a', 'Shabbat 10a']));
    });

    test('getChildTexts returns chapter-level children', () async {
      await insertText(db, ref: 'Genesis 1:1');
      await insertText(db, ref: 'Genesis 1:2');
      await insertText(db, ref: 'Genesis 2:1');

      final children = await db.contentTextCacheDao.getChildTexts('Genesis 1');
      expect(children, hasLength(2));
      for (final c in children) {
        expect(c.sefariaRef, startsWith('Genesis 1:'));
      }
    });

    test('watchText emits null then value', () async {
      final stream = db.contentTextCacheDao.watchText('Berakhot 2a');
      expect(
        stream,
        emitsInOrder([isNull, isNotNull]),
      );
      await Future<void>.delayed(Duration.zero);
      await insertText(db, ref: 'Berakhot 2a');
    });

    test('TextCacheData equality and hashCode', () async {
      await insertText(db, ref: 'A 1', hebrew: 'a', english: 'A');
      final r1 = await db.contentTextCacheDao.getText('A 1');
      final r2 = await db.contentTextCacheDao.getText('A 1');
      expect(r1, equals(r2));
      expect(r1.hashCode, equals(r2.hashCode));
    });

    test('TextCacheData.toJson and fromJson round-trip', () async {
      await insertText(db, ref: 'B 2', hebrew: 'b', english: 'B');
      final row = await db.contentTextCacheDao.getText('B 2');
      final json = row!.toJson();
      expect(json['sefariaRef'], 'B 2');
      expect(json['hebrewText'], 'b');
      expect(json['englishText'], 'B');

      final restored = TextCacheData.fromJson(json);
      expect(restored, equals(row));
    });

    test('TextCacheData.copyWith preserves unchanged fields', () async {
      await insertText(db, ref: 'C 3', hebrew: 'c', english: 'C');
      final row = (await db.contentTextCacheDao.getText('C 3'))!;

      final copy = row.copyWith(englishText: 'Changed');
      expect(copy.sefariaRef, row.sefariaRef);
      expect(copy.hebrewText, row.hebrewText);
      expect(copy.englishText, 'Changed');
    });

    test('TextCacheData.toCompanion and copyWithCompanion', () async {
      await insertText(db, ref: 'D 4', hebrew: 'd', english: 'D');
      final row = (await db.contentTextCacheDao.getText('D 4'))!;

      final companion = row.toCompanion(true);
      expect(companion.sefariaRef.value, 'D 4');

      final copy = row.copyWithCompanion(
        const TextCacheCompanion(englishText: Value('Updated')),
      );
      expect(copy.englishText, 'Updated');
      expect(copy.sefariaRef, 'D 4');
    });

    test('TextCacheData.toString contains ref', () async {
      await insertText(db, ref: 'E 5', hebrew: 'e', english: 'E');
      final row = (await db.contentTextCacheDao.getText('E 5'))!;
      expect(row.toString(), contains('E 5'));
    });

    test('TextCacheCompanion.copyWith', () {
      const original = TextCacheCompanion(
        sefariaRef: Value('A 1'),
        englishText: Value('old'),
      );
      final copy = original.copyWith(englishText: const Value('new'));
      expect(copy.sefariaRef.value, 'A 1');
      expect(copy.englishText.value, 'new');
    });
  });

  // ─── CalendarCycles ───────────────────────────────────────────────────────

  group('CalendarCycles CRUD', () {
    Future<void> insertCycle(
      ContentDatabase db, {
      String programKey = 'daf_yomi',
      String dateKey = '2026-01-01',
      String sefariaRef = 'Berakhot 2a',
      String sefariaRefHe = 'ברכות ב׳',
      String displayName = 'Daf Yomi',
    }) async {
      await db.into(db.calendarCycles).insert(
        CalendarCyclesCompanion.insert(
          programKey: programKey,
          dateKey: dateKey,
          sefariaRef: sefariaRef,
          sefariaRefHe: Value(sefariaRefHe),
          displayName: Value(displayName),
        ),
      );
    }

    test('insert and getEntry', () async {
      await insertCycle(
        db,
        programKey: 'daf_yomi',
        dateKey: '2026-01-15',
        sefariaRef: 'Berakhot 4a',
      );

      final entry = await db.calendarCycleDao.getEntry('daf_yomi', '2026-01-15');
      expect(entry, isNotNull);
      expect(entry!.sefariaRef, 'Berakhot 4a');
      expect(entry.programKey, 'daf_yomi');
    });

    test('getEntry returns null for missing key', () async {
      final entry = await db.calendarCycleDao.getEntry('missing', '2026-01-01');
      expect(entry, isNull);
    });

    test('getEntriesForDate returns all programs on a date', () async {
      await insertCycle(
        db,
        programKey: 'daf_yomi',
        dateKey: '2026-02-01',
        sefariaRef: 'Berakhot 10a',
      );
      await insertCycle(
        db,
        programKey: 'mishna_yomit',
        dateKey: '2026-02-01',
        sefariaRef: 'Mishnah Berakhot 1.1',
      );
      await insertCycle(
        db,
        programKey: 'daf_yomi',
        dateKey: '2026-02-02',
        sefariaRef: 'Berakhot 10b',
      );

      final entries = await db.calendarCycleDao.getEntriesForDate('2026-02-01');
      expect(entries, hasLength(2));
    });

    test('getEntriesForRange filters and orders', () async {
      for (var i = 1; i <= 5; i++) {
        await insertCycle(
          db,
          programKey: 'daf_yomi',
          dateKey: '2026-03-0$i',
          sefariaRef: 'Berakhot ${i}a',
        );
      }

      final entries = await db.calendarCycleDao.getEntriesForRange(
        'daf_yomi',
        '2026-03-02',
        '2026-03-04',
      );
      expect(entries, hasLength(3));
      expect(entries.first.dateKey, '2026-03-02');
      expect(entries.last.dateKey, '2026-03-04');
    });

    test('legacy method getCycleForProgramAndDate delegates', () async {
      await insertCycle(
        db,
        programKey: 'nach_yomi',
        dateKey: '2026-04-01',
        sefariaRef: 'Joshua 1',
      );
      final entry = await db.calendarCycleDao.getCycleForProgramAndDate(
        'nach_yomi',
        '2026-04-01',
      );
      expect(entry, isNotNull);
      expect(entry!.sefariaRef, 'Joshua 1');
    });

    test('legacy method getCyclesForDate delegates', () async {
      await insertCycle(
        db,
        programKey: 'daf_yomi',
        dateKey: '2026-05-01',
        sefariaRef: 'Shabbat 2a',
      );
      final entries = await db.calendarCycleDao.getCyclesForDate('2026-05-01');
      expect(entries, hasLength(1));
    });

    test('legacy getCyclesForDateRange delegates', () async {
      for (var i = 1; i <= 3; i++) {
        await insertCycle(
          db,
          programKey: 'mishna_yomit',
          dateKey: '2026-06-0$i',
          sefariaRef: 'Mishnah Berakhot 1.$i',
        );
      }
      final entries = await db.calendarCycleDao.getCyclesForDateRange(
        'mishna_yomit',
        '2026-06-01',
        '2026-06-02',
      );
      expect(entries, hasLength(2));
    });

    test('CalendarCycle equality and hashCode', () async {
      await insertCycle(db, programKey: 'p', dateKey: '2026-07-01');
      final r1 = await db.calendarCycleDao.getEntry('p', '2026-07-01');
      final r2 = await db.calendarCycleDao.getEntry('p', '2026-07-01');
      expect(r1, equals(r2));
      expect(r1.hashCode, equals(r2.hashCode));
    });

    test('CalendarCycle.toJson and fromJson round-trip', () async {
      await insertCycle(
        db,
        programKey: 'q',
        dateKey: '2026-08-01',
        sefariaRef: 'Test Ref',
        sefariaRefHe: 'טסט',
        displayName: 'Test',
      );
      final row = (await db.calendarCycleDao.getEntry('q', '2026-08-01'))!;
      final json = row.toJson();
      expect(json['programKey'], 'q');
      expect(json['sefariaRef'], 'Test Ref');
      expect(json['sefariaRefHe'], 'טסט');

      final restored = CalendarCycle.fromJson(json);
      expect(restored, equals(row));
    });

    test('CalendarCycle.copyWith', () async {
      await insertCycle(db, programKey: 'r', dateKey: '2026-09-01');
      final row = (await db.calendarCycleDao.getEntry('r', '2026-09-01'))!;

      final copy = row.copyWith(sefariaRef: 'New Ref');
      expect(copy.programKey, row.programKey);
      expect(copy.sefariaRef, 'New Ref');
    });

    test('CalendarCycle.toCompanion', () async {
      await insertCycle(db, programKey: 's', dateKey: '2026-10-01');
      final row = (await db.calendarCycleDao.getEntry('s', '2026-10-01'))!;
      final companion = row.toCompanion(true);
      expect(companion.programKey.value, 's');
    });

    test('CalendarCycle.copyWithCompanion', () async {
      await insertCycle(db, programKey: 't', dateKey: '2026-11-01');
      final row = (await db.calendarCycleDao.getEntry('t', '2026-11-01'))!;
      final copy = row.copyWithCompanion(
        const CalendarCyclesCompanion(displayName: Value('New Name')),
      );
      expect(copy.displayName, 'New Name');
      expect(copy.programKey, row.programKey);
    });

    test('CalendarCycle.toString contains programKey', () async {
      await insertCycle(db, programKey: 'u', dateKey: '2026-12-01');
      final row = (await db.calendarCycleDao.getEntry('u', '2026-12-01'))!;
      expect(row.toString(), contains('u'));
    });

    test('CalendarCyclesCompanion.copyWith', () {
      const original = CalendarCyclesCompanion(
        programKey: Value('p'),
        dateKey: Value('2026-01-01'),
      );
      final copy = original.copyWith(sefariaRef: const Value('X'));
      expect(copy.programKey.value, 'p');
      expect(copy.sefariaRef.value, 'X');
    });
  });

  // ─── DailyContent ─────────────────────────────────────────────────────────

  group('DailyContent CRUD', () {
    Future<void> insertDaily(
      ContentDatabase db, {
      String ref = 'Chullin 7',
      String english = 'Chullin text',
      String hebrew = 'חולין',
    }) async {
      await db.into(db.dailyContent).insert(
        DailyContentCompanion.insert(
          sefariaRef: ref,
          englishText: Value(english),
          hebrewText: Value(hebrew),
        ),
      );
    }

    test('insert and getByRef', () async {
      await insertDaily(db, ref: 'Chullin 7', english: 'Chullin 7 text');

      final row = await db.dailyContentDao.getByRef('Chullin 7');
      expect(row, isNotNull);
      expect(row!.sefariaRef, 'Chullin 7');
      expect(row.englishText, 'Chullin 7 text');
    });

    test('getByRef returns null for missing', () async {
      final row = await db.dailyContentDao.getByRef('Missing Ref');
      expect(row, isNull);
    });

    test('watchByRef emits null then value', () async {
      final stream = db.dailyContentDao.watchByRef('Sanhedrin 74');
      expect(stream, emitsInOrder([isNull, isNotNull]));
      await Future<void>.delayed(Duration.zero);
      await insertDaily(db, ref: 'Sanhedrin 74');
    });

    test('DailyContentData equality and hashCode', () async {
      await insertDaily(db, ref: 'X 1');
      final r1 = await db.dailyContentDao.getByRef('X 1');
      final r2 = await db.dailyContentDao.getByRef('X 1');
      expect(r1, equals(r2));
      expect(r1.hashCode, equals(r2.hashCode));
    });

    test('DailyContentData.toJson and fromJson round-trip', () async {
      await insertDaily(db, ref: 'Y 2', english: 'Y text', hebrew: 'יוד');
      final row = (await db.dailyContentDao.getByRef('Y 2'))!;
      final json = row.toJson();
      expect(json['sefariaRef'], 'Y 2');
      expect(json['englishText'], 'Y text');

      final restored = DailyContentData.fromJson(json);
      expect(restored.sefariaRef, row.sefariaRef);
    });

    test('DailyContentData.copyWith', () async {
      await insertDaily(db, ref: 'Z 3', english: 'old');
      final row = (await db.dailyContentDao.getByRef('Z 3'))!;

      final copy = row.copyWith(englishText: 'new');
      expect(copy.sefariaRef, row.sefariaRef);
      expect(copy.englishText, 'new');
    });

    test('DailyContentData.toCompanion', () async {
      await insertDaily(db, ref: 'A1 1');
      final row = (await db.dailyContentDao.getByRef('A1 1'))!;
      final companion = row.toCompanion(true);
      expect(companion.sefariaRef.value, 'A1 1');
    });

    test('DailyContentData.copyWithCompanion', () async {
      await insertDaily(db, ref: 'B1 2');
      final row = (await db.dailyContentDao.getByRef('B1 2'))!;
      final copy = row.copyWithCompanion(
        const DailyContentCompanion(englishText: Value('Updated')),
      );
      expect(copy.englishText, 'Updated');
      expect(copy.sefariaRef, row.sefariaRef);
    });

    test('DailyContentData.toString contains ref', () async {
      await insertDaily(db, ref: 'C1 3');
      final row = (await db.dailyContentDao.getByRef('C1 3'))!;
      expect(row.toString(), contains('C1 3'));
    });

    test('DailyContentCompanion.copyWith', () {
      const original = DailyContentCompanion(
        sefariaRef: Value('original'),
      );
      final copy = original.copyWith(englishText: const Value('new'));
      expect(copy.sefariaRef.value, 'original');
      expect(copy.englishText.value, 'new');
    });
  });

  // ─── SeedMetadata ─────────────────────────────────────────────────────────

  group('SeedMetadata CRUD', () {
    Future<void> insertMeta(ContentDatabase db) async {
      await db.into(db.seedMetadata).insert(
        SeedMetadataCompanion.insert(
          version: const Value(42),
          builtAt: '2026-01-01T00:00:00Z',
          buildId: 'abc123',
          textCacheCount: 50000,
          calendarCycleCount: 35000,
          contentHash: const Value('sha256hash'),
          minAppVersion: const Value('2.0.0'),
        ),
      );
    }

    test('insert and getVersion', () async {
      await insertMeta(db);
      final meta = await db.seedMetadataDao.getVersion();
      expect(meta, isNotNull);
      expect(meta!.version, 42);
      expect(meta.buildId, 'abc123');
      expect(meta.textCacheCount, 50000);
      expect(meta.calendarCycleCount, 35000);
      expect(meta.contentHash, 'sha256hash');
      expect(meta.minAppVersion, '2.0.0');
    });

    test('getVersion returns null on empty db', () async {
      final meta = await db.seedMetadataDao.getVersion();
      expect(meta, isNull);
    });

    test('SeedMetadataData equality and hashCode', () async {
      await insertMeta(db);
      final r1 = await db.seedMetadataDao.getVersion();
      final r2 = await db.seedMetadataDao.getVersion();
      expect(r1, equals(r2));
      expect(r1.hashCode, equals(r2.hashCode));
    });

    test('SeedMetadataData.toJson and fromJson round-trip', () async {
      await insertMeta(db);
      final meta = (await db.seedMetadataDao.getVersion())!;
      final json = meta.toJson();
      expect(json['version'], 42);
      expect(json['buildId'], 'abc123');

      final restored = SeedMetadataData.fromJson(json);
      expect(restored.version, meta.version);
      expect(restored.buildId, meta.buildId);
    });

    test('SeedMetadataData.copyWith', () async {
      await insertMeta(db);
      final meta = (await db.seedMetadataDao.getVersion())!;
      final copy = meta.copyWith(buildId: 'new-build');
      expect(copy.version, meta.version);
      expect(copy.buildId, 'new-build');
    });

    test('SeedMetadataData.toCompanion', () async {
      await insertMeta(db);
      final meta = (await db.seedMetadataDao.getVersion())!;
      final companion = meta.toCompanion(true);
      expect(companion.version.value, 42);
    });

    test('SeedMetadataData.copyWithCompanion', () async {
      await insertMeta(db);
      final meta = (await db.seedMetadataDao.getVersion())!;
      final copy = meta.copyWithCompanion(
        const SeedMetadataCompanion(buildId: Value('updated-build')),
      );
      expect(copy.buildId, 'updated-build');
      expect(copy.version, meta.version);
    });

    test('SeedMetadataData.toString contains version', () async {
      await insertMeta(db);
      final meta = (await db.seedMetadataDao.getVersion())!;
      expect(meta.toString(), contains('42'));
    });

    test('SeedMetadataCompanion.copyWith', () {
      const original = SeedMetadataCompanion(
        version: Value(1),
        buildId: Value('build-1'),
      );
      final copy = original.copyWith(buildId: const Value('build-2'));
      expect(copy.version.value, 1);
      expect(copy.buildId.value, 'build-2');
    });
  });

  // ─── ContentDatabase.openReadOnly factory coverage ───────────────────────

  group('ContentDatabase schema', () {
    test('schemaVersion matches expectedSchemaVersion', () {
      expect(db.schemaVersion, ContentDatabase.expectedSchemaVersion);
    });
  });

  // ─── TableManager API (covers $$*TableManager classes) ───────────────────

  group('ContentDatabase managers', () {
    test('managers.textCache.filter works', () async {
      await db.into(db.textCache).insert(
        TextCacheCompanion.insert(
          sefariaRef: 'Genesis 1:1',
          hebrewText: 'בראשית',
          englishText: 'In the beginning',
          fetchedAt: DateTime.utc(2026, 1, 1),
        ),
      );

      final rows = await db.managers.textCache
          .filter((f) => f.sefariaRef('Genesis 1:1'))
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.sefariaRef, 'Genesis 1:1');
    });

    test('managers.calendarCycles.filter works', () async {
      await db.into(db.calendarCycles).insert(
        CalendarCyclesCompanion.insert(
          programKey: 'test_program',
          dateKey: '2026-01-01',
          sefariaRef: 'Test 1',
        ),
      );

      final rows = await db.managers.calendarCycles
          .filter((f) => f.programKey('test_program'))
          .get();
      expect(rows, hasLength(1));
    });

    test('managers.dailyContent.filter works', () async {
      await db.into(db.dailyContent).insert(
        DailyContentCompanion.insert(
          sefariaRef: 'Manager Test 1',
          englishText: const Value('English'),
        ),
      );

      final rows = await db.managers.dailyContent
          .filter((f) => f.sefariaRef('Manager Test 1'))
          .get();
      expect(rows, hasLength(1));
    });

    test('managers.seedMetadata.filter works', () async {
      await db.into(db.seedMetadata).insert(
        SeedMetadataCompanion.insert(
          version: const Value(10),
          builtAt: '2026-01-01T00:00:00Z',
          buildId: 'mgr-build',
          textCacheCount: 1000,
          calendarCycleCount: 2000,
        ),
      );

      final rows = await db.managers.seedMetadata
          .filter((f) => f.version(10))
          .get();
      expect(rows, hasLength(1));
    });

    test('managers ordering works for calendarCycles', () async {
      for (final d in ['2026-03-03', '2026-03-01', '2026-03-02']) {
        await db.into(db.calendarCycles).insert(
          CalendarCyclesCompanion.insert(
            programKey: 'ord_test',
            dateKey: d,
            sefariaRef: 'Ref $d',
          ),
        );
      }

      final rows = await db.managers.calendarCycles
          .filter((f) => f.programKey('ord_test'))
          .orderBy((o) => o.dateKey.asc())
          .get();
      expect(rows.first.dateKey, '2026-03-01');
      expect(rows.last.dateKey, '2026-03-03');
    });
  });
}
