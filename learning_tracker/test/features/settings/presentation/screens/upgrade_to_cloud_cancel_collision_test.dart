// Regression test for AN-5: UpgradeToCloudScreen — collision-phase
// "Cancel — keep offline account" button must reset state to _PhaseForm(),
// not _PhaseCollision(), so cancelling actually dismisses the collision UI
// (before the fix it stayed in the collision UI with no observable change).
//
// Root cause: the onCancel callback in _CollisionBlock called
//   setState(() => _phase = const _PhaseCollision())
// which keeps the widget in the collision UI. The fix changes this to
//   setState(() => _phase = const _PhaseForm())
// mirroring _VerificationRequiredBlock.onCancel.
//
// [AUD-t-settings-04] The earlier version of this file pumped a
// hand-written `_CollisionCancelSimulator` state machine that reimplemented
// the phase-transition logic under test rather than exercising the real
// UpgradeToCloudScreen — reverting the AN-5 fix in
// upgrade_to_cloud_screen.dart would NOT have failed that suite, so it
// provided zero regression protection despite its file header claiming
// otherwise (TQ-8).
//
// This version drives the REAL _CollisionBlock inside the REAL
// UpgradeToCloudScreen. _PhaseCollision is normally reached only via a
// caught EmailCollisionException from UpgradeToCloudService. For the
// password-verifying `_submit()` path that requires an argon2id hash check
// that never completes inside flutter_test's fake_async zone (see the
// ARCHITECTURE NOTE at the top of upgrade_to_cloud_screen_l1_test.dart).
// The credential-less path (`_submitNewCredentials`, used by offline-born
// accounts with a synthetic `@offline.local` email) has no such gate — it
// calls AuthRepository.createUserAccount() directly — so mocking that call
// to throw an `[firebase_auth/email-already-in-use]`-shaped exception drives
// the screen into the real _PhaseCollision without touching argon2id at
// all. This mirrors the working pattern already used by the
// credential-less firebase-error-mapping tests in
// upgrade_to_cloud_screen_l1_test.dart ("UpgradeToCloudScreen —
// credential-less error mapping").

@Tags(['settings', 'upgrade_to_cloud', 'an5'])
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/settings/presentation/screens/upgrade_to_cloud_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockInternetConnectionChecker extends Mock
    implements InternetConnectionChecker {}

// ── Test constants ────────────────────────────────────────────────────────────

const _enteredEmail = 'newowner@example.com';
const _enteredPassword = 'a-strong-password-1';

// A credential-less (offline-born) account: the synthetic @offline.local
// email drives UpgradeToCloudScreen._isCredentialLess, routing submission
// through _submitNewCredentials() — see file header for why this path
// reaches the real _PhaseCollision without the argon2id Isolate limitation.
const AuthState _credentialLessAuth = AuthState.signedIn(
  user: AuthUser(
    profileId: 1,
    email: 'offline_abc123456789@offline.local',
    displayName: 'Tester',
  ),
  tier: Tier.localBorn,
);

// ── Widget factory ────────────────────────────────────────────────────────────

Widget _buildApp({
  required UserDatabase db,
  required DeviceRegistryDatabase registry,
  required _MockAuthRepository authRepo,
  required _MockInternetConnectionChecker checker,
}) {
  return pumpApp(
    overrides: [
      userDatabaseProvider.overrideWithValue(db),
      deviceRegistryProvider.overrideWithValue(registry),
      authRepositoryProvider.overrideWithValue(authRepo),
      authStateProvider.overrideWithValue(_credentialLessAuth),
      internetConnectionCheckerProvider.overrideWithValue(checker),
      syncOrchestratorProvider.overrideWithValue(null),
    ],
    child: const UpgradeToCloudScreen(),
  );
}

