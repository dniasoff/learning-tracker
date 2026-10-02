/// The complete event log and sub-track set of one learner profile, as the
/// Mishna-history read model consumes it (Story 1.13, DNI-475).
///
/// Built only from COMPLETE reads (AD-35 "Complete inputs"): every
/// `learning_events` page and every `sub_tracks` page — live AND
/// tombstoned — has arrived before a [ProfileHistoryLog] exists, so a
/// history is never shown from a partial log.
library;

import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

/// One profile's complete learn/void log and its sub-tracks by id.
///
/// Every row decoded: a read holding an undecodable `learning_events` or
/// `sub_tracks` row never becomes a log — it fails as
/// [UnreadableHistoryException] (no partial history).
final class ProfileHistoryLog {
  /// Creates the log. [subTracks] holds live and tombstoned rows.
  ProfileHistoryLog({
    required List<LearningEvent> events,
    required List<SubTrack> subTracks,
  }) : events = List.unmodifiable(events),
       subTracksById = Map.unmodifiable({for (final s in subTracks) s.id: s});

  /// Every learn and void event of the profile, each with its own id.
  final List<LearningEvent> events;

  /// Every sub-track of the profile — live and tombstoned — by ULID. A
  /// tombstoned row keeps its stored `name`, which is the display label of
  /// the learning recorded under it (FR-30, UX-DR-21).
  final Map<String, SubTrack> subTracksById;

  /// The stored name of sub-track [id] (live or ended), or null when the
  /// complete read holds no such row. Never derived from the ULID.
  String? subTrackName(String id) => subTracksById[id]?.name;
}

/// The complete history reads held rows that could not be decoded.
///
/// A missing event can hide a learn or a void (wrong count, wrong rows,
/// corrections on a stale row) and a missing sub-track mislabels a source,
/// so the history fails as a whole and the screen offers a retry
/// (`AppErrorView`, UX-DR-141) instead of showing partial history.
/// [eventRows] and [subTrackRows] keep each document id and decode error
/// for diagnostics.
final class UnreadableHistoryException implements Exception {
  /// Creates the exception.
  UnreadableHistoryException({
    List<RejectedRow> eventRows = const [],
    List<RejectedRow> subTrackRows = const [],
  }) : eventRows = List.unmodifiable(eventRows),
       subTrackRows = List.unmodifiable(subTrackRows);

  /// Undecodable `learning_events` rows.
  final List<RejectedRow> eventRows;

  /// Undecodable `sub_tracks` rows.
  final List<RejectedRow> subTrackRows;

  @override
  String toString() {
    String rows(List<RejectedRow> r) =>
        r.map((row) => '${row.docId}: ${row.error}').join('; ');
    return 'UnreadableHistoryException('
        'learning_events [${rows(eventRows)}], '
        'sub_tracks [${rows(subTrackRows)}])';
  }
}
