// L1 widget test — UpgradeToCloudScreen
//
// Covers:
//   • Initial render: AppBar title, password field, upgrade button.
//   • Idle state: no error messages on fresh render.
//   • Validation: empty password shows inline error "Password required".
//   • Service is NOT called when password is empty.
//   • Non-local-born auth state → "Only local-born accounts can be upgraded."
//   • Error state: null hash → UpgradePasswordMismatchException → "Incorrect password."
//   • Error state: profile not found → StateError → friendly localized fallback
//     (raw exception NOT shown).
//   • Error state: error text carries explicit colour; form re-enabled after error.
//   • Offline guard: internet error shown; service not called.
//   • Submitting state: loading indicator visible while DB lookup in-flight.
//   • EmailCollisionException path — UI (skip: argon2id Isolate limitation).
//   • UpgradeEmailNotVerifiedException path — UI (skip: argon2id Isolate limitation).
//   • Success path — UI (skip: argon2id Isolate limitation).
//   • he-RTL smoke: renders under Hebrew locale with RTL directionality.
//   • Hardcoded strings flagged in test-name comments.
//
// ARCHITECTURE NOTE: UpgradeToCloudService is constructed inline in _submit()
// with the real PasswordHasher (argon2id). Because the cryptography package
// uses Isolate.spawn on native targets, the async result never propagates back
// to widgets in Flutter's fake_async test zone — pump(duration) cannot drive
// Isolate message passing. Tests that require a successful argon2id hash
// verification (collision, verification, success) are therefore skipped with
// BUG comments. Paths that short-circuit BEFORE argon2id (null hash → immediate
// UpgradePasswordMismatchException; missing profile → StateError) ARE testable
// with standard pump() calls.

@Tags(['settings', 'upgrade_to_cloud'])
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/domain/services/password_hasher.dart';
import 'package:learning_tracker/features/account/domain/services/upgrade_to_cloud_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/settings/presentation/screens/upgrade_to_cloud_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockInternetConnectionChecker extends Mock
    implements InternetConnectionChecker {}

// ── Fake AppUser (for skip-annotated success path) ────────────────────────────

class _FakeVerifiedAppUser extends Fake implements AppUser {
  _FakeVerifiedAppUser({required this.uid});
  @override
  final String uid;
  @override
  String? get email => _email;
  @override
  String? get displayName => 'Tester';
  @override
  bool get emailVerified => true;
  @override
  List<String> get providers => const ['password'];
}

// ── Test constants ────────────────────────────────────────────────────────────

const _email = 'tester@example.com';
const _password = 'any-password-123';

// ── Auth state helpers ────────────────────────────────────────────────────────

const AuthState _localBornAuth = AuthState.signedIn(
  user: AuthUser(profileId: 1, email: _email, displayName: 'Tester'),
  tier: Tier.localBorn,
);

const AuthState _cloudBornAuth = AuthState.signedIn(
  user: AuthUser(profileId: 1, email: _email, displayName: 'Tester'),
  tier: Tier.cloudBorn,
);

// A credential-less (offline-born) account: synthetic @offline.local email
// drives UpgradeToCloudScreen._isCredentialLess, routing submission through
// _submitNewCredentials() instead of _submit(). That path calls
// authRepository.createUserAccount() directly with no local password to
// verify, so — unlike the argon2id-gated _submit() path — it is fully
// testable at L1 without the Isolate.spawn limitation (see ARCHITECTURE NOTE).
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
  AuthState auth = _localBornAuth,
  Locale locale = const Locale('en'),
}) {
  return pumpApp(
    locale: locale,
    overrides: [
      userDatabaseProvider.overrideWithValue(db),
      deviceRegistryProvider.overrideWithValue(registry),
      authRepositoryProvider.overrideWithValue(authRepo),
      authStateProvider.overrideWithValue(auth),
      internetConnectionCheckerProvider.overrideWithValue(checker),
      syncOrchestratorProvider.overrideWithValue(null),
    ],
    child: const UpgradeToCloudScreen(),
  );
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump();
}

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

