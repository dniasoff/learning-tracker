/// Engine stage 4: completed units and completion numbers (Consistency →
/// Siyum; FR-17; `prd-deviations` #11).
///
/// Completion is derived from the counted events on every run, so it is
/// retractable: a void that removes the threshold event removes the
/// completion, and a later re-completion has a new `first_completed_at(1)`.
library;

import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/learnt_set.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

/// Storage key `stage_order` of a `stage_definitions` doc.
const stageOrderKey = 'stage_order';

/// The first stage order of a curriculum (AD-32 `firstStageOrder`): the
/// lowest `stage_order` of its live [stages] docs. With no readable stage
/// doc, the lowest `stage` on its `source = main` [learns]; with neither,
/// null (no event is a later stage).
int? firstStageOrder(
  List<MainTrackConfigDoc> stages,
  Iterable<LearningEvent> learns,
) {
  int? lowest;
  for (final doc in stages) {
    final order = doc.fields[stageOrderKey];
    if (doc.endedAt == null && order is int) {
      if (lowest == null || order < lowest) lowest = order;
    }
  }
  if (lowest != null) return lowest;
  for (final e in learns) {
    final stage = e.stage;
    if (stage != null && (lowest == null || stage < lowest)) lowest = stage;
  }
  return lowest;
}

final class _Unit {
  _Unit(this.node, this.index, this.leaves);

  final NodeEntry node;
  final int index;
  final List<LeafRef> leaves;
  int k = 0;
  int atLeastNext = 0;
  final Map<int, DateTime> firstCompletedAt = {};
}

/// The units of [corpus] completed by [countedLearns] (in event order),
/// in completion order.
///
/// * Units are the nodes at `corpus.unitLevels` whose every leaf is in the
///   learner's corpus ([inScope]); a unit only partly in scope never
///   completes.
/// * `count(U, leaf)` = the counted events covering the leaf, excluding
///   events with `stage` > [firstStage]; a node event counts once per
///   covered leaf.
/// * Completion number k is reached when the minimum count over U's leaves
///   is ≥ k, and `firstCompletedAt[k]` is the `effectiveAt` of the event
///   that reached it. Only units with k ≥ 1 are returned.
/// * Completion order is `firstCompletedAt[1]`; one event completing
///   several units lists the inner unit first (masechta before seder),
///   then ContentIndex order.
List<CompletedUnit> completedUnits({
  required Corpus corpus,
  required bool Function(LeafRef leaf) inScope,
  required List<LearningEvent> countedLearns,
  int? firstStage,
}) {
  final levels = corpus.unitLevels.toSet();
  if (levels.isEmpty) return const [];
  final units = <_Unit>[];
  var index = 0;
  void walk(NodeEntry node) {
    if (levels.contains(node.level)) {
      final leaves = corpus.leavesUnder(node);
      if (leaves.isNotEmpty && leaves.every(inScope)) {
        units.add(_Unit(node, index, leaves));
      }
    }
    index++;
    corpus.childrenOf(node).forEach(walk);
  }

  corpus.roots.forEach(walk);
  if (units.isEmpty) return const [];

  final unitsByLeaf = <LeafRef, List<_Unit>>{};
  for (final unit in units) {
    for (final leaf in unit.leaves) {
      (unitsByLeaf[leaf] ??= []).add(unit);
    }
  }
  final counts = <LeafRef, int>{};
  for (final event in countedLearns) {
    final stage = event.stage;
    if (stage != null && firstStage != null && stage > firstStage) continue;
    final touched = <_Unit>{};
    for (final leaf in coveredLeaves(event, corpus)) {
      final owners = unitsByLeaf[leaf];
      if (owners == null) continue;
      final count = counts[leaf] = (counts[leaf] ?? 0) + 1;
      for (final unit in owners) {
        if (count == unit.k + 1) unit.atLeastNext++;
        touched.add(unit);
      }
    }
    for (final unit in touched) {
      while (unit.atLeastNext == unit.leaves.length) {
        unit.k++;
        unit.firstCompletedAt[unit.k] = effectiveAt(event);
        unit.atLeastNext = unit.leaves
            .where((l) => (counts[l] ?? 0) >= unit.k + 1)
            .length;
      }
    }
  }

  final depth = {for (final (i, level) in corpus.unitLevels.indexed) level: i};
  final completed = units.where((u) => u.k >= 1).toList()
    ..sort((a, b) {
      final byTime = a.firstCompletedAt[1]!.compareTo(b.firstCompletedAt[1]!);
      if (byTime != 0) return byTime;
      final byDepth = depth[b.node.level]!.compareTo(depth[a.node.level]!);
      return byDepth != 0 ? byDepth : a.index.compareTo(b.index);
    });
  return List.unmodifiable([
    for (final u in completed)
      CompletedUnit(
        unit: u.node,
        completionNumber: u.k,
        firstCompletedAt: Map.unmodifiable(u.firstCompletedAt),
      ),
  ]);
}
