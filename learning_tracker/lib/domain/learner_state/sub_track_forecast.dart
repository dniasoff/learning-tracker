/// Engine stage 6e: the AD-44 deadline forecast over sub-tracks (DNI-494,
/// PRD FR-19 / FR-21).
///
/// For each `holdsGround` sub-track `s` of a curriculum with a live
/// deadline:
///
/// * `capacity(s)` (`sub_track_capacity.dart`) — leaves it will really
///   cover before the deadline;
/// * `path(s)` — its remaining path (DNI-493), learnt leaves included:
///   chazara on the path uses capacity;
/// * `expectedNewGround(s) = max(0, capacity − |path|)` — capacity left
///   over for ground not entered yet;
/// * shortfall candidates — the unlearnt leaves of `path` at indices
///   `≥ capacity`, which the sub-track will not reach and which come back
///   to the main track.
///
/// `numerator = mainTrackRemaining − Σ expectedNewGround + Σ shortfall`,
/// where a shortfall leaf is counted once, and not at all if another
/// `holdsGround` sub-track holding it reaches it within its own capacity.
/// Expected new ground is additive per sub-track, even where grounds
/// overlap.
///
/// This is the only implementation of the FR-19 sub-track terms: no
/// provider, planner, widget or server recomputes them. With no deadline
/// it is not computed at all (AD-44), and calendar-program curricula take
/// their target from the calendar instead (AD-35).
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/predicates.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_capacity.dart';

/// One sub-track's share of the deadline forecast.
final class SubTrackForecast {
  /// Creates a forecast.
  SubTrackForecast({
    required this.capacity,
    required this.expectedNewGround,
    required List<LeafRef> shortfallLeaves,
    this.lastShortfallNode,
  }) : shortfallLeaves = List.unmodifiable(shortfallLeaves);

  /// AD-44 capacity in leaves; 0 when the capacity interval is empty.
  final int capacity;

  /// `max(0, capacity − |path|)`.
  final int expectedNewGround;

  /// The shortfall leaves this sub-track contributes to the numerator, in
  /// path order. A leaf that several holders would add back is listed
  /// under the first of them by sub-track id (ULID, i.e. creation order),
  /// so the per-track lists are disjoint and their sizes sum to the FR-19
  /// shortfall term.
  final List<LeafRef> shortfallLeaves;

  /// The last entry of the sub-track's `ground` (list order, as entered)
  /// that contains one of [shortfallLeaves]; null with no shortfall
  /// (FR-21 copy names it).
  final NodeEntry? lastShortfallNode;
}

/// The curriculum-level deadline forecast (AD-44).
final class DeadlineForecast {
  /// Creates a forecast.
  DeadlineForecast({
    required this.mainTrackRemaining,
    required Map<String, SubTrackForecast> subTracks,
  }) : subTracks = Map.unmodifiable(subTracks);

  /// `mainTrackRemaining` (AD-33): main-track leaves with no counted learn
  /// and not held by any `holdsGround` sub-track.
  final int mainTrackRemaining;

  /// The forecast of every `holdsGround` sub-track, by sub-track ULID.
  final Map<String, SubTrackForecast> subTracks;

  /// `Σ expectedNewGround(s)`.
  int get expectedNewGround =>
      subTracks.values.fold(0, (sum, f) => sum + f.expectedNewGround);

  /// `Σ shortfall(s)`, each leaf counted once.
  int get shortfall =>
      subTracks.values.fold(0, (sum, f) => sum + f.shortfallLeaves.length);

  /// `mainTrackRemaining − Σ expectedNewGround + Σ shortfall`.
  int get numerator => mainTrackRemaining - expectedNewGround + shortfall;
}

/// The AD-44 forecast of one curriculum on [today] against [targetDate].
///
/// * [subTracks] are every sub-track of the curriculum; only those that
///   `holdsGround` on [today] take part.
/// * [states] are their DNI-493 states (the `remainingPath` is `path`).
/// * [isLearnt] tells whether a leaf has a counted learn event; a
///   shortfall leaf must also be in the learner's corpus ([inScope]),
///   since only those return to the main track.
/// * [corpus] resolves ground entries for [SubTrackForecast.lastShortfallNode].
DeadlineForecast deriveDeadlineForecast({
  required List<SubTrack> subTracks,
  required Map<String, SubTrackState> states,
  required Corpus corpus,
  required bool Function(LeafRef leaf) isLearnt,
  required bool Function(LeafRef leaf) inScope,
  required int mainTrackRemaining,
  required CivilDate today,
  required CivilDate targetDate,
}) {
  final holders = [
    for (final s in subTracks)
      if (holdsGround(s, today) && states[s.id] != null) s,
  ]..sort((a, b) => a.id.compareTo(b.id));
  final capacity = <String, int>{};
  final reached = <String, Set<LeafRef>>{};
  for (final s in holders) {
    final path = states[s.id]!.remainingPath;
    final cap = subTrackCapacity(s, today: today, targetDate: targetDate);
    capacity[s.id] = cap;
    reached[s.id] = path.take(cap).toSet();
  }
  bool reachedByOther(String id, LeafRef leaf) => holders.any(
    (other) => other.id != id && reached[other.id]!.contains(leaf),
  );
  final counted = <LeafRef>{};
  final forecasts = <String, SubTrackForecast>{};
  for (final s in holders) {
    final path = states[s.id]!.remainingPath;
    final cap = capacity[s.id]!;
    final shortfall = <LeafRef>[
      for (var i = cap; i < path.length; i++)
        if (!isLearnt(path[i]) &&
            inScope(path[i]) &&
            !reachedByOther(s.id, path[i]) &&
            counted.add(path[i]))
          path[i],
    ];
    final excess = cap - path.length;
    forecasts[s.id] = SubTrackForecast(
      capacity: cap,
      expectedNewGround: excess > 0 ? excess : 0,
      shortfallLeaves: shortfall,
      lastShortfallNode: _lastNodeContaining(s.ground, shortfall, corpus),
    );
  }
  return DeadlineForecast(
    mainTrackRemaining: mainTrackRemaining,
    subTracks: forecasts,
  );
}

/// The last of [ground] (list order) whose leaves include one of
/// [leaves]; null when [leaves] is empty.
NodeEntry? _lastNodeContaining(
  List<NodeEntry> ground,
  List<LeafRef> leaves,
  Corpus corpus,
) {
  if (leaves.isEmpty) return null;
  final wanted = leaves.toSet();
  for (final entry in ground.reversed) {
    if (corpus.leavesUnder(entry).any(wanted.contains)) return entry;
  }
  return null;
}

/// [states] with each forecast sub-track's AD-44 fields filled from
/// [forecast]; a sub-track that does not hold ground keeps a null
/// `capacity` (not computed).
Map<String, SubTrackState> withForecast(
  Map<String, SubTrackState> states,
  DeadlineForecast forecast,
) => {
  for (final MapEntry(key: id, value: s) in states.entries)
    id: switch (forecast.subTracks[id]) {
      null => s,
      final f => SubTrackState(
        subTrackId: s.subTrackId,
        holdsGround: s.holdsGround,
        inForecast: s.inForecast,
        onHome: s.onHome,
        position: s.position,
        groundExhausted: s.groundExhausted,
        ticked: s.ticked,
        remainingPath: s.remainingPath,
        capacity: f.capacity,
        expectedNewGround: f.expectedNewGround,
        shortfall: f.shortfallLeaves.length,
      ),
    },
};
