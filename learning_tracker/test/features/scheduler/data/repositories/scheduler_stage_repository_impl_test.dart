/// Firestore-native tests for the scheduler stage adapter.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_stage_repository_impl.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

const _uid = 'scheduler-stage-uid';
const _profileId = '01J9V8J5Q2K7M3N6P4R8T1WXYZ';

void main() {
  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    container = ProviderContainer(
      overrides: [
        firestoreStageDefinitionRepositoryProvider.overrideWith(
          (ref) async => FirestoreStageDefinitionRepository(
            firestore: firestore,
            uid: _uid,
            profileId: _profileId,
          ),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('maps the Firestore stage definition into scheduler fields', () async {
    await seedStageDefinitions(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
    );

    final repo = SchedulerStageRepositoryImpl(
      stageRepository: container.read(
        stageDefinitionRepositoryProvider(CurriculumId.mishnayos),
      ),
    );
    final stages = await repo.getStages(CurriculumId.mishnayos);

    expect(stages, hasLength(3));
    expect(stages.map((stage) => stage.stageOrder), [1, 2, 3]);
    expect(stages[0].delayDays, 0);
    expect(stages[1].scheduleType, ScheduleType.delay);
  });
}
