import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/features/sync/domain/merge_rules.dart';

/// LWW merger for per-curriculum learning-order rows (W2.26 / closes C3/H3).
///
/// Each row has a natural key of `curriculum_id + '|' + sefaria_ref`.
/// Remote wins iff its `updated_at` is strictly newer than the local row.
///
/// Previously `pullLearningOrder` silently halted because no [EntityMerger]
/// was registered for 'learning_order' in [MergeRouter]. This closes C3/H3.
class LearningOrderMerger implements EntityMerger {
  LearningOrderMerger({required MergeStore store}) : _store = store;

  final MergeStore _store;

  @override
  String get kind => EntityKind.learningOrder;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      final curriculumId = row['curriculum_id']?.toString() ?? '';
      final sefariaRef = row['sefaria_ref']?.toString() ?? '';
      if (curriculumId.isEmpty || sefariaRef.isEmpty) continue;

      final naturalKey = '$curriculumId|$sefariaRef';
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
