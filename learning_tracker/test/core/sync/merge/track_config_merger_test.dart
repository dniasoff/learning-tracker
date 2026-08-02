/// Unit tests for [TrackConfigMerger]: fake-store LWW unit tests, Phase-3
/// LWW symmetry + persistUpdatedAt against a real [DriftMergeStore], and the
/// codec.encode() -> merger -> DB round-trip (Phase B invariant).
///
/// AG-5 (AUD-app-05): consolidates test/core/sync/merge/mergers_test.dart's
/// TrackConfigMerger group, test/sync/merge/lww_symmetric_test.dart's
/// TrackConfigMerger group, test/sync/merge/persist_updated_at_test.dart's
/// TrackConfigMerger case, and test/sync/merge/curriculum_tracks_roundtrip_test.dart
/// into the single file mirroring lib/core/sync/merge/track_config_merger.dart.
library;

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/track_codec.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/track_config_merger.dart';
import 'package:learning_tracker/data/firestore/conflict.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';

class _FakeMergeStore implements MergeStore {
  /// Simulated storage: kind → profileId → naturalKey → updatedAt
  final _timestamps = <String, Map<int, Map<String, DateTime?>>>{};
  final _syncedAt = <String, Map<int, Map<String, DateTime?>>>{};

  /// All upserted rows (for assertion).
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
  }) async {
    return _timestamps[kind]?[profileId]?[naturalKey];
  }

  @override
  Future<DateTime?> currentSyncedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  }) async {
    return _syncedAt[kind]?[profileId]?[naturalKey];
  }

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

  // AUD-t-cross-68 / AD-7: delegates to the single canonical predicate
  // instead of re-deriving it by hand, so this fake cannot drift from D15
  // semantics.
  @override
  bool remoteIsNewer({
    required DateTime? localUpdatedAt,
    required DateTime? remoteUpdatedAt,
    DateTime? localSyncedAt,
    DateTime? remoteSyncedAt,
  }) => canonicalRemoteIsNewer(
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

DateTime _dt(int year, [int month = 1, int day = 1]) =>
    DateTime.utc(year, month, day);

// ── Phase 3 LWW-symmetry / persistUpdatedAt timestamps ──────────────────────
final _local = DateTime.utc(2026, 5, 21, 12, 0, 0);
final _remoteNewer = DateTime.utc(2026, 5, 21, 13, 0, 0);
final _remoteOlder = DateTime.utc(2026, 5, 21, 11, 0, 0);
final _localSkew = DateTime.utc(2026, 5, 21, 12, 0, 0);
final _remoteSkew = DateTime.utc(2026, 5, 21, 12, 0, 2);
final _localSynced = DateTime.utc(2026, 5, 21, 12, 0, 5);
final _remoteSyncedNewer = DateTime.utc(2026, 5, 21, 12, 0, 10);
const _profileId = 1;
final _ts = DateTime.utc(2026, 5, 21, 12, 0, 0);
final _syncedAt = DateTime.utc(2026, 5, 21, 12, 0, 30);

// ── codec.encode() → merger → DB round-trip fixtures ─────────────────────────
const _codec = TrackCodec();
const _curriculumId = 'bavli';
final _activatedAt = DateTime.utc(2026, 1, 1);
final _stateChangedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);
final _olderStateChangedAt = DateTime.utc(2026, 6, 18, 9, 0, 0);

