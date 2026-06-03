// Overflow guard — ProfileSwitcherSheet (P1, bottom sheet).
//
// Root cause guarded here: in an `isScrollControlled` modal sheet the parent
// imposes no height bound, so the former `mainAxisSize.min` outer Column
// reported its full natural height and the `Flexible(SingleChildScrollView)`
// collapsed — the profiles list and the fixed Account / Add-profile /
// Skip-to-Settings tiles overflowed on short screens, with many profiles, or
// at large text. The fix bounds the sheet to 85% of the screen and scrolls the
// WHOLE body inside that bound.
//
// We pump the real [ProfileSwitcherSheet] across the device/text-scale matrix
// from [expectNoOverflowAcrossDevices] and assert no RenderFlex overflow. The
// hardest case — MANY profiles at 2.0x text on the smallest viewport — is the
// whole point, so we seed eight profiles.

@Tags(['overflow'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_switcher_sheet.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/overflow_harness.dart';

class _MockStackRouter extends Mock implements StackRouter {}

ProfileModel _profile({
  required int id,
  required String name,
  required String mode,
}) => ProfileModel(
  id: id,
  accountId: 1,
  displayName: name,
  mode: mode,
  avatarIndex: 0,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

class _FixedSelectedProfileId extends SelectedProfileId {
  _FixedSelectedProfileId(this._initial);
  final int? _initial;
  @override
  int? build() => _initial;
}

/// Eight profiles with intentionally long names — the worst case for a sheet
/// that lists every profile plus the pinned section chrome.
List<ProfileModel> _manyProfiles() => [
  _profile(id: 1, name: 'Avraham Yitzchak', mode: 'adult'),
  _profile(id: 2, name: 'Batsheva Leah', mode: 'child'),
  _profile(id: 3, name: 'Chananya Mordechai', mode: 'child'),
  _profile(id: 4, name: 'Devorah Rivka', mode: 'child'),
  _profile(id: 5, name: 'Efrayim Shlomo', mode: 'child'),
  _profile(id: 6, name: 'Frumah Gittel', mode: 'child'),
  _profile(id: 7, name: 'Gershon Nachum', mode: 'adult'),
  _profile(id: 8, name: 'Hadassah Miriam', mode: 'child'),
];

/// The sheet renders inside its [ProfileSwitcherSheet] DecoratedBox; the
/// overflow harness wraps it in a Material/MediaQuery host. We provide the
/// providers it watches and keep the talmid section empty so the test isolates
/// the profiles-list + pinned-tile overflow.
Widget _sheet(List<ProfileModel> profiles) {
  return const MediaQuery(
    // The harness already injects size/textScaler; align the sheet to the
    // bottom the way a real modal bottom sheet sits.
    data: MediaQueryData(viewInsets: EdgeInsets.zero),
    child: Align(
      alignment: Alignment.bottomCenter,
      child: ProfileSwitcherSheet(),
    ),
  );
}

void main() {
  final overrides = [
    profileListStreamProvider.overrideWith(
      (ref) => Stream.value(_manyProfiles()),
    ),
    selectedProfileIdProvider.overrideWith(() => _FixedSelectedProfileId(1)),
    authStateProvider.overrideWithValue(
      const AuthState.signedIn(
        user: AuthUser(
          profileId: 1,
          email: 'avraham.yitzchak@example.com',
          displayName: 'Avraham Yitzchak',
        ),
        tier: Tier.localBorn,
      ),
    ),
    // Keep the talmid section hidden so this guard isolates the profiles list.
    incomingTutorGrantsProvider.overrideWith(
      (ref) async => const <TutorGrant>[],
    ),
  ];

  testWidgets(
    'ProfileSwitcherSheet with 8 profiles does not overflow across the device '
    'matrix (incl. small viewport x 2.0 text)',
    (tester) async {
      // The sheet uses StackRouter via context.pushRoute on tap; render-only
      // here, so a mock router satisfies StackRouterScope without taps.
      await expectNoOverflowAcrossDevices(
        tester,
        () => StackRouterScope(
          controller: _MockStackRouter(),
          stateHash: 0,
          child: _sheet(_manyProfiles()),
        ),
        overrides: overrides,
      );
    },
  );

  testWidgets(
    'ProfileSwitcherSheet does not overflow in Hebrew (RTL) with 8 profiles',
    (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        () => StackRouterScope(
          controller: _MockStackRouter(),
          stateHash: 0,
          child: _sheet(_manyProfiles()),
        ),
        overrides: overrides,
        locale: const Locale('he'),
      );
    },
  );
}
