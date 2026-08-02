/// Unit tests for `lib/data/firestore/resilient_doc_stream.dart` — the
/// small resubscribe-on-error wrapper every Firestore repository's "watch
/// one document" method should build on.
///
/// [openStream] is a factory rather than a bare `Stream`, specifically so
/// these tests can simulate a `snapshots()` stream that errors once and
/// then recovers — a real Firestore listener stream cannot be coerced into
/// erroring on demand outside an emulator, but a factory swapping which
/// controller it returns on each call can.
///
/// TQ-6: no wall clock, and no fixed-millisecond-delay races against a
/// `.listen(` collector (AUD-t-cross-36) — tests that wait for a real
/// backoff timer to fire assert via `expect(stream, emitsInOrder([...]))`
/// (the deterministic pattern `profile_dao_test.dart`'s
/// `watchProfilesByAccount` test already uses in this codebase), which waits
/// for the actual emission rather than racing a clock. The one test that
/// needs to prove an ABSENCE of a resubscribe (nothing to await via
/// `emitsInOrder`) uses `package:fake_async` instead, so "did the timer
/// fire" is decided by a simulated clock, never a real sleep.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:mocktail/mocktail.dart';

// `DocumentSnapshot` is `@sealed` in cloud_firestore; implementing it as a
// mocktail test double is the intended extension point for test fakes (the
// lint just can't distinguish "test double" from "production subtype") —
// the exact same suppression `fake_cloud_firestore`'s own MockDocumentSnapshot
// uses, and `test/core/sync/firestore_gateway_impl_test.dart` documents for
// the sibling QueryDocumentSnapshot/DocumentChange case.
// ignore: subtype_of_sealed_class
class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

MockDocumentSnapshot _snapshotWith(Map<String, dynamic>? data) {
  final snapshot = MockDocumentSnapshot();
  when(() => snapshot.data()).thenReturn(data);
  return snapshot;
}

