import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/auth/account_auth_gateway.dart';
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

class MockAccountAuthGateway extends Mock implements AccountAuthGateway {}

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
  late MockAccountAuthGateway mockAccounts;
  late AuthRepositoryImpl repository;

  setUp(() {
    mockAuth = MockFirebaseAuthGateway();
    mockGoogle = MockGoogleSignInGateway();
    mockAccounts = MockAccountAuthGateway();
    repository = AuthRepositoryImpl(
      accountAuthGateway: mockAccounts,
      firebaseAuthGateway: mockAuth,
      googleSignInGateway: mockGoogle,
      accountId: 'acc-1',
    );
  });

  // DNI-520 (AC-1/AC-2/AC-3): every sign-in names its account and runs on
  // that account's named app through AccountAuthGateway — never the bound
  // (active) gateway, never the default app.
  group('named-app sign-in (DNI-520)', () {
    test(
      'signInToAccountWithEmail signs in on the named account only',
      () async {
        when(
          () => mockAccounts.signInWithEmail(
            'acc-9',
            email: 'a@b.c',
            password: 'pw',
          ),
        ).thenAnswer((_) async => _sampleUser(uid: 'uid-9'));

        final user = await repository.signInToAccountWithEmail(
          'acc-9',
          'a@b.c',
          'pw',
        );

        expect(user.uid, 'uid-9');
        verifyZeroInteractions(mockAuth);
      },
    );

    test(
      'pickGoogleAccount runs only the Google picker — no Firebase sign-in',
      () async {
        when(() => mockGoogle.authenticate()).thenAnswer(
          (_) async => const GoogleSignInResult(idToken: 'tok', email: 'g@x.y'),
        );

        final pick = await repository.pickGoogleAccount();

        expect(pick.idToken, 'tok');
        expect(pick.email, 'g@x.y');
        verifyZeroInteractions(mockAuth);
        verifyZeroInteractions(mockAccounts);
      },
    );

    test(
      'pickGoogleAccountSilently returns null without a cached token',
      () async {
        when(
          () => mockGoogle.authenticateSilently(),
        ).thenAnswer((_) async => null);

        expect(await repository.pickGoogleAccountSilently(), isNull);
      },
    );

    test(
      'signInToAccountWithGoogle signs the named account in with the token',
      () async {
        when(
          () => mockAccounts.signInWithGoogleIdToken('acc-9', idToken: 'tok'),
        ).thenAnswer((_) async => _sampleUser(uid: 'uid-g'));

        final user = await repository.signInToAccountWithGoogle('acc-9', 'tok');

        expect(user.uid, 'uid-g');
      },
    );

    test(
      'createAccountWithEmail signs up on the named account with the display name',
      () async {
        when(
          () => mockAccounts.createUserWithEmail(
            'acc-new',
            email: 'n@x.y',
            password: 'pw',
            displayName: 'Name',
          ),
        ).thenAnswer((_) async => _sampleUser(uid: 'uid-new'));

        final user = await repository.createAccountWithEmail(
          'acc-new',
          'n@x.y',
          'pw',
          'Name',
        );

        expect(user.uid, 'uid-new');
      },
    );

    test(
      'ensureAnonymousSession creates the AD-19 anonymous session',
      () async {
        when(
          () => mockAccounts.ensureAnonymousSession('acc-local'),
        ).thenAnswer((_) async => _sampleUser(uid: 'anon-uid'));

        final user = await repository.ensureAnonymousSession('acc-local');

        expect(user.uid, 'anon-uid');
      },
    );

    test(
      'restoreSession returns null when the account has no session',
      () async {
        when(
          () => mockAccounts.restoreSession('acc-x'),
        ).thenAnswer((_) async => null);

        expect(await repository.restoreSession('acc-x'), isNull);
      },
    );

    test(
      'linkEmailProvider links on the BOUND account via linkCredential',
      () async {
        when(
          () => mockAccounts.linkEmail('acc-1', email: 'a@b.c', password: 'pw'),
        ).thenAnswer((_) async => _sampleUser(uid: 'same-uid'));

        await repository.linkEmailProvider('a@b.c', 'pw');

        verify(
          () => mockAccounts.linkEmail('acc-1', email: 'a@b.c', password: 'pw'),
        ).called(1);
      },
    );

    test(
      'linkGoogleProvider runs Google then links on the bound account',
      () async {
        when(
          () => mockGoogle.authenticate(),
        ).thenAnswer((_) async => const GoogleSignInResult(idToken: 'tok'));
        when(
          () => mockAccounts.linkGoogleIdToken('acc-1', idToken: 'tok'),
        ).thenAnswer((_) async => _sampleUser(uid: 'same-uid'));

        await repository.linkGoogleProvider();

        verify(
          () => mockAccounts.linkGoogleIdToken('acc-1', idToken: 'tok'),
        ).called(1);
      },
    );

    test('forAccount binds the repository to another account\'s named app', () {
      when(() => mockAccounts.gatewayFor('acc-2')).thenReturn(mockAuth);

      final other = repository.forAccount('acc-2');

      expect(other.accountId, 'acc-2');
      verify(() => mockAccounts.gatewayFor('acc-2')).called(1);
    });
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

    test('a single subscription sees the mapped user on sign-in then null on '
        'sign-out (end-to-end sequencing through the gateway)', () async {
      // Unlike the two single-emission cases above, this proves the
      // *same* subscription tracks both transitions the bound account's
      // gateway stream pushes as a result of separate sign-in/signOut calls —
      // formerly covered by the standalone auth_integration_test.dart
      // (folded in here per AUD-t-auth-04; that file re-derived this
      // exact scenario in a second file with no other collaborator
      // wired in, so it wasn't a real integration test).
      final authStateController = StreamController<AuthGatewayUser?>();
      addTearDown(authStateController.close);

      final fakeUser = _sampleUser(
        uid: 'test-uid-123',
        email: 'test@example.com',
        displayName: 'Test User',
        emailVerified: true,
      );

      when(
        () => mockAccounts.signInWithEmail(
          'acc-1',
          email: 'test@example.com',
          password: 'password123',
        ),
      ).thenAnswer((_) async {
        authStateController.add(fakeUser);
        return fakeUser;
      });

      when(() => mockGoogle.signOut()).thenAnswer((_) async {});
      when(() => mockAuth.signOut()).thenAnswer((_) async {
        authStateController.add(null);
      });

      when(
        () => mockAuth.authStateChanges(),
      ).thenAnswer((_) => authStateController.stream);

      final authStates = <AppUser?>[];
      final subscription = repository.onAuthStateChanged().listen(
        authStates.add,
      );
      addTearDown(subscription.cancel);

      // Step 1 — sign in
      await repository.signInToAccountWithEmail(
        'acc-1',
        'test@example.com',
        'password123',
      );
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

  group('getIdToken (AUD-core-auth-01 / AU-5)', () {
    test(
      'delegates to the gateway with forceRefresh defaulting to false',
      () async {
        when(
          () => mockAuth.getIdToken(forceRefresh: false),
        ).thenAnswer((_) async => 'cached-jwt');

        final token = await repository.getIdToken();

        expect(token, 'cached-jwt');
        verify(() => mockAuth.getIdToken(forceRefresh: false)).called(1);
      },
    );

    test(
      'passes forceRefresh: true through to the gateway — the AU-5 recovery '
      'primitive for a permission-denied/unauthenticated synced write',
      () async {
        when(
          () => mockAuth.getIdToken(forceRefresh: true),
        ).thenAnswer((_) async => 'fresh-jwt');

        final token = await repository.getIdToken(forceRefresh: true);

        expect(token, 'fresh-jwt');
        verify(() => mockAuth.getIdToken(forceRefresh: true)).called(1);
      },
    );

    test('returns null when the gateway reports no signed-in user', () async {
      when(
        () => mockAuth.getIdToken(forceRefresh: any(named: 'forceRefresh')),
      ).thenAnswer((_) async => null);

      expect(await repository.getIdToken(), isNull);
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
