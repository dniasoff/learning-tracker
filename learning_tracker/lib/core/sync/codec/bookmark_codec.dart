/// Codec for Firestore `bookmarks/{id}` documents.
library;

import 'package:learning_tracker/core/sync/codec/entity_codec.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// Decoded shape for a bookmark row.
class BookmarkRow {
  const BookmarkRow({
    required this.curriculumId,
    required this.sefariaRef,
    required this.updatedAt,
    this.syncedAt,
  });

  final String curriculumId;
  final String sefariaRef;
  final DateTime updatedAt;

  /// Firestore server timestamp set by `FieldValue.serverTimestamp()` at
  /// push time. Used as the ±5 s clock-skew tie-breaker by mergers.
  final DateTime? syncedAt;
}

/// Codec for the `bookmarks` Firestore collection.
///
/// Natural key: `curriculumId` (one track per profile + curriculum).
/// LWW: remote wins when `updated_at` is strictly newer.
class BookmarkCodec extends EntityCodec<BookmarkRow> {
  const BookmarkCodec();

  @override
  String get kind => EntityKind.bookmark;

  @override
  BookmarkRow? decode(Map<String, dynamic> raw) {
    final curriculumId = raw['curriculum_id'] as String?;
    // Dual-key: live writers (BookmarkEntity.toFirestore et al.) persist the ref
    // under `content_item_id`; codec/legacy docs use `sefaria_ref`. Accept both —
    // reading only one drops every live-written bookmark from sync. (DriftMergeStore
    // ._upsertBookmark has the matching fallback.)
    final sefariaRef =
        (raw['sefaria_ref'] ?? raw['content_item_id']) as String?;
    final updatedAt = FirestoreCodec.parseDateTime(raw['updated_at']);

    if (curriculumId == null || sefariaRef == null || updatedAt == null) {
      return null;
    }

    return BookmarkRow(
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      updatedAt: updatedAt,
      syncedAt: FirestoreCodec.parseDateTime(raw['synced_at']),
    );
  }

  @override
  Map<String, dynamic> encode(BookmarkRow model) => {
    'curriculum_id': model.curriculumId,
    'sefaria_ref': model.sefariaRef,
    'updated_at': FirestoreCodec.encodeDateTime(model.updatedAt),
  };
}
