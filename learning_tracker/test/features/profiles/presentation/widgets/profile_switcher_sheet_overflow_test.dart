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
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_switcher_sheet.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/overflow_harness.dart';

class _MockStackRouter extends Mock implements StackRouter {}

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

class _FixedSelectedProfileId extends SelectedProfileId {
  _FixedSelectedProfileId(this._initial);
  final String? _initial;
  @override
  String? build() => _initial;
}

/// Eight profiles with intentionally long names — the worst case for a sheet
/// that lists every profile plus the pinned section chrome.
List<LearnerProfileEntity> _manyProfiles() => [
  _profile(
    profileId: 'ulid-1',
    name: 'Avraham Yitzchak',
    mode: ProfileMode.adult,
  ),
  _profile(profileId: 'ulid-2', name: 'Batsheva Leah', mode: ProfileMode.child),
  _profile(
    profileId: 'ulid-3',
    name: 'Chananya Mordechai',
    mode: ProfileMode.child,
  ),
  _profile(profileId: 'ulid-4', name: 'Devorah Rivka', mode: ProfileMode.child),
  _profile(
    profileId: 'ulid-5',
    name: 'Efrayim Shlomo',
    mode: ProfileMode.child,
  ),
  _profile(profileId: 'ulid-6', name: 'Frumah Gittel', mode: ProfileMode.child),
  _profile(
    profileId: 'ulid-7',
    name: 'Gershon Nachum',
    mode: ProfileMode.adult,
  ),
  _profile(
    profileId: 'ulid-8',
    name: 'Hadassah Miriam',
    mode: ProfileMode.child,
  ),
];

/// The sheet renders inside its [ProfileSwitcherSheet] DecoratedBox; the
/// overflow harness wraps it in a Material/MediaQuery host. We provide the
/// providers it watches and keep the talmid section empty so the test isolates
/// the profiles-list + pinned-tile overflow.
Widget _sheet(List<LearnerProfileEntity> profiles) {
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
    selectedProfileIdProvider.overrideWith(
      () => _FixedSelectedProfileId('ulid-1'),
    ),
    authStateProvider.overrideWithValue(
      const AuthState.signedIn(
        user: AuthUser(
          uid: 'account-1',
          email: 'avraham.yitzchak@example.com',
          displayName: 'Avraham Yitzchak',
        ),
        tier: Tier.local,
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
