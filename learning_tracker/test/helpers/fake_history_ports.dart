/// In-memory C0 history reads for the DNI-513 tests: a [ChangeLogRepository]
/// and a [LearningEventRepository] over one shared store, with the same
/// ordering and page contract as the Firestore adapters (newest `at` /
/// `recorded_at` first, ties by id descending), read counting and
/// injectable failures. Only the reads the Change history makes are
/// implemented; the engine's watches and the writes throw.
library;

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/change_log_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/history_page.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_event_repository.dart';

import 'learner_state/in_memory_history_page.dart';

/// A read the fake failed on purpose.
final class FakeHistoryReadFailure implements Exception {
  /// Creates the failure for [source].
  const FakeHistoryReadFailure(this.source);

  /// `change_log`, `learning_events` or `lookup`.
  final String source;

  @override
  String toString() => 'FakeHistoryReadFailure($source)';
}

/// The two C0 ports the Change history reads.
abstract interface class HistoryPorts {
  /// The `change_log` port.
  ChangeLogRepository get changeLog;

  /// The `learning_events` port.
  LearningEventRepository get events;
}

/// In-memory history pages behind both ports.
final class FakeHistoryPorts implements HistoryPorts {
  /// Creates the fake over [entries] and [events].
  FakeHistoryPorts({
    List<ChangeLogEntry> entries = const [],
    List<LearningEvent> events = const [],
  }) : entries = [...entries],
       storedEvents = [...events];

  /// Stored `change_log` entries.
  final List<ChangeLogEntry> entries;

  /// Stored `learning_events`.
  final List<LearningEvent> storedEvents;

  /// Every page read, in order: `('change_log' | 'learning_events', offset)`.
  final List<(String, int)> reads = [];

  /// Ids requested by `eventsById`.
  final List<Set<String>> lookups = [];

  /// Action ids requested by `entriesOfAction`, one set per call.
  final List<Set<String>> actionLookups = [];

  /// The next N `entriesOfAction` calls throw.
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

  @override
  late final ChangeLogRepository changeLog = _FakeChangeLog(this);

  @override
  late final LearningEventRepository events = _FakeEvents(this);
}

final class _FakeChangeLog implements ChangeLogRepository {
  _FakeChangeLog(this._store);

  final FakeHistoryPorts _store;

  @override
  Future<HistoryPage<ChangeLogEntry>> historyPage(
    LearnerScope scope, {
    HistoryCursor? after,
    int limit = kChangeHistoryPageSize,
  }) async {
    await _store.gate;
    if (_store.failChangeLogReads > 0) {
      _store.failChangeLogReads--;
      throw const FakeHistoryReadFailure('change_log');
    }
    _store.reads.add(('change_log', (after?.token as int?) ?? 0));
    return inMemoryHistoryPage(
      _store.entries,
      instantOf: (e) => e.at,
      idOf: (e) => e.id,
      after: after,
      limit: limit,
    );
  }

  @override
  Future<List<ChangeLogEntry>> entriesOfAction(
    LearnerScope scope,
    String actionId,
  ) async {
    _store.actionLookups.add({actionId});
    if (_store.failActionLookups > 0) {
      _store.failActionLookups--;
      throw const FakeHistoryReadFailure('lookup');
    }
    return [
      for (final e in _store.entries)
        if (e.actionId == actionId) e,
    ]..sort((a, b) => a.id.compareTo(b.id));
  }

  @override
  Stream<CompleteRead<ChangeLogEntry>> watchIntentHistory(LearnerScope scope) =>
      throw UnimplementedError('not read by the Change history');

  @override
  Stream<bool> watchIsReverted(LearnerScope scope, String actionId) =>
      throw UnimplementedError('not read by the Change history');

  @override
  Future<void> commitGoverned(LearnerScope scope, GovernedBatch batch) =>
      throw UnimplementedError('the Change history never writes');
}

final class _FakeEvents implements LearningEventRepository {
  _FakeEvents(this._store);

  final FakeHistoryPorts _store;

  @override
  Future<HistoryPage<LearningEvent>> historyPage(
    LearnerScope scope, {
    HistoryCursor? after,
    int limit = kChangeHistoryPageSize,
  }) async {
    await _store.gate;
    if (_store.failEventReads > 0) {
      _store.failEventReads--;
      throw const FakeHistoryReadFailure('learning_events');
    }
    _store.reads.add(('learning_events', (after?.token as int?) ?? 0));
    return inMemoryHistoryPage(
      _store.storedEvents,
      instantOf: rawRecordedAtForSkewRule,
      idOf: (e) => e.id,
      after: after,
      limit: limit,
    );
  }

  @override
  Future<List<LearningEvent>> eventsById(
    LearnerScope scope,
    Set<String> ids,
  ) async {
    _store.lookups.add(ids);
    return [
      for (final e in _store.storedEvents)
        if (ids.contains(e.id)) e,
    ];
  }

  @override
  Stream<CompleteRead<LearningEvent>> watchAll(LearnerScope scope) =>
      throw UnimplementedError('not read by the Change history');

  @override
  Future<void> create(LearnerScope scope, LearningEvent event) =>
      throw UnimplementedError('the Change history never writes');
}
