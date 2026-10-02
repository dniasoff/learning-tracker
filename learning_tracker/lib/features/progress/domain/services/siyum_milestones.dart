/// Siyum milestones and unit completions from the engine's completed units
/// (DNI-474 AC-4; Consistency → Siyum; FR-17).
///
/// The engine owns completion: `CurriculumState.completedUnits` with each
/// unit's completion number k and `first_completed_at(k)`. This file only
/// lays them out for the siyumim screens: one timeline row per completion
/// (k = 1, 2, …), unit vs aggregate tier from the corpus' siyum levels,
/// and the curriculum-level siyum when every top-level unit is complete.
library;

import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';

/// The siyum tier of a unit at [level]: with two siyum levels the outer
/// one is the aggregate (seder) and the inner the unit (masechta); with
/// one, it is the unit (sefer).
MilestoneLevel milestoneLevelOf(Corpus corpus, String level) {
  final levels = corpus.unitLevels;
  if (levels.length >= 2 && level == levels.first) {
    return MilestoneLevel.aggregate;
  }
  return MilestoneLevel.unit;
}

/// The label keys of a unit node: its own hierarchy value and its level-1
/// parent value, read from the ContentIndex container item whose
/// `sefariaRef` is the node ref.
({String key, String? parentL1}) unitLabelKeys(
  NodeEntry unit,
  Map<String, ContentItem> itemsByRef,
) {
  final item = itemsByRef[unit.ref];
  if (item == null) return (key: unit.ref, parentL1: null);
  final l2 = item.level2;
  if (l2 != null && l2.isNotEmpty) return (key: l2, parentL1: item.level1);
  return (key: item.level1, parentL1: null);
}

/// Every completion of [state]'s completed units as a milestone, one per
/// completion number k (achieved at `first_completed_at(k)`), plus the
/// curriculum-level siyum, newest first.
List<MilestoneAchievement> siyumMilestones({
  required CurriculumId curriculum,
  required CurriculumState? state,
  required Corpus corpus,
  required Map<String, ContentItem> itemsByRef,
  required String curriculumDisplayName,
}) {
  final completed = state?.completedUnits ?? const <CompletedUnit>[];
  if (completed.isEmpty) return const [];
  final out = <MilestoneAchievement>[];
  for (final unit in completed) {
    final keys = unitLabelKeys(unit.unit, itemsByRef);
    final level = milestoneLevelOf(corpus, unit.unit.level);
    for (var k = 1; k <= unit.completionNumber; k++) {
      final at = unit.firstCompletedAt[k];
      if (at == null) continue;
      out.add(
        level == MilestoneLevel.aggregate
            ? MilestoneAchievement(
                type: 'seder_complete',
                level: level,
                curriculumId: curriculum,
                displayName: keys.key,
                aggregateKey: keys.key,
                containedUnitKeys: [
                  for (final child in corpus.childrenOf(unit.unit))
                    if (corpus.unitLevels.contains(child.level))
                      unitLabelKeys(child, itemsByRef).key,
                ]..sort(),
                achievedAt: at,
                completionNumber: k,
              )
            : MilestoneAchievement(
                type: 'unit_complete',
                level: level,
                curriculumId: curriculum,
                displayName: keys.key,
                unitKey: keys.key,
                unitScope: unit.unit.level,
                parentAggregateKey: keys.parentL1,
                achievedAt: at,
                completionNumber: k,
              ),
      );
    }
  }
  final finishedAt = curriculumCompletedAt(completed, corpus);
  if (finishedAt != null) {
    out.add(
      MilestoneAchievement(
        type: 'curriculum_complete',
        level: MilestoneLevel.curriculum,
        curriculumId: curriculum,
        displayName: curriculumDisplayName,
        achievedAt: finishedAt,
      ),
    );
  }
  out.sort((a, b) => b.achievedAt.compareTo(a.achievedAt));
  return out;
}

/// When every top-level siyum unit of [corpus] is complete, the latest of
/// their `first_completed_at(1)`; otherwise null.
DateTime? curriculumCompletedAt(List<CompletedUnit> completed, Corpus corpus) {
  if (corpus.unitLevels.isEmpty) return null;
  final topLevel = corpus.unitLevels.first;
  final tops = [
    for (final root in corpus.roots)
      if (root.level == topLevel) root,
  ];
  if (tops.isEmpty) return null;
  final byNode = {for (final u in completed) u.unit: u};
  DateTime? latest;
  for (final top in tops) {
    final at = byNode[top]?.firstCompletedAt[1];
    if (at == null) return null;
    if (latest == null || at.isAfter(latest)) latest = at;
  }
  return latest;
}

/// The unit completions (one per completion number) of [state].
List<UnitCompletion> unitCompletions({
  required CurriculumState? state,
  required Map<String, ContentItem> itemsByRef,
}) => [
  for (final unit in state?.completedUnits ?? const <CompletedUnit>[])
    for (var k = 1; k <= unit.completionNumber; k++)
      if (unit.firstCompletedAt[k] case final at?)
        UnitCompletion(
          unitIdentifier: unitLabelKeys(unit.unit, itemsByRef).key,
          entryScope: unit.unit.level,
          entryKey: unitLabelKeys(unit.unit, itemsByRef).key,
          parentL1Key: unitLabelKeys(unit.unit, itemsByRef).parentL1,
          completedAt: at,
          completionNumber: k,
          isManual: false,
        ),
];

/// The number of siyum units at the inner (unit) tier of [corpus].
int unitTierCount(Corpus corpus) {
  if (corpus.unitLevels.isEmpty) return 0;
  final level = corpus.unitLevels.last;
  var count = 0;
  void walk(NodeEntry node) {
    if (node.level == level) {
      count++;
      return;
    }
    corpus.childrenOf(node).forEach(walk);
  }

  corpus.roots.forEach(walk);
  return count;
}
