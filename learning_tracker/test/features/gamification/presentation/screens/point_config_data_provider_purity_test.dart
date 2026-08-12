@Tags(['gamification', 'point_config_data_provider'])
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_point_config_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/point_config_screen.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';

import '../../../../helpers/firestore_fake.dart';

const _uid = 'point-config-purity-uid';
const _profileId = '01J00000000000000000000019';

void main() {
  test(
    'watching the pure point-config provider performs no seed writes',
    () async {
      final firestore = createFakeFirestore(authenticatedUid: _uid);
      final pointConfigRepository = FirestorePointConfigRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      );
      final stageRepository = FirestoreStageDefinitionRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      );
      await stageRepository.initializeDefaults(CurriculumId.mishnayos);
      final tracks = StreamController<List<CurriculumTrackEntity>>.broadcast();
      final container = ProviderContainer(
        overrides: [
          activeTracksProvider.overrideWith((ref) => tracks.stream),
          stageDefinitionRepositoryProvider(
            CurriculumId.mishnayos,
          ).overrideWith(
            (ref) => FirestoreStageDefinitionRepositoryAdapter(ref: ref),
          ),
          firestoreStageDefinitionRepositoryProvider.overrideWith(
            (ref) async => stageRepository,
          ),
          firestorePointConfigRepositoryProvider.overrideWith(
            (ref) async => pointConfigRepository,
          ),
        ],
      );
      final tracksSubscription = container.listen(
        activeTracksProvider,
        (_, __) {},
      );
      addTearDown(tracksSubscription.close);
      addTearDown(tracks.close);
      addTearDown(container.dispose);

      final track = CurriculumTrackEntity(
        curriculumId: CurriculumId.mishnayos,
        state: CurriculumTrackState.active.storageKey,
        stateChangedAt: DateTime.utc(2026, 1, 1),
        activatedAt: DateTime.utc(2026, 1, 1),
      );
      tracks.add([track]);
      await pumpEventQueue();

      final before = await firestore
          .collection('users')
          .doc(_uid)
          .collection('learner_profiles')
          .doc(_profileId)
          .collection('point_configs')
          .get();
      expect(before.docs, isEmpty);

      final data = await container.read(pointConfigDataProvider.future);
      expect(data, hasLength(1));

      final after = await firestore
          .collection('users')
          .doc(_uid)
          .collection('learner_profiles')
          .doc(_profileId)
          .collection('point_configs')
          .get();
      expect(after.docs, isEmpty);
    },
  );
}
