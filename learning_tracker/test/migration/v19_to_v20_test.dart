/// C1 migration gate — schema v19 → v20.
///
/// Verifies:
///   1. completion_events has a track_id column (nullable).
///   2. completion_events has a points column.
///   3. completions_view includes non-purged rows.
///   4. completions_view excludes purged rows.
///   5. completions_view is a read-only projection (purge filter is correct).
@Tags(['migration'])
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../helpers/drift_memory.dart';

void main() {
  group('v19→v20: completion_events columns + completions_view purge filter', () {
    // ── 1. track_id column exists ─────────────────────────────────────────────

    test('track_id column: insert with non-null trackId and read it back', () async {
      final db = inMemoryDb();
      addTearDown(db.close);

      await seedProfile(db);

      final id = await db.completionEventDao.appendEvent(
        CompletionEventsCompanion.insert(
          profileId: 1,
          curriculumId: 'testCurriculum',
          sefariaRef: 'Berakhot 1a',
          stageId: 1,
          trackType: 'daily',
          trackId: const Value<int?>(42),
          eventTimestamp: DateTime.utc(2026, 1, 1),
        ),
      );

      final rows = await db.completionEventDao.getEventsByProfile(1);
      expect(rows, hasLength(1));
      expect(
        rows.first.trackId,
        isNotNull,
        reason: 'C1/v20: track_id column must exist and accept a non-null value',
      );
      expect(rows.first.id, equals(id));
    });

    // ── 2. points column exists ───────────────────────────────────────────────

    test('points column: insert with points=15 and read it back', () async {
      final db = inMemoryDb();
      addTearDown(db.close);

      await seedProfile(db);

      await db.completionEventDao.appendEvent(
        CompletionEventsCompanion.insert(
          profileId: 1,
          curriculumId: 'testCurriculum',
          sefariaRef: 'Berakhot 2a',
          stageId: 1,
          trackType: 'daily',
          points: const Value(15),
          eventTimestamp: DateTime.utc(2026, 1, 2),
        ),
      );

      final rows = await db.completionEventDao.getEventsByProfile(1);
      expect(rows, hasLength(1));
      expect(
        rows.first.points,
        equals(15),
        reason: 'C1/v20: points column must exist and store the inserted value',
      );
    });

    // ── 3. completions_view includes non-purged rows ──────────────────────────

    test('completions_view includes rows where purgedAt is null', () async {
      final db = inMemoryDb();
      addTearDown(db.close);

      await seedProfile(db);

      await db.completionEventDao.appendEvent(
        CompletionEventsCompanion.insert(
          profileId: 1,
          curriculumId: 'testCurriculum',
          sefariaRef: 'Berakhot 3a',
          stageId: 1,
          trackType: 'daily',
          eventTimestamp: DateTime.utc(2026, 1, 3),
        ),
      );

      final viewRows = await db.completionDao.getCompletionsByProfile(1);
      expect(
        viewRows,
        hasLength(1),
        reason: 'C1/v20: non-purged row must appear in completions_view',
      );
      expect(viewRows.first.sefariaRef, equals('Berakhot 3a'));
    });

    // ── 4. completions_view excludes purged rows ──────────────────────────────

    test('completions_view excludes rows where purgedAt is set', () async {
      final db = inMemoryDb();
      addTearDown(db.close);

      await seedProfile(db);

      await db.completionEventDao.appendEvent(
        CompletionEventsCompanion.insert(
          profileId: 1,
          curriculumId: 'testCurriculum',
          sefariaRef: 'Berakhot 4a',
          stageId: 1,
          trackType: 'daily',
          eventTimestamp: DateTime.utc(2026, 1, 4),
        ),
      );

      // Directly stamp purgedAt on the row to simulate a purge tombstone.
      await (db.update(db.completionEvents)
            ..where((t) => t.sefariaRef.equals('Berakhot 4a')))
          .write(
            CompletionEventsCompanion(
              purgedAt: Value(DateTime.utc(2026, 1, 5)),
            ),
          );

      final viewRows = await db.completionDao.getCompletionsByProfile(1);
      expect(
        viewRows,
        isEmpty,
        reason: 'C1/v20: purged row must NOT appear in completions_view',
      );
    });

    // ── 5. completions_view is a read-only projection ─────────────────────────

    test('completions_view returns only the 1 non-purged row out of 2 inserted', () async {
      final db = inMemoryDb();
      addTearDown(db.close);

      await seedProfile(db);

      // Row 1: active (purgedAt = null).
      await db.completionEventDao.appendEvent(
        CompletionEventsCompanion.insert(
          profileId: 1,
          curriculumId: 'testCurriculum',
          sefariaRef: 'Berakhot 5a',
          stageId: 1,
          trackType: 'daily',
          eventTimestamp: DateTime.utc(2026, 1, 5),
        ),
      );

      // Row 2: purged.
      await db.completionEventDao.appendEvent(
        CompletionEventsCompanion.insert(
          profileId: 1,
          curriculumId: 'testCurriculum',
          sefariaRef: 'Berakhot 6a',
          stageId: 1,
          trackType: 'daily',
          eventTimestamp: DateTime.utc(2026, 1, 6),
        ),
      );
      await (db.update(db.completionEvents)
            ..where((t) => t.sefariaRef.equals('Berakhot 6a')))
          .write(
            CompletionEventsCompanion(
              purgedAt: Value(DateTime.utc(2026, 1, 7)),
            ),
          );

      // Underlying table has 2 rows.
      final allEvents = await db.completionEventDao.getEventsByProfile(1);
      expect(allEvents, hasLength(2), reason: 'sanity: both rows in completion_events');

      // View shows only the active one.
      final viewRows = await db.completionDao.getCompletionsByProfile(1);
      expect(
        viewRows,
        hasLength(1),
        reason: 'C1/v20: completions_view must filter out the purged row',
      );
      expect(viewRows.first.sefariaRef, equals('Berakhot 5a'));
    });
  });
}
