/// One talmid's My talmidim row from his [LearnerState] (Story 4.3,
/// DNI-511, T2; FR-29, AD-35).
///
/// Status and position are the engine's, unchanged:
/// * the status goes through the lifetime report's [OnTrackView.of] — the
///   same mapping the Dashboard on-track card reads — so the row and the
///   card cannot disagree (AC-2): *Too early to tell* under 14 days of
///   tracked history, no chip without a deadline (FR-20);
/// * the next position is the sub-track's [SubTrackState.position]
///   (AD-33), or the main-track position when the talmid has no live
///   sub-track.
///
/// Which sub-track is "the tutor's track": the storage schema has no
/// sub-track author (story Open assumptions), so the row shows the
/// talmid's most recently created live sub-track (`onHome`, highest ULID)
/// of an evaluated curriculum — a tutor's "Rebbe" track is normally added
/// after the parent's tracks. `[ASSUMPTION]` recorded for DNI-511; a
/// stored attribution would change only [pickTalmidSubTrack].
library;

import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/progress/progress.dart'
    show OnTrackView, PaceReportStatus;
import 'package:learning_tracker/features/sub_tracks/domain/models/talmid_row_state.dart';

/// The row of a talmid whose lock is known to be open, from [state].
TalmidRowReady buildTalmidRowState(LearnerState state) {
  final picked = pickTalmidSubTrack(state);
  final curricula = _evaluated(state);
  final statusCurriculum =
      (picked == null ? null : state[picked.curriculumId]) ??
      (curricula.isEmpty ? null : curricula.first);
  return TalmidRowReady(
    status: statusCurriculum == null ? null : talmidStatusOf(statusCurriculum),
    line: picked != null
        ? _subTrackLine(picked.curriculumId, picked.state)
        : _mainLine(statusCurriculum),
  );
}

/// The on-track card's status of [curriculum] as a row chip: the engine's
/// projection through [OnTrackView.of]; null without a deadline (FR-20)
/// or without a projection.
TalmidStatus? talmidStatusOf(CurriculumState curriculum) {
  final projection = curriculum.projection;
  if (!curriculum.evaluated || projection == null) return null;
  final view = OnTrackView.of(curriculum, curriculum.report);
  return switch (view?.status) {
    PaceReportStatus.onTrack => TalmidStatus.onTrack,
    PaceReportStatus.behindPace => TalmidStatus.behindPace,
    PaceReportStatus.tooEarly => TalmidStatus.tooEarly,
    null => null,
  };
}

/// The live sub-track the row shows, with its curriculum; null when the
/// talmid has none.
({String curriculumId, SubTrackState state})? pickTalmidSubTrack(
  LearnerState state,
) {
  ({String curriculumId, SubTrackState state})? best;
  for (final curriculum in _evaluated(state)) {
    for (final sub in curriculum.subTracks.values) {
      if (!sub.onHome) continue;
      if (best == null || sub.subTrackId.compareTo(best.state.subTrackId) > 0) {
        best = (curriculumId: curriculum.curriculumId, state: sub);
      }
    }
  }
  return best;
}

TalmidTrackLine _subTrackLine(String curriculumId, SubTrackState sub) {
  final name = (sub.name ?? '').trim();
  final position = sub.position;
  if (position != null) {
    return TalmidTrackNext(
      subTrackId: sub.subTrackId,
      curriculumId: curriculumId,
      name: name,
      position: position,
    );
  }
  if (sub.groundExhausted) {
    return TalmidTrackAllRecorded(subTrackId: sub.subTrackId, name: name);
  }
  return TalmidTrackNoGround(
    subTrackId: sub.subTrackId,
    curriculumId: curriculumId,
    name: name,
  );
}

TalmidTrackLine? _mainLine(CurriculumState? curriculum) {
  final position = curriculum?.mainTrackPosition;
  if (curriculum == null || position == null) return null;
  return TalmidMainTrackNext(
    curriculumId: curriculum.curriculumId,
    position: position,
  );
}

/// The evaluated curricula of [state] in the app's curriculum order;
/// unknown keys last, by key (the Dashboard's order).
List<CurriculumState> _evaluated(LearnerState state) {
  int rank(String key) {
    final id = CurriculumId.fromStorageKey(key);
    return id == null ? CurriculumId.values.length : id.index;
  }

  return [
    for (final c in state.curricula.values)
      if (c.evaluated) c,
  ]..sort((a, b) {
    final byRank = rank(a.curriculumId).compareTo(rank(b.curriculumId));
    return byRank != 0 ? byRank : a.curriculumId.compareTo(b.curriculumId);
  });
}
