import 'package:learning_tracker/core/enums/curriculum_id.dart';

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
  Map<String, dynamic> toFirestore() {
    return {
      'curriculum_id': curriculumId.storageKey,
      'content_item_id': sefariaRef,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create from Firestore document.
  static BookmarkEntity fromFirestore(Map<String, dynamic> data) {
    return BookmarkEntity(
      curriculumId: CurriculumId.values.firstWhere(
        (c) => c.storageKey == data['curriculum_id'] as String,
        orElse: () => throw ArgumentError(
          'Unknown curriculumId: ${data['curriculum_id']}',
        ),
      ),
      sefariaRef: data['content_item_id'] as String,
      updatedAt: DateTime.parse(data['updated_at'] as String),
    );
  }
}
