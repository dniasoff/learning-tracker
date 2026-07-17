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

import 'package:learning_tracker/core/ids/natural_key.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/codec/bookmark_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

class BookmarkMerger implements EntityMerger {
  BookmarkMerger({required MergeStore store, AppLogger? logger})
    : _store = store,
      _logger = logger;

  final MergeStore _store;
  // AUD-core-sync-15: optional logger so a per-row merge failure is
  // observable instead of silently swallowed.
  final AppLogger? _logger;
  static const _codec = BookmarkCodec();

  @override
  String get kind => EntityKind.bookmark;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      // AUD-core-sync-15: isolate each row. A single malformed/throwing row
      // must never abort the whole page — mirrors LearnerProfileMerger's
      // existing guard.
      try {
        final decoded = _codec.decode(row);
        if (decoded == null) continue; // Malformed row — skip.

        // AUD-core-ids-01: route through NaturalKey.forBookmark instead of
        // using the raw curriculumId.
        final naturalKey = NaturalKey.forBookmark(
          curriculumId: decoded.curriculumId,
        ).value;
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
      } on Exception catch (e, stackTrace) {
        _logger?.warning(
          event: 'sync_bookmark_merge_row_failed',
          fields: {'profile_id': profileId},
          exception: e,
          stackTrace: stackTrace,
        );
      }
    }
  }
}
