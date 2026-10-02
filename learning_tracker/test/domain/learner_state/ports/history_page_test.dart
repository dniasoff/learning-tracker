/// DNI-513 AC-2: the history page shape both C0 history reads return —
/// at most 100 documents per page (AD-38), an immutable page, and the
/// cursor, exhaustion and watermark each source pages by on its own.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/history_page.dart';

void main() {
  test('a page holds at most 100 documents (AD-38)', () {
    expect(kChangeHistoryPageSize, 100);
  });

  test('a page copies its items and rejected rows unmodifiably', () {
    final items = ['b', 'a'];
    final rejected = [RejectedRow('x', StateError('bad'))];
    final page = HistoryPage<String>(
      items: items,
      rejected: rejected,
      next: const HistoryCursor('a'),
      exhausted: false,
      watermark: DateTime.utc(2026, 9, 1),
    );
    items.add('c');
    rejected.clear();
    expect(page.items, ['b', 'a']);
    expect(page.rejected.single.docId, 'x');
    expect(() => page.items.add('z'), throwsUnsupportedError);
    expect(() => page.rejected.clear(), throwsUnsupportedError);
    expect(page.next?.token, 'a');
    expect(page.exhausted, isFalse);
    expect(page.watermark, DateTime.utc(2026, 9, 1));
  });

  test('an exhausted page has no next cursor and nothing rejected by '
      'default', () {
    final page = HistoryPage<String>(
      items: const [],
      next: null,
      exhausted: true,
      watermark: null,
    );
    expect(page.rejected, isEmpty);
    expect(page.next, isNull);
    expect(page.watermark, isNull);
  });
}
