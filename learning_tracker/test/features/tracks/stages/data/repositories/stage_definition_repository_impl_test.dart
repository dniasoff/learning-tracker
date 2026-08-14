/// Unit tests for [FirestoreStageDefinitionRepositoryAdapter]
/// (`lib/features/tracks/stages/data/repositories/
/// stage_definition_repository_impl.dart`) — the Firestore adapter over
/// [FirestoreStageDefinitionRepository] that implements
/// [StageDefinitionRepository]. Mirrors
/// `bookmark_repository_impl_test.dart`'s `FirestoreBookmarkRepositoryAdapter`
/// group structure (the reference pattern): a "not ready" group (no active
/// account/profile) and a "ready" group (active account/profile, backed by
/// `fake_cloud_firestore`).
///
/// The Drift-backed [StageDefinitionRepositoryImpl] itself has no dedicated
/// unit-test file to extend — its behavior is covered by the story
/// acceptance suite — so this file covers ONLY the new adapter class.
///
/// **What these tests cannot see**: `fake_cloud_firestore`'s own
/// limitations (no composite-index enforcement, no `resource.data` rules
/// evaluation) are already documented in
/// `firestore_stage_definition_repository_test.dart` and are not
/// re-documented here — this file only proves the adapter DELEGATES
/// correctly, not that the underlying repository's Firestore behavior is
/// correct (that is that file's job).
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/firestore_fixtures.dart';

class MockFirebaseApp extends Mock implements FirebaseApp {}

class MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

