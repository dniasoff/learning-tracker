/// Unit tests for [LearnerProfileMerger]: fake-store LWW unit tests,
/// Phase-3 LWW symmetry + persistUpdatedAt against a real
/// [DriftMergeStore], and the codec.encode() -> merger -> DB round-trip.
///
/// AG-5 (AUD-app-05): consolidates test/core/sync/merge/mergers_test.dart's
/// LearnerProfileMerger group, test/sync/merge/lww_symmetric_test.dart's
/// LearnerProfileMerger group, test/sync/merge/persist_updated_at_test.dart's
/// LearnerProfileMerger case, and
/// test/sync/merge/learner_profile_roundtrip_test.dart into the single file
/// mirroring lib/core/sync/merge/learner_profile_merger.dart.
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/learner_profile_codec.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/learner_profile_merger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';

class _FakeMergeStore implements MergeStore {
  final _timestamps = <String, Map<int, Map<String, DateTime?>>>{};
  final _syncedAt = <String, Map<int, Map<String, DateTime?>>>{};
  final List<Map<String, dynamic>> upserted = [];

  void seedTimestamp({
    required String kind,
    required int profileId,
    required String naturalKey,
    required DateTime? at,
  }) {
    _timestamps
            .putIfAbsent(kind, () => {})
            .putIfAbsent(profileId, () => {})[naturalKey] =
        at;
  }

  @override
  Future<DateTime?> currentUpdatedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  }) async => _timestamps[kind]?[profileId]?[naturalKey];

  @override
  Future<DateTime?> currentSyncedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  }) async => _syncedAt[kind]?[profileId]?[naturalKey];

  @override
  Future<void> persistUpdatedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
    required DateTime updatedAt,
    DateTime? syncedAt,
  }) async {
    _timestamps
            .putIfAbsent(kind, () => {})
            .putIfAbsent(profileId, () => {})[naturalKey] =
        updatedAt;
    _syncedAt
            .putIfAbsent(kind, () => {})
            .putIfAbsent(profileId, () => {})[naturalKey] =
        syncedAt;
  }

  // AUD-t-cross-68: delegates to the real DriftMergeStore algorithm instead
  // of re-deriving it by hand, so this fake cannot drift from D15 semantics.
  @override
  bool remoteIsNewer({
    required DateTime? localUpdatedAt,
    required DateTime? remoteUpdatedAt,
    DateTime? localSyncedAt,
    DateTime? remoteSyncedAt,
  }) => driftMergeStoreRemoteIsNewer(
    localUpdatedAt: localUpdatedAt,
    remoteUpdatedAt: remoteUpdatedAt,
    localSyncedAt: localSyncedAt,
    remoteSyncedAt: remoteSyncedAt,
  );

  @override
  Future<void> upsert({
    required String kind,
    required int profileId,
    required Map<String, dynamic> fields,
  }) async {
    upserted.add({...fields, '__kind': kind, '__profileId': profileId});
  }

  @override
  Future<void> insertIfAbsent({
    required String kind,
    required int profileId,
    required String naturalKey,
    required Map<String, dynamic> fields,
  }) async {}

  @override
  Future<T> runInTransaction<T>(Future<T> Function() body) => body();
}

/// Decorates a [MergeStore] to throw a genuine [Error] (not an [Exception])
/// from [upsert] — used to prove AUD-core-sync-25's typed catch lets Errors
/// propagate rather than silently swallowing them.
class _ThrowingErrorStore implements MergeStore {
  _ThrowingErrorStore(this._inner);
  final MergeStore _inner;

  @override
  Future<DateTime?> currentUpdatedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  }) => _inner.currentUpdatedAt(
    kind: kind,
    profileId: profileId,
    naturalKey: naturalKey,
  );

  @override
  Future<DateTime?> currentSyncedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  }) => _inner.currentSyncedAt(
    kind: kind,
    profileId: profileId,
    naturalKey: naturalKey,
  );

  @override
  Future<void> persistUpdatedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
    required DateTime updatedAt,
    DateTime? syncedAt,
  }) => _inner.persistUpdatedAt(
    kind: kind,
    profileId: profileId,
    naturalKey: naturalKey,
    updatedAt: updatedAt,
    syncedAt: syncedAt,
  );

  @override
  bool remoteIsNewer({
    required DateTime? localUpdatedAt,
    required DateTime? remoteUpdatedAt,
    DateTime? localSyncedAt,
    DateTime? remoteSyncedAt,
  }) => _inner.remoteIsNewer(
    localUpdatedAt: localUpdatedAt,
    remoteUpdatedAt: remoteUpdatedAt,
    localSyncedAt: localSyncedAt,
    remoteSyncedAt: remoteSyncedAt,
  );

  @override
  Future<void> upsert({
    required String kind,
    required int profileId,
    required Map<String, dynamic> fields,
  }) async {
    // A genuine programming-bug-shaped Error, not a data/Exception problem.
    throw StateError('fault-injected: a real bug, not a data problem');
  }

  @override
  Future<void> insertIfAbsent({
    required String kind,
    required int profileId,
    required String naturalKey,
    required Map<String, dynamic> fields,
  }) => _inner.insertIfAbsent(
    kind: kind,
    profileId: profileId,
    naturalKey: naturalKey,
    fields: fields,
  );

  @override
  Future<T> runInTransaction<T>(Future<T> Function() body) => body();
}

