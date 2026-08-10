/// Unit tests for lib/core/sync/merge/entity_merger.dart: the [EntityKind]
/// taxonomy and the [EntityMerger] / [MergeStore] abstract contracts.
///
/// [MergeRouter]'s exhaustive switch and every concrete [EntityMerger] are
/// exercised by their own mirrored tests (e.g.
/// test/core/sync/merge/merge_router_test.dart,
/// test/core/sync/merge/track_config_merger_test.dart, ...); this file
/// covers only what belongs to entity_merger.dart itself — the kind
/// taxonomy's invariants and the abstract contract shape.
///
/// AG-5 (AUD-app-05): new file — no prior mirrored or unmirrored test
/// existed for lib/core/sync/merge/entity_merger.dart.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// Minimal concrete [EntityMerger] used only to prove the abstract contract
/// is implementable and callable — mirrors the "Usage pattern" doc example
/// on [EntityCodec] but for the merge side.
class _NoopMerger implements EntityMerger {
  const _NoopMerger();

  @override
  String get kind => EntityKind.bookmark;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {}
}

/// Minimal concrete [MergeStore] used only to prove the abstract contract
/// is implementable.
class _NoopStore implements MergeStore {
  const _NoopStore();

  @override
  Future<DateTime?> currentUpdatedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  }) async => null;

  @override
  Future<DateTime?> currentSyncedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  }) async => null;

  @override
  Future<void> persistUpdatedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
    required DateTime updatedAt,
    DateTime? syncedAt,
  }) async {}

  @override
  bool remoteIsNewer({
    required DateTime? localUpdatedAt,
    required DateTime? remoteUpdatedAt,
    DateTime? localSyncedAt,
    DateTime? remoteSyncedAt,
  }) => remoteUpdatedAt != null;

  @override
  Future<void> upsert({
    required String kind,
    required int profileId,
    required Map<String, dynamic> fields,
  }) async {}

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

void main() {
  group('EntityKind.all', () {
    test('every kind constant appears exactly once in EntityKind.all', () {
      const expected = [
        EntityKind.completion,
        EntityKind.streak,
        EntityKind.learnerProfile,
        EntityKind.trackConfig,
        EntityKind.bookmark,
        EntityKind.settings,
        EntityKind.stageDefinition,
        EntityKind.profileProgram,
        EntityKind.learningOrder,
        EntityKind.goal,
        EntityKind.learningLedger,
        EntityKind.notificationSettings,
        EntityKind.gamificationSettings,
        EntityKind.uiPreferences,
        EntityKind.tutorGrant,
        EntityKind.studyDayConfig,
        EntityKind.pointsLedger,
        EntityKind.rewardRedemption,
      ];
      expect(EntityKind.all, expected);
    });

    test('EntityKind.all has no duplicate entries', () {
      expect(EntityKind.all.toSet().length, EntityKind.all.length);
    });

    test('no kind constant is an empty string', () {
      for (final kind in EntityKind.all) {
        expect(kind, isNotEmpty);
      }
    });

    test('kind constants are all distinct snake_case strings', () {
      final asSet = EntityKind.all.toSet();
      expect(asSet.length, EntityKind.all.length);
      for (final kind in asSet) {
        expect(
          kind,
          matches(RegExp(r'^[a-z][a-z_]*[a-z]$')),
          reason: '"$kind" should be a snake_case identifier',
        );
      }
    });
  });

  group('EntityMerger contract', () {
    test('a concrete implementation exposes its kind', () {
      const merger = _NoopMerger();
      expect(merger.kind, EntityKind.bookmark);
    });

    test('merge() is callable and returns a Future<void>', () async {
      const merger = _NoopMerger();
      await expectLater(merger.merge(profileId: 1, rows: const []), completes);
    });
  });

  group('MergeStore contract', () {
    test(
      'a concrete implementation satisfies every method signature',
      () async {
        const store = _NoopStore();
        expect(
          await store.currentUpdatedAt(
            kind: EntityKind.bookmark,
            profileId: 1,
            naturalKey: 'k',
          ),
          isNull,
        );
        expect(
          await store.currentSyncedAt(
            kind: EntityKind.bookmark,
            profileId: 1,
            naturalKey: 'k',
          ),
          isNull,
        );
        expect(
          store.remoteIsNewer(
            localUpdatedAt: null,
            remoteUpdatedAt: DateTime.utc(2026),
          ),
          isTrue,
        );
        await expectLater(
          store.persistUpdatedAt(
            kind: EntityKind.bookmark,
            profileId: 1,
            naturalKey: 'k',
            updatedAt: DateTime.utc(2026),
          ),
          completes,
        );
        await expectLater(
          store.upsert(
            kind: EntityKind.bookmark,
            profileId: 1,
            fields: const {},
          ),
          completes,
        );
        await expectLater(
          store.insertIfAbsent(
            kind: EntityKind.bookmark,
            profileId: 1,
            naturalKey: 'k',
            fields: const {},
          ),
          completes,
        );
      },
    );
  });
}
