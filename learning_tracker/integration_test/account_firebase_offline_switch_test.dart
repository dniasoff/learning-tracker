// Phase 1 Stories D+E — the Phase 1 EXIT verification (file 3 of 3).
//
// Covers the remaining 2 of the 6 migration-plan Phase 1 Exit-criteria
// items (see the sibling `account_firebase_multi_account_test.dart` for
// items 1/3/4/5 and the file-split rationale):
//   2. Instant offline switch between two previously-synced accounts, with
//      the network disabled — each account still reads its OWN data from
//      its own persistent cache, and cannot see the other's. This is the
//      centrepiece payoff of the whole per-account-named-app decision
//      (AD-1).
//   6. Red-demo for the offline switch (named explicitly in the plan):
//      break the isolation (force both accounts onto one app/cache) and
//      show account B can then see A's data offline — proving item 2's
//      assertion is not vacuous.
//
// Drives the REAL `AccountFirebase` registry (lib/data/firestore/
// account_firebase.dart) against the Firestore + Auth EMULATORS, exactly
// like the sibling file — see that file's header for the shared
// `_emulatorize`/`onSessionCreated` rationale.
//
// **A1 fix (named-app auth).** `AccountFirebase.resolve()` now requires an
// already-authenticated session — account creation below goes through
// `AccountFirebase.createAnonymousAccount()`, with emulator routing
// supplied via the registry's `onSessionCreated` hook (`_emulatorize`)
// rather than a manual post-resolve `signInAnonymously()` call. No
// `dispose()` happens until `tearDownAll`, so this file does not exercise
// the documented Android plugin-bug risk the sibling
// `account_firebase_multi_account_test.dart` now does.
//
// **Methodology note — what "network disabled" means here.** This uses
// `FirebaseFirestore.disableNetwork()`/`enableNetwork()`, the SDK's own
// documented mechanism for exactly this kind of test — NOT a host-level
// `adb shell settings put global airplane_mode_on 1` toggle. Two reasons:
// (1) `disableNetwork()` genuinely severs the Firestore client's ability to
// reach the backend — a `get()` after it can ONLY be satisfied from the
// persistent cache, which is precisely the mechanism AD-1/AD-8 claim
// ("SDK offline queue is the sole durability owner") and precisely what
// this criterion is about; a device-level airplane-mode toggle exercises
// the SAME underlying SDK behavior via a slower, less deterministic path
// (OS-level connectivity teardown + SDK reconnect-detection latency) and
// would require host/device orchestration mid-test (this file runs AS the
// on-device process; the host cannot reliably time an `adb` toggle against
// a specific line of in-process test code). (2) The app's OWN network-
// status UI/detection (AD-11's `connectivityStreamProvider`, backed by
// `connectivity_plus`) is a SEPARATE concern this Phase 1 story does not
// wire the registry into yet (no repository reads through it until Phase
// 2/3) — so there is no app-level "airplane mode" surface for this
// criterion to exercise even if it wanted to. `disableNetwork()` is the
// precise, controllable tool for the actual claim under test: does the
// Firestore CLIENT correctly serve cache-only reads, per account, once it
// cannot reach the backend.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';

const _emulatorHost = '10.0.2.2';
const _firestorePort = 8080;
const _authPort = 9099;

FirebaseOptions _emulatorOptions() => const FirebaseOptions(
  apiKey: 'placeholder-api-key',
  appId: '1:000000000000:android:0000000000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'torah-study-tracker',
);

/// See the sibling file's identical helper doc — the [AccountSessionHook]
/// passed to [AccountFirebase], redirecting a just-created account's
/// Firestore/Auth instances to the emulators before the registry's first
/// sign-in.
Future<void> _emulatorize(
  FirebaseApp app,
  FirebaseFirestore firestore,
  FirebaseAuth auth,
) async {
  firestore.useFirestoreEmulator(_emulatorHost, _firestorePort);
  await auth.useAuthEmulator(_emulatorHost, _authPort);
}

