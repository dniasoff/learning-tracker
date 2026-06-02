import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/progress/domain/models/curriculum_progress_data.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart'
    as domain_stage;

/// Pure computation service for curriculum progress aggregation.
///
/// Takes raw data (content items, completions, stage definitions) and
/// computes hierarchy-level breakdowns, stage breakdowns, track breakdowns,
/// and overall curriculum statistics.
class CurriculumProgressService {
  /// Compute full progress data for a curriculum.
  ///
  /// [contentItems] — all content items (leaf + container) for the curriculum
  /// [completions] — all completion records for the curriculum
  /// [stageDefinitions] — stage definitions for this curriculum, ordered by stageOrder
  /// [levelLabels] — hierarchy level labels (e.g., ['Seder', 'Masechta', 'Perek', 'Mishna'])
  static CurriculumProgressData compute({
    required String curriculumId,
    required List<ContentItem> contentItems,
    required List<Completion> completions,
    required List<domain_stage.StageDefinition> stageDefinitions,
    required List<String> levelLabels,
  }) {
    final leafItems = contentItems.where((c) => c.isLeaf).toList();
    final totalLeafCount = leafItems.length;

    // Build a set of completed refs per stage
    // Key: sefariaRef, Value: set of completed stageIds
    final completedStagesPerRef = <String, Set<int>>{};
    for (final c in completions) {
      completedStagesPerRef.putIfAbsent(c.sefariaRef, () => {}).add(c.stageId);
    }

    final totalStageCount = stageDefinitions.length;

    // Overall stats
    var completedAllStages = 0;
    var inProgressCount = 0;
    var notStartedCount = 0;
    for (final leaf in leafItems) {
      final stages = completedStagesPerRef[leaf.sefariaRef];
      if (stages == null || stages.isEmpty) {
        notStartedCount++;
      } else if (stages.length >= totalStageCount) {
        completedAllStages++;
      } else {
        inProgressCount++;
      }
    }

    final overallStats = OverallCurriculumStats(
      totalItems: totalLeafCount,
      completedAllStages: completedAllStages,
      inProgress: inProgressCount,
      notStarted: notStartedCount,
    );

    // Build hierarchy levels (level 1 grouping)
    final hierarchyLevels = _buildLevel1Progress(
      leafItems: leafItems,
      completions: completions,
      stageDefinitions: stageDefinitions,
      levelLabels: levelLabels,
    );

    return CurriculumProgressData(
      curriculumId: curriculumId,
      hierarchyLevels: hierarchyLevels,
      overallStats: overallStats,
    );
  }

  /// Compute completion percentage for a set of items based on completions.
  ///
  /// An item is "completed" if it has at least one completion record.
  ///
  /// ### Layer 3 migration note
  ///
  /// Callers MUST pass tier-filtered completions. For Manage Tracks / achievement
  /// displays pass [CompletionTierFilter.trackAchievement] rows (live +
  /// bulkInTrack); for lifetime views pass [CompletionTierFilter.lifetime].
  /// Passing unfiltered all-tiers completions violates the B1 credit policy.
  ///
  /// See [TrackProgressService.completionPercent] for the canonical aggregator.
  static double computeCompletionPercentage({
    required List<ContentItem> leafItems,
    required List<Completion> completions,
  }) {
    if (leafItems.isEmpty) return 0.0;
    final completedRefs = completions.map((c) => c.sefariaRef).toSet();
    final completedCount = leafItems
        .where((item) => completedRefs.contains(item.sefariaRef))
        .length;
    return completedCount / leafItems.length;
  }

