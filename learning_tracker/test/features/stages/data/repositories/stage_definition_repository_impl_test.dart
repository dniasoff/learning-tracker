import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

void main() {
  const uid = 'uid-stage-test';
  const profileId = 'profile-stage-test';
  const curriculum = CurriculumId.mishnayos;

  late FirestoreStageDefinitionRepository repository;
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: uid);
    repository = FirestoreStageDefinitionRepository(
      firestore: firestore,
      uid: uid,
      profileId: profileId,
    );
  });

  group('FirestoreStageDefinitionRepository', () {
    test('getStagesForCurriculum returns stages in stageOrder', () async {
      await repository.replaceStagesForCurriculum(curriculum, [
        const StageDefinition(
          curriculumId: curriculum,
          stageOrder: 2,
          stageName: 'Chazara 1',
          delayDays: 1,
          isDefault: true,
        ),
        const StageDefinition(
          curriculumId: curriculum,
          stageOrder: 1,
          stageName: 'Learn',
          delayDays: 0,
          isDefault: true,
        ),
      ]);

      final result = await repository.getStagesForCurriculum(curriculum);

      expect(result.map((stage) => stage.stageOrder), [1, 2]);
      expect(result.first.stageName, 'Learn');
      expect(result.first.curriculumId, curriculum);
    });

    test('initializeDefaults is a no-op when stages already exist', () async {
      await seedStageDefinitions(
        firestore,
        uid: uid,
        profileId: profileId,
        curriculumId: curriculum,
      );
      final before = await repository.getStagesForCurriculum(curriculum);

      await repository.initializeDefaults(curriculum);

      final after = await repository.getStagesForCurriculum(curriculum);
      expect(after, before);
    });

    test(
      'initializeDefaults writes three defaults when the curriculum is empty',
      () async {
        await repository.initializeDefaults(curriculum);

        final result = await repository.getStagesForCurriculum(curriculum);

        expect(result, hasLength(3));
        expect(result.map((stage) => stage.stageOrder), [1, 2, 3]);
      },
    );

    test(
      'resetToDefaults restores the three Firestore stage documents',
      () async {
        await repository.replaceStagesForCurriculum(curriculum, [
          const StageDefinition(
            curriculumId: curriculum,
            stageOrder: 1,
            stageName: 'Custom',
            delayDays: 4,
            isDefault: false,
          ),
        ]);

        await repository.resetToDefaults(curriculum);

        final result = await repository.getStagesForCurriculum(curriculum);
        expect(result, hasLength(3));
        expect(result.first.stageName, 'לימוד');
        expect(result.first.isDefault, isTrue);
      },
    );
  });
}
