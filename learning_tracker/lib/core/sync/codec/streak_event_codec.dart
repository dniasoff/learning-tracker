/// Codec for Firestore `streak_events/{ulid}` documents.
///
/// NOTE (W3.37): The current streak Firestore shape is a snapshot document
/// `streak/{profileId}`. W3.37 will change it to `streak_events/{ulid}`.
/// This codec targets the post-W3.37 shape.
library;

import 'package:learning_tracker/core/sync/codec/entity_codec.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// Decoded shape for a streak event row.
class StreakEventRow {
  const StreakEventRow({
    required this.profileId,
    required this.eventType,
    required this.studyDate,
    required this.createdAt,
    this.firestoreId,
  });

  final int profileId;
  final String eventType;
  final DateTime studyDate;
  final DateTime createdAt;
  final String? firestoreId;
}

/// Codec for the `streak_events` Firestore collection.
///
/// Append-only (no LWW) — events are deduplicated on `(profileId, studyDate,
/// eventType)` via INSERT OR IGNORE.
class StreakEventCodec extends EntityCodec<StreakEventRow> {
  const StreakEventCodec();

  @override
  String get kind => EntityKind.streak;

  @override
  StreakEventRow? decode(Map<String, dynamic> raw) {
    final profileId = FirestoreCodec.parseInt(raw['profile_id']);
    final eventType = raw['event_type'] as String?;
    final studyDate = FirestoreCodec.parseDateTime(raw['study_date']);
    final createdAt = FirestoreCodec.parseDateTime(raw['created_at']);

    if (profileId == null ||
        eventType == null ||
        studyDate == null ||
        createdAt == null) {
      return null;
    }

    return StreakEventRow(
      profileId: profileId,
      eventType: eventType,
      studyDate: studyDate,
      createdAt: createdAt,
      firestoreId: raw['firestore_id'] as String?,
    );
  }

  @override
  Map<String, dynamic> encode(StreakEventRow model) => {
        'profile_id': model.profileId,
        'event_type': model.eventType,
        'study_date': FirestoreCodec.encodeDateTime(model.studyDate),
        'created_at': FirestoreCodec.encodeDateTime(model.createdAt),
        if (model.firestoreId != null) 'firestore_id': model.firestoreId,
      };
}
