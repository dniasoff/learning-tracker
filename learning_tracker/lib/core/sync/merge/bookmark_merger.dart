/// LWW merger for bookmark rows.
///
/// Natural key: `(curriculum_id, track_type)`. Remote wins iff its
/// `updated_at` is strictly newer than local (see [remoteIsNewer]) —
/// ties go to local to avoid flapping.
library;

import 'package:learning_tracker/core/sync/codec/bookmark_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_rules.dart';

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
      if (!remoteIsNewer(
        localUpdatedAt: localUpdatedAt,
        remoteUpdatedAt: decoded.updatedAt,
      )) {
        continue;
      }
      await _store.upsert(kind: kind, profileId: profileId, fields: row);
    }
  }
}
