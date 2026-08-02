/// Migration gate — schema v37 → v38 (Firestore-rewrite transition: additive
/// nullable `ulid` column on `learner_profiles`).
///
/// Before v38, a Drift `learner_profiles` row had no way to record its
/// paired Firestore `learner_profiles/{ulid}` doc-id — see
/// `lib/core/database/tables/learner_profiles.dart`'s `ulid` column doc
/// comment and `FirestoreProfileRepositoryAdapter`'s class doc comment
/// (`lib/features/profiles/data/repositories/profile_repository_impl.dart`)
/// for the full "why a column, why nullable, why deleted with the Drift
/// user database" reasoning.
///
/// This builds a real v37-shaped `learner_profiles`/`accounts` pair (raw
/// SQL, `user_version = 37`) with one pre-existing profile, verifies the
/// migration adds the nullable `ulid` column WITHOUT touching any existing
/// row (pre-existing profiles stay `ulid IS NULL` — "not yet migrated to
/// Firestore", never "no profile" — no eager backfill happens at migration
/// time), and that the column is usable going forward (write + read back).
@Tags(['migration'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:sqlite3/sqlite3.dart';

void _buildV37Schema(Database raw) {
  // Mirrors the FULL current shape of these two tables (unchanged since
  // schema v28 for learner_profiles) — this migration only touches
  // learner_profiles, so no other table needs modelling here (Drift's
  // `onUpgrade` only runs the `if (from < 38)` block when `from == 37`,
  // same reasoning the v36→v37 gate documents for its own narrower schema).
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
      tutor_remote_profile_id TEXT,
      tutor_grant_id TEXT
    );
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

  // Stamp the schema version so Drift runs onUpgrade(37 → 38) — and ONLY
  // that block — when the live UserDatabase opens against this database.
  raw.execute('PRAGMA user_version = 37');
}

void main() {
  test(
    'v37 → v38 adds a nullable ulid column to learner_profiles without '
    'touching any pre-existing row (no eager backfill at migration time)',
    () async {
      final raw = sqlite3.openInMemory();
      _buildV37Schema(raw);

      final db = UserDatabase(NativeDatabase.opened(raw));
      addTearDown(db.close);

      final rows = await db.select(db.learnerProfiles).get();
      expect(rows, hasLength(1), reason: 'no row is dropped by the migration');
      expect(rows.single.id, 1);
      expect(rows.single.displayName, 'Learner One');
      expect(
        rows.single.ulid,
        isNull,
        reason:
            'a pre-existing profile is "not yet migrated to Firestore", '
            'never "no profile" — this migration only adds the column, it '
            'does not mint or invent an identity for rows that already '
            'exist (see FirestoreProfileRepositoryAdapter\'s lazy-backfill '
            'policy for what eventually fills this in)',
      );

      // ── column is real and usable going forward ───────────────────────
      await db
          .into(db.learnerProfiles)
          .insert(
            LearnerProfilesCompanion.insert(
              accountId: 1,
              displayName: 'Learner Two',
              mode: 'adult',
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
              ulid: const Value('01HZZZ000000000000000002'),
            ),
          );
      final newRow = await (db.select(
        db.learnerProfiles,
      )..where((t) => t.displayName.equals('Learner Two'))).getSingle();
      expect(newRow.ulid, '01HZZZ000000000000000002');

      // The pre-existing row's ulid can also be written after the fact —
      // the lazy-backfill-on-edit path this migration exists to support.
      await (db.update(db.learnerProfiles)..where((t) => t.id.equals(1))).write(
        const LearnerProfilesCompanion(ulid: Value('01HZZZ000000000000000001')),
      );
      final backfilled = await (db.select(
        db.learnerProfiles,
      )..where((t) => t.id.equals(1))).getSingle();
      expect(backfilled.ulid, '01HZZZ000000000000000001');
    },
  );
}
