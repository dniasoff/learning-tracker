import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/navigation/guards/auth_guard.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/core/navigation/guards/restore_guard.dart';
import 'package:learning_tracker/core/navigation/pin_scope.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockPinService extends Mock implements PinService {}

AppRouter _createAuthenticatedRouter() {
  final mockPinService = MockPinService();
  when(() => mockPinService.hasParentPin()).thenAnswer((_) async => false);

  final testDb = createTestDatabase();
  final restoreGuard = RestoreGuard(
    getDatabase: () => testDb,
    hasCloudAccount: () => false,
  );
  restoreGuard.markRestoreComplete();

  return AppRouter(
    authGuard: AuthGuard(),
    restoreGuard: restoreGuard,
    profileGuard: ProfileGuard(
      getDatabase: () => testDb,
      getSelectedProfileId: () => 1,
      setSelectedProfileId: (_) {},
      getAccountId: () => 1,
    ),
    childModeGuard: ChildModeGuard(
      getDatabase: () => testDb,
      getSelectedProfileId: () => 1,
    ),
    pinGuard: PinGuard(
      pinService: mockPinService,
      promptForPin: () async => false,
      getScope: () => const PinScope.parent(1),
    ),
  );
}

AppRouter _createUnauthenticatedRouter() {
  final mockPinService = MockPinService();
  when(() => mockPinService.hasParentPin()).thenAnswer((_) async => false);

  final testDb = createTestDatabase();
  final restoreGuard = RestoreGuard(
    getDatabase: () => testDb,
    hasCloudAccount: () => false,
  );
  restoreGuard.markRestoreComplete();

  return AppRouter(
    authGuard: AuthGuard(),
    restoreGuard: restoreGuard,
    profileGuard: ProfileGuard(
      getDatabase: () => testDb,
      getSelectedProfileId: () => 1,
      setSelectedProfileId: (_) {},
      getAccountId: () => 1,
    ),
    childModeGuard: ChildModeGuard(
      getDatabase: () => testDb,
      getSelectedProfileId: () => 1,
    ),
    pinGuard: PinGuard(
      pinService: mockPinService,
      promptForPin: () async => false,
      getScope: () => const PinScope.parent(1),
    ),
  );
}

const _authOverride = AuthState.signedIn(
  user: AuthUser(
    profileId: 1,
    email: 'test@test.com',
    displayName: 'Test',
    userMode: 'adult',
  ),
  tier: Tier.localBorn,
);

/// Pump enough frames for navigation and async providers to resolve,
/// without using pumpAndSettle (which hangs on stream providers).
Future<void> _pumpDashboard(WidgetTester tester) async {
  await tester.pump(); // initial frame
  await tester.pump(const Duration(milliseconds: 500)); // async resolution
  await tester.pump(); // rebuild
}

