import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/firestore_hidden_content_repository.dart';

void main() {
  test('reads and decodes hidden refs from a learner profile', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('users')
        .doc('owner')
        .collection('learner_profiles')
        .doc('profile')
        .set({
          'hidden_content_refs': ['Niddah', 7, '', 'Shabbos'],
        });

    final repository = FirestoreHiddenContentRepository(
      firestore: firestore,
      ownerUid: 'owner',
      profileId: 'profile',
      resolveFunctions: () async => throw UnimplementedError(),
    );

    expect(await repository.getHiddenRefs(), {'Niddah', 'Shabbos'});
  });

  test('missing hidden refs decode as an empty set', () async {
    final repository = FirestoreHiddenContentRepository(
      firestore: FakeFirebaseFirestore(),
      ownerUid: 'owner',
      profileId: 'profile',
      resolveFunctions: () async => throw UnimplementedError(),
    );

    expect(await repository.getHiddenRefs(), isEmpty);
  });
}
