// Regression test for R6-19: duplicate-completion detection must include
// curriculumId in the idempotency key.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';

import '../../../../helpers/firestore_fake.dart';

void main() {
  const uid = 'r619-uid';
  const profileId = 'r619-profile-ulid';
  late FakeFirebaseFirestore firestore;
  late FirestoreCompletionRepository firestoreRepository;
  late ProviderContainer container;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: uid);
    firestoreRepository = FirestoreCompletionRepository(
      firestore: firestore,
      uid: uid,
      profileId: profileId,
    );
    container = ProviderContainer(
      overrides: [
        firestoreCompletionRepositoryProvider.overrideWith(
          (ref) async => firestoreRepository,
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  group('R6-19 cross-curriculum dedup', () {
    test(
      'same item under two curricula creates two completion documents',
      () async {
        final repository = container.read(completionRepositoryProvider);

        final r1 = (await repository.markComplete(
          const CompletionRequest(
            curriculumId: 'mishnayos',
            sefariaRef: 'Berachot 1:1',
            stageId: 1,
            trackType: 'personal',
          ),
        )).completion;
        final r2 = (await repository.markComplete(
          const CompletionRequest(
            curriculumId: 'bavli',
            sefariaRef: 'Berachot 1:1',
            stageId: 1,
            trackType: 'personal',
          ),
        )).completion;

        expect(r1.curriculumId, CurriculumId.mishnayos);
        expect(r2.curriculumId, CurriculumId.bavli);
        expect(r1.sefariaRef, r2.sefariaRef);

        final all = await firestoreRepository.getCompletionsForContent(
          'Berachot 1:1',
        );
        expect(all, hasLength(2));
      },
    );

    test('same request within one curriculum is still deduped', () async {
      final repository = container.read(completionRepositoryProvider);
      const request = CompletionRequest(
        curriculumId: 'mishnayos',
        sefariaRef: 'Berachot 1:1',
        stageId: 1,
        trackType: 'personal',
      );

      final first = (await repository.markComplete(request)).completion;
      final second = (await repository.markComplete(request)).completion;

      expect(second.sefariaRef, first.sefariaRef);
      final all = await firestoreRepository.getCompletionsForContent(
        'Berachot 1:1',
      );
      expect(all, hasLength(1));
    });
  });
}
