import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';

part 'scheduler_analysis.freezed.dart';

/// Intermediate analysis results produced from a [SchedulerInput].
///
/// [SchedulerAnalysis] captures everything computed after loading data but
/// before task assembly. Each [SchedulingStrategy] implementation derives
/// this from its [SchedulerInput] and then uses it to assemble [TaskAssembly].
///
/// Keeping analysis and assembly separate makes each phase independently
/// testable and allows strategies to share common analysis logic.
@freezed
abstract class SchedulerAnalysis with _$SchedulerAnalysis {
  const factory SchedulerAnalysis({
    /// Completion map: sefariaRef → { stageOrder → completedAt }.
    required Map<String, Map<int, DateTime>> completionMap,

    /// Stages sorted ascending by stageOrder.
    required List<SchedulerStage> sortedStages,

    /// Content items sorted in learning order (custom or default).
    required List<SchedulerContentItem> orderedItems,

    /// Ordered sefaria refs derived from [orderedItems].
    required List<String> orderedRefs,

    /// Refs that have never been started (no first-stage completion and
    /// not in [priorlyShownRefs]).  Used by new-learning task assembly.
    required List<String> newLearningRefs,

    /// Number of new leaf items (or coarse units) to assign today.
    required int newItemsPerDay,

    /// Total chazara tasks already identified (overdue + scheduled).
    /// Strategies use this to cap or balance new-learning output.
    required int chazaraLoadCount,

    /// True when today is a study day (new learning is permitted).
    required bool isStudyDay,

    /// The first-stage stageOrder value for quick access.
    required int firstStageOrder,
  }) = _SchedulerAnalysis;
}
