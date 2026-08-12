/// Storage-only invariant: the completion adapter does not write streak data.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';

import '../../../../helpers/firestore_fake.dart';

void main() {
  const uid = 'streak-tee-uid';
  const profileId = 'streak-tee-profile-ulid';
  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: uid);
    final repository = FirestoreCompletionRepository(
      firestore: firestore,
      uid: uid,
      profileId: profileId,
    );
    container = ProviderContainer(
      overrides: [
        firestoreCompletionRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test(
    'markComplete never writes a streak_events document — storage-only',
    () async {
      final completionRepository = container.read(completionRepositoryProvider);
      final result = await completionRepository.markComplete(
        const CompletionRequest(
          curriculumId: 'mishnayos',
          sefariaRef: 'Mishnah_Berakhot_1',
          stageId: 1,
          trackType: 'personal',
        ),
      );

      expect(result.completion.sefariaRef, 'Mishnah_Berakhot_1');
      final streaks = await firestore
          .collection('users')
          .doc(uid)
          .collection('learner_profiles')
          .doc(profileId)
          .collection('streak_events')
          .get();
      expect(
        streaks.docs,
        isEmpty,
        reason:
            'streak recording belongs to orchestration, not the completion '
            'storage adapter',
      );
    },
  );
}
