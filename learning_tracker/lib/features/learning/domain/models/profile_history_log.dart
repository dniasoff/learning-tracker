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
final class ProfileHistoryLog {
  /// Creates the log. [subTracks] holds live and tombstoned rows.
  ProfileHistoryLog({
    required List<LearningEvent> events,
    required List<SubTrack> subTracks,
    List<RejectedRow> rejected = const [],
  }) : events = List.unmodifiable(events),
       subTracksById = Map.unmodifiable({for (final s in subTracks) s.id: s}),
       rejected = List.unmodifiable(rejected);

  /// Every learn and void event of the profile, each with its own id.
  final List<LearningEvent> events;

  /// Every sub-track of the profile — live and tombstoned — by ULID. A
  /// tombstoned row keeps its stored `name`, which is the display label of
  /// the learning recorded under it (FR-30, UX-DR-21).
  final Map<String, SubTrack> subTracksById;

  /// Rows the complete reads could not decode; surfaced, never dropped.
  final List<RejectedRow> rejected;

  /// The stored name of sub-track [id] (live or ended), or null when the
  /// complete read holds no such row. Never derived from the ULID.
  String? subTrackName(String id) => subTracksById[id]?.name;
}
