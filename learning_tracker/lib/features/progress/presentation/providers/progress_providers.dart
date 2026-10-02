import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/curriculum_progress_data.dart';
import 'package:learning_tracker/features/progress/domain/services/curriculum_progress_service.dart';
import 'package:learning_tracker/features/progress/domain/services/learner_progress.dart';
import 'package:learning_tracker/features/progress/presentation/providers/learner_progress_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'progress_providers.g.dart';

/// The Progress hub's live counters, from the engine's counted learning.
class ProgressOverviewStats {
  /// Counted learn events learnt while tracking (`dated` / `catch_up`).
  final int totalCompletions;

  /// Distinct leaves learnt while tracking, across curricula.
  final int totalUniqueItems;

  const ProgressOverviewStats({
    required this.totalCompletions,
    required this.totalUniqueItems,
  });
}

/// Live progress snapshot from the active learner's [LearnerState]
/// (DNI-474): tracked learning only (the old live-completions filter is
/// now the `dated` / `catch_up` date states), distinct per curriculum and
/// leaf. Before-tracking backfill is not "live" activity.
@riverpod
Future<ProgressOverviewStats> progressOverviewStats(Ref ref) async {
  final state = await watchActiveLearnerState(ref);
  final tracked = [
    for (final e in countedLearnsOf(state))
      if (e.dateState != DateState.beforeTracking) e,
  ];
  return ProgressOverviewStats(
    totalCompletions: tracked.length,
    totalUniqueItems: {
      for (final e in tracked) '${e.curriculumId}:${e.ref}',
    }.length,
  );
}

/// Per-curriculum progress data provider (family keyed by curriculumId per P3).
///
/// The learner's scoped leaves and stage definitions, marked with the
/// engine's learnt set and counted learning (DNI-474): goal progress is the
/// distinct learnt count (FR-14), so repeats never inflate it.
@riverpod
Future<CurriculumProgressData> curriculumProgress(
  Ref ref,
  String curriculumId,
) async {
  final curriculumEnum = CurriculumId.values.firstWhere(
    (c) => c.storageKey == curriculumId,
  );
  final state = await watchActiveLearnerState(ref);
  final contentItems = await ref.watch(
    scopedCurriculumContentProvider(curriculumEnum).future,
  );
  final hierarchyConfig = await ref.watch(
    curriculumHierarchyConfigProvider(curriculumEnum).future,
  );
  final stageRepository = ref.watch(
    stageDefinitionRepositoryProvider(curriculumEnum),
  );
  final stageDefinitions = await stageRepository.getStagesForCurriculum(
    curriculumEnum,
  );
  final corpus = await ref.watch(progressCorpusProvider(curriculumEnum).future);

  return CurriculumProgressService.compute(
    curriculumId: curriculumId,
    contentItems: contentItems,
    learnt: state?[curriculumId]?.learntLeaves ?? const {},
    activity: corpus == null ? const {} : leafActivityOf(state, corpus),
    stageDefinitions: stageDefinitions,
    levelLabels: hierarchyConfig.levelLabels,
  );
}

/// The engine's finish projection of a curriculum (AD-35): null without an
/// active learner, when the curriculum is not evaluated, or with no
/// deadline goal ([ProjectionStatus.noDeadline]).
@riverpod
Future<Projection?> curriculumPaceStatus(Ref ref, String curriculumId) async {
  final state = await watchActiveLearnerState(ref);
  final projection = state?[curriculumId]?.projection;
  if (projection == null || projection.status == ProjectionStatus.noDeadline) {
    return null;
  }
  return projection;
}
