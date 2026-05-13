import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/features/sync/domain/merge_rules.dart';

/// LWW merger for bookmark rows.
///
/// Natural key: `(curriculum_id, track_type)`. Remote wins iff its
/// `updated_at` is strictly newer than local (see [remoteIsNewer]) —
/// ties go to local to avoid flapping.
class BookmarkMerger implements EntityMerger {
  BookmarkMerger({required MergeStore store}) : _store = store;

  final MergeStore _store;

  @override
  String get kind => EntityKind.bookmark;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      final naturalKey = '${row['curriculum_id']}|${row['track_type']}';
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
