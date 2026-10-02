/// An in-memory [ChangeHistoryRepository] for the DNI-513 tests: the same
/// ordering and page contract as the Firestore adapter (newest `at` /
/// `recorded_at` first, ties by id descending), with read counting and
/// injectable failures.
library;

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/change_history/domain/repositories/change_history_repository.dart';

/// A read the fake failed on purpose.
final class FakeHistoryReadFailure implements Exception {
  /// Creates the failure for [source].
  const FakeHistoryReadFailure(this.source);

  /// `change_log`, `learning_events` or `lookup`.
  final String source;

  @override
  String toString() => 'FakeHistoryReadFailure($source)';
}

/// In-memory history pages.
final class FakeChangeHistoryRepository implements ChangeHistoryRepository {
  /// Creates the fake over [entries] and [events].
  FakeChangeHistoryRepository({
    List<ChangeLogEntry> entries = const [],
    List<LearningEvent> events = const [],
  }) : entries = [...entries],
       events = [...events];

  /// Stored `change_log` entries.
  final List<ChangeLogEntry> entries;

  /// Stored `learning_events`.
  final List<LearningEvent> events;

  /// Every page read, in order: `('change_log' | 'learning_events', offset)`.
  final List<(String, int)> reads = [];

  /// Ids requested by [learningEventsById].
  final List<Set<String>> lookups = [];

  /// Action ids requested by [changeLogEntriesOfActions].
  final List<Set<String>> actionLookups = [];

  /// The next N [changeLogEntriesOfActions] calls throw.
  int failActionLookups = 0;

  /// The next N `change_log` page reads throw.
  int failChangeLogReads = 0;

  /// The next N `learning_events` page reads throw.
  int failEventReads = 0;

  /// Pending reads complete only when this is completed (null: at once).
  Future<void>? gate;

  /// Reads of `change_log` pages.
  int get changeLogReads => reads.where((r) => r.$1 == 'change_log').length;

  /// Reads of `learning_events` pages.
  int get eventReads => reads.where((r) => r.$1 == 'learning_events').length;

  static int _desc(DateTime a, String aId, DateTime b, String bId) {
    final t = b.compareTo(a);
    return t != 0 ? t : bId.compareTo(aId);
  }

  @override
  Future<HistoryPage<ChangeLogEntry>> changeLogPage(
    LearnerScope scope, {
    HistoryCursor? after,
    int limit = kChangeHistoryPageSize,
  }) async {
    await gate;
    if (failChangeLogReads > 0) {
      failChangeLogReads--;
      throw const FakeHistoryReadFailure('change_log');
    }
    final sorted = [...entries]..sort((a, b) => _desc(a.at, a.id, b.at, b.id));
    final offset = (after?.token as int?) ?? 0;
    reads.add(('change_log', offset));
    final page = sorted.skip(offset).take(limit).toList();
    final exhausted = page.length < limit;
    return HistoryPage(
      items: page,
      next: exhausted ? null : HistoryCursor(offset + page.length),
      exhausted: exhausted,
      watermark: page.isEmpty ? null : page.last.at,
    );
  }

  @override
  Future<HistoryPage<LearningEvent>> learningEventPage(
    LearnerScope scope, {
    HistoryCursor? after,
    int limit = kChangeHistoryPageSize,
  }) async {
    await gate;
    if (failEventReads > 0) {
      failEventReads--;
      throw const FakeHistoryReadFailure('learning_events');
    }
    final sorted = [...events]
      ..sort(
        (a, b) => _desc(
          rawRecordedAtForSkewRule(a),
          a.id,
          rawRecordedAtForSkewRule(b),
          b.id,
        ),
      );
    final offset = (after?.token as int?) ?? 0;
    reads.add(('learning_events', offset));
    final page = sorted.skip(offset).take(limit).toList();
    final exhausted = page.length < limit;
    return HistoryPage(
      items: page,
      next: exhausted ? null : HistoryCursor(offset + page.length),
      exhausted: exhausted,
      watermark: page.isEmpty ? null : rawRecordedAtForSkewRule(page.last),
    );
  }

  @override
  Future<List<LearningEvent>> learningEventsById(
    LearnerScope scope,
    Set<String> ids,
  ) async {
    lookups.add(ids);
    return [
      for (final e in events)
        if (ids.contains(e.id)) e,
    ];
  }

  @override
  Future<List<ChangeLogEntry>> changeLogEntriesOfActions(
    LearnerScope scope,
    Set<String> actionIds,
  ) async {
    actionLookups.add(actionIds);
    if (failActionLookups > 0) {
      failActionLookups--;
      throw const FakeHistoryReadFailure('lookup');
    }
    return [
      for (final e in entries)
        if (actionIds.contains(e.actionId)) e,
    ];
  }
}
