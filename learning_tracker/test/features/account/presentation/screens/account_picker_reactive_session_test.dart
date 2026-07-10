// Regression test for AUD-account-18 (SM-3):
//
// _AccountTileState.build() computed `hasValidSession` from a one-shot
// `ref.read(authRepositoryProvider).currentUser` snapshot instead of watching
// a reactive source. Because `build()` only re-runs when something the
// widget actually WATCHES changes, the tile's "valid session" vs "sign in
// again" badge could go stale after an auth event that doesn't independently
// invalidate this tile — e.g. the device's single Firebase auth slot getting
// reassigned to a different account by a sibling tile's re-auth flow, or a
// server-side session invalidation (disabled account, revoked token).
//
// Fix: the tile now `ref.watch`es the reactive Firebase auth-state stream
// (`onAuthStateChanged()`) instead of reading the mutable `currentUser`
// getter, so the badge updates as soon as the live session changes —
// without requiring the tile to rebuild for some unrelated reason first.
//
// This test proves the fix: it changes the live Firebase session via a
// StreamController-backed provider override WHILE the picker is mounted,
// with no tap/dismiss/setState on the tile itself, and asserts the badge
// text flips accordingly.

@Tags(['needs_flutter', 'account', 'multi_account'])
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/screens/account_picker_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart'
    show SelectedProfileId, selectedProfileIdProvider;
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

/// AuthStateNotifier that starts at a known state without touching Firebase —
/// this test is only about the tile's OWN reactive read of the live Firebase
/// session, not the app-wide active-profile notifier.
class _StubAuthStateNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState.signedOut();
}

class _StubSelectedProfileId extends SelectedProfileId {
  @override
  int? build() => null;
}

final _kNow = DateTime.utc(2026, 1, 1);
const _targetUid = 'fb-uid-reactive-target';
const _otherUid = 'fb-uid-reactive-other';

AppUser _user(String uid) => AppUser(
  uid: uid,
  email: '$uid@example.test',
  displayName: 'Reactive Cloud',
  emailVerified: true,
  providers: const ['google.com'],
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  testWidgets(
    'live Firebase session change (no tap, no unrelated rebuild) flips the '
    'tile badge from CLOUD ACCOUNT to SIGN IN AGAIN',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final registry = DeviceRegistryDatabase(NativeDatabase.memory());
      final userDb = UserDatabase(NativeDatabase.memory());
      final auth = _MockAuthRepository();
      final router = _MockStackRouter();
      final sessionController = StreamController<AppUser?>.broadcast();
      addTearDown(sessionController.close);

      when(() => auth.currentUser).thenReturn(null);
      when(
        () => auth.onAuthStateChanged(),
      ).thenAnswer((_) => sessionController.stream);
      when(
        () => router.push(any<PageRouteInfo>()),
      ).thenAnswer((_) async => null);
      when(
        () => router.replaceAll(any<List<PageRouteInfo>>()),
      ).thenAnswer((_) async {});

      await registry.addAccount(
        DeviceAccountsCompanion.insert(
          accountId: 'acc-reactive-target',
          email: '$_targetUid@example.test',
          displayName: 'Reactive Cloud',
          tier: 'cloudBorn',
          firebaseUid: const Value(_targetUid),
          dbFileName: 'user_acc_reactive_target.db',
          createdAt: _kNow,
          lastUsedAt: _kNow,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            deviceRegistryProvider.overrideWithValue(registry),
            authRepositoryProvider.overrideWithValue(auth),
            userDatabaseProvider.overrideWith((ref) => userDb),
            syncOrchestratorProvider.overrideWithValue(null),
            authStateProvider.overrideWith(_StubAuthStateNotifier.new),
            selectedProfileIdProvider.overrideWith(
              () => _StubSelectedProfileId(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
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
              child: const AccountPickerScreen(),
            ),
          ),
        ),
      );
      await tester.pump(); // resolve getAllAccounts() FutureBuilder
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Reactive Cloud'), findsOneWidget);

      // First live-session event: matches this tile's account → valid
      // session.
      sessionController.add(_user(_targetUid));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.text('CLOUD ACCOUNT'),
        findsOneWidget,
        reason: 'live session matches the tile — badge should read valid',
      );
      expect(find.text('SIGN IN AGAIN'), findsNothing);

      // The device's single Firebase auth slot gets reassigned to a
      // DIFFERENT identity — e.g. a sibling tile's re-auth flow. Nothing
      // taps, dismisses, or otherwise triggers a rebuild of THIS tile; the
      // only thing that happens is the live session stream emitting a new
      // value.
      sessionController.add(_user(_otherUid));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.text('SIGN IN AGAIN'),
        findsOneWidget,
        reason:
            'AUD-account-18: a ref.read snapshot would freeze at the stale '
            'session and never show this — the badge must react to the live '
            'Firebase auth-state stream without any unrelated rebuild.',
      );
      expect(find.text('CLOUD ACCOUNT'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
      await registry.close();
      await userDb.close();
    },
  );
}
