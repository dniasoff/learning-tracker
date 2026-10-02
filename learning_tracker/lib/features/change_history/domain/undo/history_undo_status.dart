/// Whether a Change history row offers Undo (DNI-514 / Story 4.6, AC-1,
/// AC-2, AC-6, AC-7, AC-8), derived only from the persisted
/// `reverts_action_id` relation — never from local state — so every device
/// shows the same *Undone* row.
///
/// A row is one governed action (its `change_log` entries sharing an
/// `action_id`) or one learning capture (its `learning_events`, identified
/// by the first event id). An undo is always newer than what it undoes, and
/// history pages load newest first, so a row's undo is loaded before (or
/// with) the row itself.
///
/// Pure Dart; reused by the Story 4.5 (DNI-513) timeline rows.
library;

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/change_log_repository.dart';

/// What a history row offers for Undo.
enum HistoryUndoStatus {
  /// Undo is offered.
  offered,

  /// Something reverts this row: it shows *Undone* and offers no Undo
  /// (AC-1).
  undone,

  /// The row is itself an undo ("Reverted change: …"): an undo is final,
  /// so no Undo (AC-2, AC-6).
  revert,

  /// Undo is never offered: a `learnerSettings` seed entry or a
  /// lock-ignored learning record (AC-7, AD-36, AD-37).
  notOffered,
}

/// The ids reverted by the loaded history, and each row's [HistoryUndoStatus].
final class HistoryUndoIndex {
  /// Indexes every `reverts_action_id` carried by [entries] and [events].
  HistoryUndoIndex({
    Iterable<ChangeLogEntry> entries = const [],
    Iterable<LearningEvent> events = const [],
  }) : _reverted = {
         for (final e in entries) ?e.revertsActionId,
         for (final e in events) ?e.revertsActionId,
       };

  final Set<String> _reverted;

  /// Whether something reverts the action or capture [id].
  bool isReverted(String id) => _reverted.contains(id);

  /// The status of the governed action whose entries are [members].
  HistoryUndoStatus governed(List<ChangeLogEntry> members) {
    if (members.isEmpty) return HistoryUndoStatus.notOffered;
    if (members.any((e) => e.revertsActionId != null)) {
      return HistoryUndoStatus.revert;
    }
    if (members.any(isSettingsSeed)) return HistoryUndoStatus.notOffered;
    if (isReverted(members.first.actionId)) return HistoryUndoStatus.undone;
    return HistoryUndoStatus.offered;
  }

  /// The status of the learning capture whose events are [members];
  /// [isLockIgnored] tells which events the engine ignores (AD-36).
  HistoryUndoStatus capture(
    List<LearningEvent> members, {
    required bool Function(String eventId) isLockIgnored,
  }) {
    if (members.isEmpty) return HistoryUndoStatus.notOffered;
    if (members.any((e) => e.revertsActionId != null)) {
      return HistoryUndoStatus.revert;
    }
    if (isReverted(captureUndoId(members))) return HistoryUndoStatus.undone;
    if (members.every((e) => isLockIgnored(e.id))) {
      return HistoryUndoStatus.notOffered;
    }
    return HistoryUndoStatus.offered;
  }

  /// Whether [e] is a `learnerSettings` seed entry (`before` all-null),
  /// which never offers undo (AD-37).
  static bool isSettingsSeed(ChangeLogEntry e) =>
      e.entity == GovernedEntity.learnerSettings &&
      e.before.values.every((v) => v == null);

  /// The id an undo of the capture [members] carries as
  /// `reverts_action_id`: its first (lowest) event id (AD-52).
  static String captureUndoId(List<LearningEvent> members) =>
      members.map((e) => e.id).reduce((a, b) => a.compareTo(b) <= 0 ? a : b);

  /// Whether undoing the action [members] touches more than one owner
  /// batch's worth of governed docs, so it is online-only through
  /// `ownerOversizedGovernedWrite` (AC-8, AD-54).
  static bool needsOnline(List<ChangeLogEntry> members) => members.any(
    (e) =>
        {for (final k in e.changedKeys) '${k.collection}/${k.docId}'}.length >
        GovernedBatch.maxDocs,
  );
}
