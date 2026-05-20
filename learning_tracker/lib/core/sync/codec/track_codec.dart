/// Codec for Firestore `curriculum_tracks/{id}` documents.
library;

import 'package:learning_tracker/core/sync/codec/entity_codec.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// Decoded shape for a curriculum track row.
class TrackRow {
  const TrackRow({
    required this.curriculumId,
    required this.trackType,
    required this.isActive,
    required this.activatedAt,
    this.deactivatedAt,
    this.paceResetDate,
  });

  final String curriculumId;
  final String trackType;
  final bool isActive;
  final DateTime activatedAt;
  final DateTime? deactivatedAt;
  final DateTime? paceResetDate;
}

/// Codec for the `curriculum_tracks` Firestore collection.
///
/// Natural key: `(curriculumId, trackType)`.
/// LWW: remote wins when `activated_at` (or `deactivated_at` if later)
/// is strictly newer than the local equivalent.
class TrackCodec extends EntityCodec<TrackRow> {
  const TrackCodec();

  @override
  String get kind => EntityKind.trackConfig;

  @override
  TrackRow? decode(Map<String, dynamic> raw) {
    final curriculumId = raw['curriculum_id'] as String?;
    final trackType = raw['track_type'] as String?;
    final activatedAt = FirestoreCodec.parseDateTime(raw['activated_at']);

    if (curriculumId == null || trackType == null || activatedAt == null) {
      return null;
    }

    return TrackRow(
      curriculumId: curriculumId,
      trackType: trackType,
      isActive: FirestoreCodec.parseBool(raw['is_active']) ?? true,
      activatedAt: activatedAt,
      deactivatedAt: FirestoreCodec.parseDateTime(raw['deactivated_at']),
      paceResetDate: FirestoreCodec.parseDateTime(raw['pace_reset_date']),
    );
  }

  @override
  Map<String, dynamic> encode(TrackRow model) => {
        'curriculum_id': model.curriculumId,
        'track_type': model.trackType,
        'is_active': model.isActive,
        'activated_at': FirestoreCodec.encodeDateTime(model.activatedAt),
        if (model.deactivatedAt != null)
          'deactivated_at': FirestoreCodec.encodeDateTime(model.deactivatedAt),
        if (model.paceResetDate != null)
          'pace_reset_date': FirestoreCodec.encodeDateTime(model.paceResetDate),
      };
}
