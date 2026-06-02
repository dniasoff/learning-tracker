/// Unit tests for [DriftMergeStore] — the concrete LWW merge store backed by
/// Drift DAOs.
///
/// Focus: 78% core MERGE correctness (quality-crisis area). Every test
/// exercises the REAL [DriftMergeStore] against an in-memory SQLite DB; no
/// mocking of the unit under test.
///
/// Coverage:
///   • remoteIsNewer — all five LWW rule branches + clock-skew tie-break
///   • currentUpdatedAt / persistUpdatedAt — round-trip through SyncKv
///   • currentSyncedAt — optional server-timestamp round-trip
///   • upsert(learner_profile) — insert vs update, field precision
///   • upsert(track_config) — insert vs update, malformed skip
///   • upsert(bookmark) — insert, track-not-yet-synced skip, malformed skip
///   • upsert(settings) — replace-all stage semantics, empty-stages skip
///   • upsert(stage_definition) — insert vs update, missing-key skip
///   • upsert(profile_program) — insert vs update
///   • upsert(learning_order) — LWW-guarded insert, older remote skipped
///   • insertIfAbsent(completion) — append-once idempotency
///   • insertIfAbsent(completion) — tombstone resurrection (H2 path)
///   • insertIfAbsent(completion) — malformed row skip (W7.5)
///   • Idempotency — applying the same merge payload twice produces a single row
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:test/test.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Build a fresh in-memory DB, seed an account + profile with id=1, and
/// return both objects. The caller must close the DB in tearDown.
Future<({UserDatabase db, int profileId})> _buildDb() async {
  final db = UserDatabase(NativeDatabase.memory());
  final accountId = await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: 'test@example.com',
          tier: 'localBorn',
          displayName: 'Test User',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
  final profileId = await db
      .into(db.learnerProfiles)
      .insert(
        LearnerProfilesCompanion.insert(
          accountId: accountId,
          displayName: 'Test User',
          mode: 'adult',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
  return (db: db, profileId: profileId);
}

/// Seed a [CurriculumTracks] row and return its id.
Future<int> _seedTrack(
  UserDatabase db, {
  required int profileId,
  String curriculumId = 'mishnayos',
}) {
  return db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          stateChangedAt: DateTime.utc(2026, 1, 1),
          activatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ── remoteIsNewer (pure logic, no DB) ────────────────────────────────────

  group('DriftMergeStore.remoteIsNewer', () {
    // Build a minimal throwaway store purely for the pure-logic method.
    late DriftMergeStore store;
    late UserDatabase db;

    setUp(() async {
      db = UserDatabase(NativeDatabase.memory());
      store = DriftMergeStore(db);
    });
    tearDown(() => db.close());

    // Rule 1 — remote timestamp absent → false
    test('returns false when remoteUpdatedAt is null', () {
      expect(
        store.remoteIsNewer(
          localUpdatedAt: DateTime.utc(2026, 5, 1),
          remoteUpdatedAt: null,
        ),
        isFalse,
      );
    });

    // Rule 2 — no local row yet → true
    test('returns true when localUpdatedAt is null (first sync)', () {
      expect(
        store.remoteIsNewer(
          localUpdatedAt: null,
          remoteUpdatedAt: DateTime.utc(2026, 5, 1),
        ),
        isTrue,
      );
    });

    // Rule 3a — diff > 5 s, remote strictly after local → true
    test(
      'returns true when remote is strictly newer (outside skew window)',
      () {
        expect(
          store.remoteIsNewer(
            localUpdatedAt: DateTime.utc(2026, 5, 1, 0, 0, 0),
            remoteUpdatedAt: DateTime.utc(2026, 5, 1, 0, 0, 10),
          ),
          isTrue,
        );
      },
    );

    // Rule 3b — diff > 5 s, remote strictly before local → false
    test(
      'returns false when remote is strictly older (outside skew window)',
      () {
        expect(
          store.remoteIsNewer(
            localUpdatedAt: DateTime.utc(2026, 5, 1, 0, 0, 10),
            remoteUpdatedAt: DateTime.utc(2026, 5, 1, 0, 0, 0),
          ),
          isFalse,
        );
      },
    );

    // Rule 3c — exact equality (diff = 0, still within window) → falls to
    // rule 5 (prefer remote)
    test('returns true on exact timestamp tie (prefer remote)', () {
      final ts = DateTime.utc(2026, 5, 1, 12, 0, 0);
      expect(
        store.remoteIsNewer(localUpdatedAt: ts, remoteUpdatedAt: ts),
        isTrue,
      );
    });

    // Rule 4 — within ±5 s, remote syncedAt strictly after local syncedAt
    test('within clock-skew window: remote syncedAt after local → true', () {
      final base = DateTime.utc(2026, 5, 1, 12, 0, 0);
      final remoteUpdatedAt = base.add(const Duration(seconds: 3));
      expect(
        store.remoteIsNewer(
          localUpdatedAt: base,
          remoteUpdatedAt: remoteUpdatedAt,
          localSyncedAt: DateTime.utc(2026, 5, 1, 11, 59, 50),
          remoteSyncedAt: DateTime.utc(2026, 5, 1, 12, 0, 1),
        ),
        isTrue,
      );
    });

    // Rule 4 — within ±5 s, local syncedAt strictly after remote syncedAt
    test('within clock-skew window: local syncedAt after remote → false', () {
      final base = DateTime.utc(2026, 5, 1, 12, 0, 0);
      final remoteUpdatedAt = base.add(const Duration(seconds: 3));
      expect(
        store.remoteIsNewer(
          localUpdatedAt: base,
          remoteUpdatedAt: remoteUpdatedAt,
          localSyncedAt: DateTime.utc(2026, 5, 1, 12, 0, 2),
          remoteSyncedAt: DateTime.utc(2026, 5, 1, 11, 59, 50),
        ),
        isFalse,
      );
    });

    // Rule 5 — within ±5 s, no server timestamps → prefer remote
    test('within clock-skew window, no server timestamps → prefers remote', () {
      final base = DateTime.utc(2026, 5, 1, 12, 0, 0);
      final remoteUpdatedAt = base.add(const Duration(seconds: 2));
      expect(
        store.remoteIsNewer(
          localUpdatedAt: base,
          remoteUpdatedAt: remoteUpdatedAt,
        ),
        isTrue,
      );
    });

    // ── D15: a fresh, newer, un-pushed local edit must NOT be clobbered by an
    // OLDER remote inside the 5 s window just because it lacks a synced_at. ──
    test(
      'D15: newer un-pushed local (no syncedAt) beats an OLDER remote within '
      'the window — keep local',
      () {
        final t = DateTime.utc(2026, 5, 1, 12, 0, 3);
        // Local edited at T, never pushed → no synced_at.
        // Remote arrived 3 s EARLIER but has a server timestamp.
        expect(
          store.remoteIsNewer(
            localUpdatedAt: t,
            remoteUpdatedAt: t.subtract(const Duration(seconds: 3)),
            localSyncedAt: null,
            remoteSyncedAt: t,
          ),
          isFalse,
          reason: 'older remote must not overwrite a newer un-pushed local',
        );
      },
    );

    test(
      'D15: within the window with no usable server timestamps, a NEWER remote '
      'still wins',
      () {
        final t = DateTime.utc(2026, 5, 1, 12, 0, 0);
        expect(
          store.remoteIsNewer(
            localUpdatedAt: t,
            remoteUpdatedAt: t.add(const Duration(seconds: 3)),
          ),
          isTrue,
        );
      },
    );

    test(
      'D15: within the window, an OLDER remote (both sides lack syncedAt) does '
      'NOT win',
      () {
        final t = DateTime.utc(2026, 5, 1, 12, 0, 4);
        expect(
          store.remoteIsNewer(
            localUpdatedAt: t,
            remoteUpdatedAt: t.subtract(const Duration(seconds: 4)),
          ),
          isFalse,
        );
      },
    );
  });

  // ── currentUpdatedAt / persistUpdatedAt round-trip ───────────────────────

  group('DriftMergeStore — SyncKv round-trip', () {
    late UserDatabase db;
    late DriftMergeStore store;
    late int profileId;

    setUp(() async {
      final built = await _buildDb();
      db = built.db;
      profileId = built.profileId;
      store = DriftMergeStore(db);
    });
    tearDown(() => db.close());

    test('currentUpdatedAt returns null before any persist', () async {
      final result = await store.currentUpdatedAt(
        kind: EntityKind.bookmark,
        profileId: profileId,
        naturalKey: 'mishnayos',
      );
      expect(result, isNull);
    });

    test(
      'persistUpdatedAt then currentUpdatedAt returns persisted value',
      () async {
        final ts = DateTime.utc(2026, 5, 15, 10, 0, 0);
        await store.persistUpdatedAt(
          kind: EntityKind.bookmark,
          profileId: profileId,
          naturalKey: 'mishnayos',
          updatedAt: ts,
        );
        final result = await store.currentUpdatedAt(
          kind: EntityKind.bookmark,
          profileId: profileId,
          naturalKey: 'mishnayos',
        );
        expect(result, equals(ts));
      },
    );

    test(
      'persistUpdatedAt is idempotent — repeated writes with same ts',
      () async {
        final ts = DateTime.utc(2026, 5, 15, 10, 0, 0);
        await store.persistUpdatedAt(
          kind: EntityKind.bookmark,
          profileId: profileId,
          naturalKey: 'mishnayos',
          updatedAt: ts,
        );
        await store.persistUpdatedAt(
          kind: EntityKind.bookmark,
          profileId: profileId,
          naturalKey: 'mishnayos',
          updatedAt: ts,
        );
        final result = await store.currentUpdatedAt(
          kind: EntityKind.bookmark,
          profileId: profileId,
          naturalKey: 'mishnayos',
        );
        expect(result, equals(ts));
      },
    );

    test('persistUpdatedAt overwrites older with newer value', () async {
      final tsOld = DateTime.utc(2026, 5, 10);
      final tsNew = DateTime.utc(2026, 5, 20);
      await store.persistUpdatedAt(
        kind: EntityKind.trackConfig,
        profileId: profileId,
        naturalKey: 'mishnayos',
        updatedAt: tsOld,
      );
      await store.persistUpdatedAt(
        kind: EntityKind.trackConfig,
        profileId: profileId,
        naturalKey: 'mishnayos',
        updatedAt: tsNew,
      );
      final result = await store.currentUpdatedAt(
        kind: EntityKind.trackConfig,
        profileId: profileId,
        naturalKey: 'mishnayos',
      );
      expect(result, equals(tsNew));
    });

    test('currentSyncedAt returns null before any persist', () async {
      final result = await store.currentSyncedAt(
        kind: EntityKind.bookmark,
        profileId: profileId,
        naturalKey: 'mishnayos',
      );
      expect(result, isNull);
    });

    test('persistUpdatedAt with syncedAt persists server timestamp', () async {
      final updatedAt = DateTime.utc(2026, 5, 15, 10, 0, 0);
      final syncedAt = DateTime.utc(2026, 5, 15, 10, 0, 5);
      await store.persistUpdatedAt(
        kind: EntityKind.learnerProfile,
        profileId: profileId,
        naturalKey: 'profile-1',
        updatedAt: updatedAt,
        syncedAt: syncedAt,
      );
      final resultSyncedAt = await store.currentSyncedAt(
        kind: EntityKind.learnerProfile,
        profileId: profileId,
        naturalKey: 'profile-1',
      );
      expect(resultSyncedAt, equals(syncedAt));
    });

    test(
      '_scopedKey isolates profiles — same naturalKey, different profileId',
      () async {
        final ts1 = DateTime.utc(2026, 5, 10);
        final ts2 = DateTime.utc(2026, 5, 20);
        await store.persistUpdatedAt(
          kind: EntityKind.bookmark,
          profileId: 1,
          naturalKey: 'mishnayos',
          updatedAt: ts1,
        );
        await store.persistUpdatedAt(
          kind: EntityKind.bookmark,
          profileId: 2,
          naturalKey: 'mishnayos',
          updatedAt: ts2,
        );
        final r1 = await store.currentUpdatedAt(
          kind: EntityKind.bookmark,
          profileId: 1,
          naturalKey: 'mishnayos',
        );
        final r2 = await store.currentUpdatedAt(
          kind: EntityKind.bookmark,
          profileId: 2,
          naturalKey: 'mishnayos',
        );
        expect(r1, equals(ts1));
        expect(r2, equals(ts2));
      },
    );
  });

  // ── upsert(learner_profile) ───────────────────────────────────────────────

  group('DriftMergeStore.upsert — learner_profile', () {
    late UserDatabase db;
    late DriftMergeStore store;
    late int accountId;

    setUp(() async {
      db = UserDatabase(NativeDatabase.memory());
      store = DriftMergeStore(db);
      accountId = await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'remote@example.com',
              tier: 'localBorn',
              displayName: 'Remote',
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
    });
    tearDown(() => db.close());

    test(
      'insert: creates a new profile row when no local row exists',
      () async {
        await store.upsert(
          kind: EntityKind.learnerProfile,
          profileId: 99,
          fields: {
            'profile_id': 99,
            'account_id': accountId,
            'display_name': 'Alice',
            'mode': 'child',
            'avatar_index': 3,
            'updated_at': DateTime.utc(2026, 5, 15).toIso8601String(),
            'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
          },
        );

        final row = await db.profileDao.getProfileById(99);
        expect(row, isNotNull);
        expect(row!.displayName, equals('Alice'));
        expect(row.mode, equals('child'));
        expect(row.avatarIndex, equals(3));
      },
    );

    test(
      'update: overwrites display_name, mode, avatarIndex for existing profile',
      () async {
        // Seed an existing profile with id=50.
        await db
            .into(db.learnerProfiles)
            .insert(
              LearnerProfilesCompanion(
                id: const Value(50),
                accountId: Value(accountId),
                displayName: const Value('Bob Original'),
                mode: const Value('adult'),
                createdAt: Value(DateTime.utc(2026, 1, 1)),
                updatedAt: Value(DateTime.utc(2026, 1, 1)),
              ),
            );

        await store.upsert(
          kind: EntityKind.learnerProfile,
          profileId: 50,
          fields: {
            'profile_id': 50,
            'account_id': accountId,
            'display_name': 'Bob Updated',
            'mode': 'child',
            'avatar_index': 5,
            'updated_at': DateTime.utc(2026, 5, 20).toIso8601String(),
          },
        );

        final row = await db.profileDao.getProfileById(50);
        expect(row!.displayName, equals('Bob Updated'));
        expect(row.mode, equals('child'));
        expect(row.avatarIndex, equals(5));
      },
    );

    test(
      'idempotency: upsert same profile twice produces exactly one row',
      () async {
        final fields = {
          'profile_id': 77,
          'account_id': accountId,
          'display_name': 'Carol',
          'mode': 'adult',
          'avatar_index': 1,
          'updated_at': DateTime.utc(2026, 5, 10).toIso8601String(),
          'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
        };
        await store.upsert(
          kind: EntityKind.learnerProfile,
          profileId: 77,
          fields: fields,
        );
        await store.upsert(
          kind: EntityKind.learnerProfile,
          profileId: 77,
          fields: fields,
        );

        final all = await (db.select(
          db.learnerProfiles,
        )..where((t) => t.id.equals(77))).get();
        expect(all, hasLength(1));
      },
    );

    // ── Bug 1 — FK-safe account resolution ───────────────────────────────────

    test('Bug 1: remote account_id != local account id does NOT throw and '
        'remaps the profile onto the single local account', () async {
      // The remote row references account_id=999 (the cloud account id),
      // but the only local account has the autoincrement id minted in setUp.
      // Inserting the profile with 999 verbatim would violate the
      // learner_profiles → accounts FK (SqliteException 787). The merge must
      // remap onto the single local account instead.
      expect(accountId, isNot(equals(999)));

      await store.upsert(
        kind: EntityKind.learnerProfile,
        profileId: 1,
        fields: {
          'profile_id': 1,
          'account_id': 999, // remote id, absent locally
          'display_name': 'Family',
          'mode': 'adult',
          'updated_at': DateTime.utc(2026, 5, 15).toIso8601String(),
          'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
        },
      );

      final row = await db.profileDao.getProfileById(1);
      expect(row, isNotNull);
      expect(row!.displayName, equals('Family'));
      // Remapped onto the existing local account — never the missing 999.
      expect(row.accountId, equals(accountId));
    });

    test(
      'Bug 1: with NO local account, the merge seeds a placeholder account so '
      'the FK holds instead of crashing',
      () async {
        // Fresh DB with zero accounts — reproduces the on-device state right
        // after a (re)created account whose accounts row has not landed yet.
        final freshDb = UserDatabase(NativeDatabase.memory());
        addTearDown(freshDb.close);
        final freshStore = DriftMergeStore(freshDb);

        final accountsBefore = await freshDb.userProfileDao
            .getAllUserProfiles();
        expect(accountsBefore, isEmpty);

        await freshStore.upsert(
          kind: EntityKind.learnerProfile,
          profileId: 1,
          fields: {
            'profile_id': 1,
            'account_id': 1,
            'display_name': 'Family',
            'mode': 'adult',
            'updated_at': DateTime.utc(2026, 5, 15).toIso8601String(),
            'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
          },
        );

        final row = await freshDb.profileDao.getProfileById(1);
        expect(row, isNotNull);
        // The seeded account row exists, satisfying the FK.
        final acct = await freshDb.userProfileDao.getUserProfileById(
          row!.accountId,
        );
        expect(acct, isNotNull);
      },
    );
  });

  // ── upsert(track_config) ─────────────────────────────────────────────────

  group('DriftMergeStore.upsert — track_config', () {
    late UserDatabase db;
    late DriftMergeStore store;
    late int profileId;

    setUp(() async {
      final built = await _buildDb();
      db = built.db;
      profileId = built.profileId;
      store = DriftMergeStore(db);
    });
    tearDown(() => db.close());

    test('insert: creates track row when none exists', () async {
      await store.upsert(
        kind: EntityKind.trackConfig,
        profileId: profileId,
        fields: {
          'curriculum_id': 'mishnayos',
          'state': 'active',
          'activated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
          'state_changed_at': DateTime.utc(2026, 5, 1).toIso8601String(),
        },
      );

      final rows =
          await (db.select(db.curriculumTracks)..where(
                (t) =>
                    (t.profileId.equals(profileId)) &
                    (t.curriculumId.equals('mishnayos')),
              ))
              .get();
      expect(rows, hasLength(1));
      expect(rows.single.state, equals('active'));
    });

    test(
      'update: overwrites state and stateChangedAt for existing track',
      () async {
        await _seedTrack(db, profileId: profileId, curriculumId: 'mishnayos');

        await store.upsert(
          kind: EntityKind.trackConfig,
          profileId: profileId,
          fields: {
            'curriculum_id': 'mishnayos',
            'state': 'retired',
            'activated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            'state_changed_at': DateTime.utc(2026, 5, 15).toIso8601String(),
          },
        );

        final rows =
            await (db.select(db.curriculumTracks)..where(
                  (t) =>
                      (t.profileId.equals(profileId)) &
                      (t.curriculumId.equals('mishnayos')),
                ))
                .get();
        expect(rows, hasLength(1));
        expect(rows.single.state, equals('retired'));
      },
    );

    test('missing curriculum_id silently no-ops (malformed skip)', () async {
      await store.upsert(
        kind: EntityKind.trackConfig,
        profileId: profileId,
        fields: {
          // curriculum_id intentionally absent
          'state': 'active',
          'activated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
        },
      );

      final rows = await db.select(db.curriculumTracks).get();
      expect(rows, isEmpty);
    });

    test('missing activated_at silently no-ops (malformed skip)', () async {
      await store.upsert(
        kind: EntityKind.trackConfig,
        profileId: profileId,
        fields: {
          'curriculum_id': 'mishnayos',
          'state': 'active',
          // activated_at absent
        },
      );

      final rows = await db.select(db.curriculumTracks).get();
      expect(rows, isEmpty);
    });

    test(
      'idempotency: inserting same track_config twice yields one row',
      () async {
        final fields = {
          'curriculum_id': 'dafyomi',
          'state': 'active',
          'activated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
        };
        await store.upsert(
          kind: EntityKind.trackConfig,
          profileId: profileId,
          fields: fields,
        );
        await store.upsert(
          kind: EntityKind.trackConfig,
          profileId: profileId,
          fields: fields,
        );

        final rows =
            await (db.select(db.curriculumTracks)..where(
                  (t) =>
                      (t.profileId.equals(profileId)) &
                      (t.curriculumId.equals('dafyomi')),
                ))
                .get();
        expect(rows, hasLength(1));
      },
    );
  });

  // ── upsert(bookmark) ─────────────────────────────────────────────────────

  group('DriftMergeStore.upsert — bookmark', () {
    late UserDatabase db;
    late DriftMergeStore store;
    late int profileId;

    setUp(() async {
      final built = await _buildDb();
      db = built.db;
      profileId = built.profileId;
      store = DriftMergeStore(db);
    });
    tearDown(() => db.close());

    test('insert: creates bookmark when track exists', () async {
      await _seedTrack(db, profileId: profileId, curriculumId: 'mishnayos');

      await store.upsert(
        kind: EntityKind.bookmark,
        profileId: profileId,
        fields: {
          'curriculum_id': 'mishnayos',
          'track_type': 'personal',
          'sefaria_ref': 'Mishnah Berakhot 1.1',
          'updated_at': DateTime.utc(2026, 5, 10).toIso8601String(),
        },
      );

      final bookmarks = await db.bookmarkDao.getBookmarksByProfile(profileId);
      expect(bookmarks, hasLength(1));
      expect(bookmarks.single.sefariaRef, equals('Mishnah Berakhot 1.1'));
    });

    test('update: newer remote overwrites sefariaRef', () async {
      await _seedTrack(db, profileId: profileId, curriculumId: 'mishnayos');

      // Initial insert
      await store.upsert(
        kind: EntityKind.bookmark,
        profileId: profileId,
        fields: {
          'curriculum_id': 'mishnayos',
          'track_type': 'personal',
          'sefaria_ref': 'Mishnah Berakhot 1.1',
          'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
        },
      );

      // Newer remote row arrives
      await store.upsert(
        kind: EntityKind.bookmark,
        profileId: profileId,
        fields: {
          'curriculum_id': 'mishnayos',
          'track_type': 'personal',
          'sefaria_ref': 'Mishnah Berakhot 2.1',
          'updated_at': DateTime.utc(2026, 5, 20).toIso8601String(),
        },
      );

      final bookmarks = await db.bookmarkDao.getBookmarksByProfile(profileId);
      expect(bookmarks, hasLength(1));
      expect(bookmarks.single.sefariaRef, equals('Mishnah Berakhot 2.1'));
    });

    test('older remote does NOT overwrite newer local bookmark', () async {
      await _seedTrack(db, profileId: profileId, curriculumId: 'mishnayos');

      // Insert a "local" bookmark with a recent timestamp
      await store.upsert(
        kind: EntityKind.bookmark,
        profileId: profileId,
        fields: {
          'curriculum_id': 'mishnayos',
          'track_type': 'personal',
          'sefaria_ref': 'Mishnah Berakhot 3.1',
          'updated_at': DateTime.utc(2026, 5, 20).toIso8601String(),
        },
      );

      // Older remote row arrives
      await store.upsert(
        kind: EntityKind.bookmark,
        profileId: profileId,
        fields: {
          'curriculum_id': 'mishnayos',
          'track_type': 'personal',
          'sefaria_ref': 'Mishnah Berakhot 1.1',
          'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
        },
      );

      final bookmarks = await db.bookmarkDao.getBookmarksByProfile(profileId);
      // Should still have the newer ref, not the old one
      expect(bookmarks.single.sefariaRef, equals('Mishnah Berakhot 3.1'));
    });

    test('skip: track not yet synced — no bookmark inserted', () async {
      // Do NOT seed a track for 'mishnayos'
      await store.upsert(
        kind: EntityKind.bookmark,
        profileId: profileId,
        fields: {
          'curriculum_id': 'mishnayos',
          'track_type': 'personal',
          'sefaria_ref': 'Mishnah Berakhot 1.1',
          'updated_at': DateTime.utc(2026, 5, 10).toIso8601String(),
        },
      );

      final bookmarks = await db.bookmarkDao.getBookmarksByProfile(profileId);
      expect(bookmarks, isEmpty);
    });

    test(
      'skip: malformed fields (missing updated_at) — no bookmark inserted',
      () async {
        await _seedTrack(db, profileId: profileId, curriculumId: 'mishnayos');

        await store.upsert(
          kind: EntityKind.bookmark,
          profileId: profileId,
          fields: {
            'curriculum_id': 'mishnayos',
            'track_type': 'personal',
            'sefaria_ref': 'Mishnah Berakhot 1.1',
            // updated_at absent
          },
        );

        final bookmarks = await db.bookmarkDao.getBookmarksByProfile(profileId);
        expect(bookmarks, isEmpty);
      },
    );

    test('idempotency: same bookmark twice yields one row', () async {
      await _seedTrack(db, profileId: profileId, curriculumId: 'mishnayos');

      final fields = {
        'curriculum_id': 'mishnayos',
        'track_type': 'personal',
        'sefaria_ref': 'Mishnah Berakhot 1.1',
        'updated_at': DateTime.utc(2026, 5, 10).toIso8601String(),
      };
      await store.upsert(
        kind: EntityKind.bookmark,
        profileId: profileId,
        fields: fields,
      );
      await store.upsert(
        kind: EntityKind.bookmark,
        profileId: profileId,
        fields: fields,
      );

      final bookmarks = await db.bookmarkDao.getBookmarksByProfile(profileId);
      expect(bookmarks, hasLength(1));
    });
  });

  // ── upsert(settings) — replace-all stage semantics ───────────────────────

  group('DriftMergeStore.upsert — settings (replace-all stages)', () {
    late UserDatabase db;
    late DriftMergeStore store;
    late int profileId;
    late int trackId;

    setUp(() async {
      final built = await _buildDb();
      db = built.db;
      profileId = built.profileId;
      store = DriftMergeStore(db);
      trackId = await _seedTrack(
        db,
        profileId: profileId,
        curriculumId: 'mishnayos',
      );
    });
    tearDown(() => db.close());

    test('inserts all stages from the stages list', () async {
      await store.upsert(
        kind: EntityKind.settings,
        profileId: profileId,
        fields: {
          'curriculum_id': 'mishnayos',
          'track_id': trackId,
          'stages': [
            {
              'track_id': trackId,
              'stage_order': 0,
              'stage_name': 'learning',
              'is_default': true,
              'schedule': '{"type":"delay","delay_days":0}',
              'updated_at': DateTime.utc(2026, 5, 10).toIso8601String(),
            },
            {
              'track_id': trackId,
              'stage_order': 1,
              'stage_name': 'review',
              'is_default': false,
              'schedule': '{"type":"delay","delay_days":7}',
              'updated_at': DateTime.utc(2026, 5, 10).toIso8601String(),
            },
          ],
        },
      );

      final stages = await db.stageDao.getStageDefinitionsByCurriculum(
        'mishnayos',
      );
      expect(stages, hasLength(2));
      expect(
        stages.map((s) => s.stageName).toList(),
        containsAll(['learning', 'review']),
      );
    });

    test(
      'replaces all prior stages on second upsert (delete-then-insert)',
      () async {
        // Seed an initial set of 2 stages
        await store.upsert(
          kind: EntityKind.settings,
          profileId: profileId,
          fields: {
            'curriculum_id': 'mishnayos',
            'track_id': trackId,
            'stages': [
              {
                'track_id': trackId,
                'stage_order': 0,
                'stage_name': 'old_stage_1',
                'schedule': '{"type":"delay","delay_days":0}',
                'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
              },
              {
                'track_id': trackId,
                'stage_order': 1,
                'stage_name': 'old_stage_2',
                'schedule': '{"type":"delay","delay_days":7}',
                'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
              },
            ],
          },
        );

        // Merge a new set of 1 stage — should replace, not accumulate
        await store.upsert(
          kind: EntityKind.settings,
          profileId: profileId,
          fields: {
            'curriculum_id': 'mishnayos',
            'track_id': trackId,
            'stages': [
              {
                'track_id': trackId,
                'stage_order': 0,
                'stage_name': 'new_only_stage',
                'schedule': '{"type":"delay","delay_days":3}',
                'updated_at': DateTime.utc(2026, 5, 20).toIso8601String(),
              },
            ],
          },
        );

        final stages = await db.stageDao.getStageDefinitionsByCurriculum(
          'mishnayos',
        );
        expect(stages, hasLength(1));
        expect(stages.single.stageName, equals('new_only_stage'));
      },
    );

    test('skip: missing curriculum_id → no stages inserted', () async {
      await store.upsert(
        kind: EntityKind.settings,
        profileId: profileId,
        fields: {
          // curriculum_id absent
          'track_id': trackId,
          'stages': [
            {
              'stage_order': 0,
              'stage_name': 'learning',
              'schedule': '{"type":"delay","delay_days":0}',
              'updated_at': DateTime.utc(2026, 5, 10).toIso8601String(),
            },
          ],
        },
      );

      final stages = await db.stageDao.getAllStageDefinitions();
      expect(stages, isEmpty);
    });

    test('skip: empty stages list → no stages inserted, no crash', () async {
      await store.upsert(
        kind: EntityKind.settings,
        profileId: profileId,
        fields: {'curriculum_id': 'mishnayos', 'stages': <dynamic>[]},
      );

      final stages = await db.stageDao.getStageDefinitionsByCurriculum(
        'mishnayos',
      );
      expect(stages, isEmpty);
    });
  });

  // ── upsert(stage_definition) ─────────────────────────────────────────────

  group('DriftMergeStore.upsert — stage_definition', () {
    late UserDatabase db;
    late DriftMergeStore store;
    late int profileId;
    late int trackId;

    setUp(() async {
      final built = await _buildDb();
      db = built.db;
      profileId = built.profileId;
      store = DriftMergeStore(db);
      trackId = await _seedTrack(
        db,
        profileId: profileId,
        curriculumId: 'mishnayos',
      );
    });
    tearDown(() => db.close());

    test('insert: creates stage_definition when none exists', () async {
      await store.upsert(
        kind: EntityKind.stageDefinition,
        profileId: profileId,
        fields: {
          'curriculum_id': 'mishnayos',
          'track_id': trackId,
          'stage_order': 0,
          'stage_name': 'learning',
          'is_default': true,
          'schedule': '{"type":"delay","delay_days":0}',
          'updated_at': DateTime.utc(2026, 5, 10).toIso8601String(),
        },
      );

      final stages = await db.stageDao.getStageDefinitionsByCurriculum(
        'mishnayos',
      );
      expect(stages, hasLength(1));
      expect(stages.single.stageName, equals('learning'));
      expect(stages.single.isDefault, isTrue);
    });

    test(
      'Bug 3: stage with a REMOTE track_id binds to the LOCAL track '
      '(resolved by profile+curriculum) so getStagesByTrack finds it',
      () async {
        // Simulate the tutored-mirror case: the synced stage row carries the
        // parent device's track id (a large value that does not match the
        // mirror's local autoincrement track id).
        const remoteTrackId = 987654;
        expect(remoteTrackId, isNot(equals(trackId)));

        await store.upsert(
          kind: EntityKind.stageDefinition,
          profileId: profileId,
          fields: {
            'curriculum_id': 'mishnayos',
            'track_id': remoteTrackId, // stale remote id
            'stage_order': 0,
            'stage_name': 'learning',
            'is_default': true,
            'schedule': '{"type":"delay","delay_days":0}',
            'updated_at': DateTime.utc(2026, 5, 10).toIso8601String(),
          },
        );

        // The projection reads stages via getStagesByTrack(localTrackId).
        // Before the fix the stage was bound to remoteTrackId and this was
        // empty → "No projection". Now it is realigned to the local track.
        final byLocalTrack = await db.stageDao.getStagesByTrack(trackId);
        expect(byLocalTrack, hasLength(1));
        expect(byLocalTrack.single.trackId, equals(trackId));
      },
    );

    test(
      'update: overwrites stage_name, schedule for existing stage',
      () async {
        // First insert
        await store.upsert(
          kind: EntityKind.stageDefinition,
          profileId: profileId,
          fields: {
            'curriculum_id': 'mishnayos',
            'track_id': trackId,
            'stage_order': 0,
            'stage_name': 'old_name',
            'schedule': '{"type":"delay","delay_days":0}',
            'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
          },
        );

        // Update with new name
        await store.upsert(
          kind: EntityKind.stageDefinition,
          profileId: profileId,
          fields: {
            'curriculum_id': 'mishnayos',
            'track_id': trackId,
            'stage_order': 0,
            'stage_name': 'new_name',
            'schedule': '{"type":"delay","delay_days":7}',
            'updated_at': DateTime.utc(2026, 5, 20).toIso8601String(),
          },
        );

        final stages = await db.stageDao.getStageDefinitionsByCurriculum(
          'mishnayos',
        );
        expect(stages, hasLength(1));
        expect(stages.single.stageName, equals('new_name'));
        expect(
          stages.single.schedule,
          equals('{"type":"delay","delay_days":7}'),
        );
      },
    );

    test('skip: missing curriculum_id → no stage inserted', () async {
      await store.upsert(
        kind: EntityKind.stageDefinition,
        profileId: profileId,
        fields: {
          // curriculum_id absent
          'track_id': trackId,
          'stage_order': 0,
          'stage_name': 'learning',
          'updated_at': DateTime.utc(2026, 5, 10).toIso8601String(),
        },
      );

      final stages = await db.stageDao.getAllStageDefinitions();
      expect(stages, isEmpty);
    });

    test('skip: missing track_id → no stage inserted', () async {
      await store.upsert(
        kind: EntityKind.stageDefinition,
        profileId: profileId,
        fields: {
          'curriculum_id': 'mishnayos',
          // track_id absent
          'stage_order': 0,
          'stage_name': 'learning',
          'updated_at': DateTime.utc(2026, 5, 10).toIso8601String(),
        },
      );

      final stages = await db.stageDao.getAllStageDefinitions();
      expect(stages, isEmpty);
    });

    test(
      'idempotency: inserting same stage_definition twice yields one row',
      () async {
        final fields = {
          'curriculum_id': 'mishnayos',
          'track_id': trackId,
          'stage_order': 2,
          'stage_name': 'chazara',
          'schedule': '{"type":"delay","delay_days":30}',
          'updated_at': DateTime.utc(2026, 5, 10).toIso8601String(),
        };
        await store.upsert(
          kind: EntityKind.stageDefinition,
          profileId: profileId,
          fields: fields,
        );
        await store.upsert(
          kind: EntityKind.stageDefinition,
          profileId: profileId,
          fields: fields,
        );

        final stages = await db.stageDao.getStageDefinitionsByCurriculum(
          'mishnayos',
        );
        expect(stages, hasLength(1));
      },
    );

    test(
      '_encodeSchedule: legacy days_of_week quartet produces correct JSON',
      () async {
        await store.upsert(
          kind: EntityKind.stageDefinition,
          profileId: profileId,
          fields: {
            'curriculum_id': 'mishnayos',
            'track_id': trackId,
            'stage_order': 0,
            'stage_name': 'review',
            'schedule_type': 'days_of_week',
            'days_of_week': [0, 3, 5],
            'updated_at': DateTime.utc(2026, 5, 10).toIso8601String(),
          },
        );

        final stages = await db.stageDao.getStageDefinitionsByCurriculum(
          'mishnayos',
        );
        expect(stages.single.schedule, contains('"days"'));
        expect(stages.single.schedule, contains('days_of_week'));
      },
    );

    test(
      '_encodeSchedule: rolling_window quartet produces correct JSON',
      () async {
        await store.upsert(
          kind: EntityKind.stageDefinition,
          profileId: profileId,
          fields: {
            'curriculum_id': 'mishnayos',
            'track_id': trackId,
            'stage_order': 0,
            'stage_name': 'rolling_review',
            'schedule_type': 'rolling_window',
            'rolling_window_size': 14,
            'updated_at': DateTime.utc(2026, 5, 10).toIso8601String(),
          },
        );

        final stages = await db.stageDao.getStageDefinitionsByCurriculum(
          'mishnayos',
        );
        expect(stages.single.schedule, contains('rolling_window'));
        expect(stages.single.schedule, contains('"window_size":14'));
      },
    );
  });

  // ── upsert(profile_program) ───────────────────────────────────────────────

  group('DriftMergeStore.upsert — profile_program', () {
    late UserDatabase db;
    late DriftMergeStore store;
    late int profileId;

    setUp(() async {
      final built = await _buildDb();
      db = built.db;
      profileId = built.profileId;
      store = DriftMergeStore(db);
    });
    tearDown(() => db.close());

    test('insert: creates profile_program when none exists', () async {
      await store.upsert(
        kind: EntityKind.profileProgram,
        profileId: profileId,
        fields: {
          'curriculum_id': 'mishnayos',
          'program_id': 7,
          'profile_id': profileId,
        },
      );

      final prog = await db.profileProgramDao.getProgramForProfileAndCurriculum(
        profileId,
        'mishnayos',
      );
      expect(prog, isNotNull);
      expect(prog!.programId, equals(7));
    });

    test('update: overwrites programId on existing row', () async {
      await store.upsert(
        kind: EntityKind.profileProgram,
        profileId: profileId,
        fields: {
          'curriculum_id': 'mishnayos',
          'program_id': 7,
          'profile_id': profileId,
        },
      );

      await store.upsert(
        kind: EntityKind.profileProgram,
        profileId: profileId,
        fields: {
          'curriculum_id': 'mishnayos',
          'program_id': 12,
          'profile_id': profileId,
        },
      );

      final prog = await db.profileProgramDao.getProgramForProfileAndCurriculum(
        profileId,
        'mishnayos',
      );
      expect(prog!.programId, equals(12));
    });

    test('skip: missing curriculum_id → no row inserted', () async {
      await store.upsert(
        kind: EntityKind.profileProgram,
        profileId: profileId,
        fields: {
          // curriculum_id absent
          'program_id': 7,
        },
      );

      final progs = await db.profileProgramDao.getProgramsForProfile(profileId);
      expect(progs, isEmpty);
    });

    test('skip: missing program_id → no row inserted', () async {
      await store.upsert(
        kind: EntityKind.profileProgram,
        profileId: profileId,
        fields: {
          'curriculum_id': 'mishnayos',
          // program_id absent
        },
      );

      final progs = await db.profileProgramDao.getProgramsForProfile(profileId);
      expect(progs, isEmpty);
    });
  });

  // ── upsert(learning_order) ────────────────────────────────────────────────

  group('DriftMergeStore.upsert — learning_order', () {
    late UserDatabase db;
    late DriftMergeStore store;
    late int profileId;

    setUp(() async {
      final built = await _buildDb();
      db = built.db;
      profileId = built.profileId;
      store = DriftMergeStore(db);
    });
    tearDown(() => db.close());

    test('insert: creates learning_order row', () async {
      await store.upsert(
        kind: EntityKind.learningOrder,
        profileId: profileId,
        fields: {
          'curriculum_id': 'mishnayos',
          'sefaria_ref': 'Mishnah Berakhot 1',
          'user_sort_order': 5,
          'updated_at': DateTime.utc(2026, 5, 10).toIso8601String(),
        },
      );

      final rows = await db.learningOrderDao.getLearningOrderByCurriculum(
        'mishnayos',
      );
      expect(rows, hasLength(1));
      expect(rows.single.sefariaRef, equals('Mishnah Berakhot 1'));
      expect(rows.single.userSortOrder, equals(5));
    });

    test('newer remote overwrites user_sort_order', () async {
      await store.upsert(
        kind: EntityKind.learningOrder,
        profileId: profileId,
        fields: {
          'curriculum_id': 'mishnayos',
          'sefaria_ref': 'Mishnah Berakhot 1',
          'user_sort_order': 1,
          'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
        },
      );

      await store.upsert(
        kind: EntityKind.learningOrder,
        profileId: profileId,
        fields: {
          'curriculum_id': 'mishnayos',
          'sefaria_ref': 'Mishnah Berakhot 1',
          'user_sort_order': 99,
          'updated_at': DateTime.utc(2026, 5, 20).toIso8601String(),
        },
      );

      final rows = await db.learningOrderDao.getLearningOrderByCurriculum(
        'mishnayos',
      );
      expect(rows, hasLength(1));
      expect(rows.single.userSortOrder, equals(99));
    });

    test('older remote does NOT overwrite newer local row', () async {
      // Seed a "local" row with ts=May 20
      await store.upsert(
        kind: EntityKind.learningOrder,
        profileId: profileId,
        fields: {
          'curriculum_id': 'mishnayos',
          'sefaria_ref': 'Mishnah Berakhot 1',
          'user_sort_order': 50,
          'updated_at': DateTime.utc(2026, 5, 20).toIso8601String(),
        },
      );

      // Older remote row arrives
      await store.upsert(
        kind: EntityKind.learningOrder,
        profileId: profileId,
        fields: {
          'curriculum_id': 'mishnayos',
          'sefaria_ref': 'Mishnah Berakhot 1',
          'user_sort_order': 1,
          'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
        },
      );

      final rows = await db.learningOrderDao.getLearningOrderByCurriculum(
        'mishnayos',
      );
      expect(rows, hasLength(1));
      expect(rows.single.userSortOrder, equals(50));
    });

    test('skip: missing curriculum_id → no row inserted', () async {
      await store.upsert(
        kind: EntityKind.learningOrder,
        profileId: profileId,
        fields: {
          // curriculum_id absent
          'sefaria_ref': 'Mishnah Berakhot 1',
          'user_sort_order': 5,
          'updated_at': DateTime.utc(2026, 5, 10).toIso8601String(),
        },
      );

      final rows = await db.learningOrderDao.getAllLearningOrders();
      expect(rows, isEmpty);
    });

    test('skip: missing sefaria_ref → no row inserted', () async {
      await store.upsert(
        kind: EntityKind.learningOrder,
        profileId: profileId,
        fields: {
          'curriculum_id': 'mishnayos',
          // sefaria_ref absent
          'user_sort_order': 5,
          'updated_at': DateTime.utc(2026, 5, 10).toIso8601String(),
        },
      );

      final rows = await db.learningOrderDao.getAllLearningOrders();
      expect(rows, isEmpty);
    });
  });

  // ── insertIfAbsent(completion) ────────────────────────────────────────────

  group('DriftMergeStore.insertIfAbsent — completion', () {
    late UserDatabase db;
    late DriftMergeStore store;
    late int profileId;

    setUp(() async {
      final built = await _buildDb();
      db = built.db;
      profileId = built.profileId;
      store = DriftMergeStore(db);
    });
    tearDown(() => db.close());

    test('inserts completion row when natural key is absent', () async {
      await store.insertIfAbsent(
        kind: EntityKind.completion,
        profileId: profileId,
        naturalKey: 'key-1',
        fields: {
          'curriculum_id': 'mishnayos',
          'sefaria_ref': 'Mishnah Berakhot 1.1',
          'stage_id': 1,
          'track_type': 'personal',
          'completed_at': DateTime.utc(2026, 5, 10).toIso8601String(),
        },
      );

      final events = await db.completionEventDao.getEventsByProfile(profileId);
      expect(events, hasLength(1));
      expect(events.single.sefariaRef, equals('Mishnah Berakhot 1.1'));
      expect(events.single.purgedAt, isNull);
    });

    test(
      'idempotency: inserting same natural key twice yields one row',
      () async {
        final fields = {
          'curriculum_id': 'mishnayos',
          'sefaria_ref': 'Mishnah Berakhot 1.1',
          'stage_id': 1,
          'track_type': 'personal',
          'completed_at': DateTime.utc(2026, 5, 10).toIso8601String(),
        };

        await store.insertIfAbsent(
          kind: EntityKind.completion,
          profileId: profileId,
          naturalKey: 'key-dup',
          fields: fields,
        );
        await store.insertIfAbsent(
          kind: EntityKind.completion,
          profileId: profileId,
          naturalKey: 'key-dup',
          fields: fields,
        );

        final events = await db.completionEventDao.getEventsByProfile(
          profileId,
        );
        expect(events, hasLength(1));
      },
    );

    test(
      'tombstone resurrection (H2): remote arrival clears purgedAt',
      () async {
        // Seed a tombstoned completion row manually
        final ts = DateTime.utc(2026, 5, 5, 12, 0, 0);
        final id = await db.completionEventDao.appendEvent(
          CompletionEventsCompanion.insert(
            profileId: profileId,
            curriculumId: 'mishnayos',
            sefariaRef: 'Mishnah Berakhot 2.1',
            stageId: 2,
            trackType: 'personal',
            eventTimestamp: ts,
          ),
        );
        // Tombstone it
        await (db.update(
          db.completionEvents,
        )..where((t) => t.id.equals(id))).write(
          CompletionEventsCompanion(purgedAt: Value(DateTime.utc(2026, 5, 10))),
        );

        // Verify it's tombstoned
        final beforeRows = await db.completionEventDao.getEventsByProfile(
          profileId,
        );
        expect(beforeRows.single.purgedAt, isNotNull);

        // Remote row arrives — should clear the tombstone
        await store.insertIfAbsent(
          kind: EntityKind.completion,
          profileId: profileId,
          naturalKey: 'tombstone-key',
          fields: {
            'curriculum_id': 'mishnayos',
            'sefaria_ref': 'Mishnah Berakhot 2.1',
            'stage_id': 2,
            'track_type': 'personal',
            'completed_at': ts.toIso8601String(),
          },
        );

        final afterRows = await db.completionEventDao.getEventsByProfile(
          profileId,
        );
        expect(afterRows, hasLength(1));
        expect(
          afterRows.single.purgedAt,
          isNull,
          reason: 'H2: tombstone must be cleared when remote row re-arrives',
        );
      },
    );

    test(
      'tombstone resurrection (D11): remote with a DIFFERENT timestamp still '
      'clears the tombstone',
      () async {
        // Seed + tombstone a completion at T1.
        final t1 = DateTime.utc(2026, 5, 5, 12);
        final id = await db.completionEventDao.appendEvent(
          CompletionEventsCompanion.insert(
            profileId: profileId,
            curriculumId: 'mishnayos',
            sefariaRef: 'Mishnah Berakhot 3.1',
            stageId: 2,
            trackType: 'personal',
            eventTimestamp: t1,
          ),
        );
        await (db.update(
          db.completionEvents,
        )..where((t) => t.id.equals(id))).write(
          CompletionEventsCompanion(purgedAt: Value(DateTime.utc(2026, 5, 10))),
        );

        // A re-mark elsewhere produces a NEW completed_at (T2 != T1) — the
        // realistic case the old timestamp-matching lookup missed.
        final t2 = DateTime.utc(2026, 5, 12, 9);
        await store.insertIfAbsent(
          kind: EntityKind.completion,
          profileId: profileId,
          naturalKey: 'tombstone-key-2',
          fields: {
            'curriculum_id': 'mishnayos',
            'sefaria_ref': 'Mishnah Berakhot 3.1',
            'stage_id': 2,
            'track_type': 'personal',
            'completed_at': t2.toIso8601String(),
          },
        );

        final rows = await db.completionEventDao.getEventsByProfile(profileId);
        expect(rows, hasLength(1));
        expect(
          rows.single.purgedAt,
          isNull,
          reason:
              'D11: tombstone must clear even when the re-mark timestamp '
              'differs from the tombstoned row',
        );
        expect(
          rows.single.eventTimestamp.isAtSameMomentAs(t2),
          isTrue,
          reason: 'D11: resurrected row adopts the incoming completion time',
        );
      },
    );

    test('malformed skip: missing curriculum_id → no row inserted', () async {
      await store.insertIfAbsent(
        kind: EntityKind.completion,
        profileId: profileId,
        naturalKey: 'bad-key',
        fields: {
          // curriculum_id absent
          'sefaria_ref': 'Mishnah Berakhot 1.1',
          'stage_id': 1,
          'track_type': 'personal',
          'completed_at': DateTime.utc(2026, 5, 10).toIso8601String(),
        },
      );

      final events = await db.completionEventDao.getEventsByProfile(profileId);
      expect(events, isEmpty);
    });

    test('malformed skip: missing sefaria_ref → no row inserted', () async {
      await store.insertIfAbsent(
        kind: EntityKind.completion,
        profileId: profileId,
        naturalKey: 'bad-key2',
        fields: {
          'curriculum_id': 'mishnayos',
          // sefaria_ref absent
          'stage_id': 1,
          'track_type': 'personal',
          'completed_at': DateTime.utc(2026, 5, 10).toIso8601String(),
        },
      );

      final events = await db.completionEventDao.getEventsByProfile(profileId);
      expect(events, isEmpty);
    });

    test('malformed skip: missing event timestamp → no row inserted', () async {
      await store.insertIfAbsent(
        kind: EntityKind.completion,
        profileId: profileId,
        naturalKey: 'bad-key3',
        fields: {
          'curriculum_id': 'mishnayos',
          'sefaria_ref': 'Mishnah Berakhot 1.1',
          'stage_id': 1,
          'track_type': 'personal',
          // completed_at absent
        },
      );

      final events = await db.completionEventDao.getEventsByProfile(profileId);
      expect(events, isEmpty);
    });

    test('two distinct completions both inserted', () async {
      await store.insertIfAbsent(
        kind: EntityKind.completion,
        profileId: profileId,
        naturalKey: 'k1',
        fields: {
          'curriculum_id': 'mishnayos',
          'sefaria_ref': 'Mishnah Berakhot 1.1',
          'stage_id': 1,
          'track_type': 'personal',
          'completed_at': DateTime.utc(2026, 5, 1).toIso8601String(),
        },
      );
      await store.insertIfAbsent(
        kind: EntityKind.completion,
        profileId: profileId,
        naturalKey: 'k2',
        fields: {
          'curriculum_id': 'mishnayos',
          'sefaria_ref': 'Mishnah Berakhot 1.2',
          'stage_id': 1,
          'track_type': 'personal',
          'completed_at': DateTime.utc(2026, 5, 2).toIso8601String(),
        },
      );

      final events = await db.completionEventDao.getEventsByProfile(profileId);
      expect(events, hasLength(2));
    });
  });

  // ── upsert(unknown kind) — no-op ─────────────────────────────────────────

  group('DriftMergeStore.upsert — unknown kind', () {
    late UserDatabase db;
    late DriftMergeStore store;

    setUp(() async {
      db = UserDatabase(NativeDatabase.memory());
      store = DriftMergeStore(db);
    });
    tearDown(() => db.close());

    test('unknown kind is a no-op and does not throw', () async {
      await expectLater(
        store.upsert(
          kind: 'completely_unknown_kind',
          profileId: 1,
          fields: {'some': 'data'},
        ),
        completes,
      );
    });
  });

  // ── insertIfAbsent — non-completion kind is a no-op ───────────────────────

  group('DriftMergeStore.insertIfAbsent — non-completion kind', () {
    late UserDatabase db;
    late DriftMergeStore store;

    setUp(() async {
      db = UserDatabase(NativeDatabase.memory());
      store = DriftMergeStore(db);
    });
    tearDown(() => db.close());

    test('non-completion kind is silently ignored', () async {
      await expectLater(
        store.insertIfAbsent(
          kind: EntityKind.trackConfig,
          profileId: 1,
          naturalKey: 'k',
          fields: {'curriculum_id': 'mishnayos'},
        ),
        completes,
      );
    });
  });

  // ── Cross-kind isolation ──────────────────────────────────────────────────

  group('DriftMergeStore — cross-kind key isolation in SyncKv', () {
    late UserDatabase db;
    late DriftMergeStore store;
    late int profileId;

    setUp(() async {
      final built = await _buildDb();
      db = built.db;
      profileId = built.profileId;
      store = DriftMergeStore(db);
    });
    tearDown(() => db.close());

    test(
      'different kinds with same naturalKey are independent in SyncKv',
      () async {
        final ts1 = DateTime.utc(2026, 5, 1);
        final ts2 = DateTime.utc(2026, 5, 20);

        await store.persistUpdatedAt(
          kind: EntityKind.bookmark,
          profileId: profileId,
          naturalKey: 'mishnayos',
          updatedAt: ts1,
        );
        await store.persistUpdatedAt(
          kind: EntityKind.trackConfig,
          profileId: profileId,
          naturalKey: 'mishnayos',
          updatedAt: ts2,
        );

        final bookmarkTs = await store.currentUpdatedAt(
          kind: EntityKind.bookmark,
          profileId: profileId,
          naturalKey: 'mishnayos',
        );
        final trackTs = await store.currentUpdatedAt(
          kind: EntityKind.trackConfig,
          profileId: profileId,
          naturalKey: 'mishnayos',
        );

        expect(bookmarkTs, equals(ts1));
        expect(trackTs, equals(ts2));
      },
    );
  });
}
