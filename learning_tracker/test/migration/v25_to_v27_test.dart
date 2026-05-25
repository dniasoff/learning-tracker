/// R5o migration gate — schema v25 → v27 (the riskiest migration).
///
/// Background (Opus review R5o-C1): the original v26 step destroyed data.
/// It ran `m.deleteTable('learner_profiles')` + `createTable(...)` (and the
/// same for `accounts`). Because `PRAGMA foreign_keys` is OFF during
/// `onUpgrade`, the DROP did NOT cascade — but it DID empty the profile table
/// and reset AUTOINCREMENT, orphaning every child row that FK-references
/// `learner_profiles(id)`.
///
/// The v26 step now uses a row-preserving rebuild (Drift `TableMigration` /
/// the SQLite table-rebuild recipe) that:
///   - adds the CHECK (mode IN ('adult','child')) constraint to
///     learner_profiles.mode,
///   - drops the vestigial accounts.user_mode column,
///   - PRESERVES all rows + ids so child FKs stay valid.
///
/// v27 then adds nullable `ulid` columns to points_ledger and
/// reward_redemptions (Wave-B points-sync prep — additive, safe).
///
/// This test builds a real v25-shaped DB (raw SQL, user_version = 25),
/// populates accounts + learner_profiles + several FK'd child tables, opens
/// the live `UserDatabase` (triggering onUpgrade 25→27), then asserts:
///   1. every profile + child row is PRESERVED (counts + key fields),
///   2. no child row is orphaned (`PRAGMA foreign_key_check` is empty),
///   3. `accounts.user_mode` is gone,
///   4. the `mode` CHECK constraint is enforced,
///   5. the new `ulid` columns exist on points_ledger + reward_redemptions.
@Tags(['migration'])
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:sqlite3/sqlite3.dart';

