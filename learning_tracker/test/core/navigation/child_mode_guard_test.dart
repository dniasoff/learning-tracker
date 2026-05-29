// Unit tests for ChildModeGuard — all routing branches.
//
// Branch 1: profileId == null → resolver.next(false).
// Branch 2: profileId provided but profile not found in DB → resolver.next(false).
// Branch 3: profile found, mode == 'adult' → resolver.next(false).
// Branch 4: profile found, mode == 'child' → resolver.next(true).
// Branch 5 (BUG): profile found, mode is unknown storage key → fromStorageKey
//             throws ArgumentError; onNavigation propagates the exception
//             without calling next() or replace() — navigation dead-end.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_database.dart';

class MockNavigationResolver extends Mock implements NavigationResolver {}

class MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Seeds an account + profile with [mode] into [db]; returns the profile id.
Future<int> _insertProfileWithMode(
  UserDatabase db, {
  required int accountId,
  required String mode,
}) {
  return db
      .into(db.learnerProfiles)
      .insert(
        LearnerProfilesCompanion.insert(
          accountId: accountId,
          displayName: 'Test Child',
          mode: mode,
          createdAt: DateTimeFactory.nowUtc(),
          updatedAt: DateTimeFactory.nowUtc(),
        ),
      );
}

void main() {
  late UserDatabase db;
  late MockNavigationResolver resolver;
  late MockStackRouter router;

  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  setUp(() async {
    db = createTestDatabase();
    resolver = MockNavigationResolver();
    router = MockStackRouter();
    when(() => resolver.isResolved).thenReturn(false);
    when(
      () => router.replace(any<PageRouteInfo>()),
    ).thenAnswer((_) async => null);
  });

  tearDown(() async {
    await db.close();
  });

  // ── Branch 1: null profileId ─────────────────────────────────────────────

  group('null profile id', () {
    test('calls resolver.next(false) — no deadlock', () async {
      final guard = ChildModeGuard(
        getDatabase: () => db,
        getSelectedProfileId: () => null,
      );

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next(false)).called(1);
      verifyNever(() => resolver.next());
      verifyNever(() => router.replace(any<PageRouteInfo>()));
    });
  });

  // ── Branch 2: profileId set but profile missing from DB ──────────────────

  group('profile not in database', () {
    test('calls resolver.next(false) — no deadlock', () async {
      // Seed an account so the DB is in a valid state; profileId 9999 is never
      // inserted.
      await seedAccount(db);
      final guard = ChildModeGuard(
        getDatabase: () => db,
        getSelectedProfileId: () => 9999,
      );

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next(false)).called(1);
      verifyNever(() => resolver.next());
      verifyNever(() => router.replace(any<PageRouteInfo>()));
    });
  });

  // ── Branch 3: adult profile ───────────────────────────────────────────────

  group('adult profile selected', () {
    test('calls resolver.next(false) — blocks child-only routes', () async {
      final accountId = await seedAccount(db);
      final profileId = await _insertProfileWithMode(
        db,
        accountId: accountId,
        mode: 'adult',
      );

      final guard = ChildModeGuard(
        getDatabase: () => db,
        getSelectedProfileId: () => profileId,
      );

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next(false)).called(1);
      verifyNever(() => resolver.next());
      verifyNever(() => router.replace(any<PageRouteInfo>()));
    });
  });

  // ── Branch 4: child profile ───────────────────────────────────────────────

  group('child profile selected', () {
    test('calls resolver.next(true) — allows child-only routes', () async {
      final accountId = await seedAccount(db);
      final profileId = await _insertProfileWithMode(
        db,
        accountId: accountId,
        mode: 'child',
      );

      final guard = ChildModeGuard(
        getDatabase: () => db,
        getSelectedProfileId: () => profileId,
      );

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next(true)).called(1);
      verifyNever(() => resolver.next());
      verifyNever(() => resolver.next(false));
      verifyNever(() => router.replace(any<PageRouteInfo>()));
    });

    test('seedProfileWithIds helper — explicit ids work as expected', () async {
      await seedProfileWithIds(db, accountId: 1, profileId: 42, mode: 'child');

      final guard = ChildModeGuard(
        getDatabase: () => db,
        getSelectedProfileId: () => 42,
      );

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next(true)).called(1);
      verifyNever(() => resolver.next(false));
    });

    test(
      'adult profile in DB but child profile selected — allows through',
      () async {
        final accountId = await seedAccount(db);
        // Insert an adult profile first (should not affect result).
        await _insertProfileWithMode(db, accountId: accountId, mode: 'adult');
        final childId = await _insertProfileWithMode(
          db,
          accountId: accountId,
          mode: 'child',
        );

        final guard = ChildModeGuard(
          getDatabase: () => db,
          getSelectedProfileId: () => childId,
        );

        await guard.onNavigation(resolver, router);

        verify(() => resolver.next(true)).called(1);
        verifyNever(() => resolver.next(false));
      },
    );
  });

  // ── Branch 5 (REGRESSION GUARD): unexpected throw — fail CLOSED, no hang ──
  //
  // Any throw inside onNavigation (a disposed userDatabaseProvider lambda, a DB
  // I/O error, or — in defence-in-depth — ProfileMode.fromStorageKey throwing
  // ArgumentError if a future migration ever adds a mode to the table's CHECK
  // without teaching fromStorageKey about it) would previously escape the guard
  // and leave AutoRoute's resolver completer un-completed forever — a permanent
  // navigation hang (lockout) on every child-gated route. The guard now wraps
  // the body in a try/catch that fails CLOSED: it logs and calls
  // resolver.next(false) so navigation is cleanly denied instead of hanging.
  //
  // NB: a *corrupt mode string* cannot be persisted — the learner_profiles
  // table has a CHECK constraint `mode IN ('adult','child')`, so that specific
  // path is already defended at the DB layer. The reachable throw sources are
  // the provider lambda and DB-read failures, exercised below.

  group('unexpected throw (fail-closed, no dead-end)', () {
    test('throwing database lambda → resolver.next(false), no hang', () async {
      final guard = ChildModeGuard(
        getDatabase: () => throw StateError('provider disposed mid-flight'),
        getSelectedProfileId: () => 1,
      );

      // Must NOT throw — the fail-safe wrapper swallows it and fails closed.
      await guard.onNavigation(resolver, router);

      verify(() => resolver.next(false)).called(1);
      verifyNever(() => resolver.next());
      verifyNever(() => router.replace(any<PageRouteInfo>()));
    });
  });
}