void main() {
  group('resilientDocStream — happy path', () {
    test(
      'decodes and forwards every snapshot the source stream emits',
      () async {
        final source =
            StreamController<DocumentSnapshot<Map<String, dynamic>>>();
        addTearDown(source.close);

        final stream = resilientDocStream<int>(
          openStream: () => source.stream,
          decode: (snapshot) => snapshot.data()!['n'] as int,
        );

        source.add(_snapshotWith({'n': 1}));
        source.add(_snapshotWith({'n': 2}));

        await expectLater(stream, emitsInOrder([1, 2]));
      },
    );

    test(
      'openStream is only called once while the subscription stays healthy',
      () async {
        var callCount = 0;
        final source =
            StreamController<DocumentSnapshot<Map<String, dynamic>>>();
        addTearDown(source.close);

        final stream = resilientDocStream<int>(
          openStream: () {
            callCount++;
            return source.stream;
          },
          decode: (snapshot) => snapshot.data()!['n'] as int,
        );

        source.add(_snapshotWith({'n': 1}));
        await expectLater(stream, emits(1));

        expect(callCount, 1);
      },
    );
  });

  group(
    'resilientDocStream — stream-level error: resubscribe with backoff',
    () {
      test(
        'a stream error is forwarded via addError, then a fresh subscription '
        'is opened after the backoff delay and its values come through',
        () async {
          final firstAttempt =
              StreamController<DocumentSnapshot<Map<String, dynamic>>>();
          final secondAttempt =
              StreamController<DocumentSnapshot<Map<String, dynamic>>>();
          addTearDown(firstAttempt.close);
          addTearDown(secondAttempt.close);

          final attempts = [firstAttempt.stream, secondAttempt.stream];
          var callCount = 0;
          final onErrorCalls = <Object>[];

          final stream = resilientDocStream<int>(
            openStream: () => attempts[callCount++],
            decode: (snapshot) => snapshot.data()!['n'] as int,
            backoffBase: const Duration(milliseconds: 5),
            backoffCap: const Duration(milliseconds: 20),
            onError: (error, _) => onErrorCalls.add(error),
          );

          firstAttempt.addError(StateError('boom'));
          // `secondAttempt` is single-subscription and buffers this event
          // until something actually listens to it — i.e. until the
          // backoff timer fires and resubscribes — so adding it now (rather
          // than after an arbitrary wait) is itself race-free.
          secondAttempt.add(_snapshotWith({'n': 42}));

          // Waits for the ACTUAL emissions rather than racing a clock: the
          // error surfaces immediately, and `42` only once the real backoff
          // timer fires and resubscribes onto `secondAttempt` — however
          // long that genuinely takes. Awaited (not bare `expect`) so the
          // post-hoc assertions below only run once the sequence settles.
          await expectLater(
            stream,
            emitsInOrder([emitsError(isA<StateError>()), 42]),
          );

          expect(onErrorCalls, hasLength(1));
          expect(callCount, 2, reason: 'resubscribed onto the second stream');
        },
      );

      test('the attempt counter resets after a successful snapshot, so the '
          'next error backs off from attempt 1 again', () async {
        final controllers = List.generate(
          3,
          (_) => StreamController<DocumentSnapshot<Map<String, dynamic>>>(),
        );
        for (final c in controllers) {
          addTearDown(c.close);
        }
        var callCount = 0;

        final stream = resilientDocStream<int>(
          openStream: () => controllers[callCount++].stream,
          decode: (snapshot) => snapshot.data()!['n'] as int,
          backoffBase: const Duration(milliseconds: 5),
          backoffCap: const Duration(milliseconds: 20),
        );

        controllers[0].addError(StateError('first'));
        // Buffered on controllers[1] until the first resubscribe listens to
        // it — delivered in the order added, value then error.
        controllers[1].add(_snapshotWith({'n': 1}));
        controllers[1].addError(StateError('second'));
        // Buffered on controllers[2] until the second resubscribe listens.
        controllers[2].add(_snapshotWith({'n': 2}));

        // Sequence: controllers[0] errors -> resubscribe onto controllers[1]
        // -> controllers[1] emits 1 (resets the attempt counter) ->
        // controllers[1] errors again -> resubscribe onto controllers[2] ->
        // controllers[2] emits 2, proving the second resubscribe happened.
        // Awaited so `callCount` is only checked once the whole sequence
        // (both real backoff timers) has actually settled.
        await expectLater(
          stream,
          emitsInOrder([
            emitsError(isA<StateError>()),
            1,
            emitsError(isA<StateError>()),
            2,
          ]),
        );

        expect(callCount, 3);
      });
    },
  );

  group('resilientDocStream — decode error: no resubscribe', () {
    test('a decode failure is forwarded via addError but does NOT open a new '
        'subscription — the next valid snapshot on the SAME stream still '
        'comes through', () async {
      var callCount = 0;
      final source = StreamController<DocumentSnapshot<Map<String, dynamic>>>();
      addTearDown(source.close);

      final stream = resilientDocStream<int>(
        openStream: () {
          callCount++;
          return source.stream;
        },
        decode: (snapshot) => snapshot.data()!['n'] as int,
      );

      // Missing 'n' key -> decode() throws a TypeError.
      source.add(_snapshotWith({'not_n': 1}));
      source.add(_snapshotWith({'n': 7}));

      await expectLater(
        stream,
        emitsInOrder([emitsError(isA<TypeError>()), 7]),
      );
      expect(callCount, 1, reason: 'a bad document must not resubscribe');
    });
  });

  group('resilientDocStream — lazy subscription + teardown', () {
    test(
      'openStream is not called until the returned stream gets a listener',
      () async {
        var callCount = 0;
        final source =
            StreamController<DocumentSnapshot<Map<String, dynamic>>>();
        addTearDown(source.close);

        final stream = resilientDocStream<int>(
          openStream: () {
            callCount++;
            return source.stream;
          },
          decode: (snapshot) => snapshot.data()!['n'] as int,
        );

        expect(callCount, 0);

        final subscription = stream.listen((_) {});
        addTearDown(subscription.cancel);
        expect(callCount, 1);
      },
    );

    test('cancelling the last listener cancels the pending backoff timer — no '
        'resubscribe happens after teardown', () {
      final firstAttempt =
          StreamController<DocumentSnapshot<Map<String, dynamic>>>();
      addTearDown(firstAttempt.close);

      // A real Timer needs real wall-clock time to prove it did NOT fire
      // — there is no emission to deterministically await here (that's
      // the whole point: nothing should happen). `fakeAsync` simulates
      // time passing instead of racing a real sleep against it (TQ-6).
      fakeAsync((async) {
        var callCount = 0;

        final stream = resilientDocStream<int>(
          openStream: () {
            callCount++;
            return firstAttempt.stream;
          },
          decode: (snapshot) => snapshot.data()!['n'] as int,
          backoffBase: const Duration(milliseconds: 5),
          backoffCap: const Duration(milliseconds: 20),
        );

        final subscription = stream.listen((_) {}, onError: (_, _) {});
        firstAttempt.addError(StateError('boom'));
        async.flushMicrotasks();
        expect(callCount, 1);

        subscription.cancel();
        // If the pending resubscribe timer were not cancelled, this would
        // bump callCount to 2 once it fired.
        async.elapse(const Duration(milliseconds: 50));

        expect(callCount, 1);
      });
    });
  });
}
