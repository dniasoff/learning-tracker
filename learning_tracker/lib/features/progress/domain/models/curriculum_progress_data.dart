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
    required this.levelName,
    required this.levelLabel,
    required this.totalItems,
    required this.completedItems,
    required this.stageBreakdown,
    required this.trackBreakdown,
    this.subLevels,
  });

  final String levelName;
  final String levelLabel;
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
