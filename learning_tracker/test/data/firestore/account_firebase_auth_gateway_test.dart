// DNI-520 — AccountFirebaseAuthGateway: every sign-in, sign-up, anonymous
// session and credential link runs on the named app AccountFirebase owns for
// that device account (AC-1, AC-2, AC-3).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/auth/firebase_auth_gateway_impl.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/account_firebase_auth_gateway.dart';
import 'package:mocktail/mocktail.dart';

class _MockAccountFirebase extends Mock implements AccountFirebase {}

class _MockApp extends Mock implements FirebaseApp {}

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

_MockUser _user(
  String uid, {
  String? email,
  List<UserInfo> providers = const [],
}) {
  final user = _MockUser();
  when(() => user.uid).thenReturn(uid);
  when(() => user.email).thenReturn(email);
  when(() => user.displayName).thenReturn(null);
  when(() => user.emailVerified).thenReturn(true);
  when(() => user.providerData).thenReturn(providers);
  return user;
}

/// Handles whose named-app Auth has [user] signed in.
AccountFirebaseHandles _handles(_MockAuth auth, User user) {
  when(() => auth.currentUser).thenReturn(user);
  return AccountFirebaseHandles(
    app: _MockApp(),
    firestore: _MockFirestore(),
    auth: auth,
    uid: user.uid,
  );
}

void main() {
  late _MockAccountFirebase registry;
  late _MockAuth auth;
  late AccountFirebaseAuthGateway gateway;

  setUp(() {
    registry = _MockAccountFirebase();
    auth = _MockAuth();
    gateway = AccountFirebaseAuthGateway(registry);
  });

  test(
    'signInWithEmail signs in on the named account only and maps its user',
    () async {
      when(
        () => registry.signInCloudAccountWithEmail(
          'acc-1',
          email: 'a@b.c',
          password: 'pw',
        ),
      ).thenAnswer((_) async => _handles(auth, _user('uid-1', email: 'a@b.c')));

      final user = await gateway.signInWithEmail(
        'acc-1',
        email: 'a@b.c',
        password: 'pw',
      );

      expect(user.uid, 'uid-1');
      expect(user.email, 'a@b.c');
      verify(
        () => registry.signInCloudAccountWithEmail(
          'acc-1',
          email: 'a@b.c',
          password: 'pw',
        ),
      ).called(1);
    },
  );

  test(
    'createUserWithEmail signs up on the named app and sets the display name',
    () async {
      final user = _user('uid-new');
      when(() => user.updateDisplayName('Name')).thenAnswer((_) async {});
      when(
        () => registry.createCloudAccountWithEmail(
          'acc-new',
          email: 'n@x.y',
          password: 'pw',
        ),
      ).thenAnswer((_) async => _handles(auth, user));

      final created = await gateway.createUserWithEmail(
        'acc-new',
        email: 'n@x.y',
        password: 'pw',
        displayName: 'Name',
      );

      expect(created.uid, 'uid-new');
      verify(() => user.updateDisplayName('Name')).called(1);
    },
  );

  test(
    'AC-2: ensureAnonymousSession is AccountFirebase.createAnonymousAccount',
    () async {
      when(
        () => registry.createAnonymousAccount('acc-local'),
      ).thenAnswer((_) async => _handles(auth, _user('anon-uid')));

      final user = await gateway.ensureAnonymousSession('acc-local');

      expect(user.uid, 'anon-uid');
      expect(user.providers, isEmpty);
    },
  );

  test(
    'AC-3: linkEmail re-attaches, then links on the named app keeping the uid',
    () async {
      final anon = _user('anon-uid');
      when(
        () => registry.resolve('acc-local'),
      ).thenAnswer((_) async => _handles(auth, anon));
      when(
        () => registry.linkEmailCredential(
          'acc-local',
          email: 'a@b.c',
          password: 'pw',
        ),
      ).thenAnswer((_) async => _handles(auth, anon));

      final linked = await gateway.linkEmail(
        'acc-local',
        email: 'a@b.c',
        password: 'pw',
      );

      expect(linked.uid, 'anon-uid');
      verifyInOrder([
        () => registry.resolve('acc-local'),
        () => registry.linkEmailCredential(
          'acc-local',
          email: 'a@b.c',
          password: 'pw',
        ),
      ]);
    },
  );

  test(
    'restoreSession is null for an account with no session to re-attach',
    () async {
      when(
        () => registry.resolve('acc-gone'),
      ).thenThrow(const AccountNotAuthenticatedException('acc-gone'));

      expect(await gateway.restoreSession('acc-gone'), isNull);
    },
  );

  test(
    'a bundle whose named app lost its user is reported, not mapped',
    () async {
      when(() => auth.currentUser).thenReturn(null);
      when(() => registry.createAnonymousAccount('acc-1')).thenAnswer(
        (_) async => AccountFirebaseHandles(
          app: _MockApp(),
          firestore: _MockFirestore(),
          auth: auth,
          uid: 'uid-1',
        ),
      );

      await expectLater(
        gateway.ensureAnonymousSession('acc-1'),
        throwsA(isA<NotAuthenticatedException>()),
      );
    },
  );

  test(
    'gatewayFor(id) reads that account\'s named-app Auth; null is signed out',
    () {
      final user = _user('uid-1');
      when(() => registry.authFor('acc-1')).thenReturn(auth);
      when(() => auth.currentUser).thenReturn(user);

      expect(gateway.gatewayFor('acc-1').currentUser?.uid, 'uid-1');
      expect(gateway.gatewayFor(null).currentUser, isNull);
    },
  );

  test(
    'signOut and discard act on the named account through the registry',
    () async {
      when(() => registry.signOut('acc-1')).thenAnswer((_) async {});
      when(() => registry.dispose('acc-1')).thenAnswer((_) async {});

      await gateway.signOut('acc-1');
      await gateway.discard('acc-1');

      verify(() => registry.signOut('acc-1')).called(1);
      verify(() => registry.dispose('acc-1')).called(1);
    },
  );
}
