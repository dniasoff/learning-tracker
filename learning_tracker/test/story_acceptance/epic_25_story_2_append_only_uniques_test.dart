/// Story acceptance tests for Story 25.2 — Append-only event tables
/// with composite-natural-key UNIQUE indexes (DNI-323).
///
/// AC1: `completion_events` has UNIQUE composite (profileId, sefariaRef,
///      stageId, trackType).
/// AC2: `streak_events` has UNIQUE composite (profileId, dayUtc, eventType).
/// AC3: `learning_ledger` has UNIQUE composite (profileId, ulid).
/// AC4: None of the three DAOs expose a public `delete*` method.
/// AC5: Duplicate inserts use INSERT OR IGNORE — one row lands, not two.
/// AC6: Duplicate inserts return the same row id, not a throw.
@Tags(['epic_25', 'story_25_2'])
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:test/test.dart';

UserDatabase _db() => UserDatabase(NativeDatabase.memory());

void main() {
  // --------------------------------------------------------------------------
  // AC1 — completion_events UNIQUE composite (profileId, sefariaRef, stageId,
  //       trackType)
  // --------------------------------------------------------------------------

  group('AC1 — completion_events UNIQUE composite', () {
    late UserDatabase db;
    setUp(() => db = _db());
    tearDown(() => db.close());

    test(
      'table exists with a UNIQUE index on the natural-key composite',
      () async {
        final pragmaRows = await db
            .customSelect(
              'SELECT name, "unique" AS u FROM pragma_index_list(?)',
              variables: [Variable.withString('completion_events')],
            )
            .get();
        final uniqueIndexes = pragmaRows
            .where((r) => r.read<int>('u') == 1)
            .toList();
        expect(
          uniqueIndexes,
          isNotEmpty,
          reason: 'completion_events must have at least one UNIQUE index',
        );

        // Verify the columns on (at least) one UNIQUE index match the natural
        // key composite.
        final hits = <String>{};
        for (final row in uniqueIndexes) {
          final indexName = row.read<String>('name');
          final cols = await db
              .customSelect(
                'SELECT name FROM pragma_index_info(?)',
                variables: [Variable.withString(indexName)],
              )
              .get();
          final colNames = cols.map((r) => r.read<String>('name')).toSet();
          if (colNames.containsAll([
                'profile_id',
                'sefaria_ref',
                'stage_id',
                'track_type',
              ]) &&
              colNames.length == 4) {
            hits.add(indexName);
          }
        }
        expect(
          hits,
          isNotEmpty,
          reason:
              'No UNIQUE index covers (profileId, sefariaRef, stageId, trackType)',
        );
      },
    );
  });

  // --------------------------------------------------------------------------
  // AC2 — streak_events UNIQUE composite (profileId, dayUtc, eventType)
  // --------------------------------------------------------------------------

  group('AC2 — streak_events UNIQUE composite', () {
    late UserDatabase db;
    setUp(() => db = _db());
    tearDown(() => db.close());

    test('UNIQUE index covers (profileId, dayUtc, eventType)', () async {
      final pragmaRows = await db
          .customSelect(
            'SELECT name, "unique" AS u FROM pragma_index_list(?)',
            variables: [Variable.withString('streak_events')],
          )
          .get();
      final uniqueIndexes = pragmaRows
          .where((r) => r.read<int>('u') == 1)
          .toList();
      expect(uniqueIndexes, isNotEmpty);

      final hits = <String>{};
      for (final row in uniqueIndexes) {
        final indexName = row.read<String>('name');
        final cols = await db
            .customSelect(
              'SELECT name FROM pragma_index_info(?)',
              variables: [Variable.withString(indexName)],
            )
            .get();
        final colNames = cols.map((r) => r.read<String>('name')).toSet();
        if (colNames.containsAll(['profile_id', 'day_utc', 'event_type']) &&
            colNames.length == 3) {
          hits.add(indexName);
        }
      }
      expect(
        hits,
        isNotEmpty,
        reason: 'No UNIQUE index covers (profileId, dayUtc, eventType)',
      );
    });
  });

  // --------------------------------------------------------------------------
  // AC3 — learning_ledger UNIQUE composite (profileId, ulid)
  // --------------------------------------------------------------------------

  group('AC3 — learning_ledger UNIQUE composite', () {
    late UserDatabase db;
    setUp(() => db = _db());
    tearDown(() => db.close());

    test('UNIQUE index covers (profileId, ulid)', () async {
      final pragmaRows = await db
          .customSelect(
            'SELECT name, "unique" AS u FROM pragma_index_list(?)',
            variables: [Variable.withString('learning_ledger')],
          )
          .get();
      final uniqueIndexes = pragmaRows
          .where((r) => r.read<int>('u') == 1)
          .toList();
      expect(uniqueIndexes, isNotEmpty);

      final hits = <String>{};
      for (final row in uniqueIndexes) {
        final indexName = row.read<String>('name');
        final cols = await db
            .customSelect(
              'SELECT name FROM pragma_index_info(?)',
              variables: [Variable.withString(indexName)],
            )
            .get();
        final colNames = cols.map((r) => r.read<String>('name')).toSet();
        if (colNames.containsAll(['profile_id', 'ulid']) &&
            colNames.length == 2) {
          hits.add(indexName);
        }
      }
      expect(
        hits,
        isNotEmpty,
        reason: 'No UNIQUE index covers (profileId, ulid)',
      );
    });
  });

  // --------------------------------------------------------------------------
  // AC4 — DAOs expose no public delete* method
  // --------------------------------------------------------------------------

  group('AC4 — no public delete* methods on event DAOs', () {
    // dart:mirrors isn't available in Flutter test, so we statically grep the
    // DAO source files for any public `delete*` method signature. Private
    // helpers (underscore-prefixed) are explicitly permitted by the story.
    const daoSourcesToCheck = [
      'lib/core/database/daos/completion_event_dao.dart',
      'lib/core/database/daos/streak_event_dao.dart',
      'lib/core/database/daos/learning_ledger_dao.dart',
    ];

    for (final relPath in daoSourcesToCheck) {
      test('$relPath has no public delete method', () {
        final file = File(relPath);
        expect(
          file.existsSync(),
          isTrue,
          reason: 'test must run from learning_tracker/ (Flutter project root)',
        );
        final source = file.readAsStringSync();
        final pattern = RegExp(
          r'^\s*(Future|Stream|void)[^\n]*\s\bdelete\w*\s*\(',
          multiLine: true,
        );
        final matches = pattern
            .allMatches(source)
            .map((m) => m.group(0))
            .toList();
        expect(
          matches,
          isEmpty,
          reason: 'FR5: public delete method found in $relPath: $matches',
        );
      });
    }
  });

  // --------------------------------------------------------------------------
  // AC5 / AC6 — Duplicate inserts use INSERT OR IGNORE; same row id returned
  // --------------------------------------------------------------------------

  group('AC5/AC6 — INSERT OR IGNORE collapses duplicates idempotently', () {
    late UserDatabase db;
    setUp(() => db = _db());
    tearDown(() => db.close());

    test(
      'completion_events: duplicate natural key returns same row id',
      () async {
        const profileId = 7;
        const sefariaRef = 'Mishnah Berakhot 1:1';
        const stageId = 1;
        const trackType = 'personal';

        final firstId = await db.completionEventDao.appendEvent(
          CompletionEventsCompanion.insert(
            profileId: profileId,
            curriculumId: 'mishnayos',
            sefariaRef: sefariaRef,
            stageId: stageId,
            trackType: trackType,
            eventTimestamp: DateTime.utc(2026, 5, 13, 10),
          ),
        );

        final secondId = await db.completionEventDao.appendEvent(
          CompletionEventsCompanion.insert(
            profileId: profileId,
            curriculumId: 'mishnayos',
            sefariaRef: sefariaRef,
            stageId: stageId,
            trackType: trackType,
            // Different timestamp — should still collapse on natural key.
            eventTimestamp: DateTime.utc(2026, 5, 13, 11),
          ),
        );

        expect(
          secondId,
          equals(firstId),
          reason: 'INSERT OR IGNORE must surface the existing row id',
        );

        final rows = await db.select(db.completionEvents).get();
        expect(rows, hasLength(1));
      },
    );

    test('streak_events: duplicate natural key returns same row id', () async {
      const profileId = 9;
      final dayUtc = DateTime.utc(2026, 5, 13);

      final firstId = await db.streakEventDao.appendEvent(
        StreakEventsCompanion.insert(
          profileId: profileId,
          eventType: 'completion',
          dayUtc: dayUtc,
          eventTimestamp: DateTime.utc(2026, 5, 13, 10),
        ),
      );

      final secondId = await db.streakEventDao.appendEvent(
        StreakEventsCompanion.insert(
          profileId: profileId,
          eventType: 'completion',
          dayUtc: dayUtc,
          // Different sub-day timestamp — must still collapse on day.
          eventTimestamp: DateTime.utc(2026, 5, 13, 23),
        ),
      );

      expect(secondId, equals(firstId));
      final rows = await db.select(db.streakEvents).get();
      expect(rows, hasLength(1));
    });

    test(
      'learning_ledger: duplicate (profileId, ulid) returns same row id',
      () async {
        const profileId = 11;
        const ulid = '01HVABCDEFGHJKMNPQRSTVWXYZ';

        final firstId = await db.learningLedgerDao.insertEntry(
          LearningLedgerCompanion.insert(
            profileId: profileId,
            ulid: const Value(ulid),
            curriculumId: 'mishnayos',
            entryScope: 'masechta',
            unitIdentifier: 'Berakhot',
            unitDisplayNameHe: 'ברכות',
            unitDisplayNameEn: 'Berakhot',
            trackType: 'personal',
            completedAt: DateTime.utc(2026, 5, 13, 10),
            completionNumber: 1,
            markedBy: profileId,
          ),
        );

        final secondId = await db.learningLedgerDao.insertEntry(
          LearningLedgerCompanion.insert(
            profileId: profileId,
            ulid: const Value(ulid),
            curriculumId: 'mishnayos',
            entryScope: 'masechta',
            unitIdentifier: 'Berakhot',
            unitDisplayNameHe: 'ברכות',
            unitDisplayNameEn: 'Berakhot',
            trackType: 'personal',
            completedAt: DateTime.utc(2026, 5, 13, 11),
            completionNumber: 1,
            markedBy: profileId,
          ),
        );

        expect(
          secondId,
          equals(firstId),
          reason: 'duplicate ulid for the same profile must dedup',
        );
        final rows = await db.select(db.learningLedger).get();
        expect(rows, hasLength(1));
      },
    );

    test(
      'completion_events: distinct profiles with same content key do NOT dedup',
      () async {
        final id1 = await db.completionEventDao.appendEvent(
          CompletionEventsCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: 'Mishnah Berakhot 1:1',
            stageId: 1,
            trackType: 'personal',
            eventTimestamp: DateTime.utc(2026, 5, 13, 10),
          ),
        );
        final id2 = await db.completionEventDao.appendEvent(
          CompletionEventsCompanion.insert(
            profileId: 2,
            curriculumId: 'mishnayos',
            sefariaRef: 'Mishnah Berakhot 1:1',
            stageId: 1,
            trackType: 'personal',
            eventTimestamp: DateTime.utc(2026, 5, 13, 10),
          ),
        );
        expect(id1 == id2, isFalse);
        final rows = await db.select(db.completionEvents).get();
        expect(rows, hasLength(2));
      },
    );
  });

  // --------------------------------------------------------------------------
  // Schema version bumped to 14
  // --------------------------------------------------------------------------

  group('schema version', () {
    test('UserDatabase.schemaVersion is at least 14', () {
      final db = _db();
      addTearDown(db.close);
      expect(db.schemaVersion, greaterThanOrEqualTo(14));
    });
  });
}
