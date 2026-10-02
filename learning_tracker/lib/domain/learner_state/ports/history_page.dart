/// Time-ordered history pages of a learner's `change_log` and
/// `learning_events` (AD-38, AD-54): the page shape that
/// [ChangeLogRepository.historyPage] and
/// [LearningEventRepository.historyPage] return for the parent Change
/// history (Story 4.5 / DNI-513).
///
/// Each collection is read on its own, newest first, at most
/// [kChangeHistoryPageSize] documents per page, and merged by the caller.
/// Each source keeps its own [HistoryCursor], so one source can be
/// exhausted while the other still pages.
///
/// Ordering fields (single-field orders served by Firestore's automatic
/// indexes; no new index, AD-54):
///
/// - `change_log` pages by `at` descending. The caller orders by the
///   effective instant `original_at ?? at` and uses the `at` watermark as
///   its bound, as below: `original_at` (import only) is the earlier,
///   original instant of an imported change.
/// - `learning_events` pages by `recorded_at` descending. A query cannot
///   order by `original_recorded_at ?? recorded_at`, so the caller orders
///   by that effective instant and uses [HistoryPage.watermark] (the
///   `recorded_at` of the last document read) as the bound below which the
///   source may still hold unread events: an event's effective instant is
///   never later than its `recorded_at` (`original_recorded_at` is the
///   earlier, original instant of a re-recorded event).
library;

import 'package:learning_tracker/domain/learner_state/ports/change_log_repository.dart'
    show ChangeLogRepository;
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_event_repository.dart'
    show LearningEventRepository;

/// Documents per history page of each source (AD-38).
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
