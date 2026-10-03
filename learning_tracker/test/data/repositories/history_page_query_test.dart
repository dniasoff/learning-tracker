/// DNI-513 AC-2 / E-2 / AD-54: `readHistoryPage`, the one-shot
/// single-field, newest-first page read behind both C0 history reads —
/// page size bounds, cursor, exhaustion, watermark, and a malformed
/// document skipped without losing the page.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/history_page_query.dart';
import 'package:learning_tracker/domain/learner_state/ports/history_page.dart';

const _path = 'users/u/learner_profiles/p/change_log';

DateTime _at(int minutes) =>
    DateTime.utc(2026, 9, 1).add(Duration(minutes: minutes));

String _decode(String id, Map<String, Object?> map) {
  if (map['bad'] == true) throw const FormatException('bad');
  return id;
}

void main() {
  late FakeFirebaseFirestore db;

  setUp(() async {
    db = FakeFirebaseFirestore();
    for (var n = 1; n <= 5; n++) {
      await db.collection(_path).doc('d$n').set({
        'at': Timestamp.fromDate(_at(n)),
        if (n == 4) 'bad': true,
      });
    }
  });

  Future<HistoryPage<String>> read(HistoryCursor? after, {int limit = 2}) =>
      readHistoryPage<String>(
        db.collection(_path),
        orderField: 'at',
        after: after,
        limit: limit,
        decode: _decode,
      );

  test('pages newest first, each after the previous cursor, until a short '
      'page exhausts the source', () async {
    final first = await read(null);
    expect(first.items, ['d5'], reason: 'd4 does not decode');
    expect(first.rejected.single.docId, 'd4');
    expect(first.exhausted, isFalse);
    expect(first.next, isNotNull);
    expect(first.watermark, _at(4), reason: 'the last document read');

    final second = await read(first.next);
    expect(second.items, ['d3', 'd2']);
    expect(second.watermark, _at(2));

    final third = await read(second.next);
    expect(third.items, ['d1']);
    expect(third.exhausted, isTrue);
    expect(third.next, isNull);
  });

  test('an empty source is exhausted with no watermark', () async {
    final page = await readHistoryPage<String>(
      db.collection('users/u/learner_profiles/p/learning_events'),
      orderField: 'recorded_at',
      after: null,
      limit: kChangeHistoryPageSize,
      decode: _decode,
    );
    expect(page.items, isEmpty);
    expect(page.exhausted, isTrue);
    expect(page.next, isNull);
    expect(page.watermark, isNull);
  });

  test('a page size outside 1..100 is refused', () {
    expect(() => read(null, limit: 0), throwsArgumentError);
    expect(
      () => read(null, limit: kChangeHistoryPageSize + 1),
      throwsArgumentError,
    );
  });
}
