import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/navigation/guards/auth_guard.dart';
import 'package:learning_tracker/core/navigation/guards/parent_pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/tutor_pin_guard.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

AppRouter _createAuthenticatedRouter() {
  final mockAuth = MockFirebaseAuth();
  when(() => mockAuth.currentUser).thenReturn(MockUser());
  return AppRouter(
    authGuard: AuthGuard(firebaseAuth: mockAuth),
    parentPinGuard: ParentPinGuard(
      isPinVerified: () => false,
      promptForPin: () async => false,
    ),
    tutorPinGuard: TutorPinGuard(
      isPinVerified: () => false,
      promptForPin: () async => false,
    ),
  );
}

AppRouter _createUnauthenticatedRouter() {
  final mockAuth = MockFirebaseAuth();
  when(() => mockAuth.currentUser).thenReturn(null);
  return AppRouter(
    authGuard: AuthGuard(firebaseAuth: mockAuth),
    parentPinGuard: ParentPinGuard(
      isPinVerified: () => false,
      promptForPin: () async => false,
    ),
    tutorPinGuard: TutorPinGuard(
      isPinVerified: () => false,
      promptForPin: () async => false,
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
        MaterialApp.router(
          routerConfig: router.config(
            deepLinkBuilder: (_) => const DeepLink.path('/dashboard'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Settings Screen'), findsOneWidget);
    });
  });

  group('Curriculum-scoped routes', () {
    testWidgets('content browsing route accepts curriculumId parameter', (
      tester,
    ) async {
      final router = _createAuthenticatedRouter();

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router.config(
            deepLinkBuilder: (_) =>
                const DeepLink.path('/curriculum/test-curriculum/browse'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Content Browsing: test-curriculum'), findsOneWidget);
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
