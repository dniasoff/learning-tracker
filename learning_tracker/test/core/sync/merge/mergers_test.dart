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

  /// All upserted rows (for assertion).
  final List<Map<String, dynamic>> upserted = [];

  /// All insertIfAbsent calls.
  final List<Map<String, dynamic>> inserted = [];

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

    test('upserts row when no local timestamp (remote always wins)', () async {
      await merger.merge(
        profileId: 1,
        rows: [
          {
            'curriculum_id': 'bavli',
            'track_type': 'personal',
            'updated_at': _dt(2026).toIso8601String(),
          },
        ],
      );

      expect(store.upserted, hasLength(1));
    });

    test('upserts row when remote is newer than local', () async {
      store.seedTimestamp(
        kind: EntityKind.trackConfig,
        profileId: 1,
        naturalKey: 'bavli|personal',
        at: _dt(2025),
      );

      await merger.merge(
        profileId: 1,
        rows: [
          {
            'curriculum_id': 'bavli',
            'track_type': 'personal',
            'updated_at': _dt(2026).toIso8601String(),
          },
        ],
      );

      expect(store.upserted, hasLength(1));
    });

    test('skips row when remote is older than local', () async {
      store.seedTimestamp(
        kind: EntityKind.trackConfig,
        profileId: 1,
        naturalKey: 'bavli|personal',
        at: _dt(2026),
      );

      await merger.merge(
        profileId: 1,
        rows: [
          {
            'curriculum_id': 'bavli',
            'track_type': 'personal',
            'updated_at': _dt(2025).toIso8601String(), // older
          },
        ],
      );

      expect(store.upserted, isEmpty);
    });

    test('skips row when remote updated_at is null', () async {
      await merger.merge(
        profileId: 1,
        rows: [
          {
            'curriculum_id': 'bavli',
            'track_type': 'personal',
            // no updated_at
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
            'track_type': 'personal',
            'updated_at': _dt(2026), // DateTime, not String
          },
        ],
      );

      expect(store.upserted, hasLength(1));
    });

    test('processes multiple rows independently', () async {
      store.seedTimestamp(
        kind: EntityKind.trackConfig,
        profileId: 1,
        naturalKey: 'bavli|personal',
        at: _dt(2026),
      );

      await merger.merge(
        profileId: 1,
        rows: [
          {
            'curriculum_id': 'bavli',
            'track_type': 'personal',
            'updated_at': _dt(2025).toIso8601String(), // skip — older
          },
          {
            'curriculum_id': 'mishnayos',
            'track_type': 'personal',
            'updated_at': _dt(2026).toIso8601String(), // upsert — no local
          },
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

    test('handles null curriculum_id by using empty string key', () async {
      await merger.merge(
        profileId: 1,
        rows: [
          {
            // No curriculum_id
            'updated_at': _dt(2026).toIso8601String(),
          },
        ],
      );
      // Should upsert with naturalKey=''
      expect(store.upserted, hasLength(1));
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

    test('upserts when no local row exists', () async {
      await merger.merge(
        profileId: 1,
        rows: [
          {
            'profile_id': 1,
            'display_name': 'Alice',
            'updated_at': _dt(2026).toIso8601String(),
          },
        ],
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
        rows: [
          {
            'profile_id': 1,
            'display_name': 'Bob',
            'updated_at': _dt(2026).toIso8601String(),
          },
        ],
      );
      expect(store.upserted, isEmpty);
    });

    test('falls back to profileId when row has no profile_id', () async {
      // profile_id absent in row → uses profileId=1 as natural key
      await merger.merge(
        profileId: 1,
        rows: [
          {
            'display_name': 'Fallback',
            'updated_at': _dt(2026).toIso8601String(),
          },
        ],
      );
      expect(store.upserted, hasLength(1));
    });

    test('accepts DateTime object as updated_at', () async {
      await merger.merge(
        profileId: 1,
        rows: [
          {
            'profile_id': 1,
            'updated_at': _dt(2026), // DateTime, not String
          },
        ],
      );
      expect(store.upserted, hasLength(1));
    });

    test('skips row when updated_at is null', () async {
      await merger.merge(
        profileId: 1,
        rows: [
          {'profile_id': 1},
        ],
      );
      expect(store.upserted, isEmpty);
    });
  });
}
