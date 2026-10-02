/// The parent Change history read port (Story 4.5 / DNI-513, AD-38, AD-54).
///
/// The history is `change_log ∪ learning_events` of one learner profile.
/// Each collection is read on its own, newest first, at most
/// [kChangeHistoryPageSize] documents per page, and merged on the client
/// (`change_history_merge.dart`). Each source keeps its own [HistoryCursor],
/// so one source can be exhausted while the other still pages, and the
/// next page of a source is read only when the merged list reaches it.
///
/// Ordering fields (no new Firestore index, AD-54):
///
/// - `change_log` pages by `at` descending.
/// - `learning_events` pages by `recorded_at` descending. A query cannot
///   order by `original_recorded_at ?? recorded_at`, so the merge orders by
///   that effective instant and uses [HistoryPage.watermark] (the
///   `recorded_at` of the last document read) as the bound below which the
///   source may still hold unread events: an event's effective instant is
///   never later than its `recorded_at` (`original_recorded_at` is the
///   earlier, original instant of a re-recorded event).
///
/// Both are single-field orders served by Firestore's automatic indexes.
///
/// Story 1.8's [ChangeLogRepository] keeps the intent-history and undo
/// reads; it has no time-ordered page read, so this port adds one rather
/// than widening that engine contract.
library;

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/change_log_repository.dart'
    show ChangeLogRepository;
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';

/// Documents per page of each history source (AD-38).
const int kChangeHistoryPageSize = 100;

/// Where the next page of one history source starts. Opaque outside the
/// adapter that issued it.
final class HistoryCursor {
  /// Wraps the adapter's own [token].
  const HistoryCursor(this.token);

  /// Adapter-specific position (e.g. the last document read).
  final Object token;
}

/// One page of a history source, newest first.
final class HistoryPage<T> {
  /// Creates a page.
  HistoryPage({
    required List<T> items,
    required this.next,
    required this.exhausted,
    required this.watermark,
    List<RejectedRow> rejected = const [],
  }) : items = List.unmodifiable(items),
       rejected = List.unmodifiable(rejected);

  /// The decoded documents, in query order.
  final List<T> items;

  /// Documents of this page that did not decode (skipped, never shown).
  final List<RejectedRow> rejected;

  /// The cursor of the following page; null when [exhausted].
  final HistoryCursor? next;

  /// Whether the source holds no document after this page.
  final bool exhausted;

  /// The ordering-field instant of the last document read, decoded or not
  /// (UTC); null for an empty page. Every unread document of the source
  /// sorts at or below it.
  final DateTime? watermark;
}

/// Profile-scoped reads of the parent Change history.
abstract interface class ChangeHistoryRepository {
  /// One page of `change_log`, newest `at` first, after [after].
  Future<HistoryPage<ChangeLogEntry>> changeLogPage(
    LearnerScope scope, {
    HistoryCursor? after,
    int limit = kChangeHistoryPageSize,
  });

  /// One page of `learning_events`, newest `recorded_at` first, after
  /// [after].
  Future<HistoryPage<LearningEvent>> learningEventPage(
    LearnerScope scope, {
    HistoryCursor? after,
    int limit = kChangeHistoryPageSize,
  });

  /// The `learning_events` documents with [ids] that exist and decode (the
  /// targets of `void` events that are not on a loaded page).
  Future<List<LearningEvent>> learningEventsById(
    LearnerScope scope,
    Set<String> ids,
  );

  /// Every `change_log` entry that exists and decodes whose `action_id` is
  /// one of [actionIds] (the actions an undo's `reverts_action_id` names,
  /// which may be older than every loaded page). Single-field equality
  /// queries only (AD-54).
  Future<List<ChangeLogEntry>> changeLogEntriesOfActions(
    LearnerScope scope,
    Set<String> actionIds,
  );
}