/// Build a minimal [TrackRow] for the test curriculum.
TrackRow _row({
  int profileId = _profileId,
  int trackId = 1,
  String curriculumId = _curriculumId,
  String state = 'active',
  DateTime? stateChangedAt,
  DateTime? paceResetDate,
}) => TrackRow(
  profileId: profileId,
  trackId: trackId,
  curriculumId: curriculumId,
  state: state,
  activatedAt: _activatedAt,
  stateChangedAt: stateChangedAt ?? _stateChangedAt,
  paceResetDate: paceResetDate,
);

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  // ── TrackConfigMerger — fake-store unit tests ────────────────────────────
  group('TrackConfigMerger', () {
    late _FakeMergeStore store;
    late TrackConfigMerger merger;

    setUp(() {
      store = _FakeMergeStore();
      merger = TrackConfigMerger(store: store);
    });

    test('kind is "track_config"', () {
      expect(merger.kind, EntityKind.trackConfig);
    });

    // W3.22: trackType removed; natural key is now just curriculum_id.
    // W3.28: state_changed_at is the LWW timestamp; activated_at is required.

    /// Minimal valid row for TrackCodec.decode: curriculum_id + activated_at
    /// required; state_changed_at used as LWW key (falls back to activated_at).
    Map<String, dynamic> trackRow({
      String curriculumId = 'bavli',
      required DateTime activatedAt,
      DateTime? stateChangedAt,
    }) => {
      'curriculum_id': curriculumId,
      'activated_at': activatedAt.toIso8601String(),
      if (stateChangedAt != null)
        'state_changed_at': stateChangedAt.toIso8601String(),
    };

    test('upserts row when no local timestamp (remote always wins)', () async {
      await merger.merge(
        profileId: 1,
        rows: [trackRow(activatedAt: _dt(2025), stateChangedAt: _dt(2026))],
      );

      expect(store.upserted, hasLength(1));
    });

    test('upserts row when remote is newer than local', () async {
      // W3.22: natural key is just 'bavli' (no trackType component).
      store.seedTimestamp(
        kind: EntityKind.trackConfig,
        profileId: 1,
        naturalKey: 'bavli',
        at: _dt(2025),
      );

      await merger.merge(
        profileId: 1,
        rows: [trackRow(activatedAt: _dt(2025), stateChangedAt: _dt(2026))],
      );

      expect(store.upserted, hasLength(1));
    });

    test('skips row when remote is older than local', () async {
      store.seedTimestamp(
        kind: EntityKind.trackConfig,
        profileId: 1,
        naturalKey: 'bavli',
        at: _dt(2026),
      );

      await merger.merge(
        profileId: 1,
        rows: [
          trackRow(
            activatedAt: _dt(2024),
            stateChangedAt: _dt(2025), // older than local 2026
          ),
        ],
      );

      expect(store.upserted, isEmpty);
    });

    test(
      'skips row when required fields are missing (no activated_at)',
      () async {
        await merger.merge(
          profileId: 1,
          rows: [
            {
              'curriculum_id': 'bavli',
              // no activated_at — TrackCodec.decode returns null → skip
            },
          ],
        );

        expect(store.upserted, isEmpty);
      },
    );

    test('accepts DateTime object as state_changed_at', () async {
      await merger.merge(
        profileId: 1,
        rows: [
          {
            'curriculum_id': 'bavli',
            'activated_at': _dt(2025), // DateTime object (not String)
            'state_changed_at': _dt(2026), // DateTime object
          },
        ],
      );

      expect(store.upserted, hasLength(1));
    });

    test('processes multiple rows independently', () async {
      store.seedTimestamp(
        kind: EntityKind.trackConfig,
        profileId: 1,
        naturalKey: 'bavli',
        at: _dt(2026),
      );

      await merger.merge(
        profileId: 1,
        rows: [
          trackRow(
            curriculumId: 'bavli',
            activatedAt: _dt(2024),
            stateChangedAt: _dt(2025), // skip — older than local 2026
          ),
          trackRow(
            curriculumId: 'mishnayos',
            activatedAt: _dt(2025),
            stateChangedAt: _dt(2026), // upsert — no local for mishnayos
          ),
        ],
      );

      expect(store.upserted, hasLength(1));
    });
  });

  group(
    'TrackConfigMerger — LWW symmetry + persistence (real DriftMergeStore)',
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

      group('TrackConfigMerger', () {
        late TrackConfigMerger merger;

        setUp(() {
          merger = TrackConfigMerger(store: store);
        });

        Map<String, dynamic> row({
          required DateTime stateChangedAt,
          DateTime? syncedAt,
        }) => {
          'curriculum_id': 'bavli',
          'state': 'active',
          'activated_at': stateChangedAt.toIso8601String(),
          'state_changed_at': stateChangedAt.toIso8601String(),
          if (syncedAt != null) 'synced_at': syncedAt.toIso8601String(),
        };

        test('remote newer than local → applies', () async {
          await store.persistUpdatedAt(
            kind: EntityKind.trackConfig,
            profileId: profileId,
            naturalKey: 'bavli',
            updatedAt: _local,
          );

          await merger.merge(
            profileId: profileId,
            rows: [row(stateChangedAt: _remoteNewer)],
          );

          final after = await store.currentUpdatedAt(
            kind: EntityKind.trackConfig,
            profileId: profileId,
            naturalKey: 'bavli',
          );
          expect(after, _remoteNewer);
        });

        test('local newer than remote → does NOT apply', () async {
          await store.persistUpdatedAt(
            kind: EntityKind.trackConfig,
            profileId: profileId,
            naturalKey: 'bavli',
            updatedAt: _local,
          );

          await merger.merge(
            profileId: profileId,
            rows: [row(stateChangedAt: _remoteOlder)],
          );

          final after = await store.currentUpdatedAt(
            kind: EntityKind.trackConfig,
            profileId: profileId,
            naturalKey: 'bavli',
          );
          expect(after, _local);
        });

        test('within ±5 s — remote synced_at newer → applies', () async {
          await store.persistUpdatedAt(
            kind: EntityKind.trackConfig,
            profileId: profileId,
            naturalKey: 'bavli',
            updatedAt: _localSkew,
            syncedAt: _localSynced,
          );

          await merger.merge(
            profileId: profileId,
            rows: [
              row(stateChangedAt: _remoteSkew, syncedAt: _remoteSyncedNewer),
            ],
          );

          final after = await store.currentUpdatedAt(
            kind: EntityKind.trackConfig,
            profileId: profileId,
            naturalKey: 'bavli',
          );
          expect(after, _remoteSkew);
        });
      });

      test('TrackConfigMerger', () async {
        await TrackConfigMerger(store: store).merge(
          profileId: _profileId,
          rows: [
            {
              'curriculum_id': 'bavli',
              'state': 'active',
              'activated_at': _ts.toIso8601String(),
              'state_changed_at': _ts.toIso8601String(),
              'synced_at': _syncedAt.toIso8601String(),
            },
          ],
        );

        final updatedAt = await store.currentUpdatedAt(
          kind: EntityKind.trackConfig,
          profileId: _profileId,
          naturalKey: 'bavli',
        );
        expect(updatedAt, _ts);
      });
    },
  );

  group('curriculum_tracks — codec.encode() → merger → DB round-trip', () {
    late UserDatabase db;
    late DriftMergeStore store;
    late TrackConfigMerger merger;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = UserDatabase(NativeDatabase.memory());
      store = DriftMergeStore(db);
      merger = TrackConfigMerger(store: store);

      // Seed account + profile so FK constraints on curriculum_tracks hold.
      await seedProfile(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'codec.encode() payload is accepted by the merger and the row lands in DB',
      () async {
        // Build the canonical write payload via the codec — exactly as the
        // three live writers now do after Phase B.
        final payload = _codec.encode(_row());

        // The merger must accept the payload and write it to Drift.
        await merger.merge(profileId: _profileId, rows: [payload]);

        // Assert: the track row materialised in the DB — not skipped.
        final track =
            await (db.select(db.curriculumTracks)..where(
                  (t) =>
                      t.profileId.equals(_profileId) &
                      t.curriculumId.equals(_curriculumId),
                ))
                .getSingleOrNull();

        expect(
          track,
          isNotNull,
          reason:
              'TrackConfigMerger must INSERT the row when codec.encode() payload '
              'is fed in — if null the merge read-keys diverge from the codec '
              'write-keys (the push↔merge key-contract bug).',
        );
        expect(track!.curriculumId, _curriculumId);
        expect(track.state, 'active');
        expect(
          track.stateChangedAt.toUtc(),
          _stateChangedAt,
          reason: 'state_changed_at must round-trip through the codec',
        );
        expect(
          track.activatedAt.toUtc(),
          _activatedAt,
          reason: 'activated_at must round-trip through the codec',
        );
      },
    );

    test(
      'state_changed_at is persisted as LWW timestamp after merge',
      () async {
        await merger.merge(
          profileId: _profileId,
          rows: [_codec.encode(_row())],
        );

        final persisted = await store.currentUpdatedAt(
          kind: EntityKind.trackConfig,
          profileId: _profileId,
          naturalKey: _curriculumId,
        );
        expect(
          persisted,
          _stateChangedAt,
          reason:
              'persistUpdatedAt must record state_changed_at so subsequent '
              'pulls arbitrate LWW symmetrically',
        );
      },
    );

    test(
      'a second merge with an older state_changed_at is skipped (LWW wins local)',
      () async {
        // First: merge a newer row with state='active'.
        await merger.merge(
          profileId: _profileId,
          rows: [_codec.encode(_row(state: 'active'))],
        );

        // Then: try to merge an older row with state='retired' — must be ignored.
        await merger.merge(
          profileId: _profileId,
          rows: [
            _codec.encode(
              _row(state: 'retired', stateChangedAt: _olderStateChangedAt),
            ),
          ],
        );

        final track =
            await (db.select(db.curriculumTracks)..where(
                  (t) =>
                      t.profileId.equals(_profileId) &
                      t.curriculumId.equals(_curriculumId),
                ))
                .getSingleOrNull();

        expect(
          track?.state,
          'active',
          reason:
              'LWW: older remote must not overwrite a newer local row — '
              'state should remain "active" after the stale merge',
        );
      },
    );

    test('optional pace_reset_date round-trips correctly', () async {
      final paceReset = DateTime.utc(2026, 3, 15);
      final payload = _codec.encode(_row(paceResetDate: paceReset));

      await merger.merge(profileId: _profileId, rows: [payload]);

      final track =
          await (db.select(db.curriculumTracks)..where(
                (t) =>
                    t.profileId.equals(_profileId) &
                    t.curriculumId.equals(_curriculumId),
              ))
              .getSingleOrNull();

      expect(
        track?.paceResetDate?.toUtc(),
        paceReset,
        reason: 'pace_reset_date is optional but must round-trip when present',
      );
    });

    test(
      'encode() emits profile_id and track_id (Phase B canonical fields)',
      () {
        final payload = _codec.encode(_row(profileId: 7, trackId: 42));

        expect(
          payload['profile_id'],
          7,
          reason:
              'Phase B: encode() must emit profile_id so live writers '
              'no longer need to inject it separately',
        );
        expect(
          payload['track_id'],
          42,
          reason:
              'Phase B: encode() must emit track_id so live writers '
              'no longer need to inject it separately',
        );
      },
    );
  });
}
