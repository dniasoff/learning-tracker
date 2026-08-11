import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/study_day_write_repository.dart';

/// Thrown when `firestoreStudyDayConfigRepositoryProvider` resolves to
/// `null` — see `ProfileProgramRepositoryNotReadyException`'s doc comment
/// (profile_program_repository_impl.dart) for the read-vs-write split this
/// mirrors.
class StudyDayWriteRepositoryNotReadyException implements Exception {
  const StudyDayWriteRepositoryNotReadyException();

  @override
  String toString() =>
      'StudyDayWriteRepositoryNotReadyException: '
      'firestoreStudyDayConfigRepositoryProvider resolved to null (no '
      'active account, or no active learner profile, yet) — cannot replace '
      'a study-day schedule until one is active.';
}

/// Firestore-backed [StudyDayWriteRepository] adapter — write-capable
/// sibling of `FirestoreStudyDayReaderAdapter`
/// (features/dashboard/data/repositories/, read-only).
class FirestoreStudyDayWriteRepositoryAdapter
    implements StudyDayWriteRepository {
  FirestoreStudyDayWriteRepositoryAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  @override
  Future<void> replaceAllForCurriculum({
    required CurriculumId curriculumId,
    required Map<int, DayType> studyDays,
  }) async {
    final repo = await _ref.read(firestoreStudyDayConfigRepositoryProvider.future);
    if (repo == null) {
      throw const StudyDayWriteRepositoryNotReadyException();
    }
    await repo.replaceAllForCurriculum(
      curriculumId: curriculumId,
      studyDays: studyDays,
    );
  }
}
