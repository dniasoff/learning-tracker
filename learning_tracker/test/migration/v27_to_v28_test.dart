/// Migration gate — schema v27 → v28 (the tutor "talmid view" mirror columns).
///
/// v28 adds four columns to `learner_profiles` via the `from == 27` branch of
/// onUpgrade (user_database.dart): `is_tutored` (NOT NULL DEFAULT 0,
/// CHECK IN (0,1)), `tutor_parent_uid`, `tutor_remote_profile_id`,
/// `tutor_grant_id` (all nullable text). That branch only runs when upgrading
/// FROM EXACTLY v27 — the v25/v26 rebuild path already copies the current
/// schema (incl. these columns), so it is the ONE migration step that the
/// existing v25→current tests never exercise.
///
/// This builds a real v27-shaped DB (raw SQL, user_version = 27) with seeded
/// accounts + profiles + an FK'd child row, opens the live [UserDatabase]
/// (triggering onUpgrade 27→28), then asserts:
///   1. the four tutor mirror columns now exist on learner_profiles,
///   2. every existing profile + child row is PRESERVED (no data loss),
///   3. `is_tutored` is backfilled to 0 (not NULL) on pre-existing rows,
///   4. the tutor_* columns are NULL on pre-existing rows,
///   5. no FK row is orphaned (`PRAGMA foreign_key_check` is empty),
///   6. the `is_tutored IN (0,1)` CHECK is enforced on the migrated table.
@Tags(['migration'])
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:sqlite3/sqlite3.dart';

/// Builds a v27-shaped database (post-v26 rebuild, pre-v28 tutor columns) on
/// [raw], then stamps `user_version = 27` so Drift runs onUpgrade(27 → 28)
/// when [UserDatabase] opens against the same underlying database.
void _buildV27Schema(Database raw) {
  // accounts — v27 shape: user_mode was dropped in the v26 rebuild.
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

  // learner_profiles — v27 shape: has the v26 mode CHECK, but NONE of the
  // v28 tutor mirror columns.
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

  // A child row FK'd to learner_profiles to prove the migration preserves
  // referential integrity (the v28 step is additive — addColumn — but we guard
  // it anyway, matching the v25→v27 gate's discipline).
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

  raw.execute('PRAGMA user_version = 27');
}

void main() {
  test('v27 → v28 adds tutor mirror columns, preserves rows, backfills is_tutored=0', () async {
    final raw = sqlite3.openInMemory();
    _buildV27Schema(raw);

    // Opening the live UserDatabase against the v27 DB fires onUpgrade(27→28).
    final db = UserDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    // Force the migration to run by issuing a query.
    final profiles = await db
        .customSelect('SELECT id, display_name, is_tutored, tutor_parent_uid, '
            'tutor_remote_profile_id, tutor_grant_id FROM learner_profiles ORDER BY id')
        .get();

    // 1. The four tutor mirror columns now exist (the SELECT above would throw
    //    if any were missing) and 2. both profiles are preserved.
    expect(profiles.length, 2, reason: 'both profiles preserved across migration');
    expect(profiles[0].data['display_name'], 'Avi');
    expect(profiles[1].data['display_name'], 'Mum');

    // 3. is_tutored backfilled to 0 (NOT NULL DEFAULT 0), not NULL.
    expect(profiles[0].data['is_tutored'], 0);
    expect(profiles[1].data['is_tutored'], 0);

    // 4. tutor_* columns are NULL on pre-existing rows.
    expect(profiles[0].data['tutor_parent_uid'], isNull);
    expect(profiles[0].data['tutor_remote_profile_id'], isNull);
    expect(profiles[0].data['tutor_grant_id'], isNull);

    // 5. No orphaned FK rows (the child completion_event still resolves).
    final fkCheck = await db.customSelect('PRAGMA foreign_key_check').get();
    expect(fkCheck, isEmpty, reason: 'no orphaned rows after migration');
    final events = await db.customSelect('SELECT COUNT(*) AS c FROM completion_events').getSingle();
    expect(events.data['c'], 1, reason: 'child completion_event preserved');

    // 6. The is_tutored CHECK (IN (0,1)) is enforced on the migrated table.
    await expectLater(
      db.customStatement(
        'INSERT INTO learner_profiles (account_id, display_name, mode, is_tutored, created_at, updated_at) '
        "VALUES (1, 'Bad', 'child', 2, 0, 0)",
      ),
      throwsA(isA<SqliteException>()),
    );
  });
}
