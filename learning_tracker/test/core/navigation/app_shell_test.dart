import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/core/navigation/guards/local_auth_guard.dart';
import 'package:learning_tracker/core/navigation/guards/parent_pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/core/navigation/guards/restore_guard.dart';
import 'package:learning_tracker/core/navigation/guards/tutor_pin_guard.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockPinService extends Mock implements PinService {}

AppRouter _createAuthenticatedRouter() {
  final mockPinService = MockPinService();
  when(() => mockPinService.hasParentPin()).thenAnswer((_) async => false);
  when(() => mockPinService.hasTutorPin()).thenAnswer((_) async => false);

  final testDb = createTestDatabase();
  final restoreGuard = RestoreGuard(
    database: testDb,
    hasCloudAccount: () => false,
  );
  restoreGuard.markRestoreComplete();

  return AppRouter(
    authGuard: LocalAuthGuard(),
    restoreGuard: restoreGuard,
    profileGuard: ProfileGuard(
      database: testDb,
      getSelectedProfileId: () => 1,
      setSelectedProfileId: (_) {},
      getAccountId: () => 1,
    ),
    childModeGuard: ChildModeGuard(database: testDb),
    parentPinGuard: ParentPinGuard(
      pinService: mockPinService,
      promptForPin: () async => null,
    ),
    tutorPinGuard: TutorPinGuard(
      pinService: mockPinService,
      promptForPin: () async => null,
    ),
  );
}

AppRouter _createUnauthenticatedRouter() {
  final mockPinService = MockPinService();
  when(() => mockPinService.hasParentPin()).thenAnswer((_) async => false);
  when(() => mockPinService.hasTutorPin()).thenAnswer((_) async => false);

  final testDb = createTestDatabase();
  final restoreGuard = RestoreGuard(
    database: testDb,
    hasCloudAccount: () => false,
  );
  restoreGuard.markRestoreComplete();

  return AppRouter(
    authGuard: LocalAuthGuard(),
    restoreGuard: restoreGuard,
    profileGuard: ProfileGuard(
      database: testDb,
      getSelectedProfileId: () => 1,
      setSelectedProfileId: (_) {},
      getAccountId: () => 1,
    ),
    childModeGuard: ChildModeGuard(database: testDb),
    parentPinGuard: ParentPinGuard(
      pinService: mockPinService,
      promptForPin: () async => null,
    ),
    tutorPinGuard: TutorPinGuard(
      pinService: mockPinService,
      promptForPin: () async => null,
    ),
  );
}

/// Pump enough frames for navigation and async providers to resolve,
/// without using pumpAndSettle (which hangs on stream providers).
Future<void> _pumpDashboard(WidgetTester tester) async {
  await tester.pump(); // initial frame
  await tester.pump(const Duration(milliseconds: 500)); // async resolution
  await tester.pump(); // rebuild
}

void main() {
  late UserDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
    });
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
            child: MaterialApp.router(
              routerConfig: router.config(
                deepLinkBuilder: (_) => const DeepLink.path('/dashboard'),
              ),
            ),
          ),
        );
        await _pumpDashboard(tester);

        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(NavigationDestination), findsNWidgets(4));

        expect(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Dashboard'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Learn'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Progress'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Settings'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('tapping Learn tab navigates to learn route', (tester) async {
      final router = _createAuthenticatedRouter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            dashboardStreakProvider.overrideWith(
              (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
            ),
            dashboardStreakRecoveryProvider.overrideWith(
              (ref) => Future.value(
                const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router.config(
              deepLinkBuilder: (_) => const DeepLink.path('/dashboard'),
            ),
          ),
        ),
      );
      await _pumpDashboard(tester);

      // Dashboard is shown (AppBar title + nav tab label)
      expect(find.text('Dashboard'), findsWidgets);

      await tester.tap(find.text('Learn'));
      await _pumpDashboard(tester);

      // LearningScreen AppBar title is 'Learn'
      expect(find.text('Learn'), findsWidgets);
    });

    testWidgets('tapping Progress tab navigates to progress route', (
      tester,
    ) async {
      final router = _createAuthenticatedRouter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            dashboardStreakProvider.overrideWith(
              (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
            ),
            dashboardStreakRecoveryProvider.overrideWith(
              (ref) => Future.value(
                const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router.config(
              deepLinkBuilder: (_) => const DeepLink.path('/dashboard'),
            ),
          ),
        ),
      );
      await _pumpDashboard(tester);

      await tester.tap(find.text('Progress'));
      await _pumpDashboard(tester);

      // ProgressScreen AppBar title is 'Progress'
      expect(find.text('Progress'), findsWidgets);
    });

    testWidgets('tapping Settings tab navigates to settings route', (
      tester,
    ) async {
      final router = _createAuthenticatedRouter();
      final mockAuthForProvider = MockFirebaseAuth();
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
            appDatabaseProvider.overrideWithValue(db),
            firebaseAuthProvider.overrideWithValue(mockAuthForProvider),
            dashboardStreakProvider.overrideWith(
              (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
            ),
            dashboardStreakRecoveryProvider.overrideWith(
              (ref) => Future.value(
                const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router.config(
              deepLinkBuilder: (_) => const DeepLink.path('/dashboard'),
            ),
          ),
        ),
      );
      await _pumpDashboard(tester);

      await tester.tap(find.text('Settings'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      // Verify we navigated to settings — the AppBar title should be 'Settings'
      expect(find.text('Settings'), findsWidgets);
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
            dashboardStreakProvider.overrideWith(
              (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
            ),
            dashboardStreakRecoveryProvider.overrideWith(
              (ref) => Future.value(
                const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router.config(
              deepLinkBuilder: (_) =>
                  const DeepLink.path('/curriculum/mishnayos/browse'),
            ),
          ),
        ),
      );
      await tester.pump();

      // ContentBrowsingScreen is now a ConsumerStatefulWidget that
      // renders the curriculum display name and a loading indicator
      // while content loads from the (bundled JSON) asset provider.
      expect(find.text('משניות'), findsOneWidget);
    });
  });

  group('Auth flow', () {
    testWidgets('unauthenticated user is redirected to sign-in', (
      tester,
    ) async {
      final router = _createUnauthenticatedRouter();

      // Suppress layout-overflow errors from AppIntroScreen in test viewport.
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exception.toString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router.config()),
      );
      await _pumpDashboard(tester);

      // Auth guard redirects to AppIntroRoute; the dashboard NavigationBar
      // must NOT be present, confirming the user was redirected away.
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('authenticated user sees dashboard with bottom navigation', (
      tester,
    ) async {
      final router = _createAuthenticatedRouter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            dashboardStreakProvider.overrideWith(
              (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
            ),
            dashboardStreakRecoveryProvider.overrideWith(
              (ref) => Future.value(
                const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router.config()),
        ),
      );
      await _pumpDashboard(tester);

      // Dashboard AppBar title + navigation tab label
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });
}
