/// The presentation-ready projection of one My talmidim row (Story 4.3,
/// DNI-511, T2; FR-29, AD-35, AD-36).
///
/// Every value comes from the talmid's own [LearnerState] (status, next
/// position) or his lock state; the row derives nothing itself. A row whose
/// lock is not yet known, or that is locked, carries no identity, status,
/// position or action at all (AD-36: the FR-29 row shows "Shabbos / Yom
/// Tov" with no data or controls).
library;

import 'package:learning_tracker/domain/learner_state/corpus.dart';

/// The status chip (UX-DR-24, UX-DR-94): the on-track card's three states.
enum TalmidStatus {
  /// *On track*.
  onTrack,

  /// *Behind pace*.
  behindPace,

  /// *Too early to tell* (under 14 days of tracked history).
  tooEarly,
}

/// The row's detail line: the tutor's track and its next position.
sealed class TalmidTrackLine {
  const TalmidTrackLine();
}

/// "{track}: next {position}".
final class TalmidTrackNext extends TalmidTrackLine {
  /// Creates the line.
  const TalmidTrackNext({
    required this.subTrackId,
    required this.curriculumId,
    required this.name,
    required this.position,
  });

  /// The sub-track ULID.
  final String subTrackId;

  /// Its curriculum (storage key).
  final String curriculumId;

  /// The sub-track's name ("Rebbe").
  final String name;

  /// The engine's next leaf of the sub-track (AD-33).
  final LeafRef position;

  @override
  bool operator ==(Object other) =>
      other is TalmidTrackNext &&
      other.subTrackId == subTrackId &&
      other.curriculumId == curriculumId &&
      other.name == name &&
      other.position == position;

  @override
  int get hashCode => Object.hash(subTrackId, curriculumId, name, position);
}

/// "{track}: no ground yet", with *Add ground* (UX-DR-83).
final class TalmidTrackNoGround extends TalmidTrackLine {
  /// Creates the line.
  const TalmidTrackNoGround({
    required this.subTrackId,
    required this.curriculumId,
    required this.name,
  });

  /// The groundless sub-track ULID — the ground picker's target.
  final String subTrackId;

  /// Its curriculum (storage key).
  final String curriculumId;

  /// The sub-track's name.
  final String name;

  @override
  bool operator ==(Object other) =>
      other is TalmidTrackNoGround &&
      other.subTrackId == subTrackId &&
      other.curriculumId == curriculumId &&
      other.name == name;

  @override
  int get hashCode => Object.hash(subTrackId, curriculumId, name);
}

/// "{track}: all ground recorded".
final class TalmidTrackAllRecorded extends TalmidTrackLine {
  /// Creates the line.
  const TalmidTrackAllRecorded({required this.subTrackId, required this.name});

  /// The sub-track ULID.
  final String subTrackId;

  /// The sub-track's name.
  final String name;

  @override
  bool operator ==(Object other) =>
      other is TalmidTrackAllRecorded &&
      other.subTrackId == subTrackId &&
      other.name == name;

  @override
  int get hashCode => Object.hash(subTrackId, name);
}

/// "Next: {position}" on the main track, for a talmid with no live
/// sub-track.
final class TalmidMainTrackNext extends TalmidTrackLine {
  /// Creates the line.
  const TalmidMainTrackNext({
    required this.curriculumId,
    required this.position,
  });

  /// The curriculum (storage key).
  final String curriculumId;

  /// The engine's main-track position.
  final LeafRef position;

  @override
  bool operator ==(Object other) =>
      other is TalmidMainTrackNext &&
      other.curriculumId == curriculumId &&
      other.position == position;

  @override
  int get hashCode => Object.hash(curriculumId, position);
}

/// Why a row could not be shown.
enum TalmidRowFailure {
  /// The grant no longer authorizes the read (revoked, resigned): the row
  /// leaves the roster on its next refresh.
  accessEnded,

  /// The learner state or lock could not be read.
  loadFailed,

  /// The grant names a profile id that addresses no learner (AD-24).
  invalidLearner,
}

/// One row's state.
sealed class TalmidRowState {
  const TalmidRowState();

  /// Whether the learner's identity (name, initials) may be shown: only
  /// once his lock is known to be open (AD-36, fail closed).
  bool get identityVisible;

  /// Whether a tap may open the learner's context.
  bool get opensLearner;
}

/// The learner's lock is not yet known: no identity, no data, inert.
final class TalmidRowPending extends TalmidRowState {
  /// Creates the state.
  const TalmidRowPending();

  @override
  bool get identityVisible => false;

  @override
  bool get opensLearner => false;

  @override
  bool operator ==(Object other) => other is TalmidRowPending;

  @override
  int get hashCode => (TalmidRowPending).hashCode;
}

/// The learner is inside a lock window: "Shabbos / Yom Tov" only, inert.
final class TalmidRowLocked extends TalmidRowState {
  /// Creates the state.
  const TalmidRowLocked();

  @override
  bool get identityVisible => false;

  @override
  bool get opensLearner => false;

  @override
  bool operator ==(Object other) => other is TalmidRowLocked;

  @override
  int get hashCode => (TalmidRowLocked).hashCode;
}

/// Not locked; the engine is still loading.
final class TalmidRowLoading extends TalmidRowState {
  /// Creates the state.
  const TalmidRowLoading();

  @override
  bool get identityVisible => true;

  @override
  bool get opensLearner => true;

  @override
  bool operator ==(Object other) => other is TalmidRowLoading;

  @override
  int get hashCode => (TalmidRowLoading).hashCode;
}

/// Not locked; the engine's values.
final class TalmidRowReady extends TalmidRowState {
  /// Creates the state.
  const TalmidRowReady({this.status, this.line});

  /// The status chip; null with no deadline (FR-20).
  final TalmidStatus? status;

  /// The detail line; null when the learner has no track to show.
  final TalmidTrackLine? line;

  @override
  bool get identityVisible => true;

  @override
  bool get opensLearner => true;

  @override
  bool operator ==(Object other) =>
      other is TalmidRowReady && other.status == status && other.line == line;

  @override
  int get hashCode => Object.hash(status, line);

  @override
  String toString() => 'TalmidRowReady(${status?.name}, $line)';
}

/// The load did not finish in time: inline retry on this row only.
final class TalmidRowTimedOut extends TalmidRowState {
  /// Creates the state; [identityVisible] once the lock is known open.
  const TalmidRowTimedOut({required this.identityVisible});

  @override
  final bool identityVisible;

  @override
  bool get opensLearner => false;

  @override
  bool operator ==(Object other) =>
      other is TalmidRowTimedOut && other.identityVisible == identityVisible;

  @override
  int get hashCode => Object.hash(TalmidRowTimedOut, identityVisible);
}

/// The row could not be shown for [reason].
final class TalmidRowFailed extends TalmidRowState {
  /// Creates the state.
  const TalmidRowFailed(this.reason, {this.identityVisible = false});

  /// Why.
  final TalmidRowFailure reason;

  @override
  final bool identityVisible;

  @override
  bool get opensLearner => false;

  /// Whether a retry can help (not for an ended grant or a bad id).
  bool get retryable => reason == TalmidRowFailure.loadFailed;

  @override
  bool operator ==(Object other) =>
      other is TalmidRowFailed &&
      other.reason == reason &&
      other.identityVisible == identityVisible;

  @override
  int get hashCode => Object.hash(reason, identityVisible);
}
