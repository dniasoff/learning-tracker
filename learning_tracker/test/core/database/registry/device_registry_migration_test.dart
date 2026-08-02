/// Migration gate — device registry schema v1 → v2 (Phase 1 Story B,
/// AD-24: persisted path-uid with anon-reset remap).
///
/// Before v2, `device_accounts` had no way to record that a remap had
/// happened: `firebaseUid` was overwritten in place with no breadcrumb of
/// what it used to be. v2 adds two nullable, additive columns —
/// `previous_firebase_uid` and `uid_remapped_at` — that
/// [PathUidResolver.reconcileLiveUid] uses to record the AD-19 anon-reset
/// remap so the event is diagnosable and the downstream Firestore data layer
/// can find accounts with a stranded pre-remap document tree.
///
/// This builds a real v1-shaped registry DB (raw SQL, `user_version = 1`,
/// matching `device_accounts.dart`/`device_state.dart` as they existed
/// before this story) with one pre-existing cloud-born account row, then
/// opens the live [DeviceRegistryDatabase] against it so the real
/// `onUpgrade(1, 2)` runs.
@Tags(['migration'])
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/registry/path_uid_resolver.dart';
import 'package:sqlite3/sqlite3.dart';

void _buildV1Schema(Database raw) {
  raw.execute('''
    CREATE TABLE device_accounts (
      account_id TEXT NOT NULL,
      email TEXT NOT NULL,
      display_name TEXT NOT NULL,
      tier TEXT NOT NULL,
      firebase_uid TEXT,
      avatar_index INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      last_used_at INTEGER NOT NULL,
      db_file_name TEXT NOT NULL UNIQUE,
      PRIMARY KEY (account_id)
    );
  ''');

  raw.execute('''
    CREATE TABLE device_state (
      "key" TEXT NOT NULL,
      value TEXT,
      PRIMARY KEY ("key")
    );
  ''');

  raw.execute(
    'INSERT INTO device_accounts '
    '(account_id, email, display_name, tier, firebase_uid, created_at, '
    'last_used_at, db_file_name) '
    "VALUES ('acc1', 'alice@example.com', 'Alice', 'cloudBorn', "
    "'uid-pre-existing', 0, 0, 'user_acc_acc1.db');",
  );

  // A pre-existing local-born row (null firebaseUid) — must survive the
  // upgrade untouched and stay ready for AD-19 Phase 4's Anonymous Auth
  // bind with no further schema change.
  raw.execute(
    'INSERT INTO device_accounts '
    '(account_id, email, display_name, tier, firebase_uid, created_at, '
    'last_used_at, db_file_name) '
    "VALUES ('acc2', 'local@offline.local', 'Local Kid', 'localBorn', NULL, "
    "0, 0, 'user_acc_acc2.db');",
  );

  // Stamp the schema version so Drift runs onUpgrade(1 → 2) — and only that
  // block — when the live DeviceRegistryDatabase opens against this DB.
  raw.execute('PRAGMA user_version = 1');
}

void main() {
  test('v1 → v2 adds previous_firebase_uid + uid_remapped_at without losing '
      'existing rows', () async {
    final raw = sqlite3.openInMemory();
    _buildV1Schema(raw);

    final db = DeviceRegistryDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    // Existing rows survive, with the new columns defaulting to NULL.
    final rows =
        (await db
                .customSelect(
                  'SELECT account_id, firebase_uid, previous_firebase_uid, '
                  'uid_remapped_at FROM device_accounts ORDER BY account_id',
                )
                .get())
            .map((r) => r.data)
            .toList();

    expect(rows, hasLength(2), reason: 'no row is dropped by the migration');

    expect(rows[0]['account_id'], 'acc1');
    expect(
      rows[0]['firebase_uid'],
      'uid-pre-existing',
      reason:
          'the migration only adds columns — it never rewrites '
          'firebase_uid',
    );
    expect(rows[0]['previous_firebase_uid'], isNull);
    expect(rows[0]['uid_remapped_at'], isNull);

    expect(rows[1]['account_id'], 'acc2');
    expect(rows[1]['firebase_uid'], isNull);
    expect(rows[1]['previous_firebase_uid'], isNull);
    expect(rows[1]['uid_remapped_at'], isNull);

    // The new columns are real and usable going forward through the DAO
    // API a fresh v2 install would use (PathUidResolver.writePathUid).
    await db.writePathUid(
      'acc1',
      uid: 'uid-new',
      previousFirebaseUid: 'uid-pre-existing',
      remappedAt: DateTime.utc(2026, 8, 2),
    );
    final acc1 = await db.findById('acc1');
    expect(acc1!.firebaseUid, 'uid-new');
    expect(acc1.previousFirebaseUid, 'uid-pre-existing');
    // Drift round-trips DateTime via epoch millis and reads it back with
    // `isUtc == false` (local-flagged) even though a UTC instant was
    // written — same moment, different flag — so compare moments, not `==`
    // (which also compares the isUtc flag).
    expect(
      acc1.uidRemappedAt!.isAtSameMomentAs(DateTime.utc(2026, 8, 2)),
      isTrue,
    );
  });

  test(
    'PathUidResolver works against a freshly-upgraded v1→v2 database',
    () async {
      final raw = sqlite3.openInMemory();
      _buildV1Schema(raw);
      final db = DeviceRegistryDatabase(NativeDatabase.opened(raw));
      addTearDown(db.close);

      final resolver = PathUidResolver(db);
      final result = await resolver.reconcileLiveUid(
        accountId: 'acc1',
        liveUid: 'uid-after-reset',
      );

      expect(result.isRemap, isTrue);
      expect(result.previousUid, 'uid-pre-existing');
      expect(await resolver.pathUidFor('acc1'), 'uid-after-reset');
    },
  );
}
