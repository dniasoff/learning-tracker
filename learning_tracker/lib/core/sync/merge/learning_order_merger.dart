/// LWW merger for per-curriculum learning-order rows (W2.26 / closes C3/H3).
///
/// Each row has a natural key of `curriculum_id + '|' + sefaria_ref`.
/// Remote wins iff its `updated_at` is strictly newer than the local row.
library;

import 'package:learning_tracker/core/sync/codec/learning_order_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_rules.dart';

class LearningOrderMerger implements EntityMerger {
  LearningOrderMerger({required MergeStore store}) : _store = store;

  final MergeStore _store;
  static const _codec = LearningOrderCodec();

  @override
  String get kind => EntityKind.learningOrder;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      final decoded = _codec.decode(row);
      if (decoded == null) continue; // Missing curriculumId/sefariaRef — skip.

      final naturalKey = '${decoded.curriculumId}|${decoded.sefariaRef}';
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
