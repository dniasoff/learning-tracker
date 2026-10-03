/// The in-memory form of the C0 history-page reads
/// (`ChangeLogRepository.historyPage`, `LearningEventRepository.historyPage`)
/// shared by the test fakes: the same order and page contract as
/// `history_page_query.dart` — newest ordering instant first, ties by id
/// descending, at most `limit` rows, an integer offset as the cursor.
library;

import 'package:learning_tracker/domain/learner_state/ports/history_page.dart';

/// One page of [rows] ordered by [instantOf] descending (ties by [idOf]
/// descending), after [after].
HistoryPage<T> inMemoryHistoryPage<T>(
  Iterable<T> rows, {
  required DateTime Function(T) instantOf,
  required String Function(T) idOf,
  required HistoryCursor? after,
  required int limit,
}) {
  if (limit < 1 || limit > kChangeHistoryPageSize) {
    throw ArgumentError.value(limit, 'limit', 'must be 1..100');
  }
  final sorted = rows.toList()
    ..sort((a, b) {
      final t = instantOf(b).compareTo(instantOf(a));
      return t != 0 ? t : idOf(b).compareTo(idOf(a));
    });
  final offset = (after?.token as int?) ?? 0;
  final page = sorted.skip(offset).take(limit).toList();
  final exhausted = page.length < limit;
  return HistoryPage(
    items: page,
    next: exhausted ? null : HistoryCursor(offset + page.length),
    exhausted: exhausted,
    watermark: page.isEmpty ? null : instantOf(page.last),
  );
}
