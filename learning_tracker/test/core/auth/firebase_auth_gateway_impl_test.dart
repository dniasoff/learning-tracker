import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/auth/auth_gateway_user.dart';
import 'package:learning_tracker/core/auth/firebase_auth_gateway_impl.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────
// We mock the *Firebase SDK types* and exercise the REAL [FirebaseAuthGatewayImpl]
// against them. This is the only file in the test tree allowed to mock
// `firebase_auth` types directly — the rest of the suite goes through the
// gateway. The audit rule itself permits `firebase_auth` inside `core/auth/`
// and these tests live in `test/core/auth/`, the production-side mirror.
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

class MockUserInfo extends Mock implements UserInfo {}

class FakeAuthCredential extends Fake implements AuthCredential {}

class FakeActionCodeSettings extends Fake implements ActionCodeSettings {}

void main() {
  late MockFirebaseAuth mockFirebaseAuth;
  late FirebaseAuthGatewayImpl gateway;

  setUpAll(() {
    registerFallbackValue(FakeAuthCredential());
    registerFallbackValue(FakeActionCodeSettings());
  });

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    gateway = FirebaseAuthGatewayImpl(firebaseAuth: mockFirebaseAuth);
  });

  void stubUser(
    MockUser user, {
    String uid = 'uid-1',
    String? email = 'user@example.com',
    String? displayName = 'Test User',
    bool emailVerified = true,
    List<MockUserInfo> providers = const <MockUserInfo>[],
  }) {
    when(() => user.uid).thenReturn(uid);
    when(() => user.email).thenReturn(email);
    when(() => user.displayName).thenReturn(displayName);
    when(() => user.emailVerified).thenReturn(emailVerified);
    when(() => user.providerData).thenReturn(providers);
  }

  group('currentUser', () {
    test('returns null when FirebaseAuth has no current user', () {
      when(() => mockFirebaseAuth.currentUser).thenReturn(null);

      expect(gateway.currentUser, isNull);
    });

    test('maps Firebase User to AuthGatewayUser', () {
      final user = MockUser();
      stubUser(user, uid: 'mapped-uid');
      when(() => mockFirebaseAuth.currentUser).thenReturn(user);

      final mapped = gateway.currentUser;

      expect(mapped, isA<AuthGatewayUser>());
      expect(mapped!.uid, 'mapped-uid');
      expect(mapped.email, 'user@example.com');
      expect(mapped.emailVerified, isTrue);
    });

    test('propagates linked-provider IDs', () {
      final user = MockUser();
      final google = MockUserInfo();
      final password = MockUserInfo();
      when(() => google.providerId).thenReturn('google.com');
      when(() => password.providerId).thenReturn('password');
      stubUser(user, providers: [google, password]);
      when(() => mockFirebaseAuth.currentUser).thenReturn(user);

      expect(gateway.currentUser!.providers, ['google.com', 'password']);
    });
  });

  group('authStateChanges', () {
    test('emits null when Firebase emits null', () async {
      when(
        () => mockFirebaseAuth.authStateChanges(),
      ).thenAnswer((_) => Stream<User?>.value(null));

      await expectLater(gateway.authStateChanges(), emits(isNull));
    });

    test('emits a mapped AuthGatewayUser when Firebase emits a user', () async {
      final user = MockUser();
      stubUser(user, uid: 'stream-uid');
      when(
        () => mockFirebaseAuth.authStateChanges(),
      ).thenAnswer((_) => Stream<User?>.value(user));

      await expectLater(
        gateway.authStateChanges(),
        emits(isA<AuthGatewayUser>().having((u) => u.uid, 'uid', 'stream-uid')),
      );
    });
  });

  group('reloadCurrentUser', () {
    test('returns null when no current user is signed in', () async {
      when(() => mockFirebaseAuth.currentUser).thenReturn(null);

      expect(await gateway.reloadCurrentUser(), isNull);
    });

    test('calls user.reload() and returns the refreshed snapshot', () async {
      final user = MockUser();
      stubUser(user);
      when(() => user.reload()).thenAnswer((_) async {});
      when(() => mockFirebaseAuth.currentUser).thenReturn(user);

      final refreshed = await gateway.reloadCurrentUser();

      verify(() => user.reload()).called(1);
      expect(refreshed, isA<AuthGatewayUser>());
    });
  });

  group('getIdToken (AUD-core-auth-01 / AU-5)', () {
    test('returns null when no current user is signed in', () async {
      when(() => mockFirebaseAuth.currentUser).thenReturn(null);

      expect(await gateway.getIdToken(), isNull);
      expect(await gateway.getIdToken(forceRefresh: true), isNull);
    });

    test('defaults forceRefresh to false and returns the token', () async {
      final user = MockUser();
      when(() => mockFirebaseAuth.currentUser).thenReturn(user);
      when(() => user.getIdToken(false)).thenAnswer((_) async => 'cached-jwt');

      final token = await gateway.getIdToken();

      expect(token, 'cached-jwt');
      verify(() => user.getIdToken(false)).called(1);
    });

    test('passes forceRefresh: true through to User.getIdToken — the AU-5 '
        'primitive a permission-denied/unauthenticated retry needs to bypass '
        'the SDK local token cache', () async {
      final user = MockUser();
      when(() => mockFirebaseAuth.currentUser).thenReturn(user);
      when(() => user.getIdToken(true)).thenAnswer((_) async => 'fresh-jwt');

      final token = await gateway.getIdToken(forceRefresh: true);

      expect(token, 'fresh-jwt');
      verify(() => user.getIdToken(true)).called(1);
    });
  });

  group('updateDisplayName', () {
    test('updates the display name on the current user', () async {
      final user = MockUser();
      when(() => mockFirebaseAuth.currentUser).thenReturn(user);
      when(() => user.updateDisplayName('New Name')).thenAnswer((_) async {});

      await gateway.updateDisplayName('New Name');

      verify(() => user.updateDisplayName('New Name')).called(1);
    });

    test('is a no-op when no user is signed in', () async {
      when(() => mockFirebaseAuth.currentUser).thenReturn(null);

      await gateway.updateDisplayName('New Name');

      // Nothing to verify on the (null) user — just ensure no throw.
    });
  });

  group('sendEmailVerification', () {
    test('throws when no user is signed in', () async {
      when(() => mockFirebaseAuth.currentUser).thenReturn(null);

      expect(
        () => gateway.sendEmailVerification(
          continueUrl: 'https://example.com/verify',
          androidPackageName: 'com.example.app',
        ),
        throwsA(isA<NotAuthenticatedException>()),
      );
    });

    test('sends an ActionCodeSettings-aware verification email', () async {
      final user = MockUser();
      when(() => mockFirebaseAuth.currentUser).thenReturn(user);
      when(() => user.sendEmailVerification(any())).thenAnswer((_) async {});

      await gateway.sendEmailVerification(
        continueUrl: 'https://example.com/verify',
        androidPackageName: 'com.example.app',
      );

      verify(() => user.sendEmailVerification(any())).called(1);
    });
  });

  group('sendSignInLinkToEmail', () {
    test('passes the email + ActionCodeSettings to FirebaseAuth', () async {
      when(
        () => mockFirebaseAuth.sendSignInLinkToEmail(
          email: any(named: 'email'),
          actionCodeSettings: any(named: 'actionCodeSettings'),
        ),
      ).thenAnswer((_) async {});

      await gateway.sendSignInLinkToEmail(
        email: 'user@example.com',
        continueUrl: 'https://example.com/sign-in',
        androidPackageName: 'com.example.app',
      );

      verify(
        () => mockFirebaseAuth.sendSignInLinkToEmail(
          email: 'user@example.com',
          actionCodeSettings: any(named: 'actionCodeSettings'),
        ),
      ).called(1);
    });
  });

  group('isSignInWithEmailLink', () {
    test('is the SDK\'s pure string check — needs no FirebaseAuth', () {
      final unbound = FirebaseAuthGatewayImpl();

      expect(
        unbound.isSignInWithEmailLink('https://x/?mode=signIn&oobCode=abc'),
        isTrue,
      );
      expect(
        unbound.isSignInWithEmailLink('https://x/?mode%3DsignIn%26oobCode%3D1'),
        isTrue,
      );
      expect(unbound.isSignInWithEmailLink('https://x/?mode=signIn'), isFalse);
      expect(unbound.isSignInWithEmailLink('bogus'), isFalse);
    });
  });

  group('sendPasswordResetEmail', () {
    test('forwards the email to FirebaseAuth', () async {
      when(
        () => mockFirebaseAuth.sendPasswordResetEmail(email: 'a@b.c'),
      ).thenAnswer((_) async {});

      await gateway.sendPasswordResetEmail('a@b.c');

      verify(
        () => mockFirebaseAuth.sendPasswordResetEmail(email: 'a@b.c'),
      ).called(1);
    });
  });

  group('checkActionCode + applyActionCode', () {
    test('checkActionCode delegates', () async {
      when(
        () => mockFirebaseAuth.checkActionCode('oob'),
      ).thenAnswer((_) async => FakeActionCodeInfo());

      await gateway.checkActionCode('oob');

      verify(() => mockFirebaseAuth.checkActionCode('oob')).called(1);
    });

    test('applyActionCode delegates', () async {
      when(
        () => mockFirebaseAuth.applyActionCode('oob'),
      ).thenAnswer((_) async {});

      await gateway.applyActionCode('oob');

      verify(() => mockFirebaseAuth.applyActionCode('oob')).called(1);
    });
  });

  group('signOut', () {
    test('delegates to FirebaseAuth.signOut', () async {
      when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {});

      await gateway.signOut();

      verify(() => mockFirebaseAuth.signOut()).called(1);
    });
  });

  group('deleteCurrentUser', () {
    test('throws when no user is signed in', () async {
      when(() => mockFirebaseAuth.currentUser).thenReturn(null);

      expect(
        gateway.deleteCurrentUser(),
        throwsA(isA<NotAuthenticatedException>()),
      );
    });

    test('calls user.delete() when signed in', () async {
      final user = MockUser();
      when(() => mockFirebaseAuth.currentUser).thenReturn(user);
      when(() => user.delete()).thenAnswer((_) async {});

      await gateway.deleteCurrentUser();

      verify(() => user.delete()).called(1);
    });
  });

  group('updatePassword', () {
    test('throws when no user is signed in', () async {
      when(() => mockFirebaseAuth.currentUser).thenReturn(null);

      expect(
        gateway.updatePassword('pw'),
        throwsA(isA<NotAuthenticatedException>()),
      );
    });

    test('forwards to user.updatePassword when signed in', () async {
      final user = MockUser();
      when(() => mockFirebaseAuth.currentUser).thenReturn(user);
      when(() => user.updatePassword('new-pw')).thenAnswer((_) async {});

      await gateway.updatePassword('new-pw');

      verify(() => user.updatePassword('new-pw')).called(1);
    });
  });

  group('reauthenticateWithEmail', () {
    test('throws when no user is signed in', () async {
      when(() => mockFirebaseAuth.currentUser).thenReturn(null);

      expect(
        () => gateway.reauthenticateWithEmail(email: 'a@b.c', password: 'pw'),
        throwsA(isA<NotAuthenticatedException>()),
      );
    });

    test(
      'builds an EmailAuthProvider credential and reauthenticates',
      () async {
        final user = MockUser();
        when(() => mockFirebaseAuth.currentUser).thenReturn(user);
        when(
          () => user.reauthenticateWithCredential(any()),
        ).thenAnswer((_) async => MockUserCredential());

        await gateway.reauthenticateWithEmail(email: 'a@b.c', password: 'pw');

        verify(() => user.reauthenticateWithCredential(any())).called(1);
      },
    );
  });

  group('Google credential plumbing', () {
    test('reauthenticateWithGoogleIdToken reauths when signed in', () async {
      final user = MockUser();
      when(() => mockFirebaseAuth.currentUser).thenReturn(user);
      when(
        () => user.reauthenticateWithCredential(any()),
      ).thenAnswer((_) async => MockUserCredential());

      await gateway.reauthenticateWithGoogleIdToken(idToken: 'tok');

      verify(() => user.reauthenticateWithCredential(any())).called(1);
    });

    test(
      'reauthenticateWithGoogleIdToken throws when no user is signed in',
      () async {
        when(() => mockFirebaseAuth.currentUser).thenReturn(null);

        expect(
          () => gateway.reauthenticateWithGoogleIdToken(idToken: 'tok'),
          throwsA(isA<NotAuthenticatedException>()),
        );
      },
    );
  });

  _namedAppBindingTests();

  group('getLinkedProviders', () {
    test('returns empty list when no user is signed in', () {
      when(() => mockFirebaseAuth.currentUser).thenReturn(null);

      expect(gateway.getLinkedProviders(), isEmpty);
    });

    test('returns provider IDs from the current user', () {
      final user = MockUser();
      final p1 = MockUserInfo();
      final p2 = MockUserInfo();
      when(() => p1.providerId).thenReturn('password');
      when(() => p2.providerId).thenReturn('google.com');
      when(() => user.providerData).thenReturn([p1, p2]);
      when(() => mockFirebaseAuth.currentUser).thenReturn(user);

      expect(gateway.getLinkedProviders(), ['password', 'google.com']);
    });
  });
}

