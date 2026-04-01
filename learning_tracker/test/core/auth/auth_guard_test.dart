import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/navigation/guards/local_auth_guard.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockNavigationResolver extends Mock implements NavigationResolver {}

class MockStackRouter extends Mock implements StackRouter {}

void main() {
  late LocalAuthGuard authGuard;
  late MockNavigationResolver mockResolver;
  late MockStackRouter mockRouter;

  setUpAll(() {
    registerFallbackValue(const AppIntroRoute());
  });

  setUp(() {
    authGuard = LocalAuthGuard();
    mockResolver = MockNavigationResolver();
    mockRouter = MockStackRouter();

    when(() => mockResolver.next(any())).thenReturn(null);
    when(() => mockResolver.next()).thenReturn(null);
  });

  group('LocalAuthGuard', () {
    test('allows navigation when onboarding is complete', () async {
      SharedPreferences.setMockInitialValues({'onboarding_complete': true});

      await authGuard.onNavigation(mockResolver, mockRouter);

      verify(() => mockResolver.next()).called(1);
      verifyNever(() => mockRouter.replace(any()));
    });

    test('redirects to app intro when onboarding is not complete', () async {
      SharedPreferences.setMockInitialValues({});
      when(() => mockRouter.replace(any())).thenAnswer((_) async => null);

      await authGuard.onNavigation(mockResolver, mockRouter);

      verify(() => mockRouter.replace(any())).called(1);
      verify(() => mockResolver.next(false)).called(1);
    });
  });
}
