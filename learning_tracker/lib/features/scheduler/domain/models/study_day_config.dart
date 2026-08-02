import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';

part 'study_day_config.freezed.dart';

@freezed
abstract class StudyDayConfigEntry with _$StudyDayConfigEntry {
  const factory StudyDayConfigEntry({
    required int dayOfWeek, // 1=Mon..7=Sun (ISO 8601)
    required DayType dayType,
  }) = _StudyDayConfigEntry;
}

/// Firestore document codec for `study_day_configs/{curriculumId}_
/// {dayOfWeek}` (`docs/firestore-rewrite-map.md`, `firestore.rules`
/// `match /study_day_configs/{configId}`).
///
/// [StudyDayConfigEntry] carries no `curriculumId` field — every existing
/// caller (`StudyDayConfigDao.getConfigsByCurriculumAndProfile`, and now
/// `FirestoreStudyDayConfigRepository`) already scopes it externally, one
/// curriculum's configs at a time. So, exactly like
/// `StageDefinitionFirestoreCodec.toFirestore`'s `updatedAt` parameter,
/// [curriculumId] is supplied by the caller at encode time rather than
/// stored on the entry itself.
///
/// Deliberately omits `track_id` — AD-25 retires the per-device track id
/// for this collection; `curriculum_id` (supplied here) is the sole
/// canonical stable track key. Writing the Drift-local `int` `track_id`
/// from a repository would also trip the MCF-11 autoincrement-id-in-payload
/// ratchet (`tool/check_mcf11_autoincrement_id_in_payload_ratchet.dart`) as
/// a brand-new site outside `lib/core/sync/merge/`.
extension StudyDayConfigEntryFirestoreCodec on StudyDayConfigEntry {
  /// Encodes this entry for a Firestore write. `profile_id` is deliberately
  /// omitted — the path (`users/{uid}/learner_profiles/{profileId}/
  /// study_day_configs/…`) already carries it, matching
  /// `StageDefinition`/`BookmarkEntity`'s write shapes.
  Map<String, dynamic> toFirestore({
    required CurriculumId curriculumId,
    required DateTime updatedAt,
  }) {
    return {
      'curriculum_id': curriculumId.storageKey,
      'day_of_week': dayOfWeek,
      'day_type': dayType.storageKey,
      'updated_at': FirestoreCodec.encodeDateTime(updatedAt),
    };
  }
}

/// Decodes a `study_day_configs/{curriculumId}_{dayOfWeek}` document into a
/// [StudyDayConfigEntry]. `curriculum_id` is read by the caller (it selects
/// which curriculum's query to run in the first place) and is not carried
/// on the returned entry — see [StudyDayConfigEntryFirestoreCodec]'s doc
/// comment.
///
/// Throws [FormatException] for a missing/invalid `day_of_week` or a
/// missing `day_type`, and lets [DayType.fromStorageKey]'s [StateError]
/// propagate for an unrecognised `day_type` value — all caller-visible
/// decode failures by design (see `stageDefinitionFromFirestore`'s doc
/// comment for why this is not silently defaulted; surfaced via
/// `resilientQueryStream`'s per-document error handling, which skips just
/// that document rather than the whole result).
StudyDayConfigEntry studyDayConfigEntryFromFirestore(
  Map<String, dynamic> data,
) {
  final dayOfWeek = FirestoreCodec.parseInt(data['day_of_week']);
  if (dayOfWeek == null) {
    throw FormatException(
      'study_day_configs document missing day_of_week: $data',
    );
  }
  final dayTypeKey = data['day_type'] as String?;
  if (dayTypeKey == null) {
    throw FormatException('study_day_configs document missing day_type: $data');
  }
  return StudyDayConfigEntry(
    dayOfWeek: dayOfWeek,
    dayType: DayType.fromStorageKey(dayTypeKey),
  );
}
