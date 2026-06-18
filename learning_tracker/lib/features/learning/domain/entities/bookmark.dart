import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/sync/codec/bookmark_codec.dart';

/// Domain entity representing a user's current position in a curriculum.
///
/// Each bookmark points to a specific content item and is uniquely identified
/// by the curriculum (there is exactly one track per profile + curriculum).
class BookmarkEntity {
  final CurriculumId curriculumId;
  final String sefariaRef;
  final DateTime updatedAt;

  const BookmarkEntity({
    required this.curriculumId,
    required this.sefariaRef,
    required this.updatedAt,
  });

  /// Create a bookmark with updated position.
  BookmarkEntity copyWith({String? sefariaRef, DateTime? updatedAt}) {
    return BookmarkEntity(
      curriculumId: curriculumId,
      sefariaRef: sefariaRef ?? this.sefariaRef,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Firestore document ID (deterministic per P4). One track per curriculum,
  /// so the curriculum storage key alone is the natural key.
  String get firestoreId => curriculumId.storageKey;

  /// Convert to Firestore document map.
  ///
  /// Phase B: routes through [BookmarkCodec.encode] so the write shape is
  /// identical to the merge read-key (`sefaria_ref`) — removes the
  /// push↔merge key mismatch that caused cross-device bookmark loss.
  Map<String, dynamic> toFirestore() {
    return const BookmarkCodec().encode(
      BookmarkRow(
        curriculumId: curriculumId.storageKey,
        sefariaRef: sefariaRef,
        updatedAt: updatedAt,
      ),
    );
  }

  /// Create from Firestore document.
  ///
  /// Accepts both `sefaria_ref` (canonical, codec-written) and the legacy
  /// `content_item_id` key so old Firestore documents still round-trip.
  static BookmarkEntity fromFirestore(Map<String, dynamic> data) {
    final ref =
        (data['sefaria_ref'] ?? data['content_item_id']) as String? ?? '';
    return BookmarkEntity(
      curriculumId: CurriculumId.values.firstWhere(
        (c) => c.storageKey == data['curriculum_id'] as String,
        orElse: () => throw ArgumentError(
          'Unknown curriculumId: ${data['curriculum_id']}',
        ),
      ),
      sefariaRef: ref,
      updatedAt: DateTime.parse(data['updated_at'] as String),
    );
  }
}
