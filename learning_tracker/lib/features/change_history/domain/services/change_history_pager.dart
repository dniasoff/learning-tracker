/// Lazy paging of the parent Change history (Story 4.5 / DNI-513 AC-2,
/// AC-8, AC-9).
///
/// [ChangeHistoryPager.fill] reads the first page of both sources, then
/// only the source that bounds the merged list, one page at a time, until
/// the caller's view is full or both sources are exhausted — so a filter
/// that keeps few rows reads further pages, and nothing is loaded up
/// front. A failed read leaves the buffer and cursors as they were: the
/// next [ChangeHistoryPager.fill] retries the same page, and the buffer's
/// per-document de-duplication keeps a retried page from adding a row
/// twice.
library;

import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/change_history/domain/models/history_item.dart';
import 'package:learning_tracker/features/change_history/domain/repositories/change_history_repository.dart';
import 'package:learning_tracker/features/change_history/domain/services/change_history_merge.dart';

/// Whether the merged [visible] items fill the caller's view.
typedef HistoryViewFull = bool Function(List<HistoryItem> visible);

/// Pages one learner's history into a [ChangeHistoryBuffer].
final class ChangeHistoryPager {
  /// Creates a pager over [repository] for [scope].
  ChangeHistoryPager({
    required ChangeHistoryRepository repository,
    required this.scope,
    this.pageSize = kChangeHistoryPageSize,
  }) : _repository = repository;

  final ChangeHistoryRepository _repository;

  /// The learner whose history this is.
  final LearnerScope scope;

  /// Documents per page (≤ [kChangeHistoryPageSize]).
  final int pageSize;

  /// The pages read so far.
  final ChangeHistoryBuffer buffer = ChangeHistoryBuffer();

  final Set<String> _lookedUp = {};

  /// Reads pages until [isFull] holds for the visible items or both
  /// sources are exhausted, then resolves the targets of visible `void`
  /// events that are not on a loaded page. Throws the first read failure.
  Future<void> fill(HistoryViewFull isFull) async {
    while (true) {
      if (!buffer.started) {
        await Future.wait([
          if (!buffer.changeLog.started) _read(HistorySource.changeLog),
          if (!buffer.learningEvents.started)
            _read(HistorySource.learningEvents),
        ]);
        continue;
      }
      final next = buffer.boundingSource;
      if (next == null || isFull(buffer.visibleItems())) break;
      await _read(next);
    }
    await _lookUpVoidTargets();
  }

  Future<void> _read(HistorySource source) async {
    switch (source) {
      case HistorySource.changeLog:
        buffer.addChangeLogPage(
          await _repository.changeLogPage(
            scope,
            after: buffer.changeLog.cursor,
            limit: pageSize,
          ),
        );
      case HistorySource.learningEvents:
        buffer.addLearningEventPage(
          await _repository.learningEventPage(
            scope,
            after: buffer.learningEvents.cursor,
            limit: pageSize,
          ),
        );
    }
  }

  /// A void's target is older than the void, so it may sit on an unread
  /// page; read it by id so the void row can say what it removed. A failed
  /// lookup is not a history failure: the row falls back to a generic
  /// label and the lookup is retried on the next fill.
  Future<void> _lookUpVoidTargets() async {
    final missing = <String>{
      for (final item in buffer.visibleItems())
        if (item is LearningBatchItem && !item.isLearn)
          for (final e in item.events)
            if (e.targetId case final target?)
              if (buffer.eventById(target) == null &&
                  !_lookedUp.contains(target))
                target,
    };
    if (missing.isEmpty) return;
    try {
      buffer.addLookups(await _repository.learningEventsById(scope, missing));
      _lookedUp.addAll(missing);
    } on Object {
      // Retried on the next fill; see the method doc.
    }
  }
}
