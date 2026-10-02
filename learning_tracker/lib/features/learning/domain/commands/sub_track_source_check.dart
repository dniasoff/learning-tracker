/// The owner write path's check that a learn event's sub-track `source`
/// is a live sub-track of the event's curriculum in the learner's own
/// scope (AD-33; Story 2.10, DNI-501).
///
/// Owner capture has no callable: `LearningCommands` is the authoritative
/// write path, so it runs this check before planning any write. The
/// Firestore rule for `learning_events` stays free of document-access
/// calls (AD-54's 450-write chunk budget), so the rules accept any ULID
/// `source`; this check is what keeps a stale client from writing an event
/// that names an unknown, ended, other-profile or other-curriculum
/// sub-track.
library;

import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

/// Whether [subTrackId] may be the `source` of a learn event of
/// [curriculumId]. Throwing counts as "no": the command fails closed.
typedef SubTrackSourceCheck =
    Future<bool> Function(String curriculumId, String subTrackId);

/// How long [subTrackSourceCheckFrom] waits for the complete sub-track
/// read before it fails closed. The learner state, which every sub-track
/// source choice is derived from, reads the same collection, so the read
/// is normally already cached.
const Duration defaultSubTrackSourceWait = Duration(seconds: 2);

/// The [SubTrackSourceCheck] over [repository] for [scope]: the source must
/// be a live (not ended) sub-track of [scope] whose `curriculum_id` is the
/// event's. A sub-track of another profile is never in [scope]'s read.
SubTrackSourceCheck subTrackSourceCheckFrom(
  SubTrackRepository repository,
  LearnerScope scope, {
  Duration wait = defaultSubTrackSourceWait,
}) => (curriculumId, subTrackId) async {
  final read = await repository
      .watchActiveByCurriculum(scope, curriculumId)
      .firstWhere((r) => r is CompleteReadReady<SubTrack>)
      .timeout(wait);
  return (read as CompleteReadReady<SubTrack>).items.any(
    (t) => t.id == subTrackId,
  );
};
