import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/auth/auth_gateway_user.dart';
import 'package:learning_tracker/core/auth/firebase_auth_gateway.dart';
import 'package:learning_tracker/core/auth/google_sign_in_gateway.dart';
import 'package:learning_tracker/features/account/data/repositories/auth_repository_impl.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuthGateway extends Mock implements FirebaseAuthGateway {}

class MockGoogleSignInGateway extends Mock implements GoogleSignInGateway {}

void main() {
  late MockFirebaseAuthGateway mockAuth;
  late MockGoogleSignInGateway mockGoogle;
  late AuthRepositoryImpl repository;

  setUp(() {
    mockAuth = MockFirebaseAuthGateway();
    mockGoogle = MockGoogleSignInGateway();
    repository = AuthRepositoryImpl(
      firebaseAuthGateway: mockAuth,
      googleSignInGateway: mockGoogle,
    );
  });

  test(
    'sign in with email then sign out, end-to-end through the gateway',
    () async {
      // Auth-state stream emits a user on sign-in, then null on sign-out.
      // The repository should map both into AppUser? / null.
      final authStateController = StreamController<AuthGatewayUser?>();

      const fakeUser = AuthGatewayUser(
        uid: 'test-uid-123',
        email: 'test@example.com',
        displayName: 'Test User',
        emailVerified: true,
        providers: <String>[],
      );

      when(
        () => mockAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        ),
      ).thenAnswer((_) async {
        authStateController.add(fakeUser);
      });

      when(() => mockGoogle.signOut()).thenAnswer((_) async {});
      when(() => mockAuth.signOut()).thenAnswer((_) async {
        authStateController.add(null);
      });

      when(
        () => mockAuth.authStateChanges(),
      ).thenAnswer((_) => authStateController.stream);

      // Start listening to auth state via the public API
      final authStates = <AppUser?>[];
      final subscription = repository.onAuthStateChanged().listen(
        authStates.add,
      );

      // Step 1 — sign in
      await repository.signInWithEmail('test@example.com', 'password123');
      await Future<void>.delayed(Duration.zero);

      expect(authStates, contains(isA<AppUser>()));
      final signedIn = authStates.whereType<AppUser>().first;
      expect(signedIn.uid, 'test-uid-123');
      expect(signedIn.email, 'test@example.com');
      expect(signedIn.emailVerified, isTrue);

      // Step 2 — sign out
      await repository.signOut();
      await Future<void>.delayed(Duration.zero);

      expect(authStates.last, isNull);

      await subscription.cancel();
      await authStateController.close();
    },
  );
}
