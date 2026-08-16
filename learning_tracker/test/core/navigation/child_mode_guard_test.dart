// Unit tests for ChildModeGuard — all routing branches.
//
// Branch 1: profileId == null → resolver.next(false).
// Branch 2: profileId provided but getProfileById resolves null → resolver.next(false).
// Branch 3: profile found, mode == adult → resolver.next(false).
// Branch 4: profile found, mode == child → resolver.next(true).
// Branch 5 (REGRESSION GUARD): unexpected throw → fail CLOSED, no hang.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:mocktail/mocktail.dart';

class MockNavigationResolver extends Mock implements NavigationResolver {}

class MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _epoch = DateTime.utc(2026, 1, 1);

LearnerProfileEntity _profile({
  required String profileId,
  required ProfileMode mode,
}) {
  return LearnerProfileEntity(
    profileId: profileId,
    displayName: 'Test Profile',
    mode: mode,
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
    when(
      () => router.replace(any<PageRouteInfo>()),
    ).thenAnswer((_) async => null);
  });

  // ── Branch 1: null profileId ─────────────────────────────────────────────

  group('null profile id', () {
    test('calls resolver.next(false) — no deadlock', () async {
      final guard = ChildModeGuard(
        getProfileById: (_) async =>
            fail('getProfileById must not be called when profileId is null'),
        getSelectedProfileId: () => null,
      );

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next(false)).called(1);
      verifyNever(() => resolver.next());
      verifyNever(() => router.replace(any<PageRouteInfo>()));
    });
  });

  // ── Branch 2: profileId set but profile not found ─────────────────────────

  group('profile not found', () {
    test('calls resolver.next(false) — no deadlock', () async {
      final guard = ChildModeGuard(
        getProfileById: (_) async => null,
        getSelectedProfileId: () => 'missing-profile',
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
      final profile = _profile(
        profileId: 'profile-adult',
        mode: ProfileMode.adult,
      );
      final guard = ChildModeGuard(
        getProfileById: (id) async => id == profile.profileId ? profile : null,
        getSelectedProfileId: () => profile.profileId,
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
      final profile = _profile(
        profileId: 'profile-child',
        mode: ProfileMode.child,
      );
      final guard = ChildModeGuard(
        getProfileById: (id) async => id == profile.profileId ? profile : null,
        getSelectedProfileId: () => profile.profileId,
      );

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next(true)).called(1);
      verifyNever(() => resolver.next());
      verifyNever(() => resolver.next(false));
      verifyNever(() => router.replace(any<PageRouteInfo>()));
    });

    test(
      'other profiles exist but the selected one is the one checked',
      () async {
        final adult = _profile(
          profileId: 'profile-adult',
          mode: ProfileMode.adult,
        );
        final child = _profile(
          profileId: 'profile-child',
          mode: ProfileMode.child,
        );
        final byId = {adult.profileId: adult, child.profileId: child};

        final guard = ChildModeGuard(
          getProfileById: (id) async => byId[id],
          getSelectedProfileId: () => child.profileId,
        );

        await guard.onNavigation(resolver, router);

        verify(() => resolver.next(true)).called(1);
        verifyNever(() => resolver.next(false));
      },
    );
  });

  // ── Tutored session: resolve the talmid, not selectedProfileId ───────────
  //
  // TUT-02/TUT-06: in a tutored session selectedProfileId stays null while
  // the active profile is the talmid's own (child) profile. The guard must
  // resolve it via getActiveProfileId so the child-mode-gated
  // parent-management routes (ParentSettings/Tracks/PointConfig/...) open
  // for the tutor — who has full parent-equivalent management over the
  // talmid.

  group('tutored session', () {
    test('resolves the active talmid profile (child) → next(true) even when '
        'selectedProfileId is null', () async {
      final talmid = _profile(
        profileId: 'talmid-child',
        mode: ProfileMode.child,
      );

      final guard = ChildModeGuard(
        getProfileById: (id) async => id == talmid.profileId ? talmid : null,
        // Tutor sessions leave selectedProfileId null.
        getSelectedProfileId: () => null,
        getActiveProfileId: () => talmid.profileId,
        isTutoredSession: () => true,
      );

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next(true)).called(1);
      verifyNever(() => resolver.next(false));
    });

    test('tutored adult talmid → next(false)', () async {
      final talmid = _profile(
        profileId: 'talmid-adult',
        mode: ProfileMode.adult,
      );

      final guard = ChildModeGuard(
        getProfileById: (id) async => id == talmid.profileId ? talmid : null,
        getSelectedProfileId: () => null,
        getActiveProfileId: () => talmid.profileId,
        isTutoredSession: () => true,
      );

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next(false)).called(1);
      verifyNever(() => resolver.next(true));
    });

    test(
      'non-tutored session ignores getActiveProfileId, uses selectedProfileId',
      () async {
        final child = _profile(profileId: 'own-child', mode: ProfileMode.child);
        // An adult profile id that must be IGNORED when not tutoring.
        final adult = _profile(profileId: 'own-adult', mode: ProfileMode.adult);
        final byId = {child.profileId: child, adult.profileId: adult};

        final guard = ChildModeGuard(
          getProfileById: (id) async => byId[id],
          getSelectedProfileId: () => child.profileId,
          getActiveProfileId: () => adult.profileId,
          isTutoredSession: () => false,
        );

        await guard.onNavigation(resolver, router);

        verify(() => resolver.next(true)).called(1);
        verifyNever(() => resolver.next(false));
      },
    );
  });

  // ── Branch 5 (REGRESSION GUARD): unexpected throw — fail CLOSED, no hang ──
  //
  // Any throw inside onNavigation (a disposed provider lambda, a Firestore
  // read failure) would previously escape the guard and leave AutoRoute's
  // resolver completer un-completed forever — a permanent navigation hang
  // (lockout) on every child-gated route. The guard wraps the body in a
  // try/catch that fails CLOSED: it logs and calls resolver.next(false) so
  // navigation is cleanly denied instead of hanging.

  group('unexpected throw (fail-closed, no dead-end)', () {
    test(
      'throwing getProfileById lambda → resolver.next(false), no hang',
      () async {
        final guard = ChildModeGuard(
          getProfileById: (_) async =>
              throw StateError('provider disposed mid-flight'),
          getSelectedProfileId: () => 'some-profile',
        );

        // Must NOT throw — the fail-safe wrapper swallows it and fails closed.
        await guard.onNavigation(resolver, router);

        verify(() => resolver.next(false)).called(1);
        verifyNever(() => resolver.next());
        verifyNever(() => router.replace(any<PageRouteInfo>()));
      },
    );
  });
}
