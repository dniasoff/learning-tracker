/// B1 migration gate — schema v21 → v22.
///
/// Verifies that the `completion_events_natural_key` unique index is widened
/// from the 4-tuple (profile_id, sefaria_ref, stage_id, track_type) to the
/// 5-tuple (profile_id, sefaria_ref, stage_id, track_type, curriculum_id).
///
/// Tests:
///   1. Two rows sharing the same 4-tuple but with different curriculumId
///      can coexist — this was previously a unique-key violation.
///   2. Two rows with the identical 5-tuple are collapsed to one row via
///      INSERT OR IGNORE (natural-key dedup still works).
@Tags(['migration'])
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../helpers/drift_memory.dart';

void main() {
  group('v21→v22: per-curriculum natural key on completion_events', () {
    // ── 1. Different curriculumId on same 4-tuple → two rows coexist ─────────

    test(
      'two rows differing only in curriculumId can coexist after index widening',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);

        await seedProfile(db);

        // Insert directly (bypassing the DAO) so we can control curriculumId
        // independently and avoid the DAO's getSingle() limitation when
        // multiple rows share the same 4-tuple.
        await db.into(db.completionEvents).insert(
          CompletionEventsCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot 1a',
            stageId: 1,
            trackType: 'daily',
            eventTimestamp: DateTime.utc(2026, 1, 1),
          ),
          mode: InsertMode.insertOrIgnore,
        );

        // Same 4-tuple, different curriculumId — must succeed with v22 index.
        await db.into(db.completionEvents).insert(
          CompletionEventsCompanion.insert(
            profileId: 1,
            curriculumId: 'bavli',
            sefariaRef: 'Berakhot 1a',
            stageId: 1,
            trackType: 'daily',
            eventTimestamp: DateTime.utc(2026, 1, 2),
          ),
          mode: InsertMode.insertOrIgnore,
        );

        final rows = await db.completionEventDao.getEventsByProfile(1);
        expect(
          rows,
          hasLength(2),
          reason:
              'B1/v22: rows with the same (profileId, sefariaRef, stageId, '
              'trackType) but different curriculumId must both be stored — '
              'the v22 index uses the 5-tuple including curriculum_id',
        );
        final curricula = rows.map((r) => r.curriculumId).toSet();
        expect(curricula, containsAll(['mishnayos', 'bavli']));
      },
    );

    // ── 2. Identical 5-tuple → silently dropped (INSERT OR IGNORE) ───────────

    test(
      'exact 5-tuple duplicate is silently dropped via INSERT OR IGNORE',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);

        await seedProfile(db);

        // First insert.
        await db.into(db.completionEvents).insert(
          CompletionEventsCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot 2a',
            stageId: 1,
            trackType: 'daily',
            eventTimestamp: DateTime.utc(2026, 2, 1),
          ),
          mode: InsertMode.insertOrIgnore,
        );

        // Second insert — identical 5-tuple; must be silently ignored.
        await db.into(db.completionEvents).insert(
          CompletionEventsCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot 2a',
            stageId: 1,
            trackType: 'daily',
            eventTimestamp: DateTime.utc(2026, 2, 2),
          ),
          mode: InsertMode.insertOrIgnore,
        );

        final rows = await db.completionEventDao.getEventsByProfile(1);
        expect(
          rows,
          hasLength(1),
          reason:
              'B1/v22: a 5-tuple duplicate must be silently dropped by '
              'INSERT OR IGNORE — natural-key dedup is still enforced',
        );
        // The first insert wins — eventTimestamp from the original row.
        expect(
          rows.first.eventTimestamp.toUtc(),
          equals(DateTime.utc(2026, 2, 1)),
          reason: 'The first (winning) row\'s eventTimestamp must be retained',
        );
      },
    );
  });
}
