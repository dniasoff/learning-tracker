// Regression test for RESTORE-01 (loop-iter1):
//
// RestoreGuard._isNewDevice was never reset after markRestoreComplete(). In a
// multi-account session — User A (cloud, empty DB) completes restore, then
// User B (cloud, DIFFERENT empty DB) switches in — the guard's cached
// `_isNewDevice == false` caused the new-device check to be SKIPPED for
// User B, silently bypassing the DeviceRestoreRoute redirect.
//
// Fix: add resetForNewSession() that sets _isNewDevice = null so the check
// runs fresh for each incoming account.  AccountPickerScreen calls this on
// every account switch (both cloud and local-born paths).
//
// Covered cases:
//   R1 — resetForNewSession() on a guard where markRestoreComplete() was
//         called: next navigation with empty DB + cloud account MUST redirect.
//   R2 — resetForNewSession() on a guard that already cached non-new-device
//         (from a non-empty DB): next navigation with empty DB MUST redirect.
//   R3 — resetForNewSession() on a fresh guard (never ran): behaviour is
//         unchanged (empty DB + cloud → redirect).
//   R4 — markRestoreComplete() after reset MUST re-apply the cached false
//         state, not be broken by the prior reset.

@Tags(['needs_flutter'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/guards/restore_guard.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_database.dart';

class MockNavigationResolver extends Mock implements NavigationResolver {}

class MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

/// Inserts one learner profile (with the owning account row) so the guard sees
/// a non-empty DB and caches `_isNewDevice = false` on first nav.
Future<void> _seedProfile(UserDatabase db) async {
  final accountId = await seedAccount(db);
  await db.into(db.learnerProfiles).insert(
    LearnerProfilesCompanion.insert(
      accountId: accountId,
      displayName: 'Alice',
      mode: 'adult',
      createdAt: DateTimeFactory.nowUtc(),
      updatedAt: DateTimeFactory.nowUtc(),
    ),
  );
}

/// Stub a fresh resolver that silently accepts next() and next(bool).
MockNavigationResolver _resolver() {
  final r = MockNavigationResolver();
  when(() => r.next()).thenReturn(null);
  when(() => r.next(any<bool>())).thenReturn(null);
  return r;
}

void main() {
  setUpAll(() => registerFallbackValue(_FakePageRouteInfo()));

  late UserDatabase db;
  late MockStackRouter router;

  setUp(() {
    db = UserDatabase(NativeDatabase.memory());
    router = MockStackRouter();
    when(
      () => router.replace(any<PageRouteInfo>()),
    ).thenAnswer((_) async => null);
  });

  tearDown(() async {
    await db.close();
  });

  // ── R1: restore complete → reset → new cloud account with empty DB ─────────

  group('R1 — reset after markRestoreComplete re-enables redirect', () {
    test(
      'empty DB + cloud account after reset redirects to DeviceRestoreRoute',
      () async {
        // BEFORE FIX this test would FAIL: the guard would return resolver.next()
        // (short-circuit on _isNewDevice == false) instead of redirecting.
        final guard = RestoreGuard(
          getDatabase: () => db, // empty — simulates a brand-new account DB
          hasCloudAccount: () => true,
        );

        // Simulate User A completing restore.
        guard.markRestoreComplete();
        // Quick sanity: the guard now short-circuits.
        final r0 = _resolver();
        final router0 = MockStackRouter();
        when(() => router0.replace(any<PageRouteInfo>())).thenAnswer(
          (_) async => null,
        );
        await guard.onNavigation(r0, router0);
        verify(() => r0.next()).called(1);
        verifyNever(() => router0.replace(any<PageRouteInfo>()));

        // Account switch to User B — reset the guard.
        guard.resetForNewSession();

        // User B's first navigation with an empty DB MUST redirect.
        final r1 = _resolver();
        await guard.onNavigation(r1, router);

        verify(
          () => router.replace(
            any<PageRouteInfo>(
              that: isA<PageRouteInfo>().having(
                (r) => r.routeName,
                'routeName',
                'DeviceRestoreRoute',
              ),
            ),
          ),
        ).called(1);
        verify(() => r1.next(false)).called(1);
        verifyNever(() => r1.next());
      },
    );
  });

  // ── R2: non-empty DB cached false → reset → empty DB now redirects ─────────

  group('R2 — reset after non-new-device cache re-enables redirect', () {
    test(
      'after caching a non-empty DB result, reset + empty DB redirects',
      () async {
        // Seed a profile so the first nav sees a non-empty DB.
        await _seedProfile(db);

        final guard = RestoreGuard(
          getDatabase: () => db,
          hasCloudAccount: () => true,
        );

        // First nav: non-empty DB, caches _isNewDevice = false.
        final r0 = _resolver();
        final router0 = MockStackRouter();
        when(() => router0.replace(any<PageRouteInfo>())).thenAnswer(
          (_) async => null,
        );
        await guard.onNavigation(r0, router0);
        verify(() => r0.next()).called(1);
        verifyNever(() => router0.replace(any<PageRouteInfo>()));

        // Account switch to a NEW cloud user — empty DB + reset.
        guard.resetForNewSession();
        await db.delete(db.learnerProfiles).go();
        await db.delete(db.accounts).go();

        // Next nav MUST redirect because DB is now empty.
        final r1 = _resolver();
        await guard.onNavigation(r1, router);

        verify(
          () => router.replace(
            any<PageRouteInfo>(
              that: isA<PageRouteInfo>().having(
                (r) => r.routeName,
                'routeName',
                'DeviceRestoreRoute',
              ),
            ),
          ),
        ).called(1);
        verify(() => r1.next(false)).called(1);
        verifyNever(() => r1.next());
      },
    );
  });

  // ── R3: reset on a fresh guard leaves behaviour unchanged ──────────────────

  group('R3 — reset on a fresh (never-run) guard is a no-op', () {
    test(
      'empty DB + cloud account redirects regardless of reset',
      () async {
        final guard = RestoreGuard(
          getDatabase: () => db,
          hasCloudAccount: () => true,
        );
        guard.resetForNewSession(); // no-op on fresh guard

        final r = _resolver();
        await guard.onNavigation(r, router);

        verify(
          () => router.replace(
            any<PageRouteInfo>(
              that: isA<PageRouteInfo>().having(
                (r) => r.routeName,
                'routeName',
                'DeviceRestoreRoute',
              ),
            ),
          ),
        ).called(1);
        verify(() => r.next(false)).called(1);
        verifyNever(() => r.next());
      },
    );
  });

  // ── R4: markRestoreComplete() still works after a prior reset ──────────────

  group('R4 — markRestoreComplete after reset works correctly', () {
    test(
      'reset then markRestoreComplete: subsequent nav passes through',
      () async {
        final guard = RestoreGuard(
          getDatabase: () => db,
          hasCloudAccount: () => true,
        );

        // Simulate a reset (account switch) followed by a restore completion.
        guard.resetForNewSession();
        guard.markRestoreComplete();

        // Nav after restore complete must NOT redirect even with empty DB.
        final r = _resolver();
        await guard.onNavigation(r, router);

        verify(() => r.next()).called(1);
        verifyNever(() => r.next(false));
        verifyNever(() => router.replace(any<PageRouteInfo>()));
      },
    );
  });
}