/// Seeds the local-born account row the credential-less path looks up by
/// [AuthUser.profileId] (1 — the first row inserted into a fresh in-memory
/// DB gets auto-incremented id 1, matching `_credentialLessAuth`).
Future<void> _seedLocalBornAccount(UserDatabase db) async {
  await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: 'offline_abc123456789@offline.local',
          tier: 'localBorn',
          displayName: 'Tester',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
}

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  late UserDatabase db;
  late DeviceRegistryDatabase registry;
  late _MockAuthRepository authRepo;
  late _MockInternetConnectionChecker checker;

  setUp(() async {
    db = UserDatabase(NativeDatabase.memory());
    registry = DeviceRegistryDatabase(NativeDatabase.memory());
    authRepo = _MockAuthRepository();
    checker = _MockInternetConnectionChecker();

    when(() => checker.hasConnection).thenAnswer((_) async => true);
    when(() => authRepo.currentUser).thenReturn(null);
    when(
      () => authRepo.onAuthStateChanged(),
    ).thenAnswer((_) => const Stream.empty());
    // Drives the real service into throwing EmailCollisionException (see
    // UpgradeToCloudService.upgradeWithNewCredentials's catch block, which
    // maps the '[firebase_auth/email-already-in-use]' code onto it) so the
    // real screen enters the real _PhaseCollision.
    when(() => authRepo.createUserAccount(any(), any())).thenThrow(
      Exception(
        '[firebase_auth/email-already-in-use] The email address is '
        'already in use by another account.',
      ),
    );

    await _seedLocalBornAccount(db);
  });

  tearDown(() async {
    await db.close();
    await registry.close();
  });

  group(
    'AN-5 regression — upgrade_to_cloud collision cancel (real widget)',
    () {
      testWidgets(
        'submitting a colliding email drives the REAL screen into the REAL '
        'collision block',
        (tester) async {
          await tester.pumpWidget(
            _buildApp(
              db: db,
              registry: registry,
              authRepo: authRepo,
              checker: checker,
            ),
          );
          await tester.pump();
          await tester.pump();

          final context = tester.element(find.byType(Scaffold));
          final l10n = AppLocalizations.of(context)!;

          await tester.enterText(
            find.byType(TextFormField).at(0),
            _enteredEmail,
          );
          await tester.enterText(
            find.byType(TextFormField).at(1),
            _enteredPassword,
          );
          await tester.pump();
          await tester.tap(find.byType(FilledButton));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          expect(
            find.text(l10n.upgradeToCloudCollisionTitle),
            findsOneWidget,
            reason:
                'The real UpgradeToCloudScreen must have entered the real '
                '_PhaseCollision — this is the widget under test, not a '
                'simulator',
          );
        },
      );

      testWidgets('AN-5: tapping "Cancel — keep offline account" from the REAL '
          'collision block returns to the REAL form phase', (tester) async {
        await tester.pumpWidget(
          _buildApp(
            db: db,
            registry: registry,
            authRepo: authRepo,
            checker: checker,
          ),
        );
        await tester.pump();
        await tester.pump();

        final context = tester.element(find.byType(Scaffold));
        final l10n = AppLocalizations.of(context)!;

        await tester.enterText(find.byType(TextFormField).at(0), _enteredEmail);
        await tester.enterText(
          find.byType(TextFormField).at(1),
          _enteredPassword,
        );
        await tester.pump();
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Sanity: we are actually in the collision block before cancelling.
        expect(find.text(l10n.upgradeToCloudCollisionTitle), findsOneWidget);

        await tester.tap(find.text(l10n.upgradeToCloudCancelKeepOffline));
        await tester.pump();

        // FIXED (AN-5): cancel dismisses the collision block and the form
        // (email + password fields) is visible again.
        expect(
          find.text(l10n.upgradeToCloudCollisionTitle),
          findsNothing,
          reason: 'Fixed: collision block dismissed by cancel',
        );
        expect(
          find.text(l10n.upgradeToCloudEmailLabel),
          findsOneWidget,
          reason:
              'Fixed: cancel transitions back to the credential-less '
              'form (email field re-appears)',
        );
      });

      testWidgets(
        'AN-5 — l10n cancel label is non-empty (the button is labeled '
        'correctly)',
        (tester) async {
          await tester.pumpWidget(
            _buildApp(
              db: db,
              registry: registry,
              authRepo: authRepo,
              checker: checker,
            ),
          );
          await tester.pump();

          final context = tester.element(find.byType(Scaffold));
          final l10n = AppLocalizations.of(context)!;
          expect(
            l10n.upgradeToCloudCancelKeepOffline.isNotEmpty,
            isTrue,
            reason: 'Cancel button must have a non-empty label',
          );
        },
      );
    },
  );
}
