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

String _id(int i) => 'd${i.toString().padLeft(4, '0')}';

/// A collection whose every page listener is scripted by the test: each
/// `snapshots()` call is recorded with its `startAfterDocument` cursor, so
/// a test can deliver exactly the (possibly transient) page contents a real
/// listener would — e.g. a page that shrinks before its limit window
/// refills.
final class _ScriptedCollection {
  _ScriptedCollection() {
    final ordered = _queryAfter(null);
    when(() => root.orderBy(FieldPath.documentId)).thenReturn(ordered);
  }

  final root = _MockQuery();
  final opens =
      <
        ({
          String? after,
          StreamController<QuerySnapshot<Map<String, dynamic>>> c,
        })
      >[];

  _MockQuery _queryAfter(String? after) {
    final q = _MockQuery();
    when(() => q.limit(any())).thenReturn(q);
    when(() => q.startAfterDocument(any())).thenAnswer(
      (inv) => _queryAfter(
        (inv.positionalArguments.first as DocumentSnapshot<Object?>).id,
      ),
    );
    when(q.snapshots).thenAnswer((_) {
      final c = StreamController<QuerySnapshot<Map<String, dynamic>>>();
      addTearDown(c.close);
      opens.add((after: after, c: c));
      return c.stream;
    });
    return q;
  }

  /// The most recently opened listener starting after [after].
  StreamController<QuerySnapshot<Map<String, dynamic>>> latest(String? after) =>
      opens.lastWhere((o) => o.after == after).c;

  /// Delivers [ids] to the newest listener after [after].
  Future<void> deliver(String? after, Iterable<String> ids) async {
    latest(after).add(_snapshot(ids.toList()));
    await pumpEventQueue();
  }
}

void main() {
  setUpAll(() => registerFallbackValue(_MockDoc()));

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

  group('an established page that shrinks never drops later pages', () {
    // Each scenario: 1 loading, then complete lists only. The transient
    // short page (a delete delivered before the limit window refills)
    // must not be read as end-of-collection.
    Future<
      (
        _ScriptedCollection,
        List<CompleteRead<String>>,
        StreamSubscription<CompleteRead<String>>,
      )
    >
    open() async {
      final collection = _ScriptedCollection();
      final events = <CompleteRead<String>>[];
      final sub = watchCompletePaged<String>(
        collection: collection.root,
        decode: (id, data) => id,
        backoffBase: Duration.zero,
        backoffCap: Duration.zero,
        random: math.Random(1),
      ).listen(events.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      return (collection, events, sub);
    }

    List<String> range(int from, int to, {Set<int> except = const {}}) => [
      for (var i = from; i < to; i++)
        if (!except.contains(i)) _id(i),
    ];

    test('501 rows: a delete in page 0 keeps the 501st row', () async {
      final (c, events, _) = await open();
      await c.deliver(null, range(0, 500));
      await c.deliver(_id(499), [_id(500)]);
      expect((events.last as CompleteReadReady<String>).items, range(0, 501));

      // Transient: page 0 shrinks to 499 before it refills.
      await c.deliver(null, range(0, 500, except: {10}));
      expect(
        (events.last as CompleteReadReady<String>).items,
        range(0, 501, except: {10}),
      );

      // Refill: page 0 is full again with the 501st row; page 1 is
      // re-cursored after it and comes back empty.
      await c.deliver(null, range(0, 501, except: {10}));
      expect(c.opens.last.after, _id(500));
      await c.deliver(_id(500), const []);

      final readies = events.whereType<CompleteReadReady<String>>().toList();
      expect(events.first, isA<CompleteReadLoading<String>>());
      expect(events.whereType<CompleteReadLoading<String>>(), hasLength(1));
      expect(readies.map((r) => r.items), [
        range(0, 501),
        range(0, 501, except: {10}),
      ]);
    });

    test('1000 rows: a delete in page 0 keeps every page-1 row', () async {
      final (c, events, _) = await open();
      await c.deliver(null, range(0, 500));
      await c.deliver(_id(499), range(500, 1000));
      await c.deliver(_id(999), const []);
      expect((events.last as CompleteReadReady<String>).items, range(0, 1000));

      await c.deliver(null, range(0, 500, except: {10}));
      expect(
        (events.last as CompleteReadReady<String>).items,
        range(0, 1000, except: {10}),
      );
      for (final ready in events.whereType<CompleteReadReady<String>>()) {
        expect(ready.items.length, greaterThanOrEqualTo(999));
      }
    });

    test('1000 rows: deleting page 0\'s LAST row re-pages the successor '
        'from the new cursor and publishes only the rebuilt chain', () async {
      final (c, events, _) = await open();
      await c.deliver(null, range(0, 500));
      await c.deliver(_id(499), range(500, 1000));
      await c.deliver(_id(999), const []);
      final before = events.length;

      // Page 0 shrinks and its end cursor moves from d0499 to d0498.
      await c.deliver(null, range(0, 499));
      expect(c.opens.last.after, _id(498));
      expect(events.length, before, reason: 'no partial publication');

      await c.deliver(_id(498), range(500, 1000));
      expect(c.opens.last.after, _id(999));
      expect(events.length, before, reason: 'tail not proven yet');
      await c.deliver(_id(999), const []);

      expect(
        (events.last as CompleteReadReady<String>).items,
        range(0, 1000, except: {499}),
      );
    });
  });

  group('deletes against a live collection (limit windows refill)', () {
    for (final count in [501, 1000]) {
      test('$count rows: deleting from page 0 publishes the full '
          'remainder', () async {
        final firestore = FakeFirebaseFirestore();
        for (var i = 0; i < count; i++) {
          await firestore.collection('c').doc(_id(i)).set({'v': _id(i)});
        }
        final events = <CompleteRead<String>>[];
        final sub = watchCompletePaged<String>(
          collection: firestore.collection('c'),
          decode: (id, data) => id,
        ).listen(events.add);
        addTearDown(sub.cancel);
        await pumpEventQueue(times: 50);
        expect((events.last as CompleteReadReady<String>).items, [
          for (var i = 0; i < count; i++) _id(i),
        ]);

        // Not the page-0 boundary row: fake_cloud_firestore (unlike real
        // Firestore) rejects a cursor snapshot whose doc was deleted. The
        // boundary case is covered by the scripted tests above.
        await firestore.collection('c').doc(_id(10)).delete();
        await firestore.collection('c').doc(_id(250)).delete();
        await pumpEventQueue(times: 50);

        expect((events.last as CompleteReadReady<String>).items, [
          for (var i = 0; i < count; i++)
            if (i != 10 && i != 250) _id(i),
        ]);
      });
    }
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
