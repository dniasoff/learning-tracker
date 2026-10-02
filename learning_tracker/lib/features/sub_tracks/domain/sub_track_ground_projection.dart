/// The ordered-ground view of one sub-track for its detail screen (Story
/// 2.6 / DNI-497, AC-3, AC-4).
///
/// A story-owned adapter over engine outputs, not a second engine: the
/// leaves of every entry come from the engine's one `expandGround` (AD-34,
/// so overlapping entries never show a leaf twice), the tri-state from the
/// engine's `triStateOf` over the engine's all-source learnt set, and the
/// "held" test from the engine's `holdsGround` verdict per sub-track
/// (`SubTrackState.holdsGround`). It adds only presentation facts the
/// engine has no output for: which source learnt a leaf ("learnt at home",
/// "learnt at {name}") and which other sub-track also holds a row's ground
/// ("{name} · In use").
///
/// Pure Dart: imports only `lib/domain/learner_state/**`.
library;

import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/counted_events.dart';
import 'package:learning_tracker/domain/learner_state/expand_ground.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/learnt_set.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/tri_state.dart';

/// Where a ground leaf was learnt when it was not ticked in this sub-track
/// (FR-9, FR-13, UX-DR-91).
final class GroundLearntAt {
  /// Learnt on the main track ("learnt at home").
  const GroundLearntAt.home() : subTrackName = null;

  /// Learnt in the sub-track named [subTrackName] ("learnt at {name}").
  const GroundLearntAt.subTrack(String this.subTrackName);

  /// The other sub-track's name; null for the main track.
  final String? subTrackName;

  /// Whether it was learnt on the main track.
  bool get isHome => subTrackName == null;

  @override
  bool operator ==(Object other) =>
      other is GroundLearntAt && other.subTrackName == subTrackName;

  @override
  int get hashCode => subTrackName.hashCode;

  @override
  String toString() =>
      isHome ? 'GroundLearntAt.home' : 'GroundLearntAt($subTrackName)';
}

/// One row of the ground tree: a stored ground entry ([depth] 0) or a
/// ContentIndex node under one (depth ≥ 1).
final class SubTrackGroundRow {
  /// Creates a row. Prefer [SubTrackGroundProjection.project].
  SubTrackGroundRow({
    required this.node,
    required this.depth,
    required this.isLeaf,
    required List<LeafRef> leaves,
    required this.learnt,
    required this.state,
    required this.learntAt,
    required List<String> inUseBy,
    this.entryIndex,
  }) : leaves = List.unmodifiable(leaves),
       inUseBy = List.unmodifiable(inUseBy);

  /// The node.
  final NodeEntry node;

  /// 0 for a stored ground entry; children are one deeper.
  final int depth;

  /// Whether [node] is a ContentIndex leaf.
  final bool isLeaf;

  /// The row's leaves in `expandGround` order. For an entry, only the
  /// leaves no earlier entry already holds (AD-34 drops later duplicates),
  /// so the rows of one ground never share a leaf.
  final List<LeafRef> leaves;

  /// How many of [leaves] are learnt from any source.
  final int learnt;

  /// `leaves.length`.
  int get total => leaves.length;

  /// All-source tri-state of [leaves] (engine `triStateOf`).
  final TriState state;

  /// The single other source every learnt leaf of the row was learnt in,
  /// when none of them is ticked in this sub-track; otherwise null.
  final GroundLearntAt? learntAt;

  /// Names of the other sub-tracks that hold any of [leaves]
  /// (`holdsGround`), in name order.
  final List<String> inUseBy;

  /// The index of this entry in the stored `ground` list, for a depth-0
  /// row; null for a child row.
  final int? entryIndex;

  /// Whether the row has children to expand into.
  bool get expandable => !isLeaf && leaves.isNotEmpty;
}

/// The ordered ground of one sub-track, ready to render.
final class SubTrackGroundProjection {
  SubTrackGroundProjection._(this._rows, List<NodeEntry> ground)
    : entries = List.unmodifiable([
        for (var i = 0; i < ground.length; i++) _rows.entry(ground, i),
      ]);

