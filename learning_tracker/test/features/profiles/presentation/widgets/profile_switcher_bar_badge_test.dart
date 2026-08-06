// Regression test for AN-3: ProfileSwitcherBar shows CHILD MODE badge on
// parent-elevated sub-routes (parent-management screens) even though the parent
// has authenticated via PIN and is managing the child's settings.
//
// Root cause: the roleBadge computation in ProfileSwitcherBar only checked
// `activeProfile?.profileMode == ProfileMode.child` and emitted
// `profileBadgeChildMode` ("CHILD MODE"), ignoring the
// `parentPinAuthenticatedProfileIdProvider` elevation state.
//
// Fix (AN-3): When `parentPinAuthenticatedProfileId == activeProfileId` AND the
// active profile is a child, the bar must show "PARENT MODE" (profileBadgeParentMode),
// not "CHILD MODE".

@Tags(['needs_flutter', 'account', 'an3'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_shell.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ── Stubs ─────────────────────────────────────────────────────────────────────

class _StubAuthStateNotifier extends AuthStateNotifier {
  _StubAuthStateNotifier(this._initial);
  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

class _StubParentPinNotifier extends ParentPinAuthenticatedProfileId {
  _StubParentPinNotifier(this._value);
  final int? _value;

  @override
  int? build() => _value;
}

class _StubActiveProfileId extends ActiveProfileId {
  _StubActiveProfileId(this._id);
  final int _id;

  @override
  int build() => _id;
}

class _StubActiveTutoredProfileSelection extends ActiveTutoredProfileSelection {
  _StubActiveTutoredProfileSelection(this._value);
  final TutoredProfileSelection? _value;

  @override
  TutoredProfileSelection? build() => _value;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const _kChildProfileId = 42;
const _kAccountId = 1;
final _kNow = DateTime(2024);

ProfileModel _childProfile() => ProfileModel(
  id: _kChildProfileId,
  ulid: 'ulid-$_kChildProfileId',
  accountId: _kAccountId,
  displayName: 'Junior',
  mode: 'child',
  avatarIndex: 0,
  createdAt: _kNow,
  updatedAt: _kNow,
);

ProfileModel _adultProfile() => ProfileModel(
  id: 99,
  ulid: 'ulid-99',
  accountId: _kAccountId,
  displayName: 'Parent',
  mode: 'adult',
  avatarIndex: 0,
  createdAt: _kNow,
  updatedAt: _kNow,
);

const _kLocalAuthState = AuthState.signedIn(
  user: AuthUser(
    profileId: _kChildProfileId,
    email: 'parent@example.test',
    displayName: 'Parent',
  ),
  tier: Tier.localBorn,
);

const _kAdultAuthState = AuthState.signedIn(
  user: AuthUser(
    profileId: 99,
    email: 'parent@example.test',
    displayName: 'Parent',
  ),
  tier: Tier.localBorn,
);

Widget _buildBar({
  required AuthState authState,
  required int activeId,
  required ProfileModel? profile,
  required int? parentAuthedId,
}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _StubAuthStateNotifier(authState)),
      activeProfileIdProvider.overrideWith(
        () => _StubActiveProfileId(activeId),
      ),
      profileListStreamProvider.overrideWith(
        (ref) => Stream.value(profile != null ? [profile] : <ProfileModel>[]),
      ),
      activeProfileProvider.overrideWith((ref) async => profile),
      activeTutoredProfileSelectionProvider.overrideWith(
        () => _StubActiveTutoredProfileSelection(null),
      ),
      parentPinAuthenticatedProfileIdProvider.overrideWith(
        () => _StubParentPinNotifier(parentAuthedId),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ProfileSwitcherBar()),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('ProfileSwitcherBar badge — AN-3 regression', () {
    testWidgets(
      'shows CHILD MODE badge when child profile active and PIN NOT entered',
      (tester) async {
        await tester.pumpWidget(
          _buildBar(
            authState: _kLocalAuthState,
            activeId: _kChildProfileId,
            profile: _childProfile(),
            parentAuthedId: null,
          ),
        );
        await tester.pump();
        expect(
          find.text('CHILD MODE'),
          findsOneWidget,
          reason: 'No PIN elevation → badge must read CHILD MODE',
        );
        expect(
          find.text('PARENT MODE'),
          findsNothing,
          reason: 'PARENT MODE must not appear without elevation',
        );
      },
    );

    testWidgets(
      // AN-3: This test was FAILING before the fix because the bar always showed
      // CHILD MODE for a child profile regardless of PIN elevation.
      'shows PARENT MODE badge when parent PIN elevated for the active child profile (AN-3)',
      (tester) async {
        await tester.pumpWidget(
          _buildBar(
            authState: _kLocalAuthState,
            activeId: _kChildProfileId,
            profile: _childProfile(),
            parentAuthedId: _kChildProfileId, // PIN entered for this child
          ),
        );
        await tester.pump();
        expect(
          find.text('PARENT MODE'),
          findsOneWidget,
          reason:
              'Parent PIN elevated for this child → badge must read PARENT MODE',
        );
        expect(
          find.text('CHILD MODE'),
          findsNothing,
          reason: 'CHILD MODE must not show when parent is elevated',
        );
      },
    );

    testWidgets('shows ADULT MODE badge when adult profile is active', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildBar(
          authState: _kAdultAuthState,
          activeId: 99,
          profile: _adultProfile(),
          parentAuthedId: null,
        ),
      );
      await tester.pump();
      expect(find.text('ADULT MODE'), findsOneWidget);
      expect(find.text('CHILD MODE'), findsNothing);
      expect(find.text('PARENT MODE'), findsNothing);
    });

    testWidgets(
      'parent PIN elevated for a DIFFERENT child does not change this child badge',
      (tester) async {
        // parentAuthedId = 99, but activeProfileId = 42 → no elevation for 42
        await tester.pumpWidget(
          _buildBar(
            authState: _kLocalAuthState,
            activeId: _kChildProfileId,
            profile: _childProfile(),
            parentAuthedId: 99, // Different profile ID
          ),
        );
        await tester.pump();
        expect(
          find.text('CHILD MODE'),
          findsOneWidget,
          reason:
              'PIN was entered for a different profile (99 != 42) → still CHILD MODE',
        );
        expect(find.text('PARENT MODE'), findsNothing);
      },
    );
  });
}
