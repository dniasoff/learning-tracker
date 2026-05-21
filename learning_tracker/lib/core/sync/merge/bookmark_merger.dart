/// LWW merger for bookmark rows.
///
/// Natural key: `(curriculum_id, track_type)`. Remote wins iff its
/// `updated_at` is strictly newer than local; within ±5 s clock skew the
/// Firestore server timestamp (`synced_at`) decides.
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

      final naturalKey = '${decoded.curriculumId}|${decoded.trackType}';
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
      await _store.upsert(kind: kind, profileId: profileId, fields: row);
      await _store.persistUpdatedAt(
        kind: kind,
        profileId: profileId,
        naturalKey: naturalKey,
        updatedAt: decoded.updatedAt,
        syncedAt: decoded.syncedAt,
      );
    }
  }
}
