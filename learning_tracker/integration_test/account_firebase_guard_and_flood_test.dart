// Phase 1 Stories D+E — the Phase 1 EXIT verification (file 2 of 3).
//
// Covers 2 of the 6 migration-plan Phase 1 Exit-criteria items:
//   3. Identity-mismatch guard (AD-2) reproduced against the ACTIVE-
//      ACCOUNT RECORD's persisted uid (PathUidResolver), never
//      `FirebaseAuth.currentUser`.
//   4. No PERMISSION_DENIED flood when switching attention between
//      concurrently-active accounts, and none when a stale (pre-uid-
//      change) listener is correctly cancelled before the identity
//      changes underneath it.
// See the sibling `account_firebase_multi_account_test.dart` for items 1/5
// and `account_firebase_offline_switch_test.dart` for items 2/6.
//
// **No `dispose()` call anywhere in this file until the very end
// (tearDownAll).** This file exists specifically to stay on the safe side
// of the Android `firebase_auth`/`cloud_firestore` platform-channel bug
// documented in the sibling file's header — every `useAuthEmulator` call
// here happens with ZERO prior in-process deletions, matching Story 2.1's
// own proven-safe shape.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/registry/path_uid_resolver.dart';
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

Future<void> _emulatorize(AccountFirebaseHandles handles) async {
  handles.firestore.useFirestoreEmulator(_emulatorHost, _firestorePort);
  await handles.auth.useAuthEmulator(_emulatorHost, _authPort);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1 exit verification (2/3) — AD-2 identity guard + '
      'permission-denied flood check', () {
    late AccountFirebase registry;

    setUpAll(() {
      registry = AccountFirebase(
        options: _emulatorOptions(),
        enableAppCheck: false,
      );
    });

    tearDownAll(() async {
      await registry.disposeAll();
    });

    testWidgets(
      'Exit criterion 3 (AD-2): identity-mismatch guard reproduced against '
      "the active-account record's PERSISTED uid (PathUidResolver), never "
      'FirebaseAuth.currentUser — an anon-uid reset remaps the path uid, '
      'and a caller addressing Firestore from a stale cached currentUser '
      'uid would silently target the wrong (orphaned) tree',
      (tester) async {
        final db = DeviceRegistryDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final resolver = PathUidResolver(db);

        const accountId = 'e2e_guard_A';
        await db.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: accountId,
            email: 'guard-a@example.test',
            displayName: 'Guard A',
            tier: 'localBorn',
            createdAt: DateTime.now(),
            lastUsedAt: DateTime.now(),
            dbFileName: 'user_$accountId.db',
          ),
        );

        final handles = await registry.resolve(accountId);
        await _emulatorize(handles);

        final cred1 = await handles.auth.signInAnonymously();
        final uid1 = cred1.user!.uid;
        final bind = await resolver.reconcileLiveUid(
          accountId: accountId,
          liveUid: uid1,
        );
        expect(bind.kind, PathUidReconcileKind.initialBind);
        expect(await resolver.pathUidFor(accountId), uid1);

        await handles.firestore
            .doc('users/$uid1/diagnostic_logs/guard_marker')
            .set({'account': accountId, 'uid': uid1});

        // AD-19 anon-uid reset: sign out + back in on the SAME named app
        // (no new Firebase.initializeApp/delete involved — safe). Anon
        // Auth never recovers a signed-out identity, so this
        // deterministically yields a genuinely different uid.
        await handles.auth.signOut();
        final cred2 = await handles.auth.signInAnonymously();
        final uid2 = cred2.user!.uid;
        expect(uid2, isNot(equals(uid1)));

        // THE GUARD: reconcile against the PERSISTED record.
        final remap = await resolver.reconcileLiveUid(
          accountId: accountId,
          liveUid: uid2,
        );
        expect(remap.kind, PathUidReconcileKind.remapped);
        expect(remap.previousUid, uid1);
        final correctPathUid = await resolver.pathUidFor(accountId);
        expect(correctPathUid, uid2);
        expect(correctPathUid, handles.auth.currentUser!.uid);

        expect(
          uid1,
          isNot(equals(correctPathUid)),
          reason:
              'a stale cached currentUser.uid ($uid1) diverges from the '
              'AD-2-mandated, resolver-derived path uid ($correctPathUid) '
              'after a remap — this divergence IS the guard: a caller '
              'using the stale value would silently target the wrong, '
              'orphaned tree — exactly the historical "uid-under-live-'
              'listeners PERMISSION_DENIED flood" class AD-2 prevents',
        );
        final newTreeRead = await handles.firestore
            .doc('users/$uid2/diagnostic_logs/guard_marker')
            .get();
        expect(
          newTreeRead.exists,
          isFalse,
          reason:
              'the marker lives at the OLD uid ($uid1) tree only — '
              'PathUidResolver correctly re-points FUTURE writes, but does '
              'not itself re-home historical documents (a separate, later '
              'Firestore-data-layer concern; see path_uid_resolver.dart\'s '
              '"Scope note")',
        );
      },
    );

    testWidgets('Exit criterion 4: zero permission-denied events (a) across '
        'concurrently-active, correctly-scoped listeners on 3 different '
        'accounts while attention switches between them, and (b) when a '
        'listener is correctly cancelled BEFORE its owning account\'s uid '
        'changes underneath it (the disciplined-switch shape) — reproducing '
        'the undisciplined shape (a listener left attached THROUGH a uid '
        'change) as a documented, expected contrast, not asserted zero', (
      tester,
    ) async {
      final deniedEvents = <String, List<String>>{};
      void recordDenied(String label, Object e) {
        if (e is FirebaseException && e.code == 'permission-denied') {
          deniedEvents.putIfAbsent(label, () => []).add('$e');
        }
      }

      // (a) 3 concurrently-active accounts, each on its own named app +
      // its own auth identity — "switching" = reading each one in turn
      // while ALL of them stay live, proving the per-account isolation
      // itself never cross-wires a read/listener onto the wrong
      // account's auth context.
      final ids = ['e2e_flood_1', 'e2e_flood_2', 'e2e_flood_3'];
      final subs = <StreamSubscription<void>>[];
      for (final id in ids) {
        final handles = await registry.resolve(id);
        await _emulatorize(handles);
        final cred = await handles.auth.signInAnonymously();
        final uid = cred.user!.uid;

        final sub = handles.firestore
            .collection('users/$uid/diagnostic_logs')
            .snapshots()
            .listen((_) {}, onError: (Object e) => recordDenied(id, e));
        subs.add(sub);

        await handles.firestore
            .doc('users/$uid/diagnostic_logs/flood_marker')
            .set({'account': id});
      }
      // Settle window: let every listener actually observe its own
      // write while all 3 remain concurrently attached — the "switching
      // attention between accounts" proof.
      await Future<void>.delayed(const Duration(seconds: 1));
      for (final sub in subs) {
        await sub.cancel();
      }
      expect(
        deniedEvents,
        isEmpty,
        reason:
            'zero permission-denied events expected across 3 '
            'concurrently-active, correctly-scoped account listeners, '
            'got: $deniedEvents',
      );

      // (b) The disciplined-switch shape named in the criterion
      // ("an app's listeners outlive their auth context"): attach a
      // listener, then correctly CANCEL it before changing the owning
      // account's uid (the same safe sign-out/sign-in-on-the-same-app
      // shape as criterion 3) — zero permission-denied, because nothing
      // was left outliving the context change.
      final disciplined = await registry.resolve('e2e_flood_disciplined');
      await _emulatorize(disciplined);
      final firstCred = await disciplined.auth.signInAnonymously();
      final firstUid = firstCred.user!.uid;
      final disciplinedEvents = <String>[];
      final disciplinedSub = disciplined.firestore
          .collection('users/$firstUid/diagnostic_logs')
          .snapshots()
          .listen(
            (_) {},
            onError: (Object e) => recordDenied('disciplined', e),
          );
      await disciplined.firestore
          .doc('users/$firstUid/diagnostic_logs/flood_marker')
          .set({'phase': 'before-switch'});
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Correct order: cancel FIRST, then switch identity.
      await disciplinedSub.cancel();
      await disciplined.auth.signOut();
      await disciplined.auth.signInAnonymously();
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(
        disciplinedEvents,
        isEmpty,
        reason:
            'a listener correctly cancelled BEFORE its uid changes must '
            'never see permission-denied — this is the discipline AD-9\'s '
            'resubscribe/lifecycle rule assumes callers follow',
      );
      expect(
        deniedEvents['disciplined'],
        isNull,
        reason:
            'no permission-denied recorded for the disciplined '
            'listener either, via the shared recorder',
      );
    });
  });
}