/// Fails loudly, before any Firebase call, if either emulator port is
/// unreachable — an environment problem, not a code regression. See the
/// identical helper in `account_firebase_guard_and_flood_test.dart` for the
/// full rationale.
Future<void> _ensureEmulatorsReachable() async {
  for (final port in [_firestorePort, _authPort]) {
    try {
      final socket = await Socket.connect(
        _emulatorHost,
        port,
      ).timeout(const Duration(seconds: 5));
      await socket.close();
    } catch (e) {
      fail(
        'Cannot reach the Firebase emulator at $_emulatorHost:$port ($e). '
        'This is an ENVIRONMENT problem, not a code regression: start the '
        'Firestore/Auth emulators (`firebase emulators:start`) and confirm '
        'the Android emulator/device has outbound network access (AVDs on '
        'this box have been observed to boot with airplane mode on — clear '
        'it with `adb -s <device> shell settings put global '
        'airplane_mode_on 0`).',
      );
    }
  }
}

void _logResourceSnapshot(String label) {
  try {
    final status = File('/proc/self/status').readAsStringSync();
    final vmRss = RegExp(r'VmRSS:\s*(\d+ kB)').firstMatch(status)?.group(1);
    final fdCount = Directory('/proc/self/fd').listSync().length;
    // ignore: avoid_print
    print('[resource-snapshot:$label] VmRSS=$vmRss openFds=$fdCount');
  } catch (e) {
    // ignore: avoid_print
    print('[resource-snapshot:$label] unavailable: $e');
  }
}

