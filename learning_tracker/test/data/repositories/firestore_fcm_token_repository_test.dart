// FirestoreFcmTokenRepository — users/{uid}.fcm_tokens[installId]
// (Story 4.7 / DNI-515 AC-4): only this install's entry of the owning
// account is written or deleted.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/firestore_fcm_token_repository.dart';
import 'package:learning_tracker/domain/repositories/fcm_token_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late List<String> resolvedAccounts;
  late FirestoreFcmTokenRepository repo;
  const owner = FcmTokenOwner(accountId: 'acct-1', uid: 'owner-uid');

  Future<Map<String, dynamic>?> tokens(String uid) async {
    final snap = await firestore.collection('users').doc(uid).get();
    return snap.data()?[kFcmTokensField] as Map<String, dynamic>?;
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    resolvedAccounts = [];
    repo = FirestoreFcmTokenRepository(
      firestoreFor: (accountId) async {
        resolvedAccounts.add(accountId);
        return firestore;
      },
    );
    await firestore.collection('users').doc('owner-uid').set({
      'display_name': 'Parent',
      kFcmTokensField: {
        'other-install': {'token': 'tok-other', 'updated_at': Timestamp.now()},
      },
    });
  });

  test(
    "upsert writes this install's entry on the owner's account only",
    () async {
      await repo.upsertToken(owner, installId: 'install-a', token: 'tok-a');

      expect(resolvedAccounts, ['acct-1']);
      final map = await tokens('owner-uid');
      expect(map!.keys, unorderedEquals(['other-install', 'install-a']));
      final entry = map['install-a'] as Map<String, dynamic>;
      expect(entry['token'], 'tok-a');
      expect(entry['updated_at'], isA<Timestamp>());
      expect((map['other-install'] as Map)['token'], 'tok-other');
      final account = await firestore
          .collection('users')
          .doc('owner-uid')
          .get();
      expect(account.data()!['display_name'], 'Parent');
    },
  );

  test('a repeated upsert replaces the same entry', () async {
    await repo.upsertToken(owner, installId: 'install-a', token: 'tok-1');
    await repo.upsertToken(owner, installId: 'install-a', token: 'tok-2');
    final map = await tokens('owner-uid');
    expect(map!.length, 2);
    expect((map['install-a'] as Map)['token'], 'tok-2');
  });

  test("remove deletes only this install's entry", () async {
    await repo.upsertToken(owner, installId: 'install-a', token: 'tok-a');
    await repo.removeToken(owner, installId: 'install-a');
    final map = await tokens('owner-uid');
    expect(map!.keys, ['other-install']);
  });

  test('removing an absent entry is not an error', () async {
    await repo.removeToken(owner, installId: 'never-registered');
    expect((await tokens('owner-uid'))!.keys, ['other-install']);
  });

  test('writes go to the owner uid, never another account', () async {
    await repo.upsertToken(
      const FcmTokenOwner(accountId: 'acct-2', uid: 'second-uid'),
      installId: 'install-a',
      token: 'tok-a',
    );
    expect(await tokens('second-uid'), contains('install-a'));
    expect((await tokens('owner-uid'))!.keys, ['other-install']);
    expect(resolvedAccounts, ['acct-2']);
  });
}
