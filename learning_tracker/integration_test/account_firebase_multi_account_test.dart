// Phase 1 Stories D+E — the Phase 1 EXIT verification (file 1 of 3).
//
// This file drives the REAL, unmodified `AccountFirebase` registry (lib/
// data/firestore/account_firebase.dart, Story P1-A) end-to-end on a real
// Android emulator against the Firestore + Auth EMULATORS (learning_
// tracker/firebase.json, reached from an Android emulator/device at
// 10.0.2.2 — same wiring `firestore_multi_app_isolation_test.dart`, Story
// 2.1, already proved works on API 28 + 34). Nothing here is a fake/mock:
// every `resolve`/`dispose` call goes through the actual shipped code.
//
// Covers 2 of the 6 migration-plan Phase 1 Exit-criteria items:
//   1. <=5 named apps create/switch/tear down cleanly with multi-account
//      data; a 6th fails loudly (MaxAccountsReachedException), not a
//      silent eviction.
//   5. Resource sanity (VmRSS + fd counts) across create/switch/dispose
//      cycles — observational evidence, mirroring Story 2.1's harness.
// Items 3 (AD-2 guard) and 4 (no permission-denied flood) live in
// `account_firebase_guard_and_flood_test.dart`; items 2 (offline switch)
// and 6 (red-demo) live in `account_firebase_offline_switch_test.dart`.
//
// **A confirmed environment/tooling defect this file works around — not a
// topology or AccountFirebase defect.** While building this suite, calling
// `FirebaseAuth.useAuthEmulator()` (or issuing a Firestore operation) on
// ANY app immediately after a DIFFERENT app was deleted in the SAME
// process reproducibly throws `_TypeError: type 'String' is not a subtype
// of type 'Map<dynamic, dynamic>?'` inside
// `platformExceptionToFirebaseAuthException` — this is the SAME class of
// Android `firebase_auth`-plugin bug `firestore_multi_app_isolation_test
// .dart` (Story 2.1) already documented and front-loaded its app creation
// to avoid. Independently isolated here via a throwaway probe (see the
// story report, not checked in) with three findings: (a) the bug is
// reproducible on a 2-second settle delay too — not a race, a deterministic
// plugin defect; (b) once it fires, a FOLLOW-UP Firestore operation on a
// DIFFERENT, still-valid app can additionally throw `[cloud_firestore/
// unknown] FirebaseApp was deleted` — a second, more serious symptom of
// the same underlying native app-registry confusion; (c) crucially, PURE
// `AccountFirebase.resolve()`/`dispose()` cycles — the real native
// `Firebase.initializeApp`/`FirebaseApp.delete()` calls, with NO
// `useAuthEmulator`/`useFirestoreEmulator`/Firestore-operation involved —
// are completely unaffected, proven via 10 repeated create/dispose cycles
// with zero errors. The bug lives specifically in firebase_auth/
// cloud_firestore's Android platform-channel handling of emulator-routing
// (and subsequent operations) on a sibling app after another app's
// deletion — third-party plugin code, not `lib/data/firestore/
// account_firebase.dart`, which this story is told not to modify. This
// file's design therefore separates concerns precisely: every assertion
// that needs auth-emulator-routed reads/writes happens BEFORE this file's
// first `dispose()` call; every assertion made AFTER a `dispose()` call
// uses ONLY the pure `resolve()`/`dispose()`/`activeAccountIds` surface
// (proven safe), never `useAuthEmulator`/Firestore operations on the
// post-dispose handle. Where that leaves a gap in ON-DEVICE, real-SDK
// coverage (specifically: proving a POST-dispose re-resolved account gets
// a genuinely NEW Auth identity, not just a new [FirebaseApp] object), the
// gap is filled by `test/data/firestore/account_firebase_test.dart` and
// `account_switch_lifecycle_test.dart` (Story D) — real production code,
// injected SDK entry points, immune to this Android-platform-channel-only
// bug — see this story's final report for the explicit cross-reference.
//
// Scope note (Phase 1 honesty): this exercises the registry directly, NOT
// through the app's UI / a Parent-PIN gate — per the migration plan, Phase
// 1 "ships to users: nothing yet" (no repository reads through the
// registry until Phase 2/3), so there is no UI consumer yet to drive a
// full-app seeded-data pass through. "Multi-account data" here means each
// named app carries its own genuinely distinguishable Firestore document.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart'
    show MaxAccountsReachedException, kMaxDeviceAccounts;
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

