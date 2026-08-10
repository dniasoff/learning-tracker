/// LWW merger for per-curriculum settings rows.
///
/// Natural key: `curriculum_id`. Remote wins iff its `updated_at` is
/// strictly newer than the local row; within ±5 s clock skew the
/// Firestore server timestamp (`synced_at`) decides.
///
/// Phase 3: after a successful apply the merger persists the remote
/// `updated_at` via [MergeStore.persistUpdatedAt].
library;

import 'package:learning_tracker/core/ids/natural_key.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/codec/settings_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

class SettingsMerger implements EntityMerger {
  SettingsMerger({required MergeStore store, AppLogger? logger})
    : _store = store,
      _logger = logger;

  final MergeStore _store;
  // AUD-core-sync-15: optional logger so a per-row merge failure is
  // observable instead of silently swallowed.
  final AppLogger? _logger;
  static const _codec = SettingsCodec();

  @override
  String get kind => EntityKind.settings;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      // AUD-core-sync-15: isolate each row — mirrors LearnerProfileMerger.
      try {
        final decoded = _codec.decode(row);
        if (decoded == null) continue; // Missing curriculumId — skip.
        final remoteUpdatedAt = decoded.updatedAt;
        if (remoteUpdatedAt == null) continue;

        // AUD-core-ids-01: route through NaturalKey.forSettings instead of
        // using the raw curriculumId.
        final naturalKey = NaturalKey.forSettings(
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
          event: 'sync_settings_merge_row_failed',
          fields: {'profile_id': profileId},
          exception: e,
          stackTrace: stackTrace,
        );
      }
    }
  }
}
