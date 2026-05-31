/// Migration gate — schema v26 → v29 (regression for R4-10: v28 tutor columns
/// skipped on v26→v29 upgrade path).
///
/// Background (R4-10): the v28 tutor mirror columns
/// (`is_tutored`, `tutor_parent_uid`, `tutor_remote_profile_id`,
/// `tutor_grant_id`) were originally guarded by `if (from == 27)` in
/// onUpgrade. A v26 database upgrading to v29 has `from=26`, so `from == 27`
/// is false and the four columns are never added → runtime "no such column"
/// on any tutor-feature query.
///
/// Fix: the guard was changed to `if (from >= 26 && from < 28)`, which covers
/// both v26→v29 and v27→v28 (and v27→v29) paths, while NOT double-adding for
/// databases arriving from v25 or earlier (those receive the columns via the
/// v26 alterTable rebuild's columnTransformer).
///
/// This builds a real v26-shaped DB (raw SQL, user_version = 26) with seeded
/// accounts + profiles + an FK'd child row, opens the live [UserDatabase]
/// (triggering onUpgrade 26→29), then asserts:
///   1. the four v28 tutor mirror columns exist on learner_profiles,
///   2. existing rows are preserved (no data loss),
///   3. `is_tutored` is backfilled to 0 (not NULL) on pre-existing rows,
///   4. the `tutor_*` columns are NULL on pre-existing rows,
///   5. no FK row is orphaned (`PRAGMA foreign_key_check` is empty),
///   6. the v29 `sync_enqueued_at` column also exists on points_ledger
///      (the v29 migration runs too on this upgrade path).
@Tags(['migration'])
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:sqlite3/sqlite3.dart';

/// Builds a v26-shaped database on [raw], then stamps `user_version = 26` so
/// Drift runs onUpgrade(26→29) when [UserDatabase] opens against it.
///
/// v26 shape: accounts without `user_mode` (dropped in v26 rebuild), and
/// learner_profiles with mode CHECK constraint but WITHOUT any of the v28
/// tutor mirror columns.
void _buildV26Schema(Database raw) {
  // accounts — v26 shape: user_mode was dropped by the v26 rebuild.
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

  // learner_profiles — v26 shape: has the mode CHECK constraint, but NONE of
  // the v28 tutor mirror columns (is_tutored, tutor_parent_uid,
  // tutor_remote_profile_id, tutor_grant_id).
  raw.execute('''
    CREATE TABLE learner_profiles (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      account_id INTEGER NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
      display_name TEXT NOT NULL,
      mode TEXT NOT NULL CHECK (mode IN ('adult', 'child')),
      avatar_index INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
  ''');

  // completion_events — FK'd child row to prove referential integrity survives.
  raw.execute('''
    CREATE TABLE completion_events (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      profile_id INTEGER NOT NULL REFERENCES learner_profiles (id) ON DELETE CASCADE,
      curriculum_id TEXT NOT NULL,
      sefaria_ref TEXT NOT NULL,
      stage_id INTEGER NOT NULL,
      track_type TEXT NOT NULL,
      event_timestamp INTEGER NOT NULL
    );
  ''');

  // points_ledger — v26 shape: `ulid` column is NOT present yet (added in v27).
  // The v27 arm (`from < 27`) will add it during the 26→29 upgrade, and the
  // v29 arm (`from < 29`) will then add `sync_enqueued_at`.
  raw.execute('''
    CREATE TABLE points_ledger (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      profile_id INTEGER NOT NULL REFERENCES learner_profiles (id) ON DELETE CASCADE,
      entry_kind TEXT NOT NULL,
      delta INTEGER NOT NULL,
      note TEXT,
      redemption_id INTEGER,
      created_at INTEGER NOT NULL
    );
  ''');

  // reward_redemptions — v26 shape: `ulid` column is NOT present yet.
  raw.execute('''
    CREATE TABLE reward_redemptions (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      profile_id INTEGER NOT NULL REFERENCES learner_profiles (id) ON DELETE CASCADE,
      reward_title TEXT NOT NULL,
      icon_index INTEGER NOT NULL DEFAULT 0,
      points_cost INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending_fulfilment',
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
  ''');

  raw.execute(
    'INSERT INTO accounts (id, email, tier, display_name, created_at, updated_at) '
    "VALUES (1, 'a@example.com', 'localBorn', 'Account', 0, 0);",
  );
  raw.execute(
    'INSERT INTO learner_profiles (id, account_id, display_name, mode, created_at, updated_at) '
    "VALUES (1, 1, 'Avi', 'child', 0, 0), (2, 1, 'Mum', 'adult', 0, 0);",
  );
  raw.execute(
    'INSERT INTO completion_events (id, profile_id, curriculum_id, sefaria_ref, stage_id, track_type, event_timestamp) '
    "VALUES (1, 1, 'talmud_bavli', 'Berakhot.2a', 1, 'personal', 0);",
  );
  raw.execute(
    'INSERT INTO points_ledger (id, profile_id, entry_kind, delta, created_at) '
    "VALUES (1, 1, 'completion', 10, 1000);",
  );

  raw.execute('PRAGMA user_version = 26');
}

