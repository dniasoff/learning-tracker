/// LWW merger for learner profile rows.
///
/// Natural key: `profile_id` (the profile is identifying itself). Remote
/// wins iff its `updated_at` is strictly newer than the local row; within
/// ±5 s clock skew the Firestore server timestamp (`synced_at`) decides.
///
/// Phase 3: after a successful apply the merger persists the remote
/// `updated_at` via [MergeStore.persistUpdatedAt].
library;

import 'package:learning_tracker/core/sync/codec/learner_profile_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

class LearnerProfileMerger implements EntityMerger {
  LearnerProfileMerger({required MergeStore store}) : _store = store;

  final MergeStore _store;
  static const _codec = LearnerProfileCodec();

  @override
  String get kind => EntityKind.learnerProfile;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      final decoded = _codec.decode(row);
      // Fall back to caller's profileId when profile_id is absent.
      final naturalKey = decoded != null
          ? decoded.profileId.toString()
          : profileId.toString();

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
      final remoteUpdatedAt = decoded?.updatedAt;
      if (!_store.remoteIsNewer(
        localUpdatedAt: localUpdatedAt,
        remoteUpdatedAt: remoteUpdatedAt,
        localSyncedAt: localSyncedAt,
        remoteSyncedAt: decoded?.syncedAt,
      )) {
        continue;
      }
      await _store.upsert(kind: kind, profileId: profileId, fields: row);
      if (remoteUpdatedAt != null) {
        await _store.persistUpdatedAt(
          kind: kind,
          profileId: profileId,
          naturalKey: naturalKey,
          updatedAt: remoteUpdatedAt,
          syncedAt: decoded?.syncedAt,
        );
      }
    }
  }
}
