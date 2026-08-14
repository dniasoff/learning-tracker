import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/firestore_fixtures.dart';

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

const _uid = 'l3-user';
const _profileId = '01J6Q2H4A8M7K3P9R5T6V8WXYB';

void main() {
  group('FirestoreStageDefinitionRepository L3', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreStageDefinitionRepository repository;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      await seedProfile(firestore, uid: _uid, profileId: _profileId);
      repository = FirestoreStageDefinitionRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      );
    });

    test('detects active and absent stage-order completions', () async {
      await seedCompletion(
        firestore,
        uid: _uid,
        profileId: _profileId,
        curriculumId: CurriculumId.mishnayos,
        stageId: 2,
      );

      expect(await repository.hasCompletionsForStage(2), isTrue);
      expect(await repository.hasCompletionsForStage(3), isFalse);
    });

    test(
      'ignores a purged completion but throws for malformed active data',
      () async {
        await seedCompletion(
          firestore,
          uid: _uid,
          profileId: _profileId,
          stageId: 4,
          purgedAt: DateTime.utc(2026, 1, 2),
        );
        expect(await repository.hasCompletionsForStage(4), isFalse);

        await firestore
            .collection('users')
            .doc(_uid)
            .collection('learner_profiles')
            .doc(_profileId)
            .collection('completions')
            .doc('malformed')
            .set({'stage_id': 5});

        expect(
          () => repository.hasCompletionsForStage(5),
          throwsA(isA<ArgumentError>()),
        );
      },
    );
  });

  group('FirestoreStageDefinitionRepositoryAdapter L3', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;
    late FirestoreStageDefinitionRepositoryAdapter adapter;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      await seedAccount(firestore, uid: _uid);
      await seedProfile(firestore, uid: _uid, profileId: _profileId);
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
        curriculumId: CurriculumId.mishnayos,
      );
      await seedStageDefinitions(
        firestore,
        uid: _uid,
        profileId: _profileId,
        curriculumId: CurriculumId.bavli,
      );

      container = ProviderContainer(
        overrides: [
          activeAccountFirebaseProvider.overrideWith(
            (ref) async => AccountFirebaseHandles(
              app: _MockFirebaseApp(),
              firestore: firestore,
              auth: _MockFirebaseAuth(),
              uid: _uid,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(activeProfileDocIdProvider.notifier).set(_profileId);

      final adapterProvider =
          Provider<FirestoreStageDefinitionRepositoryAdapter>(
            (ref) => FirestoreStageDefinitionRepositoryAdapter(ref: ref),
          );
      adapter = container.read(adapterProvider);
    });

    test('getStagesByTrack uses CurriculumId as the track identity', () async {
      final stages = await adapter.getStagesByTrack(CurriculumId.mishnayos);

      expect(stages, hasLength(3));
      expect(
        stages.every((stage) => stage.curriculumId == CurriculumId.mishnayos),
        isTrue,
      );
    });

    test(
      'deleteStagesForTrack tombstones only the requested curriculum',
      () async {
        await adapter.deleteStagesForTrack(CurriculumId.mishnayos);

        expect(await adapter.getStagesByTrack(CurriculumId.mishnayos), isEmpty);
        expect(
          await adapter.getStagesByTrack(CurriculumId.bavli),
          hasLength(3),
        );

        final deletedStage = await firestore
            .collection('users')
            .doc(_uid)
            .collection('learner_profiles')
            .doc(_profileId)
            .collection('stage_definitions')
            .doc(
              DocIds.stageDefinitionDocId({
                'curriculum_id': CurriculumId.mishnayos.storageKey,
                'stage_order': 1,
              }),
            )
            .get();
        expect(deletedStage.exists, isTrue);
        expect(deletedStage.data(), contains('synced_at'));
      },
    );
  });
}
