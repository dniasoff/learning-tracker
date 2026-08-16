// Unit tests for ProfileGuard — all routing branches (S6).
//
// Branch 1: tutored session active → resolver.next() (short-circuit, skip
//           all own-profile checks regardless of own-profile count).
// Branch 2: count==0 own profiles, no tutored session → resolver.next()
//           (allow into AppShell). The shell detects the empty-profile state
//           and jumps to the Settings tab, where a tutor-only adult sees
//           their grants (TALMID PROFILES) and a first-run user can add a
//           profile. We never replace() to the picker or call next(false)
//           here.
// Branch 3: a selected id that no longer exists in the account's profile
//           list is re-resolved rather than trusted blindly.
// Branch 4: count==1 own profile → auto-select + resolver.next().
// Branch 5: count>=2 own profiles, none selected → redirect to picker.
// Branch 6: a valid already-selected profile short-circuits.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:mocktail/mocktail.dart';

class MockNavigationResolver extends Mock implements NavigationResolver {}

class MockStackRouter extends Mock implements StackRouter {}

// Registers fake values for auto_route's PageRouteInfo types so that
// verify() matcher captures them without a registerFallbackValue error.
class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

final _epoch = DateTime.utc(2026, 1, 1);

LearnerProfileEntity _ownProfile(String profileId) {
  return LearnerProfileEntity(
    profileId: profileId,
    displayName: 'Own Learner',
    mode: ProfileMode.adult,
    createdAt: _epoch,
    updatedAt: _epoch,
  );
}

