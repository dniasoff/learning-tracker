import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/progress/domain/models/curriculum_progress_data.dart';
import 'package:learning_tracker/features/progress/domain/services/learner_progress.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart'
    as domain_stage;

/// Lays a curriculum's scoped hierarchy out with the engine's learnt state
/// for the Curriculum Progress screen (DNI-474).
///
/// It derives no learnt state: [learnt] is the engine's learnt-leaf set
/// (distinct, every source and date state, FR-14) and [activity] the
/// engine's counted learning per leaf. Per hierarchy level it counts learnt
/// leaves (repeats once) and, per stage, the counted main-track events of
/// that stage.
class CurriculumProgressService {
  /// Computes [CurriculumProgressData].
  ///
  /// [contentItems] — the learner's scoped content items (leaves and
  ///   containers).
  /// [learnt] — the engine's learnt leaves of the curriculum.
  /// [activity] — the engine's counted learning per leaf.
  /// [stageDefinitions] — the track's stages, in order.
  /// [levelLabels] — hierarchy level labels (e.g. ['Seder', 'Masechta']).
  static CurriculumProgressData compute({
    required String curriculumId,
    required List<ContentItem> contentItems,
    required Set<String> learnt,
    required Map<String, LeafActivity> activity,
    required List<domain_stage.StageDefinition> stageDefinitions,
    required List<String> levelLabels,
  }) {
    final leafItems = contentItems.where((c) => c.isLeaf).toList();
    final stageOrders = stageDefinitions.map((s) => s.stageOrder).toSet();

    var completedAllStages = 0;
    var inProgressCount = 0;
    var notStartedCount = 0;
    for (final leaf in leafItems) {
      if (!learnt.contains(leaf.sefariaRef)) {
        notStartedCount++;
        continue;
      }
      final stages = activity[leaf.sefariaRef]?.stages ?? const <int>{};
      if (stageOrders.length <= 1 || stageOrders.every(stages.contains)) {
        completedAllStages++;
      } else {
        inProgressCount++;
      }
    }

    final curriculumEnum = _resolveCurriculumId(curriculumId);
    final hierarchyLevels = _buildLevel1Progress(
      curriculumEnum: curriculumEnum,
      leafItems: leafItems,
      learnt: learnt,
      activity: activity,
      stageDefinitions: stageDefinitions,
      levelLabels: levelLabels,
    );

    return CurriculumProgressData(
      curriculumId: curriculumId,
      hierarchyLevels: hierarchyLevels,
      overallStats: OverallCurriculumStats(
        totalItems: leafItems.length,
        completedAllStages: completedAllStages,
        inProgress: inProgressCount,
        notStarted: notStartedCount,
      ),
    );
  }

  /// The distinct learnt share of [leafItems] (FR-14): repeats count once.
  static double computeCompletionPercentage({
    required List<ContentItem> leafItems,
    required Set<String> learnt,
  }) {
    if (leafItems.isEmpty) return 0.0;
    final learntCount = leafItems
        .where((item) => learnt.contains(item.sefariaRef))
        .length;
    return learntCount / leafItems.length;
  }

  static CurriculumId _resolveCurriculumId(String storageKey) =>
      CurriculumId.fromStorageKey(storageKey) ?? CurriculumId.mishnayos;

  static List<HierarchyLevelProgress> _buildLevel1Progress({
    required CurriculumId curriculumEnum,
    required List<ContentItem> leafItems,
    required Set<String> learnt,
    required Map<String, LeafActivity> activity,
    required List<domain_stage.StageDefinition> stageDefinitions,
    required List<String> levelLabels,
  }) {
    final grouped = <String, List<ContentItem>>{};
    for (final item in leafItems) {
      grouped.putIfAbsent(item.level1, () => []).add(item);
    }
    return [
      for (final MapEntry(key: level1Name, value: items) in grouped.entries)
        _buildLevelProgress(
          curriculumEnum: curriculumEnum,
          level: 1,
          levelName: level1Name,
          leafItems: items,
          learnt: learnt,
          activity: activity,
          stageDefinitions: stageDefinitions,
          subLevels: levelLabels.length > 1
              ? _buildLevel2Progress(
                  curriculumEnum: curriculumEnum,
                  leafItems: items,
                  learnt: learnt,
                  activity: activity,
                  stageDefinitions: stageDefinitions,
                )
              : null,
        ),
    ];
  }

  static List<HierarchyLevelProgress> _buildLevel2Progress({
    required CurriculumId curriculumEnum,
    required List<ContentItem> leafItems,
    required Set<String> learnt,
    required Map<String, LeafActivity> activity,
    required List<domain_stage.StageDefinition> stageDefinitions,
  }) {
    final grouped = <String, List<ContentItem>>{};
    for (final item in leafItems) {
      grouped.putIfAbsent(item.level2 ?? 'Unknown', () => []).add(item);
    }
    return [
      for (final MapEntry(key: level2Name, value: items) in grouped.entries)
        _buildLevelProgress(
          curriculumEnum: curriculumEnum,
          level: 2,
          levelName: level2Name,
          leafItems: items,
          learnt: learnt,
          activity: activity,
          stageDefinitions: stageDefinitions,
        ),
    ];
  }

  static HierarchyLevelProgress _buildLevelProgress({
    required CurriculumId curriculumEnum,
    required int level,
    required String levelName,
    required List<ContentItem> leafItems,
    required Set<String> learnt,
    required Map<String, LeafActivity> activity,
    required List<domain_stage.StageDefinition> stageDefinitions,
    List<HierarchyLevelProgress>? subLevels,
  }) {
    final learntCount = leafItems
        .where((item) => learnt.contains(item.sefariaRef))
        .length;
    final stageCounts = <int, int>{};
    for (final item in leafItems) {
      for (final stage in activity[item.sefariaRef]?.stages ?? const <int>{}) {
        stageCounts[stage] = (stageCounts[stage] ?? 0) + 1;
      }
    }
    return HierarchyLevelProgress(
      curriculumId: curriculumEnum,
      level: level,
      levelName: levelName,
      totalItems: leafItems.length,
      completedItems: learntCount,
      stageBreakdown: [
        for (final sd in stageDefinitions)
          StageBreakdownEntry(
            stageName: sd.stageName,
            count: stageCounts[sd.stageOrder] ?? 0,
          ),
      ],
      trackBreakdown: const {},
      subLevels: subLevels,
    );
  }
}
