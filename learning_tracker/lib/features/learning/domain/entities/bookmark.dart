import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';

/// Domain entity representing a user's current position in a curriculum track.
///
/// Each bookmark points to a specific content item and is uniquely identified
/// by the combination of curriculum and track type.
class BookmarkEntity {
  final CurriculumId curriculumId;
  final TrackType trackType;
  final int contentItemId;
  final DateTime updatedAt;

  const BookmarkEntity({
    required this.curriculumId,
    required this.trackType,
    required this.contentItemId,
    required this.updatedAt,
  });

  /// Create a bookmark with updated position.
  BookmarkEntity copyWith({int? contentItemId, DateTime? updatedAt}) {
    return BookmarkEntity(
      curriculumId: curriculumId,
      trackType: trackType,
      contentItemId: contentItemId ?? this.contentItemId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Firestore document ID (deterministic per P4).
  String get firestoreId =>
      '${curriculumId.storageKey}_${trackType.storageKey}';

  /// Convert to Firestore document map.
  Map<String, dynamic> toFirestore() {
    return {
      'curriculumId': curriculumId.storageKey,
      'trackType': trackType.storageKey,
      'contentItemId': contentItemId,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from Firestore document.
  static BookmarkEntity fromFirestore(Map<String, dynamic> data) {
    return BookmarkEntity(
      curriculumId: CurriculumId.values.firstWhere(
        (c) => c.storageKey == data['curriculumId'] as String,
      ),
      trackType: TrackType.fromStorageKey(data['trackType'] as String),
      contentItemId: data['contentItemId'] as int,
      updatedAt: DateTime.parse(data['updatedAt'] as String),
    );
  }
}
