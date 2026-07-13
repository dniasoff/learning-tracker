/// Migration gate — schema v35 → v36 (AUD-t-cross-06:
/// track_learning_order profileId-in-PK gap closure).
///
/// Before v36, `track_learning_order` was the one user_database table with
/// a bare autoincrement PK and no `profileId` — isolation depended entirely
/// on `trackId` never being confused across profiles, with no schema-level
/// guard, and nothing purged the table on track/profile delete (no FK at
/// all). The v36 migration declares `profileId`
/// (`.references(LearnerProfiles, #id, onDelete: KeyAction.cascade)`) and
/// folds it into `uniqueKeys` with `trackId`/`sefariaRef`.
///
/// This builds a real v35-shaped DB (raw SQL, `user_version = 35`) with:
///   - two profiles, each with their own track,
///   - a `track_learning_order` row belonging to profile 1's track,
///   - a `track_learning_order` row belonging to profile 2's track,
///   - an ORPHANED `track_learning_order` row whose `track_id` does not
///     resolve to any `curriculum_tracks` row (the "never purged on delete"
///     gap this migration also closes) — must be dropped, not crash the
///     migration.
///
/// Then opens the live [UserDatabase] (triggering onUpgrade 35→36) and
/// asserts: each surviving row's `profileId` matches its track's real
/// owner, the orphan is gone, the composite UNIQUE(profileId, trackId,
/// sefariaRef) is enforced, and the new FK is enforced going forward
/// (cascade-deleting a profile purges its track_learning_order rows).
@Tags(['migration'])
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:sqlite3/sqlite3.dart';

void _buildV35Schema(Database raw) {
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

  // track_learning_order — v35 shape: bare autoincrement PK, no profileId.
  raw.execute('''
    CREATE TABLE track_learning_order (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      track_id INTEGER NOT NULL,
      sefaria_ref TEXT NOT NULL,
      sort_order INTEGER NOT NULL
    );
  ''');
  raw.execute('''
    CREATE UNIQUE INDEX track_learning_order_track_id_sefaria_ref
      ON track_learning_order (track_id, sefaria_ref);
  ''');

  raw.execute(
    'INSERT INTO accounts (id, email, tier, display_name, created_at, updated_at) '
    'VALUES '
    "(1, 'a@example.com', 'localBorn', 'Account A', 0, 0), "
    "(2, 'b@example.com', 'localBorn', 'Account B', 0, 0);",
  );
  raw.execute(
    'INSERT INTO learner_profiles '
    '(id, account_id, display_name, mode, created_at, updated_at) '
    'VALUES '
    "(1, 1, 'Learner One', 'adult', 0, 0), "
    "(2, 2, 'Learner Two', 'adult', 0, 0);",
  );
  raw.execute(
    'INSERT INTO curriculum_tracks '
    '(id, profile_id, curriculum_id, state_changed_at, activated_at) '
    'VALUES '
    "(10, 1, 'bavli', 1000, 1000), "
    "(20, 2, 'mishnayos', 1000, 1000);",
  );

  // Row 1 — belongs to track 10 (profile 1). Row 2 — belongs to track 20
  // (profile 2). Row 3 — ORPHANED: track_id 999 does not exist in
  // curriculum_tracks (the pre-v36 "never purged on delete" gap) — must be
  // dropped, not crash the migration with a NULL/missing profileId.
  raw.execute(
    'INSERT INTO track_learning_order (id, track_id, sefaria_ref, sort_order) '
    'VALUES '
    "(1, 10, 'Bavli.Berakhos', 0), "
    "(2, 20, 'Mishnah.Berakhos', 0), "
    "(3, 999, 'Orphaned.Ref', 0);",
  );

  // Stamp the schema version so Drift runs onUpgrade(35 → 36) — and ONLY
  // that block — when the live UserDatabase opens against this database.
  raw.execute('PRAGMA user_version = 35');
}

void main() {
  test('v35 → v36 backfills profileId from the owning track, drops '
      'orphaned rows, preserves the composite key, and enforces the new '
      'FK (cascade delete) going forward', () async {
    final raw = sqlite3.openInMemory();
    _buildV35Schema(raw);

    final db = UserDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    // ── profileId backfilled from the owning curriculum_tracks row ────
    final rows =
        (await db
                .customSelect(
                  'SELECT id, profile_id, track_id, sefaria_ref '
                  'FROM track_learning_order ORDER BY id',
                )
                .get())
            .map((r) => r.data)
            .toList();

    expect(
      rows,
      hasLength(2),
      reason:
          'the orphaned row (track_id 999) must be dropped by the '
          'migration, not crash it or survive with a bogus profileId',
    );

    expect(rows[0]['id'], 1);
    expect(
      rows[0]['profile_id'],
      1,
      reason: 'row 1 belongs to track 10, owned by profile 1',
    );

    expect(rows[1]['id'], 2);
    expect(
      rows[1]['profile_id'],
      2,
      reason: 'row 2 belongs to track 20, owned by profile 2',
    );

    // ── composite UNIQUE(profileId, trackId, sefariaRef) enforced ─────
    await expectLater(
      db
          .into(db.trackLearningOrder)
          .insert(
            TrackLearningOrderCompanion.insert(
              profileId: 1,
              trackId: 10,
              sefariaRef: 'Bavli.Berakhos',
              sortOrder: 5,
            ),
          ),
      throwsException,
      reason:
          'the new composite UNIQUE(profile_id, track_id, sefaria_ref) '
          'must still reject a duplicate after the v36 rebuild',
    );

    // ── new FK enforced going forward: profile-delete cascades ────────
    await (db.delete(db.learnerProfiles)..where((t) => t.id.equals(1))).go();

    final remaining =
        (await db
                .customSelect('SELECT profile_id FROM track_learning_order')
                .get())
            .map((r) => r.data['profile_id'])
            .toList();
    expect(
      remaining,
      [2],
      reason:
          'deleting profile 1 must now cascade-delete its '
          'track_learning_order row via the new FK — before v36 this row '
          'was orphaned forever',
    );
  });
}
