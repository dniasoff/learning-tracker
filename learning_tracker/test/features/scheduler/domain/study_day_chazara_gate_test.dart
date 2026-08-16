/// Firestore-native coverage for the study-day chazara gate.
@Tags(['scheduler', 'study_day', 'studyday_chazara_gate_12'])
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/study_day_config_screen.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';

import '../../../helpers/firestore_fake.dart';
import '../../../helpers/firestore_fixtures.dart';

const _uid = 'study-day-gate-uid';
const _profileId = '01J9V8J5Q2K7M3N6P4R8T1WXYZ';

Future<bool> _gate({
  required FakeFirebaseFirestore firestore,
  required CurriculumId curriculumId,
}) async {
  final repository = FirestoreStageDefinitionRepository(
    firestore: firestore,
    uid: _uid,
    profileId: _profileId,
  );
  final container = ProviderContainer(
    overrides: [
      firestoreStageDefinitionRepositoryProvider.overrideWith(
        (ref) async => repository,
      ),
    ],
  );
  addTearDown(container.dispose);
  return container.read(curriculumTrackHasChazaraProvider(curriculumId).future);
}

List<StageDefinition> _stages(CurriculumId curriculumId, int count) => [
  for (var i = 1; i <= count; i++)
    StageDefinition(
      curriculumId: curriculumId,
      stageOrder: i,
      stageName: 'Stage $i',
      delayDays: i == 1 ? 0 : 1,
      isDefault: false,
    ),
];

void main() {
  test('one stage disables the chazara UI', () async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    await seedStageDefinitions(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
      stages: _stages(CurriculumId.mishnayos, 1),
    );

    expect(
      await _gate(firestore: firestore, curriculumId: CurriculumId.mishnayos),
      isFalse,
    );
  });

  test('two stages enable the chazara UI', () async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    await seedStageDefinitions(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
      stages: _stages(CurriculumId.mishnayos, 2),
    );

    expect(
      await _gate(firestore: firestore, curriculumId: CurriculumId.mishnayos),
      isTrue,
    );
  });

  test('an existing track with zero stages disables the chazara UI', () async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    await seedTrack(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
    );

    expect(
      await _gate(firestore: firestore, curriculumId: CurriculumId.mishnayos),
      isFalse,
    );
  });

  test('an absent curriculum has no chazara stages', () async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    expect(
      await _gate(firestore: firestore, curriculumId: CurriculumId.bavli),
      isFalse,
    );
  });

  test('stages from another curriculum do not contaminate the gate', () async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    await seedTrack(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
    );
    await seedTrack(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.bavli,
    );
    await seedStageDefinitions(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.bavli,
      stages: _stages(CurriculumId.bavli, 3),
    );

    final mishnayos = await _gate(
      firestore: firestore,
      curriculumId: CurriculumId.mishnayos,
    );
    final bavli = await _gate(
      firestore: firestore,
      curriculumId: CurriculumId.bavli,
    );
    expect(mishnayos, isFalse);
    expect(bavli, isTrue);
  });
}
