import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// A per-curriculum-per-stage point-value override (Phase 3 task #4).
///
/// Firestore doc-id: `point_configs/{curriculumId}_{stageOrder}`
/// (`DocIds.pointConfigDocId`, `firestore.rules` `match /point_configs/{configId}`).
/// AD-25: there is no per-device track id on this collection — a curriculum
/// IS its track, so `curriculumId` + `stageOrder` is already the sole
/// canonical key (same shape `StageDefinition` uses).
class PointConfigEntity {
  const PointConfigEntity({
    required this.curriculumId,
    required this.stageOrder,
    required this.points,
  });

  final CurriculumId curriculumId;
  final int stageOrder;
  final int points;
}

/// Firestore codec for [PointConfigEntity]. See the class doc comment for
/// the doc-id scheme.
extension PointConfigFirestoreCodec on PointConfigEntity {
  Map<String, dynamic> toFirestore({required DateTime updatedAt}) {
    return {
      'curriculum_id': curriculumId.storageKey,
      'stage_order': stageOrder,
      'points': points,
      'updated_at': FirestoreCodec.encodeDateTime(updatedAt),
    };
  }
}

/// Decodes a `point_configs/{curriculumId}_{stageOrder}` document into a
/// [PointConfigEntity].
///
/// Throws [ArgumentError] for an unrecognised `curriculum_id` — a
/// caller-visible decode failure by design (surfaced via a query's
/// per-document error handling, which skips just that document rather than
/// the whole result), never silently defaulted.
PointConfigEntity pointConfigFromFirestore(Map<String, dynamic> data) {
  final curriculumId = CurriculumId.fromStorageKey(
    data['curriculum_id'] as String? ?? '',
  );
  if (curriculumId == null) {
    throw ArgumentError('Unknown curriculumId: ${data['curriculum_id']}');
  }
  return PointConfigEntity(
    curriculumId: curriculumId,
    stageOrder: FirestoreCodec.parseInt(data['stage_order']) ?? 0,
    points: FirestoreCodec.parseInt(data['points']) ?? 0,
  );
}
