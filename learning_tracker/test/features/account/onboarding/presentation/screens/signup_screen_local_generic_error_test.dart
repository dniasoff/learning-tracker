// Regression test for AUD-account-24: signup_screen.dart's local (offline)
// sign-up failure path must not interpolate a raw exception's .toString()
// into the user-facing snackbar message.
//
// _signUpLocal's outer `catch (e)` handles anything that isn't the two
// already-typed exceptions (DuplicateEmailException / InvalidInputException)
// — an unexpected/untyped failure (disk error, closed DB, etc). Previously
// that branch did:
//
//   _showError(l10n.signUpFailed(e.toString()))
//
// which showed the raw Dart exception text (e.g. "Exception: disk I/O
// error") to the user — untranslated and leaking implementation detail. This
// is exactly the pattern the `no_e_to_string_in_ui` custom lint targets.
//
// Fixed to show the existing localized generic fallback (signUpErrGeneric)
// instead — the same message the cloud-signup path already falls back to
// for an unmapped Firebase error code.
//
// Red -> Green:
//   BEFORE the fix: the snackbar text contained the raw exception message
//   ("disk I/O error...") and NOT the generic l10n copy.
//   AFTER the fix: the snackbar shows only the generic l10n message; the raw
//   exception text never reaches the UI.
@Tags(['l1', 'signup', 'account'])
library;

import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart'
    show userDatabaseProvider;
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/onboarding/presentation/screens/signup_screen.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockDeviceRegistry extends Mock implements DeviceRegistryDatabase {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

late Directory _fakeDocsDir;

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    registerFallbackValue(_FakePageRouteInfo());

    // _signUpLocal's failure path always calls
    // path_provider.getApplicationDocumentsDirectory() (for the recovery /
    // orphan-cleanup helper), regardless of where in the try block the
    // failure originated — mock the channel so the widget test doesn't hang
    // on a MissingPluginException.
    _fakeDocsDir = Directory.systemTemp.createTempSync(
      'signup_local_generic_error_test_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory' ||
                methodCall.method == 'getApplicationSupportDirectory' ||
                methodCall.method == 'getTemporaryDirectory') {
              return _fakeDocsDir.path;
            }
            return null;
          },
        );
  });

  tearDownAll(() {
    if (_fakeDocsDir.existsSync()) {
      _fakeDocsDir.deleteSync(recursive: true);
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Offline-until-proven-online default; belt-and-braces alongside the
    // connectivityStreamProvider override below.
    debugSetLastKnownOnline(false);
  });

  tearDown(debugResetLastKnownOnline);

  testWidgets(
    'offline local sign-up: unexpected error shows the localized generic '
    'message, never the raw exception text',
    (tester) async {
      final registry = _MockDeviceRegistry();
      // Anything other than DuplicateEmailException / InvalidInputException
      // reaching the try block falls into the generic `catch (e)` under
      // test — a device-registry lookup failure is a realistic, minimal way
      // to trigger it without touching the local user DB at all.
      when(
        () => registry.findByEmail(any()),
      ).thenThrow(Exception('disk I/O error: device not ready'));

      final userDb = UserDatabase(NativeDatabase.memory());
      addTearDown(() async => userDb.close());

      final auth = _MockAuthRepository();
      when(() => auth.currentUser).thenReturn(null);

      final router = _MockStackRouter();
      when(() => router.replace(any())).thenAnswer((_) async => null);
      when(
        () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
      ).thenAnswer((_) async => null);
      when(() => router.replaceAll(any())).thenAnswer((_) async => []);
      when(() => router.canPop()).thenReturn(false);

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            deviceRegistryProvider.overrideWithValue(registry),
            userDatabaseProvider.overrideWithValue(userDb),
            connectivityStreamProvider.overrideWith(
              (ref) => Stream.value(false),
            ),
          ],
          child: MaterialApp(
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
              child: const Scaffold(body: SignupScreen()),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final button = find.widgetWithText(
        FilledButton,
        'Create Offline Account',
      );
      expect(button, findsOneWidget);
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byType(SnackBar),
        findsOneWidget,
        reason: 'an error snackbar must appear after the unexpected failure',
      );
      expect(
        find.textContaining('Account creation failed'),
        findsOneWidget,
        reason:
            'the snackbar must show the localized generic signup-failure '
            'message (signUpErrGeneric)',
      );
      expect(
        find.textContaining('disk I/O error'),
        findsNothing,
        reason:
            'the raw exception text must never reach the UI — this is the '
            'AUD-account-24 regression: e.toString() must not be '
            'interpolated into the user-facing message',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