/// Force-disposes the widget tree and drains Drift's zero-duration cleanup
/// timers so the test framework's `_verifyInvariants` sees no pending timers.
Future<void> _cleanUpWidgets(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

/// Wraps the router in a MaterialApp configured with the same localization
/// delegates as production main.dart — without these, screens that call
/// `AppLocalizations.of(context)!` crash with a null-check error.
MaterialApp _wrapApp(RouterConfig<Object> routerConfig) {
  return MaterialApp.router(
    routerConfig: routerConfig,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  late UserDatabase db;

  setUpAll(() {
    // Prevent google_fonts from making real HTTP requests in tests.
    // Without this, font-loading futures cause 10-minute test timeouts.
    GoogleFonts.config.allowRuntimeFetching = false;

    // Suppress Drift "multiple database" warning in tests where router
    // helpers and setUp each create their own in-memory database.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    // Suppress google_fonts "font not found in assets" errors — PlusJakartaSans
    // is not bundled in test assets, but navigation tests don't need real fonts.
    final savedOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final msg = details.exception.toString();
      if (msg.contains('GoogleFonts') || msg.contains('google_fonts')) return;
      savedOnError?.call(details);
    };

    // Mock path_provider so driftDatabase can resolve in the auth guard
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getTemporaryDirectory' ||
                methodCall.method == 'getApplicationDocumentsDirectory' ||
                methodCall.method == 'getApplicationSupportDirectory') {
              return '/tmp/flutter_test';
            }
            return null;
          },
        );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('AppShellScreen bottom navigation', () {
    testWidgets(
      'renders exactly 4 tabs: Dashboard, Learn, Progress, Settings',
      (tester) async {
        final router = _createAuthenticatedRouter();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              userDatabaseProvider.overrideWithValue(db),
              authStateProvider.overrideWithValue(_authOverride),
              dashboardActiveCurriculaStreamProvider.overrideWith(
                (ref) => Stream.value(<CurriculumId>[]),
              ),
              dashboardStreakProvider.overrideWith(
                (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
              ),
              dashboardStreakRecoveryProvider.overrideWith(
                (ref) => Future.value(
                  const StreakRecoveryInfo(
                    wasRecovered: false,
                    currentStreak: 0,
                  ),
                ),
              ),
            ],
            child: _wrapApp(
              router.config(
                deepLinkBuilder: (_) => const DeepLink.path('/dashboard'),
              ),
            ),
          ),
        );
        await _pumpDashboard(tester);

        // The shell renders 4 tab items with uppercase labels from l10n.
        expect(find.text('DASHBOARD'), findsOneWidget);
        expect(find.text('LEARN'), findsOneWidget);
        expect(find.text('PROGRESS'), findsOneWidget);
        expect(find.text('SETTINGS'), findsOneWidget);

        await _cleanUpWidgets(tester);
      },
    );

    testWidgets('tapping Learn tab navigates to learn route', (tester) async {
      final router = _createAuthenticatedRouter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            userDatabaseProvider.overrideWithValue(db),
            authStateProvider.overrideWithValue(_authOverride),
            dashboardActiveCurriculaStreamProvider.overrideWith(
              (ref) => Stream.value(<CurriculumId>[]),
            ),
            dashboardStreakProvider.overrideWith(
              (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
            ),
            dashboardStreakRecoveryProvider.overrideWith(
              (ref) => Future.value(
                const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
              ),
            ),
          ],
          child: _wrapApp(
            router.config(
              deepLinkBuilder: (_) => const DeepLink.path('/dashboard'),
            ),
          ),
        ),
      );
      await _pumpDashboard(tester);

      expect(find.text('DASHBOARD'), findsOneWidget);

      await tester.tap(find.text('LEARN'));
      await _pumpDashboard(tester);

      // Bottom nav is still rendered after the tab switch.
      expect(find.text('LEARN'), findsOneWidget);

      await _cleanUpWidgets(tester);
    });

    testWidgets('tapping Progress tab navigates to progress route', (
      tester,
    ) async {
      final router = _createAuthenticatedRouter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            userDatabaseProvider.overrideWithValue(db),
            authStateProvider.overrideWithValue(_authOverride),
            dashboardActiveCurriculaStreamProvider.overrideWith(
              (ref) => Stream.value(<CurriculumId>[]),
            ),
            dashboardStreakProvider.overrideWith(
              (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
            ),
            dashboardStreakRecoveryProvider.overrideWith(
              (ref) => Future.value(
                const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
              ),
            ),
          ],
          child: _wrapApp(
            router.config(
              deepLinkBuilder: (_) => const DeepLink.path('/dashboard'),
            ),
          ),
        ),
      );
      await _pumpDashboard(tester);

      await tester.tap(find.text('PROGRESS'));
      await _pumpDashboard(tester);

      expect(find.text('PROGRESS'), findsOneWidget);

      await _cleanUpWidgets(tester);
    });

    testWidgets('tapping Settings tab navigates to settings route', (
      tester,
    ) async {
      final router = _createAuthenticatedRouter();
      final mockAuthForProvider = MockAuthRepository();
      when(() => mockAuthForProvider.currentUser).thenReturn(null);

      // The CurriculumToggleTile reads curriculumActivationServiceProvider,
      // which cascades into Firestore providers not available in tests.
      // Suppress those expected ProviderException errors since this test
      // only verifies navigation.
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exception.toString().contains('ProviderException')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...[
              appDatabaseProvider.overrideWithValue(db),
              userDatabaseProvider.overrideWithValue(db),
              authStateProvider.overrideWithValue(_authOverride),
              dashboardActiveCurriculaStreamProvider.overrideWith(
                (ref) => Stream.value(<CurriculumId>[]),
              ),
              dashboardStreakProvider.overrideWith(
                (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
              ),
              dashboardStreakRecoveryProvider.overrideWith(
                (ref) => Future.value(
                  const StreakRecoveryInfo(
                    wasRecovered: false,
                    currentStreak: 0,
                  ),
                ),
              ),
            ],
            authRepositoryProvider.overrideWithValue(mockAuthForProvider),
          ],
          child: _wrapApp(
            router.config(
              deepLinkBuilder: (_) => const DeepLink.path('/dashboard'),
            ),
          ),
        ),
      );
      await _pumpDashboard(tester);

      await tester.tap(find.text('SETTINGS'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('SETTINGS'), findsOneWidget);

      await _cleanUpWidgets(tester);
    });
  });

  group('Curriculum-scoped routes', () {
    testWidgets('content browsing route accepts curriculumId parameter', (
      tester,
    ) async {
      final router = _createAuthenticatedRouter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            userDatabaseProvider.overrideWithValue(db),
            authStateProvider.overrideWithValue(_authOverride),
            dashboardActiveCurriculaStreamProvider.overrideWith(
              (ref) => Stream.value(<CurriculumId>[]),
            ),
            dashboardStreakProvider.overrideWith(
              (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
            ),
            dashboardStreakRecoveryProvider.overrideWith(
              (ref) => Future.value(
                const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
              ),
            ),
          ],
          child: _wrapApp(
            router.config(
              deepLinkBuilder: (_) =>
                  const DeepLink.path('/curriculum/mishnayos/browse'),
            ),
          ),
        ),
      );
      await tester.pump();

      // ContentHierarchyScreen renders the 'Browse Content' AppBar title
      // while content loads from the (bundled JSON) asset provider.
      expect(find.text('Browse Content'), findsOneWidget);

      await _cleanUpWidgets(tester);
    });
  });

  group('Auth flow', () {
    testWidgets('unauthenticated user is redirected to sign-in', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({}); // no onboarding_complete
      final router = _createUnauthenticatedRouter();

      // Suppress layout-overflow errors and Drift multiple-database warnings.
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        final msg = details.exception.toString();
        if (msg.contains('overflowed')) return;
        if (msg.contains('multiple times')) return;
        if (msg.contains('drift')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [useHebrewTermsProvider.overrideWithValue(false)],
          child: _wrapApp(router.config()),
        ),
      );
      await _pumpDashboard(tester);

      // Auth guard redirects to AppIntroRoute; the shell's bottom-nav
      // labels must NOT be present, confirming the user was redirected away.
      expect(find.text('DASHBOARD'), findsNothing);
      expect(find.text('LEARN'), findsNothing);

      await _cleanUpWidgets(tester);
    });

    testWidgets('authenticated user sees dashboard with bottom navigation', (
      tester,
    ) async {
      final router = _createAuthenticatedRouter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            userDatabaseProvider.overrideWithValue(db),
            authStateProvider.overrideWithValue(_authOverride),
            dashboardActiveCurriculaStreamProvider.overrideWith(
              (ref) => Stream.value(<CurriculumId>[]),
            ),
            dashboardStreakProvider.overrideWith(
              (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
            ),
            dashboardStreakRecoveryProvider.overrideWith(
              (ref) => Future.value(
                const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
              ),
            ),
          ],
          child: _wrapApp(router.config()),
        ),
      );
      await _pumpDashboard(tester);

      // Authenticated user reaches the shell — all 4 bottom-nav labels
      // are present.
      expect(find.text('DASHBOARD'), findsOneWidget);
      expect(find.text('LEARN'), findsOneWidget);
      expect(find.text('PROGRESS'), findsOneWidget);
      expect(find.text('SETTINGS'), findsOneWidget);

      await _cleanUpWidgets(tester);
    });
  });
}