void main() {
  group('FirestoreStageDefinitionRepositoryAdapter', () {
    const uid = 'uid-1';
    const profileDocId = '01J6Q2H4A8M7K3P9R5T6V8WXYB';

    AccountFirebaseHandles handles(FakeFirebaseFirestore firestore) {
      return AccountFirebaseHandles(
        app: MockFirebaseApp(),
        firestore: firestore,
        auth: MockFirebaseAuthHandle(),
        uid: uid,
      );
    }

    // Constructing the adapter requires a Ref (Riverpod's Ref is sealed —
    // it can only come from inside a provider callback), so tests obtain
    // one the same way production does: read a throwaway Provider that
    // builds the adapter from the container's ref. Mirrors
    // FirestoreBookmarkRepositoryAdapter's test helper
    // (bookmark_repository_impl_test.dart).
    FirestoreStageDefinitionRepositoryAdapter buildAdapter(
      ProviderContainer container,
    ) {
      final adapterProvider =
          Provider<FirestoreStageDefinitionRepositoryAdapter>(
            (ref) => FirestoreStageDefinitionRepositoryAdapter(ref: ref),
          );
      return container.read(adapterProvider);
    }

    group('not ready (no active account/profile)', () {
      test(
        'getStagesForCurriculum throws StageDefinitionRepositoryNotReadyException',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          expect(
            () => adapter.getStagesForCurriculum(CurriculumId.mishnayos),
            throwsA(isA<StageDefinitionRepositoryNotReadyException>()),
          );
        },
      );

      test(
        'getAllStageDefinitions throws StageDefinitionRepositoryNotReadyException',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          expect(
            () => adapter.getAllStageDefinitions(),
            throwsA(isA<StageDefinitionRepositoryNotReadyException>()),
          );
        },
      );

      test(
        'initializeDefaults throws StageDefinitionRepositoryNotReadyException',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          expect(
            () => adapter.initializeDefaults(CurriculumId.mishnayos),
            throwsA(isA<StageDefinitionRepositoryNotReadyException>()),
          );
        },
      );

      test(
        'resetToDefaults throws StageDefinitionRepositoryNotReadyException',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          expect(
            () => adapter.resetToDefaults(CurriculumId.mishnayos),
            throwsA(isA<StageDefinitionRepositoryNotReadyException>()),
          );
        },
      );

      test(
        'hasCompletionsForStage throws StageDefinitionRepositoryNotReadyException',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          expect(
            () => adapter.hasCompletionsForStage(1),
            throwsA(isA<StageDefinitionRepositoryNotReadyException>()),
          );
        },
      );

      // Verified against StageDefinitionRepository and
      // FirestoreStageDefinitionRepositoryAdapter: pushStagesForTrack was a
      // retired sync-pipeline operation and no longer exists; its no-op test
      // premise is obsolete, so this single test case is intentionally gone.
    });

    group('ready (active account + profile)', () {
      late FakeFirebaseFirestore firestore;
      late ProviderContainer container;
      late FirestoreStageDefinitionRepositoryAdapter adapter;

      setUp(() {
        firestore = FakeFirebaseFirestore();
        container = ProviderContainer(
          overrides: [
            activeAccountFirebaseProvider.overrideWith(
              (ref) async => handles(firestore),
            ),
          ],
        );
        container.read(activeProfileDocIdProvider.notifier).set(profileDocId);
        adapter = buildAdapter(container);
      });

      tearDown(() => container.dispose());

      test('initializeDefaults delegates to FirestoreStageDefinitionRepository '
          'and seeds 3 default stages reachable at the expected Firestore '
          'path', () async {
        await adapter.initializeDefaults(
          CurriculumId.mishnayos,
        );

        final stages = await adapter.getStagesForCurriculum(
          CurriculumId.mishnayos,
        );
        expect(stages, hasLength(3));

        final doc = await firestore
            .collection('users')
            .doc(uid)
            .collection('learner_profiles')
            .doc(profileDocId)
            .collection('stage_definitions')
            .doc('mishnayos_1')
            .get();
        expect(doc.exists, isTrue);
      });

      test(
        'getStagesForCurriculum returns [] before anything is seeded',
        () async {
          final stages = await adapter.getStagesForCurriculum(
            CurriculumId.mishnayos,
          );
          expect(stages, isEmpty);
        },
      );

      test(
        'resetToDefaults overwrites the 3 default doc-ids in place',
        () async {
          await adapter.initializeDefaults(
            CurriculumId.mishnayos,
          );

          await adapter.resetToDefaults(CurriculumId.mishnayos);

          final stages = await adapter.getStagesForCurriculum(
            CurriculumId.mishnayos,
          );
          expect(stages, hasLength(3));
        },
      );

      test('hasCompletionsForStage delegates to completion data', () async {
        await seedCompletion(
          firestore,
          uid: uid,
          profileId: profileDocId,
          stageId: 1,
        );

        expect(await adapter.hasCompletionsForStage(1), isTrue);
        expect(await adapter.hasCompletionsForStage(2), isFalse);
      });

      test(
        'getStagesByTrack uses CurriculumId and returns only its stages',
        () async {
          await adapter.initializeDefaults(
            CurriculumId.mishnayos,
          );
          await adapter.initializeDefaults(
            CurriculumId.bavli,
          );

          final stages = await adapter.getStagesByTrack(CurriculumId.mishnayos);

          expect(stages, hasLength(3));
          expect(
            stages.every(
              (stage) => stage.curriculumId == CurriculumId.mishnayos,
            ),
            isTrue,
          );
        },
      );

      test('deleteStagesForTrack tombstones only that curriculum', () async {
        await adapter.initializeDefaults(
          CurriculumId.mishnayos,
        );
        await adapter.initializeDefaults(
          CurriculumId.bavli,
        );

        await adapter.deleteStagesForTrack(CurriculumId.mishnayos);

        expect(await adapter.getStagesByTrack(CurriculumId.mishnayos), isEmpty);
        expect(
          await adapter.getStagesByTrack(CurriculumId.bavli),
          hasLength(3),
        );

        final stageDoc = await firestore
            .collection('users')
            .doc(uid)
            .collection('learner_profiles')
            .doc(profileDocId)
            .collection('stage_definitions')
            .doc('mishnayos_1')
            .get();
        expect(stageDoc.exists, isTrue);
        expect(stageDoc.data(), contains('synced_at'));
      });

      // Verified against StageDefinitionRepository and
      // FirestoreStageDefinitionRepositoryAdapter: the former push no-op was
      // removed with the sync pipeline, so this second occurrence's premise
      // is also obsolete and this single test case is intentionally gone.

      test('getAllStageDefinitions returns every seeded stage', () async {
        await adapter.initializeDefaults(
          CurriculumId.mishnayos,
        );

        final all = await adapter.getAllStageDefinitions();
        expect(all, hasLength(3));
      });
    });
  });
}
