import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/auth/auth_gateway_user.dart';
import 'package:learning_tracker/core/auth/firebase_auth_gateway.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/repositories/minimum_app_version_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _MockFirebaseAuthGateway extends Mock implements FirebaseAuthGateway {}

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

const _user = AuthGatewayUser(
  uid: 'user-1',
  email: null,
  displayName: null,
  emailVerified: false,
  providers: [],
);

AccountFirebaseHandles _handles(FakeFirebaseFirestore firestore) =>
    AccountFirebaseHandles(
      app: _MockFirebaseApp(),
      firestore: firestore,
      auth: _MockFirebaseAuth(),
      uid: _user.uid,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockFirebaseAuthGateway auth;
  late FakeFirebaseFirestore firestore;
  late AccountFirebaseHandles account;

  setUp(() {
    auth = _MockFirebaseAuthGateway();
    firestore = FakeFirebaseFirestore();
    account = _handles(firestore);
    when(() => auth.currentUser).thenReturn(_user);
  });

  test('missing minimum config allows startup and records the build', () async {
    await firestore.doc('users/${_user.uid}').set({});
    final checker = FirebaseMinimumAppVersionChecker(
      auth: auth,
      resolveAccount: () async => account,
      loadPackageInfo: () async => _packageInfo('42'),
    );

    expect(await checker.shouldBlockApp(), isFalse);
    // Heartbeats are deliberately fire-and-forget for startup. Let the fake
    // backend's queued write complete before asserting the recorded value.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final user = await firestore.doc('users/${_user.uid}').get();
    expect(
      user.data()?[FirebaseMinimumAppVersionChecker.lastSeenBuildField],
      42,
    );
  });

  test(
    'blocks only when server minimum is newer than installed build',
    () async {
      await firestore.doc(FirebaseMinimumAppVersionChecker.configPath).set({
        FirebaseMinimumAppVersionChecker.minimumBuildField: 43,
      });
      final checker = FirebaseMinimumAppVersionChecker(
        auth: auth,
        resolveAccount: () async => account,
        loadPackageInfo: () async => _packageInfo('42'),
      );

      expect(await checker.shouldBlockApp(), isTrue);
    },
  );

  test('signed out or unresolved account never blocks', () async {
    when(() => auth.currentUser).thenReturn(null);
    final signedOutChecker = FirebaseMinimumAppVersionChecker(
      auth: auth,
      resolveAccount: () async => account,
      loadPackageInfo: () async => _packageInfo('1'),
    );
    expect(await signedOutChecker.shouldBlockApp(), isFalse);

    when(() => auth.currentUser).thenReturn(_user);
    final unresolvedChecker = FirebaseMinimumAppVersionChecker(
      auth: auth,
      resolveAccount: () async => null,
      loadPackageInfo: () async => _packageInfo('1'),
    );
    expect(await unresolvedChecker.shouldBlockApp(), isFalse);
  });
}

PackageInfo _packageInfo(String build) => PackageInfo(
  appName: 'Learning Tracker',
  packageName: 'com.example.learning_tracker',
  version: '1.0.0',
  buildNumber: build,
);
