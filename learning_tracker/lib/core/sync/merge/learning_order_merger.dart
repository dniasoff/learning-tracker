/// LWW merger for per-curriculum learning-order rows (W2.26 / closes C3/H3).
///
/// Each row has a natural key of `curriculum_id + '|' + sefaria_ref`.
/// Remote wins iff its `updated_at` is strictly newer than the local row;
/// within ±5 s clock skew the Firestore server timestamp (`synced_at`)
/// decides.
///
/// Phase 3: after a successful apply the merger persists the remote
/// `updated_at` via [MergeStore.persistUpdatedAt].
library;

import 'package:learning_tracker/core/sync/codec/learning_order_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

class LearningOrderMerger implements EntityMerger {
  LearningOrderMerger({required MergeStore store}) : _store = store;

  final MergeStore _store;
  static const _codec = LearningOrderCodec();

  @override
  String get kind => EntityKind.learningOrder;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      final decoded = _codec.decode(row);
      if (decoded == null) continue; // Missing curriculumId/sefariaRef — skip.
      final remoteUpdatedAt = decoded.updatedAt;
      if (remoteUpdatedAt == null) continue;

      final naturalKey = '${decoded.curriculumId}|${decoded.sefariaRef}';
      final localUpdatedAt = await _store.currentUpdatedAt(
        kind: kind,
        profileId: profileId,
        naturalKey: naturalKey,
      );
      final localSyncedAt = await _store.currentSyncedAt(
        kind: kind,
        profileId: profileId,
        naturalKey: naturalKey,
      );
      if (!_store.remoteIsNewer(
        localUpdatedAt: localUpdatedAt,
        remoteUpdatedAt: remoteUpdatedAt,
        localSyncedAt: localSyncedAt,
        remoteSyncedAt: decoded.syncedAt,
      )) {
        continue;
      }
      // AUD-core-sync-08: apply + persist the LWW shadow atomically — see
      // BookmarkMerger for the crash-mid-sequence rationale.
      await _store.runInTransaction(() async {
        await _store.upsert(kind: kind, profileId: profileId, fields: row);
        await _store.persistUpdatedAt(
          kind: kind,
          profileId: profileId,
          naturalKey: naturalKey,
          updatedAt: remoteUpdatedAt,
          syncedAt: decoded.syncedAt,
        );
      });
    }
  }
}
