/// Run-10 P0 CALLER-LEVEL regression — the test the campaign was missing.
///
/// `test/core/navigation/run10_p0_pin_bypass_after_profile_roundtrip_test.dart`
/// pins the [PinGuard] contract (lock() clears the cached scope; the cache
/// still short-circuits without a lock; lock() fires onSessionLocked) but its
/// own header says plainly that it does NOT catch the defect — the bug lived
/// in the CALLER, [ProfileSwitcherSheet]'s private `_switchProfile`, which
/// used to clear only `parentPinAuthenticatedProfileIdProvider` (the banner's
/// reactive flag) instead of calling `pinGuard.lock()`. Reverting the
/// production fix left that file 3/3 green.
///
/// THIS file pumps the real [ProfileSwitcherSheet], taps a non-active profile
/// row (the exact tap that drives `_switchProfile`), and asserts the REAL
/// `routerProvider`'s [PinGuard] got locked. It fails if `_switchProfile`
/// reverts to clearing only the reactive flag, because then nothing would
/// ever call `pinGuard.lock()` and the spy counter would stay at 0.
///
/// Verified both directions, not merely asserted:
///   RED:   reverting `profile_switcher_sheet.dart` to the pre-`e45449ee`
///          `_switchProfile` (the one that cleared only
///          `parentPinAuthenticatedProfileIdProvider.notifier`) makes the
///          `expect(lockedCount, 1)` below fail — `lockedCount` stays 0.
///   GREEN: with `e45449ee` in place, `lockedCount` reaches 1.
@Tags(['profiles', 'an2', 'pin_guard', 'security'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/guards/auth_guard.dart';
import 'package:learning_tracker/app/router/router_provider.dart' as rp;
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/core/navigation/pin_scope.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/switcher_sheet_pin_guard_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_switcher_sheet.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _MockPinService extends Mock implements PinService {}

class _FixedActiveProfileId extends ActiveProfileId {
  _FixedActiveProfileId(this._id);
  final String _id;
  @override
  String build() => _id;
}

class _FixedSelectedProfileId extends SelectedProfileId {
  _FixedSelectedProfileId(this._id);
  final String _id;
  @override
  String? build() => _id;
}

LearnerProfileEntity _profile({
  required String id,
  required String name,
  required ProfileMode mode,
}) => LearnerProfileEntity(
  profileId: id,
  displayName: name,
  mode: mode,
  createdAt: DateTime.utc(2024),
  updatedAt: DateTime.utc(2024),
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  const childId = 'ulid-child';
  const adultId = 'ulid-adult';
  final childProfile = _profile(
    id: childId,
    name: 'Beni',
    mode: ProfileMode.child,
  );
  final adultProfile = _profile(
    id: adultId,
    name: 'Avi',
    mode: ProfileMode.adult,
  );

  testWidgets(
    'P0: tapping a profile row in ProfileSwitcherSheet locks the REAL PinGuard '
    'behind routerProvider — fails if _switchProfile reverts to clearing only '
    'the reactive flag',
    (tester) async {
      // The observable this test asserts on: incremented only by
      // PinGuard.onSessionLocked, which only fires from PinGuard.lock().
      var lockedCount = 0;

      // A real AppRouter, constructed exactly like router_provider.dart's
      // production wiring, so ref.read(routerProvider).pinGuard is the SAME
      // kind of object _switchProfile calls .lock() on in production — only
      // onSessionLocked additionally increments the spy counter.
      final spyRouter = AppRouter(
        authGuard: AuthGuard(),
        profileGuard: ProfileGuard(
          profilePickerRoute: () => const ProfilePickerRoute(),
          getProfiles: () async => [childProfile, adultProfile],
          getSelectedProfileId: () => childId,
          setSelectedProfileId: (_) {},
          isTutoredSession: () => false,
        ),
        childModeGuard: ChildModeGuard(
          getProfileById: (id) async => [
            childProfile,
            adultProfile,
          ].where((p) => p.profileId == id).firstOrNull,
          getSelectedProfileId: () => childId,
        ),
        pinGuard: PinGuard(
          pinSetupRoute: () => const PinFlowSetupRoute(),
          pinService: _MockPinService(),
          promptForPin: () async => true,
          getScope: () => const PinScope.parent(childId),
          onSessionLocked: () => lockedCount++,
        ),
      );
      // Model the exact precondition of the P0: a parent already elevated
      // Parent Mode for this child earlier THIS session, so the guard's
      // cache holds a scope matching childId — the same stale-cache state
      // that, pre-fix, waved a returning child straight into admin controls.
      spyRouter.pinGuard.markAuthenticated(childId);

      // _switchProfile also calls context.router.replaceAll(...) (unawaited).
      // Stub it so the mock StackRouter ancestor doesn't throw on the call.
      final mockStackRouter = _MockStackRouter();
      when(() => mockStackRouter.replaceAll(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        pumpApp(
          overrides: [
            profileListStreamProvider.overrideWith(
              (ref) => Stream.value([childProfile, adultProfile]),
            ),
            activeProfileIdProvider.overrideWith(
              () => _FixedActiveProfileId(childId),
            ),
            selectedProfileIdProvider.overrideWith(
              () => _FixedSelectedProfileId(childId),
            ),
            authStateProvider.overrideWithValue(
              const AuthState.signedIn(
                user: AuthUser(
                  uid: 'uid-run10',
                  email: 'parent@test.com',
                  displayName: 'Parent',
                ),
                tier: Tier.local,
              ),
            ),
            // No PIN dialog intercepts the tap — isolates this test to what
            // _switchProfile itself does, matching how the an2 suite's
            // "guard=false" cases isolate the escalation gate from the
            // action it protects.
            switcherSheetPinGuardRequiredProvider.overrideWith(
              (ref) async => false,
            ),
            rp.routerProvider.overrideWithValue(spyRouter),
          ],
          child: StackRouterScope(
            controller: mockStackRouter,
            stateHash: 0,
            child: const Scaffold(body: ProfileSwitcherSheet()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        lockedCount,
        0,
        reason: 'precondition: nothing has locked the guard until the tap',
      );

      // adultProfile (id=1) is NOT the active profile (childId=2) — tapping
      // its row is the exact "switch profile" tap that drives _switchProfile.
      await tester.tap(find.text(adultProfile.displayName));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        lockedCount,
        1,
        reason:
            'tapping a non-active profile row must lock the REAL PinGuard '
            'behind routerProvider. Run-10 P0: _switchProfile used to clear '
            'only the reactive flag and never touch pinGuard, so a child '
            'returning to a previously-elevated profile could re-enter Parent '
            'Mode with no PIN prompt at all.',
      );
    },
  );
}
