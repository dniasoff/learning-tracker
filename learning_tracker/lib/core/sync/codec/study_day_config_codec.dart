/// Codec for Firestore `study_day_configs/{id}` documents.
///
/// Document id is derived deterministically from
/// `(curriculum_id, day_of_week, track_id)` so repeated writes for the same
/// (curriculum, day, track) collapse to one document.
library;

import 'package:learning_tracker/core/sync/codec/entity_codec.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// Decoded shape for a study-day config row.
class StudyDayConfigRow {
  const StudyDayConfigRow({
    required this.profileId,
    required this.curriculumId,
    required this.trackId,
    required this.dayOfWeek,
    required this.dayType,
    required this.updatedAt,
    this.syncedAt,
  });

  final int profileId;
  final String curriculumId;
  final int trackId;
  final int dayOfWeek;
  final String dayType;
  final DateTime updatedAt;

  /// Firestore server timestamp set by `FieldValue.serverTimestamp()` at
  /// push time. Used as the ±5 s clock-skew tie-breaker by
  /// [MergeStore.remoteIsNewer].
  final DateTime? syncedAt;
}

/// Codec for the `study_day_configs` Firestore collection.
///
/// Natural key: `(curriculumId, dayOfWeek, trackId)` — matches the Drift PK
/// minus `profileId`, which is implicit in the subcollection scope.
/// LWW on `updated_at`.
class StudyDayConfigCodec extends EntityCodec<StudyDayConfigRow> {
  const StudyDayConfigCodec();

  @override
  String get kind => EntityKind.studyDayConfig;

  @override
  StudyDayConfigRow? decode(Map<String, dynamic> raw) {
    final profileId = FirestoreCodec.parseInt(raw['profile_id']);
    final curriculumId = raw['curriculum_id'] as String?;
    final trackId = FirestoreCodec.parseInt(raw['track_id']);
    final dayOfWeek = FirestoreCodec.parseInt(raw['day_of_week']);
    final dayType = raw['day_type'] as String?;
    final updatedAt = FirestoreCodec.parseDateTime(raw['updated_at']);

    if (profileId == null ||
        curriculumId == null ||
        trackId == null ||
        dayOfWeek == null ||
        dayType == null ||
        updatedAt == null) {
      return null;
    }

    return StudyDayConfigRow(
      profileId: profileId,
      curriculumId: curriculumId,
      trackId: trackId,
      dayOfWeek: dayOfWeek,
      dayType: dayType,
      updatedAt: updatedAt,
      syncedAt: FirestoreCodec.parseDateTime(raw['synced_at']),
    );
  }

  @override
  Map<String, dynamic> encode(StudyDayConfigRow model) => {
    'profile_id': model.profileId,
    'curriculum_id': model.curriculumId,
    'track_id': model.trackId,
    'day_of_week': model.dayOfWeek,
    'day_type': model.dayType,
    'updated_at': FirestoreCodec.encodeDateTime(model.updatedAt),
  };
}
