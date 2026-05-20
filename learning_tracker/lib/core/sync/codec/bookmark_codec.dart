/// Codec for Firestore `bookmarks/{id}` documents.
library;

import 'package:learning_tracker/core/sync/codec/entity_codec.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// Decoded shape for a bookmark row.
class BookmarkRow {
  const BookmarkRow({
    required this.curriculumId,
    required this.trackType,
    required this.sefariaRef,
    required this.updatedAt,
  });

  final String curriculumId;
  final String trackType;
  final String sefariaRef;
  final DateTime updatedAt;
}

/// Codec for the `bookmarks` Firestore collection.
///
/// Natural key: `(curriculumId, trackType)`.
/// LWW: remote wins when `updated_at` is strictly newer.
class BookmarkCodec extends EntityCodec<BookmarkRow> {
  const BookmarkCodec();

  @override
  String get kind => EntityKind.bookmark;

  @override
  BookmarkRow? decode(Map<String, dynamic> raw) {
    final curriculumId = raw['curriculum_id'] as String?;
    final trackType = raw['track_type'] as String?;
    final sefariaRef = raw['sefaria_ref'] as String?;
    final updatedAt = FirestoreCodec.parseDateTime(raw['updated_at']);

    if (curriculumId == null ||
        trackType == null ||
        sefariaRef == null ||
        updatedAt == null) {
      return null;
    }

    return BookmarkRow(
      curriculumId: curriculumId,
      trackType: trackType,
      sefariaRef: sefariaRef,
      updatedAt: updatedAt,
    );
  }

  @override
  Map<String, dynamic> encode(BookmarkRow model) => {
    'curriculum_id': model.curriculumId,
    'track_type': model.trackType,
    'sefaria_ref': model.sefariaRef,
    'updated_at': FirestoreCodec.encodeDateTime(model.updatedAt),
  };
}