class FakeActionCodeInfo extends Fake implements ActionCodeInfo {}

/// DNI-520 (AC-1): the gateway is bound to ONE account's named-app Auth and
/// has no default-app (`FirebaseAuth.instance`) fallback.
void _namedAppBindingTests() {
  group('named-app binding (DNI-520 AC-1)', () {
    test(
      'with no Auth bound it is signed out — no default-app fallback',
      () async {
        final unbound = FirebaseAuthGatewayImpl();

        expect(unbound.currentUser, isNull);
        expect(await unbound.authStateChanges().toList(), [null]);
        expect(await unbound.getIdToken(), isNull);
        expect(unbound.getLinkedProviders(), isEmpty);
        expect(
          unbound.deleteCurrentUser,
          throwsA(isA<NotAuthenticatedException>()),
        );
      },
    );

    test(
      'account-free calls fall back to the utility app only while unbound',
      () async {
        final utility = MockFirebaseAuth();
        when(
          () => utility.sendPasswordResetEmail(email: 'a@b.c'),
        ).thenAnswer((_) async {});
        when(() => utility.applyActionCode('oob')).thenAnswer((_) async {});
        final unbound = FirebaseAuthGatewayImpl(
          accountFreeAuth: () async => utility,
        );

        await unbound.sendPasswordResetEmail('a@b.c');
        await unbound.applyActionCode('oob');

        verify(() => utility.sendPasswordResetEmail(email: 'a@b.c')).called(1);
        verify(() => utility.applyActionCode('oob')).called(1);
      },
    );

    test('resolves the bound Auth live, per call', () {
      FirebaseAuth? bound;
      final gateway = FirebaseAuthGatewayImpl(resolveAuth: () => bound);
      expect(gateway.currentUser, isNull);

      final auth = MockFirebaseAuth();
      final user = MockUser();
      when(() => user.uid).thenReturn('named-uid');
      when(() => user.email).thenReturn(null);
      when(() => user.displayName).thenReturn(null);
      when(() => user.emailVerified).thenReturn(true);
      when(() => user.providerData).thenReturn(const <UserInfo>[]);
      when(() => auth.currentUser).thenReturn(user);
      bound = auth;

      expect(gateway.currentUser?.uid, 'named-uid');
    });

    test('signOut goes through onSignOut (the registry) when given', () async {
      final auth = MockFirebaseAuth();
      var registrySignOuts = 0;
      final gateway = FirebaseAuthGatewayImpl(
        firebaseAuth: auth,
        onSignOut: () async => registrySignOuts++,
      );

      await gateway.signOut();

      expect(registrySignOuts, 1);
      verifyNever(() => auth.signOut());
    });
  });
}
