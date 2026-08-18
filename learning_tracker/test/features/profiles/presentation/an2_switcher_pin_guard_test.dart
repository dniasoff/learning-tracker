/// AN-2 regression test: ProfileSwitcherSheet must gate escalating actions
/// (edit, delete, add profile, switch account, switch to adult profile) behind
/// a Parent PIN challenge when the active profile is a child and a PIN is set.
///
/// Every one of the 5 escalating actions named above has its own testWidgets
/// case below: edit, delete, switch account, add profile, and switch to a
/// non-active adult profile.
///
/// RED → GREEN cycle:
///   RED:  tapping edit/delete/add/switch-account/switch-to-adult while
///         active=child and pinGuardRequired=true fires the action directly —
///         no PIN dialog shown.
///   GREEN: the same taps show the Parent PIN verification dialog first.
@Tags(['profiles', 'an2'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/switcher_sheet_pin_guard_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_switcher_sheet.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

/// Real [PinService] mock — used by the "real guard decision" group below so
/// [switcherSheetPinGuardRequiredProvider] runs UNSTUBBED and its actual call
/// into [PinService.hasProfilePin] can be observed.
class _MockPinService extends Mock implements PinService {}

LearnerProfileEntity _profile({
  required String profileId,
  required String name,
  required ProfileMode mode,
}) => LearnerProfileEntity(
  profileId: profileId,
  displayName: name,
  mode: mode,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

/// Build the sheet with [pinGuardRequired] injected via a provider override
/// so tests can control the guard without touching FlutterSecureStorage.
Widget _buildSheet({
  required List<LearnerProfileEntity> profiles,
  required String activeProfileId,
  required bool pinGuardRequired,
  StackRouter? router,
}) {
  final mockRouter = router ?? _MockStackRouter();
  return pumpApp(
    overrides: [
      profileListStreamProvider.overrideWith((ref) => Stream.value(profiles)),
      selectedProfileIdProvider.overrideWith(
        () => _FixedSelectedProfileId(activeProfileId),
      ),
      authStateProvider.overrideWithValue(
        const AuthState.signedIn(
          user: AuthUser(
            uid: 'account-1',
            email: 'parent@test.com',
            displayName: 'Parent',
          ),
          tier: Tier.local,
        ),
      ),
      // AN-2: inject the guard state directly, bypassing FlutterSecureStorage.
      switcherSheetPinGuardRequiredProvider.overrideWith(
        (ref) async => pinGuardRequired,
      ),
    ],
    child: StackRouterScope(
      controller: mockRouter,
      stateHash: 0,
      child: const Scaffold(body: ProfileSwitcherSheet()),
    ),
  );
}

class _FixedSelectedProfileId extends SelectedProfileId {
  _FixedSelectedProfileId(this._initial);
  final String _initial;
  @override
  String? build() => _initial;
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  // Two profiles: child (ULID ulid-2, active) and adult (ULID ulid-1).
  final childProfile = _profile(
    profileId: 'ulid-2',
    name: 'Beni',
    mode: ProfileMode.child,
  );
  final adultProfile = _profile(
    profileId: 'ulid-1',
    name: 'Avi',
    mode: ProfileMode.adult,
  );
  final profiles = [adultProfile, childProfile];
  const activeChildId = 'ulid-2';

  group('AN-2 PIN guard for escalating actions', () {
    testWidgets(
      'edit button shows Parent PIN dialog when active=child and guard=true',
      (tester) async {
        await tester.pumpWidget(
          _buildSheet(
            profiles: profiles,
            activeProfileId: activeChildId,
            pinGuardRequired: true,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Two edit buttons — one per profile row.
        final editButtons = find.byIcon(Icons.edit_outlined);
        expect(editButtons, findsNWidgets(2));

        // Invoke the callback directly to avoid InkSparkle shader in tests.
        final btn = tester.widget<IconButton>(
          find.ancestor(
            of: editButtons.first,
            matching: find.byType(IconButton),
          ),
        );
        btn.onPressed?.call();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // AN-2 fix: the Parent PIN verification dialog must appear.
        expect(
          find.text('Enter Parent PIN'),
          findsOneWidget,
          reason:
              'AN-2: pressing edit while active=child (PIN guard required) '
              'must show the Parent PIN verification dialog first.',
        );
      },
    );

    testWidgets(
      'delete button shows Parent PIN dialog when active=child and guard=true',
      (tester) async {
        await tester.pumpWidget(
          _buildSheet(
            profiles: profiles,
            activeProfileId: activeChildId,
            pinGuardRequired: true,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final deleteButtons = find.byIcon(Icons.delete_outline_rounded);
        expect(deleteButtons, findsNWidgets(2));

        final btn = tester.widget<IconButton>(
          find.ancestor(
            of: deleteButtons.first,
            matching: find.byType(IconButton),
          ),
        );
        btn.onPressed?.call();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('Enter Parent PIN'),
          findsOneWidget,
          reason:
              'AN-2: pressing delete while active=child (PIN guard required) '
              'must show the Parent PIN verification dialog first.',
        );
      },
    );

    testWidgets(
      'switch account tile shows Parent PIN dialog when active=child and '
      'guard=true',
      (tester) async {
        await tester.pumpWidget(
          _buildSheet(
            profiles: profiles,
            activeProfileId: activeChildId,
            pinGuardRequired: true,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Switch account'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // AN-2 fix: the Parent PIN verification dialog must appear.
        expect(
          find.text('Enter Parent PIN'),
          findsOneWidget,
          reason:
              'AN-2: tapping Switch account while active=child (PIN guard '
              'required) must show the Parent PIN verification dialog first.',
        );
      },
    );

    testWidgets(
      'Add Profile tile shows Parent PIN dialog when active=child and '
      'guard=true',
      (tester) async {
        await tester.pumpWidget(
          _buildSheet(
            profiles: profiles,
            activeProfileId: activeChildId,
            pinGuardRequired: true,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Add Profile'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // AN-2 fix: the Parent PIN verification dialog must appear instead
        // of the Add Profile dialog firing directly.
        expect(
          find.text('Enter Parent PIN'),
          findsOneWidget,
          reason:
              'AN-2: tapping Add Profile while active=child (PIN guard '
              'required) must show the Parent PIN verification dialog first, '
              'not open the create-profile flow directly.',
        );
      },
    );

    testWidgets(
      'switching to a non-active adult profile shows Parent PIN dialog when '
      'active=child and guard=true',
      (tester) async {
        await tester.pumpWidget(
          _buildSheet(
            profiles: profiles,
            activeProfileId: activeChildId,
            pinGuardRequired: true,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // adultProfile (ulid-1) is not the active profile (activeChildId=ulid-2) —
        // tapping its row is the "switch to adult profile" escalating action.
        await tester.tap(find.text(adultProfile.displayName));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // AN-2 fix: the Parent PIN verification dialog must appear instead
        // of switching straight into the adult profile.
        expect(
          find.text('Enter Parent PIN'),
          findsOneWidget,
          reason:
              'AN-2: switching to a non-active adult profile while '
              'active=child (PIN guard required) must show the Parent PIN '
              'verification dialog first.',
        );
      },
    );

    testWidgets(
      'no PIN dialog when guard=false (adult active or no PIN configured)',
      (tester) async {
        // When guard is off, edit fires immediately — no PIN dialog.
        await tester.pumpWidget(
          _buildSheet(
            profiles: profiles,
            activeProfileId: activeChildId,
            pinGuardRequired: false,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final editButtons = find.byIcon(Icons.edit_outlined);
        final btn = tester.widget<IconButton>(
          find.ancestor(
            of: editButtons.first,
            matching: find.byType(IconButton),
          ),
        );
        btn.onPressed?.call();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // No PIN dialog — the edit flow is invoked directly.
        expect(
          find.text('Enter Parent PIN'),
          findsNothing,
          reason:
              'AN-2: when guard is not required, no PIN dialog should appear.',
        );
      },
    );

    /// TEA-009 de-tautologization: the block below used to override
    /// [switcherSheetPinGuardRequiredProvider] itself with a hand-copied
    /// re-implementation of its own logic (including a bare `return true; //
    /// would call hasProfilePin in real code` for the child branch) — a
    /// tautology on a P0 child-privacy path. `container.read(...)` was only
    /// ever proving the TEST'S copy-pasted `if` statement worked, never the
    /// real provider body in
    /// `lib/features/profiles/presentation/providers/switcher_sheet_pin_guard_provider.dart`,
    /// so a real regression there (e.g. deleting the `hasProfilePin` call, or
    /// flipping `!=` to `==`) could ship with this test still green.
    ///
    /// Rewritten to build a REAL [ProviderContainer] with ONLY the guard's
    /// true upstream dependencies overridden ([profileListStreamProvider],
    /// [selectedProfileIdProvider], [pinServiceProvider]) and read
    /// [switcherSheetPinGuardRequiredProvider] completely unstubbed — the
    /// actual production function body runs and its actual decision is
    /// asserted, including verifying [PinService.hasProfilePin] is (or is
    /// not) consulted, exactly as
    /// `switcher_sheet_pin_guard_provider_test.dart` does for the same
    /// provider in isolation.
    group('real guard decision (no test-side re-implementation)', () {
      late _MockPinService pinService;

      setUp(() {
        pinService = _MockPinService();
      });

      Future<ProviderContainer> makeContainer({
        required List<LearnerProfileEntity> profiles,
        required String activeProfileId,
      }) async {
        final container = ProviderContainer(
          overrides: [
            profileListStreamProvider.overrideWith(
              (ref) => Stream.value(profiles),
            ),
            selectedProfileIdProvider.overrideWith(
              () => _FixedSelectedProfileId(activeProfileId),
            ),
            pinServiceProvider.overrideWithValue(pinService),
          ],
        );
        addTearDown(container.dispose);
        // Keep the autoDispose profileListStreamProvider alive across the
        // await below, matching the identical workaround in
        // switcher_sheet_pin_guard_provider_test.dart.
        final sub = container.listen(profileListStreamProvider, (_, _) {});
        addTearDown(sub.close);
        await container.read(profileListStreamProvider.future);
        return container;
      }

      test('returns false for an adult active profile — hasProfilePin never '
          'consulted', () async {
        final container = await makeContainer(
          profiles: [adultProfile],
          activeProfileId: adultProfile.profileId,
        );

        final result = await container.read(
          switcherSheetPinGuardRequiredProvider.future,
        );

        expect(
          result,
          isFalse,
          reason:
              'AN-2: the REAL guard provider must return false for an '
              'adult active profile.',
        );
        verifyNever(() => pinService.hasProfilePin(any()));
      });

      test('returns true for a child active profile with a configured Parent '
          'PIN', () async {
        when(
          () => pinService.hasProfilePin(childProfile.profileId),
        ).thenAnswer((_) async => true);
        final container = await makeContainer(
          profiles: [childProfile],
          activeProfileId: childProfile.profileId,
        );

        final result = await container.read(
          switcherSheetPinGuardRequiredProvider.future,
        );

        expect(
          result,
          isTrue,
          reason:
              'AN-2: the REAL guard provider must return true for a child '
              'active profile with a Parent PIN configured — this is the '
              'exact condition the widget tests above rely on to show the '
              'PIN dialog.',
        );
        verify(
          () => pinService.hasProfilePin(childProfile.profileId),
        ).called(1);
      });

      test('returns false for a child active profile with no Parent PIN '
          'configured', () async {
        when(
          () => pinService.hasProfilePin(childProfile.profileId),
        ).thenAnswer((_) async => false);
        final container = await makeContainer(
          profiles: [childProfile],
          activeProfileId: childProfile.profileId,
        );

        final result = await container.read(
          switcherSheetPinGuardRequiredProvider.future,
        );

        expect(
          result,
          isFalse,
          reason:
              'AN-2: no PIN configured means no escalation guard — the '
              'child can use the switcher sheet unimpeded.',
        );
        verify(
          () => pinService.hasProfilePin(childProfile.profileId),
        ).called(1);
      });
    });
  });
}
