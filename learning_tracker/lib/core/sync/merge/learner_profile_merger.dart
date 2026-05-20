/// LWW merger for learner profile rows.
///
/// Natural key: `profile_id` (the profile is identifying itself). Remote
/// wins iff its `updated_at` is strictly newer than the local row.
library;

import 'package:learning_tracker/core/sync/codec/learner_profile_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_rules.dart';

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
      final remoteUpdatedAt = decoded?.updatedAt;
      if (!remoteIsNewer(
        localUpdatedAt: localUpdatedAt,
        remoteUpdatedAt: remoteUpdatedAt,
      )) {
        continue;
      }
      await _store.upsert(kind: kind, profileId: profileId, fields: row);
    }
  }
}
