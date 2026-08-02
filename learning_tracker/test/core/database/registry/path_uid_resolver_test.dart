/// Tests for [PathUidResolver] — Phase 1 Story B (AD-24: persisted path-uid
/// with anon-reset remap).
///
/// AD-24 rule 2 (quoted in `path_uid_resolver.dart`): the Firestore-path uid
/// is a persisted field on the active-account record, never the live
/// `FirebaseAuth.currentUser`, with an explicit remap-on-anon-reset step
/// (AD-19) when the live uid diverges from the persisted one.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/registry/path_uid_resolver.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:talker/talker.dart';

/// Collects all log event strings from a Talker history — mirrors the helper
/// in `seed_manager_test.dart`.
List<String> _loggedEvents(Talker talker) {
  return talker.history
      .map((e) => e.message ?? '')
      .where((m) => m.isNotEmpty)
      .toList();
}

bool _hasEvent(Talker talker, String event) =>
    _loggedEvents(talker).any((msg) => msg.contains(event));

DeviceAccountsCompanion _account({
  required String id,
  String email = 'test@test.local',
  String tier = 'cloudBorn',
  String? firebaseUid,
}) => DeviceAccountsCompanion.insert(
  accountId: id,
  email: email,
  displayName: 'User $id',
  tier: tier,
  firebaseUid: Value(firebaseUid),
  createdAt: DateTime.utc(2026, 1, 1),
  lastUsedAt: DateTime.utc(2026, 1, 1),
  dbFileName: 'user_acc_$id.db',
);

