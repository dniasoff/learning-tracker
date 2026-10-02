import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/domain/services/siyum_milestones.dart';
import 'package:learning_tracker/features/progress/domain/siyum_granularity_filter.dart';
import 'package:learning_tracker/features/progress/domain/siyum_unit_scope.dart';
import 'package:learning_tracker/features/progress/presentation/providers/learner_progress_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'journey_providers.g.dart';

@riverpod
class JourneySortModeNotifier extends _$JourneySortModeNotifier {
  @override
  JourneySortModeValue build() => JourneySortModeValue.grouped;

  void toggle() {
    state = state == JourneySortModeValue.grouped
        ? JourneySortModeValue.chronological
        : JourneySortModeValue.grouped;
  }

  void setMode(JourneySortModeValue mode) {
    state = mode;
  }
}

/// Thrown when [journeyViewModel] runs with no active learner.
class JourneyNoActiveProfileException implements Exception {
  const JourneyNoActiveProfileException();

  @override
  String toString() =>
      'JourneyNoActiveProfileException: journeyViewModel was read with no '
      'active learner — there is no learner state to read without one.';
}

/// The siyumim journey of the active learner (DNI-474 AC-4).
///
/// Every milestone comes from the engine's completed units
/// (`CurriculumState.completedUnits`, from any source including backfill
/// and correction): one row per completion number k, dated
/// `first_completed_at(k)`. A void that takes a completion away removes
/// its row, and a later re-completion adds a row with its new date. The
/// chosen siyum granularity filters what is shown; the level counters
/// count each unit's first completion.
@riverpod
Future<JourneyViewModel> journeyViewModel(Ref ref) async {
  final state = await watchActiveLearnerState(ref);
  if (state == null) throw const JourneyNoActiveProfileException();
  final activeCurricula = await ref.watch(activeCurriculaProvider.future);
  final curricula = <CurriculumId>{
    ...activeCurricula,
    for (final key in state.curricula.keys)
      if (CurriculumId.fromStorageKey(key) case final c?) c,
  }.toList()..sort((a, b) => a.index.compareTo(b.index));

  final journeys = <CurriculumJourney>[];
  var totalCompletions = 0;
  final allUniqueUnits = <String>{};
  var unitLevelSiyumimCount = 0;
  var aggregateLevelSiyumimCount = 0;
  var curriculumLevelSiyumimCount = 0;

  for (final curriculum in curricula) {
    final corpus = await ref.watch(progressCorpusProvider(curriculum).future);
    if (corpus == null) continue;
    final content = await ref.watch(
      curriculumContentProvider(curriculum).future,
    );
    final itemsByRef = _containersByRef(content);
    final curriculumState = state[curriculum.storageKey];
    final completions = unitCompletions(
      state: curriculumState,
      itemsByRef: itemsByRef,
    );
    final milestones = siyumMilestones(
      curriculum: curriculum,
      state: curriculumState,
      corpus: corpus,
      itemsByRef: itemsByRef,
      curriculumDisplayName: curriculumLabelTextFromRef(
        ref,
        curriculum: curriculum,
      ),
    );
    final visibleMilestones = filterMilestonesByGranularity(
      milestones,
      ref.watch(siyumGranularityProvider(curriculum)),
    );

    for (final m in visibleMilestones) {
      if (m.completionNumber != 1) continue;
      switch (m.level) {
        case MilestoneLevel.unit:
          unitLevelSiyumimCount++;
        case MilestoneLevel.aggregate:
          aggregateLevelSiyumimCount++;
        case MilestoneLevel.curriculum:
          curriculumLevelSiyumimCount++;
      }
    }

    final uniqueUnits = {
      for (final c in completions) '${curriculum.storageKey}|${c.entryKey}',
    };
    totalCompletions += completions.length;
    allUniqueUnits.addAll(uniqueUnits);
    final totalUnits = unitTierCount(corpus);
    if (completions.isNotEmpty || totalUnits > 0) {
      journeys.add(
        CurriculumJourney(
          curriculumId: curriculum,
          completions: completions,
          uniqueUnitsCompleted: uniqueUnits.length,
          totalUnitsAvailable: totalUnits,
          milestones: visibleMilestones,
        ),
      );
    }
  }

  return JourneyViewModel(
    curricula: journeys,
    totalCompletions: totalCompletions,
    totalUniqueUnits: allUniqueUnits.length,
    unitLevelSiyumimCount: unitLevelSiyumimCount,
    aggregateLevelSiyumimCount: aggregateLevelSiyumimCount,
    curriculumLevelSiyumimCount: curriculumLevelSiyumimCount,
  );
}

/// Which siyum tiers [curriculum] offers in the granularity selector — a
/// property of the curriculum's content structure, not of the learner: the
/// unit tier, the aggregate tier when its level-2 values name units
/// grouped under more than one level-1 group (Mishnayos sederim), and the
/// whole curriculum.
@riverpod
Future<List<MilestoneLevel>> availableSiyumTiers(
  Ref ref,
  CurriculumId curriculum,
) async {
  final content = await ref.watch(curriculumContentProvider(curriculum).future);
  final groups = <String, Set<String>>{};
  for (final item in content) {
    final unit = item.level2;
    if (unit != null) groups.putIfAbsent(item.level1, () => {}).add(unit);
  }
  final offersAggregate =
      hasNamedLevel2Unit(curriculum) &&
      groups.length > 1 &&
      groups.values.any((units) => units.isNotEmpty);
  return [
    MilestoneLevel.unit,
    if (offersAggregate) MilestoneLevel.aggregate,
    MilestoneLevel.curriculum,
  ];
}

/// The container items of [content] by `sefariaRef` (unit label lookup).
Map<String, ContentItem> _containersByRef(List<ContentItem> content) => {
  for (final item in content)
    if (!item.isLeaf) item.sefariaRef: item,
};
