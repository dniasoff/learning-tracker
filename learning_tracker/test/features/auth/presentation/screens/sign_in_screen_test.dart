// Widget tests for SignInScreen connectivity-driven rendering.
//
// Regression coverage for the offline bug cluster:
//   • online  → cloud-blue mode card + tappable "Sign in with Google" button
//   • offline → coral local-warning card + NO Google button
//   • loading (probe in flight) → falls back to offline-until-proven-online,
//     so the cloud card / Google button never flash while the device is
//     genuinely offline.
//
// AUD-t-auth-02: also covers two previously-unverified behaviors on this
// churn-hotspot screen —
//   • Epic 21.7 registry-mode selection: `_effectiveSignInMode` /
//     `_registrySubtitle` must be driven by the debounced device-registry
//     lookup (`_onEmailChanged` → `RegistryMatchKind`), not just by the raw
//     connectivity flag.
//   • AN-11 forgot-password anti-enumeration: `_handleForgotPassword` must
//     show byte-identical snackbar copy whether the reset email send
//     succeeds or throws.
import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/account/presentation/screens/sign_in_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_repositories.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  group('SignInScreen', () {
    setUp(debugResetLastKnownOnline);
    tearDown(debugResetLastKnownOnline);

    Widget buildTestWidget({
      Stream<bool>? connectivity,
      _MockStackRouter? router,
    }) {
      return ProviderScope(
        retry: (_, __) => null,
        overrides: [
          if (connectivity != null)
            connectivityStreamProvider.overrideWith((ref) => connectivity),
        ],
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: router == null
              ? const SignInScreen()
              : StackRouterScope(
                  controller: router,
                  stateHash: 0,
                  child: const SignInScreen(),
                ),
        ),
      );
    }

    testWidgets('Register Here pushes SignupRoute', (tester) async {
      final router = _MockStackRouter();
      final pushedRoutes = <PageRouteInfo>[];

      when(
        () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
      ).thenAnswer((invocation) async {
        pushedRoutes.add(invocation.positionalArguments.first as PageRouteInfo);
        return null;
      });

      await tester.pumpWidget(
        buildTestWidget(connectivity: Stream.value(true), router: router),
      );
      await tester.pump(const Duration(seconds: 2));

      final registerCta = find.textContaining(
        'Register Here',
        findRichText: true,
      );
      await tester.ensureVisible(registerCta);
      await tester.tapOnText(find.textRange.ofSubstring('Register Here'));
      await tester.pump();

      expect(pushedRoutes, hasLength(1));
      expect(pushedRoutes.single, isA<SignupRoute>());
      verifyNever(() => router.replace(any()));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(connectivity: Stream.value(true)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(Scaffold), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('shows email and password fields', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(connectivity: Stream.value(true)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Your Email'), findsOneWidget);
      expect(find.text('Secret Key'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('online: shows Sign In button and Google sign-in option', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(connectivity: Stream.value(true)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('online: shows the cloud (backed-up) mode card', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(connectivity: Stream.value(true)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('offline: hides the Google sign-in button', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(connectivity: Stream.value(false)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(
        find.text('Sign in with Google'),
        findsNothing,
        reason: 'Google sign-in must be hidden offline',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets(
      'offline: shows the inline wifi-off hint (Fix #13 — no email typed)',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(connectivity: Stream.value(false)),
        );
        await tester.pump(const Duration(seconds: 2));

        // Fix #13: When offline and no confirmed local-born account is matched,
        // the screen now shows an inline wifi-off hint instead of the coral
        // "local account only" SignInModeCard. The cloud-blue "backed up" card
        // must still NOT appear.
        expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
        expect(find.byIcon(Icons.cloud_done_rounded), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'loading (probe in flight): defaults to offline — no cloud card, '
      'no Google button (offline-until-proven-online)',
      (tester) async {
        // A never-emitting stream keeps the provider in its loading state so
        // we exercise the orElse fallback. lastKnownOnline defaults to false.
        await tester.pumpWidget(
          buildTestWidget(connectivity: const Stream<bool>.empty()),
        );
        await tester.pump(const Duration(seconds: 2));

        expect(
          find.text('Sign in with Google'),
          findsNothing,
          reason:
              'while the connectivity probe is in flight the screen must not '
              'optimistically render the online (Google) affordance',
        );
        expect(find.byIcon(Icons.cloud_done_rounded), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets('shows password visibility toggle', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(connectivity: Stream.value(true)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── Epic 21.7: registry-mode selection ───────────────────────────────────────
  //
  // `RegistryMatchKind` only has none/cloudBorn/notOnDevice now — the
  // localBorn variant, and the "local mode card" (warning_amber_rounded)
  // it drove, were removed by 91798ab8 (local-born account support deleted
  // entirely; every registry match is treated as cloudBorn or notOnDevice).
  // `_effectiveSignInMode` itself no longer branches on the registry match
  // at all — it is purely `isOnline ? cloud : cloudOffline` — so this group
  // now only covers `_registrySubtitle`'s cloudBorn/notOnDevice branches.
  group('SignInScreen — registry-mode selection (Epic 21.7)', () {
    setUp(debugResetLastKnownOnline);
    tearDown(debugResetLastKnownOnline);

    late DeviceRegistryDatabase registry;

    setUp(() {
      registry = DeviceRegistryDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await registry.close();
    });

    Widget buildRegistryTestWidget({required Stream<bool> connectivity}) {
      return ProviderScope(
        retry: (_, __) => null,
        overrides: [
          connectivityStreamProvider.overrideWith((ref) => connectivity),
          deviceRegistryProvider.overrideWithValue(registry),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SignInScreen(),
        ),
      );
    }

    Future<void> enterEmailAndSettle(WidgetTester tester, String email) async {
      await tester.enterText(find.byType(TextFormField).first, email);
      // Fire the 300ms _onEmailChanged debounce timer, then flush the
      // subsequent async registry lookup + setState.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets(
      'online + email matches a cloudBorn device account: shows the cloud '
      'mode card and the "found on this device (Cloud)" subtitle',
      (tester) async {
        await registry.addAccount(
          DeviceAccountsCompanion.insert(
            accountId: 'acc-cloud',
            email: 'cloud@example.com',
            displayName: 'Cloud User',
            tier: 'cloudBorn',
            firebaseUid: const Value('fb-uid-cloud'),
            dbFileName: 'user_acc_cloud.db',
            createdAt: DateTime.utc(2026, 1, 1),
            lastUsedAt: DateTime.utc(2026, 1, 1),
          ),
        );

        await tester.pumpWidget(
          buildRegistryTestWidget(connectivity: Stream.value(true)),
        );
        await tester.pump(const Duration(seconds: 1));

        await enterEmailAndSettle(tester, 'cloud@example.com');

        expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(
          find.text(l10n.authFoundOnDevice(l10n.authTierCloud)),
          findsOneWidget,
          reason:
              'a cloudBorn registry match must render the found-on-device '
              'subtitle — proves RegistryMatchKind.cloudBorn was set, not '
              'just the default "no match" state',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets('offline + email does NOT match any device account: shows the '
        'wifi-off hint and the "not on this device (offline)" subtitle', (
      tester,
    ) async {
      // No accounts seeded — the debounced lookup resolves to
      // RegistryMatchKind.notOnDevice.
      await tester.pumpWidget(
        buildRegistryTestWidget(connectivity: Stream.value(false)),
      );
      await tester.pump(const Duration(seconds: 1));

      await enterEmailAndSettle(tester, 'nobody@example.com');

      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.byIcon(Icons.cloud_done_rounded), findsNothing);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        find.text(l10n.authNotOnDeviceOffline),
        findsOneWidget,
        reason:
            'an unmatched email while offline must resolve to '
            'RegistryMatchKind.notOnDevice (distinct from the initial '
            '"none" state), surfaced via the not-on-device offline copy',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── AN-11: forgot-password anti-enumeration snackbar parity ─────────────────
  //
  // AUD-t-auth-02: `_handleForgotPassword` deliberately shows the SAME
  // snackbar text whether `sendPasswordResetEmail` resolves or throws, so a
  // failed lookup never confirms/denies that an email address has an
  // account (Firebase's own anti-enumeration recommendation). A reverted
  // `_handleForgotPassword` that surfaces the raw error (or a distinct
  // failure message) makes the second test below fail.
  group('SignInScreen — forgot password (AN-11 snackbar parity)', () {
    setUp(debugResetLastKnownOnline);
    tearDown(debugResetLastKnownOnline);

    late MockAuthRepository mockAuthRepo;

    setUp(() {
      mockAuthRepo = MockAuthRepository();
    });

    Widget buildForgotPasswordTestWidget() {
      return ProviderScope(
        retry: (_, __) => null,
        overrides: [
          connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SignInScreen(),
        ),
      );
    }

    Future<void> tapForgotPassword(WidgetTester tester, String email) async {
      await tester.enterText(find.byType(TextFormField).first, email);
      await tester.pump();

      await tester.tap(find.textContaining('Forgot'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets(
      'reset email SUCCEEDS: shows the generic "reset email sent" snackbar',
      (tester) async {
        when(
          () => mockAuthRepo.sendPasswordResetEmail(any()),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(buildForgotPasswordTestWidget());
        await tester.pump(const Duration(seconds: 1));

        await tapForgotPassword(tester, 'known@example.com');

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(find.text(l10n.signInForgotPasswordSent), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets('reset email THROWS (e.g. user-not-found): shows the IDENTICAL '
        '"reset email sent" snackbar — never reveals whether the account '
        'exists', (tester) async {
      when(
        () => mockAuthRepo.sendPasswordResetEmail(any()),
      ).thenThrow(Exception('[firebase_auth/user-not-found]'));

      await tester.pumpWidget(buildForgotPasswordTestWidget());
      await tester.pump(const Duration(seconds: 1));

      await tapForgotPassword(tester, 'unknown@example.com');

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        find.text(l10n.signInForgotPasswordSent),
        findsOneWidget,
        reason:
            'AN-11 anti-enumeration: the failure path must show the SAME '
            'copy as the success path — any different text here would '
            'leak whether unknown@example.com has an account',
      );
      expect(
        find.text(l10n.signInForgotPasswordNoEmail),
        findsNothing,
        reason:
            'the empty-email validation message must not appear — this '
            'is a THROW from a non-empty email, not the empty-field path',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
