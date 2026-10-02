/// The client-side merge of the parent Change history (Story 4.5 /
/// DNI-513 AC-2, E-1; AD-38).
///
/// [ChangeHistoryBuffer] holds the pages read so far from both sources,
/// de-duplicated by document id, and exposes the merged items whose order
/// can no longer change: an item is visible only when it sorts strictly
/// above the [ChangeHistoryBuffer.frontier] — the highest watermark of the
/// sources that still have unread pages. Every unread document of a source
/// sorts at or below that source's watermark, so a visible item is never
/// followed later by a newer one, an item on a page boundary is neither
/// lost nor duplicated, and the merged list reaches its end exactly when
/// the bounding source must be read again.
library;

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/history_page.dart';
import 'package:learning_tracker/features/change_history/domain/models/history_item.dart';

/// The read state of one history source.
final class HistorySourceState {
  /// Whether a first page has been read.
  bool started = false;

  /// Whether the source holds nothing after the pages read.
  bool exhausted = false;

  /// The ordering instant of the last document read (UTC).
  DateTime? watermark;

  /// Where the next page starts.
  HistoryCursor? cursor;

  /// Pages read so far.
  int pagesRead = 0;

  /// Documents skipped as undecodable (E-2).
  int rejected = 0;

  void _apply<T>(HistoryPage<T> page) {
    started = true;
    pagesRead++;
    rejected += page.rejected.length;
    exhausted = page.exhausted;
    cursor = page.next;
    // A page whose last order value was unreadable keeps the old bound.
    watermark = page.watermark ?? watermark;
  }
}

/// Which source a read goes to.
enum HistorySource {
  /// `change_log`.
  changeLog,

  /// `learning_events`.
  learningEvents,
}

/// The pages read so far and their merged, final-order items.
final class ChangeHistoryBuffer {
  final Map<String, ChangeLogEntry> _entries = {};
  final Map<String, LearningEvent> _events = {};
  final Map<String, LearningEvent> _lookups = {};
  final Map<String, ChangeLogEntry> _actionLookups = {};

  /// `change_log` read state.
  final HistorySourceState changeLog = HistorySourceState();

  /// `learning_events` read state.
  final HistorySourceState learningEvents = HistorySourceState();

  List<HistoryItem>? _visible;

  /// Every loaded `change_log` entry.
  Iterable<ChangeLogEntry> get entries => _entries.values;

  /// Every loaded `learning_events` document on a page.
  Iterable<LearningEvent> get events => _events.values;

  /// The loaded event with [id], from a page or a by-id lookup.
  LearningEvent? eventById(String id) => _events[id] ?? _lookups[id];

  /// Adds a `change_log` page (idempotent per document id).
  void addChangeLogPage(HistoryPage<ChangeLogEntry> page) {
    for (final e in page.items) {
      _entries[e.id] = e;
    }
    changeLog._apply(page);
    _visible = null;
  }

  /// Adds a `learning_events` page (idempotent per document id).
  void addLearningEventPage(HistoryPage<LearningEvent> page) {
    for (final e in page.items) {
      _events[e.id] = e;
    }
    learningEvents._apply(page);
    _visible = null;
  }

  /// Adds events read by id (void targets); they are context, not rows.
  void addLookups(Iterable<LearningEvent> events) {
    for (final e in events) {
      _lookups[e.id] = e;
    }
  }

  /// Adds `change_log` entries read by `action_id` (the actions undos
  /// revert); they are context, not rows.
  void addActionLookups(Iterable<ChangeLogEntry> entries) {
    for (final e in entries) {
      _actionLookups[e.id] = e;
    }
  }

  /// Every known entry of [actionId], from a page or an action lookup,
  /// de-duplicated by id.
  List<ChangeLogEntry> entriesOfAction(String actionId) => [
    for (final e in {..._actionLookups, ..._entries}.values)
      if (e.actionId == actionId) e,
  ];

  /// Whether both sources have had a first page read.
  bool get started => changeLog.started && learningEvents.started;

  /// Whether both sources are read to their end.
  bool get exhausted => changeLog.exhausted && learningEvents.exhausted;

  static final _unbounded = DateTime.utc(275760, 9, 13);

  /// Items strictly above this instant are final; null when nothing is
  /// left to read. A source that has not started bounds everything.
  DateTime? get frontier {
    DateTime? bound;
    for (final s in [changeLog, learningEvents]) {
      if (s.started && s.exhausted) continue;
      final w = s.started ? (s.watermark ?? _unbounded) : _unbounded;
      if (bound == null || w.isAfter(bound)) bound = w;
    }
    return bound;
  }

  /// The source whose next page lowers the [frontier]: an unstarted source
  /// first, else the unexhausted source with the newest watermark; null
  /// when both are exhausted.
  HistorySource? get boundingSource {
    if (!changeLog.started) return HistorySource.changeLog;
    if (!learningEvents.started) return HistorySource.learningEvents;
    if (changeLog.exhausted && learningEvents.exhausted) return null;
    if (changeLog.exhausted) return HistorySource.learningEvents;
    if (learningEvents.exhausted) return HistorySource.changeLog;
    final a = changeLog.watermark ?? _unbounded;
    final b = learningEvents.watermark ?? _unbounded;
    return b.isAfter(a)
        ? HistorySource.learningEvents
        : HistorySource.changeLog;
  }

  /// Every loaded item, merged newest first (including those not final
  /// yet).
  List<HistoryItem> allItems() {
    final byAction = <String, List<ChangeLogEntry>>{};
    for (final e in _entries.values) {
      (byAction[e.actionId] ??= []).add(e);
    }
    final byBatch = <String, List<LearningEvent>>{};
    for (final e in _events.values) {
      (byBatch[LearningBatchItem.batchKeyOf(e)] ??= []).add(e);
    }
    return [
      for (final MapEntry(:key, :value) in byAction.entries)
        GovernedActionItem(key, value),
      for (final batch in byBatch.values) LearningBatchItem(batch),
    ]..sort(compareHistoryItems);
  }

  /// The merged items whose position is final, newest first.
  List<HistoryItem> visibleItems() {
    final cached = _visible;
    if (cached != null) return cached;
    final bound = frontier;
    final visible = List<HistoryItem>.unmodifiable([
      for (final item in allItems())
        if (bound == null || item.sortAt.isAfter(bound)) item,
    ]);
    _visible = visible;
    return visible;
  }
}
