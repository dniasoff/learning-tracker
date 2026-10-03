/// *Yes, all of it* on a catch-up card (Story 3.3, DNI-506 T1): the
/// deterministic expansion of a pending card into one [CatchUpAction].
///
/// Consumes Story 3.2's card (DNI-505, `catch_up_card_projection.dart`)
/// as it is: its lock, its covered locked days and, per curriculum and
/// day, the main-track planner tasks and each eligible sub-track's
/// planned leaves. Nothing is recomputed here (A-3: the planned amounts
/// are already on the card).
///
/// Every main-track task becomes a `main` leaf carrying the planner's
/// stage (AC-1 [ASSUMPTION]: the stage on the planned task is kept, never
/// inferred); every sub-track leaf becomes a leaf of that sub-track's
/// ULID with no stage. Each is dated to the locked day it is listed
/// under. Order is card order: curriculum, then day, then main before
/// sub-tracks (hub order), so the command's ascending ids follow it.
///
/// Pure Dart.
library;

import 'package:learning_tracker/domain/learner_state/catch_up_card_projection.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learning/domain/commands/catch_up_commands.dart';

/// The *Yes, all of it* action of [card].
///
/// [refOf] and [stageOf] read a main-track task's leaf and planner stage.
/// A leaf listed twice under one day and source with the same stage is
/// recorded once.
CatchUpAction buildCatchUpAllAction<T>(
  CatchUpCard<T> card, {
  required LeafRef Function(T task) refOf,
  required int? Function(T task) stageOf,
}) {
  final leaves = <CatchUpLeaf>[];
  final seen = <CatchUpLeaf>{};
  void add(CatchUpLeaf leaf) {
    if (seen.add(leaf)) leaves.add(leaf);
  }

  for (final group in card.groups) {
    for (final day in group.days) {
      for (final task in day.mainTasks) {
        add(
          CatchUpLeaf(
            curriculumId: group.curriculumId,
            ref: refOf(task),
            source: LearningEvent.sourceMain,
            learnedOn: day.day.date,
            stage: stageOf(task),
          ),
        );
      }
      for (final plan in day.subTracks) {
        for (final ref in plan.leaves) {
          add(
            CatchUpLeaf(
              curriculumId: group.curriculumId,
              ref: ref,
              source: plan.subTrackId,
              learnedOn: day.day.date,
            ),
          );
        }
      }
    }
  }
  return CatchUpAction(
    lock: card.window.lock,
    mode: CatchUpMode.all,
    lockedDaysOffered: card.window.lockedDays.length,
    leaves: leaves,
  );
}
