// Regression tests for iter9 finding:
// user_profile_header_card.dart:79 — the condition
//   `!authState.isSignedIn || !authState.isLocalBorn`
// incorrectly renders the "Not signed in" placeholder for signed-in
// cloud-born users when user==null (a transient state or edge case).
//
// Expected:
//   • Not signed in          → shows notSignedIn placeholder text
//   • Signed in, local-born  → shows _LocalBornProfileRow (email visible)
//   • Signed in, cloud-born, user==null → MUST NOT show "Not signed in";
//     shows SizedBox.shrink() (empty widget, no misleading label)

@Tags(['settings', 'l10n', 'regression'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/user_profile_header_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

Widget _buildCardWidget({
  required AuthState authState,
  AppUser? firebaseUser,
  Locale locale = const Locale('en'),
}) {
  final auth = _MockAuthRepository();
  when(() => auth.currentUser).thenReturn(firebaseUser);
  final router = _MockStackRouter();
  when(() => router.canPop()).thenReturn(false);
  when(() => router.currentPath).thenReturn('/settings');

  return ProviderScope(
    overrides: [
      authStateProvider.overrideWithValue(authState),
      authRepositoryProvider.overrideWithValue(auth),
      activeProfileIdProvider.overrideWithValue(
        '01ARZ3NDEKTSV4RRFFQ69G5FAV',
      ),
      profileListStreamProvider.overrideWith((_) => Stream.value([])),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: const Scaffold(body: UserProfileHeaderCard(user: null)),
      ),
    ),
  );
}

void main() {
  setUpAll(() => registerFallbackValue(_FakePageRouteInfo()));

  // ────────────────────────────────────────────────────────────────────────────
  // Case 1: Not signed in — placeholder should appear
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('not signed in → shows notSignedIn placeholder text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildCardWidget(authState: const AuthState.signedOut()),
    );
    await tester.pump();

    expect(
      find.text('Not signed in'),
      findsOneWidget,
      reason: 'signed-out state must render the notSignedIn placeholder label',
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Case 2: Signed in, local-born — shows profile row (email visible)
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets(
    'signed in local-born, user==null → shows local-born profile row',
    (tester) async {
      const authUser = AuthUser(
        email: 'local@test.local',
        displayName: 'Local Tester',
        uid: 'local-user',
      );
      await tester.pumpWidget(
        _buildCardWidget(
          authState: const AuthState.signedIn(
            user: authUser,
            tier: Tier.local,
          ),
        ),
      );
      await tester.pump();

      // Must NOT show the "not signed in" placeholder.
      expect(
        find.text('Not signed in'),
        findsNothing,
        reason:
            'local-born signed-in user must not see the notSignedIn placeholder',
      );
      // Email should be visible in the local-born profile row.
      expect(
        find.text('local@test.local'),
        findsOneWidget,
        reason: 'local-born profile row must render the account email',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // Case 3 (regression): Signed in, cloud-born, user==null →
  //   must NOT render "Not signed in" (the iter9 bug)
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets(
    'iter9 regression: signed-in cloud-born, user==null → must NOT show "Not signed in"',
    (tester) async {
      const authUser = AuthUser(
        email: 'cloud@test.cloud',
        displayName: 'Cloud Tester',
        uid: 'cloud-user',
        firebaseUid: 'fb-uid-cloud',
      );
      await tester.pumpWidget(
        _buildCardWidget(
          authState: const AuthState.signedIn(
            user: authUser,
            tier: Tier.cloud,
          ),
          firebaseUser: null, // user param to widget is null (transient)
        ),
      );
      await tester.pump();

      // THE FIX: cloud-born signed-in users must not see "Not signed in".
      expect(
        find.text('Not signed in'),
        findsNothing,
        reason:
            'iter9 regression (DG-HDR-01): cloud-born signed-in user must not '
            'see the misleading "Not signed in" placeholder when user==null',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  // Hebrew locale: not signed in → shows Hebrew placeholder
  testWidgets(
    'Hebrew locale: not signed in → shows Hebrew notSignedIn placeholder',
    (tester) async {
      await tester.pumpWidget(
        _buildCardWidget(
          authState: const AuthState.signedOut(),
          locale: const Locale('he'),
        ),
      );
      await tester.pump();

      // The Hebrew ARB value for notSignedIn is "לא מחוברים".
      expect(
        find.text('לא מחוברים'),
        findsOneWidget,
        reason:
            'Hebrew locale: notSignedIn placeholder must render Hebrew text',
      );
      // English text must be absent.
      expect(
        find.text('Not signed in'),
        findsNothing,
        reason: 'Hebrew locale: English "Not signed in" must be absent',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
