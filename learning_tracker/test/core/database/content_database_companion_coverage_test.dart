/// Companion-class coverage tests for content_database.g.dart.
///
/// Exercises the following generated patterns not yet covered:
///   • Companion.custom()    — RawValuesInsertable body
///   • Companion.toString()  — StringBuffer body
///   • Companion.toColumns() — present-field branches
///   • DataClass.toColumns() — direct call on DataClass instances
///   • DataClass.copyWithCompanion() — all field paths
///   • validateIntegrity missing paths — empty-companion inserts
///
/// No Firebase / Riverpod. Plain Drift in-memory DB.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';

ContentDatabase makeDb() => ContentDatabase(NativeDatabase.memory());

void main() {
  late ContentDatabase db;

  final now = DateTime.utc(2026, 3, 1, 12);

  setUp(() {
    db = makeDb();
  });

  tearDown(() async {
    await db.close();
  });

  // ─── TextCacheCompanion ───────────────────────────────────────────────────

  group('TextCacheCompanion', () {
    test('toString covers StringBuffer body', () {
      final c = TextCacheCompanion.insert(
        sefariaRef: 'Berakhot 2a',
        hebrewText: 'ברכות',
        englishText: 'Berakhot',
        fetchedAt: now,
      );
      final s = c.toString();
      expect(s, contains('TextCacheCompanion'));
      expect(s, contains('sefariaRef'));
      expect(s, contains('hebrewText'));
      expect(s, contains('rowid'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = TextCacheCompanion.custom(
        sefariaRef: const Variable('Berakhot 2a'),
        hebrewText: const Variable('ברכות'),
        englishText: const Variable('Berakhot'),
        fetchedAt: Variable(now),
        rowid: const Variable(1),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('sefaria_ref'), isTrue);
      expect(cols.containsKey('hebrew_text'), isTrue);
      expect(cols.containsKey('english_text'), isTrue);
      expect(cols.containsKey('fetched_at'), isTrue);
      expect(cols.containsKey('rowid'), isTrue);
    });

    test('toColumns with rowid present', () {
      final c = TextCacheCompanion(
        sefariaRef: const Value('Berakhot 2a'),
        hebrewText: const Value('ברכות'),
        englishText: const Value('Berakhot'),
        fetchedAt: Value(now),
        rowid: const Value(5),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('rowid'), isTrue);
    });

    test('copyWith preserves and overrides fields', () {
      final original = TextCacheCompanion.insert(
        sefariaRef: 'Berakhot 2a',
        hebrewText: 'ברכות',
        englishText: 'Berakhot',
        fetchedAt: now,
      );
      final copy = original.copyWith(
        hebrewText: const Value('ברכות עדכון'),
        rowid: const Value(10),
      );
      expect(copy.sefariaRef.value, 'Berakhot 2a');
      expect(copy.hebrewText.value, 'ברכות עדכון');
      expect(copy.rowid.value, 10);
    });
  });

  // ─── TextCacheData DataClass ──────────────────────────────────────────────

  group('TextCacheData DataClass', () {
    Future<TextCacheData> insertAndGet(String ref) async {
      await db.into(db.textCache).insert(
        TextCacheCompanion.insert(
          sefariaRef: ref,
          hebrewText: 'עברית',
          englishText: 'English',
          fetchedAt: now,
        ),
      );
      return (await db.contentTextCacheDao.getText(ref))!;
    }

    test('toColumns(true) covers DataClass.toColumns body', () async {
      final data = await insertAndGet('Genesis 1.1');
      final cols = data.toColumns(true);
      expect(cols.containsKey('sefaria_ref'), isTrue);
      expect(cols.containsKey('hebrew_text'), isTrue);
      expect(cols.containsKey('english_text'), isTrue);
      expect(cols.containsKey('fetched_at'), isTrue);
    });

    test('toCompanion covers DataClass.toCompanion body', () async {
      final data = await insertAndGet('Exodus 1.1');
      final comp = data.toCompanion(false);
      expect(comp.sefariaRef.value, 'Exodus 1.1');
      expect(comp.hebrewText.value, 'עברית');
    });

    test('copyWithCompanion covers all field paths', () async {
      final data = await insertAndGet('Leviticus 1.1');
      final copy = data.copyWithCompanion(
        const TextCacheCompanion(
          hebrewText: Value('new hebrew'),
          englishText: Value('new english'),
        ),
      );
      expect(copy.sefariaRef, 'Leviticus 1.1');
      expect(copy.hebrewText, 'new hebrew');
      expect(copy.englishText, 'new english');
      expect(copy.fetchedAt, data.fetchedAt);
    });

    test('toString covers StringBuffer body', () async {
      final data = await insertAndGet('Numbers 1.1');
      final s = data.toString();
      expect(s, contains('TextCacheData'));
      expect(s, contains('Numbers 1.1'));
    });

    test('hashCode and == work correctly', () async {
      final d1 = await insertAndGet('Deuteronomy 1.1');
      final d2 = await db.contentTextCacheDao.getText('Deuteronomy 1.1');
      expect(d1, equals(d2));
      expect(d1.hashCode, equals(d2!.hashCode));
    });
  });

  // ─── CalendarCyclesCompanion ──────────────────────────────────────────────

  group('CalendarCyclesCompanion', () {
    test('toString covers StringBuffer body', () {
      final c = CalendarCyclesCompanion.insert(
        programKey: 'daf_yomi',
        dateKey: '2026-03-01',
        sefariaRef: 'Berakhot 2a',
        sefariaRefHe: const Value('ברכות ב׳'),
        displayName: const Value('Daf Yomi'),
      );
      final s = c.toString();
      expect(s, contains('CalendarCyclesCompanion'));
      expect(s, contains('programKey'));
      expect(s, contains('sefariaRefHe'));
      expect(s, contains('rowid'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = CalendarCyclesCompanion.custom(
        programKey: const Variable('mishna_yomit'),
        dateKey: const Variable('2026-03-01'),
        sefariaRef: const Variable('Mishnah Berakhot 1.1'),
        sefariaRefHe: const Variable('משנה ברכות א׳:א׳'),
        displayName: const Variable('Mishna Yomit'),
        rowid: const Variable(99),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('program_key'), isTrue);
      expect(cols.containsKey('sefaria_ref_he'), isTrue);
      expect(cols.containsKey('display_name'), isTrue);
      expect(cols.containsKey('rowid'), isTrue);
    });

    test('toColumns with optional fields present', () {
      const c = CalendarCyclesCompanion(
        programKey: Value('daf_yomi'),
        dateKey: Value('2026-03-01'),
        sefariaRef: Value('Berakhot 2a'),
        sefariaRefHe: Value('ברכות ב׳'),
        displayName: Value('Daf Yomi'),
        rowid: Value(1),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('sefaria_ref_he'), isTrue);
      expect(cols.containsKey('display_name'), isTrue);
      expect(cols.containsKey('rowid'), isTrue);
    });

    test('copyWith preserves and overrides fields', () {
      final c = CalendarCyclesCompanion.insert(
        programKey: 'daf_yomi',
        dateKey: '2026-03-01',
        sefariaRef: 'Berakhot 2a',
      );
      final copy = c.copyWith(
        sefariaRefHe: const Value('ברכות ב׳ עדכון'),
        displayName: const Value('Updated'),
      );
      expect(copy.programKey.value, 'daf_yomi');
      expect(copy.sefariaRefHe.value, 'ברכות ב׳ עדכון');
      expect(copy.displayName.value, 'Updated');
    });
  });

  // ─── CalendarCycle DataClass ──────────────────────────────────────────────

  group('CalendarCycle DataClass', () {
    Future<CalendarCycle> insertAndGet(String program, String date) async {
      await db.into(db.calendarCycles).insert(
        CalendarCyclesCompanion.insert(
          programKey: program,
          dateKey: date,
          sefariaRef: 'Berakhot 2a',
          sefariaRefHe: const Value('ברכות ב׳'),
          displayName: const Value('Daf Yomi'),
        ),
      );
      final rows = await (db.select(db.calendarCycles)
            ..where(
              (t) => t.programKey.equals(program) & t.dateKey.equals(date),
            ))
          .getSingleOrNull();
      return rows!;
    }

    test('toColumns covers DataClass.toColumns body', () async {
      final cycle = await insertAndGet('daf_yomi', '2026-03-01');
      final cols = cycle.toColumns(true);
      expect(cols.containsKey('program_key'), isTrue);
      expect(cols.containsKey('date_key'), isTrue);
      expect(cols.containsKey('sefaria_ref'), isTrue);
      expect(cols.containsKey('sefaria_ref_he'), isTrue);
      expect(cols.containsKey('display_name'), isTrue);
    });

    test('toCompanion covers DataClass.toCompanion body', () async {
      final cycle = await insertAndGet('mishna_yomit', '2026-03-01');
      final comp = cycle.toCompanion(false);
      expect(comp.programKey.value, 'mishna_yomit');
      expect(comp.sefariaRefHe.value, 'ברכות ב׳');
    });

    test('copyWithCompanion covers all field paths', () async {
      final cycle = await insertAndGet('nach_yomi', '2026-03-01');
      final copy = cycle.copyWithCompanion(
        const CalendarCyclesCompanion(
          sefariaRef: Value('Updated 3a'),
          displayName: Value('Updated Name'),
        ),
      );
      expect(copy.programKey, 'nach_yomi');
      expect(copy.sefariaRef, 'Updated 3a');
      expect(copy.displayName, 'Updated Name');
      expect(copy.sefariaRefHe, cycle.sefariaRefHe);
    });

    test('toString covers StringBuffer body', () async {
      final cycle = await insertAndGet('daf_yomi', '2026-03-02');
      final s = cycle.toString();
      expect(s, contains('CalendarCycle'));
      expect(s, contains('daf_yomi'));
    });

    test('hashCode and == work correctly', () async {
      final c1 = await insertAndGet('daf_yomi', '2026-03-03');
      final c2 = await (db.select(db.calendarCycles)
            ..where(
              (t) =>
                  t.programKey.equals('daf_yomi') &
                  t.dateKey.equals('2026-03-03'),
            ))
          .getSingleOrNull();
      expect(c1, equals(c2));
      expect(c1.hashCode, equals(c2!.hashCode));
    });
  });

  // ─── DailyContentCompanion ────────────────────────────────────────────────

  group('DailyContentCompanion', () {
    test('toString covers StringBuffer body', () {
      final c = DailyContentCompanion.insert(
        sefariaRef: 'Berakhot 2a',
        englishText: const Value('English text here'),
        hebrewText: const Value('עברית'),
      );
      final s = c.toString();
      expect(s, contains('DailyContentCompanion'));
      expect(s, contains('sefariaRef'));
      expect(s, contains('englishText'));
      expect(s, contains('rowid'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = DailyContentCompanion.custom(
        sefariaRef: const Variable('Berakhot 5a'),
        englishText: const Variable('English content'),
        hebrewText: const Variable('תוכן עברי'),
        rowid: const Variable(7),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('sefaria_ref'), isTrue);
      expect(cols.containsKey('english_text'), isTrue);
      expect(cols.containsKey('hebrew_text'), isTrue);
      expect(cols.containsKey('rowid'), isTrue);
    });

    test('toColumns with optional fields present', () {
      const c = DailyContentCompanion(
        sefariaRef: Value('Berakhot 3a'),
        englishText: Value('English'),
        hebrewText: Value('עברית'),
        rowid: Value(3),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('english_text'), isTrue);
      expect(cols.containsKey('hebrew_text'), isTrue);
      expect(cols.containsKey('rowid'), isTrue);
    });

    test('copyWith preserves and overrides', () {
      final c = DailyContentCompanion.insert(sefariaRef: 'Berakhot 2a');
      final copy = c.copyWith(
        englishText: const Value('New English'),
        rowid: const Value(42),
      );
      expect(copy.sefariaRef.value, 'Berakhot 2a');
      expect(copy.englishText.value, 'New English');
      expect(copy.rowid.value, 42);
    });
  });

  // ─── DailyContentData DataClass ───────────────────────────────────────────

  group('DailyContentData DataClass', () {
    Future<DailyContentData> insertAndGet(String ref) async {
      await db.into(db.dailyContent).insert(
        DailyContentCompanion.insert(
          sefariaRef: ref,
          englishText: const Value('English text'),
          hebrewText: const Value('טקסט עברי'),
        ),
      );
      final rows = await (db.select(db.dailyContent)
            ..where((t) => t.sefariaRef.equals(ref)))
          .getSingleOrNull();
      return rows!;
    }

    test('toColumns covers DataClass.toColumns body', () async {
      final d = await insertAndGet('Berakhot 10a');
      final cols = d.toColumns(true);
      expect(cols.containsKey('sefaria_ref'), isTrue);
      expect(cols.containsKey('english_text'), isTrue);
      expect(cols.containsKey('hebrew_text'), isTrue);
    });

    test('toCompanion covers DataClass.toCompanion body', () async {
      final d = await insertAndGet('Berakhot 11a');
      final comp = d.toCompanion(false);
      expect(comp.sefariaRef.value, 'Berakhot 11a');
    });

    test('copyWithCompanion covers field paths', () async {
      final d = await insertAndGet('Berakhot 12a');
      final copy = d.copyWithCompanion(
        const DailyContentCompanion(
          englishText: Value('Updated English'),
        ),
      );
      expect(copy.sefariaRef, 'Berakhot 12a');
      expect(copy.englishText, 'Updated English');
      expect(copy.hebrewText, d.hebrewText);
    });

    test('toString covers StringBuffer body', () async {
      final d = await insertAndGet('Berakhot 13a');
      final s = d.toString();
      expect(s, contains('DailyContentData'));
      expect(s, contains('Berakhot 13a'));
    });

    test('toJson / fromJson round-trip', () async {
      final d = await insertAndGet('Berakhot 14a');
      final json = d.toJson();
      expect(json['sefariaRef'], 'Berakhot 14a');
      expect(json['englishText'], 'English text');

      final restored = DailyContentData.fromJson(json);
      expect(restored.sefariaRef, d.sefariaRef);
      expect(restored, equals(d));
    });

    test('copyWith preserves unchanged fields', () async {
      final d = await insertAndGet('Berakhot 15a');
      final copy = d.copyWith(englishText: 'New English');
      expect(copy.sefariaRef, d.sefariaRef);
      expect(copy.englishText, 'New English');
      expect(copy.hebrewText, d.hebrewText);
    });

    test('hashCode and == work correctly', () async {
      final d1 = await insertAndGet('Berakhot 16a');
      final d2 = await (db.select(db.dailyContent)
            ..where((t) => t.sefariaRef.equals('Berakhot 16a')))
          .getSingleOrNull();
      expect(d1, equals(d2));
      expect(d1.hashCode, equals(d2!.hashCode));
    });
  });

  // ─── SeedMetadataCompanion ────────────────────────────────────────────────

  group('SeedMetadataCompanion', () {
    test('toString covers StringBuffer body', () {
      final c = SeedMetadataCompanion.insert(
        builtAt: '2026-03-01T00:00:00Z',
        buildId: 'build-abc',
        textCacheCount: 1000,
        calendarCycleCount: 200,
        contentHash: const Value('sha256-abc'),
        minAppVersion: const Value('2.0.0'),
      );
      final s = c.toString();
      expect(s, contains('SeedMetadataCompanion'));
      expect(s, contains('builtAt'));
      expect(s, contains('contentHash'));
      expect(s, contains('minAppVersion'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = SeedMetadataCompanion.custom(
        version: const Variable(3),
        builtAt: const Variable('2026-03-01T00:00:00Z'),
        buildId: const Variable('build-xyz'),
        textCacheCount: const Variable(2000),
        calendarCycleCount: const Variable(400),
        contentHash: const Variable('sha256-xyz'),
        minAppVersion: const Variable('3.0.0'),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('version'), isTrue);
      expect(cols.containsKey('built_at'), isTrue);
      expect(cols.containsKey('content_hash'), isTrue);
      expect(cols.containsKey('min_app_version'), isTrue);
      expect(cols.containsKey('calendar_cycle_count'), isTrue);
    });

    test('toColumns with all fields present', () {
      const c = SeedMetadataCompanion(
        version: Value(2),
        builtAt: Value('2026-03-01T00:00:00Z'),
        buildId: Value('build-abc'),
        textCacheCount: Value(1000),
        calendarCycleCount: Value(200),
        contentHash: Value('sha256-abc'),
        minAppVersion: Value('2.0.0'),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('version'), isTrue);
      expect(cols.containsKey('content_hash'), isTrue);
      expect(cols.containsKey('min_app_version'), isTrue);
      expect(cols.containsKey('calendar_cycle_count'), isTrue);
    });

    test('copyWith preserves and overrides fields', () {
      final c = SeedMetadataCompanion.insert(
        builtAt: '2026-03-01T00:00:00Z',
        buildId: 'build-abc',
        textCacheCount: 1000,
        calendarCycleCount: 200,
      );
      final copy = c.copyWith(
        version: const Value(5),
        contentHash: const Value('new-hash'),
        minAppVersion: const Value('4.0.0'),
      );
      expect(copy.builtAt.value, '2026-03-01T00:00:00Z');
      expect(copy.version.value, 5);
      expect(copy.contentHash.value, 'new-hash');
      expect(copy.minAppVersion.value, '4.0.0');
    });
  });

  // ─── SeedMetadataData DataClass ───────────────────────────────────────────

  group('SeedMetadataData DataClass', () {
    Future<SeedMetadataData> insertAndGet() async {
      await db.into(db.seedMetadata).insert(
        SeedMetadataCompanion.insert(
          builtAt: '2026-03-01T00:00:00Z',
          buildId: 'build-xyz',
          textCacheCount: 1500,
          calendarCycleCount: 300,
          contentHash: const Value('sha256-test'),
          minAppVersion: const Value('2.5.0'),
        ),
      );
      return (await db.select(db.seedMetadata).getSingleOrNull())!;
    }

    test('toColumns covers DataClass.toColumns body', () async {
      final d = await insertAndGet();
      final cols = d.toColumns(true);
      expect(cols.containsKey('built_at'), isTrue);
      expect(cols.containsKey('build_id'), isTrue);
      expect(cols.containsKey('text_cache_count'), isTrue);
      expect(cols.containsKey('calendar_cycle_count'), isTrue);
      expect(cols.containsKey('content_hash'), isTrue);
      expect(cols.containsKey('min_app_version'), isTrue);
    });

    test('toCompanion covers DataClass.toCompanion body', () async {
      final d = await insertAndGet();
      final comp = d.toCompanion(false);
      expect(comp.buildId.value, 'build-xyz');
      expect(comp.textCacheCount.value, 1500);
    });

    test('copyWithCompanion covers field paths', () async {
      final d = await insertAndGet();
      final copy = d.copyWithCompanion(
        const SeedMetadataCompanion(
          textCacheCount: Value(2000),
          contentHash: Value('new-hash'),
        ),
      );
      expect(copy.buildId, d.buildId);
      expect(copy.textCacheCount, 2000);
      expect(copy.contentHash, 'new-hash');
    });

    test('toString covers StringBuffer body', () async {
      final d = await insertAndGet();
      final s = d.toString();
      expect(s, contains('SeedMetadataData'));
      expect(s, contains('build-xyz'));
    });

    test('toJson / fromJson round-trip', () async {
      final d = await insertAndGet();
      final json = d.toJson();
      expect(json['buildId'], 'build-xyz');
      expect(json['textCacheCount'], 1500);

      final restored = SeedMetadataData.fromJson(json);
      expect(restored.buildId, d.buildId);
      expect(restored, equals(d));
    });

    test('copyWith preserves unchanged fields', () async {
      final d = await insertAndGet();
      final copy = d.copyWith(textCacheCount: 9999);
      expect(copy.buildId, d.buildId);
      expect(copy.textCacheCount, 9999);
    });

    test('hashCode and ==', () async {
      final d1 = await insertAndGet();
      final d2 = await db.select(db.seedMetadata).getSingleOrNull();
      expect(d1, equals(d2));
      expect(d1.hashCode, equals(d2!.hashCode));
    });
  });

  // ─── validateIntegrity missing paths ──────────────────────────────────────

  group('validateIntegrity — missing required fields', () {
    test('TextCache insert without sefariaRef throws', () {
      expect(
        () => db.into(db.textCache).insert(const TextCacheCompanion()),
        throwsA(anything),
      );
    });

    test('CalendarCycles insert without programKey throws', () {
      expect(
        () => db
            .into(db.calendarCycles)
            .insert(const CalendarCyclesCompanion()),
        throwsA(anything),
      );
    });

    test('DailyContent insert without sefariaRef throws', () {
      expect(
        () => db
            .into(db.dailyContent)
            .insert(const DailyContentCompanion()),
        throwsA(anything),
      );
    });

    test('SeedMetadata insert without builtAt throws', () {
      expect(
        () => db
            .into(db.seedMetadata)
            .insert(const SeedMetadataCompanion()),
        throwsA(anything),
      );
    });
  });

  // ─── managers — extended filter fields ────────────────────────────────────

  group('managers — textCache filter by hebrewText and englishText', () {
    setUp(() async {
      await db.into(db.textCache).insert(
        TextCacheCompanion.insert(
          sefariaRef: 'Berakhot 2a',
          hebrewText: 'ברכות',
          englishText: 'Berakhot Chapter 1',
          fetchedAt: now,
        ),
      );
      await db.into(db.textCache).insert(
        TextCacheCompanion.insert(
          sefariaRef: 'Shabbat 2a',
          hebrewText: 'שבת',
          englishText: 'Shabbat Chapter 1',
          fetchedAt: now,
        ),
      );
    });

    test('filter by hebrewText', () async {
      final rows = await db.managers.textCache
          .filter((f) => f.hebrewText('ברכות'))
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.sefariaRef, 'Berakhot 2a');
    });

    test('filter by englishText', () async {
      final rows = await db.managers.textCache
          .filter((f) => f.englishText('Shabbat Chapter 1'))
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.sefariaRef, 'Shabbat 2a');
    });

    test('filter by fetchedAt', () async {
      final rows = await db.managers.textCache
          .filter((f) => f.fetchedAt(now))
          .get();
      expect(rows, hasLength(2));
    });

    test('orderBy hebrewText', () async {
      final rows = await db.managers.textCache
          .orderBy((o) => o.hebrewText.asc())
          .get();
      expect(rows, hasLength(2));
    });

    test('orderBy englishText desc', () async {
      final rows = await db.managers.textCache
          .orderBy((o) => o.englishText.desc())
          .get();
      expect(rows.first.sefariaRef, 'Shabbat 2a');
    });

    test('orderBy fetchedAt', () async {
      final rows = await db.managers.textCache
          .orderBy((o) => o.fetchedAt.asc())
          .get();
      expect(rows, hasLength(2));
    });
  });

  group('managers — calendarCycles extended filter fields', () {
    setUp(() async {
      await db.into(db.calendarCycles).insert(
        CalendarCyclesCompanion.insert(
          programKey: 'daf_yomi',
          dateKey: '2026-03-01',
          sefariaRef: 'Berakhot 2a',
          sefariaRefHe: const Value('ברכות ב׳'),
          displayName: const Value('Daf Yomi'),
        ),
      );
      await db.into(db.calendarCycles).insert(
        CalendarCyclesCompanion.insert(
          programKey: 'mishna_yomit',
          dateKey: '2026-03-01',
          sefariaRef: 'Mishnah Berakhot 1.1',
          sefariaRefHe: const Value('משנה ברכות'),
          displayName: const Value('Mishna Yomit'),
        ),
      );
    });

    test('filter by sefariaRefHe', () async {
      final rows = await db.managers.calendarCycles
          .filter((f) => f.sefariaRefHe('ברכות ב׳'))
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.programKey, 'daf_yomi');
    });

    test('filter by displayName', () async {
      final rows = await db.managers.calendarCycles
          .filter((f) => f.displayName('Mishna Yomit'))
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy sefariaRef', () async {
      final rows = await db.managers.calendarCycles
          .orderBy((o) => o.sefariaRef.asc())
          .get();
      expect(rows, hasLength(2));
    });

    test('orderBy sefariaRefHe', () async {
      final rows = await db.managers.calendarCycles
          .orderBy((o) => o.sefariaRefHe.asc())
          .get();
      expect(rows, hasLength(2));
    });

    test('orderBy displayName', () async {
      final rows = await db.managers.calendarCycles
          .orderBy((o) => o.displayName.desc())
          .get();
      expect(rows.first.displayName, 'Mishna Yomit');
    });
  });

  group('managers — seedMetadata extended filter fields', () {
    setUp(() async {
      await db.into(db.seedMetadata).insert(
        SeedMetadataCompanion.insert(
          builtAt: '2026-03-01T00:00:00Z',
          buildId: 'build-mgr-1',
          textCacheCount: 1000,
          calendarCycleCount: 200,
          contentHash: const Value('hash-1'),
          minAppVersion: const Value('1.5.0'),
        ),
      );
    });

    test('filter by builtAt', () async {
      final rows = await db.managers.seedMetadata
          .filter((f) => f.builtAt('2026-03-01T00:00:00Z'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by buildId', () async {
      final rows = await db.managers.seedMetadata
          .filter((f) => f.buildId('build-mgr-1'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by textCacheCount', () async {
      final rows = await db.managers.seedMetadata
          .filter((f) => f.textCacheCount(1000))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by calendarCycleCount', () async {
      final rows = await db.managers.seedMetadata
          .filter((f) => f.calendarCycleCount(200))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by contentHash', () async {
      final rows = await db.managers.seedMetadata
          .filter((f) => f.contentHash('hash-1'))
          .get();
      expect(rows, hasLength(1));
    });

    test('filter by minAppVersion', () async {
      final rows = await db.managers.seedMetadata
          .filter((f) => f.minAppVersion('1.5.0'))
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy builtAt', () async {
      final rows = await db.managers.seedMetadata
          .orderBy((o) => o.builtAt.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy buildId', () async {
      final rows = await db.managers.seedMetadata
          .orderBy((o) => o.buildId.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy textCacheCount', () async {
      final rows = await db.managers.seedMetadata
          .orderBy((o) => o.textCacheCount.desc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy calendarCycleCount', () async {
      final rows = await db.managers.seedMetadata
          .orderBy((o) => o.calendarCycleCount.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy contentHash', () async {
      final rows = await db.managers.seedMetadata
          .orderBy((o) => o.contentHash.asc())
          .get();
      expect(rows, hasLength(1));
    });

    test('orderBy minAppVersion', () async {
      final rows = await db.managers.seedMetadata
          .orderBy((o) => o.minAppVersion.desc())
          .get();
      expect(rows, hasLength(1));
    });
  });
}
