import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';

import '../helpers/firestore_fake.dart';
import '../helpers/firestore_fixtures.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreStageDefinitionRepository repository;

  const uid = 'stage-sync-test-user';
  const profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
  const curriculum = CurriculumId.mishnayos;

  setUp(() async {
    firestore = createFakeFirestore(authenticatedUid: uid);
    await seedAccount(firestore, uid: uid);
    await seedProfile(firestore, uid: uid, profileId: profileId);
    await seedTrack(
      firestore,
      uid: uid,
      profileId: profileId,
      curriculumId: curriculum,
    );
    repository = FirestoreStageDefinitionRepository(
      firestore: firestore,
      uid: uid,
      profileId: profileId,
    );
  });

  group('Stage sync integration', () {
    test(
      'replaceStagesForCurriculum restores stages from Firestore payload',
      () async {
        await repository.initializeDefaults(curriculum);

        // Simulate Firestore payload arriving with 4 stages.
        final firestoreStages = [
          StageDefinition(
            curriculumId: curriculum,
            stageOrder: 1,
            stageName: 'Learn',
            delayDays: 0,
            isDefault: true,
          ),
          StageDefinition(
            curriculumId: curriculum,
            stageOrder: 2,
            stageName: 'Chazara 1',
            delayDays: 1,
            isDefault: true,
          ),
          StageDefinition(
            curriculumId: curriculum,
            stageOrder: 3,
            stageName: 'Chazara 2',
            delayDays: 7,
            isDefault: true,
          ),
          StageDefinition(
            curriculumId: curriculum,
            stageOrder: 4,
            stageName: 'Chazara 3',
            delayDays: 30,
            isDefault: false,
          ),
        ];

        await repository.replaceStagesForCurriculum(
          curriculum,
          firestoreStages,
        );

        final restored = await repository.getStagesForCurriculum(curriculum);

        expect(restored, hasLength(4));
        expect(restored.last.stageName, 'Chazara 3');
        expect(restored.last.delayDays, 30);
        expect(restored.last.isDefault, false);
      },
    );

    test(
      'resetToDefaults restores defaults while retaining a custom stage',
      () async {
        await seedStageDefinitions(
          firestore,
          uid: uid,
          profileId: profileId,
          curriculumId: curriculum,
          stages: [
            for (final stage in [
              (1, 'Old Learn', 2, true),
              (2, 'Old Chazara 1', 3, true),
              (3, 'Old Chazara 2', 8, true),
              (4, 'Custom', 60, false),
            ])
              StageDefinition(
                curriculumId: curriculum,
                stageOrder: stage.$1,
                stageName: stage.$2,
                delayDays: stage.$3,
                isDefault: stage.$4,
              ),
          ],
        );

        await repository.resetToDefaults(curriculum);

        final stages = await repository.getStagesForCurriculum(curriculum);
        expect(stages, hasLength(4));
        expect(stages.take(3).map((s) => s.stageName).toList(), [
          'לימוד',
          'חזרה א׳',
          'חזרה ב׳',
        ]);
        expect(stages.take(3).every((s) => s.isDefault), isTrue);
        expect(stages.last.stageName, 'Custom');
        expect(stages.last.delayDays, 60);
        expect(stages.last.isDefault, false);
      },
    );
  });
}
