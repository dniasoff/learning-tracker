/// The active learner's `onHome` sub-tracks joined with their engine state
/// (AD-34 "home rows use `onHome`"; Story 2.10, DNI-501).
///
/// Pure Dart. The Learn-tab rows, the Browse capture sources (AC-9) and the
/// history source correction (AC-10) all read this one list, so every
/// surface offers the same sub-tracks.
library;

import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

/// One `onHome` sub-track and its engine state.
final class OnHomeSubTrack {
  /// Creates the pair.
  const OnHomeSubTrack({required this.track, required this.state});

  /// The stored sub-track (name, curriculum, ground).
  final SubTrack track;

  /// The engine's derived state (position, remaining path).
  final SubTrackState state;

  /// The sub-track ULID (the events' `source`).
  String get id => track.id;

  /// The curriculum storage key.
  String get curriculumId => track.curriculumId;

  @override
  String toString() => 'OnHomeSubTrack(${track.id})';
}

/// The live sub-tracks of [tracks] the engine marks `onHome` in [state],
/// in hub order.
///
/// [ASSUMPTION] Hub order is `window_start`, then name, then id: the stored
/// schema has no sort field and the hub (Story 2.2) is not on this branch.
List<OnHomeSubTrack> onHomeSubTracks(
  List<SubTrack> tracks,
  LearnerState state, {
  String? curriculumId,
}) {
  final out = <OnHomeSubTrack>[];
  for (final t in tracks) {
    if (t.isEnded) continue;
    if (curriculumId != null && t.curriculumId != curriculumId) continue;
    final s = state.curricula[t.curriculumId]?.subTracks[t.id];
    if (s == null || !s.onHome) continue;
    out.add(OnHomeSubTrack(track: t, state: s));
  }
  out.sort((a, b) {
    final byStart = a.track.windowStart.compareTo(b.track.windowStart);
    if (byStart != 0) return byStart;
    final byName = a.track.name.compareTo(b.track.name);
    return byName != 0 ? byName : a.id.compareTo(b.id);
  });
  return List.unmodifiable(out);
}
