import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/study_day_config_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/study_day_config.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'study_day_config_providers.g.dart';

/// Firestore-backed adapter for study-day configs — **wired Phase 3, T-20**.
/// The Drift DAO-backed providers below are deprecated and will be removed in Phase 4.
@riverpod
FirestoreStudyDayConfigRepositoryAdapter studyDayConfigRepositoryAdapter(
  Ref ref,
) {
  return FirestoreStudyDayConfigRepositoryAdapter(ref: ref);
}

/// Watch study day configs for a curriculum reactively as domain models.
///
/// **Firestore-backed** via [studyDayConfigRepositoryAdapterProvider] (Phase 3, T-20).
@riverpod
Stream<List<StudyDayConfigEntry>> studyDayConfigs(
  Ref ref,
  CurriculumId curriculumId,
) {
  final adapter = ref.watch(studyDayConfigRepositoryAdapterProvider);
  return adapter.watchConfigsForCurriculum(curriculumId);
}

/// Check if today is a study day for a curriculum.
///
/// **Firestore-backed** via [studyDayConfigRepositoryAdapterProvider] (Phase 3, T-20).
@riverpod
Future<bool> isStudyDay(Ref ref, CurriculumId curriculumId) async {
  final adapter = ref.watch(studyDayConfigRepositoryAdapterProvider);
  final configs = await adapter.getConfigsForCurriculum(curriculumId);
  final today = ref.watch(clockProvider);
  return configs.any(
    (c) => c.dayOfWeek == today.weekday && c.dayType == DayType.study,
  );
}

/// Get count of study days per week for a curriculum.
///
/// **Firestore-backed** via [studyDayConfigRepositoryAdapterProvider] (Phase 3, T-20).
@riverpod
Future<int> studyDaysPerWeek(Ref ref, CurriculumId curriculumId) async {
  final adapter = ref.watch(studyDayConfigRepositoryAdapterProvider);
  final configs = await adapter.getConfigsForCurriculum(curriculumId);
  return configs.where((c) => c.dayType == DayType.study).length;
}
