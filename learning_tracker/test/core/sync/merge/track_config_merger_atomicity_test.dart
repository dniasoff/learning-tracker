/// AUD-core-sync-08: end-to-end proof that TrackConfigMerger's real
/// production call path — not just the raw MergeStore method — applies the
/// remote row and persists the SyncKv shadow atomically.
///
/// TrackConfigMerger is one of the 5 unguarded sites (no redundant per-DAO
/// LWW guard) named by the audit's correction note as the reliable
/// reproduction target.
@Tags(['unit', 'sync'])
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/track_config_merger.dart';

import '../../../helpers/test_database.dart';

/// Wraps a real [DriftMergeStore] and throws from [persistUpdatedAt] —
/// simulating a crash/failure at the exact point the pre-fix, non-atomic
/// merger code was vulnerable (after the entity write, before the SyncKv
/// shadow write commits).
class _CrashingAfterUpsertStore implements MergeStore {
  _CrashingAfterUpsertStore(this._inner);

  final DriftMergeStore _inner;

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
  }) async {
    throw Exception('simulated crash before persistUpdatedAt commits');
  }

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
  }) => _inner.upsert(kind: kind, profileId: profileId, fields: fields);

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
  Future<T> runInTransaction<T>(Future<T> Function() body) =>
      _inner.runInTransaction(body);
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('TrackConfigMerger — atomic apply (AUD-core-sync-08)', () {
    late UserDatabase db;
    late DriftMergeStore realStore;

    setUp(() async {
      db = UserDatabase(NativeDatabase.memory());
      realStore = DriftMergeStore(db);
      await seedProfile(db);
    });

    tearDown(() async => db.close());

    test('a persistUpdatedAt failure during merge() rolls back the entity '
        'write too — no half-applied track_config row', () async {
      final crashingStore = _CrashingAfterUpsertStore(realStore);
      final merger = TrackConfigMerger(store: crashingStore);

      // weaken-ok: AUD-core-sync-15 (landed after this test) makes
      // TrackConfigMerger isolate a per-row failure (log + continue)
      // instead of letting it propagate out of merge(), so the simulated
      // persistUpdatedAt failure is now swallowed here rather than
      // rethrown — the removed `expect(caught, isNotNull, ...)` assertion
      // tested exception propagation, which AUD-core-sync-15 deliberately
      // changed. What this test verifies (the ROLLBACK below) is
      // orthogonal and still fully asserted: merge() completing without
      // throwing is itself part of the AUD-core-sync-15 contract, not a
      // sign the fault injection failed to fire.
      await merger.merge(
        profileId: 1,
        rows: [
          {
            'curriculum_id': 'mishnayos',
            'state': 'active',
            'activated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            'state_changed_at': DateTime.utc(2026, 5, 1).toIso8601String(),
          },
        ],
      );

      // Before AUD-core-sync-08, upsert() and persistUpdatedAt() were two
      // independent awaited calls: the entity row below would exist even
      // though persistUpdatedAt threw. With the fix, TrackConfigMerger
      // wraps both in runInTransaction, so the entity write rolls back
      // together with the failed shadow write — regardless of whether the
      // resulting exception is later swallowed by AUD-core-sync-15's
      // per-row isolation.
      final rows = await (db.select(
        db.curriculumTracks,
      )..where((t) => t.curriculumId.equals('mishnayos'))).get();
      expect(
        rows,
        isEmpty,
        reason:
            'TrackConfigMerger must not leave the entity row applied when '
            'persisting the LWW shadow fails — both must roll back together',
      );
    });
  });
}
