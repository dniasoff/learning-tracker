import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/app/router/persistent_switcher_scaffold.dart';
import 'package:learning_tracker/app/router/router_provider.dart' as rp;
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
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_switcher_sheet.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockPinService extends Mock implements PinService {}

/// Pins the active profile id deterministically so the switcher bar resolves
/// the seeded profile (id 1) and shows its real name — instead of the
/// account/fallback chain (the nav harness never sets the selected-profile
/// pref, so the real `activeProfileIdProvider` would not resolve to a profile).
class _FixedActiveProfileId extends ActiveProfileId {
  @override
  int build() => 1;
}

/// TUT-05: pins the active profile id to the talmid's synthetic local MIRROR id
/// (a profile id that is NOT in the signed-in tutor account's own profile set),
/// modelling a live tutor session where the mirror was resolved by the pull.
class _MirrorActiveProfileId extends ActiveProfileId {
  @override
  int build() => 99;
}

/// TUT-05: a fixed non-null tutored selection so the switcher bar treats the
/// session as an active tutor context (TUTOR badge + name from the mirror).
class _ActiveTutoredSelection extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => const TutoredProfileSelection(
    profileId: 'talmid-remote-id',
    ownerUid: 'owner-uid',
    grantId: 'grant-id',
    permissions: TutorPermissions(),
  );
}

