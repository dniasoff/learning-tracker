// Empirical settlement of the disputed offline claim.
//
// THE DISPUTE. `FirestoreCompletionRepository.recordCompletionIfAbsent` was
// changed from `runTransaction` to `get()` + `set(merge:true)` so that marking
// a completion would QUEUE offline instead of failing. A reviewer claims that
// fix rests on a false premise: that `DocumentReference.get()` THROWS
// UNAVAILABLE offline when the document is not in the local cache, rather than
// returning a not-exists snapshot. If the reviewer is right, the comment in
// that method is false and the offline path is still broken.
//
// This test answers it against the REAL cloud_firestore SDK on a REAL device.
// fake_cloud_firestore structurally cannot: it has no network and no offline
// concept, so any test of this path passes unconditionally.
//
// Run: flutter test integration_test/offline_probe_test.dart -d <device>
// with the Firestore emulator reachable at the host below.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// 10.0.2.2 is the Android emulator's alias for the host loopback.
const String kEmulatorHost = '10.0.2.2';
const int kFirestorePort = 8080;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseFirestore db;

  setUpAll(() async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'fake-api-key',
        appId: '1:1:android:1',
        messagingSenderId: '1',
        projectId: 'demo-offline-probe',
      ),
    );
    db = FirebaseFirestore.instance;
    db.useFirestoreEmulator(kEmulatorHost, kFirestorePort);
    db.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 20 * 1024 * 1024,
    );
  });

  test('Q1: get() on an UNCACHED doc while offline — throws or not-exists?',
      () async {
    // Never fetched on this device, so it cannot be in the cache.
    final ref = db.collection('probe').doc('never-fetched-${DateTime.now().microsecondsSinceEpoch}');

    await db.disableNetwork();
    String outcome;
    try {
      final snap = await ref.get();
      outcome = 'RETURNED snapshot, exists=${snap.exists}, '
          'isFromCache=${snap.metadata.isFromCache}';
    } on FirebaseException catch (e) {
      outcome = 'THREW FirebaseException code=${e.code}';
    } catch (e) {
      outcome = 'THREW ${e.runtimeType}: $e';
    } finally {
      await db.enableNetwork();
    }
    // Printed, not asserted — the POINT is to observe, not to confirm a bias.
    // ignore: avoid_print
    print('PROBE_Q1_UNCACHED_GET_OFFLINE :: $outcome');
  });

  test('Q2: set() while offline — queues, hangs, or throws?', () async {
    final ref = db.collection('probe').doc('queued-write');

    await db.disableNetwork();
    String outcome;
    try {
      // If `await` never returns offline, the timeout distinguishes
      // "hangs (data safely queued, UI spins)" from "queues and returns".
      await ref
          .set({'v': 1, 'at': DateTime.now().toUtc()})
          .timeout(const Duration(seconds: 5));
      outcome = 'AWAIT RETURNED (write acknowledged locally)';
    } on Exception catch (e) {
      outcome = 'AWAIT DID NOT RETURN / threw: ${e.runtimeType}: $e';
    }
    // ignore: avoid_print
    print('PROBE_Q2_SET_OFFLINE :: $outcome');

    // Did the queued write reach the server once back online?
    await db.enableNetwork();
    await Future<void>.delayed(const Duration(seconds: 3));
    final server = await ref.get(const GetOptions(source: Source.server));
    // ignore: avoid_print
    print('PROBE_Q2_AFTER_RECONNECT :: exists=${server.exists} '
        'data=${server.data()}');
  });

  test('Q3: the REAL shape — get() then set(), exactly as the app does',
      () async {
    // This mirrors recordCompletionIfAbsent verbatim: read to decide isNew,
    // then write. If Q1 throws, this whole path fails offline and marking a
    // completion on a bus is impossible.
    final ref = db.collection('probe').doc('completion-shape');

    await db.disableNetwork();
    String outcome;
    try {
      final snap = await ref.get();
      if (!snap.exists) {
        await ref
            .set({'marked': true}, SetOptions(merge: true))
            .timeout(const Duration(seconds: 5));
        outcome = 'FULL PATH SUCCEEDED offline (exists=false then set queued)';
      } else {
        outcome = 'doc already existed; inconclusive';
      }
    } catch (e) {
      outcome = 'FULL PATH FAILED offline: ${e.runtimeType}: $e';
    } finally {
      await db.enableNetwork();
    }
    // ignore: avoid_print
    print('PROBE_Q3_COMPLETION_PATH_OFFLINE :: $outcome');
  });
// Q4: the FIXED shape — unavailable-tolerant get, bounded set.
  test('Q4: FIXED shape — tolerate unavailable, bounded set', () async {
    final ref = db.collection('probe').doc('fixed-shape-${DateTime.now().microsecondsSinceEpoch}');
    await db.disableNetwork();
    String outcome;
    try {
      var exists = false;
      try {
        final snap = await ref.get();
        exists = snap.exists;
      } on FirebaseException catch (e) {
        if (e.code != 'unavailable') rethrow;
        exists = false;
      }
      if (!exists) {
        await ref
            .set({'marked': true}, SetOptions(merge: true))
            .timeout(const Duration(seconds: 3), onTimeout: () {});
      }
      outcome = 'FIXED PATH SUCCEEDED offline';
    } catch (e) {
      outcome = 'FIXED PATH FAILED offline: ${e.runtimeType}: $e';
    }
    // ignore: avoid_print
    print('PROBE_Q4_FIXED_PATH_OFFLINE :: $outcome');
    await db.enableNetwork();
    await Future<void>.delayed(const Duration(seconds: 3));
    final server = await ref.get(const GetOptions(source: Source.server));
    // ignore: avoid_print
    print('PROBE_Q4_LANDED_AFTER_RECONNECT :: exists=${server.exists} data=${server.data()}');
  });
}
