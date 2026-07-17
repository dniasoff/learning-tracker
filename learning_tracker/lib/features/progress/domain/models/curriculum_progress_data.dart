import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';

/// Progress data for an entire curriculum, broken down by hierarchy level.
class CurriculumProgressData {
  const CurriculumProgressData({
    required this.curriculumId,
    required this.hierarchyLevels,
    required this.overallStats,
    this.paceStatus,
  });

  final String curriculumId;
  final List<HierarchyLevelProgress> hierarchyLevels;
  final OverallCurriculumStats overallStats;
  final PaceStatus? paceStatus;
}

/// Progress for one hierarchy level (e.g., a specific seder).
class HierarchyLevelProgress {
  const HierarchyLevelProgress({
    required this.curriculumId,
    required this.level,
    required this.levelName,
    required this.totalItems,
    required this.completedItems,
    required this.stageBreakdown,
    required this.trackBreakdown,
    this.subLevels,
  });

  /// Which curriculum this level belongs to — needed so the presentation
  /// layer can resolve [levelName] (a raw content key) to its variant-aware
  /// display form via the shared curriculum label renderer.
  final CurriculumId curriculumId;

  /// 1-based hierarchy depth of this level (1 = seder/sefer, 2 = masechta, …).
  /// Feeds the level-aware name renderer alongside [levelName].
  final int level;

  /// Raw content storage key for this level (e.g. "Seder Zeraim"). NOT a
  /// display string — render it through the curriculum label layer.
  final String levelName;
  final int totalItems;
  final int completedItems;
  final List<StageBreakdownEntry> stageBreakdown;

  /// Completion count keyed by the internal track storage key. One track per
  /// curriculum, so this is a single-entry map — not a user-facing concept.
  final Map<String, int> trackBreakdown;
  final List<HierarchyLevelProgress>? subLevels;

  double get completionPercentage =>
      totalItems > 0 ? completedItems / totalItems : 0.0;
}

/// A single entry in a stage breakdown (e.g., "Learned: 15").
class StageBreakdownEntry {
  const StageBreakdownEntry({required this.stageName, required this.count});

  final String stageName;
  final int count;
}

/// Overall curriculum stats: total, completed all stages, in progress, not started.
class OverallCurriculumStats {
  const OverallCurriculumStats({
    required this.totalItems,
    required this.completedAllStages,
    required this.inProgress,
    required this.notStarted,
  });

  final int totalItems;
  final int completedAllStages;
  final int inProgress;
  final int notStarted;
}
