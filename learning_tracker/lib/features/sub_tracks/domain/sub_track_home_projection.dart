/// The Learn-tab / Dashboard projection of a learner's sub-tracks
/// (Story 2.9, DNI-500 T1).
///
/// Joins each stored [SubTrack] (name, ground) with the engine's
/// [SubTrackState] (`onHome`, position, ticked count, remaining path) for
/// its curriculum. Every number comes from the engine (AD-35): this file
/// only filters, orders and labels; it never derives a position, a count or
/// a window predicate itself.
library;

import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

/// What a sub-track row can offer (AC-1, AC-3, AC-4).
enum SubTrackRowKind {
  /// Ground with an unticked leaf: shows "Next: {position}", *Up to…* and
  /// *+1*.
  active,

  /// No ground yet (FR-2): actions disabled for the child, *Add ground* for
  /// the parent.
  groundless,

  /// Every leaf of the ground is ticked in this track: actions disabled,
  /// *Add ground* for the parent.
  allRecorded,
}

/// One `onHome` sub-track as the Learn row and the Dashboard card show it.
final class SubTrackHomeItem {
  /// Creates an item.
  const SubTrackHomeItem({
    required this.subTrackId,
    required this.curriculumId,
    required this.name,
    required this.kind,
    this.position,
    this.ticked = 0,
    this.remaining = 0,
  });

  /// The sub-track ULID — also the `source` of its learn events.
  final String subTrackId;

  /// Its curriculum (CurriculumId storage key).
  final String curriculumId;

  /// The learner-given name ("School").
  final String name;

  /// Which row state applies.
  final SubTrackRowKind kind;

  /// The engine's next leaf for this track; non-null iff [kind] is
  /// [SubTrackRowKind.active].
  final LeafRef? position;

  /// Distinct leaves ticked in this track (engine).
  final int ticked;

  /// Leaves on the remaining path (engine).
  final int remaining;

  /// `ticked ÷ (ticked + remaining)`, or 0 when both are 0 (AC-8; never
  /// divides by zero).
  double get progress {
    final total = ticked + remaining;
    return total == 0 ? 0 : ticked / total;
  }

  /// Whether *+1* / *Up to…* can record (before role gating).
  bool get canCapture => kind == SubTrackRowKind.active;

  @override
  bool operator ==(Object other) =>
      other is SubTrackHomeItem &&
      other.subTrackId == subTrackId &&
      other.curriculumId == curriculumId &&
      other.name == name &&
      other.kind == kind &&
      other.position == position &&
      other.ticked == ticked &&
      other.remaining == remaining;

  @override
  int get hashCode => Object.hash(
    subTrackId,
    curriculumId,
    name,
    kind,
    position,
    ticked,
    remaining,
  );

  @override
  String toString() =>
      'SubTrackHomeItem($subTrackId, ${kind.name}, $position, '
      '$ticked/${ticked + remaining})';
}

/// Hub order (UX-DR-71, EXPERIENCE.md "hub order [ASSUMPTION]"): creation
/// order, which for client ULIDs is ascending id. DNI-500 default, recorded
/// under B13; the hub (DNI-495) uses the same comparator if it adopts one.
int compareSubTracksInHubOrder(SubTrack a, SubTrack b) => a.id.compareTo(b.id);

/// The `onHome` sub-tracks of [subTracks] in hub order, joined with their
/// engine state in [learnerState] (AC-1).
///
/// A track is included only when its curriculum's engine state holds a
/// [SubTrackState] for it with `onHome` true, so future-start, ended and
/// window-passed tracks have no row (the engine's AD-34 `onHome`). One item
/// per track, however many nodes its ground holds.
List<SubTrackHomeItem> projectHomeSubTracks({
  required List<SubTrack> subTracks,
  required LearnerState learnerState,
}) {
  final ordered = [...subTracks]..sort(compareSubTracksInHubOrder);
  return [
    for (final track in ordered)
      if (learnerState[track.curriculumId]?.subTracks[track.id]
          case final state? when state.onHome)
        _item(track, state),
  ];
}

SubTrackHomeItem _item(SubTrack track, SubTrackState state) {
  final kind = track.ground.isEmpty
      ? SubTrackRowKind.groundless
      : (state.groundExhausted || state.position == null)
      ? SubTrackRowKind.allRecorded
      : SubTrackRowKind.active;
  return SubTrackHomeItem(
    subTrackId: track.id,
    curriculumId: track.curriculumId,
    name: track.name,
    kind: kind,
    position: kind == SubTrackRowKind.active ? state.position : null,
    ticked: state.ticked,
    remaining: state.remainingPath.length,
  );
}
