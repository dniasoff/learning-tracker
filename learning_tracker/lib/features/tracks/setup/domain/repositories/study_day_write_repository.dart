import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';

/// Abstract write-side repository for a curriculum's study-day schedule
/// (which weekdays are `study` vs `review`).
///
/// Read-only access already exists per-scheduler-feature
/// (`FirestoreStudyDayConfigRepository.getConfigsForCurriculum`, wrapped
/// for dashboard's own needs by `FirestoreStudyDayReaderAdapter`) — this is
/// the write-capable sibling, needed by `TrackEditService`
/// (features/tracks/setup/domain/services/), which AD-23/AD-28 forbid from
/// reaching the data ring directly.
abstract class StudyDayWriteRepository {
  /// Replaces [curriculumId]'s full study-day schedule with [studyDays]
  /// (weekday 1-7 ISO -> [DayType]). Unlike stage_definitions,
  /// firestore.rules allows delete on study_day_configs, so this can be a
  /// true replace — a weekday omitted from [studyDays] that was previously
  /// configured is deleted, not left as an orphan.
  Future<void> replaceAllForCurriculum({
    required CurriculumId curriculumId,
    required Map<int, DayType> studyDays,
  });
}
