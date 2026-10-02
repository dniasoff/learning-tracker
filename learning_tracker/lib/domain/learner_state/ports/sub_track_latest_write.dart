/// Optional port for a sub-track change derived from the server's latest
/// row and committed atomically against it (Story 2.7 / DNI-498).
///
/// `ground` is one whole-list field, so two devices that each read the
/// same ground and append different nodes would, under AD-38 per-field
/// LWW, silently drop one another's nodes. A [SubTrackRepository] that
/// also implements this port lets `editSubTrack`'s append derive the new
/// whole list from the row the server holds at commit time and write it,
/// with its change-log entry, in one compare-and-set (a Firestore
/// transaction): a concurrent write makes the transaction re-read and
/// re-derive, never overwrite.
///
/// It is a separate interface, not a [SubTrackRepository] member, so every
/// existing implementation and fake keeps compiling; the commands use it
/// only when the injected repository implements it. It needs the server:
/// offline it throws [OnlineRequiredException], and the caller refuses the
/// append as online-required. It never falls back to a queued
/// [SubTrackRepository.applyGovernedChange] batch, whose whole list from a
/// stale cache could overwrite a concurrent append when it syncs.
library;

import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart'
    show PermanentWriteRejection;
import 'package:learning_tracker/domain/learner_state/ports/oversized_governed_write_port.dart'
    show OnlineRequiredException;
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart'
    show StorageFormatException;
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

/// Applies a governed sub-track change built from the latest stored row.
abstract interface class SubTrackLatestWrite {
  /// Reads `sub_tracks/{subTrackId}` of [scope] from the server, calls
  /// [build] with the decoded row and commits the [SubTrackChange] it
  /// returns — the field patch plus `last_change_id` and the create of its
  /// `change_log` entry — atomically, only if the row is still the one
  /// [build] saw. When another write lands first, the row is re-read and
  /// [build] runs again, so it must be pure and may run more than once.
  ///
  /// Returns the committed change, or null when [build] returned null
  /// (nothing to write; nothing is written).
  ///
  /// Throws [SubTrackNotFoundException] for an unknown row,
  /// [ChangeBaselineMismatchException] when the change's `before` is not
  /// the row [build] was given, [StorageFormatException] for an invalid
  /// merged row, [PermanentWriteRejection] for a refused commit, and
  /// [OnlineRequiredException] when the server cannot be reached (a
  /// transaction commits only on the server). Anything [build] throws
  /// propagates and writes nothing.
  Future<SubTrackChange?> applyGovernedChangeToLatest(
    LearnerScope scope,
    String subTrackId,
    SubTrackChange? Function(SubTrack latest) build,
  );
}
