/// Codec for Firestore `learning_order/{id}` documents.
library;

import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/codec/entity_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// Decoded shape for a learning order item.
class LearningOrderRow {
  const LearningOrderRow({
    required this.curriculumId,
    required this.sefariaRef,
    required this.userSortOrder,
    this.updatedAt,
    this.syncedAt,
    this.isCustomOrdered = false,
    this.displayNameHe,
    this.displayNameEn,
  });

  final String curriculumId;
  final String sefariaRef;
  final int userSortOrder;
  final DateTime? updatedAt;

  /// Firestore server timestamp set by `FieldValue.serverTimestamp()` at
  /// push time. Used as the ±5 s clock-skew tie-breaker by mergers.
  final DateTime? syncedAt;
  final bool isCustomOrdered;
  final String? displayNameHe;
  final String? displayNameEn;
}

/// Codec for the `learning_order` Firestore collection.
///
/// Natural key: `(curriculumId, sefariaRef)`.
/// LWW: remote wins when `updated_at` is strictly newer.
class LearningOrderCodec extends EntityCodec<LearningOrderRow> {
  const LearningOrderCodec();

  @override
  String get kind => EntityKind.learningOrder;

  @override
  LearningOrderRow? decode(Map<String, dynamic> raw) {
    final curriculumId = raw['curriculum_id'] as String?;
    final sefariaRef = raw['sefaria_ref'] as String?;
    final userSortOrder = FirestoreCodec.parseInt(raw['user_sort_order']);

    if (curriculumId == null || sefariaRef == null || userSortOrder == null) {
      return null;
    }

    return LearningOrderRow(
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      userSortOrder: userSortOrder,
      updatedAt: FirestoreCodec.parseDateTime(raw['updated_at']),
      syncedAt: FirestoreCodec.parseDateTime(raw['synced_at']),
      isCustomOrdered:
          FirestoreCodec.parseBool(raw['is_custom_ordered']) ?? false,
      displayNameHe: raw['display_name_he'] as String?,
      displayNameEn: raw['display_name_en'] as String?,
    );
  }

  @override
  Map<String, dynamic> encode(LearningOrderRow model) => {
    // Only rule-legal keys (see `learning_order` hasOnly() in firestore.rules).
    // `is_custom_ordered` / `display_name_*` are local-only enrichments and are
    // intentionally NOT synced (the live writer never emitted them either).
    'curriculum_id': model.curriculumId,
    'sefaria_ref': model.sefariaRef,
    'user_sort_order': model.userSortOrder,
    if (model.updatedAt != null)
      'updated_at': FirestoreCodec.encodeDateTime(model.updatedAt),
  };
}
