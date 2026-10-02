// DNI-520 — NamedAppSignIn: one sign-in, on the right account's named app
// (AC-1), and the AD-24 path-uid reconcile (AC-4).
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/registry/path_uid_resolver.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/services/named_app_sign_in.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_repositories.dart';

AppUser _user(String uid, {String email = 'a@b.c'}) => AppUser(
  uid: uid,
  email: email,
  displayName: 'User',
  emailVerified: true,
  providers: const ['password'],
);

void main() {
  late DeviceRegistryDatabase registry;
  late MockAuthRepository auth;
  late NamedAppSignIn signIn;
  late List<String> signedInOn;

  Future<void> seed(String accountId, {required String email, String? uid}) =>
      registry.addAccount(
        DeviceAccountsCompanion.insert(
          accountId: accountId,
          email: email,
          displayName: accountId,
          tier: 'cloudBorn',
          firebaseUid: Value(uid),
          dbFileName: 'user_acc_$accountId.db',
          createdAt: DateTime.utc(2026),
          lastUsedAt: DateTime.utc(2026),
        ),
      );

  Future<AppUser> Function(String) authenticatesAs(AppUser user) =>
      (accountId) async {
        signedInOn.add(accountId);
        return user;
      };

  setUp(() {
    registry = DeviceRegistryDatabase(NativeDatabase.memory());
    addTearDown(registry.close);
    auth = MockAuthRepository();
    when(() => auth.forAccount(any())).thenReturn(auth);
    when(() => auth.signOut()).thenAnswer((_) async {});
    when(() => auth.discardAccountSession(any())).thenAnswer((_) async {});
    signedInOn = [];
    signIn = NamedAppSignIn(
      auth: auth,
      registry: registry,
      pathUids: PathUidResolver(registry),
      newAccountId: () => 'minted-id',
    );
  });

  test(
    'AC-1: a known email signs in ONCE, on that registry row\'s named app',
    () async {
      await seed('acc-1', email: 'a@b.c', uid: 'uid-1');

      final session = await signIn.signIn(
        emailHint: 'a@b.c',
        authenticate: authenticatesAs(_user('uid-1')),
      );

      expect(signedInOn, ['acc-1']);
      expect(session.accountId, 'acc-1');
      expect(session.isNewToDevice, isFalse);
    },
  );

  test('AC-1: an unknown email signs in ONCE on a freshly minted account id '
      '(never the Firebase uid)', () async {
    final session = await signIn.signIn(
      emailHint: 'new@x.y',
      authenticate: authenticatesAs(_user('uid-new', email: 'new@x.y')),
    );

    expect(signedInOn, ['minted-id']);
    expect(session.accountId, 'minted-id');
    expect(session.isNewToDevice, isTrue);
  });

  test('a uid that already has its own row moves the session to that row\'s '
      'named app and tears the minted one down', () async {
    await seed('acc-old-email', email: 'old@x.y', uid: 'uid-1');

    final session = await signIn.signIn(
      emailHint: 'changed@x.y',
      authenticate: authenticatesAs(_user('uid-1', email: 'changed@x.y')),
    );

    expect(signedInOn, ['minted-id', 'acc-old-email']);
    expect(session.accountId, 'acc-old-email');
    expect(session.registryRow?.accountId, 'acc-old-email');
    verify(() => auth.discardAccountSession('minted-id')).called(1);
  });

  test(
    'a failed sign-in on a minted id tears that named app down and rethrows',
    () async {
      await expectLater(
        signIn.signIn(
          emailHint: 'new@x.y',
          authenticate: (_) async => throw Exception('[invalid-credential]'),
        ),
        throwsA(isA<Exception>()),
      );

      verify(() => auth.discardAccountSession('minted-id')).called(1);
    },
  );

  test(
    'a failed sign-in on an existing account never tears its app down',
    () async {
      await seed('acc-1', email: 'a@b.c', uid: 'uid-1');

      await expectLater(
        signIn.signIn(
          emailHint: 'a@b.c',
          authenticate: (_) async => throw Exception('[wrong-password]'),
        ),
        throwsA(isA<Exception>()),
      );

      verifyNever(() => auth.discardAccountSession(any()));
    },
  );

  test(
    'AC-4: reconcilePathUid persists the signed-in uid through '
    'PathUidResolver — a changed uid is an AD-19 remap with breadcrumb',
    () async {
      await seed('acc-1', email: 'a@b.c', uid: 'uid-before');
      final session = await signIn.signIn(
        emailHint: 'a@b.c',
        authenticate: authenticatesAs(_user('uid-after')),
      );

      await signIn.reconcilePathUid(session);

      final row = await registry.findById('acc-1');
      expect(row!.firebaseUid, 'uid-after');
      expect(row.previousFirebaseUid, 'uid-before');
    },
  );

  test(
    'abandon signs the session out; only a new-to-device app is torn down',
    () async {
      await seed('acc-1', email: 'a@b.c', uid: 'uid-1');
      final existing = await signIn.signIn(
        emailHint: 'a@b.c',
        authenticate: authenticatesAs(_user('uid-1')),
      );

      await signIn.abandon(existing);

      verify(() => auth.signOut()).called(1);
      verifyNever(() => auth.discardAccountSession(any()));
    },
  );
}
