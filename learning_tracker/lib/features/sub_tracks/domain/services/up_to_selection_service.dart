/// Builds the Up to… picker's rows from the engine's derived state (Story
/// 2.10, DNI-501; FR-2, FR-2a, AD-33, AD-34).
///
/// Pure Dart. The engine is the only implementation of position, ground
/// order (`expandGround`) and `schedulableRefs` (AD-33); this service only
/// slices what the engine derived:
///
/// * a sub-track's rows are its `remainingPath` (ground in `expandGround`
///   order from its position to the end), each leaf already ticked in that
///   sub-track (`recordedAhead`) marked recorded;
/// * the main track's rows are its `schedulableRefs` from the main-track
///   position, led by today's new-learning tasks.
///
/// [pending] leaves are captures this device made that the engine has not
/// derived yet (the optimistic overlay): they read as recorded, so the row
/// and the picker move on in the same frame as the capture.
library;

import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/sub_tracks/domain/models/up_to_selection.dart';

/// Whether Up to… can open a picker (AC-6).
enum UpToAvailability {
  /// Rows to choose from.
  ready,

  /// A sub-track with no ground: the actions are disabled (Story 2.9).
  groundless,

  /// No leaf left after the position: "No more … in {name}'s ground."
  exhausted,
}

/// The rows of one Up to… picker.
final class UpToSlice {
  /// Creates a slice.
  UpToSlice({
    required this.curriculumId,
    required this.source,
    required List<UpToRow> rows,
    this.groundless = false,
  }) : rows = List.unmodifiable(rows);

  /// The curriculum storage key.
  final String curriculumId;

  /// `main` or the sub-track ULID written as the events' `source`.
  final String source;

  /// The rows, from the position, in track order.
  final List<UpToRow> rows;

  /// A sub-track with no ground.
  final bool groundless;

  /// Whether the picker can open.
  UpToAvailability get availability {
    if (groundless) return UpToAvailability.groundless;
    if (!rows.any((r) => !r.recorded)) return UpToAvailability.exhausted;
    return UpToAvailability.ready;
  }

  /// A fresh selection over [rows].
  UpToSelection select() => UpToSelection(rows);
}

/// Whether [state] is a sub-track with no ground: no position and not
/// exhausted (Story 2.9 disables its actions).
bool isGroundless(SubTrackState state) =>
    state.position == null && !state.groundExhausted;

/// The sub-track's position as this device sees it: the first leaf of its
/// remaining path not already ticked in it and not [pending]; null when
/// none is left.
LeafRef? displayedSubTrackPosition(
  SubTrackState state, {
  Set<LeafRef> pending = const {},
}) {
  for (final ref in state.remainingPath) {
    if (!state.recordedAhead.contains(ref) && !pending.contains(ref)) {
      return ref;
    }
  }
  return null;
}

/// The picker rows of the sub-track [state] of [curriculumId].
///
/// Rows run from the displayed position to the end of the ground; leaves
/// already ticked in this sub-track (or [pending]) after the position are
/// kept as recorded rows.
UpToSlice subTrackUpToSlice({
  required String curriculumId,
  required SubTrackState state,
  Set<LeafRef> pending = const {},
}) {
  if (isGroundless(state)) {
    return UpToSlice(
      curriculumId: curriculumId,
      source: state.subTrackId,
      rows: const [],
      groundless: true,
    );
  }
  final at = displayedSubTrackPosition(state, pending: pending);
  final path = state.remainingPath;
  final start = at == null ? path.length : path.indexOf(at);
  return UpToSlice(
    curriculumId: curriculumId,
    source: state.subTrackId,
    rows: [
      for (final ref in path.skip(start))
        UpToRow(
          ref,
          recorded: state.recordedAhead.contains(ref) || pending.contains(ref),
        ),
    ],
  );
}

/// The main-track picker rows of [state] (AC-5): its `schedulableRefs`
/// from the main-track position, led by [leadRefs] (today's new-learning
/// tasks, in task order). A lead ref that is not schedulable is dropped;
/// [pending] leaves are left out (they are learnt now).
UpToSlice mainTrackUpToSlice({
  required CurriculumState state,
  List<LeafRef> leadRefs = const [],
  Set<LeafRef> pending = const {},
}) {
  final refs = [
    for (final r in state.schedulableRefs)
      if (!pending.contains(r)) r,
  ];
  final position = state.mainTrackPosition;
  final at = position == null ? -1 : refs.indexOf(position);
  final schedulable = refs.toSet();
  final lead = <LeafRef>[];
  for (final r in leadRefs) {
    if (schedulable.contains(r) && !lead.contains(r)) lead.add(r);
  }
  final leadSet = lead.toSet();
  return UpToSlice(
    curriculumId: state.curriculumId,
    source: LearningEvent.sourceMain,
    rows: [
      for (final r in lead) UpToRow(r),
      for (final r in refs.skip(at < 0 ? 0 : at))
        if (!leadSet.contains(r)) UpToRow(r),
    ],
  );
}