  static List<HierarchyLevelProgress> _buildLevel1Progress({
    required List<ContentItem> leafItems,
    required List<Completion> completions,
    required List<domain_stage.StageDefinition> stageDefinitions,
    required List<String> levelLabels,
  }) {
    // Group leaf items by level1
    final groupedByLevel1 = <String, List<ContentItem>>{};
    for (final item in leafItems) {
      groupedByLevel1.putIfAbsent(item.level1, () => []).add(item);
    }

    // Group completions by level1 via sefariaRef lookup
    final refToLevel1 = <String, String>{};
    for (final item in leafItems) {
      refToLevel1[item.sefariaRef] = item.level1;
    }
    final completionsByLevel1 = <String, List<Completion>>{};
    for (final c in completions) {
      final l1 = refToLevel1[c.sefariaRef];
      if (l1 != null) {
        completionsByLevel1.putIfAbsent(l1, () => []).add(c);
      }
    }

    final level1Label = levelLabels.isNotEmpty ? levelLabels[0] : 'Level 1';
    final level2Label = levelLabels.length > 1 ? levelLabels[1] : 'Level 2';

    // Maintain order by first occurrence
    final orderedKeys = <String>[];
    for (final item in leafItems) {
      if (!orderedKeys.contains(item.level1)) {
        orderedKeys.add(item.level1);
      }
    }

    return orderedKeys.map((level1Name) {
      final items = groupedByLevel1[level1Name]!;
      final levelCompletions = completionsByLevel1[level1Name] ?? [];

      // Build sub-levels (level2)
      List<HierarchyLevelProgress>? subLevels;
      if (levelLabels.length > 1) {
        subLevels = _buildLevel2Progress(
          leafItems: items,
          completions: levelCompletions,
          stageDefinitions: stageDefinitions,
          levelLabel: level2Label,
        );
      }

      return _buildLevelProgress(
        levelName: level1Name,
        levelLabel: level1Label,
        leafItems: items,
        completions: levelCompletions,
        stageDefinitions: stageDefinitions,
        subLevels: subLevels,
      );
    }).toList();
  }

  static List<HierarchyLevelProgress> _buildLevel2Progress({
    required List<ContentItem> leafItems,
    required List<Completion> completions,
    required List<domain_stage.StageDefinition> stageDefinitions,
    required String levelLabel,
  }) {
    final grouped = <String, List<ContentItem>>{};
    for (final item in leafItems) {
      final key = item.level2 ?? 'Unknown';
      grouped.putIfAbsent(key, () => []).add(item);
    }

    final refToLevel2 = <String, String>{};
    for (final item in leafItems) {
      refToLevel2[item.sefariaRef] = item.level2 ?? 'Unknown';
    }
    final completionsByLevel2 = <String, List<Completion>>{};
    for (final c in completions) {
      final l2 = refToLevel2[c.sefariaRef];
      if (l2 != null) {
        completionsByLevel2.putIfAbsent(l2, () => []).add(c);
      }
    }

    final orderedKeys = <String>[];
    for (final item in leafItems) {
      final key = item.level2 ?? 'Unknown';
      if (!orderedKeys.contains(key)) {
        orderedKeys.add(key);
      }
    }

    return orderedKeys.map((level2Name) {
      final items = grouped[level2Name]!;
      final levelCompletions = completionsByLevel2[level2Name] ?? [];

      return _buildLevelProgress(
        levelName: level2Name,
        levelLabel: levelLabel,
        leafItems: items,
        completions: levelCompletions,
        stageDefinitions: stageDefinitions,
      );
    }).toList();
  }

  static HierarchyLevelProgress _buildLevelProgress({
    required String levelName,
    required String levelLabel,
    required List<ContentItem> leafItems,
    required List<Completion> completions,
    required List<domain_stage.StageDefinition> stageDefinitions,
    List<HierarchyLevelProgress>? subLevels,
  }) {
    final completedRefs = completions.map((c) => c.sefariaRef).toSet();
    final completedCount = leafItems
        .where((item) => completedRefs.contains(item.sefariaRef))
        .length;

    // Stage breakdown
    final stageCounts = <int, int>{};
    for (final c in completions) {
      stageCounts[c.stageId] = (stageCounts[c.stageId] ?? 0) + 1;
    }
    final stageBreakdown = stageDefinitions.map((sd) {
      return StageBreakdownEntry(
        stageName: sd.stageName,
        // D12: completions store stageId = the stage ORDER (1=Learn, 2=Chazara1
        // …), NOT the StageDefinition auto-increment PK. Keying the read by
        // sd.id returned 0 for every track whose stage rows didn't get PKs
        // equal to their order (i.e. every track after the first). Read by
        // stageOrder to match how completions are recorded.
        count: stageCounts[sd.stageOrder] ?? 0,
      );
    }).toList();

    // Completion count keyed by the internal track storage key (one track per
    // curriculum, so this is a single-entry map).
    final trackBreakdown = <String, int>{};
    for (final c in completions) {
      trackBreakdown[c.trackType] = (trackBreakdown[c.trackType] ?? 0) + 1;
    }

    return HierarchyLevelProgress(
      levelName: levelName,
      levelLabel: levelLabel,
      totalItems: leafItems.length,
      completedItems: completedCount,
      stageBreakdown: stageBreakdown,
      trackBreakdown: trackBreakdown,
      subLevels: subLevels,
    );
  }
}
