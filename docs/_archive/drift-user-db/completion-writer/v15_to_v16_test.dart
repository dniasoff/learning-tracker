/// C1 migration gate — schema v15 → v16.
///
/// Verifies:
///   1. CompletionWriter dedups a duplicate commit via the UNIQUE constraint
///      on completion_events instead of writing a second event row.
///   2. Migration integrity: a pre-v25 database upgrades to the current schema
///      without the points_ledger duplicate-column crash (AUD-t-cross-62
///      follow-up — onUpgrade's from<27/from<29 branches are now guarded with
///      from>=25). The original v15→v16 derived_from_events backfill assertion
///      is not reinstated — that column was removed in W3.22.
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

    // ── 2. Migration integrity: a pre-v25 database upgrades cleanly ──────────
    //
    // This slot originally asserted the v15→v16 `derived_from_events` backfill,
    // but that column and its two assertions were removed in W3.22 (see file
    // header). Reactivating the case (AUD-t-cross-62 AC2) surfaced a genuine,
    // unrelated bug in UserDatabase.migration's onUpgrade: the `from < 25`
    // branch calls `m.createTable(pointsLedger)` using the *current* table
    // definition — which already declares `ulid` (v27), `syncEnqueuedAt` (v29),
    // the UNIQUE indexes (v34) and the redemptionId FK (v35) — and the later
    // `from < 27` / `< 29` / `< 34` / `< 35` branches then re-added those same
    // columns/indexes, raising `SqliteException: duplicate column name: ulid`
    // and aborting the entire upgrade for any pre-v25 database.
    //
    // FIXED 2026-07-21: those four branches are now guarded with `from >= 25`,
    // so a < 25 upgrade (which already gets the full current-schema points
    // tables from the `from < 25` createTable) skips the redundant deltas
    // instead of duplicating them. This test now proves a pre-v25 → current
    // upgrade runs to completion and yields the correct points_ledger schema.
    // The removed derived_from_events backfill assertion is not reinstated —
    // the column no longer exists; migration integrity is what remains worth
    // guarding here.
    test(
      'a pre-v25 database upgrades to the current schema without the '
      'points_ledger duplicate-column crash (AUD-t-cross-62 follow-up)',
      () async {
        final db = openDbAtVersion(15, v15SchemaForC1());
        addTearDown(db.close);

        // Force the full onUpgrade chain (15 → current) to run to completion.
        // Before the from>=25 guards this threw "duplicate column name: ulid".
        await db.customStatement('SELECT 1');

        // points_ledger exists carrying the modern columns the `from < 25`
        // createTable builds — proving the guarded v27/v29/v34/v35 deltas were
        // skipped for the pre-v25 path, not re-applied.
        final cols = await db
            .customSelect("SELECT name FROM pragma_table_info('points_ledger')")
            .get();
        final columnNames = cols.map((r) => r.read<String>('name')).toSet();
        expect(
          columnNames,
          containsAll(['ulid', 'sync_enqueued_at', 'redemption_id']),
          reason:
              'the from<25 createTable must build the current points_ledger '
              'schema and the guarded addColumn deltas must not run again',
        );

        // The @TableIndex UNIQUE index is present exactly once (not duplicated
        // by the now-guarded `from < 34` createIndex).
        final indexes = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'index' "
              "AND name = 'points_ledger_profile_ulid'",
            )
            .get();
        expect(indexes, hasLength(1));
      },
    );
  });
}
