/// Unit tests for `watchCompletePaged` — the complete, document-id-paged,
/// AD-9-resilient live read behind both Story 1.2 repositories.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/paged_complete_query.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:mocktail/mocktail.dart';

// Mocks of sealed cloud_firestore types, as resilient_doc_stream_test does.
// ignore: subtype_of_sealed_class
class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class _MockSnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class _MockDoc extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

_MockSnapshot _snapshot(List<String> ids) {
  final snapshot = _MockSnapshot();
  final docs = [
    for (final id in ids)
      () {
        final doc = _MockDoc();
        when(() => doc.id).thenReturn(id);
        when(doc.data).thenReturn({'v': id});
        return doc;
      }(),
  ];
  when(() => snapshot.docs).thenReturn(docs);
  return snapshot;
}

String _decode(String id, Map<String, Object?> data) => data['v']! as String;

void main() {
  group('AD-9 listener recovery', () {
    test('a stream-level error is forwarded, the page resubscribes, and the '
        'complete list is published after recovery', () async {
      final query = _MockQuery();
      final opens = <StreamController<QuerySnapshot<Map<String, dynamic>>>>[];
      when(() => query.orderBy(FieldPath.documentId)).thenReturn(query);
      when(() => query.limit(500)).thenReturn(query);
      when(query.snapshots).thenAnswer((_) {
        final c = StreamController<QuerySnapshot<Map<String, dynamic>>>();
        opens.add(c);
        return c.stream;
      });

      final events = <Object>[];
      final sub = watchCompletePaged<String>(
        collection: query,
        decode: _decode,
        backoffBase: Duration.zero,
        backoffCap: Duration.zero,
        random: math.Random(1),
      ).listen(events.add, onError: (Object e) => events.add('error: $e'));
      addTearDown(sub.cancel);

      await pumpEventQueue();
      expect(opens, hasLength(1));
      opens.first.addError(StateError('unavailable'));
      await pumpEventQueue();
      expect(opens, hasLength(2));
      opens.last.add(_snapshot(['a', 'b']));
      await pumpEventQueue();

      expect(events, [
        const CompleteReadLoading<String>(),
        'error: Bad state: unavailable',
        CompleteReadReady<String>(['a', 'b']),
      ]);
    });

    test('after an error, an unchanged complete list is re-published so a '
        'consumer leaves its error state', () async {
      final query = _MockQuery();
      final opens = <StreamController<QuerySnapshot<Map<String, dynamic>>>>[];
      when(() => query.orderBy(FieldPath.documentId)).thenReturn(query);
      when(() => query.limit(500)).thenReturn(query);
      when(query.snapshots).thenAnswer((_) {
        final c = StreamController<QuerySnapshot<Map<String, dynamic>>>();
        opens.add(c);
        return c.stream;
      });

      final events = <Object>[];
      final sub = watchCompletePaged<String>(
        collection: query,
        decode: _decode,
        backoffBase: Duration.zero,
        backoffCap: Duration.zero,
        random: math.Random(1),
      ).listen(events.add, onError: (Object e) => events.add('error'));
      addTearDown(sub.cancel);

      await pumpEventQueue();
      opens.first.add(_snapshot(['a']));
      await pumpEventQueue();
      opens.first.add(_snapshot(['a']));
      await pumpEventQueue();
      opens.first.addError(StateError('permission-denied'));
      await pumpEventQueue();
      opens.last.add(_snapshot(['a']));
      await pumpEventQueue();

      expect(events, [
        const CompleteReadLoading<String>(),
        CompleteReadReady<String>(['a']),
        'error',
        CompleteReadReady<String>(['a']),
      ]);
    });
  });

  group('paging', () {
    Future<void> seed(FakeFirebaseFirestore f, int count) async {
      for (var i = 0; i < count; i++) {
        await f.collection('c').doc('d${i.toString().padLeft(4, '0')}').set({
          'v': 'x$i',
        });
      }
    }

    test('custom page size pages until a short page, never partial', () async {
      final firestore = FakeFirebaseFirestore();
      await seed(firestore, 7);
      final pageSizes = <int>[];
      final events = await watchCompletePaged<String>(
        collection: firestore.collection('c'),
        decode: (id, data) => data['v']! as String,
        pageSize: 3,
        probe:
            ({
              required pageIndex,
              required afterDocId,
              required limit,
              required delivered,
            }) {
              if (delivered != null) pageSizes.add(delivered);
            },
      ).take(2).toList();
      expect(events.first, isA<CompleteReadLoading<String>>());
      expect((events.last as CompleteReadReady<String>).items, [
        for (var i = 0; i < 7; i++) 'x$i',
      ]);
      expect(pageSizes, [3, 3, 1]);
    });

    test('a page whose boundary shifts re-opens later pages and publishes '
        'only the re-assembled complete list', () async {
      final firestore = FakeFirebaseFirestore();
      await seed(firestore, 4);
      final events = <CompleteRead<String>>[];
      final sub = watchCompletePaged<String>(
        collection: firestore.collection('c'),
        decode: (id, data) => id,
        pageSize: 2,
      ).listen(events.add);
      addTearDown(sub.cancel);
      await pumpEventQueue(times: 50);
      // Insert a doc that sorts into the FIRST page's range.
      await firestore.collection('c').doc('d0000a').set({'v': 'new'});
      await pumpEventQueue(times: 50);

      final readies = events.whereType<CompleteReadReady<String>>().toList();
      expect(readies.first.items, ['d0000', 'd0001', 'd0002', 'd0003']);
      expect(readies.last.items, [
        'd0000',
        'd0000a',
        'd0001',
        'd0002',
        'd0003',
      ]);
      for (final ready in readies) {
        expect(ready.items.toSet(), hasLength(ready.items.length));
      }
    });

    test('rejects page sizes above the SR-4 cap', () {
      expect(
        () => watchCompletePaged<String>(
          collection: FakeFirebaseFirestore().collection('c'),
          decode: (id, data) => id,
          pageSize: 501,
        ),
        throwsArgumentError,
      );
    });
  });
}