/// A cache-only read that treats "throws" and "returned exists:false" as
/// the same "not present in this cache" outcome — mirrors Story 2.1's
/// documented Android SDK behavior ("Failed to get document from cache"
/// for a cache-only get() on an unknown path).
Future<bool> _cacheHasDoc(FirebaseFirestore firestore, String path) async {
  try {
    final snap = await firestore
        .doc(path)
        .get(const GetOptions(source: Source.cache));
    return snap.exists;
  } catch (_) {
    return false;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1 exit verification (3/3) — instant offline account switch '
      '+ red-demo', () {
    // All contexts (the registry's A/B for the isolation proof, and a raw
    // shared_leaky app for the red-demo) are created together in
    // setUpAll and torn down together in tearDownAll — no interleaved
    // create/dispose mid-file, per Story 2.1's documented Android
    // firebase_auth-plugin workaround (a NEW useAuthEmulator() call made
    // after an EARLIER app in the same process was deleted previously
    // tripped a plugin bug).
    late AccountFirebase registry;
    late AccountFirebaseHandles handlesA;
    late AccountFirebaseHandles handlesB;
    late String uidA;
    late String uidB;

    late FirebaseApp sharedApp;
    late FirebaseFirestore sharedFirestore;
    late FirebaseAuth sharedAuth;

    setUpAll(() async {
      await _ensureEmulatorsReachable();

      registry = AccountFirebase(
        options: _emulatorOptions(),
        enableAppCheck: false,
        onSessionCreated: _emulatorize,
      );

      handlesA = await registry.createAnonymousAccount('e2e_offline_A');
      uidA = handlesA.uid;

      handlesB = await registry.createAnonymousAccount('e2e_offline_B');
      uidB = handlesB.uid;

      sharedApp = await Firebase.initializeApp(
        name: 'e2e_offline_shared_leaky',
        options: _emulatorOptions(),
      );
      sharedFirestore = FirebaseFirestore.instanceFor(app: sharedApp);
      sharedFirestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: 5 * 1024 * 1024,
      );
      sharedFirestore.useFirestoreEmulator(_emulatorHost, _firestorePort);
      sharedAuth = FirebaseAuth.instanceFor(app: sharedApp);
      await sharedAuth.useAuthEmulator(_emulatorHost, _authPort);

      // PRE-SYNC (network ON): each account writes its own marker and
      // round-trips it through the REAL server (not a cache-only local
      // write) so the on-disk persistent cache is genuinely populated with
      // server-confirmed data — "previously-synced accounts".
      await handlesA.firestore
          .doc('users/$uidA/diagnostic_logs/offline_marker')
          .set({'account': 'A', 'uid': uidA});
      await handlesB.firestore
          .doc('users/$uidB/diagnostic_logs/offline_marker')
          .set({'account': 'B', 'uid': uidB});
      final serverA = await handlesA.firestore
          .doc('users/$uidA/diagnostic_logs/offline_marker')
          .get(const GetOptions(source: Source.server));
      final serverB = await handlesB.firestore
          .doc('users/$uidB/diagnostic_logs/offline_marker')
          .get(const GetOptions(source: Source.server));
      expect(serverA.exists, isTrue);
      expect(serverB.exists, isTrue);
    });

    tearDownAll(() async {
      await handlesA.firestore.enableNetwork();
      await handlesB.firestore.enableNetwork();
      await registry.disposeAll();
      await sharedApp.delete();
    });

    testWidgets(
      'Exit criterion 2: with the network DISABLED at the Firestore-client '
      'level, switching between two previously-synced accounts reads '
      "EACH ONE'S OWN data instantly from its own persistent cache, and "
      "cannot see the other's",
      (tester) async {
        _logResourceSnapshot('criterion2-start');

        await handlesA.firestore.disableNetwork();
        await handlesB.firestore.disableNetwork();

        final stopwatch = Stopwatch()..start();
        final readA = await handlesA.firestore
            .doc('users/$uidA/diagnostic_logs/offline_marker')
            .get(const GetOptions(source: Source.cache));
        stopwatch.stop();
        expect(readA.exists, isTrue);
        expect(readA.data()!['account'], 'A');
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(1000),
          reason:
              'a cache-sourced read with the network disabled must not '
              'block on any network attempt — "instant" is the claim',
        );

        // SWITCH: read B's OWN data next, still fully offline.
        final readB = await handlesB.firestore
            .doc('users/$uidB/diagnostic_logs/offline_marker')
            .get(const GetOptions(source: Source.cache));
        expect(readB.exists, isTrue);
        expect(readB.data()!['account'], 'B');

        // ISOLATION while offline: neither account's cache leaks into the
        // other's.
        final aSeesB = await _cacheHasDoc(
          handlesA.firestore,
          'users/$uidB/diagnostic_logs/offline_marker',
        );
        final bSeesA = await _cacheHasDoc(
          handlesB.firestore,
          'users/$uidA/diagnostic_logs/offline_marker',
        );
        expect(
          aSeesB,
          isFalse,
          reason: "account A's cache must NOT contain B's data",
        );
        expect(
          bSeesA,
          isFalse,
          reason: "account B's cache must NOT contain A's data",
        );

        await handlesA.firestore.enableNetwork();
        await handlesB.firestore.enableNetwork();
        _logResourceSnapshot('criterion2-end');
      },
    );

    testWidgets(
      'Exit criterion 6 (red-demo): forcing two logical accounts onto ONE '
      "shared app/cache, offline, lets context 2 see context 1's data — "
      "proving criterion 2's isolation assertion is not vacuous",
      (tester) async {
        final cred1 = await sharedAuth.signInAnonymously();
        final uid1 = cred1.user!.uid;
        final markerPath = 'users/$uid1/diagnostic_logs/offline_marker';
        await sharedFirestore.doc(markerPath).set({'writtenBy': 'context_1'});
        // Round-trip through the server first, mirroring the real
        // assertion's "previously-synced" setup.
        await sharedFirestore
            .doc(markerPath)
            .get(const GetOptions(source: Source.server));

        await sharedAuth.signOut();
        final cred2 = await sharedAuth.signInAnonymously();
        final uid2 = cred2.user!.uid;
        expect(
          uid2,
          isNot(equals(uid1)),
          reason: 'sanity check: context 2 must be a genuinely new identity',
        );

        await sharedFirestore.disableNetwork();

        final leaked = await sharedFirestore
            .doc(markerPath)
            .get(const GetOptions(source: Source.cache));
        expect(
          leaked.exists,
          isTrue,
          reason:
              'RED-DEMO: with one shared app/cache, context 2 (uid $uid2) '
              "CAN see context 1's (uid $uid1) write while offline — this "
              "is the leak criterion 2's real isolation assertion is "
              'designed to catch. Seeing it here confirms that assertion '
              'has teeth.',
        );
        expect(leaked.data()!['writtenBy'], 'context_1');

        await sharedFirestore.enableNetwork();
      },
    );
  });
}
