/// The display model of one parent Change history row (Story 4.5 /
/// DNI-513 AC-3 – AC-6). Built by `change_history_row_mapper.dart`; the
/// presentation layer turns the structured [ChangeHistorySummary] into
/// localised copy and never shows raw payloads or ids.
library;

import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';

/// Whether a row is a governed change or a learning record.
enum ChangeHistoryRowKind {
  /// One `change_log` action.
  governed,

  /// One batch of `learning_events`.
  learning,
}

/// Who did something, and when, in the learner's time zone.
final class HistoryStamp {
  /// Creates a stamp.
  const HistoryStamp({
    required this.actor,
    required this.at,
    required this.day,
    required this.localTime,
  });

  /// Who.
  final Actor actor;

  /// When (UTC).
  final DateTime at;

  /// The learner's civil day of [at] (AD-41).
  final CivilDate day;

  /// The learner's wall-clock time of [at], as a zone-less [DateTime]
  /// whose fields are the local date and time.
  final DateTime localTime;
}

/// What a governed change did to its entity.
enum GovernedChangeKind {
  /// The entity's first write (every `before` is absent).
  created,

  /// The entity was ended (`ended_at` set, reason "ended").
  ended,

  /// The entity was removed (`ended_at` set, a deleting reason).
  removed,

  /// A sub-track's name changed (and nothing else).
  renamed,

  /// Any other field change.
  updated,
}

/// One entity changed by a governed action.
final class GovernedPart {
  /// Creates a part.
  GovernedPart({
    required this.entity,
    required this.change,
    required List<String> fields,
    this.subjectName,
    this.newDate,
  }) : fields = List.unmodifiable(fields);

  /// The entity changed.
  final GovernedEntity entity;

  /// What happened to it.
  final GovernedChangeKind change;

  /// The storage names of the changed fields, sorted and distinct.
  final List<String> fields;

  /// The sub-track's name as it was at the change, when [entity] is a
  /// sub-track.
  final String? subjectName;

  /// The civil date a deadline was set to (`goals/*.target_date`).
  final CivilDate? newDate;
}

/// The structured content of a row.
sealed class ChangeHistorySummary {
  const ChangeHistorySummary();
}

/// A governed action: its [primary] part and every other part of the same
/// `action_id` (e.g. a track removal and its sub-track tombstones).
final class GovernedSummary extends ChangeHistorySummary {
  /// Creates the summary.
  GovernedSummary({required this.primary, required List<GovernedPart> others})
    : others = List.unmodifiable(others);

  /// The part of the action's first entry.
  final GovernedPart primary;

  /// The action's other parts, by entry id.
  final List<GovernedPart> others;
}

/// The source a learning record was captured to.
sealed class HistorySourceLabel {
  const HistorySourceLabel();
}

/// The main track.
final class MainTrackSource extends HistorySourceLabel {
  /// The main track.
  const MainTrackSource();
}

/// A sub-track, by its name at event time (null when unknown).
final class SubTrackSource extends HistorySourceLabel {
  /// A sub-track named [name].
  const SubTrackSource(this.name);

  /// The name in force when the event was recorded.
  final String? name;
}

/// More than one source: an un-learn voids counted learning of one
/// curriculum on every source it was captured to.
final class SeveralSources extends HistorySourceLabel {
  /// More than one source.
  const SeveralSources();
}

/// A learning batch: what was learnt (or, for a void, what was removed).
final class LearningSummary extends ChangeHistorySummary {
  /// Creates the summary.
  LearningSummary({
    required this.kind,
    required List<String> refs,
    required this.source,
    required this.dateState,
    required this.learnedOn,
  }) : refs = List.unmodifiable(refs);

  /// `learn` or `void`.
  final LearningEventKind kind;

  /// The refs learnt (or removed), in id order; empty when a void's
  /// target is unknown.
  final List<String> refs;

  /// The source at event time; [SeveralSources] when a void's targets span
  /// sources; null when unknown (an unresolved void).
  final HistorySourceLabel? source;

  /// The learnt events' date state; null when unknown or not shared.
  final DateState? dateState;

  /// The learnt events' civil date; null when unknown or not shared.
  final CivilDate? learnedOn;
}

/// One row of the parent Change history.
final class ChangeHistoryRow {
  /// Creates a row.
  const ChangeHistoryRow({
    required this.key,
    required this.kind,
    required this.stamp,
    required this.summary,
    required this.notifiesParent,
    required this.isRevert,
    required this.lockIgnored,
    required this.eventCount,
    this.undoneBy,
    this.voidedBy,
    this.voidedCount = 0,
  });

  /// Stable row identity (the merged item key).
  final String key;

  /// Governed change or learning record.
  final ChangeHistoryRowKind kind;

  /// Who and when.
  final HistoryStamp stamp;

  /// What.
  final ChangeHistorySummary summary;

  /// AD-39: a tutor change to a push-eligible entity (the bell).
  final bool notifiesParent;

  /// The undo that reverted this action (AD-38 `reverts_action_id`).
  final HistoryStamp? undoneBy;

  /// Whether this row is itself an undo ("Reverted change: …").
  final bool isRevert;

  /// AD-36: recorded inside a lock window, kept but not counted.
  final bool lockIgnored;

  /// Events in a learning batch (1 for governed rows).
  final int eventCount;

  /// The void that removed this learning, when any did.
  final HistoryStamp? voidedBy;

  /// How many of the batch's events are voided.
  final int voidedCount;

  /// Whether the row is a learning record.
  bool get isLearning => kind == ChangeHistoryRowKind.learning;

  /// Whether the row is a `void`.
  bool get isVoid =>
      summary is LearningSummary &&
      (summary as LearningSummary).kind == LearningEventKind.void_;

  /// Whether Undo may be offered (Story 4.6 executes it): never for an
  /// undo, an undone action, a void, a lock-ignored record (AD-36) or a
  /// fully removed batch.
  bool get canUndo {
    if (isRevert || undoneBy != null || lockIgnored) return false;
    if (!isLearning) return true;
    return !isVoid && voidedCount < eventCount;
  }
}
