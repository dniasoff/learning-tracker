/// Engine stage: sub-track positions (AD-33, AD-34; DNI-493).
///
/// Each sub-track keeps its own position over its ground, independent of
/// the main track and of every other sub-track (FR-13). Everything here is
/// derived on every run and never persisted (AD-33): the position, the
/// ticked count and the remaining path.
///
/// The main-track side of sub-tracks (held ground leaves `schedulableRefs`
/// and returns when the sub-track stops holding it) is in
/// `main_track_position.dart`; the engine feeds it the ground of every
/// `holdsGround` sub-track. The AD-44 capacity, expected new ground and
/// shortfall fields of [SubTrackState] belong to DNI-494.
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/expand_ground.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/learnt_set.dart';
import 'package:learning_tracker/domain/learner_state/predicates.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

/// The [SubTrackState] of every sub-track in [subTracks] that belongs to
/// `corpus.curriculumId`, keyed by sub-track ULID.
///
/// Live and tombstoned sub-tracks both get a state: a tombstone holds no
/// ground and is not on home, but its position over its own events is
/// still derivable. [countedLearns] are the curriculum's counted `learn`
/// events (not voided, not lock-ignored); [deadline] is the curriculum's
/// live `target_date`, used only by `inForecast`.
Map<String, SubTrackState> subTrackStates({
  required List<SubTrack> subTracks,
  required Corpus corpus,
  required List<LearningEvent> countedLearns,
  required CivilDate today,
  required CivilDate? deadline,
}) {
  final mine = [
    for (final s in subTracks)
      if (s.curriculumId == corpus.curriculumId) s,
  ];
  if (mine.isEmpty) return const {};
  final ids = {for (final s in mine) s.id};
  // Leaves each sub-track source has a counted event on.
  final tickedBySource = <String, Set<LeafRef>>{};
  for (final e in countedLearns) {
    final source = e.source;
    if (source == null || !ids.contains(source)) continue;
    (tickedBySource[source] ??= {}).addAll(coveredLeaves(e, corpus));
  }
  return {
    for (final s in mine)
      s.id: subTrackState(
        s,
        ground: expandGround(s.ground, corpus),
        tickedInSource: tickedBySource[s.id] ?? const {},
        today: today,
        deadline: deadline,
      ),
  };
}

/// The state of one sub-track [s] (AD-33, AD-34).
///
/// * [ground] is `expandGround(s.ground)`.
/// * [tickedInSource] are the leaves with a counted `learn` event whose
///   `source` is `s.id` (from any curriculum leaf; only ground leaves
///   count).
/// * Position = the first leaf of [ground] not in [tickedInSource], or
///   null when every ground leaf is ticked in this sub-track (or there is
///   no ground). A leaf learnt from another source does not advance it.
/// * Ticked = the distinct ground leaves in [tickedInSource].
/// * Remaining path = [ground] from the position to the end, learnt or
///   not; empty when there is no position.
SubTrackState subTrackState(
  SubTrack s, {
  required List<LeafRef> ground,
  required Set<LeafRef> tickedInSource,
  required CivilDate today,
  required CivilDate? deadline,
}) {
  var at = -1;
  var ticked = 0;
  for (var i = 0; i < ground.length; i++) {
    if (tickedInSource.contains(ground[i])) {
      ticked++;
    } else if (at < 0) {
      at = i;
    }
  }
  return SubTrackState(
    subTrackId: s.id,
    holdsGround: holdsGround(s, today),
    inForecast: inForecast(s, today, deadline: deadline),
    onHome: onHome(s, today),
    position: at < 0 ? null : ground[at],
    groundExhausted: ground.isNotEmpty && at < 0,
    ticked: ticked,
    remainingPath: at < 0 ? const [] : List.unmodifiable(ground.sublist(at)),
  );
}
