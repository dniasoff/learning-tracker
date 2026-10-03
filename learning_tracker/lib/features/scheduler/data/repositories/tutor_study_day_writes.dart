// Story 1.24 (DNI-486) tutor study-day write, shared by the scheduler and
// tracks study-day repositories. Its basename is not *_repository*, so the
// tracks repository importing it is not repository->repository (SM-8,
// AUD-tracks-15).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/study_day_config.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_learning_providers.dart';

/// A tutor's study-day write (Story 1.24, DNI-486): upserts [studyDays]
/// and tombstones every [existing] day absent from it as ONE governed
/// `tutorReplaceStudyDays` action after the tutor preflight. Throws when
/// the preflight refuses or the callable fails; then nothing was written.
Future<void> tutorReplaceStudyDays(
  Ref ref, {
  required CurriculumId curriculumId,
  required Map<int, DayType> studyDays,
  required List<StudyDayConfigEntry> existing,
}) async {
  final writes = await requireTutorGovernedWrites(ref);
  String docId(int day) => DocIds.studyDayConfigDocId({
    'curriculum_id': curriculumId.storageKey,
    'day_of_week': day,
  });
  await writes.replaceStudyDays(
    curriculumId: curriculumId.storageKey,
    upserts: [
      for (final MapEntry(key: day, value: type) in studyDays.entries)
        (
          docId: docId(day),
          data: StudyDayConfigEntry(
            dayOfWeek: day,
            dayType: type,
          ).toFirestore(curriculumId: curriculumId),
        ),
    ],
    removedDocIds: [
      for (final entry in existing)
        if (!studyDays.containsKey(entry.dayOfWeek)) docId(entry.dayOfWeek),
    ],
  );
}
