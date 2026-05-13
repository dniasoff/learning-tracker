import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:learning_tracker/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:learning_tracker/features/auth/domain/models/app_user.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockGoogleSignInAuthentication extends Mock
    implements GoogleSignInAuthentication {}

class FakeAuthCredential extends Fake implements AuthCredential {}

class MockUserInfo extends Mock implements UserInfo {}

class FakeActionCodeSettings extends Fake implements ActionCodeSettings {}

void main() {
  late MockFirebaseAuth mockFirebaseAuth;
  late MockGoogleSignIn mockGoogleSignIn;
  late AuthRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(FakeAuthCredential());
    registerFallbackValue(FakeActionCodeSettings());
  });

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockGoogleSignIn = MockGoogleSignIn();
    when(() => mockGoogleSignIn.initialize()).thenAnswer((_) async {});
    repository = AuthRepositoryImpl(
      firebaseAuth: mockFirebaseAuth,
      googleSignIn: mockGoogleSignIn,
    );
  });

  group('signInWithEmail', () {
    test(
      'calls FirebaseAuth.signInWithEmailAndPassword with correct email and password',
      () async {
        final mockCredential = MockUserCredential();
        when(
          () => mockFirebaseAuth.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'password123',
          ),
        ).thenAnswer((_) async => mockCredential);

        // signInWithEmail now returns void
        await repository.signInWithEmail('test@example.com', 'password123');

        verify(
          () => mockFirebaseAuth.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'password123',
          ),
        ).called(1);
      },
    );
  });

  group('signUp', () {
    test(
      'calls FirebaseAuth.createUserWithEmailAndPassword and sets display name',
      () async {
        final mockCredential = MockUserCredential();
        final mockUser = MockUser();
        when(() => mockCredential.user).thenReturn(mockUser);
        when(
          () => mockFirebaseAuth.createUserWithEmailAndPassword(
            email: 'new@example.com',
            password: 'newpass123',
          ),
        ).thenAnswer((_) async => mockCredential);
        when(
          () => mockUser.updateDisplayName('Test User'),
        ).thenAnswer((_) async {});

        // signUp now returns void
        await repository.signUp('new@example.com', 'newpass123', 'Test User');

        verify(
          () => mockFirebaseAuth.createUserWithEmailAndPassword(
            email: 'new@example.com',
            password: 'newpass123',
          ),
        ).called(1);
        verify(() => mockUser.updateDisplayName('Test User')).called(1);
      },
    );
  });

  group('signUp error handling', () {
    test(
      'sign-up with invalid email format returns appropriate error',
      () async {
        when(
          () => mockFirebaseAuth.createUserWithEmailAndPassword(
            email: 'not-an-email',
            password: 'password123',
          ),
        ).thenThrow(
          FirebaseAuthException(
            code: 'invalid-email',
            message: 'The email address is badly formatted.',
          ),
        );

        expect(
          () => repository.signUp('not-an-email', 'password123', 'Test'),
          throwsA(
            isA<FirebaseAuthException>().having(
              (e) => e.code,
              'code',
              'invalid-email',
            ),
          ),
        );
      },
    );
  });

  group('signInWithGoogle', () {
    test(
      'triggers Google Sign-In flow and exchanges credential with Firebase',
      () async {
        final mockAccount = MockGoogleSignInAccount();
        final mockAuth = MockGoogleSignInAuthentication();
        final mockCredential = MockUserCredential();

        when(
          () => mockGoogleSignIn.authenticate(),
        ).thenAnswer((_) async => mockAccount);
        when(() => mockAccount.authentication).thenReturn(mockAuth);
        when(() => mockAuth.idToken).thenReturn('test-id-token');
        when(
          () => mockFirebaseAuth.signInWithCredential(any()),
        ).thenAnswer((_) async => mockCredential);

        // signInWithGoogle now returns void
        await repository.signInWithGoogle();

        verify(() => mockGoogleSignIn.authenticate()).called(1);
        verify(() => mockFirebaseAuth.signInWithCredential(any())).called(1);
      },
    );
  });

  group('sendSignInLinkToEmail', () {
    test(
      'calls FirebaseAuth.sendSignInLinkToEmail with correct email and ActionCodeSettings',
      () async {
        when(
          () => mockFirebaseAuth.sendSignInLinkToEmail(
            email: any(named: 'email'),
            actionCodeSettings: any(named: 'actionCodeSettings'),
          ),
        ).thenAnswer((_) async {});

        await repository.sendSignInLinkToEmail('user@example.com');

        verify(
          () => mockFirebaseAuth.sendSignInLinkToEmail(
            email: 'user@example.com',
            actionCodeSettings: any(named: 'actionCodeSettings'),
          ),
        ).called(1);
      },
    );
  });

  group('signInWithEmailLink', () {
    test(
      'calls FirebaseAuth.signInWithEmailLink and returns AppUser?',
      () async {
        final mockCredential = MockUserCredential();
        final mockUser = MockUser();
        when(() => mockCredential.user).thenReturn(mockUser);
        when(() => mockUser.uid).thenReturn('user-uid');
        when(() => mockUser.email).thenReturn('user@example.com');
        when(() => mockUser.displayName).thenReturn(null);
        when(() => mockUser.emailVerified).thenReturn(false);
        when(() => mockUser.providerData).thenReturn([]);
        when(
          () => mockFirebaseAuth.signInWithEmailLink(
            email: 'user@example.com',
            emailLink: 'https://example.com/sign-in?oobCode=abc123',
          ),
        ).thenAnswer((_) async => mockCredential);

        final result = await repository.signInWithEmailLink(
          'user@example.com',
          'https://example.com/sign-in?oobCode=abc123',
        );

        expect(result, isA<AppUser>());
        expect(result?.uid, equals('user-uid'));
        verify(
          () => mockFirebaseAuth.signInWithEmailLink(
            email: 'user@example.com',
            emailLink: 'https://example.com/sign-in?oobCode=abc123',
          ),
        ).called(1);
      },
    );
  });

  group('isSignInWithEmailLink', () {
    test('correctly validates incoming deep links', () {
      when(
        () => mockFirebaseAuth.isSignInWithEmailLink(
          'https://example.com/sign-in?oobCode=abc123',
        ),
      ).thenReturn(true);
      when(
        () => mockFirebaseAuth.isSignInWithEmailLink('https://example.com'),
      ).thenReturn(false);

      expect(
        repository.isSignInWithEmailLink(
          'https://example.com/sign-in?oobCode=abc123',
        ),
        isTrue,
      );
      expect(repository.isSignInWithEmailLink('https://example.com'), isFalse);
    });
  });

  group('signOut', () {
    test('calls FirebaseAuth.signOut and GoogleSignIn.signOut', () async {
      when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async {});
      when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {});

      await repository.signOut();

      verify(() => mockGoogleSignIn.signOut()).called(1);
      verify(() => mockFirebaseAuth.signOut()).called(1);
    });
  });

  group('deleteAccount', () {
    test('calls FirebaseAuth.currentUser.delete()', () async {
      final mockUser = MockUser();
      when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.delete()).thenAnswer((_) async {});

      await repository.deleteAccount();

      verify(() => mockUser.delete()).called(1);
    });
  });

  group('changePassword', () {
    test('calls currentUser.updatePassword with new password', () async {
      final mockUser = MockUser();
      when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
      when(
        () => mockUser.updatePassword('newPass123'),
      ).thenAnswer((_) async {});

      await repository.changePassword('newPass123');

      verify(() => mockUser.updatePassword('newPass123')).called(1);
    });
  });

  group('reauthenticateWithEmail', () {
    test('creates EmailAuthProvider credential and reauthenticates', () async {
      final mockUser = MockUser();
      final mockCredential = MockUserCredential();
      when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
      when(
        () => mockUser.reauthenticateWithCredential(any()),
      ).thenAnswer((_) async => mockCredential);

      await repository.reauthenticateWithEmail('test@example.com', 'pass123');

      verify(() => mockUser.reauthenticateWithCredential(any())).called(1);
    });
  });

  group('linkGoogleProvider', () {
    test(
      'triggers Google Sign-In and links credential to current user',
      () async {
        final mockUser = MockUser();
        final mockAccount = MockGoogleSignInAccount();
        final mockAuth = MockGoogleSignInAuthentication();
        final mockCredential = MockUserCredential();

        when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(
          () => mockGoogleSignIn.authenticate(),
        ).thenAnswer((_) async => mockAccount);
        when(() => mockAccount.authentication).thenReturn(mockAuth);
        when(() => mockAuth.idToken).thenReturn('test-id-token');
        when(
          () => mockUser.linkWithCredential(any()),
        ).thenAnswer((_) async => mockCredential);

        await repository.linkGoogleProvider();

        verify(() => mockUser.linkWithCredential(any())).called(1);
      },
    );
  });

  group('linkEmailProvider', () {
    test(
      'creates EmailAuthProvider credential and links to current user',
      () async {
        final mockUser = MockUser();
        final mockCredential = MockUserCredential();
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(
          () => mockUser.linkWithCredential(any()),
        ).thenAnswer((_) async => mockCredential);

        await repository.linkEmailProvider('test@example.com', 'pass123');

        verify(() => mockUser.linkWithCredential(any())).called(1);
      },
    );
  });

  group('getLinkedProviders', () {
    test('returns list of provider IDs from current user', () {
      final mockUser = MockUser();
      final mockProviderInfo1 = MockUserInfo();
      final mockProviderInfo2 = MockUserInfo();
      when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
      when(
        () => mockUser.providerData,
      ).thenReturn([mockProviderInfo1, mockProviderInfo2]);
      when(() => mockProviderInfo1.providerId).thenReturn('password');
      when(() => mockProviderInfo2.providerId).thenReturn('google.com');

      final providers = repository.getLinkedProviders();

      expect(providers, ['password', 'google.com']);
    });

    test('returns empty list when no current user', () {
      when(() => mockFirebaseAuth.currentUser).thenReturn(null);

      final providers = repository.getLinkedProviders();

      expect(providers, isEmpty);
    });
  });

  group('onAuthStateChanged', () {
    test('emits null when user is signed out', () async {
      when(
        () => mockFirebaseAuth.authStateChanges(),
      ).thenAnswer((_) => Stream.value(null));

      final stream = repository.onAuthStateChanged();

      await expectLater(stream, emits(isNull));
    });

    test('emits AppUser when user is signed in', () async {
      final mockUser = MockUser();
      when(() => mockUser.uid).thenReturn('test-uid');
      when(() => mockUser.email).thenReturn('test@example.com');
      when(() => mockUser.displayName).thenReturn('Test User');
      when(() => mockUser.emailVerified).thenReturn(true);
      when(() => mockUser.providerData).thenReturn([]);
      when(
        () => mockFirebaseAuth.authStateChanges(),
      ).thenAnswer((_) => Stream.value(mockUser));

      final stream = repository.onAuthStateChanged();

      await expectLater(stream, emits(isA<AppUser>()));
    });
  });
}
