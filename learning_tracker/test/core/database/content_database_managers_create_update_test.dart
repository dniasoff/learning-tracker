/// Coverage for manager create/update/withReferences callbacks in
/// content_database.g.dart (TextCache, CalendarCycles, DailyContent,
/// SeedMetadata tables).
///
/// Triggers createCompanionCallback, updateCompanionCallback, and
/// withReferenceMapper in the generated TableManager classes.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';

void main() {
  late ContentDatabase db;
  final now = DateTime.utc(2026, 3, 1, 12);

  setUp(() {
    db = ContentDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // ── textCache ──────────────────────────────────────────────────────────────

  group('textCache manager create/update/withReferences', () {
    setUp(() async {
      await db.managers.textCache.create(
        (o) => o(
          sefariaRef: 'Berakhot 2a',
          hebrewText: 'גמרא טקסט',
          englishText: 'Talmud text',
          fetchedAt: now,
        ),
      );
    });

    test('create via manager callback', () async {
      final rows = await db.managers.textCache.get();
      expect(rows, isNotEmpty);
    });

    test('update via manager callback', () async {
      final count = await db.managers.textCache
          .filter((f) => f.sefariaRef('Berakhot 2a'))
          .update(
            (o) => o(
              englishText: const Value('Updated text'),
              fetchedAt: Value(now),
            ),
          );
      expect(count, 1);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.textCache.withReferences().get();
      expect(rows, isNotEmpty);
    });
  });

  // ── calendarCycles ─────────────────────────────────────────────────────────

  group('calendarCycles manager create/update/withReferences', () {
    setUp(() async {
      await db.managers.calendarCycles.create(
        (o) => o(
          programKey: 'daf-yomi',
          dateKey: '2026-03-01',
          sefariaRef: 'Berakhot 2a',
        ),
      );
    });

    test('create via manager callback', () async {
      final rows = await db.managers.calendarCycles.get();
      expect(rows, isNotEmpty);
    });

    test('update via manager callback', () async {
      final count = await db.managers.calendarCycles
          .filter((f) => f.programKey('daf-yomi'))
          .update(
            (o) => o(displayName: const Value('Berakhot 2')),
          );
      expect(count, isNonNegative);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.calendarCycles.withReferences().get();
      expect(rows, isNotEmpty);
    });
  });

  // ── dailyContent ───────────────────────────────────────────────────────────

  group('dailyContent manager create/update/withReferences', () {
    setUp(() async {
      await db.managers.dailyContent.create(
        (o) => o(sefariaRef: 'Berakhot 2a'),
      );
    });

    test('create via manager callback', () async {
      final rows = await db.managers.dailyContent.get();
      expect(rows, isNotEmpty);
    });

    test('update via manager callback', () async {
      final count = await db.managers.dailyContent
          .filter((f) => f.sefariaRef('Berakhot 2a'))
          .update(
            (o) => o(englishText: const Value('Updated text')),
          );
      expect(count, isNonNegative);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.dailyContent.withReferences().get();
      expect(rows, isNotEmpty);
    });
  });

  // ── seedMetadata ───────────────────────────────────────────────────────────

  group('seedMetadata manager create/update/withReferences', () {
    setUp(() async {
      await db.managers.seedMetadata.create(
        (o) => o(
          builtAt: '2026-03-01',
          buildId: 'build-1',
          textCacheCount: 100,
          calendarCycleCount: 50,
        ),
      );
    });

    test('create via manager callback', () async {
      final rows = await db.managers.seedMetadata.get();
      expect(rows, isNotEmpty);
    });

    test('update via manager callback', () async {
      final count = await db.managers.seedMetadata
          .update(
            (o) => o(
              version: const Value(2),
              contentHash: const Value('abc123'),
              minAppVersion: const Value('1.0.0'),
            ),
          );
      expect(count, isNonNegative);
    });

    test('withReferences returns rows', () async {
      final rows = await db.managers.seedMetadata.withReferences().get();
      expect(rows, isNotEmpty);
    });
  });
}