void main() {
  group('PathUidResolver.pathUidFor — round-trip, never live-uid', () {
    test('returns exactly the persisted value, ignoring any live uid the '
        'caller might separately observe', () async {
      final db = DeviceRegistryDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await db.addAccount(_account(id: 'a1', firebaseUid: 'persisted-uid-123'));
      final resolver = PathUidResolver(db);

      // A "live" uid the caller happens to know about is irrelevant —
      // this module has no way to read it and no parameter accepts one
      // here. pathUidFor reads ONLY the persisted record.
      expect(await resolver.pathUidFor('a1'), 'persisted-uid-123');
    });

    test(
      'returns null for a local-born account with no persisted uid yet',
      () async {
        final db = DeviceRegistryDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        await db.addAccount(
          _account(id: 'a1', tier: 'localBorn', firebaseUid: null),
        );
        final resolver = PathUidResolver(db);

        expect(await resolver.pathUidFor('a1'), isNull);
      },
    );

    test(
      'throws UnknownDeviceAccountException for an unregistered account',
      () async {
        final db = DeviceRegistryDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final resolver = PathUidResolver(db);

        expect(
          () => resolver.pathUidFor('nope'),
          throwsA(isA<UnknownDeviceAccountException>()),
        );
      },
    );
  });

  group(
    'PathUidResolver.reconcileLiveUid — initial bind (AD-19 readiness)',
    () {
      test(
        'binds a local-born account\'s first Anonymous Auth uid without it '
        'counting as a remap — the exact case AD-19 Phase 4 will drive',
        () async {
          final db = DeviceRegistryDatabase(NativeDatabase.memory());
          addTearDown(db.close);

          await db.addAccount(
            _account(id: 'a1', tier: 'localBorn', firebaseUid: null),
          );
          final resolver = PathUidResolver(db);

          final result = await resolver.reconcileLiveUid(
            accountId: 'a1',
            liveUid: 'anon-uid-first-bind',
          );

          expect(result.kind, PathUidReconcileKind.initialBind);
          expect(result.isRemap, isFalse);
          expect(result.previousUid, isNull);
          expect(await resolver.pathUidFor('a1'), 'anon-uid-first-bind');

          // No remap breadcrumb — there was no prior tree to strand.
          final account = await db.findById('a1');
          expect(account!.previousFirebaseUid, isNull);
          expect(account.uidRemappedAt, isNull);
        },
      );

      test('binds a cloud-born account\'s uid on first sign-in', () async {
        final db = DeviceRegistryDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        await db.addAccount(_account(id: 'a1', firebaseUid: null));
        final resolver = PathUidResolver(db);

        final result = await resolver.reconcileLiveUid(
          accountId: 'a1',
          liveUid: 'cloud-uid-1',
        );

        expect(result.kind, PathUidReconcileKind.initialBind);
        expect(await resolver.pathUidFor('a1'), 'cloud-uid-1');
      });
    },
  );

  group('PathUidResolver.reconcileLiveUid — already matched (no-op)', () {
    test(
      'does not write when the live uid already matches the persisted one',
      () async {
        final db = DeviceRegistryDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        await db.addAccount(_account(id: 'a1', firebaseUid: 'uid-1'));
        final resolver = PathUidResolver(db);

        final result = await resolver.reconcileLiveUid(
          accountId: 'a1',
          liveUid: 'uid-1',
        );

        expect(result.kind, PathUidReconcileKind.matched);
        expect(result.isRemap, isFalse);

        final account = await db.findById('a1');
        expect(account!.firebaseUid, 'uid-1');
        expect(account.previousFirebaseUid, isNull);
        expect(account.uidRemappedAt, isNull);
      },
    );
  });

  // ─── Red-demo: anon-reset remap (AD-24 / AD-19) ─────────────────────────
  //
  // Simulates the OS clearing app data / an anon session resetting before
  // being linked — the live Firebase Auth uid comes back DIFFERENT from the
  // uid persisted on the account record. Before the remap step, the
  // account's resolved path uid stays pointed at the now-stale uid: any
  // Firestore path built from it addresses a tree the live session can no
  // longer authenticate against (rules require `request.auth.uid == uid`),
  // i.e. an orphaned/unreachable tree. After the remap, the resolver
  // recovers by re-pointing to the new uid and recording the re-home
  // breadcrumb for the downstream Firestore data layer, per AD-24's
  // ratified choice (quoted in `path_uid_resolver.dart`).

  group('PathUidResolver.reconcileLiveUid — red-demo: anon-uid reset', () {
    test('BEFORE reconciliation: the account stays resolved to the stale, '
        'orphaned uid once the live session has reset', () async {
      final db = DeviceRegistryDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await db.addAccount(_account(id: 'a1', firebaseUid: 'anon-old'));
      final resolver = PathUidResolver(db);

      // Simulated anon-reset: the live session now reports a DIFFERENT
      // uid than what's persisted. Nobody has told the resolver yet.
      const liveUidAfterReset = 'anon-new';

      // Without calling reconcileLiveUid, the resolved path uid is still
      // the pre-reset value — a real caller building `users/{uid}/…` from
      // this would address a tree the live session (anon-new) cannot
      // write to.
      expect(await resolver.pathUidFor('a1'), 'anon-old');
      expect(await resolver.pathUidFor('a1'), isNot(liveUidAfterReset));
    });

    test('AFTER reconciliation: the account recovers — path uid re-points to '
        'the new live uid and the old uid is preserved as the re-home '
        'breadcrumb', () async {
      final db = DeviceRegistryDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      // Hermetic clock (TQ-6): pin `uidRemappedAt` to a known instant
      // instead of asserting against the wall clock.
      useLocalDayClock(FakeLocalDayClock(DateTime.utc(2026, 8, 2, 12)));
      addTearDown(resetLocalDayClock);

      await db.addAccount(_account(id: 'a1', firebaseUid: 'anon-old'));
      final resolver = PathUidResolver(db);

      final result = await resolver.reconcileLiveUid(
        accountId: 'a1',
        liveUid: 'anon-new',
      );

      expect(result.kind, PathUidReconcileKind.remapped);
      expect(result.isRemap, isTrue);
      expect(result.previousUid, 'anon-old');
      expect(result.newUid, 'anon-new');

      // Recovered: the resolver now points at the live session's uid.
      expect(await resolver.pathUidFor('a1'), 'anon-new');

      // Re-home breadcrumb persisted for the (out-of-scope) Firestore
      // data layer that will copy users/anon-old/… -> users/anon-new/….
      final account = await db.findById('a1');
      expect(account!.previousFirebaseUid, 'anon-old');
      expect(
        account.uidRemappedAt!.isAtSameMomentAs(DateTime.utc(2026, 8, 2, 12)),
        isTrue,
      );
    });

    test('is idempotent: reconciling twice with the same post-reset uid only '
        'remaps once', () async {
      final db = DeviceRegistryDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await db.addAccount(_account(id: 'a1', firebaseUid: 'anon-old'));
      final resolver = PathUidResolver(db);

      final first = await resolver.reconcileLiveUid(
        accountId: 'a1',
        liveUid: 'anon-new',
      );
      expect(first.kind, PathUidReconcileKind.remapped);

      final beforeSecond = await db.findById('a1');
      final second = await resolver.reconcileLiveUid(
        accountId: 'a1',
        liveUid: 'anon-new',
      );
      final afterSecond = await db.findById('a1');

      expect(second.kind, PathUidReconcileKind.matched);
      expect(
        afterSecond!.uidRemappedAt,
        beforeSecond!.uidRemappedAt,
        reason:
            'a second call with the SAME live uid must not re-stamp '
            'the remap breadcrumb',
      );
      expect(afterSecond.previousFirebaseUid, beforeSecond.previousFirebaseUid);
    });

    test('logs the remap event through AppLogger so a field occurrence is '
        'diagnosable', () async {
      final db = DeviceRegistryDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await db.addAccount(_account(id: 'a1', firebaseUid: 'anon-old'));
      final talker = Talker();
      final logger = AppLogger(talker);
      final resolver = PathUidResolver(db, logger: logger);

      await resolver.reconcileLiveUid(accountId: 'a1', liveUid: 'anon-new');

      expect(_hasEvent(talker, 'registry_path_uid_remapped'), isTrue);
      expect(_hasEvent(talker, 'anon-old'), isTrue);
      expect(_hasEvent(talker, 'anon-new'), isTrue);
    });

    test('logs the initial-bind event through AppLogger too', () async {
      final db = DeviceRegistryDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await db.addAccount(
        _account(id: 'a1', tier: 'localBorn', firebaseUid: null),
      );
      final talker = Talker();
      final logger = AppLogger(talker);
      final resolver = PathUidResolver(db, logger: logger);

      await resolver.reconcileLiveUid(accountId: 'a1', liveUid: 'anon-first');

      expect(_hasEvent(talker, 'registry_path_uid_bound'), isTrue);
    });
  });

  group('PathUidResolver.reconcileLiveUid — error handling', () {
    test(
      'throws UnknownDeviceAccountException for an unregistered account',
      () async {
        final db = DeviceRegistryDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final resolver = PathUidResolver(db);

        expect(
          () => resolver.reconcileLiveUid(accountId: 'nope', liveUid: 'x'),
          throwsA(isA<UnknownDeviceAccountException>()),
        );
      },
    );
  });
}
