import 'package:learning_tracker/core/codec/firestore_codec.dart';
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
  ///
  /// `updated_at` is decoded via [FirestoreCodec.parseDateTime], so it
  /// tolerates every wire shape that helper supports — ISO-8601 [String],
  /// epoch-seconds [int], a `{seconds: ...}` [Map], or an already-parsed
  /// [DateTime] — plus a real `cloud_firestore` `Timestamp`, which is what
  /// this field actually is on every read of a document a writer stamped
  /// with `FieldValue.serverTimestamp()` (`FirestoreGatewayImpl
  /// .pushBookmark`, and the tutor-proxy Cloud Function's
  /// `tutorUpsertBookmark` in `functions/src/tutor_writes.ts`). `Timestamp`
  /// can't be one of [FirestoreCodec.parseDateTime]'s own cases — that
  /// helper is deliberately `cloud_firestore`-free (see its doc comment),
  /// and this domain-entity file is barred from importing
  /// `package:cloud_firestore` at all (Rule 3, CLAUDE.md: Firebase SDK
  /// types are confined to `core/sync`/`core/auth`) — so [_asTimestampInput]
  /// below duck-types it via a dynamic `toDate()` call instead, exactly
  /// like `TutorGrantDoc.fromFirestore`
  /// (`lib/features/tutoring/domain/models/tutor_grant.dart`) does for the
  /// same reason. `Timestamp.toDate()` returns a [DateTime] flagged local
  /// even though the instant it encodes is already correct;
  /// [FirestoreCodec.parseDateTime]'s `DateTime` branch then calls
  /// `.toUtc()` on it, which fixes the flag (a no-op on the instant itself)
  /// so downstream calendar-field access and re-serialization are
  /// consistently UTC.
  ///
  /// A missing/unparsable `updated_at`, or an unknown/missing
  /// `curriculum_id`, throws [ArgumentError] rather than substituting a
  /// fabricated value:
  ///   - `updated_at` drives cross-device last-write-wins merges elsewhere
  ///     (`BookmarkMerger`); silently inventing "now" would let a corrupt
  ///     document masquerade as the freshest bookmark and clobber a real
  ///     one.
  ///   - `curriculum_id` is this document's own identity (its
  ///     [firestoreId] is derived from it); a document that cannot say
  ///     which curriculum it belongs to is not a decodable bookmark.
  ///
  /// Throwing here is safe: `watchBookmark`'s `resilientDocStream`
  /// (`lib/data/firestore/resilient_doc_stream.dart`) forwards a decode
  /// failure to its stream via `addError` WITHOUT tearing down and
  /// resubscribing the underlying listener — resubscribing would just hit
  /// the same bad document again — so the corrupt document surfaces to the
  /// caller once per snapshot instead of leaving the stream permanently
  /// dark the way a bare `.snapshots()` would.
  static BookmarkEntity fromFirestore(Map<String, dynamic> data) {
    final ref =
        (data['sefaria_ref'] ?? data['content_item_id']) as String? ?? '';

    final curriculumKey = data['curriculum_id'] as String?;
    final curriculumId = CurriculumId.values.firstWhere(
      (c) => c.storageKey == curriculumKey,
      orElse: () => throw ArgumentError('Unknown curriculumId: $curriculumKey'),
    );

    final updatedAt = FirestoreCodec.parseDateTime(
      _asTimestampInput(data['updated_at']),
    );
    if (updatedAt == null) {
      throw ArgumentError(
        'Missing or unparseable updated_at for curriculum '
        '$curriculumKey: ${data['updated_at']}',
      );
    }

    return BookmarkEntity(
      curriculumId: curriculumId,
      sefariaRef: ref,
      updatedAt: updatedAt,
    );
  }

  /// Duck-types a real Firestore `Timestamp` into the [DateTime] that
  /// [FirestoreCodec.parseDateTime] already knows how to handle, without
  /// importing `package:cloud_firestore` (barred from domain code — Rule 3,
  /// CLAUDE.md). Any value already in one of [FirestoreCodec.parseDateTime]'s
  /// own shapes passes through untouched; only what remains is even tried as
  /// a `Timestamp`.
  static Object? _asTimestampInput(Object? raw) {
    if (raw == null ||
        raw is DateTime ||
        raw is String ||
        raw is int ||
        raw is Map) {
      return raw;
    }
    try {
      // ignore: avoid_dynamic_calls — Firestore's `Timestamp.toDate()` is
      // not reachable without a cloud_firestore import, which this domain
      // file may not take (Rule 3). Mirrors `TutorGrantDoc.fromFirestore`.
      final maybeDate = (raw as dynamic).toDate();
      if (maybeDate is DateTime) return maybeDate;
    } catch (_) {
      // Not Timestamp-shaped (no toDate(), or it returned something else) —
      // fall through so FirestoreCodec.parseDateTime sees the original raw
      // value and returns null for it.
    }
    return raw;
  }
}
