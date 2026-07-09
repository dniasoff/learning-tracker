/// Migration gate — schema v33 → v34 (AUD-core-database-03: points_ledger /
/// reward_redemptions UNIQUE(profile_id, ulid) gap closure).
///
/// Before v34, `points_ledger` and `reward_redemptions` had a nullable
/// `ulid` cloud-sync id but no DB constraint backing it — a
/// SELECT-then-INSERT TOCTOU race in `PointsBalanceDao` could let two racing
/// merges of the same pulled remote entry land as two rows, silently
/// double-crediting a child's points balance (the `points_balance` row is
/// re-derived by *summing* the ledger, so a duplicate row directly inflates
/// it). The v34 migration adds a UNIQUE composite index on
/// `(profile_id, ulid)` to both tables — mirroring the one `learning_ledger`
/// already has — but first must safely handle any duplicate rows a device
/// that already hit the race would have accumulated (`CREATE UNIQUE INDEX`
/// fails outright over duplicate data), and repair any resulting stale
/// balance.
///
/// This builds a real v33-shaped DB (raw SQL, `user_version = 33`) with:
///   - a profile whose `points_ledger` already has a genuine duplicate
///     `(profile_id, ulid)` pair (the pre-existing double-credit bug: the
///     stored `points_balance.balance` reflects BOTH copies),
///   - a `NULL`-ulid local-born ledger row on the same profile (must never
///     be treated as a duplicate — SQLite allows multiple NULLs in a
///     UNIQUE index),
///   - a second profile whose ledger has no duplicates (must be left alone
///     — balance untouched, no spurious re-derivation),
///   - a `reward_redemptions` duplicate `(profile_id, ulid)` pair with
///     different `status`/`updated_at` (LWW: the newer `updated_at` row
///     must survive).
///
/// Then opens the live [UserDatabase] (triggering onUpgrade 33→34) and
/// asserts: duplicates collapse to one row each, the surviving reward
/// redemption is the newer one, the un-duplicated profile's ledger/balance
/// are untouched, the double-credited profile's balance is corrected to the
/// deduplicated sum, and both UNIQUE indexes now exist and are enforced
/// (a fresh duplicate insert throws).
@Tags(['migration'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:sqlite3/sqlite3.dart';

void _buildV33Schema(Database raw) {
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

  // points_ledger — v29+ shape (ulid @ v27, sync_enqueued_at @ v29), no
  // UNIQUE(profile_id, ulid) index yet (that's the v34 migration).
  raw.execute('''
    CREATE TABLE points_ledger (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      profile_id INTEGER NOT NULL REFERENCES learner_profiles (id) ON DELETE CASCADE,
      entry_kind TEXT NOT NULL,
      delta INTEGER NOT NULL,
      note TEXT,
      redemption_id INTEGER,
      created_at INTEGER NOT NULL,
      ulid TEXT,
      sync_enqueued_at INTEGER
    );
  ''');

  raw.execute('''
    CREATE TABLE points_balance (
      profile_id INTEGER NOT NULL REFERENCES learner_profiles (id) ON DELETE CASCADE,
      balance INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (profile_id)
    );
  ''');

  raw.execute('''
    CREATE TABLE reward_redemptions (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      profile_id INTEGER NOT NULL REFERENCES learner_profiles (id) ON DELETE CASCADE,
      reward_title TEXT NOT NULL,
      icon_index INTEGER NOT NULL DEFAULT 0,
      points_cost INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending_fulfilment',
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      ulid TEXT
    );
  ''');

  raw.execute(
    'INSERT INTO accounts (id, email, tier, display_name, created_at, updated_at) '
    "VALUES (1, 'a@example.com', 'localBorn', 'Account', 0, 0);",
  );
  raw.execute(
    'INSERT INTO learner_profiles '
    '(id, account_id, display_name, mode, created_at, updated_at) VALUES '
    "(1, 1, 'Racer', 'child', 0, 0), "
    "(2, 1, 'Clean', 'child', 0, 0);",
  );

  // Profile 1 — the double-credit bug: two rows share ulid 'race-ulid',
  // each with delta 10, plus a NULL-ulid local-born row with delta 3 that
  // must be left completely alone.
  raw.execute(
    'INSERT INTO points_ledger '
    '(id, profile_id, entry_kind, delta, created_at, ulid, sync_enqueued_at) '
    'VALUES '
    "(1, 1, 'completion', 10, 1000, 'race-ulid', 1000), "
    "(2, 1, 'completion', 10, 1000, 'race-ulid', 1000), "
    "(3, 1, 'completion', 3, 2000, NULL, NULL);",
  );
  // Stored balance reflects the double-credit (10 + 10 + 3 = 23) — the
  // exact stale value the migration must repair to the deduplicated sum
  // (10 + 3 = 13).
  raw.execute(
    'INSERT INTO points_balance (profile_id, balance, updated_at) VALUES '
    '(1, 23, 1000);',
  );

  // Profile 2 — no duplicates. Must survive untouched: same row count, same
  // balance, same updated_at (no spurious re-derivation).
  raw.execute(
    'INSERT INTO points_ledger '
    '(id, profile_id, entry_kind, delta, created_at, ulid, sync_enqueued_at) '
    'VALUES '
    "(4, 2, 'completion', 5, 3000, 'clean-ulid', 3000);",
  );
  raw.execute(
    'INSERT INTO points_balance (profile_id, balance, updated_at) VALUES '
    '(2, 5, 3000);',
  );

  // reward_redemptions — profile 1 has a duplicate ulid pair: an older
  // 'pending_fulfilment' row and a newer 'fulfilled' row. LWW must keep the
  // newer one.
  raw.execute(
    'INSERT INTO reward_redemptions '
    '(id, profile_id, reward_title, icon_index, points_cost, status, '
    'created_at, updated_at, ulid) VALUES '
    "(1, 1, 'Ice cream', 0, 20, 'pending_fulfilment', 1000, 1000, 'redeem-ulid'), "
    "(2, 1, 'Ice cream', 0, 20, 'fulfilled', 1000, 5000, 'redeem-ulid');",
  );

  // Stamp the schema version so Drift runs onUpgrade(33 → 34) — and ONLY
  // that block — when the live UserDatabase opens against this database.
  raw.execute('PRAGMA user_version = 33');
}

void main() {
  test('v33 → v34 collapses duplicate (profile_id, ulid) rows to one, repairs '
      'the double-credited balance, leaves untouched profiles/NULL-ulid rows '
      'alone, and enforces the new UNIQUE indexes going forward', () async {
    final raw = sqlite3.openInMemory();
    _buildV33Schema(raw);

    final db = UserDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    // ── points_ledger dedup (profile 1) ──────────────────────────────
    final profile1Ledger = await db
        .customSelect(
          'SELECT id, delta, ulid FROM points_ledger '
          'WHERE profile_id = 1 ORDER BY id',
        )
        .get();
    expect(
      profile1Ledger.length,
      2,
      reason:
          'the duplicate race-ulid pair collapses to one row; the '
          'NULL-ulid row is untouched',
    );
    expect(
      profile1Ledger[0].data['id'],
      1,
      reason: 'the lower id of the duplicate pair is kept',
    );
    expect(profile1Ledger[0].data['ulid'], 'race-ulid');
    expect(profile1Ledger[1].data['id'], 3);
    expect(profile1Ledger[1].data['ulid'], isNull);

    // ── balance repair (profile 1) ───────────────────────────────────
    final profile1Balance = await db
        .customSelect('SELECT balance FROM points_balance WHERE profile_id = 1')
        .getSingle();
    expect(
      profile1Balance.data['balance'],
      13,
      reason:
          'stale double-credited balance (23) repaired to the '
          'deduplicated ledger sum (10 + 3)',
    );

    // ── untouched profile (profile 2) ────────────────────────────────
    final profile2Ledger = await db
        .customSelect('SELECT id FROM points_ledger WHERE profile_id = 2')
        .get();
    expect(
      profile2Ledger.length,
      1,
      reason: 'profile 2 had no duplicates — its ledger is untouched',
    );
    final profile2Balance = await db
        .customSelect(
          'SELECT balance, updated_at FROM points_balance '
          'WHERE profile_id = 2',
        )
        .getSingle();
    expect(
      profile2Balance.data['balance'],
      5,
      reason: 'profile 2 balance is not re-derived (no duplicate removed)',
    );
    expect(
      profile2Balance.data['updated_at'],
      3000,
      reason: 'profile 2 balance row is not touched at all by the migration',
    );

    // ── reward_redemptions LWW dedup ─────────────────────────────────
    final redemptions = await db
        .customSelect(
          'SELECT id, status FROM reward_redemptions WHERE profile_id = 1',
        )
        .get();
    expect(
      redemptions.length,
      1,
      reason: 'the duplicate redeem-ulid pair collapses to one row',
    );
    expect(
      redemptions.single.data['status'],
      'fulfilled',
      reason: 'LWW keeps the row with the newer updated_at',
    );

    // ── UNIQUE indexes exist and are enforced going forward ──────────
    final indexNames =
        (await db
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type = 'index' "
                  "AND name IN ('points_ledger_profile_ulid', "
                  "'reward_redemptions_profile_ulid')",
                )
                .get())
            .map((r) => r.data['name'])
            .toSet();
    expect(indexNames, {
      'points_ledger_profile_ulid',
      'reward_redemptions_profile_ulid',
    });

    await expectLater(
      db
          .into(db.pointsLedger)
          .insert(
            PointsLedgerCompanion.insert(
              profileId: 1,
              entryKind: 'completion',
              delta: 1,
              createdAt: DateTime.utc(2026, 1, 1),
              ulid: const Value('race-ulid'),
            ),
          ),
      throwsException,
      reason:
          'the UNIQUE(profile_id, ulid) index now rejects a fresh '
          'duplicate insert outright',
    );
  });
}
