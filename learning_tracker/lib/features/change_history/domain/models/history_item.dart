/// The merged items of the parent Change history (Story 4.5 / DNI-513):
/// one per governed action (`change_log` entries sharing an `action_id`,
/// AD-38) and one per learning batch (the `learning_events` one capture
/// wrote together).
library;

import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';

/// One merged history item, ordered newest [sortAt] first.
sealed class HistoryItem {
  const HistoryItem();

  /// Stable identity across page loads (never changes as more of the same
  /// action or batch is read).
  String get key;

  /// The instant the item sorts by (UTC).
  DateTime get sortAt;

  /// Who made the change or recorded the learning.
  Actor get actor;

  /// Tie order between items with the same [sortAt]: governed before
  /// learning, then by [key] descending.
  int get sourceRank;
}

/// Every loaded `change_log` entry of one `action_id`.
final class GovernedActionItem extends HistoryItem {
  /// Creates the item; [entries] are non-empty and share [actionId].
  GovernedActionItem(this.actionId, List<ChangeLogEntry> entries)
    : entries = List.unmodifiable(
        <ChangeLogEntry>[...entries]..sort((a, b) => a.id.compareTo(b.id)),
      ) {
    if (this.entries.isEmpty) {
      throw ArgumentError.value(actionId, 'entries', 'empty action');
    }
  }

  /// The ULID shared by the action's entries.
  final String actionId;

  /// The loaded entries, by id (the action's first entry first).
  final List<ChangeLogEntry> entries;

  /// The entry that names the action: the one whose id is the action id,
  /// else the smallest loaded id.
  ChangeLogEntry get primary =>
      entries.firstWhere((e) => e.id == actionId, orElse: () => entries.first);

  @override
  String get key => 'action:$actionId';

  /// The newest entry instant of the action.
  @override
  DateTime get sortAt =>
      entries.map((e) => e.at).reduce((a, b) => b.isAfter(a) ? b : a);

  @override
  Actor get actor => primary.actor;

  @override
  int get sourceRank => 0;

  /// The action this one undoes, when it is an undo (AD-38
  /// `reverts_action_id`).
  String? get revertsActionId {
    for (final e in entries) {
      if (e.revertsActionId != null) return e.revertsActionId;
    }
    return null;
  }
}

/// The `learning_events` of one capture: same kind, actor, source,
/// curriculum, date state, civil date and effective instant.
final class LearningBatchItem extends HistoryItem {
  /// Creates the item; [events] are non-empty and share the batch key.
  LearningBatchItem(List<LearningEvent> events)
    : events = List.unmodifiable(
        <LearningEvent>[...events]..sort((a, b) => a.id.compareTo(b.id)),
      ) {
    if (this.events.isEmpty) {
      throw ArgumentError.value(events, 'events', 'empty batch');
    }
  }

  /// The batch's events, by id.
  final List<LearningEvent> events;

  /// The batch's first event.
  LearningEvent get first => events.first;

  /// Whether the batch records learning (not a `void`).
  bool get isLearn => first.isLearn;

  @override
  String get key => 'events:${batchKeyOf(first)}';

  /// `original_recorded_at ?? recorded_at` (AD-31).
  @override
  DateTime get sortAt => effectiveAt(first);

  @override
  Actor get actor => first.actor;

  @override
  int get sourceRank => 1;

  /// The grouping key of [event]: events with equal keys were written by
  /// one capture.
  static String batchKeyOf(LearningEvent event) => [
    event.kind.storage,
    effectiveAt(event).microsecondsSinceEpoch,
    event.actor.uid,
    event.actor.role.storage,
    event.source ?? '',
    event.curriculumId ?? '',
    event.dateState?.storage ?? '',
    event.learnedOn ?? '',
  ].join('|');
}

/// Newest first; ties by [HistoryItem.sourceRank], then key descending.
int compareHistoryItems(HistoryItem a, HistoryItem b) {
  final byTime = b.sortAt.compareTo(a.sortAt);
  if (byTime != 0) return byTime;
  final byRank = a.sourceRank.compareTo(b.sourceRank);
  if (byRank != 0) return byRank;
  return b.key.compareTo(a.key);
}
