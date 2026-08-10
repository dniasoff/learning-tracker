/// Codec for Firestore `completions/{firestoreId}` documents.
library;

import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/codec/entity_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// Decoded shape for a completion event row.
///
/// All fields are extracted from the Firestore wire format so that the
/// merger and [DriftMergeStore] receive clean typed values.
class CompletionEventRow {
  const CompletionEventRow({
    this.firestoreId,
    required this.profileId,
    required this.curriculumId,
    required this.sefariaRef,
    required this.stageId,
    required this.trackType,
    this.trackId,
    required this.eventTimestamp,
    this.points = 0,
    this.priorMarkOnly = false,
  });

  final String? firestoreId;
  final int profileId;
  final String curriculumId;
  final String sefariaRef;
  final int stageId;
  final String trackType;

  /// Nullable — absent from legacy rows that pre-date the trackId column.
  final int? trackId;
  final DateTime eventTimestamp;
  final int points;
  final bool priorMarkOnly;
}

/// Codec for the `completions` Firestore collection.
///
/// Wire format → [CompletionEventRow] → Drift [CompletionEventsCompanion].
class CompletionEventCodec extends EntityCodec<CompletionEventRow> {
  const CompletionEventCodec();

  @override
  String get kind => EntityKind.completion;

  @override
  CompletionEventRow? decode(Map<String, dynamic> raw) {
    final curriculumId = raw['curriculum_id'] as String?;
    final sefariaRef = raw['sefaria_ref'] as String?;
    final stageId = FirestoreCodec.parseInt(raw['stage_id']);
    final trackType = raw['track_type'] as String?;
    final eventTs =
        FirestoreCodec.parseDateTime(
          raw['completed_at'] ?? raw['event_timestamp'],
        ) ??
        FirestoreCodec.parseDateTime(raw['completedAt']);

    if (curriculumId == null ||
        sefariaRef == null ||
        stageId == null ||
        trackType == null ||
        eventTs == null) {
      return null; // Malformed row — skip.
    }

    return CompletionEventRow(
      firestoreId: raw['firestore_id'] as String?,
      profileId: FirestoreCodec.parseInt(raw['profile_id']) ?? 0,
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      stageId: stageId,
      trackType: trackType,
      trackId: FirestoreCodec.parseInt(raw['track_id']),
      eventTimestamp: eventTs,
      points: FirestoreCodec.parseInt(raw['points']) ?? 0,
      priorMarkOnly: FirestoreCodec.parseBool(raw['prior_mark_only']) ?? false,
    );
  }

  @override
  Map<String, dynamic> encode(CompletionEventRow model) => {
    'profile_id': model.profileId,
    'curriculum_id': model.curriculumId,
    'sefaria_ref': model.sefariaRef,
    'stage_id': model.stageId,
    'track_type': model.trackType,
    if (model.trackId != null) 'track_id': model.trackId,
    'completed_at': FirestoreCodec.encodeDateTime(model.eventTimestamp),
    'points': model.points,
    if (model.priorMarkOnly) 'prior_mark_only': true,
    if (model.firestoreId != null) 'firestore_id': model.firestoreId,
  };
}
