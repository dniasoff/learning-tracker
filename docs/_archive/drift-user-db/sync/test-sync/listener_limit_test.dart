/// Phase 2 (sync-architecture-plan 2026-05-21) — listener bound tests.
///
/// Verifies that every wired listener carries the canonical
/// `.orderBy(<field>, descending: true).limit(kListenerPageSize)` shape so
/// the gRPC stream payload never grows unbounded with the user's history.
///
/// Two layers are covered:
///   1. `FirestoreListenerSource.openChannels()` passes a per-collection
///      ordering field to the gateway.
///   2. The gateway impl, via a stub, records the `orderField` + `limit`
///      every listener was opened with.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/firestore_gateway_impl.dart';
import 'package:learning_tracker/core/sync/firestore_listener_source.dart';

class _RecordingGateway implements FirestoreGateway {
  final List<({String collection, String orderField, int limit})>
  collectionCalls = [];
  final List<({String collection, String docId})> docCalls = [];
  int tutorGrantsLimit = -1;
  int learnerProfilesLimit = -1;

  @override
  Stream<ListenerSnapshot> listenToCollection({
    required int profileId,
    required String collection,
    required String orderField,
    int limit = FirestoreGatewayImpl.kListenerPageSize,
  }) {
    collectionCalls.add((
      collection: collection,
      orderField: orderField,
      limit: limit,
    ));
    return const Stream.empty();
  }

  @override
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) {
    docCalls.add((collection: collection, docId: docId));
    return const Stream.empty();
  }

  @override
  Stream<ListenerSnapshot> listenToTutorGrants({
    int limit = FirestoreGatewayImpl.kListenerPageSize,
  }) {
    tutorGrantsLimit = limit;
    return const Stream.empty();
  }

  @override
  Stream<ListenerSnapshot> listenToLearnerProfiles({
    int limit = FirestoreGatewayImpl.kListenerPageSize,
  }) {
    learnerProfilesLimit = limit;
    return const Stream.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('Phase 2 — listener bound (`.limit(500)` + `.orderBy(<field>)`)', () {
    late _RecordingGateway gateway;
    late FirestoreListenerSource source;

    setUp(() {
      gateway = _RecordingGateway();
      source = FirestoreListenerSource(
        resolveGateway: () => gateway,
        resolveProfileId: () => 1,
      );
    });

    test(
      'kListenerPageSize is the canonical default page size and equals 500',
      () {
        expect(FirestoreGatewayImpl.kListenerPageSize, 500);
      },
    );

    test('every wired collection listener uses limit == 500', () {
      source.openChannels();
      for (final call in gateway.collectionCalls) {
        expect(
          call.limit,
          equals(FirestoreGatewayImpl.kListenerPageSize),
          reason:
              '${call.collection}: every Phase 2 listener must be opened '
              'with the canonical page size — unbounded snapshots will '
              'reintroduce the O(history) cost the audit identified.',
        );
      }
    });

    test('every wired collection listener uses a known ordering field', () {
      source.openChannels();
      for (final call in gateway.collectionCalls) {
        final expected = FirestoreListenerSource.orderFields[call.collection];
        expect(
          expected,
          isNotNull,
          reason:
              '${call.collection} must declare an ordering field in '
              'FirestoreListenerSource.orderFields.',
        );
        expect(
          call.orderField,
          equals(expected),
          reason:
              '${call.collection} listener must order by the registered '
              'field (currently $expected, got ${call.orderField}).',
        );
      }
    });

    test('completions listener orders by completed_at (event-log timestamp, '
        'not updated_at — the schema has no updated_at)', () {
      source.openChannels();
      final call = gateway.collectionCalls.firstWhere(
        (c) => c.collection == 'completions',
      );
      expect(call.orderField, 'completed_at');
    });

    test('streak_events listener orders by event_timestamp '
        '(matches the streak event schema, not the snapshot updated_at)', () {
      source.openChannels();
      final call = gateway.collectionCalls.firstWhere(
        (c) => c.collection == 'streak_events',
      );
      expect(call.orderField, 'event_timestamp');
    });

    test('tutor_grants and learner_profiles listeners use limit == 500', () {
      source.openChannels();
      expect(
        gateway.tutorGrantsLimit,
        equals(FirestoreGatewayImpl.kListenerPageSize),
      );
      expect(
        gateway.learnerProfilesLimit,
        equals(FirestoreGatewayImpl.kListenerPageSize),
      );
    });

    test('the orderField map covers every wired collection — no listener '
        'silently falls back to documentId', () {
      source.openChannels();
      final wiredCollections = gateway.collectionCalls
          .map((c) => c.collection)
          .toSet();
      for (final collection in wiredCollections) {
        expect(
          FirestoreListenerSource.orderFields,
          contains(collection),
          reason:
              '$collection has no entry in FirestoreListenerSource.'
              'orderFields — it would order by documentId which is the '
              'wrong shape for newest-first delta streams.',
        );
      }
    });
  });
}
