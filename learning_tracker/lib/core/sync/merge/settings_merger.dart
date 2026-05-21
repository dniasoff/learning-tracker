/// LWW merger for per-curriculum settings rows.
///
/// Natural key: `curriculum_id`. Remote wins iff its `updated_at` is
/// strictly newer than the local row; within ±5 s clock skew the
/// Firestore server timestamp (`synced_at`) decides.
///
/// Phase 3: after a successful apply the merger persists the remote
/// `updated_at` via [MergeStore.persistUpdatedAt].
library;

import 'package:learning_tracker/core/sync/codec/settings_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

class SettingsMerger implements EntityMerger {
  SettingsMerger({required MergeStore store}) : _store = store;

  final MergeStore _store;
  static const _codec = SettingsCodec();

  @override
  String get kind => EntityKind.settings;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      final decoded = _codec.decode(row);
      if (decoded == null) continue; // Missing curriculumId — skip.
      final remoteUpdatedAt = decoded.updatedAt;
      if (remoteUpdatedAt == null) continue;

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
        remoteUpdatedAt: remoteUpdatedAt,
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
        updatedAt: remoteUpdatedAt,
        syncedAt: decoded.syncedAt,
      );
    }
  }
}