/// Builds a v25-shaped database (the pre-v26 schema) directly on [raw] using
/// raw SQL, then stamps `user_version = 25` so Drift runs onUpgrade(25 → 27)
/// when [UserDatabase] opens against the same underlying database.
///
/// Only the tables exercised by this test are created. The FK'd child tables
/// declare `ON DELETE CASCADE` to `learner_profiles(id)` exactly as in
/// production, so a broken (drop-based) v26 migration would orphan or destroy
/// their rows.
void _buildV25Schema(Database raw) {
  // ── accounts (v25 shape: still has user_mode) ──────────────────────────────
  raw.execute('''
    CREATE TABLE accounts (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      email TEXT NOT NULL UNIQUE,
      firebase_uid TEXT UNIQUE,
      password_hash TEXT,
      tier TEXT NOT NULL,
      display_name TEXT NOT NULL,
      user_mode TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
  ''');

  // ── learner_profiles (v25 shape: free-text mode, NO check constraint) ──────
  raw.execute('''
    CREATE TABLE learner_profiles (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      account_id INTEGER NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
      display_name TEXT NOT NULL,
      mode TEXT NOT NULL,
      avatar_index INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
  ''');

  // ── curriculum_tracks (needed for goals.track_id FK) ───────────────────────
  raw.execute('''
    CREATE TABLE curriculum_tracks (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      profile_id INTEGER NOT NULL REFERENCES learner_profiles (id) ON DELETE CASCADE,
      curriculum_id TEXT NOT NULL,
      state TEXT NOT NULL DEFAULT 'active',
      state_changed_at INTEGER NOT NULL,
      activated_at INTEGER NOT NULL,
      chazara_enabled INTEGER NOT NULL DEFAULT 0
    );
  ''');

  // ── completion_events (FK'd child) ─────────────────────────────────────────
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
      created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER)),
      purged_at INTEGER
    );
  ''');

  // ── goals (FK'd child) ─────────────────────────────────────────────────────
  raw.execute('''
    CREATE TABLE goals (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      profile_id INTEGER NOT NULL REFERENCES learner_profiles (id) ON DELETE CASCADE,
      curriculum_id TEXT NOT NULL,
      track_id INTEGER NOT NULL REFERENCES curriculum_tracks (id),
      target_percent REAL NOT NULL DEFAULT 100.0,
      target_date INTEGER,
      description TEXT NOT NULL DEFAULT '',
      date_type TEXT NOT NULL DEFAULT 'gregorian',
      goal_type TEXT NOT NULL DEFAULT 'deadline',
      pace_value INTEGER,
      pace_period TEXT,
      pace_granularity TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
  ''');

  // ── streak_events (FK'd child) ─────────────────────────────────────────────
  raw.execute('''
    CREATE TABLE streak_events (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      profile_id INTEGER NOT NULL REFERENCES learner_profiles (id) ON DELETE CASCADE,
      event_type TEXT NOT NULL,
      day_utc INTEGER NOT NULL,
      event_timestamp INTEGER NOT NULL,
      client_device_id TEXT,
      created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER))
    );
  ''');

  // ── points_balance (FK'd child, v25) ───────────────────────────────────────
  raw.execute('''
    CREATE TABLE points_balance (
      profile_id INTEGER NOT NULL PRIMARY KEY REFERENCES learner_profiles (id) ON DELETE CASCADE,
      balance INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL
    );
  ''');

  // ── points_ledger (FK'd child, v25 — NO ulid yet) ──────────────────────────
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

  // ── reward_redemptions (FK'd child, v25 — has updated_at, NO ulid yet) ──────
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

  raw.execute('PRAGMA user_version = 25');
}

/// Populates the v25 DB with one account, two profiles, and child rows under
/// the FIRST profile, plus a SECOND account/profile so we can prove ids are
/// preserved (not collapsed/reassigned by an AUTOINCREMENT reset).
void _seedV25Data(Database raw) {
  const ts = 1700000000; // arbitrary epoch-seconds stamp

  raw.execute(
    'INSERT INTO accounts (id, email, tier, display_name, user_mode, '
    'created_at, updated_at) VALUES '
    "(1, 'a@example.com', 'localBorn', 'Account One', 'adult', $ts, $ts),"
    "(2, 'b@example.com', 'localBorn', 'Account Two', 'child', $ts, $ts)",
  );

  raw.execute(
    'INSERT INTO learner_profiles (id, account_id, display_name, mode, '
    'avatar_index, created_at, updated_at) VALUES '
    "(1, 1, 'Adult P', 'adult', 0, $ts, $ts),"
    "(2, 1, 'Child P', 'child', 3, $ts, $ts),"
    "(5, 2, 'Child Q', 'child', 7, $ts, $ts)", // non-contiguous id (gap) on purpose
  );

  raw.execute(
    'INSERT INTO curriculum_tracks (id, profile_id, curriculum_id, '
    'state_changed_at, activated_at) VALUES '
    "(1, 2, 'mishnayos', $ts, $ts)",
  );

  // Child rows belonging to profile 2 (the child) and 5 (Child Q).
  raw.execute(
    'INSERT INTO completion_events (id, profile_id, curriculum_id, sefaria_ref, '
    'stage_id, track_type, event_timestamp) VALUES '
    "(1, 2, 'mishnayos', 'Berakhot 1:1', 1, 'daily', $ts),"
    "(2, 2, 'mishnayos', 'Berakhot 1:2', 1, 'daily', $ts),"
    "(3, 5, 'mishnayos', 'Peah 1:1', 1, 'daily', $ts)",
  );

  raw.execute(
    'INSERT INTO goals (id, profile_id, curriculum_id, track_id, created_at, '
    'updated_at) VALUES (1, 2, \'mishnayos\', 1, $ts, $ts)',
  );

  raw.execute(
    'INSERT INTO streak_events (id, profile_id, event_type, day_utc, '
    'event_timestamp) VALUES '
    "(1, 2, 'completion', $ts, $ts),"
    "(2, 5, 'completion', $ts, $ts)",
  );

  raw.execute(
    'INSERT INTO points_balance (profile_id, balance, updated_at) VALUES '
    '(2, 42, $ts), (5, 7, $ts)',
  );

  raw.execute(
    'INSERT INTO points_ledger (id, profile_id, entry_kind, delta, created_at) '
    'VALUES '
    "(1, 2, 'completion', 10, $ts),"
    "(2, 2, 'completion', 32, $ts),"
    "(3, 5, 'completion', 7, $ts)",
  );

  raw.execute(
    'INSERT INTO reward_redemptions (id, profile_id, reward_title, '
    'points_cost, created_at, updated_at) VALUES '
    "(1, 2, 'Ice cream', 20, $ts, $ts)",
  );
}

void main() {
  group('v25→v27: row-preserving rebuild + additive ulid columns', () {
    late Database raw;
    late UserDatabase db;

    setUp(() async {
      // Single in-memory sqlite3 handle shared between the raw v25 setup and
      // the live UserDatabase, so onUpgrade runs against our seeded data.
      raw = sqlite3.openInMemory();
      _buildV25Schema(raw);
      _seedV25Data(raw);

      db = UserDatabase(NativeDatabase.opened(raw));
      // Force the migration to run by issuing a query.
      await db.customSelect('SELECT 1').get();
    });

    tearDown(() async {
      await db.close();
    });

    test('schemaVersion is 27 after migration', () async {
      final row = await db.customSelect('PRAGMA user_version').getSingle();
      expect(row.data.values.first, 27);
    });

    test('all learner_profiles are preserved with ids intact', () async {
      final profiles = await db.select(db.learnerProfiles).get();
      expect(
        profiles.map((p) => p.id).toList()..sort(),
        [1, 2, 5],
        reason:
            'R5o-C1: every profile must survive the v26 rebuild WITH its '
            'original id (the old drop-based migration emptied the table and '
            'reset AUTOINCREMENT, orphaning all child rows)',
      );
      final child = profiles.firstWhere((p) => p.id == 5);
      expect(child.displayName, 'Child Q');
      expect(child.mode, 'child');
      expect(child.avatarIndex, 7);
    });

    test('all FK\'d child rows are preserved (counts + key fields)', () async {
      expect(await db.select(db.completionEvents).get(), hasLength(3));
      expect(await db.select(db.goals).get(), hasLength(1));
      expect(await db.select(db.streakEvents).get(), hasLength(2));
      expect(await db.select(db.pointsBalance).get(), hasLength(2));
      expect(await db.select(db.pointsLedger).get(), hasLength(3));
      expect(await db.select(db.rewardRedemptions).get(), hasLength(1));

      // Key fields survive.
      final balances = await db.select(db.pointsBalance).get();
      expect(
        {for (final b in balances) b.profileId: b.balance},
        {2: 42, 5: 7},
      );
      final ledger = await db.select(db.pointsLedger).get();
      expect(ledger.map((l) => l.delta).toList()..sort(), [7, 10, 32]);
    });

    test('no child row is orphaned (foreign_key_check is empty)', () async {
      // Enforcement is back ON after migration (beforeOpen + v26 step).
      final violations = await db.customSelect('PRAGMA foreign_key_check').get();
      expect(
        violations,
        isEmpty,
        reason:
            'R5o-C1: child rows must still point at valid learner_profiles '
            'ids after the rebuild',
      );
    });

    test('accounts.user_mode column is gone', () async {
      final cols = await db
          .customSelect("PRAGMA table_info('accounts')")
          .get();
      final names = cols.map((r) => r.data['name'] as String).toList();
      expect(names, isNot(contains('user_mode')));
      expect(names, contains('email'));
      expect(names, contains('tier'));
    });

    test('learner_profiles.mode CHECK constraint is enforced', () async {
      // A bogus mode must be rejected by the new CHECK (mode IN ...) constraint.
      expect(
        () => db.customStatement(
          'INSERT INTO learner_profiles (account_id, display_name, mode, '
          "created_at, updated_at) VALUES (1, 'Bad', 'wizard', 0, 0)",
        ),
        throwsA(isA<Exception>()),
        reason: 'R5o: v26 must add CHECK (mode IN (\'adult\',\'child\'))',
      );
    });

    test('points_ledger + reward_redemptions gain a nullable ulid column', () async {
      final ledgerCols = await db
          .customSelect("PRAGMA table_info('points_ledger')")
          .get();
      expect(
        ledgerCols.map((r) => r.data['name'] as String),
        contains('ulid'),
      );

      final redemptionCols = await db
          .customSelect("PRAGMA table_info('reward_redemptions')")
          .get();
      final redemptionNames =
          redemptionCols.map((r) => r.data['name'] as String).toList();
      expect(redemptionNames, contains('ulid'));
      // LWW field for reward_redemptions must exist.
      expect(redemptionNames, contains('updated_at'));

      // Existing rows have NULL ulid (additive, no backfill in this slice).
      final existing = await db.select(db.pointsLedger).get();
      expect(existing.every((l) => l.ulid == null), isTrue);
    });
  });
}
