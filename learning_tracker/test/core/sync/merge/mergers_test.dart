/// Unit tests for the LWW merge implementations:
/// [TrackConfigMerger], [SettingsMerger], [LearnerProfileMerger].
///
/// All three follow the same LWW pattern, so a single fake [MergeStore]
/// works for all.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/learner_profile_merger.dart';
import 'package:learning_tracker/core/sync/merge/settings_merger.dart';
import 'package:learning_tracker/core/sync/merge/track_config_merger.dart';

// ── Fake MergeStore ──────────────────────────────────────────────────────────

class _FakeMergeStore implements MergeStore {
  /// Simulated storage: kind → profileId → naturalKey → updatedAt
  final _timestamps = <String, Map<int, Map<String, DateTime?>>>{};
  final _syncedAt = <String, Map<int, Map<String, DateTime?>>>{};

  /// All upserted rows (for assertion).
  final List<Map<String, dynamic>> upserted = [];

  /// All insertIfAbsent calls.
  final List<Map<String, dynamic>> inserted = [];

  /// All persistUpdatedAt calls.
  final List<Map<String, dynamic>> persisted = [];

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
    persisted.add({
      'kind': kind,
      'profileId': profileId,
      'naturalKey': naturalKey,
      'updatedAt': updatedAt,
      'syncedAt': syncedAt,
    });
  }

  @override
  bool remoteIsNewer({
    required DateTime? localUpdatedAt,
    required DateTime? remoteUpdatedAt,
    DateTime? localSyncedAt,
    DateTime? remoteSyncedAt,
  }) {
    if (remoteUpdatedAt == null) return false;
    if (localUpdatedAt == null) return true;
    // Mirror DriftMergeStore semantics: strict `remote > local` outside
    // the ±5 s window; inside the window, server timestamp decides.
    final diff = remoteUpdatedAt.difference(localUpdatedAt).abs();
    if (diff > const Duration(seconds: 5)) {
      return remoteUpdatedAt.isAfter(localUpdatedAt);
    }
    if (remoteSyncedAt != null && localSyncedAt != null) {
      if (remoteSyncedAt.isAfter(localSyncedAt)) return true;
      if (localSyncedAt.isAfter(remoteSyncedAt)) return false;
    }
    return true;
  }

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
  }) async {
    inserted.add({...fields, '__kind': kind, '__profileId': profileId});
  }

  @override
  Future<T> runInTransaction<T>(Future<T> Function() body) => body();
}

// ── Helpers ──────────────────────────────────────────────────────────────────

DateTime _dt(int year, [int month = 1, int day = 1]) =>
    DateTime.utc(year, month, day);

// ── TrackConfigMerger ────────────────────────────────────────────────────────

void main() {
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

  // ── SettingsMerger ────────────────────────────────────────────────────────

  group('SettingsMerger', () {
    late _FakeMergeStore store;
    late SettingsMerger merger;

    setUp(() {
      store = _FakeMergeStore();
      merger = SettingsMerger(store: store);
    });

    test('kind is "settings"', () {
      expect(merger.kind, EntityKind.settings);
    });

    test('upserts when remote is newer', () async {
      await merger.merge(
        profileId: 1,
        rows: [
          {
            'curriculum_id': 'mishnayos',
            'updated_at': _dt(2026).toIso8601String(),
          },
        ],
      );

      expect(store.upserted, hasLength(1));
    });

    test('skips when remote is older than local', () async {
      store.seedTimestamp(
        kind: EntityKind.settings,
        profileId: 1,
        naturalKey: 'mishnayos',
        at: _dt(2027),
      );

      await merger.merge(
        profileId: 1,
        rows: [
          {
            'curriculum_id': 'mishnayos',
            'updated_at': _dt(2026).toIso8601String(),
          },
        ],
      );

      expect(store.upserted, isEmpty);
    });

    test('skips row when curriculum_id is missing', () async {
      // SettingsCodec.decode returns null when curriculum_id is absent.
      // The merger skips null-decode rows; no upsert occurs.
      await merger.merge(
        profileId: 1,
        rows: [
          {
            // No curriculum_id — codec returns null → skip
            'updated_at': _dt(2026).toIso8601String(),
          },
        ],
      );
      expect(store.upserted, isEmpty);
    });

    test('accepts DateTime object as updated_at', () async {
      await merger.merge(
        profileId: 1,
        rows: [
          {
            'curriculum_id': 'bavli',
            'updated_at': _dt(2026), // DateTime
          },
        ],
      );
      expect(store.upserted, hasLength(1));
    });
  });

  // ── LearnerProfileMerger ─────────────────────────────────────────────────

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