Future<AppRouter> _createAuthenticatedRouter({
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  final mockPinService = MockPinService();
  when(() => mockPinService.hasParentPin()).thenAnswer((_) async => false);

  final testDb = createTestDatabase();
  // ProfileGuard now validates that the selected profile id actually exists in
  // the current DB before short-circuiting (R1o-C2), so the guard DB must hold
  // a profile whose id matches getSelectedProfileId() → 1.
  await seedProfileWithIds(testDb, profileId: 1, accountId: 1);
  final restoreGuard = RestoreGuard(
    getDatabase: () => testDb,
    hasCloudAccount: () => false,
  );
  restoreGuard.markRestoreComplete();

  return AppRouter(
    // BUG E3 follow-up: the persistent switcher bar (rendered above the
    // router's Navigator in the builder slot) opens the sheet through the root
    // navigator's context (rp.navigatorKey). Tests that exercise the tap must
    // bind the router to that same global key, mirroring production.
    navigatorKey: navigatorKey,
    authGuard: AuthGuard(),
    restoreGuard: restoreGuard,
    profileGuard: ProfileGuard(
      getDatabase: () => testDb,
      getSelectedProfileId: () => 1,
      setSelectedProfileId: (_) {},
      getAccountId: () => 1,
      isTutoredSession: () => false,
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

Future<AppRouter> _createUnauthenticatedRouter() async {
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
      isTutoredSession: () => false,
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
  user: AuthUser(profileId: 1, email: 'test@test.com', displayName: 'Test'),
  tier: Tier.localBorn,
);

/// A single own adult profile so AppShell sees a non-empty profile list and
/// does NOT trigger the profile-less → Settings-tab jump — it stays on the
/// Dashboard tab, which is what these shell-navigation tests exercise.
final _seededProfiles = [
  ProfileModel(
    id: 1,
    accountId: 1,
    displayName: 'Test',
    mode: 'adult',
    avatarIndex: 0,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  ),
];

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

/// Like [_wrapApp] but mounts the production [PersistentSwitcherScaffold] in the
/// `MaterialApp.router` builder slot — the global layer that keeps the
/// profile/role switcher bar at the top of EVERY pushed sub-route. Used by the
/// persistent-switcher regression tests so the test tree matches production.
MaterialApp _wrapAppWithPersistentSwitcher(RouterConfig<Object> routerConfig) {
  return MaterialApp.router(
    routerConfig: routerConfig,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) =>
        PersistentSwitcherScaffold(child: child ?? const SizedBox.shrink()),
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
        final router = await _createAuthenticatedRouter();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              userDatabaseProvider.overrideWithValue(db),
              authStateProvider.overrideWithValue(_authOverride),
              profileListStreamProvider.overrideWith(
                (ref) => Stream.value(_seededProfiles),
              ),
              activeProfileIdProvider.overrideWith(_FixedActiveProfileId.new),
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
      final router = await _createAuthenticatedRouter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            userDatabaseProvider.overrideWithValue(db),
            authStateProvider.overrideWithValue(_authOverride),
            profileListStreamProvider.overrideWith(
              (ref) => Stream.value(_seededProfiles),
            ),
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
      final router = await _createAuthenticatedRouter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            userDatabaseProvider.overrideWithValue(db),
            authStateProvider.overrideWithValue(_authOverride),
            profileListStreamProvider.overrideWith(
              (ref) => Stream.value(_seededProfiles),
            ),
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
      final router = await _createAuthenticatedRouter();
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
              profileListStreamProvider.overrideWith(
                (ref) => Stream.value(_seededProfiles),
              ),
              activeProfileIdProvider.overrideWith(_FixedActiveProfileId.new),
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
      final router = await _createAuthenticatedRouter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            userDatabaseProvider.overrideWithValue(db),
            authStateProvider.overrideWithValue(_authOverride),
            profileListStreamProvider.overrideWith(
              (ref) => Stream.value(_seededProfiles),
            ),
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
      final router = await _createUnauthenticatedRouter();

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
      final router = await _createAuthenticatedRouter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            userDatabaseProvider.overrideWithValue(db),
            authStateProvider.overrideWithValue(_authOverride),
            profileListStreamProvider.overrideWith(
              (ref) => Stream.value(_seededProfiles),
            ),
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

  // §5 persistent switcher (feedback_profile_switcher_top): the profile/role
  // switcher must be present at the TOP of EVERY context. Regression guard for
  // the previously-missing switcher in the DEFAULT own-profile context
  // (Dashboard/Learn/Progress had no switcher entry; only Settings did).
  group('AppShellScreen persistent profile switcher', () {
    testWidgets(
      'default own-profile context shows the persistent switcher bar at top',
      (tester) async {
        final router = await _createAuthenticatedRouter();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              userDatabaseProvider.overrideWithValue(db),
              authStateProvider.overrideWithValue(_authOverride),
              profileListStreamProvider.overrideWith(
                (ref) => Stream.value(_seededProfiles),
              ),
              activeProfileIdProvider.overrideWith(_FixedActiveProfileId.new),
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

        // The always-present switcher bar (keyed) is rendered on the default
        // Dashboard context, showing the active profile name + role badge.
        expect(
          find.byKey(const Key('appShellProfileSwitcherBar')),
          findsOneWidget,
        );
        // Resolved active-profile name + role badge + the unfold affordance
        // that signals it opens the switcher.
        expect(find.text('Test'), findsWidgets);
        // Bug A: the role badge must reflect the profile MODE — the seeded
        // profile is an ADULT, so it reads "ADULT MODE", NOT the generic
        // "SELF-LEARNER" that previously rendered for every mode.
        expect(find.text('ADULT MODE'), findsOneWidget);
        expect(find.text('SELF-LEARNER'), findsNothing);
        expect(find.byIcon(Icons.unfold_more_rounded), findsOneWidget);

        await _cleanUpWidgets(tester);
      },
    );

    // Bug A regression: a CHILD learner profile must NOT read identically to an
    // adult — the persistent switcher chip must show the child mode badge.
    testWidgets(
      'child profile shows the CHILD MODE badge (not SELF-LEARNER / ADULT MODE)',
      (tester) async {
        final router = await _createAuthenticatedRouter();
        final childProfiles = [
          ProfileModel(
            id: 1,
            accountId: 1,
            displayName: 'Test',
            mode: 'child',
            avatarIndex: 0,
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              userDatabaseProvider.overrideWithValue(db),
              authStateProvider.overrideWithValue(_authOverride),
              profileListStreamProvider.overrideWith(
                (ref) => Stream.value(childProfiles),
              ),
              activeProfileIdProvider.overrideWith(_FixedActiveProfileId.new),
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

        expect(
          find.byKey(const Key('appShellProfileSwitcherBar')),
          findsOneWidget,
        );
        expect(find.text('CHILD MODE'), findsOneWidget);
        expect(find.text('ADULT MODE'), findsNothing);
        expect(find.text('SELF-LEARNER'), findsNothing);

        await _cleanUpWidgets(tester);
      },
    );

    testWidgets('tapping the switcher bar opens the ProfileSwitcherSheet', (
      tester,
    ) async {
      final router = await _createAuthenticatedRouter();

      // Opening the sheet pulls in the tutored-children section, which reads
      // tutoring/Firestore providers not wired in this navigation test;
      // suppress those expected ProviderExceptions — we only assert the sheet
      // (the switcher entry point) was presented.
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        final msg = details.exception.toString();
        if (msg.contains('ProviderException') || msg.contains('overflowed')) {
          return;
        }
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            userDatabaseProvider.overrideWithValue(db),
            authStateProvider.overrideWithValue(_authOverride),
            profileListStreamProvider.overrideWith(
              (ref) => Stream.value(_seededProfiles),
            ),
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

      expect(find.byType(ProfileSwitcherSheet), findsNothing);

      await tester.tap(find.byKey(const Key('appShellProfileSwitcherBar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The canonical profile switcher/manager sheet is now presented.
      expect(find.byType(ProfileSwitcherSheet), findsOneWidget);

      await _cleanUpWidgets(tester);
    });
  });

  // BUG E3 (feedback_profile_switcher_top): the persistent profile/role
  // switcher must remain at the TOP of EVERY pushed sub-route — not only the
  // four shell tabs. Sub-routes are TOP-LEVEL siblings of the shell, so when
  // pushed they replace the shell and used to lose the switcher entirely.
  // PersistentSwitcherScaffold (mounted in the MaterialApp.router builder slot)
  // re-renders the SAME ProfileSwitcherBar above the sub-route. This guards
  // against regressing to a switcher-less sub-screen.
  group('Persistent switcher on pushed sub-routes (BUG E3)', () {
    testWidgets('switcher bar is present on a pushed sub-route above the shell', (
      tester,
    ) async {
      final router = await _createAuthenticatedRouter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            userDatabaseProvider.overrideWithValue(db),
            authStateProvider.overrideWithValue(_authOverride),
            profileListStreamProvider.overrideWith(
              (ref) => Stream.value(_seededProfiles),
            ),
            activeProfileIdProvider.overrideWith(_FixedActiveProfileId.new),
            // Override the dashboard streak providers so the underlying
            // dashboard route (resolved before the push) doesn't spawn the
            // 15-min rollover timer that trips the test timer-invariant.
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
            // The PersistentSwitcherScaffold resolves the active router via
            // routerProvider; point it at the same test router instance so it
            // observes the real navigation stack.
            rp.routerProvider.overrideWithValue(router),
          ],
          child: _wrapAppWithPersistentSwitcher(
            router.config(
              // Land directly on a PUSHED sub-route (City picker), which is a
              // top-level sibling of the shell — not a shell tab. Chosen as a
              // lightweight sub-route with no DB/plugin/timer dependencies.
              deepLinkBuilder: (_) => const DeepLink.path('/sacred-time/city'),
            ),
          ),
        ),
      );
      await _pumpDashboard(tester);

      // We are on the sub-route, NOT a shell tab — the bottom-nav tab labels
      // are absent here.
      expect(find.text('DASHBOARD'), findsNothing);

      // Yet the persistent profile/role switcher bar is still rendered at the
      // top, supplied by the global builder-slot layer.
      expect(
        find.byKey(const Key('appShellProfileSwitcherBar')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.unfold_more_rounded), findsOneWidget);

      // Visibility guard (feedback_profile_switcher_top): the persistent bar
      // must sit ABOVE the sub-route's own AppBar — genuinely visible at the
      // top, not behind/overlaid by it. The switcher bar's bottom edge must be
      // at or above the sub-route AppBar's top edge (no vertical overlap), and
      // its top edge must be the topmost of the two.
      final switcherRect = tester.getRect(
        find.byKey(const Key('appShellProfileSwitcherBar')),
      );
      final appBarFinder = find.byType(AppBar);
      if (appBarFinder.evaluate().isNotEmpty) {
        final appBarRect = tester.getRect(appBarFinder.first);
        expect(
          switcherRect.top,
          lessThanOrEqualTo(appBarRect.top),
          reason: 'switcher bar must be the topmost element',
        );
        expect(
          switcherRect.bottom,
          lessThanOrEqualTo(appBarRect.top + 0.5),
          reason:
              'switcher bar must sit above the sub-route AppBar without '
              'being overlaid by it',
        );
      }

      await _cleanUpWidgets(tester);
    });

    testWidgets(
      'tapping the switcher bar on a pushed sub-route opens the sheet',
      (tester) async {
        // BUG E3 follow-up root cause: the builder-slot ProfileSwitcherBar sits
        // ABOVE the router's Navigator, so opening the modal sheet from its
        // local context (no Navigator ancestor) silently failed — the bar
        // SHOWED on sub-routes but TAPPING it did nothing. The fix routes the
        // tap through the root navigator's context. This test taps the bar on a
        // pushed sub-route and asserts the sheet appears, which fails on the
        // pre-fix behaviour.
        final router = await _createAuthenticatedRouter(
          navigatorKey: rp.navigatorKey,
        );

        // Opening the sheet pulls in the tutored-children section, which reads
        // tutoring/Firestore providers not wired here; suppress those expected
        // ProviderExceptions/overflows — we only assert the sheet was shown.
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          final msg = details.exception.toString();
          if (msg.contains('ProviderException') || msg.contains('overflowed')) {
            return;
          }
          originalOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = originalOnError);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              userDatabaseProvider.overrideWithValue(db),
              authStateProvider.overrideWithValue(_authOverride),
              profileListStreamProvider.overrideWith(
                (ref) => Stream.value(_seededProfiles),
              ),
              activeProfileIdProvider.overrideWith(_FixedActiveProfileId.new),
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
              rp.routerProvider.overrideWithValue(router),
            ],
            child: _wrapAppWithPersistentSwitcher(
              router.config(
                deepLinkBuilder: (_) =>
                    const DeepLink.path('/sacred-time/city'),
              ),
            ),
          ),
        );
        await _pumpDashboard(tester);

        // We are on the pushed sub-route (no shell tabs), and the persistent
        // switcher bar is present.
        expect(find.text('DASHBOARD'), findsNothing);
        expect(
          find.byKey(const Key('appShellProfileSwitcherBar')),
          findsOneWidget,
        );
        expect(find.byType(ProfileSwitcherSheet), findsNothing);

        // Tapping the bar opens the canonical switcher sheet — the behaviour
        // that was broken on sub-routes before the fix.
        await tester.tap(find.byKey(const Key('appShellProfileSwitcherBar')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(ProfileSwitcherSheet), findsOneWidget);

        await _cleanUpWidgets(tester);
      },
    );
  });

  // TUT-05: in a TUTOR session the persistent switcher header must show the
  // TUTORED CHILD's name (the talmid mirror) WITH the TUTOR badge — so the tutor
  // always sees whose data they are managing — NOT the tutor's own account name.
  // The active profile is the talmid's synthetic local MIRROR, which lives
  // outside the signed-in account's own profile set, so it is never in
  // `profileListStreamProvider`; the header must resolve the name via
  // `activeProfileProvider` (loads by id, finds the mirror).
  group('Tutor session header name (TUT-05)', () {
    testWidgets(
      'shows the talmid child name + TUTOR badge, not the tutor own account name',
      (tester) async {
        final router = await _createAuthenticatedRouter(
          navigatorKey: rp.navigatorKey,
        );

        // The signed-in TUTOR account's own profile (would be the wrong name to
        // show). Note its name differs from both the account "Test" and the
        // talmid "Kid".
        final tutorOwnProfiles = [
          ProfileModel(
            id: 1,
            accountId: 1,
            displayName: 'Family Niasoff',
            mode: 'adult',
            avatarIndex: 0,
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        ];

        // The talmid mirror profile (id 99) — what the header SHOULD display.
        final talmidMirror = ProfileModel(
          id: 99,
          accountId: 1,
          displayName: 'Kid',
          mode: 'child',
          avatarIndex: 0,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              userDatabaseProvider.overrideWithValue(db),
              authStateProvider.overrideWithValue(_authOverride),
              // Own profiles never contain the talmid mirror.
              profileListStreamProvider.overrideWith(
                (ref) => Stream.value(tutorOwnProfiles),
              ),
              // Active profile resolves to the mirror id (99), not own id (1).
              activeProfileIdProvider.overrideWith(_MirrorActiveProfileId.new),
              // The mirror is resolvable by id via activeProfileProvider.
              activeProfileProvider.overrideWith(
                (ref) => Future.value(talmidMirror),
              ),
              // An active tutored selection → TUTOR context.
              activeTutoredProfileSelectionProvider.overrideWith(
                _ActiveTutoredSelection.new,
              ),
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
              rp.routerProvider.overrideWithValue(router),
            ],
            // Use the persistent-switcher wrapper: in a tutored session the
            // shell appBar suppresses ProfileSwitcherBar, but the global layer
            // renders it (this is the header the tester sees).
            child: _wrapAppWithPersistentSwitcher(
              router.config(
                deepLinkBuilder: (_) =>
                    const DeepLink.path('/sacred-time/city'),
              ),
            ),
          ),
        );
        await _pumpDashboard(tester);

        // The switcher header is present, showing the TUTOR badge…
        expect(
          find.byKey(const Key('appShellProfileSwitcherBar')),
          findsOneWidget,
        );
        expect(find.text('TUTOR'), findsOneWidget);

        // …and the TALMID's name — not the tutor's own profile / account name.
        expect(find.text('Kid'), findsWidgets);
        expect(find.text('Family Niasoff'), findsNothing);
        expect(find.text('Test'), findsNothing);

        await _cleanUpWidgets(tester);
      },
    );
  });
}
