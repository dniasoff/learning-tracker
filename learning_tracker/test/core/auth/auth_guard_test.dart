import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/navigation/guards/auth_guard.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockNavigationResolver extends Mock implements NavigationResolver {}

class MockStackRouter extends Mock implements StackRouter {}

void main() {
  late MockFirebaseAuth mockFirebaseAuth;
  late AuthGuard authGuard;
  late MockNavigationResolver mockResolver;
  late MockStackRouter mockRouter;

  setUpAll(() {
    registerFallbackValue(const SignInRoute());
  });

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    authGuard = AuthGuard(firebaseAuth: mockFirebaseAuth);
    mockResolver = MockNavigationResolver();
    mockRouter = MockStackRouter();

    when(() => mockResolver.next(any())).thenReturn(null);
    when(() => mockResolver.next()).thenReturn(null);
  });

  group('AuthGuard', () {
    test('allows navigation when auth state has valid user', () async {
      final mockUser = MockUser();
      when(
        () => mockFirebaseAuth.authStateChanges(),
      ).thenAnswer((_) => Stream.value(mockUser));

      await authGuard.onNavigation(mockResolver, mockRouter);

      verify(() => mockResolver.next()).called(1);
      verifyNever(() => mockRouter.replace(any()));
    });

    test('redirects to sign-in route when auth state is null', () async {
      when(
        () => mockFirebaseAuth.authStateChanges(),
      ).thenAnswer((_) => Stream.value(null));
      when(() => mockRouter.replace(any())).thenAnswer((_) async => null);

      await authGuard.onNavigation(mockResolver, mockRouter);

      verify(() => mockRouter.replace(any())).called(1);
      verify(() => mockResolver.next(false)).called(1);
    });
  });
}
