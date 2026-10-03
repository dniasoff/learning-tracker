/// Engine stage 4: completed units and completion numbers (Consistency →
/// Siyum; FR-17; `prd-deviations` #11).
///
/// Completion is derived from the counted events on every run, so it is
/// retractable: a void that removes the threshold event removes the
/// completion, and a later re-completion has a new `first_completed_at(1)`.
library;

import 'dart:typed_data';

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

  /// [leaves] as slots into the per-leaf count array (fyh.325).
  late final Int32List slots;
  int k = 0;
  int atLeastNext = 0;

  /// The last event (by position) that touched this unit; -1 for none.
  int touchedBy = -1;
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

  // fyh.325: every unit leaf gets an int slot, so the per-event loop is
  // array arithmetic. Counts, owners and touch order are as before: a leaf
  // count is the number of counted events covering it, and the units an
  // event touched are re-checked in first-touch order.
  final slotOf = <LeafRef, int>{};
  final owners = <List<_Unit>>[];
  for (final unit in units) {
    final slots = Int32List(unit.leaves.length);
    for (final (i, leaf) in unit.leaves.indexed) {
      final slot = slotOf.putIfAbsent(leaf, () {
        owners.add([]);
        return owners.length - 1;
      });
      owners[slot].add(unit);
      slots[i] = slot;
    }
    unit.slots = slots;
  }
  final counts = Int32List(owners.length);
  // The slots of a multi-leaf (node) event's leaves, by the identity of
  // its covered-leaf list: expandGround memoises that list per node, so a
  // repeated node event resolves its slots once.
  final nodeSlots = Map<List<LeafRef>, Int32List>.identity();
  Int32List slotsOf(List<LeafRef> leaves) {
    final out = Int32List(leaves.length);
    for (final (i, leaf) in leaves.indexed) {
      out[i] = slotOf[leaf] ?? -1;
    }
    return out;
  }

  final touched = <_Unit>[];
  var position = 0;
  for (final event in countedLearns) {
    final eventIndex = position++;
    final stage = event.stage;
    if (stage != null && firstStage != null && stage > firstStage) continue;
    final leaves = coveredLeaves(event, corpus);
    if (leaves.isEmpty) continue;
    final Int32List slots;
    if (leaves.length == 1) {
      final slot = slotOf[leaves.first];
      if (slot == null) continue;
      slots = Int32List(1)..[0] = slot;
    } else {
      slots = nodeSlots[leaves] ??= slotsOf(leaves);
    }
    touched.clear();
    for (final slot in slots) {
      if (slot < 0) continue;
      final count = ++counts[slot];
      for (final unit in owners[slot]) {
        if (count == unit.k + 1) unit.atLeastNext++;
        if (unit.touchedBy != eventIndex) {
          unit.touchedBy = eventIndex;
          touched.add(unit);
        }
      }
    }
    for (final unit in touched) {
      while (unit.atLeastNext == unit.leaves.length) {
        unit.k++;
        unit.firstCompletedAt[unit.k] = effectiveAt(event);
        var atLeast = 0;
        for (final slot in unit.slots) {
          if (counts[slot] >= unit.k + 1) atLeast++;
        }
        unit.atLeastNext = atLeast;
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
