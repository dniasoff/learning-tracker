import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_rules.dart';

/// LWW merger for learner profile rows.
///
/// Natural key: `profile_id` (the profile is identifying itself). Remote
/// wins iff its `updated_at` is strictly newer than the local row.
class LearnerProfileMerger implements EntityMerger {
  LearnerProfileMerger({required MergeStore store}) : _store = store;

  final MergeStore _store;

  @override
  String get kind => EntityKind.learnerProfile;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      final naturalKey = (row['profile_id'] ?? profileId).toString();
      final localUpdatedAt = await _store.currentUpdatedAt(
        kind: kind,
        profileId: profileId,
        naturalKey: naturalKey,
      );
      final remoteUpdatedAt = _parseUpdatedAt(row['updated_at']);
      if (!remoteIsNewer(
        localUpdatedAt: localUpdatedAt,
        remoteUpdatedAt: remoteUpdatedAt,
      )) {
        continue;
      }
      await _store.upsert(kind: kind, profileId: profileId, fields: row);
    }
  }

  DateTime? _parseUpdatedAt(Object? raw) {
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}