  /// Projects [track]'s [ground] (its stored ground, or an optimistic
  /// reorder of it) over the engine outputs.
  ///
  /// * [learntLeaves]: the curriculum's all-source learnt set
  ///   (`CurriculumState.learntLeaves`).
  /// * [countedLearns]: the curriculum's counted `learn` events (ids in
  ///   `LearnerState.countedEventIds`); the earliest one per leaf, in the
  ///   engine's event order, names where an unticked leaf was learnt.
  /// * [subTracks]: every sub-track of the learner (names and ground of
  ///   the others); [holdsGround] is the engine's verdict per sub-track id.
  factory SubTrackGroundProjection.project({
    required SubTrack track,
    required List<NodeEntry> ground,
    required Corpus corpus,
    required Set<LeafRef> learntLeaves,
    required Iterable<LearningEvent> countedLearns,
    required Iterable<SubTrack> subTracks,
    required bool Function(String subTrackId) holdsGround,
  }) {
    final names = {for (final s in subTracks) s.id: s.name};
    final ordered = [...countedLearns]..sort(compareEventsByEffectiveAt);
    final tickedHere = <LeafRef>{};
    final elsewhere = <LeafRef, GroundLearntAt>{};
    for (final event in ordered) {
      final leaves = coveredLeaves(event, corpus);
      final source = event.source;
      if (source == track.id) {
        tickedHere.addAll(leaves);
        continue;
      }
      final at = switch (names[source]) {
        final name? => GroundLearntAt.subTrack(name),
        null => const GroundLearntAt.home(),
      };
      for (final leaf in leaves) {
        elsewhere.putIfAbsent(leaf, () => at);
      }
    }
    final heldByOthers = <String, Set<LeafRef>>{
      for (final s in subTracks)
        if (s.id != track.id &&
            s.curriculumId == track.curriculumId &&
            holdsGround(s.id))
          s.name: expandGround(s.ground, corpus).toSet(),
    };
    return SubTrackGroundProjection._(
      _RowBuilder(
        corpus: corpus,
        learnt: learntLeaves,
        tickedHere: tickedHere,
        elsewhere: elsewhere,
        heldByOthers: heldByOthers,
      ),
      ground,
    );
  }

  final _RowBuilder _rows;

  /// One row per stored ground entry, in stored order.
  final List<SubTrackGroundRow> entries;

  /// Whether the sub-track has no ground entries (UX-DR-122).
  bool get isGroundless => entries.isEmpty;

  /// Whether [leaf] has a counted `learn` event from this sub-track.
  bool isTickedHere(LeafRef leaf) => _rows.tickedHere.contains(leaf);

  /// The ContentIndex children of [row] that hold any of its leaves, in
  /// ContentIndex order; each keeps only the leaves [row] holds, so a child
  /// of a de-duplicated entry never repeats another entry's leaf.
  List<SubTrackGroundRow> childrenOf(SubTrackGroundRow row) {
    if (!row.expandable) return const [];
    final mine = row.leaves.toSet();
    final corpus = _rows.corpus;
    return [
      for (final child in corpus.childrenOf(row.node))
        if (corpus.leavesUnder(child).where(mine.contains).toList()
            case final leaves when leaves.isNotEmpty)
          _rows.row(child, depth: row.depth + 1, leaves: leaves),
    ];
  }
}

final class _RowBuilder {
  _RowBuilder({
    required this.corpus,
    required this.learnt,
    required this.tickedHere,
    required this.elsewhere,
    required this.heldByOthers,
  });

  final Corpus corpus;
  final Set<LeafRef> learnt;
  final Set<LeafRef> tickedHere;
  final Map<LeafRef, GroundLearntAt> elsewhere;
  final Map<String, Set<LeafRef>> heldByOthers;

  /// Leaves already held by an earlier entry (AD-34 duplicate drop).
  final Set<LeafRef> _seen = {};

  /// The row of `ground[index]`; entries must be built in list order.
  SubTrackGroundRow entry(List<NodeEntry> ground, int index) {
    final node = ground[index];
    final own = [
      for (final leaf in expandGround([node], corpus))
        if (_seen.add(leaf)) leaf,
    ];
    return row(node, depth: 0, leaves: own, entryIndex: index);
  }

  SubTrackGroundRow row(
    NodeEntry node, {
    required int depth,
    required List<LeafRef> leaves,
    int? entryIndex,
  }) {
    GroundLearntAt? at;
    var mixed = false;
    for (final leaf in leaves) {
      if (!learnt.contains(leaf)) continue;
      final source = tickedHere.contains(leaf) ? null : elsewhere[leaf];
      if (source == null || (at != null && at != source)) {
        mixed = true;
        break;
      }
      at = source;
    }
    final names = <String>[
      for (final MapEntry(key: name, value: held) in heldByOthers.entries)
        if (leaves.any(held.contains)) name,
    ]..sort();
    return SubTrackGroundRow(
      node: node,
      depth: depth,
      isLeaf: corpus.isLeaf(node),
      leaves: leaves,
      learnt: leaves.where(learnt.contains).length,
      state: triStateOf(leaves, learnt),
      learntAt: mixed ? null : at,
      inUseBy: names,
      entryIndex: entryIndex,
    );
  }
}