DateTime _dt(int year, [int month = 1, int day = 1]) =>
    DateTime.utc(year, month, day);

// ── Phase 3 LWW-symmetry / persistUpdatedAt fixtures ────────────────────────
final _local = DateTime.utc(2026, 5, 21, 12, 0, 0);
final _remoteNewer = DateTime.utc(2026, 5, 21, 13, 0, 0);
final _remoteOlder = DateTime.utc(2026, 5, 21, 11, 0, 0);
const _profileId = 1;
final _ts = DateTime.utc(2026, 5, 21, 12, 0, 0);
final _syncedAt = DateTime.utc(2026, 5, 21, 12, 0, 30);

// ── codec.encode() → merger → DB round-trip fixtures ─────────────────────────
const _codec = LearnerProfileCodec();
const _remoteProfileId = 42;
final _updatedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);
final _createdAt = DateTime.utc(2026, 1, 1, 0, 0, 0);

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  // ── LearnerProfileMerger — fake-store unit tests ─────────────────────────
  group('LearnerProfileMerger', () {
    late _FakeMergeStore store;
    late LearnerProfileMerger merger;

    setUp(() {
      store = _FakeMergeStore();
      merger = LearnerProfileMerger(store: store);
    });

    test('kind is "learner_profile"', () {
      expect(merger.kind, EntityKind.learnerProfile);
    });

    // LearnerProfileCodec.decode requires: profile_id, account_id,
    // display_name, mode, updated_at, created_at. All must be present.

    /// Minimal valid row for LearnerProfileCodec.decode.
    Map<String, dynamic> profileRow({
      int profileId = 1,
      int accountId = 1,
      String displayName = 'Alice',
      String mode = 'adult',
      required DateTime updatedAt,
      DateTime? createdAt,
    }) => {
      'profile_id': profileId,
      'account_id': accountId,
      'display_name': displayName,
      'mode': mode,
      'updated_at': updatedAt.toIso8601String(),
      'created_at': (createdAt ?? _dt(2025)).toIso8601String(),
    };

    test('upserts when no local row exists', () async {
      await merger.merge(
        profileId: 1,
        rows: [profileRow(updatedAt: _dt(2026))],
      );
      expect(store.upserted, hasLength(1));
    });

    test('skips when remote is older', () async {
      store.seedTimestamp(
        kind: EntityKind.learnerProfile,
        profileId: 1,
        naturalKey: '1',
        at: _dt(2027),
      );

      await merger.merge(
        profileId: 1,
        rows: [profileRow(displayName: 'Bob', updatedAt: _dt(2026))],
      );
      expect(store.upserted, isEmpty);
    });

    // AUD-t-cross-68: within DriftMergeStore.clockSkewTieBreakWindow (±5s)
    // with no decisive synced_at on either side, the real store falls back
    // to comparing raw updated_at and keeps the strictly-newer side (D15).
    // The hand-rolled fake this test was migrated with unconditionally
    // preferred remote once inside the window, which would silently clobber
    // a newer, un-pushed local edit with an older remote value.
    test('D15: within clock-skew window, older remote (no synced_at) does NOT '
        'clobber a newer local edit', () async {
      final localTime = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final remoteTime = localTime.subtract(const Duration(seconds: 2));

      store.seedTimestamp(
        kind: EntityKind.learnerProfile,
        profileId: 1,
        naturalKey: '1',
        at: localTime,
      );

      await merger.merge(
        profileId: 1,
        rows: [profileRow(displayName: 'Clobbered?', updatedAt: remoteTime)],
      );

      expect(
        store.upserted,
        isEmpty,
        reason:
            'Older remote inside the clock-skew window must not overwrite '
            'a newer un-pushed local edit (D15) when neither side has '
            'synced_at',
      );
    });

    test('falls back to profileId when row decode returns null', () async {
      // When the row is missing required fields (e.g. no account_id), decode
      // returns null. The merger uses the caller profileId as natural key and
      // treats remoteUpdatedAt as null → remoteIsNewer returns false → skipped.
      await merger.merge(
        profileId: 1,
        rows: [
          {
            // Missing account_id, mode, created_at → decode returns null
            'display_name': 'Fallback',
            'updated_at': _dt(2026).toIso8601String(),
          },
        ],
      );
      // When decode fails, remoteUpdatedAt is null → remoteIsNewer=false → skip
      expect(store.upserted, isEmpty);
    });

    test('accepts DateTime object as updated_at', () async {
      await merger.merge(
        profileId: 1,
        rows: [
          {
            'profile_id': 1,
            'account_id': 1,
            'display_name': 'Alice',
            'mode': 'adult',
            'updated_at': _dt(2026), // DateTime, not String
            'created_at': _dt(2025).toIso8601String(),
          },
        ],
      );
      expect(store.upserted, hasLength(1));
    });

    test('skips row when updated_at is null', () async {
      await merger.merge(
        profileId: 1,
        rows: [
          {
            'profile_id': 1,
            'account_id': 1,
            'display_name': 'Alice',
            'mode': 'adult',
            'created_at': _dt(2025).toIso8601String(),
            // no updated_at → decode returns null → remoteIsNewer=false → skip
          },
        ],
      );
      expect(store.upserted, isEmpty);
    });

    // AUD-core-sync-25 (EH-4): the per-row catch was narrowed from a bare
    // `catch (e, stackTrace)` to `on Exception catch`. A genuine Error
    // subtype (a real programming bug, not a data problem) must now
    // propagate loudly instead of being silently logged-and-swallowed.
    test('a genuine Error thrown mid-row (not an Exception) propagates instead '
        'of being silently swallowed', () async {
      final errorStore = _ThrowingErrorStore(store);
      final errorMerger = LearnerProfileMerger(store: errorStore);

      expect(
        () => errorMerger.merge(
          profileId: 1,
          rows: [profileRow(updatedAt: _dt(2026))],
        ),
        throwsA(isA<StateError>()),
        reason:
            'EH-4: a bare catch would have swallowed this Error and logged '
            'a quiet warning instead of crashing loudly on a real bug',
      );
    });
  });

  group(
    'LearnerProfileMerger — LWW symmetry + persistence (real DriftMergeStore)',
    () {
      late UserDatabase db;
      late DriftMergeStore store;
      const profileId = 1;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        db = UserDatabase(NativeDatabase.memory());
        await seedProfile(db);
        store = DriftMergeStore(db);
      });

      tearDown(() async {
        await db.close();
      });

      group('LearnerProfileMerger', () {
        late LearnerProfileMerger merger;

        setUp(() {
          merger = LearnerProfileMerger(store: store);
        });

        Map<String, dynamic> row({
          required DateTime updatedAt,
          DateTime? syncedAt,
        }) => {
          'profile_id': profileId,
          'account_id': 1,
          'display_name': 'Alice',
          'mode': 'adult',
          'updated_at': updatedAt.toIso8601String(),
          'created_at': _local.toIso8601String(),
          if (syncedAt != null) 'synced_at': syncedAt.toIso8601String(),
        };

        test('remote newer than local → applies', () async {
          await store.persistUpdatedAt(
            kind: EntityKind.learnerProfile,
            profileId: profileId,
            naturalKey: profileId.toString(),
            updatedAt: _local,
          );

          await merger.merge(
            profileId: profileId,
            rows: [row(updatedAt: _remoteNewer)],
          );

          final after = await store.currentUpdatedAt(
            kind: EntityKind.learnerProfile,
            profileId: profileId,
            naturalKey: profileId.toString(),
          );
          expect(after, _remoteNewer);
        });

        test('local newer than remote → does NOT apply', () async {
          await store.persistUpdatedAt(
            kind: EntityKind.learnerProfile,
            profileId: profileId,
            naturalKey: profileId.toString(),
            updatedAt: _local,
          );

          await merger.merge(
            profileId: profileId,
            rows: [row(updatedAt: _remoteOlder)],
          );

          final after = await store.currentUpdatedAt(
            kind: EntityKind.learnerProfile,
            profileId: profileId,
            naturalKey: profileId.toString(),
          );
          expect(after, _local);
        });
      });

      test('LearnerProfileMerger', () async {
        await LearnerProfileMerger(store: store).merge(
          profileId: _profileId,
          rows: [
            {
              'profile_id': _profileId,
              'account_id': 1,
              'display_name': 'Alice',
              'mode': 'adult',
              'updated_at': _ts.toIso8601String(),
              'created_at': _ts.toIso8601String(),
              'synced_at': _syncedAt.toIso8601String(),
            },
          ],
        );

        final updatedAt = await store.currentUpdatedAt(
          kind: EntityKind.learnerProfile,
          profileId: _profileId,
          naturalKey: _profileId.toString(),
        );
        expect(updatedAt, _ts);
      });
    },
  );

  group('learner_profile — codec.encode() → merger → DB round-trip', () {
    late UserDatabase db;
    late DriftMergeStore store;
    late LearnerProfileMerger merger;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = UserDatabase(NativeDatabase.memory());
      store = DriftMergeStore(db);
      merger = LearnerProfileMerger(store: store);

      // Seed an account row so _resolveLocalAccountId has a FK target to bind.
      // Do NOT seed a learner profile — the merge must INSERT it.
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'test@example.com',
              tier: 'cloudBorn',
              displayName: 'Test Account',
              createdAt: DateTimeFactory.nowUtc(),
              updatedAt: DateTimeFactory.nowUtc(),
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'codec.encode() payload is accepted by the merger and the row lands in DB',
      () async {
        // Build the canonical write payload via the codec — exactly as
        // ProfileRepositoryImpl._toFirestorePayload now does.
        final row = LearnerProfileRow(
          profileId: _remoteProfileId,
          accountId: 1,
          displayName: 'Alice',
          mode: 'adult',
          avatarIndex: 3,
          createdAt: _createdAt,
          updatedAt: _updatedAt,
        );
        final payload = _codec.encode(row);

        // The merger must accept the payload and write it to Drift.
        await merger.merge(profileId: _remoteProfileId, rows: [payload]);

        // Assert: the profile row materialised in the DB — not skipped.
        final profile = await db.profileDao.getProfileById(_remoteProfileId);
        expect(
          profile,
          isNotNull,
          reason:
              'LearnerProfileMerger must INSERT the profile when codec.encode() '
              'payload is fed in — if null, the merge read-keys diverge from the '
              'codec write-keys (the bookmarks-class push↔merge key-contract bug).',
        );
        expect(profile!.displayName, 'Alice');
        expect(profile.mode, 'adult');
        expect(profile.avatarIndex, 3);
        expect(
          profile.updatedAt.toUtc(),
          _updatedAt,
          reason:
              'updated_at must round-trip through the codec and be stored correctly',
        );
      },
    );

    test('currentUpdatedAt is persisted after a successful merge', () async {
      final row = LearnerProfileRow(
        profileId: _remoteProfileId,
        accountId: 1,
        displayName: 'Bob',
        mode: 'child',
        avatarIndex: 0,
        createdAt: _createdAt,
        updatedAt: _updatedAt,
      );
      await merger.merge(
        profileId: _remoteProfileId,
        rows: [_codec.encode(row)],
      );

      final persisted = await store.currentUpdatedAt(
        kind: EntityKind.learnerProfile,
        profileId: _remoteProfileId,
        naturalKey: _remoteProfileId.toString(),
      );
      expect(
        persisted,
        _updatedAt,
        reason:
            'persistUpdatedAt must record the remote updated_at so subsequent '
            'pulls use LWW symmetrically',
      );
    });

    test(
      'a second merge with an older updated_at is skipped (LWW wins local)',
      () async {
        final newer = LearnerProfileRow(
          profileId: _remoteProfileId,
          accountId: 1,
          displayName: 'Carol-new',
          mode: 'adult',
          avatarIndex: 1,
          createdAt: _createdAt,
          updatedAt: _updatedAt,
        );
        await merger.merge(
          profileId: _remoteProfileId,
          rows: [_codec.encode(newer)],
        );

        // Now merge an older version — must not overwrite the newer local row.
        final older = LearnerProfileRow(
          profileId: _remoteProfileId,
          accountId: 1,
          displayName: 'Carol-old',
          mode: 'adult',
          avatarIndex: 2,
          createdAt: _createdAt,
          updatedAt: _updatedAt.subtract(const Duration(minutes: 1)),
        );
        await merger.merge(
          profileId: _remoteProfileId,
          rows: [_codec.encode(older)],
        );

        final profile = await db.profileDao.getProfileById(_remoteProfileId);
        expect(
          profile?.displayName,
          'Carol-new',
          reason: 'LWW: older remote must not overwrite a newer local row',
        );
        expect(profile?.avatarIndex, 1);
      },
    );
  });
}
