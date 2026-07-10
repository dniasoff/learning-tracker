/// LWW merger for bookmark rows.
///
/// Natural key: `curriculum_id` (one track per profile + curriculum). Remote
/// wins iff its `updated_at` is strictly newer than local; within ±5 s clock
/// skew the Firestore server timestamp (`synced_at`) decides.
///
/// Phase 3: after a successful apply the merger persists the remote
/// `updated_at` via [MergeStore.persistUpdatedAt] so subsequent pulls
/// arbitrate symmetrically (local edits between pulls are no longer lost).
library;

import 'package:learning_tracker/core/sync/codec/bookmark_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

class BookmarkMerger implements EntityMerger {
  BookmarkMerger({required MergeStore store}) : _store = store;

  final MergeStore _store;
  static const _codec = BookmarkCodec();

  @override
  String get kind => EntityKind.bookmark;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      final decoded = _codec.decode(row);
      if (decoded == null) continue; // Malformed row — skip.

      final naturalKey = decoded.curriculumId;
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
        remoteUpdatedAt: decoded.updatedAt,
        localSyncedAt: localSyncedAt,
        remoteSyncedAt: decoded.syncedAt,
      )) {
        continue;
      }
      // AUD-core-sync-08: apply + persist the LWW shadow atomically so a
      // process death between the two can never leave a stale SyncKv
      // timestamp that silently lets a later remote pull clobber a newer
      // local edit (DB-2).
      await _store.runInTransaction(() async {
        await _store.upsert(kind: kind, profileId: profileId, fields: row);
        await _store.persistUpdatedAt(
          kind: kind,
          profileId: profileId,
          naturalKey: naturalKey,
          updatedAt: decoded.updatedAt,
          syncedAt: decoded.syncedAt,
        );
      });
    }
  }
}
