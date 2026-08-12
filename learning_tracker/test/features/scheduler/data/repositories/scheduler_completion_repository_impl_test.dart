/// Firestore-native tests for the scheduler completion adapter.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_completion_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

const _uid = 'scheduler-completion-uid';
const _profileId = '01J9V8J5Q2K7M3N6P4R8T1WXYZ';

final _adapterProvider = Provider<SchedulerCompletionRepository>((ref) {
  return SchedulerFirestoreCompletionRepositoryAdapter(ref: ref);
});

void main() {
  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    container = ProviderContainer(
      overrides: [
        firestoreCompletionRepositoryProvider.overrideWith(
          (ref) async => FirestoreCompletionRepository(
            firestore: firestore,
            uid: _uid,
            profileId: _profileId,
          ),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('maps Firestore completion stageId directly to stageOrder', () async {
    await seedCompletion(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
      sefariaRef: 'Mishnah Berakhot 1:1',
      stageId: 2,
      completedAt: DateTime.utc(2026, 2, 1),
    );

    final repo = container.read(_adapterProvider);
    final completions = await repo.getCompletions(CurriculumId.mishnayos);

    expect(completions, hasLength(1));
    expect(completions.single.stageOrder, 2);
    expect(completions.single.sefariaRef, 'Mishnah Berakhot 1:1');
  });

  test('does not perform the retired Drift id/order collision guess', () async {
    await seedCompletion(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
      sefariaRef: 'Mishnah Berakhot 1:2',
      stageId: 7,
      completedAt: DateTime.utc(2026, 2, 2),
    );

    final repo = container.read(_adapterProvider);
    final completion = (await repo.getCompletions(
      CurriculumId.mishnayos,
    )).single;

    expect(completion.stageOrder, 7);
  });
}
