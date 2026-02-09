import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:learning_tracker/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

void main() {
  late MockFirebaseAuth mockFirebaseAuth;
  late MockGoogleSignIn mockGoogleSignIn;
  late AuthRepositoryImpl repository;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockGoogleSignIn = MockGoogleSignIn();
    repository = AuthRepositoryImpl(
      firebaseAuth: mockFirebaseAuth,
      googleSignIn: mockGoogleSignIn,
    );
  });

  test(
    'Integration: sign in with email → verify UID is non-null → sign out → verify auth state is null',
    () async {
      // Set up mocks
      final mockCredential = MockUserCredential();
      final mockUser = MockUser();
      when(() => mockCredential.user).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('test-uid-123');

      // Auth state stream: emits user on sign-in, then null on sign-out
      final authStateController = StreamController<User?>();

      when(
        () => mockFirebaseAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        ),
      ).thenAnswer((_) async {
        authStateController.add(mockUser);
        return mockCredential;
      });

      when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async {});
      when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {
        authStateController.add(null);
      });

      when(
        () => mockFirebaseAuth.authStateChanges(),
      ).thenAnswer((_) => authStateController.stream);

      // Start listening to auth state
      final authStates = <User?>[];
      final subscription = repository.authStateChanges().listen(authStates.add);

      // Step 1: Sign in with email/password
      final credential = await repository.signInWithEmail(
        'test@example.com',
        'password123',
      );

      // Step 2: Verify UID is non-null
      expect(credential.user, isNotNull);
      expect(credential.user!.uid, equals('test-uid-123'));

      // Allow stream to process
      await Future<void>.delayed(Duration.zero);
      expect(authStates, contains(isA<User>()));

      // Step 3: Sign out
      await repository.signOut();

      // Allow stream to process
      await Future<void>.delayed(Duration.zero);

      // Step 4: Verify auth state is null
      expect(authStates.last, isNull);

      await subscription.cancel();
      await authStateController.close();
    },
  );
}
