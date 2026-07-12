/// Migration gate — schema v34 → v35 (AUD-core-database-09:
/// points_ledger.redemptionId comment-only FK gap closure).
///
/// Before v35, `points_ledger.redemptionId` was documented as "FK to
/// RewardRedemptions.id" in a doc comment only — nothing at the DB layer
/// stopped it from pointing at a nonexistent (or wrong-profile) redemption
/// row. The v35 migration declares a real
/// `.references(RewardRedemptions, #id, onDelete: KeyAction.restrict)` on
/// the column. SQLite cannot ALTER TABLE an existing column to add a
/// REFERENCES clause, so the migration rebuilds `points_ledger` via
/// `TableMigration` (the same recipe v26/v34 use) — which must first null
/// out any pre-existing bogus `redemptionId` (the exact gap this migration
/// closes could already have let one in), or the rebuild's
/// `PRAGMA foreign_key_check` would trip on stale data.
///
/// This builds a real v34-shaped DB (raw SQL, `user_version = 34`) with:
///   - a `points_ledger` row whose `redemption_id` points at a
///     `reward_redemptions` row that does not exist (the bogus reference
///     the old comment-only "FK" allowed),
///   - a `points_ledger` row whose `redemption_id` is `NULL` (must survive
///     untouched),
///   - a `points_ledger` row whose `redemption_id` legitimately points at a
///     real `reward_redemptions` row (must survive untouched),
///   - the pre-existing `points_ledger_profile_ulid` UNIQUE index (v34),
///     which must still exist and still be enforced after the rebuild.
///
/// Then opens the live [UserDatabase] (triggering onUpgrade 34→35) and
/// asserts: the bogus reference is nulled out, the NULL and legitimate rows
/// are untouched, the pre-existing UNIQUE index survives the table rebuild,
/// and the new FK is enforced going forward (a fresh bogus insert throws).
@Tags(['migration'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:sqlite3/sqlite3.dart';

void _buildV34Schema(Database raw) {
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

  // points_ledger — v34 shape: has the points_ledger_profile_ulid UNIQUE
  // index but redemption_id is still a bare, unconstrained column (that's
  // exactly the v35 migration).
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
    CREATE UNIQUE INDEX points_ledger_profile_ulid
      ON points_ledger (profile_id, ulid);
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
  raw.execute('''
    CREATE UNIQUE INDEX reward_redemptions_profile_ulid
      ON reward_redemptions (profile_id, ulid);
  ''');

  raw.execute(
    'INSERT INTO accounts (id, email, tier, display_name, created_at, updated_at) '
    "VALUES (1, 'a@example.com', 'localBorn', 'Account', 0, 0);",
  );
  raw.execute(
    'INSERT INTO learner_profiles '
    '(id, account_id, display_name, mode, created_at, updated_at) '
    "VALUES (1, 1, 'Learner', 'child', 0, 0);",
  );

  // A real redemption row (id 1) that a legitimate ledger row may reference.
  raw.execute(
    'INSERT INTO reward_redemptions '
    '(id, profile_id, reward_title, icon_index, points_cost, status, '
    'created_at, updated_at, ulid) VALUES '
    "(1, 1, 'Ice cream', 0, 20, 'pending_fulfilment', 1000, 1000, 'redeem-ulid-1');",
  );

  // Row 1 — the gap this migration closes: redemption_id points at id 999,
  // which does not exist in reward_redemptions. The old comment-only "FK"
  // let this insert through silently.
  //
  // Row 2 — NULL redemption_id (a completion credit). Must be left alone.
  //
  // Row 3 — a legitimate reference to the real redemption (id 1). Must be
  // left alone.
  raw.execute(
    'INSERT INTO points_ledger '
    '(id, profile_id, entry_kind, delta, redemption_id, created_at, ulid) '
    'VALUES '
    "(1, 1, 'redemption_debit', -5, 999, 1000, 'bogus-ulid'), "
    "(2, 1, 'completion', 10, NULL, 2000, 'completion-ulid'), "
    "(3, 1, 'redemption_debit', -20, 1, 3000, 'legit-ulid');",
  );

  // Stamp the schema version so Drift runs onUpgrade(34 → 35) — and ONLY
  // that block — when the live UserDatabase opens against this database.
  raw.execute('PRAGMA user_version = 34');
}

void main() {
  test('v34 → v35 nulls out a bogus redemptionId, leaves NULL/legitimate '
      'rows alone, preserves the pre-existing UNIQUE index, and enforces '
      'the new FK going forward', () async {
    final raw = sqlite3.openInMemory();
    _buildV34Schema(raw);

    final db = UserDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    // ── bogus reference nulled out ───────────────────────────────────
    final rows =
        (await db
                .customSelect(
                  'SELECT id, redemption_id, ulid FROM points_ledger ORDER BY id',
                )
                .get())
            .map((r) => r.data)
            .toList();
    expect(rows, hasLength(3), reason: 'the rebuild drops no rows');

    expect(rows[0]['id'], 1);
    expect(
      rows[0]['redemption_id'],
      isNull,
      reason:
          'row 1 pointed at a nonexistent reward_redemptions row (999) — '
          'the migration must null it out defensively before the rebuild',
    );

    expect(rows[1]['id'], 2);
    expect(
      rows[1]['redemption_id'],
      isNull,
      reason: 'row 2 was already NULL — left untouched',
    );

    expect(rows[2]['id'], 3);
    expect(
      rows[2]['redemption_id'],
      1,
      reason: 'row 3 legitimately references a real redemption — untouched',
    );

    // ── pre-existing v34 UNIQUE index survives the table rebuild ──────
    final indexNames =
        (await db
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type = 'index' "
                  "AND name = 'points_ledger_profile_ulid'",
                )
                .get())
            .map((r) => r.data['name'])
            .toSet();
    expect(
      indexNames,
      {'points_ledger_profile_ulid'},
      reason:
          'alterTable re-creates indexes/triggers on the rebuilt table '
          '(drift docs) — the v34 UNIQUE(profile_id, ulid) index must not '
          'be silently dropped by the v35 rebuild',
    );
    await expectLater(
      db
          .into(db.pointsLedger)
          .insert(
            PointsLedgerCompanion.insert(
              profileId: 1,
              entryKind: 'completion',
              delta: 1,
              createdAt: DateTime.utc(2026, 1, 1),
              ulid: const Value('completion-ulid'),
            ),
          ),
      throwsException,
      reason:
          'the pre-existing UNIQUE(profile_id, ulid) index must still '
          'reject a duplicate ulid after the v35 rebuild',
    );

    // ── new FK enforced going forward ──────────────────────────────────
    await expectLater(
      db
          .into(db.pointsLedger)
          .insert(
            PointsLedgerCompanion.insert(
              profileId: 1,
              entryKind: 'redemption_debit',
              delta: -1,
              redemptionId: const Value(999999),
              createdAt: DateTime.utc(2026, 1, 1),
            ),
          ),
      throwsException,
      reason:
          'a fresh insert with a bogus redemptionId must now be rejected '
          'by the real FK the v35 migration declared',
    );
  });
}
