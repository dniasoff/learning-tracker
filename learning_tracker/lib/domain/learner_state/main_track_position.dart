/// Engine stage 3b: `schedulableRefs`, the FR-12a current unit and the
/// main-track position (AD-33). Derived on every run, never persisted.
///
/// DNI-465 owns the derivation. The engine feeds it the learner order `O`
/// (`orderedLeaves`, DNI-467) and the ground held by `holdsGround`
/// sub-tracks (DNI-467); with no live order docs `O` is the corpus order,
/// and with no sub-tracks nothing is held.
library;

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/derived_curriculum_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/learnt_set.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

/// The FR-12a unit containing [leaf]: its nearest ancestor (or itself) at
/// the innermost of `corpus.unitLevels` (Mishnayos: the masechta). Null
/// when [leaf] is not in [corpus] or the curriculum has no unit level.
NodeEntry? unitOf(LeafRef leaf, Corpus corpus) {
  final levels = corpus.unitLevels;
  if (levels.isEmpty) return null;
  final unitLevel = levels.last;
  var node = corpus.nodeForRef(leaf);
  while (node != null && node.level != unitLevel) {
    node = corpus.parentOf(node);
  }
  return node;
}

/// AD-33 `schedulableRefs`: the leaves of [order] (`O`) that are not
/// [learnt] and not in [heldGround], ordered as the leaves at or after
/// [start] in `O` order, then the leaves before [start]. A [start] that is
/// not in [order] rotates nothing.
List<LeafRef> schedulableRefs({
  required List<LeafRef> order,
  required Set<LeafRef> learnt,
  Set<LeafRef> heldGround = const {},
  LeafRef? start,
}) {
  final at = start == null ? -1 : order.indexOf(start);
  final rotated = at <= 0
      ? order
      : [...order.sublist(at), ...order.sublist(0, at)];
  return List.unmodifiable(
    rotated.where((l) => !learnt.contains(l) && !heldGround.contains(l)),
  );
}

/// The instant `tracking_start_ref` was last set for [curriculumId]: the
/// `original_at ?? at` of the latest `mainTrackProgram` change-log entry
/// that changed `profile_programs/{curriculumId}.tracking_start_ref`
/// (ordered by that instant, then entry id). Null when [intentHistory]
/// holds none.
DateTime? trackingStartAt(
  List<ChangeLogEntry> intentHistory,
  String curriculumId,
) {
  ChangeLogEntry? latest;
  DateTime instant(ChangeLogEntry e) => e.originalAt ?? e.at;
  for (final entry in intentHistory) {
    if (entry.entity != GovernedEntity.mainTrackProgram ||
        entry.entityId != curriculumId ||
        !entry.changedKeys.any(
          (k) =>
              k.collection == MainTrackProgram.collection &&
              k.docId == curriculumId &&
              k.field == MainTrackProgram.kTrackingStartRef,
        )) {
      continue;
    }
    final current = latest;
    if (current == null) {
      latest = entry;
      continue;
    }
    final byTime = instant(entry).compareTo(instant(current));
    if (byTime > 0 || (byTime == 0 && entry.id.compareTo(current.id) > 0)) {
      latest = entry;
    }
  }
  return latest == null ? null : instant(latest);
}

/// The AD-33 main-track stage of one evaluated curriculum.
///
/// * `schedulableRefs` per [schedulableRefs].
/// * The anchor is the later, by time, of the leaf of the latest counted
///   `source = main` `dated`/`catch_up` leaf event in [countedLearns]
///   (event order: `effectiveAt`, then id) and [start] (at [startAt]).
///   [start] wins a tie, and loses to any such event when [startAt] is
///   unknown. A [start] outside [order] is not an anchor.
/// * The current unit is [unitOf] the anchor, only while it still has a
///   schedulable leaf. Position = its first schedulable leaf, else the
///   first of `schedulableRefs`.
///
/// Sub-track, free-tick and before-tracking events never move the anchor.
MainTrackRecord deriveMainTrack({
  required Corpus corpus,
  required List<LeafRef> order,
  required Set<LeafRef> learnt,
  required List<LearningEvent> countedLearns,
  Set<LeafRef> heldGround = const {},
  LeafRef? start,
  DateTime? startAt,
}) {
  final validStart = start != null && order.contains(start) ? start : null;
  final schedulable = schedulableRefs(
    order: order,
    learnt: learnt,
    heldGround: heldGround,
    start: validStart,
  );
  LearningEvent? latestMain;
  for (final e in countedLearns.reversed) {
    if (e.source == LearningEvent.sourceMain &&
        (e.dateState == DateState.dated || e.dateState == DateState.catchUp) &&
        coveredLeaves(e, corpus).isNotEmpty) {
      latestMain = e;
      break;
    }
  }
  final LeafRef? anchor;
  if (latestMain != null &&
      (validStart == null ||
          startAt == null ||
          effectiveAt(latestMain).isAfter(startAt))) {
    anchor = latestMain.ref;
  } else {
    anchor = validStart;
  }
  final unit = anchor == null ? null : unitOf(anchor, corpus);
  if (unit != null) {
    final unitLeaves = corpus.leavesUnder(unit).toSet();
    for (final leaf in schedulable) {
      if (unitLeaves.contains(leaf)) {
        return MainTrackRecord(
          schedulableRefs: schedulable,
          currentUnit: unit,
          position: leaf,
        );
      }
    }
  }
  return MainTrackRecord(
    schedulableRefs: schedulable,
    position: schedulable.isEmpty ? null : schedulable.first,
  );
}
