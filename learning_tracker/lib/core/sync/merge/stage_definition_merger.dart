/// LWW merger for stage definitions.
///
/// Closes T1.9: every configurable field on a stage is merged, not just
/// delay configuration. The full set is:
///   `stage_name`, `stage_order`, `schedule` (JSON), `is_default`.
///
/// W3.27: schedule quartet replaced by JSON `schedule` column.
/// Natural key: `(curriculum_id, track_id, stage_order)`. Remote wins iff
/// its `updated_at` is strictly newer than the local row; within ±5 s
/// clock skew the Firestore server timestamp (`synced_at`) decides.
///
/// Phase 3: after a successful apply the merger persists the remote
/// `updated_at` via [MergeStore.persistUpdatedAt].
library;

import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/codec/stage_definition_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

class StageDefinitionMerger implements EntityMerger {
  StageDefinitionMerger({required MergeStore store, AppLogger? logger})
    : _store = store,
      _logger = logger;

  final MergeStore _store;
  // AUD-core-sync-15: optional logger so a per-row merge failure is
  // observable instead of silently swallowed.
  final AppLogger? _logger;
  static const _codec = StageDefinitionCodec();

  @override
  String get kind => EntityKind.stageDefinition;

  /// All fields preserved through a merge. See T1.9 in the rebuild plan.
  /// W3.27: schedule quartet collapsed to single JSON `schedule` field.
  static const List<String> mergedFields = [
    'stage_name',
    'stage_order',
    'schedule',
    'is_default',
  ];

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      // AUD-core-sync-15: isolate each row — mirrors LearnerProfileMerger.
      try {
        final decoded = _codec.decode(row);
        if (decoded == null) continue; // Missing required fields — skip.
        final remoteUpdatedAt = decoded.updatedAt;
        if (remoteUpdatedAt == null) continue;

        final naturalKey =
            '${decoded.curriculumId}|${decoded.trackId}|${decoded.stageOrder}';
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
      } on Exception catch (e, stackTrace) {
        _logger?.warning(
          event: 'sync_stage_definition_merge_row_failed',
          fields: {'profile_id': profileId},
          exception: e,
          stackTrace: stackTrace,
        );
      }
    }
  }
}