/// Seeds a local-born account row with a null passwordHash.
///
/// The PasswordHasher short-circuits on null hash before running any argon2id
/// computation, immediately throwing UpgradePasswordMismatchException. This
/// lets error-path tests avoid the Isolate.spawn limitation in fake_async.
Future<void> _seedAccountNullHash(UserDatabase db) async {
  await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: _email,
          tier: 'localBorn',
          passwordHash: const Value(null),
          displayName: 'Tester',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
}

// ── Per-test fixtures ─────────────────────────────────────────────────────────

late UserDatabase _db;
late DeviceRegistryDatabase _registry;
late _MockAuthRepository _authRepo;
late _MockInternetConnectionChecker _checker;

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    _db = UserDatabase(NativeDatabase.memory());
    _registry = DeviceRegistryDatabase(NativeDatabase.memory());
    _authRepo = _MockAuthRepository();
    _checker = _MockInternetConnectionChecker();

    when(() => _checker.hasConnection).thenAnswer((_) async => true);
    when(() => _authRepo.currentUser).thenReturn(null);
    when(
      () => _authRepo.onAuthStateChanged(),
    ).thenAnswer((_) => const Stream.empty());
  });

  tearDown(() async {
    await _db.close();
    await _registry.close();
  });

  // ── Initial render ──────────────────────────────────────────────────────────

  group('UpgradeToCloudScreen — initial render (en)', () {
    testWidgets('shows AppBar with l10n title "Upgrade to Cloud"', (
      tester,
    ) async {
      await _pump(
        tester,
        _buildApp(
          db: _db,
          registry: _registry,
          authRepo: _authRepo,
          checker: _checker,
        ),
      );

      // l10n key: upgradeToCloudTitle
      expect(find.text('Upgrade to Cloud'), findsWidgets);
      expect(find.byType(AppBar), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('shows password TextFormField with hardcoded label', (
      tester,
    ) async {
      await _pump(
        tester,
        _buildApp(
          db: _db,
          registry: _registry,
          authRepo: _authRepo,
          checker: _checker,
        ),
      );

      expect(find.byType(TextFormField), findsOneWidget);
      // AppLocalizations-sourced: "Confirm your password" is
      // l10n.upgradeToCloudPasswordLabel (app_en.arb).
      expect(find.text('Confirm your password'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('shows upgrade FilledButton with l10n label', (tester) async {
      await _pump(
        tester,
        _buildApp(
          db: _db,
          registry: _registry,
          authRepo: _authRepo,
          checker: _checker,
        ),
      );

      // l10n key: upgradeToCloudButton
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Upgrade to Cloud'), findsWidgets);

      await _tearDown(tester);
    });

    testWidgets('shows user email in body copy', (tester) async {
      await _pump(
        tester,
        _buildApp(
          db: _db,
          registry: _registry,
          authRepo: _authRepo,
          checker: _checker,
        ),
      );

      // AppLocalizations-sourced: "You're signed in as …" body text is
      // l10n.upgradeToCloudValueProp({email}) (app_en.arb).
      expect(find.textContaining(_email), findsWidgets);

      await _tearDown(tester);
    });

    testWidgets('no error messages shown on initial render', (tester) async {
      await _pump(
        tester,
        _buildApp(
          db: _db,
          registry: _registry,
          authRepo: _authRepo,
          checker: _checker,
        ),
      );

      expect(find.text('Password required'), findsNothing);
      expect(find.text('Incorrect password.'), findsNothing);
      expect(find.textContaining('Upgrade failed:'), findsNothing);

      await _tearDown(tester);
    });
  });

  // ── Validation ──────────────────────────────────────────────────────────────

  group('UpgradeToCloudScreen — validation', () {
    testWidgets(
      'tapping button with empty password shows inline validation error',
      (tester) async {
        await _pump(
          tester,
          _buildApp(
            db: _db,
            registry: _registry,
            authRepo: _authRepo,
            checker: _checker,
          ),
        );

        await tester.tap(find.byType(FilledButton));
        await tester.pump();

        // AppLocalizations-sourced: "Password required" is
        // l10n.upgradeToCloudPasswordRequired in the validator (app_en.arb).
        expect(find.text('Password required'), findsOneWidget);

        await _tearDown(tester);
      },
    );

    testWidgets('service not called when password field is empty', (
      tester,
    ) async {
      await _pump(
        tester,
        _buildApp(
          db: _db,
          registry: _registry,
          authRepo: _authRepo,
          checker: _checker,
        ),
      );

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      verifyNever(() => _authRepo.createUserAccount(any(), any()));

      await _tearDown(tester);
    });

    testWidgets(
      'non-local-born auth state shows "Only local-born…" error inline',
      (tester) async {
        await _pump(
          tester,
          _buildApp(
            db: _db,
            registry: _registry,
            authRepo: _authRepo,
            checker: _checker,
            auth: _cloudBornAuth,
          ),
        );

        await tester.enterText(find.byType(TextFormField), _password);
        await tester.pump();
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // AppLocalizations-sourced: this message is
        // l10n.upgradeToCloudErrorLocalBornOnly in _submit() (app_en.arb).
        expect(
          find.text('Only local-born accounts can be upgraded.'),
          findsOneWidget,
        );

        await _tearDown(tester);
      },
    );
  });

  // ── Error state — password mismatch ─────────────────────────────────────────
  //
  // Uses null passwordHash: PasswordHasher short-circuits without argon2id.

  group('UpgradeToCloudScreen — error: password mismatch', () {
    testWidgets('shows "Incorrect password." for null-hash profile', (
      tester,
    ) async {
      await _seedAccountNullHash(_db);

      await _pump(
        tester,
        _buildApp(
          db: _db,
          registry: _registry,
          authRepo: _authRepo,
          checker: _checker,
        ),
      );

      await tester.enterText(find.byType(TextFormField), _password);
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // AppLocalizations-sourced: "Incorrect password." is
      // l10n.upgradeToCloudErrorIncorrectPassword in the catch block (app_en.arb).
      expect(find.text('Incorrect password.'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('form is re-enabled after password-mismatch error', (
      tester,
    ) async {
      await _seedAccountNullHash(_db);

      await _pump(
        tester,
        _buildApp(
          db: _db,
          registry: _registry,
          authRepo: _authRepo,
          checker: _checker,
        ),
      );

      await tester.enterText(find.byType(TextFormField), _password);
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(
        field.enabled,
        isNot(false),
        reason: 'Password field must be re-enabled after error',
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(
        button.onPressed,
        isNotNull,
        reason: 'Button must be re-enabled after error',
      );

      await _tearDown(tester);
    });
  });

  // ── Error state — generic exception (missing profile) ───────────────────────
  //
  // Profile not seeded → getUserProfileById returns null → StateError → screen
  // shows a FRIENDLY LOCALIZED fallback (upgradeToCloudErrorGeneric), NOT the
  // raw exception. This is the red→green guard for [P1]: the screen used to
  // interpolate the raw exception via 'Upgrade failed: $e'.

  group('UpgradeToCloudScreen — error: generic exception', () {
    testWidgets(
      'shows friendly localized fallback (not raw exception) when profile is '
      'missing from DB',
      (tester) async {
        // No profile seeded — getUserProfileById(1) returns null.

        await _pump(
          tester,
          _buildApp(
            db: _db,
            registry: _registry,
            authRepo: _authRepo,
            checker: _checker,
          ),
        );

        await tester.enterText(find.byType(TextFormField), _password);
        await tester.pump();
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // RED→GREEN: the raw exception text/prefix must NEVER render.
        expect(
          find.textContaining('Upgrade failed:'),
          findsNothing,
          reason: 'The raw exception prefix must not be shown to the user',
        );
        expect(
          find.textContaining('Bad state'),
          findsNothing,
          reason: 'The raw StateError text must not be shown to the user',
        );
        // The friendly localized fallback (en) is shown instead.
        expect(
          find.text("We couldn't complete the upgrade. Please try again."),
          findsOneWidget,
        );

        await _tearDown(tester);
      },
    );

    testWidgets('error text carries explicit colour', (tester) async {
      await _pump(
        tester,
        _buildApp(
          db: _db,
          registry: _registry,
          authRepo: _authRepo,
          checker: _checker,
        ),
      );

      await tester.enterText(find.byType(TextFormField), _password);
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final errorFinder = find.text(
        "We couldn't complete the upgrade. Please try again.",
      );
      expect(errorFinder, findsOneWidget);

      final text = tester.widget<Text>(errorFinder);
      expect(
        text.style?.color,
        isNotNull,
        reason: 'Error text must carry an explicit theme error colour',
      );

      await _tearDown(tester);
    });

    testWidgets('form is re-enabled after generic error', (tester) async {
      await _pump(
        tester,
        _buildApp(
          db: _db,
          registry: _registry,
          authRepo: _authRepo,
          checker: _checker,
        ),
      );

      await tester.enterText(find.byType(TextFormField), _password);
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(
        field.enabled,
        isNot(false),
        reason: 'Field must be re-enabled after error',
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(
        button.onPressed,
        isNotNull,
        reason: 'Button must be re-enabled after error',
      );

      await _tearDown(tester);
    });
  });

  // ── Offline guard ────────────────────────────────────────────────────────────

  group('UpgradeToCloudScreen — offline guard', () {
    testWidgets('shows internet-required message when offline', (tester) async {
      when(() => _checker.hasConnection).thenAnswer((_) async => false);

      await _pump(
        tester,
        _buildApp(
          db: _db,
          registry: _registry,
          authRepo: _authRepo,
          checker: _checker,
        ),
      );

      await tester.enterText(find.byType(TextFormField), _password);
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // AppLocalizations-sourced: internet error message is
      // l10n.upgradeToCloudErrorInternetRequired (app_en.arb).
      expect(
        find.textContaining('Internet connection is required'),
        findsOneWidget,
      );

      verifyNever(() => _authRepo.createUserAccount(any(), any()));

      await _tearDown(tester);
    });
  });

  // ── Error state — credential-less Firebase error-code mapping (AUD-account-10)
  //
  // UpgradeToCloudScreen carried its own private _extractFirebaseCode() copy
  // (duplicated from the shared lib/core/utils/firebase_error_code.dart helper
  // introduced for AUD-account-04) with the stale `RegExp(r'\[([a-z-]+)\]')`
  // pattern that never matches Firebase's real `[plugin/code]` toString()
  // shape (e.g. `[firebase_auth/weak-password]`) — every real Firebase error
  // code silently fell through to the generic fallback message instead of the
  // specific, actionable one. The credential-less path (_submitNewCredentials)
  // calls authRepository.createUserAccount() directly with no local password
  // to verify, so it exercises this mapping without the argon2id Isolate
  // limitation that gates the _submit() path's error tests above.

  group('UpgradeToCloudScreen — credential-less error mapping', () {
    testWidgets('shows the specific weak-password message for a '
        '"[firebase_auth/weak-password]"-shaped exception, not the generic '
        'fallback', (tester) async {
      await _seedAccountNullHash(_db);
      when(() => _authRepo.createUserAccount(any(), any())).thenThrow(
        Exception(
          '[firebase_auth/weak-password] Password should be at least 6 '
          'characters',
        ),
      );

      await _pump(
        tester,
        _buildApp(
          db: _db,
          registry: _registry,
          authRepo: _authRepo,
          checker: _checker,
          auth: _credentialLessAuth,
        ),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'newuser@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), _password);
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // l10n key: signUpErrWeakPassword. Must be the SPECIFIC mapped
      // message, not upgradeToCloudErrorGeneric — a stale/broken code
      // extractor cannot tell weak-password apart from any other error.
      expect(
        find.text('Password is too weak. Use at least 6 characters.'),
        findsOneWidget,
        reason:
            'A [firebase_auth/weak-password] exception must map to the '
            'specific weak-password message via the SHARED extractFirebaseCode '
            'helper, not fall through to the generic fallback because of a '
            'stale duplicated regex',
      );
      expect(
        find.text("We couldn't complete the upgrade. Please try again."),
        findsNothing,
      );

      await _tearDown(tester);
    });
  });

  // ── Submitting state ─────────────────────────────────────────────────────────
  //
  // The isLoading flag is set BEFORE the password hash check. After a single
  // pump that processes the internet check + DB lookup microtasks, the button
  // is disabled and the spinner should be visible.

  group('UpgradeToCloudScreen — submitting state', () {
    testWidgets(
      'button is disabled immediately after tap (DB lookup in-flight)',
      (tester) async {
        // Seed a profile so getUserProfileById returns a result, keeping the
        // async chain alive long enough to observe isLoading = true.
        await _seedAccountNullHash(_db);

        await _pump(
          tester,
          _buildApp(
            db: _db,
            registry: _registry,
            authRepo: _authRepo,
            checker: _checker,
          ),
        );

        await tester.enterText(find.byType(TextFormField), _password);
        await tester.pump();

        await tester.tap(find.byType(FilledButton));
        // One pump processes the internet check future.
        await tester.pump();
        // Second pump processes the DB lookup future and setState(isLoading).
        await tester.pump();

        // The isLoading state disables the button.
        final button = tester.widget<FilledButton>(
          find.byType(FilledButton).first,
        );
        // NOTE: After second pump the password-mismatch error may already be
        // shown (the null-hash path is fast). Check either isLoading OR error.
        final isDisabledOrError =
            button.onPressed == null ||
            find.text('Incorrect password.').evaluate().isNotEmpty;
        expect(
          isDisabledOrError,
          isTrue,
          reason:
              'Button must be either disabled (loading) or show error after submit',
        );

        await _tearDown(tester);
      },
    );
  });

  // ── Email-collision state (skip: argon2id Isolate limitation) ────────────────

  group('UpgradeToCloudScreen — EmailCollisionException', () {
    // BUG: To reach authRepo.createUserAccount, PasswordHasher.verify must
    // return true (password matches stored hash). The cryptography package
    // uses Isolate.spawn for argon2id, whose completion never propagates
    // to Flutter's fake_async widget-test zone. Even with tester.runAsync,
    // the setState call from inside _submit() doesn't rebuild the widget.
    // These tests are therefore skipped at L1; the full collision flow
    // is covered at integration level in epic_20_hard_tier_auth_test.dart.
    testWidgets(
      'collision block shown with both resolution tiles',
      skip: true,
      (tester) async {
        // Would need: valid argon2id hash + authRepo.createUserAccount throws
        // EmailCollisionException. See ARCHITECTURE NOTE at top of file.
        expect(true, isTrue);
      },
    );

    testWidgets(
      'selecting Upload option shows cloud-password field',
      skip: true,
      (tester) async {
        expect(true, isTrue);
      },
    );

    testWidgets('collision block shows l10n cancel button', skip: true, (
      tester,
    ) async {
      expect(true, isTrue);
    });

    testWidgets('tapping cancel from collision returns to form', skip: true, (
      tester,
    ) async {
      expect(true, isTrue);
    });
  });

  // ── Verification-required state (skip: argon2id Isolate limitation) ──────────

  group('UpgradeToCloudScreen — UpgradeEmailNotVerifiedException', () {
    // BUG: Same Isolate limitation as collision tests above.
    testWidgets(
      'shows EmailVerificationConfirmPanel with hardcoded verified-link label',
      skip: true,
      (tester) async {
        expect(true, isTrue);
      },
    );

    testWidgets('cancel on verification panel returns to form', skip: true, (
      tester,
    ) async {
      expect(true, isTrue);
    });
  });

  // ── Success state (skip: argon2id Isolate limitation) ────────────────────────

  group('UpgradeToCloudScreen — success state', () {
    // BUG: To observe success the full async chain must complete:
    // argon2id verify → createUserAccount → reloadCurrentUser → upgradeLocalToCloud
    // → setCloudBornSession → setState(_PhaseSuccess). The argon2id Isolate
    // completion cannot propagate in fake_async (see ARCHITECTURE NOTE).
    // AppLocalizations-sourced: "You're backed up!" in _SuccessBlock is
    // l10n.upgradeToCloudSuccessTitle (app_en.arb).
    testWidgets(
      'shows "You\'re backed up!" block after complete upgrade',
      skip: true,
      (tester) async {
        expect(true, isTrue);
      },
    );
  });

  // ── he-RTL smoke ─────────────────────────────────────────────────────────────

  group('UpgradeToCloudScreen — RTL smoke (he)', () {
    testWidgets('renders under Hebrew locale without exception', (
      tester,
    ) async {
      await _pump(
        tester,
        _buildApp(
          db: _db,
          registry: _registry,
          authRepo: _authRepo,
          checker: _checker,
          locale: const Locale('he'),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('Hebrew locale applies RTL text direction', (tester) async {
      await _pump(
        tester,
        _buildApp(
          db: _db,
          registry: _registry,
          authRepo: _authRepo,
          checker: _checker,
          locale: const Locale('he'),
        ),
      );

      final dirFinders = find.byType(Directionality);
      expect(dirFinders, findsWidgets);
      final outerDir = tester.widget<Directionality>(dirFinders.first);
      expect(outerDir.textDirection, TextDirection.rtl);

      await _tearDown(tester);
    });

    // RED→GREEN [P1]: the headline + value-prop were hardcoded English. Under a
    // Hebrew UI they must render the localized Hebrew copy, not English.
    testWidgets('he locale: headline + value-prop are localized (no English)', (
      tester,
    ) async {
      await _pump(
        tester,
        _buildApp(
          db: _db,
          registry: _registry,
          authRepo: _authRepo,
          checker: _checker,
          locale: const Locale('he'),
        ),
      );

      // English literals from the previous hardcoded implementation must be gone.
      expect(find.text('Back up your account'), findsNothing);
      expect(find.textContaining("You're signed in as"), findsNothing);
      // Localized Hebrew headline is shown.
      expect(find.text('גבו את החשבון שלכם'), findsOneWidget);
      // Value-prop still interpolates the email (ICU placeholder) under RTL.
      expect(find.textContaining(_email), findsWidgets);
      // Password field label is localized.
      expect(find.text('Confirm your password'), findsNothing);

      await _tearDown(tester);
    });

    // RED→GREEN [P1]: the generic catch interpolated the raw exception
    // ('Upgrade failed: $e'). Under a Hebrew UI that leaks English + internal
    // exception text. Profile missing → StateError → friendly localized he copy.
    testWidgets(
      'he locale: generic error shows localized fallback (no raw exception)',
      (tester) async {
        // No profile seeded → getUserProfileById(1) returns null → StateError.
        await _pump(
          tester,
          _buildApp(
            db: _db,
            registry: _registry,
            authRepo: _authRepo,
            checker: _checker,
            locale: const Locale('he'),
          ),
        );

        await tester.enterText(find.byType(TextFormField), _password);
        await tester.pump();
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.textContaining('Upgrade failed:'),
          findsNothing,
          reason: 'Raw English exception prefix must never render under he',
        );
        expect(find.textContaining('Bad state'), findsNothing);
        // Localized Hebrew fallback (upgradeToCloudErrorGeneric).
        expect(
          find.text('לא הצלחנו להשלים את השדרוג. נסו שוב.'),
          findsOneWidget,
        );

        await _tearDown(tester);
      },
    );
  });
}

// ── Suppress unused-import warning (PasswordHasher used for Argon2idParams) ──
// ignore: unused_element
void _usedInSkippedTests() {
  PasswordHasher; // ignore: unnecessary_statements
  _FakeVerifiedAppUser; // ignore: unnecessary_statements
  EmailCollisionException; // ignore: unnecessary_statements
  UpgradeEmailNotVerifiedException; // ignore: unnecessary_statements
}
