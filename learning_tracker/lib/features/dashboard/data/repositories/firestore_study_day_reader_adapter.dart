import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_study_day_config_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/study_day_config.dart';

/// Client-side study-day-count derivations dashboard's pace calculation
/// needs, over the raw config list [FirestoreStudyDayConfigRepository]
/// returns.
///
/// [FirestoreStudyDayConfigRepository]'s own class doc comment explains why
/// it deliberately does NOT expose these as repository methods:
/// `countStudyDaysInInclusiveDateRangeForTrack`/`getStudyDaysPerWeekForTrack`
/// (the old `StudyDayConfigDao` methods this replaces) are pure derived
/// computations over `getConfigsForCurriculum`'s full result — duplicating
/// that logic into repository plumbing would just move the same
/// computation to a second place. This is that "scheduler/service layer"
/// the comment points to, scoped to what dashboard's pace status needs.
///
/// Configuration-shaped, not achievement-shaped (D-E): an unconfigured
/// study-day schedule is a legitimate, common state (self-paced tracks
/// never set one) — `[]`/`0` on a not-ready backend is treated the same as
/// "nothing configured yet", exactly like every other config-shaped read
/// in this codebase (`FirestoreGoalRepositoryAdapter.getGoals`, etc.).
class FirestoreStudyDayReaderAdapter {
  FirestoreStudyDayReaderAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  Future<List<StudyDayConfigEntry>> _configs(CurriculumId curriculumId) async {
    final repo = await _ref.read(firestoreStudyDayConfigRepositoryProvider.future);
    if (repo == null) return const [];
    return repo.getConfigsForCurriculum(curriculumId);
  }

  /// Count of calendar days in `[startInclusive, endInclusive]` whose ISO
  /// weekday (`DateTime.weekday`, 1=Mon..7=Sun — same numbering
  /// [StudyDayConfigEntry.dayOfWeek] already uses) is configured as a study
  /// day for [curriculumId].
  Future<int> countStudyDaysInInclusiveDateRange({
    required CurriculumId curriculumId,
    required DateTime startInclusive,
    required DateTime endInclusive,
  }) async {
    if (endInclusive.isBefore(startInclusive)) return 0;
    final configs = await _configs(curriculumId);
    final studyWeekdays = configs
        .where((c) => c.dayType == DayType.study)
        .map((c) => c.dayOfWeek)
        .toSet();
    if (studyWeekdays.isEmpty) return 0;

    var count = 0;
    var day = startInclusive;
    while (!day.isAfter(endInclusive)) {
      if (studyWeekdays.contains(day.weekday)) count++;
      day = day.add(const Duration(days: 1));
    }
    return count;
  }

  /// Number of distinct weekdays configured as a study day for
  /// [curriculumId] (0-7).
  Future<int> studyDaysPerWeek(CurriculumId curriculumId) async {
    final configs = await _configs(curriculumId);
    return configs.where((c) => c.dayType == DayType.study).length;
  }
}
