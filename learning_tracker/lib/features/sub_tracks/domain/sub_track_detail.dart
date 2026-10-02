/// The sub-track detail screen's model (Story 2.6 / DNI-497).
///
/// Every number here is an engine output read as-is: position, ticked
/// count and remaining path (Story 2.2 / DNI-493) and capacity and
/// shortfall (Story 2.3 / DNI-494) come from the engine's [SubTrackState];
/// the ground rows come from [SubTrackGroundProjection]. Nothing is
/// computed here (AD-33, AD-44: "the screen consumes the engine's numbers
/// and does not repeat these calculations").
library;

import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_ground_projection.dart';

/// Who is looking at the detail.
///
/// Only the parent edits (AC-5, AC-6). The child is read-only with no
/// shortfall (AC-2, AC-7). A tutor is read-only in Epic 2 (tutor sub-track
/// writes arrive in Epic 4) and, like the parent, may see the shortfall.
enum SubTrackDetailRole {
  /// The parent (or an adult learner): full controls.
  parent,

  /// A child-mode profile without a verified parent PIN session.
  child,

  /// A tutored session on a tutor device.
  tutor,
}

/// Everything the detail renders for one sub-track.
final class SubTrackDetail {
  /// Creates the detail.
  const SubTrackDetail({
    required this.track,
    required this.state,
    required this.ground,
    required this.role,
  });

  /// The stored intent.
  final SubTrack track;

  /// The engine's view of [track].
  final SubTrackState state;

  /// The ordered ground, rendered.
  final SubTrackGroundProjection ground;

  /// The viewer.
  final SubTrackDetailRole role;

  /// Whether the viewer may reorder or remove ground: the parent, on a
  /// sub-track that is not ended.
  bool get canEdit => role == SubTrackDetailRole.parent && !track.isEnded;

  /// Whether the shortfall tag may show (never for the child, NFR-9).
  bool get showsShortfall => role != SubTrackDetailRole.child;

  /// "Up next": the engine position, or null when there is none.
  LeafRef? get upNext => state.position;

  /// Distinct ground leaves ticked in this sub-track.
  int get ticked => state.ticked;

  /// Whether the capacity bar renders: capacity is computed only with a
  /// deadline (AD-44), so a null engine capacity means no deadline.
  bool get hasDeadline => state.capacity != null;

  /// AD-44 `capacity` in leaves; null with no deadline.
  int? get capacity => state.capacity;

  /// AD-44 `path`: the remaining path length in leaves.
  int get remainingPath => state.remainingPath.length;

  /// AD-44 shortfall in leaves.
  int get shortfall => state.shortfall;
}
