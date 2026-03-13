import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/navigation/guards/auth_guard.dart';
import 'package:learning_tracker/core/navigation/guards/parent_pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/tutor_pin_guard.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockPinService extends Mock implements PinService {}

AppRouter _createAuthenticatedRouter() {
  final mockAuth = MockFirebaseAuth();
  final mockUser = MockUser();
  when(
    () => mockAuth.authStateChanges(),
  ).thenAnswer((_) => Stream.value(mockUser));

  final mockPinService = MockPinService();
  when(() => mockPinService.hasParentPin()).thenAnswer((_) async => false);
  when(() => mockPinService.hasTutorPin()).thenAnswer((_) async => false);

  return AppRouter(
    authGuard: AuthGuard(firebaseAuth: mockAuth),
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
  final mockAuth = MockFirebaseAuth();
  when(
    () => mockAuth.authStateChanges(),
  ).thenAnswer((_) => Stream.value(null));

  final mockPinService = MockPinService();
  when(() => mockPinService.hasParentPin()).thenAnswer((_) async => false);
  when(() => mockPinService.hasTutorPin()).thenAnswer((_) async => false);

  return AppRouter(
    authGuard: AuthGuard(firebaseAuth: mockAuth),
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

void main() {
  group('AppShellScreen bottom navigation', () {
    testWidgets(
      'renders exactly 4 tabs: Dashboard, Learn, Progress, Settings',
      (tester) async {
        final router = _createAuthenticatedRouter();

        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router.config(
              deepLinkBuilder: (_) => const DeepLink.path('/dashboard'),
            ),
          ),
        );
        await tester.pumpAndSettle();

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
        MaterialApp.router(
          routerConfig: router.config(
            deepLinkBuilder: (_) => const DeepLink.path('/dashboard'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dashboard Screen'), findsOneWidget);

      await tester.tap(find.text('Learn'));
      await tester.pumpAndSettle();

      expect(find.text('Learning Screen'), findsOneWidget);
    });

    testWidgets('tapping Progress tab navigates to progress route', (
      tester,
    ) async {
      final router = _createAuthenticatedRouter();

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router.config(
            deepLinkBuilder: (_) => const DeepLink.path('/dashboard'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Progress'));
      await tester.pumpAndSettle();

      expect(find.text('Progress Screen'), findsOneWidget);
    });

    testWidgets('tapping Settings tab navigates to settings route', (
      tester,
    ) async {
      final router = _createAuthenticatedRouter();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router.config(
              deepLinkBuilder: (_) => const DeepLink.path('/dashboard'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // SettingsScreen should be displayed with its distinctive content
      expect(find.text('Active Curricula'), findsOneWidget);
    });
  });

  group('Curriculum-scoped routes', () {
    testWidgets('content browsing route accepts curriculumId parameter', (
      tester,
    ) async {
      final router = _createAuthenticatedRouter();

      await tester.pumpWidget(
        ProviderScope(
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
      expect(find.text('Mishnayos'), findsOneWidget);
    });
  });

  group('Auth flow', () {
    testWidgets('unauthenticated user is redirected to sign-in', (
      tester,
    ) async {
      final router = _createUnauthenticatedRouter();

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router.config()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign In Screen'), findsOneWidget);
    });

    testWidgets('authenticated user sees dashboard with bottom navigation', (
      tester,
    ) async {
      final router = _createAuthenticatedRouter();

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router.config()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dashboard Screen'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });
}