void main() {
  late MockNavigationResolver resolver;
  late MockStackRouter router;

  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  setUp(() {
    resolver = MockNavigationResolver();
    router = MockStackRouter();
    when(() => resolver.isResolved).thenReturn(false);
    when(() => router.replace(any())).thenAnswer((_) async => null);
  });

  // ── Branch 1: tutored session active ──────────────────────────────────────

  group('tutored session active', () {
    ProfileGuard makeGuard({
      required String? selectedId,
      List<LearnerProfileEntity> profiles = const [],
    }) => ProfileGuard(
      profilePickerRoute: () => _FakePageRouteInfo(),
      getProfiles: () async => profiles,
      getSelectedProfileId: () => selectedId,
      setSelectedProfileId: (_) {},
      isTutoredSession: () => true,
    );

    test('allows through when account has zero own profiles', () async {
      // Profile-less tutor: no own profiles, tutored session active.
      final guard = makeGuard(selectedId: null);

      await guard.onNavigation(resolver, router);

      // Must call next() with no argument (or true) — never next(false).
      verify(() => resolver.next()).called(1);
      verifyNever(() => resolver.next(false));
      verifyNever(() => router.replace(any()));
    });

    test('allows through when account has own profiles', () async {
      final profile = _ownProfile('profile-1');
      final guard = makeGuard(
        selectedId: profile.profileId,
        profiles: [profile],
      );

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
      getProfiles: () async => const [],
      getSelectedProfileId: () => null,
      setSelectedProfileId: (_) {},
      isTutoredSession: () => false,
    );

    test(
      'allows into AppShell (shell jumps to Settings) — not the picker',
      () async {
        // Genuine new user: no profiles, no tutored session. ProfileGuard
        // lets them into AppShell; the shell jumps to the Settings tab so
        // they can manage their account / add a profile. No picker redirect.
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
      // TALMID PROFILES section lets them accept/enter without first
      // creating a learner profile.
      final guard = makeGuard();

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next()).called(1);
      verifyNever(() => resolver.next(false));
      verifyNever(() => router.replace(any()));
    });
  });

  // ── Branch 3: stale selected id, re-resolves ─────────────────────────────

  group('selected id no longer exists in the profile list', () {
    test(
      'falls through to re-resolution instead of trusting the stale id',
      () async {
        // The stale id belonged to a profile that no longer exists (e.g. an
        // account switch left selectedProfileIdProvider — keepAlive —
        // pointing at the previous account's profile). With exactly one
        // real profile left, the guard should fall through to the
        // auto-select branch rather than short-circuiting on the stale id.
        final profile = _ownProfile('current-profile');
        final selectedIds = <String>[];
        final guard = ProfileGuard(
          profilePickerRoute: () => _FakePageRouteInfo(),
          getProfiles: () async => [profile],
          getSelectedProfileId: () => 'stale-profile-id',
          setSelectedProfileId: selectedIds.add,
          isTutoredSession: () => false,
        );

        await guard.onNavigation(resolver, router);

        expect(selectedIds, [profile.profileId]);
        verify(() => resolver.next()).called(1);
        verifyNever(() => resolver.next(false));
        verifyNever(() => router.replace(any()));
      },
    );
  });

  // ── Branch 4: count>=1 own profiles, exactly one ─────────────────────────

  group('one own profile, not tutored', () {
    test('auto-selects single profile and calls resolver.next()', () async {
      final profile = _ownProfile('profile-1');
      final selectedIds = <String>[];
      final guard = ProfileGuard(
        profilePickerRoute: () => _FakePageRouteInfo(),
        getProfiles: () async => [profile],
        getSelectedProfileId: () => null,
        setSelectedProfileId: selectedIds.add,
        isTutoredSession: () => false,
      );

      await guard.onNavigation(resolver, router);

      expect(selectedIds, [profile.profileId]);
      verify(() => resolver.next()).called(1);
      verifyNever(() => resolver.next(false));
      verifyNever(() => router.replace(any()));
    });
  });

  // ── Branch 5: 2+ profiles, none selected → redirect to picker ─────────────

  group('2+ own profiles, none selected', () {
    test('AUD-core-navigation-01: replaces with exactly the route returned by '
        'the injected profilePickerRoute builder, not a route the guard '
        'builds itself', () async {
      // Regression for the app→core→app import cycle: ProfileGuard used
      // to hardcode `const ProfilePickerRoute()` internally (importing the
      // app-layer route class directly). Prove the redirect route is now
      // fully caller-controlled by injecting a distinctive marker route
      // that the guard could not possibly have constructed on its own.
      final guard = ProfileGuard(
        profilePickerRoute: () =>
            const PageRouteInfo('AUD_CORE_NAV_01_MARKER_ROUTE'),
        getProfiles: () async => [
          _ownProfile('profile-1'),
          _ownProfile('profile-2'),
        ],
        getSelectedProfileId: () => null,
        setSelectedProfileId: (_) {},
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

  // ── Branch 6: already-selected valid profile ─────────────────────────────

  group('valid profile already selected', () {
    test('short-circuits and calls resolver.next()', () async {
      final profile = _ownProfile('profile-1');
      final guard = ProfileGuard(
        profilePickerRoute: () => _FakePageRouteInfo(),
        getProfiles: () async => [profile],
        getSelectedProfileId: () => profile.profileId,
        setSelectedProfileId: (_) {},
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
  // getProfiles can throw — a Firestore read failure, a disposed provider
  // lambda. ProfileGuard is not a security gate (the shell handles the
  // empty-profile state by jumping to Settings), so the guard wraps
  // onNavigation in a try/catch that fails OPEN (next()) rather than leaving
  // navigation hung.
  group('unexpected throw (fail-open, no dead-end)', () {
    test(
      'throwing getProfiles lambda → resolver.next(), allows to shell',
      () async {
        final guard = ProfileGuard(
          profilePickerRoute: () => _FakePageRouteInfo(),
          getProfiles: () async =>
              throw StateError('provider disposed mid-flight'),
          getSelectedProfileId: () => null,
          setSelectedProfileId: (_) {},
          isTutoredSession: () => false,
        );

        await guard.onNavigation(resolver, router);

        verify(() => resolver.next()).called(1);
        verifyNever(() => resolver.next(false));
      },
    );
  });
}
