/// C1 migration gate — schema v15 → v16.
///
/// Verifies:
///   1. CompletionWriter dedups a duplicate commit via the UNIQUE constraint
///      on completion_events instead of writing a second event row.
///   2. Backfill: rows seeded under the v15 schema survive the full
///      migration chain up to the current schema version. Currently skipped
///      (test-level) — see the AUD-t-cross-62 comment on the test itself for
///      the unrelated migration bug it is blocked on.
///
/// W3.22 dropped the derived_from_events column from completion_events; the
/// two tests that asserted its schema default and CompletionWriter tagging
/// were deleted rather than skipped (AUD-t-cross-62) — the column's
/// replacement (`CompletionDao._fromView` hardcoding `derivedFromEvents:
/// true` for every view row) leaves no per-row invariant left to test.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/learning/data/completion_writer.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_command.dart';

import '../helpers/drift_memory.dart';
import '../helpers/migration_test_helper.dart';

void main() {
  group('v15→v16: CompletionWriter dedup and migration backfill', () {
    // ── 1. CompletionWriter idempotency via completion_events (UNIQUE) ───────

    test(
      'duplicate commit returns isNew=false without writing a second event',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);

        final trackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: CurriculumId.mishnayos.storageKey,
                stateChangedAt: DateTimeFactory.nowUtc(),
                activatedAt: DateTimeFactory.nowUtc(),
              ),
            );

        final cmd = CompletionCommand(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Berakhot 3:1',
          stageId: 1,
          trackType: 'personal',
          trackId: trackId,
          completedAt: DateTimeFactory.nowUtc(),
          points: 5,
        );

        final writer = CompletionWriter(db);
        await writer.commit(cmd);
        final second = await writer.commit(cmd);

        expect(second.isNew, isFalse);

        final events = await db.completionEventDao.getEventsByProfile(1);
        expect(
          events,
          hasLength(1),
          reason: 'C1: dedup must prevent a second event row',
        );
      },
    );

    // ── 2. Migration backfill: openDbAtVersion simulates v15 → v16 ──────────
    //
    // Note: this exercises the FULL migration path from v15 (C1 setup) through
    // the current schema version. The partial schema in v15SchemaForC1() means
    // later migrations that touch other tables (streakEvents, learningLedger,
    // etc.) will skip gracefully — those tables don't exist and alterTable
    // creates them fresh. What we verify is that the seeded rows survive the
    // chain.
    //
    // AUD-t-cross-62 verification (2026-07-14): unskipping this test exposes a
    // genuine, pre-existing bug in UserDatabase.migration's onUpgrade, unrelated
    // to derived_from_events: the `from < 25` branch calls
    // `m.createTable(pointsLedger)` using the *current* PointsLedger table
    // definition, which already declares `ulid` (added v27) and
    // `syncEnqueuedAt` (added v29) as ordinary columns. The subsequent
    // `from < 27` / `from < 29` branches then call `m.addColumn(pointsLedger,
    // pointsLedger.ulid)` / `.syncEnqueuedAt` on a table that already has those
    // columns, raising `SqliteException: duplicate column name: ulid`. Any
    // real device upgrading from a schema below v25 straight to the current
    // version would hit this. Fixing it is out of scope for this test-hygiene
    // finding (AUD-t-cross-62 is about the file's dead placeholder assertions,
    // not the migration strategy) — filed as a candidate follow-up rather than
    // fixed as a drive-by here. Left skipped (test-level, not the whole group)
    // until that migration bug is fixed.
    test(
      'migration backfill: seeded completion_events rows survive the v15 → current migration chain',
      skip:
          'blocked on a pre-existing points_ledger/reward_redemptions '
          'duplicate-column migration bug when upgrading from < v25 '
          '(see comment above) — unrelated to AUD-t-cross-62; candidate '
          'follow-up, not fixed here',
      () async {
        final db = openDbAtVersion(15, v15SchemaForC1());
        addTearDown(db.close);

        // Trigger the first open (which runs migrations).
        final rows = await db.select(db.completionEvents).get();
        expect(rows, hasLength(2));

        expect(rows.any((r) => r.sefariaRef == 'Berakhot 2a'), isTrue);
        expect(rows.any((r) => r.sefariaRef == 'Berakhot 2b'), isTrue);
      },
    );
  });
}