void main() {
  test('v26 → v29: adds tutor mirror columns (R4-10 regression), preserves rows, '
      'backfills is_tutored=0', () async {
    final raw = sqlite3.openInMemory();
    _buildV26Schema(raw);

    // Opening the live UserDatabase against the v26 DB fires onUpgrade(26→29).
    final db = UserDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    // 1. Force the migration to run by selecting the four v28 tutor columns.
    //    This SELECT would throw with "no such column" if R4-10 were not fixed.
    final profiles = await db
        .customSelect(
          'SELECT id, display_name, is_tutored, tutor_parent_uid, '
          'tutor_remote_profile_id, tutor_grant_id FROM learner_profiles ORDER BY id',
        )
        .get();

    // 2. Both profiles are preserved.
    expect(
      profiles.length,
      2,
      reason: 'both profiles preserved across v26→v29 migration',
    );
    expect(profiles[0].data['display_name'], 'Avi');
    expect(profiles[1].data['display_name'], 'Mum');

    // 3. is_tutored backfilled to 0 (NOT NULL DEFAULT 0), not NULL.
    expect(
      profiles[0].data['is_tutored'],
      0,
      reason: 'is_tutored backfilled to 0 on pre-existing child profile',
    );
    expect(
      profiles[1].data['is_tutored'],
      0,
      reason: 'is_tutored backfilled to 0 on pre-existing adult profile',
    );

    // 4. tutor_* columns are NULL on pre-existing rows.
    expect(profiles[0].data['tutor_parent_uid'], isNull);
    expect(profiles[0].data['tutor_remote_profile_id'], isNull);
    expect(profiles[0].data['tutor_grant_id'], isNull);

    // 5. No orphaned FK rows (the child completion_event must still resolve).
    final fkCheck = await db.customSelect('PRAGMA foreign_key_check').get();
    expect(fkCheck, isEmpty, reason: 'no orphaned rows after migration');
    final events = await db
        .customSelect('SELECT COUNT(*) AS c FROM completion_events')
        .getSingle();
    expect(events.data['c'], 1, reason: 'child completion_event preserved');

    // 6. The v29 `sync_enqueued_at` column also exists on points_ledger
    //    (the from < 29 arm also runs on this upgrade path).
    final ledgerCols = await db
        .customSelect("PRAGMA table_info('points_ledger')")
        .get();
    final colNames = ledgerCols.map((r) => r.data['name'] as String).toList();
    expect(
      colNames,
      contains('sync_enqueued_at'),
      reason: 'v29 sync_enqueued_at column added during v26→v29 upgrade',
    );
    // Also confirm ulid was added (v27 arm runs too).
    expect(
      colNames,
      contains('ulid'),
      reason: 'v27 ulid column added during v26→v29 upgrade',
    );
  });
}
