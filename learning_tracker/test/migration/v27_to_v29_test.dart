/// Migration gate — schema v27 → v29 (the D14 `sync_enqueued_at` backfill).
///
/// v29 adds a nullable `sync_enqueued_at` marker to `points_ledger` via the
/// `from < 29` branch of onUpgrade (user_database.dart). That marker drives
/// PointsBalanceDao.reEnqueueUnsyncedLedgerRows, which re-pushes every row
/// WHERE `sync_enqueued_at IS NULL AND ulid IS NOT NULL`.
///
/// Pre-D14 ledger rows (written under v27/v28) already carry a non-NULL `ulid`
/// (the deterministic cloud doc-id used to push them) but cannot have a
/// `sync_enqueued_at` value because that column did not exist yet. Without a
/// backfill, the v29 migration would leave every already-synced row with a NULL
/// marker + non-NULL ulid, so the reconciliation would treat the ENTIRE
/// historical ledger as "never queued" and re-push it on first post-upgrade
/// launch (a one-time outbox spike / burst of redundant Firestore writes).
///
/// This builds a real v27-shaped DB (raw SQL, user_version = 27) with seeded
/// points_ledger rows — some already-synced (non-NULL ulid), one local-born
/// (NULL ulid) — opens the live [UserDatabase] (triggering onUpgrade 27→29),
/// then asserts:
///   1. the `sync_enqueued_at` column now exists on points_ledger,
///   2. every ALREADY-SYNCED row (non-NULL ulid) has `sync_enqueued_at`
///      backfilled to its `created_at` (so the reconciliation skips it),
///   3. the LOCAL-BORN row (NULL ulid) keeps `sync_enqueued_at` NULL (it has no
///      cloud destination and must stay eligible for a future re-enqueue),
///   4. all ledger rows are preserved (no data loss).
@Tags(['migration'])
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:sqlite3/sqlite3.dart';

/// Builds a v27-shaped database (points_ledger has `ulid` but NOT
/// `sync_enqueued_at`) on [raw], seeds ledger rows, then stamps
/// `user_version = 27` so Drift runs onUpgrade(27 → 29) when [UserDatabase]
/// opens against the same underlying database.
void _buildV27Schema(Database raw) {
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
      updated_at INTEGER NOT NULL
    );
  ''');

  // points_ledger — v27 shape (table added at v25, `ulid` added at v27);
  // NO `sync_enqueued_at` column yet (that arrives in the v29 migration).
  raw.execute('''
    CREATE TABLE points_ledger (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      profile_id INTEGER NOT NULL REFERENCES learner_profiles (id) ON DELETE CASCADE,
      entry_kind TEXT NOT NULL,
      delta INTEGER NOT NULL,
      note TEXT,
      redemption_id INTEGER,
      created_at INTEGER NOT NULL,
      ulid TEXT
    );
  ''');

  raw.execute(
    'INSERT INTO accounts (id, email, tier, display_name, created_at, updated_at) '
    "VALUES (1, 'a@example.com', 'localBorn', 'Account', 0, 0);",
  );
  raw.execute(
    'INSERT INTO learner_profiles (id, account_id, display_name, mode, created_at, updated_at) '
    "VALUES (1, 1, 'Avi', 'child', 0, 0);",
  );

  // Two already-synced rows (non-NULL ulid) with distinct created_at values,
  // plus one local-born row (NULL ulid). created_at is stored as epoch-millis
  // (Drift DateTimeColumn default storage).
  raw.execute(
    'INSERT INTO points_ledger '
    '(id, profile_id, entry_kind, delta, created_at, ulid) VALUES '
    "(1, 1, 'completion', 10, 1000, '01HSYNCEDAAAAAAAAAAAAAAAAA'), "
    "(2, 1, 'parent_add', 5, 2000, '01HSYNCEDBBBBBBBBBBBBBBBBB'), "
    '(3, 1, \'completion\', 7, 3000, NULL);',
  );

  raw.execute('PRAGMA user_version = 27');
}

void main() {
  test(
    'v27 → v29 backfills sync_enqueued_at=created_at for already-synced '
    '(ulid != NULL) ledger rows, leaves local-born (ulid NULL) rows NULL',
    () async {
      final raw = sqlite3.openInMemory();
      _buildV27Schema(raw);

      // Opening the live UserDatabase against the v27 DB fires onUpgrade(27→29).
      final db = UserDatabase(NativeDatabase.opened(raw));
      addTearDown(db.close);

      // Force the migration to run by issuing a query. The SELECT references
      // sync_enqueued_at — it would throw if the v29 column migration didn't run.
      final rows = await db
          .customSelect(
            'SELECT id, created_at, ulid, sync_enqueued_at '
            'FROM points_ledger ORDER BY id',
          )
          .get();

      // 4. All three ledger rows are preserved.
      expect(
        rows.length,
        3,
        reason: 'all ledger rows preserved across migration',
      );

      final byId = {for (final r in rows) r.data['id'] as int: r.data};

      // 2. The two already-synced rows (non-NULL ulid) have sync_enqueued_at
      //    backfilled to their own created_at, so the reconciliation skips them
      //    (it only re-enqueues sync_enqueued_at IS NULL AND ulid IS NOT NULL).
      expect(byId[1]!['ulid'], isNotNull);
      expect(
        byId[1]!['sync_enqueued_at'],
        byId[1]!['created_at'],
        reason: 'already-synced row 1 marker backfilled from created_at',
      );
      expect(byId[2]!['ulid'], isNotNull);
      expect(
        byId[2]!['sync_enqueued_at'],
        byId[2]!['created_at'],
        reason: 'already-synced row 2 marker backfilled from created_at',
      );

      // 3. The local-born row (NULL ulid) keeps sync_enqueued_at NULL — it has no
      //    cloud destination and must remain eligible for a future re-enqueue.
      expect(byId[3]!['ulid'], isNull);
      expect(
        byId[3]!['sync_enqueued_at'],
        isNull,
        reason: 'local-born (ulid NULL) row marker stays NULL',
      );

      // Belt-and-braces: NO already-synced row is left mistakenly eligible for
      // re-enqueue (the exact D14 regression — a re-push of the whole history).
      final eligible = await db
          .customSelect(
            'SELECT COUNT(*) AS c FROM points_ledger '
            'WHERE sync_enqueued_at IS NULL AND ulid IS NOT NULL',
          )
          .getSingle();
      expect(
        eligible.data['c'],
        0,
        reason: 'no already-synced row is re-enqueued after the v29 backfill',
      );
    },
  );
}
