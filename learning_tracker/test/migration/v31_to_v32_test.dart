/// Migration gate — schema v31 → v32 (composite synthetic-container cleanup).
///
/// Tanach is a COMPOSITE curriculum assembled at runtime from Chumash + Nach,
/// with the Chumash books re-parented under a SYNTHETIC level1 section container
/// 'Torah' that exists in no real curriculum. A lifetime mark recorded directly
/// against that synthetic container —
/// `curriculum_id='tanach', entry_scope='level1', unit_identifier='Torah'` —
/// blanket-credited the ENTIRE Torah (all five chumashim) even when the user had
/// only marked a single book. The v32 migration deletes those spurious rows.
///
/// This builds a real v31-shaped DB (raw SQL, user_version = 31), seeds:
///   - the spurious `tanach/level1/'Torah'` row (must be deleted),
///   - an `unmark_level1` Torah row on tanach (also synthetic — must be deleted),
///   - legitimate rows that MUST survive: a Tanach deeper-scope mark
///     ('Torah|Genesis'), a real `chumash/level1/'Genesis'` mark, and a
///     non-composite curriculum mark.
/// Then opens the live [UserDatabase] (triggering onUpgrade 31→32) and asserts
/// only the synthetic-container rows are gone.
@Tags(['migration'])
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:sqlite3/sqlite3.dart';

void _buildV31Schema(Database raw) {
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

  // learning_ledger — v31 shape (matches lib/core/database/tables/learning_ledger.dart).
  raw.execute('''
    CREATE TABLE learning_ledger (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      profile_id INTEGER NOT NULL REFERENCES learner_profiles (id) ON DELETE CASCADE,
      ulid TEXT NOT NULL,
      curriculum_id TEXT NOT NULL,
      entry_scope TEXT NOT NULL,
      unit_identifier TEXT NOT NULL,
      unit_display_name_he TEXT NOT NULL,
      unit_display_name_en TEXT NOT NULL,
      track_type TEXT NOT NULL,
      track_id INTEGER,
      completed_at INTEGER NOT NULL,
      completion_number INTEGER NOT NULL,
      marked_by INTEGER NOT NULL,
      is_manual INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL DEFAULT 0
    );
  ''');

  raw.execute(
    'INSERT INTO accounts (id, email, tier, display_name, created_at, updated_at) '
    "VALUES (1, 'a@example.com', 'localBorn', 'Account', 0, 0);",
  );
  raw.execute(
    'INSERT INTO learner_profiles (id, account_id, display_name, mode, created_at, updated_at) '
    "VALUES (1, 1, 'Loop', 'child', 0, 0);",
  );

  void insert(int id, String curriculum, String scope, String unit) {
    raw.execute(
      'INSERT INTO learning_ledger '
      '(id, profile_id, ulid, curriculum_id, entry_scope, unit_identifier, '
      'unit_display_name_he, unit_display_name_en, track_type, completed_at, '
      'completion_number, marked_by, is_manual, created_at) VALUES '
      "($id, 1, 'ulid$id', '$curriculum', '$scope', '$unit', '', '', "
      "'personal', 0, 1, 1, 1, 0);",
    );
  }

  // SPURIOUS — must be deleted by v32.
  insert(1, 'tanach', 'level1', 'Torah');
  insert(2, 'tanach', 'unmark_level1', 'Torah');

  // LEGITIMATE — must survive.
  insert(3, 'tanach', 'level2', 'Torah|Genesis'); // a real book mark via Tanach
  insert(4, 'chumash', 'level1', 'Genesis'); // standalone Chumash book mark
  insert(5, 'bavli', 'level1', 'Moed'); // unrelated curriculum seder mark

  // Stamp the schema version so Drift runs onUpgrade(31 → 32) — and ONLY that
  // block — when the live UserDatabase opens against this database.
  raw.execute('PRAGMA user_version = 31');
}

void main() {
  test('v31 → v32 deletes only tanach synthetic-container (level1 Torah) rows; '
      'real book/seder marks survive', () async {
    final raw = sqlite3.openInMemory();
    _buildV31Schema(raw);

    final db = UserDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          'SELECT id, curriculum_id, entry_scope, unit_identifier '
          'FROM learning_ledger ORDER BY id',
        )
        .get();

    final ids = rows.map((r) => r.data['id'] as int).toSet();

    // Synthetic-container rows gone.
    expect(ids.contains(1), isFalse, reason: 'tanach level1 Torah deleted');
    expect(
      ids.contains(2),
      isFalse,
      reason: 'tanach unmark_level1 Torah deleted',
    );

    // Legitimate rows preserved.
    expect(ids.contains(3), isTrue, reason: 'tanach level2 book mark survives');
    expect(
      ids.contains(4),
      isTrue,
      reason: 'chumash level1 book mark survives',
    );
    expect(ids.contains(5), isTrue, reason: 'bavli level1 seder mark survives');
    expect(rows.length, 3);
  });
}
