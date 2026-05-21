import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/auth/auth_gateway_user.dart';
import 'package:learning_tracker/core/auth/firebase_auth_gateway.dart';
import 'package:learning_tracker/core/auth/google_sign_in_gateway.dart';
import 'package:learning_tracker/features/account/data/repositories/auth_repository_impl.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────
// We mock the gateway interfaces, NOT the Firebase SDK directly. After the
// core/auth refactor `AuthRepositoryImpl` no longer touches FirebaseAuth or
// GoogleSignIn — it composes the gateways instead, so the tests follow suit.
class MockFirebaseAuthGateway extends Mock implements FirebaseAuthGateway {}

class MockGoogleSignInGateway extends Mock implements GoogleSignInGateway {}

AuthGatewayUser _sampleUser({
  String uid = 'test-uid',
  String? email = 'user@example.com',
  String? displayName,
  bool emailVerified = false,
  List<String> providers = const <String>[],
}) => AuthGatewayUser(
  uid: uid,
  email: email,
  displayName: displayName,
  emailVerified: emailVerified,
  providers: providers,
);

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

  group('signInWithEmail', () {
    test('delegates to the gateway with the same email/password', () async {
      when(
        () => mockAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        ),
      ).thenAnswer((_) async {});

      await repository.signInWithEmail('test@example.com', 'password123');

      verify(
        () => mockAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        ),
      ).called(1);
    });
  });

  group('signUp', () {
    test(
      'creates the user via the gateway and updates the display name',
      () async {
        when(
          () => mockAuth.createUserWithEmailAndPassword(
            email: 'new@example.com',
            password: 'newpass123',
          ),
        ).thenAnswer((_) async => 'new-uid');
        when(
          () => mockAuth.updateDisplayName('Test User'),
        ).thenAnswer((_) async {});

        await repository.signUp('new@example.com', 'newpass123', 'Test User');

        verify(
          () => mockAuth.createUserWithEmailAndPassword(
            email: 'new@example.com',
            password: 'newpass123',
          ),
        ).called(1);
        verify(() => mockAuth.updateDisplayName('Test User')).called(1);
      },
    );

    test('rethrows when the gateway rejects the email', () async {
      when(
        () => mockAuth.createUserWithEmailAndPassword(
          email: 'not-an-email',
          password: 'password123',
        ),
      ).thenThrow(StateError('invalid-email'));

      expect(
        () => repository.signUp('not-an-email', 'password123', 'Test'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('signInWithGoogle', () {
    test(
      'runs Google flow then exchanges the id-token via the gateway',
      () async {
        when(
          () => mockGoogle.authenticate(),
        ).thenAnswer((_) async => const GoogleSignInResult(idToken: 'tok-1'));
        when(
          () => mockAuth.signInWithGoogleIdToken(idToken: 'tok-1'),
        ).thenAnswer((_) async {});

        await repository.signInWithGoogle();

        verify(() => mockGoogle.authenticate()).called(1);
        verify(
          () => mockAuth.signInWithGoogleIdToken(idToken: 'tok-1'),
        ).called(1);
      },
    );
  });

  group('sendSignInLinkToEmail', () {
    test('forwards the email + standard continue-url to the gateway', () async {
      when(
        () => mockAuth.sendSignInLinkToEmail(
          email: any(named: 'email'),
          continueUrl: any(named: 'continueUrl'),
          androidPackageName: any(named: 'androidPackageName'),
        ),
      ).thenAnswer((_) async {});

      await repository.sendSignInLinkToEmail('user@example.com');

      final captured = verify(
        () => mockAuth.sendSignInLinkToEmail(
          email: captureAny(named: 'email'),
          continueUrl: captureAny(named: 'continueUrl'),
          androidPackageName: captureAny(named: 'androidPackageName'),
        ),
      ).captured;
      expect(captured[0], 'user@example.com');
      expect(captured[1], contains('sign-in'));
      expect(captured[2], 'com.jcom.torah.learning_tracker');
    });
  });

  group('signInWithEmailLink', () {
    test('returns an AppUser converted from the gateway response', () async {
      when(
        () => mockAuth.signInWithEmailLink(
          email: 'user@example.com',
          emailLink: 'https://example.com/sign-in?oobCode=abc123',
        ),
      ).thenAnswer(
        (_) async => _sampleUser(uid: 'user-uid', email: 'user@example.com'),
      );

      final result = await repository.signInWithEmailLink(
        'user@example.com',
        'https://example.com/sign-in?oobCode=abc123',
      );

      expect(result, isA<AppUser>());
      expect(result?.uid, 'user-uid');
      expect(result?.email, 'user@example.com');
    });

    test('returns null when the gateway returned null', () async {
      when(
        () => mockAuth.signInWithEmailLink(
          email: any(named: 'email'),
          emailLink: any(named: 'emailLink'),
        ),
      ).thenAnswer((_) async => null);

      final result = await repository.signInWithEmailLink('a@b.c', 'link');

      expect(result, isNull);
    });
  });

  group('isSignInWithEmailLink', () {
    test('delegates straight to the gateway', () {
      when(
        () => mockAuth.isSignInWithEmailLink(
          'https://example.com/sign-in?oobCode=abc',
        ),
      ).thenReturn(true);
      when(
        () => mockAuth.isSignInWithEmailLink('https://example.com'),
      ).thenReturn(false);

      expect(
        repository.isSignInWithEmailLink(
          'https://example.com/sign-in?oobCode=abc',
        ),
        isTrue,
      );
      expect(repository.isSignInWithEmailLink('https://example.com'), isFalse);
    });
  });

  group('signOut', () {
    test('signs out both Google and Firebase via the gateways', () async {
      when(() => mockGoogle.signOut()).thenAnswer((_) async {});
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      await repository.signOut();

      verify(() => mockGoogle.signOut()).called(1);
      verify(() => mockAuth.signOut()).called(1);
    });
  });

  group('deleteAccount', () {
    test('asks the gateway to delete the current user', () async {
      when(() => mockAuth.deleteCurrentUser()).thenAnswer((_) async {});

      await repository.deleteAccount();

      verify(() => mockAuth.deleteCurrentUser()).called(1);
    });
  });

  group('changePassword', () {
    test('asks the gateway to update the password', () async {
      when(
        () => mockAuth.updatePassword('newPass123'),
      ).thenAnswer((_) async {});

      await repository.changePassword('newPass123');

      verify(() => mockAuth.updatePassword('newPass123')).called(1);
    });
  });

  group('reauthenticateWithEmail', () {
    test('forwards email + password to the gateway', () async {
      when(
        () => mockAuth.reauthenticateWithEmail(
          email: 'test@example.com',
          password: 'pass123',
        ),
      ).thenAnswer((_) async {});

      await repository.reauthenticateWithEmail('test@example.com', 'pass123');

      verify(
        () => mockAuth.reauthenticateWithEmail(
          email: 'test@example.com',
          password: 'pass123',
        ),
      ).called(1);
    });
  });

  group('linkGoogleProvider', () {
    test('runs Google then links the id-token via the gateway', () async {
      when(
        () => mockGoogle.authenticate(),
      ).thenAnswer((_) async => const GoogleSignInResult(idToken: 'tok-link'));
      when(
        () => mockAuth.linkWithGoogleIdToken(idToken: 'tok-link'),
      ).thenAnswer((_) async {});

      await repository.linkGoogleProvider();

      verify(() => mockGoogle.authenticate()).called(1);
      verify(
        () => mockAuth.linkWithGoogleIdToken(idToken: 'tok-link'),
      ).called(1);
    });
  });

  group('linkEmailProvider', () {
    test('forwards email + password to the gateway', () async {
      when(
        () => mockAuth.linkWithEmailAndPassword(
          email: 'test@example.com',
          password: 'pass123',
        ),
      ).thenAnswer((_) async {});

      await repository.linkEmailProvider('test@example.com', 'pass123');

      verify(
        () => mockAuth.linkWithEmailAndPassword(
          email: 'test@example.com',
          password: 'pass123',
        ),
      ).called(1);
    });
  });

  group('getLinkedProviders', () {
    test('returns whatever the gateway returns', () {
      when(
        () => mockAuth.getLinkedProviders(),
      ).thenReturn(['password', 'google.com']);

      expect(repository.getLinkedProviders(), ['password', 'google.com']);
    });

    test('returns an empty list when the gateway has nobody signed in', () {
      when(() => mockAuth.getLinkedProviders()).thenReturn(const <String>[]);

      expect(repository.getLinkedProviders(), isEmpty);
    });
  });

  group('onAuthStateChanged', () {
    test('emits null when the gateway stream emits null', () async {
      when(
        () => mockAuth.authStateChanges(),
      ).thenAnswer((_) => Stream<AuthGatewayUser?>.value(null));

      final stream = repository.onAuthStateChanged();

      await expectLater(stream, emits(isNull));
    });

    test('emits a mapped AppUser when the gateway emits a user', () async {
      when(() => mockAuth.authStateChanges()).thenAnswer(
        (_) => Stream<AuthGatewayUser?>.value(
          _sampleUser(uid: 'state-uid', emailVerified: true),
        ),
      );

      final stream = repository.onAuthStateChanged();

      await expectLater(
        stream,
        emits(
          isA<AppUser>()
              .having((u) => u.uid, 'uid', 'state-uid')
              .having((u) => u.emailVerified, 'emailVerified', true),
        ),
      );
    });
  });

  group('currentUser', () {
    test('maps the gateway snapshot to AppUser', () {
      when(() => mockAuth.currentUser).thenReturn(
        _sampleUser(
          uid: 'current-uid',
          displayName: 'Daniel',
          providers: const ['password'],
        ),
      );

      final user = repository.currentUser;

      expect(user?.uid, 'current-uid');
      expect(user?.displayName, 'Daniel');
      expect(user?.providers, ['password']);
    });

    test('returns null when no user is signed in', () {
      when(() => mockAuth.currentUser).thenReturn(null);

      expect(repository.currentUser, isNull);
    });
  });

  group('reloadCurrentUser', () {
    test('returns the refreshed AppUser from the gateway', () async {
      when(() => mockAuth.reloadCurrentUser()).thenAnswer(
        (_) async => _sampleUser(uid: 'refreshed-uid', emailVerified: true),
      );

      final user = await repository.reloadCurrentUser();

      expect(user?.uid, 'refreshed-uid');
      expect(user?.emailVerified, isTrue);
    });

    test('returns null when no user is signed in', () async {
      when(() => mockAuth.reloadCurrentUser()).thenAnswer((_) async => null);

      expect(await repository.reloadCurrentUser(), isNull);
    });
  });

  group('action codes', () {
    test('checkActionCode delegates to the gateway', () async {
      when(() => mockAuth.checkActionCode('oob')).thenAnswer((_) async {});

      await repository.checkActionCode('oob');

      verify(() => mockAuth.checkActionCode('oob')).called(1);
    });

    test('applyActionCode delegates to the gateway', () async {
      when(() => mockAuth.applyActionCode('oob')).thenAnswer((_) async {});

      await repository.applyActionCode('oob');

      verify(() => mockAuth.applyActionCode('oob')).called(1);
    });
  });

  group('createUserAccount', () {
    test('returns the UID provided by the gateway', () async {
      when(
        () => mockAuth.createUserWithEmailAndPassword(
          email: 'a@b.c',
          password: 'pw',
        ),
      ).thenAnswer((_) async => 'fresh-uid');

      expect(await repository.createUserAccount('a@b.c', 'pw'), 'fresh-uid');
    });
  });

  group('signInAndGetUser', () {
    test('maps the gateway response to AppUser', () async {
      when(
        () => mockAuth.signInAndGetUser(email: 'a@b.c', password: 'pw'),
      ).thenAnswer((_) async => _sampleUser(uid: 'sign-in-uid'));

      final user = await repository.signInAndGetUser('a@b.c', 'pw');

      expect(user?.uid, 'sign-in-uid');
    });

    test('returns null when the gateway returns null', () async {
      when(
        () => mockAuth.signInAndGetUser(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => null);

      expect(await repository.signInAndGetUser('a@b.c', 'pw'), isNull);
    });
  });

  group('updateDisplayName', () {
    test('delegates to the gateway', () async {
      when(() => mockAuth.updateDisplayName('Daniel')).thenAnswer((_) async {});

      await repository.updateDisplayName('Daniel');

      verify(() => mockAuth.updateDisplayName('Daniel')).called(1);
    });
  });

  group('deleteCurrentFirebaseUser', () {
    test('asks the gateway to delete when a user is signed in', () async {
      when(() => mockAuth.currentUser).thenReturn(_sampleUser(uid: 'will-die'));
      when(() => mockAuth.deleteCurrentUser()).thenAnswer((_) async {});

      await repository.deleteCurrentFirebaseUser();

      verify(() => mockAuth.deleteCurrentUser()).called(1);
    });

    test('is a no-op when no user is signed in', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      await repository.deleteCurrentFirebaseUser();

      verifyNever(() => mockAuth.deleteCurrentUser());
    });
  });
}
