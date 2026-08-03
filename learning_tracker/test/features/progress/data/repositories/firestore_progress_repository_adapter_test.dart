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
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/progress/data/repositories/firestore_progress_repository_adapter.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseApp extends Mock implements FirebaseApp {}

class MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

void main() {
  // Constructing FirestoreProgressRepositoryAdapter requires a Ref
  // (Riverpod's Ref is sealed — it can only come from inside a provider
  // callback), so tests obtain one the same way production does: read a
  // throwaway Provider that builds the adapter from the container's ref —
  // same technique `FirestoreBookmarkRepositoryAdapter`'s test file uses.
  FirestoreProgressRepositoryAdapter buildAdapter(ProviderContainer container) {
    final adapterProvider = Provider<FirestoreProgressRepositoryAdapter>(
      (ref) => FirestoreProgressRepositoryAdapter(ref: ref),
    );
    return container.read(adapterProvider);
  }

  group('not ready (no active account/profile)', () {
    test(
      'getTrackBreakdown returns an empty map instead of throwing',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final adapter = buildAdapter(container);

        final result = await adapter.getTrackBreakdown('bavli');

        expect(result, isEmpty);
      },
    );

    test('getAggregateCount returns 0 instead of throwing', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final adapter = buildAdapter(container);

      final result = await adapter.getAggregateCount('bavli');

      expect(result, 0);
    });

    test(
      'getCompletionsByCurriculum throws ProgressRepositoryUnsupportedException '
      'regardless of readiness',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final adapter = buildAdapter(container);

        expect(
          () => adapter.getCompletionsByCurriculum('bavli'),
          throwsA(isA<ProgressRepositoryUnsupportedException>()),
        );
      },
    );

    test('getAllCompletions throws ProgressRepositoryUnsupportedException '
        'regardless of readiness', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final adapter = buildAdapter(container);

      expect(
        () => adapter.getAllCompletions(),
        throwsA(isA<ProgressRepositoryUnsupportedException>()),
      );
    });
  });

  group('ready (active account + profile)', () {
    const uid = 'uid-1';
    const profileDocId = 'profile-ulid-1';

    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;
    late FirestoreProgressRepositoryAdapter adapter;

    AccountFirebaseHandles handles() {
      return AccountFirebaseHandles(
        app: MockFirebaseApp(),
        firestore: firestore,
        auth: MockFirebaseAuthHandle(),
        uid: uid,
      );
    }

    setUp(() {
      firestore = FakeFirebaseFirestore();
      container = ProviderContainer(
        overrides: [
          activeAccountFirebaseProvider.overrideWith((ref) async => handles()),
        ],
      );
      container.read(activeProfileDocIdProvider.notifier).set(profileDocId);
      adapter = buildAdapter(container);
    });

    tearDown(() => container.dispose());

    Future<void> writeCompletion({
      required CurriculumId curriculumId,
      required String sefariaRef,
      required int stageId,
      required String trackType,
    }) async {
      final entity = CompletionEntity(
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        stageId: stageId,
        trackType: trackType,
        source: CompletionSource.live,
        completedAt: DateTime.utc(2026, 5, 1),
        points: 10,
      );
      await firestore
          .collection('users')
          .doc(uid)
          .collection('learner_profiles')
          .doc(profileDocId)
          .collection('completions')
          .doc('${curriculumId.storageKey}_${sefariaRef}_${stageId}_')
          .set(entity.toFirestore());
    }

    test('getTrackBreakdown delegates to FirestoreCompletionRepository and '
        'groups by trackType', () async {
      await writeCompletion(
        curriculumId: CurriculumId.bavli,
        sefariaRef: 'Berakhot.2a',
        stageId: 1,
        trackType: 'personal',
      );
      await writeCompletion(
        curriculumId: CurriculumId.bavli,
        sefariaRef: 'Berakhot.2b',
        stageId: 1,
        trackType: 'personal',
      );

      final breakdown = await adapter.getTrackBreakdown('bavli');

      expect(breakdown['personal'], 2);
    });

    test('getAggregateCount counts distinct sefariaRefs, matching '
        'getTrackBreakdown\'s scope', () async {
      await writeCompletion(
        curriculumId: CurriculumId.bavli,
        sefariaRef: 'Berakhot.2a',
        stageId: 1,
        trackType: 'personal',
      );
      await writeCompletion(
        curriculumId: CurriculumId.bavli,
        sefariaRef: 'Berakhot.2b',
        stageId: 1,
        trackType: 'personal',
      );

      final aggregate = await adapter.getAggregateCount('bavli');

      expect(aggregate, 2);
    });

    test('getTrackBreakdown filters by curriculum correctly', () async {
      await writeCompletion(
        curriculumId: CurriculumId.bavli,
        sefariaRef: 'Berakhot.2a',
        stageId: 1,
        trackType: 'personal',
      );
      await writeCompletion(
        curriculumId: CurriculumId.mishnayos,
        sefariaRef: 'Berakhot.1.1',
        stageId: 1,
        trackType: 'personal',
      );

      final bavliBreakdown = await adapter.getTrackBreakdown('bavli');
      final mishnaBreakdown = await adapter.getTrackBreakdown('mishnayos');

      expect(bavliBreakdown['personal'], 1);
      expect(mishnaBreakdown['personal'], 1);
    });

    test('getAggregateCount returns 0 when no completions exist', () async {
      final aggregate = await adapter.getAggregateCount('bavli');

      expect(aggregate, 0);
    });

    test('getCompletionsByCurriculum still throws even when ready — a '
        'type-shape gap, not a readiness gap', () async {
      expect(
        () => adapter.getCompletionsByCurriculum('bavli'),
        throwsA(isA<ProgressRepositoryUnsupportedException>()),
      );
    });

    test('getAllCompletions still throws even when ready — a type-shape gap, '
        'not a readiness gap', () async {
      expect(
        () => adapter.getAllCompletions(),
        throwsA(isA<ProgressRepositoryUnsupportedException>()),
      );
    });
  });
}
