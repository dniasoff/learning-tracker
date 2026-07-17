// Unit tests for ProfileGuard — three routing branches (S6).
//
// Branch 1: tutored session active → resolver.next() (short-circuit, skip all
//           profile checks regardless of own-profile count).
// Branch 2: count==0 own profiles, no tutored session → resolver.next()
//           (allow into AppShell). The shell detects the empty-profile state
//           and jumps to the Settings tab, where a tutor-only adult sees their
//           grants (TALMID PROFILES) and a first-run user can add a profile.
//           We never replace() to the picker or call next(false) here.
// Branch 3: count≥1 own profiles, one profile → auto-select + resolver.next().
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_database.dart';

class MockNavigationResolver extends Mock implements NavigationResolver {}

class MockStackRouter extends Mock implements StackRouter {}

// Registers fake values for auto_route's PageRouteInfo types so that
// verify() matcher captures them without a registerFallbackValue error.
class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

Future<int> _insertOwnProfile(UserDatabase db, {required int accountId}) {
  return db
      .into(db.learnerProfiles)
      .insert(
        LearnerProfilesCompanion.insert(
          accountId: accountId,
          displayName: 'Own Learner',
          mode: 'adult',
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
    when(() => router.replace(any())).thenAnswer((_) async => null);
  });

  tearDown(() async {
    await db.close();
  });

  // ── Branch 1: tutored session active ────────────────────────────────────────

  group('tutored session active', () {
    ProfileGuard makeGuard({required int? selectedId}) => ProfileGuard(
      profilePickerRoute: () => _FakePageRouteInfo(),
      getDatabase: () => db,
      getSelectedProfileId: () => selectedId,
      setSelectedProfileId: (_) {},
      getAccountId: () => 1,
      isTutoredSession: () => true,
    );

    test('allows through when account has zero own profiles', () async {
      // Profile-less tutor: no own profiles, tutored session active.
      await seedAccount(db);
      final guard = makeGuard(selectedId: null);

      await guard.onNavigation(resolver, router);

      // Must call next() with no argument (or true) — never next(false).
      verify(() => resolver.next()).called(1);
      verifyNever(() => resolver.next(false));
      verifyNever(() => router.replace(any()));
    });

    test('allows through when account has own profiles', () async {
      final accountId = await seedAccount(db);
      final profileId = await _insertOwnProfile(db, accountId: accountId);
      final guard = makeGuard(selectedId: profileId);

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next()).called(1);
      verifyNever(() => resolver.next(false));
      verifyNever(() => router.replace(any()));
    });
  });

  // ── Branch 2: count==0 own profiles, no tutored session ─────────────────────

  group('zero own profiles, not tutored', () {
    ProfileGuard makeGuard() => ProfileGuard(
      profilePickerRoute: () => _FakePageRouteInfo(),
      getDatabase: () => db,
      getSelectedProfileId: () => null,
      setSelectedProfileId: (_) {},
      getAccountId: () => 1,
      isTutoredSession: () => false,
    );

    test(
      'allows into AppShell (shell jumps to Settings) — not the picker',
      () async {
        // Genuine new user: no profiles, no tutored session. ProfileGuard now
        // lets them into AppShell; the shell jumps to the Settings tab so they
        // can manage their account / add a profile. No picker redirect.
        await seedAccount(db);
        final guard = makeGuard();

        await guard.onNavigation(resolver, router);

        verify(() => resolver.next()).called(1);
        verifyNever(() => resolver.next(false));
        verifyNever(() => router.replace(any()));
      },
    );

    test('allows into AppShell — same path for profile-less tutor', () async {
      // Pure tutor: 0 own profiles, tutored session NOT yet active (before
      // they select a talmid). They land in AppShell → Settings, where the
      // TALMID PROFILES section lets them accept/enter without first creating
      // a learner profile.
      await seedAccount(db);
      final guard = makeGuard();

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next()).called(1);
      verifyNever(() => resolver.next(false));
      verifyNever(() => router.replace(any()));
    });
  });

  // ── Branch 3: count≥1 own profiles ──────────────────────────────────────────

  group('one own profile, not tutored', () {
    test('auto-selects single profile and calls resolver.next()', () async {
      final accountId = await seedAccount(db);
      final profileId = await _insertOwnProfile(db, accountId: accountId);

      final selected = <int>[];
      final guard = ProfileGuard(
        profilePickerRoute: () => _FakePageRouteInfo(),
        getDatabase: () => db,
        getSelectedProfileId: () => null,
        setSelectedProfileId: (id) => selected.add(id),
        getAccountId: () => accountId,
        isTutoredSession: () => false,
      );

      await guard.onNavigation(resolver, router);

      expect(selected, [profileId]);
      verify(() => resolver.next()).called(1);
      verifyNever(() => resolver.next(false));
      verifyNever(() => router.replace(any()));
    });
  });

  // ── 2+ profiles, none selected → redirect to picker ───────────────────────

  group('2+ own profiles, none selected', () {
    test('AUD-core-navigation-01: replaces with exactly the route returned by '
        'the injected profilePickerRoute builder, not a route the guard '
        'builds itself', () async {
      // Regression for the app→core→app import cycle: ProfileGuard used
      // to hardcode `const ProfilePickerRoute()` internally (importing the
      // app-layer route class directly). Prove the redirect route is now
      // fully caller-controlled by injecting a distinctive marker route
      // that the guard could not possibly have constructed on its own.
      final accountId = await seedAccount(db);
      await _insertOwnProfile(db, accountId: accountId);
      await _insertOwnProfile(db, accountId: accountId);

      final guard = ProfileGuard(
        profilePickerRoute: () =>
            const PageRouteInfo('AUD_CORE_NAV_01_MARKER_ROUTE'),
        getDatabase: () => db,
        getSelectedProfileId: () => null,
        setSelectedProfileId: (_) {},
        getAccountId: () => accountId,
        isTutoredSession: () => false,
      );

      await guard.onNavigation(resolver, router);

      verify(
        () => router.replace(
          any<PageRouteInfo>(
            that: isA<PageRouteInfo>().having(
              (r) => r.routeName,
              'routeName',
              'AUD_CORE_NAV_01_MARKER_ROUTE',
            ),
          ),
        ),
      ).called(1);
      verify(() => resolver.next(false)).called(1);
      verifyNever(() => resolver.next());
    });
  });

  // ── Branch 4: already-selected valid profile ─────────────────────────────────

  group('valid profile already selected', () {
    test('short-circuits and calls resolver.next()', () async {
      final accountId = await seedAccount(db);
      final profileId = await _insertOwnProfile(db, accountId: accountId);

      final guard = ProfileGuard(
        profilePickerRoute: () => _FakePageRouteInfo(),
        getDatabase: () => db,
        getSelectedProfileId: () => profileId,
        setSelectedProfileId: (_) {},
        getAccountId: () => accountId,
        isTutoredSession: () => false,
      );

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next()).called(1);
      verifyNever(() => resolver.next(false));
      verifyNever(() => router.replace(any()));
    });
  });

  // ── Fail-safe: unexpected throw → fail OPEN (not a gate), no hang ──────────
  //
  // getProfilesByAccount can throw — a corrupt/locked DB, a disposed provider
  // lambda. ProfileGuard is not a security gate (the shell handles the empty-
  // profile state by jumping to Settings), so the guard wraps onNavigation in
  // a try/catch that fails OPEN (next()) rather than leaving navigation hung.
  group('unexpected throw (fail-open, no dead-end)', () {
    test(
      'throwing database lambda → resolver.next(), allows to shell',
      () async {
        when(() => resolver.isResolved).thenReturn(false);
        final guard = ProfileGuard(
          profilePickerRoute: () => _FakePageRouteInfo(),
          getDatabase: () => throw StateError('provider disposed mid-flight'),
          getSelectedProfileId: () => null,
          setSelectedProfileId: (_) {},
          getAccountId: () => 1,
          isTutoredSession: () => false,
        );

        await guard.onNavigation(resolver, router);

        verify(() => resolver.next()).called(1);
        verifyNever(() => resolver.next(false));
      },
    );
  });
}
