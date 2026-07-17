/// Migration gate — schema v36 → v37 (AUD-scheduler-15: explicit
/// `stage_id_format` marker on `completion_events`).
///
/// Before v37, `completion_events.stage_id` was ambiguous — some rows store
/// a [StageDefinitions.id] value (older writes), others store a
/// [StageDefinitions.stageOrder] ordinal (every current writer,
/// [CompletionWriter]). Both value spaces are small positive integers that
/// can coincide — especially once `reorderStages` moves a stage's order
/// away from its id — so a per-read "does this look like a known stageOrder"
/// guess (the pre-v37 `SchedulerCompletionRepositoryImpl.resolveStageOrder`)
/// could silently resolve to the WRONG stage.
///
/// The v37 migration adds the nullable `stage_id_format` column and runs a
/// ONE-TIME backfill that classifies every pre-existing row it CAN classify
/// with certainty:
///   - `stage_id` matches a CURRENT `stageOrder` for the row's own
///     (profile_id, curriculum_id) -> tagged `'stageOrder'`.
///   - else `stage_id` matches a CURRENT stage `id` for the row's own
///     (profile_id, curriculum_id) -> tagged `'legacyId'`.
///   - else (the stage no longer exists) -> left `NULL` (unresolvable,
///     unaffected — same as pre-v37 behaviour).
///
/// This builds a real v36-shaped DB (raw SQL, `user_version = 36`) with one
/// profile, one curriculum, four stages arranged so that stage A's id (7)
/// coincides with stage B's CURRENT stageOrder (7) — the exact collision
/// AUD-scheduler-15 describes — and four completion_events rows exercising:
/// a non-colliding legacy-id reference (row 1), the genuine, unrecoverable
/// id/order collision (row 2 — the migration cannot invent information that
/// was never persisted, so it preserves the pre-v37 priority rather than
/// crashing or guessing worse), a clean already-new-format row (row 3), and
/// an unresolvable row referencing a deleted stage (row 4).
@Tags(['migration'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:sqlite3/sqlite3.dart';

void _buildV36Schema(Database raw) {
  raw.execute('''
    CREATE TABLE accounts (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      email TEXT NOT NULL UNIQUE,
      firebase_uid TEXT UNIQUE,
      password_hash TEXT,
      tier TEXT NOT NULL,
      display_name TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
  ''');

  raw.execute('''
    CREATE TABLE learner_profiles (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      account_id INTEGER NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
      display_name TEXT NOT NULL,
      mode TEXT NOT NULL CHECK (mode IN ('adult', 'child')),
      avatar_index INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      is_tutored INTEGER NOT NULL DEFAULT 0,
      tutor_parent_uid TEXT,
      tutor_remote_profile_id INTEGER,
      tutor_grant_id TEXT
    );
  ''');

  raw.execute('''
    CREATE TABLE curriculum_tracks (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      profile_id INTEGER NOT NULL REFERENCES learner_profiles (id) ON DELETE CASCADE,
      curriculum_id TEXT NOT NULL,
      state TEXT NOT NULL DEFAULT 'active',
      state_changed_at INTEGER NOT NULL,
      activated_at INTEGER NOT NULL,
      pace_reset_date INTEGER,
      last_reorder_at INTEGER
    );
  ''');

  raw.execute('''
    CREATE TABLE stage_definitions (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      profile_id INTEGER NOT NULL REFERENCES learner_profiles (id) ON DELETE CASCADE,
      curriculum_id TEXT NOT NULL,
      track_id INTEGER NOT NULL REFERENCES curriculum_tracks (id),
      stage_order INTEGER NOT NULL,
      stage_name TEXT NOT NULL,
      is_default INTEGER NOT NULL DEFAULT 0,
      schedule TEXT NOT NULL DEFAULT '{"type":"delay","delay_days":0}',
      updated_at INTEGER NOT NULL,
      UNIQUE (profile_id, curriculum_id, stage_order, track_id)
    );
  ''');

  raw.execute('''
    CREATE TABLE completion_events (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      profile_id INTEGER NOT NULL REFERENCES learner_profiles (id) ON DELETE CASCADE,
      curriculum_id TEXT NOT NULL,
      sefaria_ref TEXT NOT NULL,
      stage_id INTEGER NOT NULL,
      track_type TEXT NOT NULL,
      track_id INTEGER,
      points INTEGER NOT NULL DEFAULT 0,
      event_timestamp INTEGER NOT NULL,
      created_at INTEGER NOT NULL DEFAULT 0,
      purged_at INTEGER
    );
  ''');
  raw.execute('''
    CREATE UNIQUE INDEX completion_events_natural_key
      ON completion_events (profile_id, sefaria_ref, stage_id, track_type, curriculum_id);
  ''');

  raw.execute(
    'INSERT INTO accounts (id, email, tier, display_name, created_at, updated_at) '
    "VALUES (1, 'a@example.com', 'localBorn', 'Account A', 0, 0);",
  );
  raw.execute(
    'INSERT INTO learner_profiles '
    '(id, account_id, display_name, mode, created_at, updated_at) '
    "VALUES (1, 1, 'Learner One', 'adult', 0, 0);",
  );
  raw.execute(
    'INSERT INTO curriculum_tracks '
    '(id, profile_id, curriculum_id, state_changed_at, activated_at) '
    "VALUES (100, 1, 'mishnayos', 1000, 1000);",
  );

  // Stage set for profile 1 / curriculum 'mishnayos' — deliberately
  // constructed so stage A's id (7) coincides with stage B's CURRENT
  // stageOrder (7), the exact ambiguity AUD-scheduler-15 describes.
  //   A: id=7,  stageOrder=1 ('Learn')     <- legacy row 2 means THIS stage
  //   B: id=1,  stageOrder=7 ('Custom')    <- what row 2 wrongly resolves to
  //   C: id=2,  stageOrder=2 ('Chazara1')  <- clean new-format control
  //   D: id=99, stageOrder=3 ('Chazara2')  <- non-colliding legacy-id target
  raw.execute(
    'INSERT INTO stage_definitions '
    '(id, profile_id, curriculum_id, track_id, stage_order, stage_name, updated_at) '
    'VALUES '
    "(7, 1, 'mishnayos', 100, 1, 'Learn', 0), "
    "(1, 1, 'mishnayos', 100, 7, 'Custom', 0), "
    "(2, 1, 'mishnayos', 100, 2, 'Chazara1', 0), "
    "(99, 1, 'mishnayos', 100, 3, 'Chazara2', 0);",
  );

  raw.execute(
    'INSERT INTO completion_events '
    '(id, profile_id, curriculum_id, sefaria_ref, stage_id, track_type, event_timestamp) '
    'VALUES '
    // Row 1 — non-colliding legacy-id reference: 99 matches no CURRENT
    // stageOrder (known orders are {1,2,3,7}) but matches stage D's id.
    "(1, 1, 'mishnayos', 'Mishnah.Berakhos.1.1', 99, 'personal', 2000), "
    // Row 2 — the genuine, unrecoverable collision: 7 is BOTH stage A's id
    // and stage B's CURRENT stageOrder. No signal survives to tell them
    // apart; the migration preserves the pre-v37 order-first priority.
    "(2, 1, 'mishnayos', 'Mishnah.Berakhos.1.2', 7, 'personal', 2001), "
    // Row 3 — a clean, already-new-format row (order 2, no ambiguity).
    "(3, 1, 'mishnayos', 'Mishnah.Berakhos.1.3', 2, 'personal', 2002), "
    // Row 4 — unresolvable: 555 matches neither a current id nor order
    // (references a since-deleted stage).
    "(4, 1, 'mishnayos', 'Mishnah.Berakhos.1.4', 555, 'personal', 2003);",
  );

  // Stamp the schema version so Drift runs onUpgrade(36 → 37) — and ONLY
  // that block — when the live UserDatabase opens against this database.
  raw.execute('PRAGMA user_version = 36');
}

void main() {
  test('v36 → v37 adds stage_id_format and backfills it deterministically, '
      'preserving stage_id and leaving genuine collisions unresolved rather '
      'than guessing worse', () async {
    final raw = sqlite3.openInMemory();
    _buildV36Schema(raw);

    final db = UserDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    final rows =
        (await db
                .customSelect(
                  'SELECT id, stage_id, stage_id_format '
                  'FROM completion_events ORDER BY id',
                )
                .get())
            .map((r) => r.data)
            .toList();

    expect(rows, hasLength(4), reason: 'no row is dropped by the migration');

    // Row 1 — non-colliding legacy id: deterministically classified.
    expect(rows[0]['id'], 1);
    expect(
      rows[0]['stage_id'],
      99,
      reason: 'the migration only tags the row — it never rewrites stage_id',
    );
    expect(
      rows[0]['stage_id_format'],
      'legacyId',
      reason:
          '99 matches no current stageOrder but matches stage D\'s id — '
          'unambiguous, so the migration tags it deterministically',
    );

    // Row 2 — genuine collision: no new information exists to resolve it,
    // so the migration must not invent a "fix" — it preserves exactly the
    // pre-v37 order-first priority (tagged 'stageOrder', which downstream
    // still resolves to stage B's order, same as before this migration).
    expect(rows[1]['id'], 2);
    expect(rows[1]['stage_id'], 7);
    expect(
      rows[1]['stage_id_format'],
      'stageOrder',
      reason:
          '7 collides with BOTH stage A\'s id and stage B\'s stageOrder — '
          'unrecoverable; the migration must not regress or fabricate a '
          'result, so it keeps the historical order-first reading',
    );

    // Row 3 — already unambiguous new-format row: untouched.
    expect(rows[2]['id'], 3);
    expect(rows[2]['stage_id'], 2);
    expect(rows[2]['stage_id_format'], 'stageOrder');

    // Row 4 — unresolvable (deleted stage): left NULL, same as pre-v37.
    expect(rows[3]['id'], 4);
    expect(rows[3]['stage_id'], 555);
    expect(rows[3]['stage_id_format'], isNull);

    // ── column is real and usable going forward ───────────────────────
    await db
        .into(db.completionEvents)
        .insert(
          CompletionEventsCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: 'Mishnah.Berakhos.1.5',
            stageId: 1,
            trackType: 'personal',
            eventTimestamp: DateTime.utc(2026, 1, 1),
            stageIdFormat: const Value('stageOrder'),
          ),
        );
    final newRow = await (db.select(
      db.completionEvents,
    )..where((t) => t.sefariaRef.equals('Mishnah.Berakhos.1.5'))).getSingle();
    expect(newRow.stageIdFormat, 'stageOrder');
  });
}