/// Points a freshly-[AccountFirebase.resolve]d handle bundle at the
/// emulators. Must be called immediately after `resolve()` returns and
/// before any other Firestore/Auth call on the bundle, and — per this
/// file's header note — must NEVER be called on a handle resolved AFTER
/// this file's first `dispose()` call.
Future<void> _emulatorize(AccountFirebaseHandles handles) async {
  handles.firestore.useFirestoreEmulator(_emulatorHost, _firestorePort);
  await handles.auth.useAuthEmulator(_emulatorHost, _authPort);
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1 exit verification (1/3) — registry boundary/switch + '
      'resource sanity', () {
    testWidgets(
      'Exit criterion 1: <=5 named apps create cleanly with distinguishable '
      'per-account data; a 6th fails loudly (MaxAccountsReachedException), '
      'never a silent eviction; disposing frees the bound back up and '
      'tear-down is real (native app.delete(), verified via object '
      'identity across a dispose+re-resolve cycle)',
      (tester) async {
        _logResourceSnapshot('criterion1-start');
        final registry = AccountFirebase(
          options: _emulatorOptions(),
          enableAppCheck: false,
        );

        // ── Phase A: full auth+Firestore proof for all 5, BEFORE any
        // dispose() in this process (safe — see file header). ──
        final ids = List.generate(kMaxDeviceAccounts, (i) => 'e2e_bound_$i');
        final uids = <String, String>{};
        final firstAppRefs = <String, FirebaseApp>{};

        for (final id in ids) {
          final handles = await registry.resolve(id);
          firstAppRefs[id] = handles.app;
          await _emulatorize(handles);
          final cred = await handles.auth.signInAnonymously();
          uids[id] = cred.user!.uid;
          await handles.firestore
              .doc('users/${uids[id]}/diagnostic_logs/boundary_marker')
              .set({'account': id, 'uid': uids[id]});
        }
        expect(registry.activeAccountIds, ids.toSet());

        // The 6th must fail LOUDLY — pure Dart-side bound check, never
        // reaches Firebase.initializeApp at all (see AccountFirebase.
        // resolve's ordering), so this is unaffected by the plugin bug
        // regardless of process history.
        await expectLater(
          registry.resolve('e2e_bound_6th'),
          throwsA(isA<MaxAccountsReachedException>()),
        );
        expect(
          registry.activeAccountIds,
          ids.toSet(),
          reason:
              'the 5 already-active accounts must be completely untouched '
              'by the failed 6th resolve attempt',
        );
        for (final id in ids) {
          final readBack = await registry.resolve(id); // memoized, no-op
          final doc = await readBack.firestore
              .doc('users/${uids[id]}/diagnostic_logs/boundary_marker')
              .get(const GetOptions(source: Source.cache));
          expect(doc.data()!['account'], id);
        }

        // ── Phase B: real teardown + bound recovery, using ONLY the pure
        // resolve()/dispose() surface from here on (proven safe post-
        // dispose; see file header — no useAuthEmulator/Firestore calls
        // past this point). ──
        await registry.dispose(ids[0]);
        await registry.dispose(ids[1]);
        expect(registry.activeAccountIds, ids.skip(2).toSet());

        // Now under the bound again: the 6th CAN be created for real (a
        // genuine native Firebase.initializeApp call) — proves this is a
        // real, recoverable bound, not a permanent lockout.
        final sixth = await registry.resolve('e2e_bound_6th');
        expect(sixth.app.name, 'account_e2e_bound_6th');
        await registry.dispose('e2e_bound_6th');

        // Re-resolving a disposed account yields a genuinely DIFFERENT
        // native [FirebaseApp] object — not the same cached reference —
        // the on-device, real-SDK proof that dispose() actually released
        // it rather than leaving a stale handle. (The complementary proof
        // that this also carries a genuinely NEW Auth identity is covered
        // by the mocked-but-structurally-faithful
        // `account_firebase_test.dart` unit suite — seeing it on-device
        // too is blocked by the Android plugin bug described in this
        // file's header.)
        final reResolved = await registry.resolve(ids[0]);
        expect(
          identical(reResolved.app, firstAppRefs[ids[0]]),
          isFalse,
          reason:
              'a fresh resolve after dispose must return a genuinely new '
              'native FirebaseApp object, not the stale pre-dispose '
              'reference',
        );

        await registry.dispose(ids[0]);
        for (final id in ids.skip(2)) {
          await registry.dispose(id);
        }
        expect(registry.activeAccountIds, isEmpty);

        _logResourceSnapshot('criterion1-end');
      },
    );

    testWidgets(
      'Exit criterion 5: resource sanity — 20 real native create/dispose '
      'cycles (Firebase.initializeApp/FirebaseApp.delete, the actual '
      "resource-relevant operations for risk-register item (a), 'named-app "
      "teardown leaks native resources -> OOM') produce no OOM / fd "
      'exhaustion / crash (VmRSS + fd counts captured as observational '
      "evidence, matching Story 2.1's harness)",
      (tester) async {
        _logResourceSnapshot('criterion5-start');
        final registry = AccountFirebase(
          options: _emulatorOptions(),
          enableAppCheck: false,
        );
        const cycles = 20;
        for (var i = 0; i < cycles; i++) {
          final id = 'e2e_cycle_${i % kMaxDeviceAccounts}';
          final handles = await registry.resolve(id);
          // The registry's own `.settings` assignment (persistence +
          // bounded cache, AD-18) already spins up the full native
          // Firestore local-persistence engine regardless of which
          // backend it points at — that IS the resource-relevant cost
          // this criterion measures. Emulator routing / sign-in are
          // deliberately NOT exercised here (see file header): they are
          // orthogonal to the resource question and would trip the
          // unrelated Android plugin bug on cycle 2 onward.
          expect(handles.app.name, 'account_$id');
          await registry.dispose(id);
          if (i % 5 == 0) _logResourceSnapshot('criterion5-cycle-$i');
        }
        _logResourceSnapshot('criterion5-end');
        // Reaching this line at all — no OOM kill, no fd-exhaustion crash —
        // IS the binary pass bar (Story 2.1's steer); the numbers logged
        // above are attached evidence only, not a gating assertion.
        expect(registry.activeAccountIds, isEmpty);
      },
    );
  });
}
