import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/navigation/guards/auth_guard.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockNavigationResolver extends Mock implements NavigationResolver {}

class MockStackRouter extends Mock implements StackRouter {}

void main() {
  late AuthGuard authGuard;
  late MockNavigationResolver mockResolver;
  late MockStackRouter mockRouter;

  setUpAll(() {
    registerFallbackValue(const AppIntroRoute());
    registerFallbackValue(const WelcomeRoute());
  });

  setUp(() {
    authGuard = AuthGuard();
    mockResolver = MockNavigationResolver();
    mockRouter = MockStackRouter();

    when(() => mockResolver.next(any())).thenReturn(null);
    when(() => mockResolver.next()).thenReturn(null);
    when(() => mockRouter.replace(any())).thenAnswer((_) async => null);
  });

  group('AuthGuard', () {
    test('allows navigation when onboarding is complete', () async {
      SharedPreferences.setMockInitialValues({'onboarding_complete': true});

      await authGuard.onNavigation(mockResolver, mockRouter);

      verify(() => mockResolver.next()).called(1);
      verifyNever(() => mockRouter.replace(any()));
    });

    test('redirects to app intro when onboarding not complete and intro not seen', () async {
      SharedPreferences.setMockInitialValues({});

      await authGuard.onNavigation(mockResolver, mockRouter);

      final captured = verify(() => mockRouter.replace(captureAny())).captured;
      expect(captured.single, isA<AppIntroRoute>());
      verify(() => mockResolver.next(false)).called(1);
    });

    test('redirects to welcome when onboarding not complete but intro already seen', () async {
      SharedPreferences.setMockInitialValues({'intro_seen': true});

      await authGuard.onNavigation(mockResolver, mockRouter);

      final captured = verify(() => mockRouter.replace(captureAny())).captured;
      expect(captured.single, isA<WelcomeRoute>());
      verify(() => mockResolver.next(false)).called(1);
    });
  });
}
